//
//  DeviceTests.swift
//  TreasureDataSDK
//
//  Created by Yuki Nagai on 4/23/16.
//  Copyright © 2016 Recruit Lifestyle Co., Ltd. All rights reserved.
//

import XCTest
@testable import TreasureDataSDK

final class DeviceTests: XCTestCase {
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    // MARK: deviceIdentifier
    func testNewDeviceIdentifier() {
        Device.Cached.deviceIdentifier = ""
        let stub = UIDeviceStub()
        Device.device = stub
        let identifier = Device().deviceIdentifier
        let expected = stub.identifierForVendor!.UUIDString
        XCTAssertEqual(identifier, expected)
    }
    func testCachedDeviceIdentifier() {
        let cached = "deviceIdentifier"
        Device.Cached.deviceIdentifier = cached
        let identifier = Device().deviceIdentifier
        XCTAssertEqual(identifier, cached)
    }
    
    // MARK: systemName
    func testSystemName() {
        Device.Cached.systemName = ""
        let stub = UIDeviceStub()
        Device.device = stub
        let systemName = Device().systemName
        XCTAssertEqual(systemName, stub.systemName)
    }
    func testCachedSystemName() {
        let cached = "cachedSystemName"
        Device.Cached.systemName = cached
        let systemName = Device().systemName
        XCTAssertEqual(systemName, cached)
    }
    
    // MARK: systemVersion
    func testSystemVersion() {
        Device.Cached.systemVersion = ""
        let stub = UIDeviceStub()
        Device.device = stub
        let systemVersion = Device().systemVersion
        XCTAssertEqual(systemVersion, stub.systemVersion)
    }
    func testCachedSystemVersion() {
        let cached = "cachedSystemVersion"
        Device.Cached.systemVersion = cached
        let systemVersion = Device().systemVersion
        XCTAssertEqual(systemVersion, cached)
    }
    
    // MARK: deviceModel
    func testDeviceModel() {
        Device.Cached.deviceModel = ""
        let stub = UIDeviceStub()
        Device.device = stub
        let deviceModel = Device().deviceModel
        XCTAssertEqual(deviceModel, stub.deviceModel)
    }
    func testCachedDeviceModel() {
        let cached = "cachedDeviceModel"
        Device.Cached.deviceModel = cached
        let deviceModel = Device().deviceModel
        XCTAssertEqual(deviceModel, cached)
    }
}
