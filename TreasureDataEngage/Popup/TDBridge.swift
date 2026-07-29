//
//  TDBridge.swift
//  TreasureDataEngage
//
//  The native side of the WebView↔native channel. Receives
//  messages posted to the "TDBridge" handler and dispatches the four fixed
//  methods: close / openUrl / track / invoke. Holds no API keys and makes no
//  HTTP calls of its own.
//
//  Custom methods use a SINGLE delegate entry point (`handleTDBridgeInvoke`):
//  the SDK never inspects the invoke `name`, never allowlists it, and never
//  errors on an unknown name — the app dispatches and authorizes. This suits a
//  SaaS where each customer exposes a different set of functions.
//

#if canImport(WebKit)
import Foundation
import WebKit

/// Breaks the WKUserContentController → handler retain cycle. The content
/// controller strongly retains whatever is passed to `add(_:name:)`; a weak
/// forwarder lets the real bridge (and its owning view) deinit normally.
final class WeakScriptMessageHandler: NSObject, WKScriptMessageHandler {
    weak var target: WKScriptMessageHandler?

    init(_ target: WKScriptMessageHandler) {
        self.target = target
    }

    func userContentController(_ controller: WKUserContentController,
                               didReceive message: WKScriptMessage) {
        target?.userContentController(controller, didReceive: message)
    }
}

/// The bridge message name shared with the injected JS
/// (`window.webkit.messageHandlers.TDBridge`).
let tdBridgeMessageName = "TDBridge"

/// The fixed WebView→SDK methods. `invoke`'s inner name is deliberately NOT in
/// this set — it is unbounded and handled by the app delegate.
enum TDBridgeMethod {
    static let close = "close"
    static let openUrl = "openUrl"
    static let track = "track"
    static let invoke = "invoke"
}

/// The app's integration point. The SDK relays app-specific decisions here;
/// business logic, authorization, navigation, and unknown-name handling are the
/// app's responsibility.
public protocol TDBridgeDelegate: AnyObject {
    /// Every `invoke(name, params)` from the LP. The SDK does not inspect `name`.
    func handleTDBridgeInvoke(name: String, params: [String: Any])

    /// `openUrl(url)` — deep-link / native navigation. The navigation decision
    /// is the app's.
    func handleTDBridgeOpenURL(_ url: URL)

    /// `track(event, values)` — measurement/feedback from the LP. Routed to the
    /// app so it decides the destination (table) via the core SDK's ingest.
    /// TODO: confirm whether track should instead go straight to a fixed SDK
    /// ingest table rather than through the app.
    func handleTDBridgeTrack(event: String, values: [String: Any])
}

final class TDBridge: NSObject, WKScriptMessageHandler {

    /// The container providing the close callback. Weak: the container owns the
    /// bridge (indirectly, via the web view config).
    weak var host: LandingPageView?

    /// App integration point for invoke / openUrl / track.
    weak var delegate: TDBridgeDelegate?

    /// A decoded, allowlisted message. Constructed only from a well-formed body
    /// whose `method` is one of the fixed four — the single trust boundary.
    private struct Message {
        let method: String
        let body: [String: Any]
    }

    func userContentController(_ controller: WKUserContentController,
                               didReceive message: WKScriptMessage) {
        guard let msg = decode(message.body) else { return }

        switch msg.method {
        case TDBridgeMethod.close:
            host?.onClose?()

        case TDBridgeMethod.openUrl:
            guard let urlString = msg.body["url"] as? String,
                  let url = URL(string: urlString) else {
                EngageLog.log("TDBridge: openUrl with missing/invalid url")
                return
            }
            delegate?.handleTDBridgeOpenURL(url)

        case TDBridgeMethod.track:
            guard let event = msg.body["event"] as? String else {
                EngageLog.log("TDBridge: track with missing event")
                return
            }
            // params/values are objects (not JSON strings) for iOS/Android parity.
            let values = msg.body["values"] as? [String: Any] ?? [:]
            delegate?.handleTDBridgeTrack(event: event, values: values)

        case TDBridgeMethod.invoke:
            guard let name = msg.body["name"] as? String else {
                EngageLog.log("TDBridge: invoke with missing name")
                return
            }
            let params = msg.body["params"] as? [String: Any] ?? [:]
            // The SDK does not inspect `name`; the app dispatches + authorizes.
            delegate?.handleTDBridgeInvoke(name: name, params: params)

        default:
            // Unreachable: `decode` only admits the fixed four. Defensive no-op.
            break
        }
    }

    /// Typed decode + allowlist. Returns nil (drop, no-op) for any message that
    /// is malformed OR whose `method` is not one of the fixed four. This is the
    /// trust boundary: never network, never eval for anything that fails here.
    private func decode(_ body: Any) -> Message? {
        guard let dict = body as? [String: Any] else {
            EngageLog.log("TDBridge: dropped non-object message: \(body)")
            return nil
        }
        guard let method = dict["method"] as? String else {
            EngageLog.log("TDBridge: dropped message with missing/invalid method")
            return nil
        }
        guard allowedMethods.contains(method) else {
            EngageLog.log("TDBridge: dropped unallowed method '\(method)'")
            return nil
        }
        return Message(method: method, body: dict)
    }

    /// The fixed method allowlist. `invoke`'s inner `name` is intentionally NOT
    /// bounded here — that is the app delegate's domain.
    private let allowedMethods: Set<String> = [
        TDBridgeMethod.close,
        TDBridgeMethod.openUrl,
        TDBridgeMethod.track,
        TDBridgeMethod.invoke,
    ]

    // MARK: - JSON literal (for TDContext injection)

    /// Serialize `value` to a JSON literal safe to embed in evaluateJavaScript /
    /// an injected user script. Falls back to `null` for nil or non-JSON values
    /// rather than injecting a broken/dangerous string.
    ///
    /// JSONSerialization on iOS 12 requires a top-level container (no
    /// `.fragmentsAllowed`), so the value is wrapped in a one-element array and
    /// the surrounding `[` `]` trimmed. Arrays serialize deterministically.
    static func jsonLiteral(from value: Any?) -> String {
        guard let value = value else { return "null" }
        let wrapped = [value]
        guard JSONSerialization.isValidJSONObject(wrapped),
              let data = try? JSONSerialization.data(withJSONObject: wrapped),
              let json = String(data: data, encoding: .utf8),
              json.hasPrefix("["), json.hasSuffix("]") else {
            EngageLog.log("TDBridge: value not JSON-serializable, using null")
            return "null"
        }
        return String(json.dropFirst().dropLast())
    }
}
#endif
