//
//  LandingPageView.swift
//  TreasureDataEngage
//
//  A WKWebView container that hosts the TDBridge and loads a campaign / landing
//  page. It injects TDBridge.js and a `window.TDContext` object at document
//  start (before page scripts), and routes bridge messages to the app via a
//  `TDBridgeDelegate`. The host decides presentation (add as a subview, present
//  a full-screen transparent overlay, etc.).
//

#if canImport(WebKit)
import UIKit
import WebKit

public final class LandingPageView: UIView {

    /// Data injected into the page as `window.TDContext` at load time (push).
    /// Determined natively before display (e.g. nickname). Set before `load(...)`.
    public var context: [String: Any] = [:]

    /// App integration point for `invoke` / `openUrl` / `track`.
    public weak var delegate: TDBridgeDelegate? {
        didSet { bridge.delegate = delegate }
    }

    /// Invoked when the page calls `TDBridge.close()`. The host removes /
    /// dismisses this view.
    public var onClose: (() -> Void)?

    private let webView: WKWebView
    private let bridge = TDBridge()
    private var didInjectContext = false

    public override init(frame: CGRect) {
        webView = LandingPageView.makeWebView(bridge: bridge)
        super.init(frame: frame)
        connectBridge()
        addWebView()
    }

    public required init?(coder: NSCoder) {
        webView = LandingPageView.makeWebView(bridge: bridge)
        super.init(coder: coder)
        connectBridge()
        addWebView()
    }

    private func connectBridge() {
        bridge.host = self
        bridge.delegate = delegate
    }

    // MARK: - Loading

    public func load(html: String, baseURL: URL?) {
        injectContextIfNeeded()
        webView.loadHTMLString(html, baseURL: baseURL)
    }

    public func load(url: URL) {
        injectContextIfNeeded()
        webView.load(URLRequest(url: url))
    }

    /// Inject `window.TDContext = <json>` once, at first load, before page
    /// scripts run. Uses the injection-safe JSON literal serializer.
    private func injectContextIfNeeded() {
        guard !didInjectContext else { return }
        didInjectContext = true
        guard !context.isEmpty else { return }

        let literal = TDBridge.jsonLiteral(from: context)
        let source = "window.TDContext = \(literal);"
        let script = WKUserScript(source: source,
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

    private static func makeWebView(bridge: TDBridge) -> WKWebView {
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

    /// Load TDBridge.js from the resource bundle as a document-start user script.
    private static func loadBridgeUserScript() -> WKUserScript? {
        guard let url = EngageResources.url(forResource: "TDBridge", withExtension: "js"),
              let source = try? String(contentsOf: url, encoding: .utf8) else {
            EngageLog.log("TDBridge.js not found in resource bundle")
            return nil
        }
        return WKUserScript(source: source,
                            injectionTime: .atDocumentStart,
                            forMainFrameOnly: true)
    }
}

/// Locates Engage's bundled resources across build systems. SwiftPM generates
/// `Bundle.module`; CocoaPods puts resources in the framework bundle (and, when
/// resources ship as a bundle, a nested bundle named for the pod). Try each.
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
        bundles.append(Bundle.module)
        #endif
        let hostBundle = Bundle(for: BundleToken.self)
        bundles.append(hostBundle)
        if let nested = hostBundle.url(forResource: "TreasureDataEngage", withExtension: "bundle"),
           let bundle = Bundle(url: nested) {
            bundles.append(bundle)
        }
        return bundles
    }
}

private final class BundleToken {}
#endif
