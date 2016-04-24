//
//  UIDevice+DeviceModelTests.swift
//  TreasureDataSDK
//
//  Created by Yuki Nagai on 4/23/16.
//  Copyright © 2016 Recruit Lifestyle Co., Ltd. All rights reserved.
//

import XCTest
@testable import TreasureDataSDK

final class UIDevice_DeviceModelTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }

    func testThatItReturnsActualDeviceModel() {
        let device = UIDevice()
        let isSimulator = ["i386", "x86_64"].contains(device.deviceModel)
        XCTAssertTrue(isSimulator)
    }
}
