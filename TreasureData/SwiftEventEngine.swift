//
//  SwiftEventEngine.swift
//  TreasureData
//
//  Pure-Swift `EventEngine`: buffering via the Swift `EventStore` and the
//  add/serialize/upload orchestration ported from KeenClient.

import Foundation

// Error codes, matching KeenClient's ERROR_CODE_* string constants that tests
// and callers observe.
private enum EngineError {
    static let invalidEvent = "invalid_event"
    static let dataConversion = "data_conversion"
    static let storageError = "storage_error"
    static let networkError = "network_error"
    static let serverResponse = "server_response"
}

final class SwiftEventEngine: EventEngine {
    
    // Buffer sizing, matching kKeenMaxEventsPerCollection / kKeenNumberEventsToForget
    // and KeenClient's maxUploadEventsAtOnce.
    private static let maxEventsPerCollection = 10000
    private static let numberEventsToForget = 100
    private static let maxUploadEventsAtOnce = 400
    
    private let store = EventStore()
    private let sender: TDClient
    private let uploadQueue = DispatchQueue(label: "com.treasuredata.uploader")
    
    init(apiKey: String, apiEndpoint: String) {
        self.sender = TDClient(apiKey: apiKey, apiEndpoint: apiEndpoint)
        // KeenClient namespaced its on-disk buffer by projectId; keep the exact
        // "_td <sha256(apiKey)>" scheme so upgrading apps reuse their buffer.
        store.projectId = sender.projectIdForBuffer
    }
    
    // MARK: - EventEngine config (forwarded to the sender)
    
    var apiKey: String {
        get { sender.apiKey }
        set { sender.apiKey = newValue }
    }
    var apiEndpoint: String {
        get { sender.apiEndpoint }
        set { sender.apiEndpoint = newValue }
    }
    var isTrackingIP: Bool {
        get { sender.isTrackingIP }
        set { sender.isTrackingIP = newValue }
    }
    var session: URLSession {
        get { sender.uploadSession }
        set { sender.uploadSession = newValue }
    }
    var retry: RetryConfig {
        get {
            RetryConfig(isEnabled: sender.retryEnabled,
                        intervalCoefficient: sender.retryIntervalCoefficient,
                        intervalBase: sender.retryIntervalBase,
                        maxCount: sender.retryCount)
        }
        set {
            sender.retryEnabled = newValue.isEnabled
            sender.retryIntervalCoefficient = newValue.intervalCoefficient
            sender.retryIntervalBase = newValue.intervalBase
            sender.retryCount = newValue.maxCount
        }
    }
    
    static func initializeEncryptionKey(_ key: String?) {
        EventStore.initializeEncryptionKey(key)
    }
    
    func deleteAllBufferedEvents() {
        store.deleteAllEventsSync()
    }
    
    // MARK: - Add (KeenClient.addEvent:withKeenProperties:...)
    
    func addEvent(_ event: [String: Any],
                  collection: String,
                  onSuccess: EngineSuccessHandler?,
                  onError: EngineErrorHandler?) {
        // Stamp a uuid, matching TDClient's globalPropertiesBlock.
        var newEvent = event
        if newEvent["uuid"] == nil { newEvent["uuid"] = UUID().uuidString }
        
        // Age out the collection if we're at the cap.
        let eventCount = Int(store.getTotalEventCount())
        if eventCount + 1 > SwiftEventEngine.maxEventsPerCollection {
            store.deleteEvents(fromOffset: NSNumber(value: eventCount - SwiftEventEngine.numberEventsToForget))
        }
        
        // Serialize (converting NSDate values to ISO-8601 via the store, as
        // KeenClient's handleInvalidJSONInObject did).
        let fixed = handleInvalidJSON(newEvent)
        guard JSONSerialization.isValidJSONObject(fixed),
              let jsonData = try? JSONSerialization.data(withJSONObject: fixed) else {
            onError?(EngineError.dataConversion, "An error occurred when serializing event to JSON")
            return
        }
        
        store.lastErrorMessage = nil
        if store.addEvent(jsonData, collection: collection) {
            onSuccess?()
        } else {
            onError?(EngineError.storageError, store.lastErrorMessage)
        }
    }
    
    /// Recursively convert NSDate values to ISO-8601 strings; leave everything
    /// else as-is. Mirrors KeenClient's handleInvalidJSONInObject for dates.
    private func handleInvalidJSON(_ value: Any) -> Any {
        switch value {
        case let dict as [String: Any]:
            var out = [String: Any]()
            for (k, v) in dict { out[k] = handleInvalidJSON(v) }
            return out
        case let arr as [Any]:
            return arr.map { handleInvalidJSON($0) }
        case let date as Date:
            return store.convertToISO8601(date)
        default:
            return value
        }
    }
    
