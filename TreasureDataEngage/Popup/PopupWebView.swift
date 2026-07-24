//
//  PopupWebView.swift
//  TreasureDataEngage
//
//  A minimal WKWebView container that hosts the TDJSBridge: it injects
//  TDJSBridge.js at document start (driving the TDJSBridgeReady handshake) and
//  routes bridge messages to the native handler. The host decides presentation
//  (add as a subview, constrain, etc.).
//

#if canImport(WebKit)
import UIKit
import WebKit

public final class PopupWebView: UIView {

    /// The payload `getCampaignPayload` resolves with (caller-supplied). The
    /// bridge holds no API keys and makes no HTTP calls of its own.
    public var campaignPayload: [String: Any] = [:]

    /// Invoked when the page calls `TDJSBridge.closeMessage()`.
    public var onClose: (() -> Void)?

    private let webView: WKWebView
    private let bridge = TDJSBridge()
    private var didInjectStubs = false

    public override init(frame: CGRect) {
        webView = PopupWebView.makeWebView(bridge: bridge)
        super.init(frame: frame)
        connectBridge()
        addWebView()
    }

    public required init?(coder: NSCoder) {
        webView = PopupWebView.makeWebView(bridge: bridge)
        super.init(coder: coder)
        connectBridge()
        addWebView()
    }

    /// Give the bridge weak back-references to this container (payload, onClose)
    /// and the web view (callback resolution). Both are weak in `TDJSBridge`.
    private func connectBridge() {
        bridge.host = self
        bridge.webView = webView
    }

    // MARK: - Custom methods

    /// Register a custom bridge method the page can call as
    /// `TDJSBridge.<method>(json, cb)`. The handler runs natively (e.g. a secure
    /// write-back) and calls `done` to resolve the JS callback.
    ///
    /// Must be called BEFORE `load(...)`: the per-method JS stubs are frozen into
    /// the web view's user scripts at load time. Registering after load logs a
    /// warning and the page will have no stub for that name.
    public func register(_ method: String,
                         handler: @escaping (_ json: String?,
                                             _ done: @escaping (Any?) -> Void) -> Void) {
        if didInjectStubs {
            EngageLog.log("PopupWebView.register('\(method)') called after load(); no JS stub will exist for it")
        }
        bridge.register(method, handler: handler)
    }

    // MARK: - Loading

    public func load(html: String, baseURL: URL?) {
        injectStubsIfNeeded()
        webView.loadHTMLString(html, baseURL: baseURL)
    }

    public func load(url: URL) {
        injectStubsIfNeeded()
        webView.load(URLRequest(url: url))
    }

    /// Add one JS stub per registered custom method, once, at first load. Each
    /// stub forwards to the bridge's `__invoke`. Runs at document start so the
    /// stubs exist before page scripts (alongside the base TDJSBridge.js).
    private func injectStubsIfNeeded() {
        guard !didInjectStubs else { return }
        didInjectStubs = true

        let names = bridge.handlers.keys
        guard !names.isEmpty else { return }

        let stubs = names.map { name -> String in
            // name is a JSON string literal so an odd method name can't break out.
            let literal = TDJSBridge.jsonLiteral(from: name)
            return "TDJSBridge[\(literal)] = function (json, cb) { TDJSBridge.__invoke(\(literal), json, cb); };"
        }.joined(separator: "\n")

        let script = WKUserScript(source: stubs,
                                  injectionTime: .atDocumentStart,
                                  forMainFrameOnly: true)
        webView.configuration.userContentController.addUserScript(script)
    }

    // MARK: - Setup

    private func addWebView() {
        webView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(webView)
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: topAnchor),
            webView.bottomAnchor.constraint(equalTo: bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
    }

    private static func makeWebView(bridge: TDJSBridge) -> WKWebView {
        let controller = WKUserContentController()

        // Inject the bridge JS before any page script runs. A weak forwarder
        // avoids the WKUserContentController → handler retain cycle.
        if let script = loadBridgeUserScript() {
            controller.addUserScript(script)
        }
        controller.add(WeakScriptMessageHandler(bridge), name: tdBridgeMessageName)

        let config = WKWebViewConfiguration()
        config.userContentController = controller
        return WKWebView(frame: .zero, configuration: config)
    }

    /// Load TDJSBridge.js from the resource bundle as a document-start user script.
    private static func loadBridgeUserScript() -> WKUserScript? {
        guard let url = EngageResources.url(forResource: "TDJSBridge", withExtension: "js"),
              let source = try? String(contentsOf: url, encoding: .utf8) else {
            EngageLog.log("TDJSBridge.js not found in resource bundle")
            return nil
        }
        return WKUserScript(source: source,
                            injectionTime: .atDocumentStart,
                            forMainFrameOnly: true)
    }
}

/// Locates Engage's bundled resources across build systems. SwiftPM generates
/// `Bundle.module`; CocoaPods puts resources in a bundle named for the pod,
/// nested inside the framework. Try both.
enum EngageResources {
    static func url(forResource name: String, withExtension ext: String) -> URL? {
        for bundle in candidateBundles {
            if let url = bundle.url(forResource: name, withExtension: ext) {
                return url
            }
        }
        return nil
    }

    private static var candidateBundles: [Bundle] {
        var bundles: [Bundle] = []
        #if SWIFT_PACKAGE
        // SwiftPM: the generated per-module resource bundle.
        bundles.append(Bundle.module)
        #endif
        // The framework bundle Engage's code lives in (CocoaPods dynamic
        // framework, or a static-lib main bundle).
        let hostBundle = Bundle(for: BundleToken.self)
        bundles.append(hostBundle)
        // CocoaPods resource bundle nested inside the framework, named for the
        // pod's module ("TreasureData"). Present when resources ship as a bundle.
        if let nested = hostBundle.url(forResource: "TreasureData", withExtension: "bundle"),
           let bundle = Bundle(url: nested) {
            bundles.append(bundle)
        }
        return bundles
    }
}

private final class BundleToken {}
#endif
