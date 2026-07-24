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
    private var popup: PopupWebView?
    #endif

    override func viewDidLoad() {
        super.viewDidLoad()
        addBridgeSmokeTestButton()
    }

    // MARK: - TDJSBridge smoke test
    //
    // A manual check that PopupWebView + TDJSBridge work end-to-end in a real
    // app: tapping the button presents a campaign WebView whose page reads the
    // native payload, invokes a registered custom method, and closes itself.

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
        let popup = PopupWebView(frame: view.bounds)
        popup.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        popup.campaignPayload = [
            "location": "US",
            "user_profile": ["id": 42, "tier": "gold"],
        ]
        popup.onClose = { [weak self] in
            self?.popup?.removeFromSuperview()
            self?.popup = nil
            print("[smoke] campaign popup closed")
        }
        popup.register("submitRaffleEntries") { json, done in
            print("[smoke] submitRaffleEntries received: \(json ?? "nil")")
            done(["isSuccess": true])
        }
        popup.load(html: Self.sampleCampaignHTML, baseURL: nil)
        view.addSubview(popup)
        self.popup = popup
        #else
        print("[smoke] TreasureDataEngage not linked; add the Engage subspec")
        #endif
    }

    private static let sampleCampaignHTML = """
    <html><head><meta name="viewport" content="width=device-width, initial-scale=1"></head>
    <body style="font-family: -apple-system; padding: 24px;">
      <h2>Campaign</h2>
      <pre id="payload">loading…</pre>
      <button onclick="submit()">Enter Raffle</button>
      <button onclick="TDJSBridge.closeMessage()">Close</button>
      <script>
        function init() {
          TDJSBridge.getCampaignPayload(function (p) {
            document.getElementById('payload').textContent = JSON.stringify(p, null, 2);
          });
        }
        function submit() {
          TDJSBridge.submitRaffleEntries('{"entries":3}', function (res) {
            alert('result: ' + JSON.stringify(res));
          });
        }
        window.TDJSBridge ? init()
          : document.addEventListener('TDJSBridgeReady', init);
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

