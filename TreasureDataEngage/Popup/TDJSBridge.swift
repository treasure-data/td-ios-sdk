//
//  TDJSBridge.swift
//  TreasureDataEngage
//
//  The native side of the WebView↔native channel. Receives messages posted to
//  the "TDJSBridge" handler, dispatches standard (and registered) methods, and
//  resolves JS callbacks via window.__tdBridgeResolve. Holds no API keys and
//  makes no HTTP calls of its own.
//

#if canImport(WebKit)
import Foundation
import WebKit

/// Breaks the WKUserContentController → handler retain cycle. The content
/// controller strongly retains whatever is passed to `add(_:name:)`; giving it a
/// weak forwarder lets the real `TDJSBridge` (and its owning `PopupWebView`)
/// deinit normally.
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
/// (`window.webkit.messageHandlers.TDJSBridge`).
let tdBridgeMessageName = "TDJSBridge"

/// The standard method names the bridge always handles.
enum TDBridgeMethod {
    static let getCampaignPayload = "getCampaignPayload"
    static let closeMessage = "closeMessage"
}

final class TDJSBridge: NSObject, WKScriptMessageHandler {

    /// A registered custom-method handler: receives the raw JSON-string arg the
    /// page passed and a `done` closure to resolve the JS callback with any
    /// JSON-safe value.
    typealias Handler = (_ json: String?, _ done: @escaping (Any?) -> Void) -> Void

    /// The container supplying the payload and close callback. Weak: the
    /// container owns the bridge (indirectly, via the web view config).
    weak var host: PopupWebView?

    /// The web view used to resolve JS callbacks. Weak for the same reason.
    weak var webView: WKWebView?

    /// Custom methods registered by the host, keyed by JS method name. Populated
    /// before `load(...)`; the injected per-name JS stubs mirror these keys.
    private(set) var handlers: [String: Handler] = [:]

    func register(_ method: String, handler: @escaping Handler) {
        handlers[method] = handler
    }

    /// A decoded, allowlisted bridge message. Constructed only from a
    /// well-formed body whose `method` is known — the single trust boundary.
    private struct Message {
        let method: String
        let args: Any?
        let callbackId: Int?
    }

    func userContentController(_ controller: WKUserContentController,
                               didReceive message: WKScriptMessage) {
        guard let msg = decode(message.body) else { return }

        switch msg.method {
        case TDBridgeMethod.getCampaignPayload:
            resolve(msg.callbackId, with: host?.campaignPayload ?? [:])
        case TDBridgeMethod.closeMessage:
            host?.onClose?()
        default:
            // Guaranteed to be a registered custom method (allowlist enforced in
            // `decode`). Hand the page's JSON-string arg to the app handler.
            guard let handler = handlers[msg.method] else { return }
            handler(msg.args as? String) { [weak self] result in
                self?.resolve(msg.callbackId, with: result)
            }
        }
    }

    /// Typed decode + allowlist. Returns nil (drop, no-op) for any message that
    /// is malformed OR names a method outside `{standard} ∪ {registered}`.
    /// This is *the* trust boundary from the design: never network, never eval
    /// for anything that doesn't pass here.
    private func decode(_ body: Any) -> Message? {
        guard let dict = body as? [String: Any] else {
            EngageLog.log("TDJSBridge: dropped non-object message: \(body)")
            return nil
        }
        guard let method = dict["method"] as? String else {
            EngageLog.log("TDJSBridge: dropped message with missing/invalid method")
            return nil
        }
        guard allowedMethods.contains(method) else {
            EngageLog.log("TDJSBridge: dropped unallowed method '\(method)'")
            return nil
        }
        // callbackId is optional: absent, or JS `null` (arrives as NSNull), both
        // mean fire-and-forget. A present non-null, non-integer value is a
        // malformed message.
        let callbackId: Int?
        let rawCallbackId = dict["callbackId"]
        if rawCallbackId == nil || rawCallbackId is NSNull {
            callbackId = nil
        } else if let id = rawCallbackId as? Int {
            callbackId = id
        } else {
            EngageLog.log("TDJSBridge: dropped message with non-integer callbackId")
            return nil
        }
        return Message(method: method, args: dict["args"], callbackId: callbackId)
    }

    /// The full allowlist: standard methods plus host-registered custom methods.
    private var allowedMethods: Set<String> {
        Set([TDBridgeMethod.getCampaignPayload, TDBridgeMethod.closeMessage])
            .union(handlers.keys)
    }

    // MARK: - Callback resolution

    /// Resolve a JS callback with `result`, or no-op when there is no callback
    /// (fire-and-forget). `result` is serialized to a JSON literal — never
    /// string-concatenated from raw values — to keep the eval injection-safe.
    func resolve(_ callbackId: Int?, with result: Any?) {
        guard let callbackId = callbackId else { return }
        guard let webView = webView else { return }

        let literal = TDJSBridge.jsonLiteral(from: result)
        let js = "window.__tdBridgeResolve(\(callbackId), \(literal));"
        webView.evaluateJavaScript(js) { _, error in
            if let error = error {
                EngageLog.log("TDJSBridge: resolve(\(callbackId)) failed: \(error)")
            }
        }
    }

    /// Serialize `value` to a JSON literal safe to embed in evaluateJavaScript.
    /// Falls back to `null` for nil or non-JSON values rather than injecting a
    /// broken/dangerous string.
    ///
    /// JSONSerialization on iOS 12 requires a top-level container (no
    /// `.fragmentsAllowed`), so the value is wrapped in a one-element array and
    /// the surrounding `[` `]` trimmed. Arrays serialize deterministically (no
    /// key-ordering or spacing surprises), unlike an object wrapper.
    static func jsonLiteral(from value: Any?) -> String {
        guard let value = value else { return "null" }
        let wrapped = [value]
        guard JSONSerialization.isValidJSONObject(wrapped),
              let data = try? JSONSerialization.data(withJSONObject: wrapped),
              let json = String(data: data, encoding: .utf8),
              json.hasPrefix("["), json.hasSuffix("]") else {
            EngageLog.log("TDJSBridge: value not JSON-serializable, resolving null")
            return "null"
        }
        return String(json.dropFirst().dropLast())
    }
}
#endif
