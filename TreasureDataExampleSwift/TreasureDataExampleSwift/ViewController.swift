//
//  ViewController.swift
//  TreasureDataExampleSwift
//
//  Created by Mitsunori Komatsu on 1/2/16.
//  Copyright © 2016 Treasure Data. All rights reserved.
//

import UIKit
import TreasureData
#if canImport(TreasureDataEngage)
import TreasureDataEngage
#endif

class ViewController: UIViewController {

    #if canImport(TreasureDataEngage)
    private var popup: LandingPageView?
    #endif

    override func viewDidLoad() {
        super.viewDidLoad()
        addBridgeSmokeTestButton()
    }

    // MARK: - TDBridge smoke test
    //
    // A manual check that LandingPageView + TDBridge work end-to-end in a real
    // app: tapping the button presents a campaign WebView whose page reads
    // window.TDContext, sends a track event, invokes a custom method (routed to
    // this delegate), and closes itself.

    private func addBridgeSmokeTestButton() {
        let button = UIButton(type: .system)
        button.setTitle("Show Campaign Popup", for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(button)
        NSLayoutConstraint.activate([
            button.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            button.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -24),
        ])
        button.addTarget(self, action: #selector(showCampaignPopup), for: .touchUpInside)
    }

    @objc private func showCampaignPopup() {
        #if canImport(TreasureDataEngage)
        let lp = LandingPageView(frame: view.bounds)
        lp.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        // Data pushed to the page as window.TDContext.
        lp.context = ["nickname": "Alex", "tier": "gold"]
        lp.delegate = self
        lp.onClose = { [weak self] in
            self?.popup?.removeFromSuperview()
            self?.popup = nil
            print("[smoke] LP closed")
        }
        lp.load(html: Self.sampleCampaignHTML, baseURL: nil)
        view.addSubview(lp)
        self.popup = lp
        #else
        print("[smoke] TreasureDataEngage not linked; add the Engage pod")
        #endif
    }

    private static let sampleCampaignHTML = """
    <html><head><meta name="viewport" content="width=device-width, initial-scale=1"></head>
    <body style="font-family: -apple-system; padding: 24px;">
      <h2>Campaign</h2>
      <pre id="ctx">loading…</pre>
      <button onclick="TDBridge.invoke('grantPoints', {amount: 100})">Enter Raffle</button>
      <button onclick="TDBridge.close()">Close</button>
      <script>
        function init() {
          document.getElementById('ctx').textContent =
            JSON.stringify(window.TDContext, null, 2);
          TDBridge.track('lp_view', { screen: 'raffle' });
        }
        window.TDBridge ? init()
          : document.addEventListener('TDBridgeReady', init);
      </script>
    </body></html>
    """

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @IBOutlet weak var addEvent: UIButton!
    
    @IBOutlet weak var uploadEvents: UIButton!

    @IBAction func touchDownAddEvent(sender: AnyObject) {
        TreasureData.sharedInstance().addEventWithCallback(
            ["name": "komamitsu", "age": 99],
            database: "testdb",
            table: "demotbl",
            onSuccess:{()-> Void in
                print("addEvent: success")
            },
            onError:{(errorCode, message) -> Void in
                print("addEvent: error. errorCode=%@, message=%@", errorCode, message ?? "")
            }
        )
    }

    @IBAction func touchDownUploadEvents(sender: AnyObject) {
        TreasureData.sharedInstance().uploadEventsWithCallback({
                print("uploadEvents: success")
            },
            onError: {(errorCode, message) -> Void in
                print("uploadEvents: error. errorCode=%@, message=%@", errorCode, message ?? "")
            })
    }
    
    @IBAction func fetchUserSegments(sender: AnyObject) {
        let audienceTokens = ["Your Profile API (Audience) Token here"]
        let keys = ["your_key": "your_value",]
//        let options: [TDRequestOptionsKey : Any] = [.timeoutInterval: 10, .cachePolicy: 10];
        let options: [String : Any] = ["TDRequestOptionsTimeoutIntervalKey": 10, "TDRequestOptionsCachePolicyKey": 10];
        TreasureData.sharedInstance().fetchUserSegments(tokens: audienceTokens, keys: keys, options: options) { response, error in
            print("Response: \(String(describing: response))");
            print("Error: \(String(describing: error))");
        }
    }
}

#if canImport(TreasureDataEngage)
extension ViewController: TDBridgeDelegate {
    func handleTDBridgeInvoke(name: String, params: [String: Any]) {
        // The app dispatches by name and performs business logic / authorization.
        print("[smoke] invoke: \(name) \(params)")
    }

    func handleTDBridgeOpenURL(_ url: URL) {
        print("[smoke] openUrl: \(url)")
    }

    func handleTDBridgeTrack(event: String, values: [String: Any]) {
        // Route LP measurement into the SDK's ingest.
        print("[smoke] track: \(event) \(values)")
    }
}
#endif

