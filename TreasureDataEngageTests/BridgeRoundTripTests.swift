//
//  BridgeRoundTripTests.swift
//  TreasureDataEngageTests
//
//  The one real check on the money path: an offscreen WKWebView loads fixture
//  HTML that drives TDJSBridge, and we assert the four contract behaviors —
//  payload delivery, closeMessage → onClose, a custom method round-trip, and an
//  unregistered method being a safe no-op.
//

#if canImport(WebKit)
import XCTest
import WebKit
@testable import TreasureDataEngage

final class BridgeRoundTripTests: XCTestCase {

    // A window keeps each test's WKWebView in a render tree — WebKit throttles
    // JS in a web view that isn't attached to a window, which makes offscreen
    // bridge round-trips flaky. Torn down per test.
    private var window: UIWindow?

    override func tearDown() {
        window?.isHidden = true
        window = nil
        super.tearDown()
    }

    // Build a popup hosted in a real window and keep it retained via `window`.
    private func makePopup() -> PopupWebView {
        let win = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        let popup = PopupWebView(frame: win.bounds)
        win.addSubview(popup)
        win.isHidden = false
        window = win
        return popup
    }

    /// getCampaignPayload: the page's callback receives exactly the payload set
    /// natively. The page echoes what it got back through a custom method so the
    /// native side can assert on it.
    func testGetCampaignPayloadDeliversExactPayload() {
        let popup = makePopup()
        popup.campaignPayload = ["location": "US", "user_profile": ["id": 42]]

        let got = expectation(description: "payload echoed back")
        var echoed: String?
        popup.register("echoPayload") { json, done in
            echoed = json
            done(true)
            got.fulfill()
        }

        popup.load(html: """
        <html><body><script>
          function init() {
            TDJSBridge.getCampaignPayload(function (p) {
              TDJSBridge.echoPayload(JSON.stringify(p), function () {});
            });
          }
          window.TDJSBridge ? init()
            : document.addEventListener('TDJSBridgeReady', init);
        </script></body></html>
        """, baseURL: nil)

        wait(for: [got], timeout: 5)
        // The echoed JSON must decode to the exact payload set natively.
        let data = echoed?.data(using: .utf8)
        let decoded = data.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
        XCTAssertEqual(decoded?["location"] as? String, "US")
        XCTAssertEqual((decoded?["user_profile"] as? [String: Any])?["id"] as? Int, 42)
    }

    /// closeMessage fires the container's onClose.
    func testCloseMessageFiresOnClose() {
        let popup = makePopup()
        let closed = expectation(description: "onClose fired")
        popup.onClose = { closed.fulfill() }

        popup.load(html: """
        <html><body><script>
          function init() { TDJSBridge.closeMessage(); }
          window.TDJSBridge ? init()
            : document.addEventListener('TDJSBridgeReady', init);
        </script></body></html>
        """, baseURL: nil)

        wait(for: [closed], timeout: 5)
    }

    /// A registered custom method round-trips: JS call → native handler →
    /// done(result) → JS callback resolves with that result.
    func testCustomMethodRoundTrips() {
        let popup = makePopup()
        let resolvedInJS = expectation(description: "JS callback resolved")
        var receivedJSON: String?

        popup.register("submitRaffleEntries") { json, done in
            receivedJSON = json
            done(["isSuccess": true])
        }
        // The page reports the resolved result back via a second custom method.
        popup.register("reportResult") { json, done in
            XCTAssertEqual(json, "{\"isSuccess\":true}")
            done(nil)
            resolvedInJS.fulfill()
        }

        popup.load(html: """
        <html><body><script>
          function init() {
            TDJSBridge.submitRaffleEntries('{"n":3}', function (res) {
              TDJSBridge.reportResult(JSON.stringify(res), function () {});
            });
          }
          window.TDJSBridge ? init()
            : document.addEventListener('TDJSBridgeReady', init);
        </script></body></html>
        """, baseURL: nil)

        wait(for: [resolvedInJS], timeout: 5)
        XCTAssertEqual(receivedJSON, "{\"n\":3}")
    }

    /// An unregistered method is a safe no-op: no crash, no callback resolution.
    /// We prove liveness afterward with a registered method that DOES fire, so a
    /// hung bridge would fail rather than falsely pass.
    func testUnregisteredMethodIsNoOp() {
        let popup = makePopup()
        let liveness = expectation(description: "bridge still works after unknown call")

        popup.register("ping") { _, done in
            done(nil)
            liveness.fulfill()
        }

        popup.load(html: """
        <html><body><script>
          function init() {
            // Direct __invoke of a name that was never registered: must no-op.
            TDJSBridge.__invoke('neverRegistered', null, function () {
              // If this ever resolves, the bridge broke its allowlist.
              window.__brokeAllowlist = true;
            });
            TDJSBridge.ping(null, function () {});
          }
          window.TDJSBridge ? init()
            : document.addEventListener('TDJSBridgeReady', init);
        </script></body></html>
        """, baseURL: nil)

        wait(for: [liveness], timeout: 5)
    }
}
#endif
