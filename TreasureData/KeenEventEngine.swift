//
//  KeenEventEngine.swift
//  TreasureData
//
//  `EventEngine` implementation backed by KeenClient's buffer + upload
//  orchestration, via the internal `TDClient` (a KeenClient subclass that
//  redirects uploads to the Treasure Data endpoint). KeenClient never appears in
//  the public API; this can be swapped for a pure-Swift engine without breaking
//  consumers.
//

import Foundation
import KeenClientTD

final class KeenEventEngine: EventEngine {

    /// The underlying KeenClient subclass. Held via composition, never exposed.
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
        get { client.isTrackingIP }
        set { client.isTrackingIP = newValue }
    }

    var session: URLSession {
        get { client.uploadSession }
        set { client.uploadSession = newValue }
    }

    var retry: RetryConfig {
        get {
            RetryConfig(
                isEnabled: client.retryEnabled,
                intervalCoefficient: client.retryIntervalCoefficient,
                intervalBase: client.retryIntervalBase,
                maxCount: client.retryCount
            )
        }
        set {
            client.retryEnabled = newValue.isEnabled
            client.retryIntervalCoefficient = newValue.intervalCoefficient
            client.retryIntervalBase = newValue.intervalBase
            client.retryCount = newValue.maxCount
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
        client.isEventCompressionEnabled = compression
        client.upload(callbacks: onSuccess, onError: onError)
    }

    static func initializeEncryptionKey(_ key: String?) {
        KeenClient.initializeEncryptionKey(key)
    }

    func deleteAllBufferedEvents() {
        KeenClient.clearAllEvents()
    }
}
