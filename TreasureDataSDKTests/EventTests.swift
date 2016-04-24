//
//  EventTests.swift
//  TreasureDataSDK
//
//  Created by Yuki Nagai on 4/23/16.
//  Copyright © 2016 Recruit Lifestyle Co., Ltd. All rights reserved.
//

import XCTest
@testable import TreasureDataSDK

final class EventTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testThatItAppendsInformation() {
        let configuration = Configuration(
            key:      "KEY",
            database: "DATABASE",
            table:    "TABLE",
            shouldAppendDeviceIdentifier: true,
            shouldAppendModelInformation: true,
            shouldAppendSeverSideTimestamp: true)
        let instance = TreasureData(configuration: configuration)
        instance.startSession()
        let event = Event().appendInformation(instance)
        XCTAssertEqual(event.database, configuration.database)
        XCTAssertEqual(event.table, configuration.table)
        XCTAssertFalse(event.deviceIdentifier.isEmpty)
        XCTAssertFalse(event.systemName.isEmpty)
        XCTAssertFalse(event.systemVersion.isEmpty)
        XCTAssertFalse(event.deviceModel.isEmpty)
        XCTAssertFalse(event.sessionIdentifier.isEmpty)
    }
    
    func testThatItDoesNotAppendDeviceIdentifier() {
        let configuration = Configuration(
            key:      "KEY",
            database: "DATABASE",
            table:    "TABLE")
        let instance = TreasureData(configuration: configuration)
        let event = Event().appendInformation(instance)
        XCTAssertTrue(event.deviceIdentifier.isEmpty)
    }
    
    func testThatItDoesNotAppendModelInformation() {
        let configuration = Configuration(
            key:      "KEY",
            database: "DATABASE",
            table:    "TABLE")
        let instance = TreasureData(configuration: configuration)
        let event = Event().appendInformation(instance)
        XCTAssertTrue(event.systemName.isEmpty)
        XCTAssertTrue(event.systemVersion.isEmpty)
        XCTAssertTrue(event.deviceModel.isEmpty)
    }
}
