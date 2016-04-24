//
//  ConfigurationTests.swift
//  TreasureDataSDK
//
//  Created by Yuki Nagai on 4/4/16.
//  Copyright © 2016 Recruit Lifestyle Co., Ltd. All rights reserved.
//

import XCTest
@testable import TreasureDataSDK

final class ConfigurationTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }

    func testThatItConfiguresDefaultRealmFileURL() {
        let configuration = Configuration(key: "KEY", database: "DATABASE", table: "TABLE")
        XCTAssertEqual(configuration.fileURL, Configuration.defaultFileURL())
        XCTAssertNil(configuration.inMemoryIdentifier)
    }
    
    func testThatItConfiguresRealmFileURL() {
        let defaultFileURL = Configuration.defaultFileURL()
        let renamedURL = defaultFileURL.URLByDeletingLastPathComponent?.URLByAppendingPathComponent("Renamed.realm")
        let configuration = Configuration(key: "KEY", database: "DATABASE", table: "TABLE", fileURL: renamedURL)
        XCTAssertEqual(configuration.fileURL, renamedURL)
        XCTAssertNil(configuration.inMemoryIdentifier)
    }
    
    func testThatItConfiguresRealmInMemoryIdentifier() {
        let inMemoryIdentifier = "inMemoryIdentifier"
        let configuration = Configuration(key: "KEY", database: "DATABASE", table: "TABLE", inMemoryIdentifier: inMemoryIdentifier)
        XCTAssertNil(configuration.fileURL)
        XCTAssertEqual(configuration.inMemoryIdentifier, inMemoryIdentifier)
    }
    
    func testThatItRealmFileURLIsPriorToInMemoryIdentifier() {
        let fileURL = Configuration.defaultFileURL()
        let configuration = Configuration(key: "KEY", database: "DATABASE", table: "TABLE", fileURL: fileURL, inMemoryIdentifier: "inMemoryIdentifier")
        XCTAssertEqual(configuration.fileURL, fileURL)
        XCTAssertNil(configuration.inMemoryIdentifier)
    }
    
    func testThatItReturnsSchemaName() {
        let configuration = Configuration(key: "KEY", database: "DATABASE", table: "TABLE")
        XCTAssertEqual(configuration.schemaName, "\(configuration.database).\(configuration.table)")
    }
}
