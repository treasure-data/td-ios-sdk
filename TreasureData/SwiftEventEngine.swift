//
//  SwiftEventEngine.swift
//  TreasureData
//
//  Pure-Swift `EventEngine`: buffering via the Swift `EventStore` plus the
//  add / serialize / upload orchestration.

import Foundation

// Error-code strings surfaced to callers (and asserted by tests).
private enum EngineError {
    static let invalidEvent = "invalid_event"
    static let dataConversion = "data_conversion"
    static let storageError = "storage_error"
    static let networkError = "network_error"
    static let serverResponse = "server_response"
}

final class SwiftEventEngine: EventEngine {
    
    // Buffer sizing: cap per collection, how many to drop when aging out, and
    // the max events sent in a single upload request.
    private static let maxEventsPerCollection = 10000
    private static let numberEventsToForget = 100
    private static let maxUploadEventsAtOnce = 400
    
    private let store = EventStore()
    private let sender: TDClient
    private let uploadQueue = DispatchQueue(label: "com.treasuredata.uploader")
    
    init(apiKey: String, apiEndpoint: String) {
        self.sender = TDClient(apiKey: apiKey, apiEndpoint: apiEndpoint)
        // The on-disk buffer is namespaced by a projectId derived from the api
        // key ("_td <sha256(apiKey)>"); this scheme is preserved so upgrading
        // apps reuse their existing buffer.
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
    
    // MARK: - Add
    
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
        
        // Serialize, converting any NSDate values to ISO-8601 via the store.
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
    /// else as-is.
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
    
    // MARK: - Upload
    
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

            // Fan out one send per chunk across all collections; a DispatchGroup
            // joins them. `errorLock` guards the single shared error slot.
            let group = DispatchGroup()
            let errorLock = NSLock()
            var finalError: (String, String?)?
            let recordError: ((String, String?)?) -> Void = { err in
                guard let err = err else { return }
                errorLock.lock(); finalError = err; errorLock.unlock()
            }

            for (collection, collEvents) in events {
                uploadCollection(collection, collEvents, group: group, onError: recordError)
            }

            group.notify(queue: uploadQueue) {
                if let (code, msg) = finalError { onError?(code, msg) }
                else { onSuccess?() }
            }
        }
    }

    /// Split a collection's events into chunks of maxUploadEventsAtOnce and send
    /// each, entering `group` per in-flight send.
    private func uploadCollection(_ collection: String,
                                  _ collEvents: [NSNumber: Data],
                                  group: DispatchGroup,
                                  onError: @escaping ((String, String?)?) -> Void) {
        let parts = collection.components(separatedBy: ".")
        guard parts.count == 2 else {
            onError((EngineError.invalidEvent, "Invalid collection name: \(collection)"))
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

        for chunk in chunks {
            guard let requestData = try? JSONSerialization.data(withJSONObject: ["events": chunk.events]) else {
                onError((EngineError.dataConversion, "An error occurred when serializing the final request data back to JSON"))
                continue
            }
            group.enter()
            sender.sendEvents(requestData, database: database, table: table) { [self] data, response, _ in
                onError(handleResponse(data: data, response: response, eventIds: chunk.ids))
                group.leave()
            }
        }
    }
    
    /// Parse the ingest response, delete succeeded/user-error events, keep
    /// server-error ones for a later retry.
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
        // These ingest error names mean "user error, drop the event".
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
