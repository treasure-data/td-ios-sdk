//
//  KeenEventEngine.swift
//  TreasureData
//
//  `EventEngine` implementation that wraps the existing Objective-C `TDClient`
//  (a `KeenClient` subclass) by *composition* — no Swift type subclasses
//  KeenClient, so KeenClient never appears in the public API and this can be
//  swapped for a pure-Swift engine without breaking consumers.
//

import Foundation

final class KeenEventEngine: EventEngine {

    /// The underlying ObjC client. Held via composition, deliberately not exposed.
    private let client: TDClient

    init(apiKey: String, apiEndpoint: String) {
        self.client = TDClient(apiKey: apiKey, apiEndpoint: apiEndpoint)
    }

    var apiKey: String {
        get { client.apiKey }
        set { client.apiKey = newValue }
    }

    var apiEndpoint: String {
        get { client.apiEndpoint }
        set { client.apiEndpoint = newValue }
    }

    var isTrackingIP: Bool {
        get { client.enableTrackingIP }
        set { client.enableTrackingIP = newValue }
    }

    var session: URLSession {
        get { client.__session() ?? .shared }
        set { client.__setSession(newValue) }
    }

    var retry: RetryConfig {
        get {
            RetryConfig(
                isEnabled: client.enableRetryUploading,
                intervalCoefficient: Int(client.uploadRetryIntervalCoeficient),
                intervalBase: Int(client.uploadRetryIntervalBase),
                maxCount: Int(client.uploadRetryCount)
            )
        }
        set {
            client.enableRetryUploading = newValue.isEnabled
            client.uploadRetryIntervalCoeficient = Int32(newValue.intervalCoefficient)
            client.uploadRetryIntervalBase = Int32(newValue.intervalBase)
            client.uploadRetryCount = Int32(newValue.maxCount)
        }
    }

    func addEvent(_ event: [String: Any],
                  collection: String,
                  onSuccess: EngineSuccessHandler?,
                  onError: EngineErrorHandler?) {
        client.addEvent(withCallbacks: event,
                        toEventCollection: collection,
                        onSuccess: onSuccess,
                        onError: onError)
    }

    func upload(compression: Bool,
                onSuccess: EngineSuccessHandler?,
                onError: EngineErrorHandler?) {
        client.__enableEventCompression(compression)
        client.upload(callbacks: onSuccess, onError: onError)
    }

    static func initializeEncryptionKey(_ key: String?) {
        TDClient.initializeEncryptionKey(key)
    }
}