    // MARK: - Upload (KeenClient.upload / uploadCollection / handleIngestAPIResponse)
    
    func upload(compression: Bool,
                onSuccess: EngineSuccessHandler?,
                onError: EngineErrorHandler?) {
        sender.isEventCompressionEnabled = compression
        uploadQueue.async { [self] in
            let events = store.getEvents()
            if events.isEmpty {
                onSuccess?()
                return
            }
            
            let lock = NSObject()
            var finished = Set<String>()
            var finalError: (String, String?)?
            let total = events.count
            
            let collectionDone: (String, (String, String?)?) -> Void = { coll, err in
                objc_sync_enter(lock); defer { objc_sync_exit(lock) }
                if finished.contains(coll) { return }
                finished.insert(coll)
                if let err = err { finalError = err }
                if finished.count == total {
                    if let (code, msg) = finalError { onError?(code, msg) }
                    else { onSuccess?() }
                }
            }
            
            for (collection, collEvents) in events {
                uploadCollection(collection, collEvents, done: collectionDone)
            }
        }
    }
    
    /// Split a collection's events into chunks of maxUploadEventsAtOnce and
    /// upload each; report the collection done when all chunks settle.
    private func uploadCollection(_ collection: String,
                                  _ collEvents: [NSNumber: Data],
                                  done: @escaping (String, (String, String?)?) -> Void) {
        let parts = collection.components(separatedBy: ".")
        guard parts.count == 2 else {
            done(collection, (EngineError.invalidEvent, "Invalid collection name: \(collection)"))
            return
        }
        let database = parts[0], table = parts[1]
        
        // Deserialize buffered rows into (event dicts, matching event ids).
        var chunks: [(events: [Any], ids: [NSNumber])] = []
        var events: [Any] = []
        var ids: [NSNumber] = []
        for (eid, data) in collEvents {
            guard let dict = try? JSONSerialization.jsonObject(with: data) else { continue }
            events.append(dict)
            ids.append(eid)
            if events.count >= SwiftEventEngine.maxUploadEventsAtOnce {
                chunks.append((events, ids)); events = []; ids = []
            }
        }
        if !events.isEmpty { chunks.append((events, ids)) }
        
        if chunks.isEmpty { done(collection, nil); return }
        
        let lock = NSObject()
        var finishedChunks = 0
        var finalError: (String, String?)?
        let total = chunks.count
        
        for chunk in chunks {
            guard let requestData = try? JSONSerialization.data(withJSONObject: ["events": chunk.events]) else {
                objc_sync_enter(lock)
                finishedChunks += 1
                finalError = (EngineError.dataConversion, "An error occurred when serializing the final request data back to JSON")
                let complete = finishedChunks == total
                let err = finalError
                objc_sync_exit(lock)
                if complete { done(collection, err) }
                continue
            }
            
            sender.sendEvents(requestData, database: database, table: table) { [self] data, response, _ in
                let err = handleResponse(data: data, response: response, eventIds: chunk.ids)
                objc_sync_enter(lock)
                finishedChunks += 1
                if let err = err { finalError = err }
                let complete = finishedChunks == total
                let settled = finalError
                objc_sync_exit(lock)
                if complete { done(collection, settled) }
            }
        }
    }
    
    /// Parse the ingest response, delete succeeded/user-error events, keep
    /// server-error ones. Mirrors KeenClient.handleIngestAPIResponse.
    private func handleResponse(data: Data?, response: URLResponse?, eventIds: [NSNumber]) -> (String, String?)? {
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard let data = data else {
            return (statusCode == 0 ? EngineError.networkError : EngineError.serverResponse,
                    "response status code: \(statusCode)")
        }
        guard statusCode == 200 else {
            return (statusCode == 0 ? EngineError.networkError : EngineError.serverResponse,
                    "Response code was NOT 200. It was: \(statusCode)")
        }
        guard let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return (EngineError.dataConversion, "An error occurred when deserializing HTTP response JSON into dictionary.")
        }
        
        let results = dict["receipts"] as? [[String: Any]] ?? []
        // These KeenClient error names mean "user error, drop the event".
        let userErrors: Set<String> = ["InvalidCollectionNameError", "InvalidPropertyNameError", "InvalidPropertyValueError"]
        for (i, result) in results.enumerated() {
            var deleteRow = true
            let success = (result["success"] as? NSNumber)?.boolValue ?? false
            if !success {
                let errorDict = result["error"] as? [String: Any]
                let errorCode = errorDict?["name"] as? String
                // Keep the row only on a non-user (server) error.
                deleteRow = errorCode != nil && userErrors.contains(errorCode!)
            }
            if deleteRow, i < eventIds.count {
                store.deleteEvent(eventIds[i])
            }
        }
        return nil
    }
}
