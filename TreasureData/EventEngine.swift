//
//  EventEngine.swift
//  TreasureData
//
//  The internal seam between the public `TreasureData` façade and the buffering /
//  upload engine. This is backed by `KeenEventEngine` (which wraps KeenClient).
//  The engine implementation can be swapped without changing this protocol or
//  the public API.
//

import Foundation

/// Callback fired (on the main thread) when a buffer/upload operation succeeds.
typealias EngineSuccessHandler = () -> Void

/// Callback fired (on the main thread) when a buffer/upload operation fails,
/// carrying an error code and a human-readable message. Both are optional to
/// match the un-annotated Objective-C block signature this bridges to.
typealias EngineErrorHandler = (_ errorCode: String?, _ message: String?) -> Void

/// Retry policy for uploads. Mirrors the tunables currently exposed on `TDClient`.
struct RetryConfig {
    var isEnabled: Bool
    /// Wait before next retry = `intervalCoefficient` * `intervalBase` ^ retryCount.
    var intervalCoefficient: Int
    var intervalBase: Int
    var maxCount: Int

    /// The defaults `TDClient.__initWithApiKey:apiEndpoint:` installs today.
    static let `default` = RetryConfig(
        isEnabled: true,
        intervalCoefficient: 4,
        intervalBase: 2,
        maxCount: 5
    )
}

/// The buffering + upload engine behind the `TreasureData` façade.
///
/// An event `collection` is the `"database.table"` string the façade builds; the
/// engine is agnostic to how it is composed.
protocol EventEngine: AnyObject {

    /// The write-only API key used to authenticate uploads.
    var apiKey: String { get set }

    /// The ingestion endpoint uploads are sent to.
    var apiEndpoint: String { get set }

    /// Whether the client's IP is tracked (selects the request content type).
    var isTrackingIP: Bool { get set }

    /// Retry policy for failed uploads.
    var retry: RetryConfig { get set }

    /// The URLSession used for uploads. Injectable so tests can stub the network.
    var session: URLSession { get set }

    /// Buffer an already-enriched event into the given `"database.table"` collection.
    func addEvent(_ event: [String: Any],
                  collection: String,
                  onSuccess: EngineSuccessHandler?,
                  onError: EngineErrorHandler?)

    /// Drain the buffer and upload pending events.
    /// - Parameter compression: gzip the payload when `true`.
    func upload(compression: Bool,
                onSuccess: EngineSuccessHandler?,
                onError: EngineErrorHandler?)

    /// Install the encryption key for the on-disk buffer. Must be called once,
    /// before any `addEvent`.
    static func initializeEncryptionKey(_ key: String?)

    /// Synchronously drop all buffered events. Used by tests to reset the buffer
    /// between cases; routes clearing through the live engine's own store.
    func deleteAllBufferedEvents()
}
