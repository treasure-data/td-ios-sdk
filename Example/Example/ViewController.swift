//
//  ViewController.swift
//  Example
//
//  Created by Yuki Nagai on 4/24/16.
//  Copyright © 2016 Recruit Lifestyle Co., Ltd. All rights reserved.
//

import UIKit
import TreasureDataSDK
import SnapKit

final class ViewController: UIViewController {
    private let addEventButton     = UIButton(type: .System)
    private let uploadEventsButton = UIButton(type: .System)
    private let startSessionButton = UIButton(type: .System)
    private let endSessionButton   = UIButton(type: .System)
    
    init() {
        super.init(nibName: nil, bundle: nil)
        let configuration = Configuration(
            debug: true,
            key: "your_api_key",
            database: "testdb",
            table: "demotbl",
            shouldAppendDeviceIdentifier: true,
            shouldAppendModelInformation: true,
            shouldAppendSeverSideTimestamp: true)
        TreasureData.configure(configuration)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.backgroundColor = UIColor.whiteColor()
        
        self.view.addSubview(self.addEventButton)
        self.view.addSubview(self.uploadEventsButton)
        self.view.addSubview(self.startSessionButton)
        self.view.addSubview(self.endSessionButton)
        
        self.addEventButton.snp_makeConstraints { make in
            make.top.equalTo(self.view)
            make.leading.equalTo(self.view)
            make.height.equalTo(self.view).multipliedBy(0.5)
            make.width.equalTo(self.view).multipliedBy(0.5)
        }
        self.uploadEventsButton.snp_makeConstraints { make in
            make.top.equalTo(self.view)
            make.trailing.equalTo(self.view)
            make.height.equalTo(self.view).multipliedBy(0.5)
            make.width.equalTo(self.view).multipliedBy(0.5)
        }
        self.startSessionButton.snp_makeConstraints { make in
            make.bottom.equalTo(self.view)
            make.leading.equalTo(self.view)
            make.height.equalTo(self.view).multipliedBy(0.5)
            make.width.equalTo(self.view).multipliedBy(0.5)
        }
        self.endSessionButton.snp_makeConstraints { make in
            make.bottom.equalTo(self.view)
            make.trailing.equalTo(self.view)
            make.height.equalTo(self.view).multipliedBy(0.5)
            make.width.equalTo(self.view).multipliedBy(0.5)
        }
        
        self.addEventButton.setTitle("Add Event", forState: .Normal)
        self.uploadEventsButton.setTitle("Upload Event", forState: .Normal)
        self.startSessionButton.setTitle("Star Session", forState: .Normal)
        self.endSessionButton.setTitle("End Session", forState: .Normal)
        
        self.addEventButton.addTarget(self, action: #selector(addEvent(_:)), forControlEvents: .TouchUpInside)
        self.uploadEventsButton.addTarget(self, action: #selector(uploadEvents(_:)), forControlEvents: .TouchUpInside)
        self.startSessionButton.addTarget(self, action: #selector(startSession(_:)), forControlEvents: .TouchUpInside)
        self.endSessionButton.addTarget(self, action: #selector(endSession(_:)), forControlEvents: .TouchUpInside)
    }
    
    func addEvent(_: UIButton) {
        let userInfo: [String: String] = [
            "name": "uny",
            "age": "27",
            ]
        TreasureData.addEvent(userInfo: userInfo)
    }
    
    func uploadEvents(_: UIButton) {
        TreasureData.uploadEvents { result in
            print(result)
        }
    }
    
    func startSession(_: UIButton) {
        TreasureData.startSession()
    }
    
    func endSession(_: UIButton) {
        TreasureData.endSession()
    }
}

