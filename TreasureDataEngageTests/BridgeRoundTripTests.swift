//
//  BridgeRoundTripTests.swift
//  TreasureDataEngageTests
//
//  Money-path checks for the TDBridge driven through a real
//  offscreen WKWebView: close → onClose, track/invoke/openUrl →
//  delegate, TDContext injection, and the invoke-before-close ordering the PoC
//  requires.
//

#if canImport(WebKit)
import XCTest
import WebKit
@testable import TreasureDataEngage

/// Records delegate callbacks and fulfills expectations on demand.
private final class SpyDelegate: TDBridgeDelegate {
    var onInvoke: ((String, [String: Any]) -> Void)?
    var onOpenURL: ((URL) -> Void)?
    var onTrack: ((String, [String: Any]) -> Void)?

    func handleTDBridgeInvoke(name: String, params: [String: Any]) { onInvoke?(name, params) }
    func handleTDBridgeOpenURL(_ url: URL) { onOpenURL?(url) }
    func handleTDBridgeTrack(event: String, values: [String: Any]) { onTrack?(event, values) }
}

final class BridgeRoundTripTests: XCTestCase {

    // A window keeps the WKWebView in a render tree; WebKit throttles JS in a
    // web view not attached to a window, which makes offscreen calls flaky.
    private var window: UIWindow?
    private var delegate: SpyDelegate!

    override func setUp() {
        super.setUp()
        delegate = SpyDelegate()
    }

    override func tearDown() {
        window?.isHidden = true
        window = nil
        delegate = nil
        super.tearDown()
    }

    private func makeLP() -> LandingPageView {
        let win = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        let lp = LandingPageView(frame: win.bounds)
        lp.delegate = delegate
        win.addSubview(lp)
        win.isHidden = false
        window = win
        return lp
    }

    private func html(callingBridgeOnReady body: String) -> String {
        """
        <html><body><script>
          function init() { \(body) }
          window.TDBridge ? init()
            : document.addEventListener('TDBridgeReady', init);
        </script></body></html>
        """
    }

    /// close() fires onClose.
    func testCloseFiresOnClose() {
        let lp = makeLP()
        let closed = expectation(description: "onClose fired")
        lp.onClose = { closed.fulfill() }
        lp.load(html: html(callingBridgeOnReady: "TDBridge.close();"), baseURL: nil)
        wait(for: [closed], timeout: 5)
    }

    /// invoke(name, params) reaches the delegate with name + params intact.
    func testInvokeReachesDelegate() {
        let lp = makeLP()
        let got = expectation(description: "invoke delegated")
        delegate.onInvoke = { name, params in
            XCTAssertEqual(name, "grantPoints")
            XCTAssertEqual(params["amount"] as? Int, 100)
            got.fulfill()
        }
        lp.load(html: html(callingBridgeOnReady: "TDBridge.invoke('grantPoints', {amount: 100});"), baseURL: nil)
        wait(for: [got], timeout: 5)
    }

    /// track(event, values) reaches the delegate with structured values.
    func testTrackReachesDelegate() {
        let lp = makeLP()
        let got = expectation(description: "track delegated")
        delegate.onTrack = { event, values in
            XCTAssertEqual(event, "lp_view")
            XCTAssertEqual(values["screen"] as? String, "lottery")
            got.fulfill()
        }
        lp.load(html: html(callingBridgeOnReady: "TDBridge.track('lp_view', {screen: 'lottery'});"), baseURL: nil)
        wait(for: [got], timeout: 5)
    }

    /// openUrl(url) reaches the delegate as a parsed URL.
    func testOpenURLReachesDelegate() {
        let lp = makeLP()
        let got = expectation(description: "openUrl delegated")
        delegate.onOpenURL = { url in
            XCTAssertEqual(url.absoluteString, "myapp://coupon/42")
            got.fulfill()
        }
        lp.load(html: html(callingBridgeOnReady: "TDBridge.openUrl('myapp://coupon/42');"), baseURL: nil)
        wait(for: [got], timeout: 5)
    }

    /// window.TDContext is injected and readable by the page. The page reports
    /// it back via track so the native side can assert.
    func testContextInjected() {
        let lp = makeLP()
        lp.context = ["nickname": "Alex", "tier": 3]
        let got = expectation(description: "context echoed via track")
        delegate.onTrack = { event, values in
            XCTAssertEqual(event, "ctx")
            XCTAssertEqual(values["nickname"] as? String, "Alex")
            XCTAssertEqual(values["tier"] as? Int, 3)
            got.fulfill()
        }
        lp.load(html: html(callingBridgeOnReady: "TDBridge.track('ctx', window.TDContext);"), baseURL: nil)
        wait(for: [got], timeout: 5)
    }

    /// The PoC requires invoke to be delivered BEFORE close destroys the view.
    /// Fire both in one tick and assert invoke landed before onClose.
    func testInvokeDeliveredBeforeClose() {
        let lp = makeLP()
        var invokeSeen = false
        let invoked = expectation(description: "invoke")
        let closed = expectation(description: "close")
        delegate.onInvoke = { _, _ in invokeSeen = true; invoked.fulfill() }
        lp.onClose = {
            XCTAssertTrue(invokeSeen, "close arrived before invoke — ordering violated")
            closed.fulfill()
        }
        lp.load(html: html(callingBridgeOnReady:
            "TDBridge.invoke('grantPoints', {amount: 1}); TDBridge.close();"), baseURL: nil)
        wait(for: [invoked, closed], timeout: 5)
    }
}
#endif
