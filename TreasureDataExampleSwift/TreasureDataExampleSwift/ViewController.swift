//
//  ViewController.swift
//  TreasureDataExampleSwift
//
//  Created by Mitsunori Komatsu on 1/2/16.
//  Copyright © 2016 Treasure Data. All rights reserved.
//

import UIKit
import TreasureData_iOS_SDK

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @IBOutlet weak var addEvent: UIButton!
    
    @IBOutlet weak var uploadEvents: UIButton!

    @IBAction func touchDownAddEvent(sender: AnyObject) {
        TreasureData.sharedInstance().addEvent(
            withCallback: ["name": "komamitsu", "age": 99],
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
        TreasureData.sharedInstance().uploadEvents(callback: {
                print("uploadEvents: success")
            },
            onError: {(errorCode, message) -> Void in
                print("uploadEvents: error. errorCode=%@, message=%@", errorCode, message ?? "")
            })
    }
    
    @IBAction func fetchUserSegments(sender: AnyObject) {
        let audienceTokens = ["Your Profile API (Audience) Token here"]
        let keys = ["your_key": "your_value",]
        let options: [TDRequestOptionsKey : Any] = [.timeoutInterval: 10, .cachePolicy: 10];
        TreasureData.sharedInstance().fetchUserSegments(audienceTokens, keys: keys, options: options) { response, error in
            print("Response: \(String(describing: response))");
            print("Error: \(String(describing: error))");
        }
    }
}

