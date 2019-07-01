//
//  TreasureDataSwiftTests.swift
//  TreasureDataTests
//
//  Created by Huy TD on 1/27/19.
//  Copyright © 2019 Huy TD. All rights reserved.
//

import XCTest

class IntegrationTests: XCTestCase {

    var sdkClient: TreasureData!
    static var api: TDAPI!
    static var apiKey: String!
    static var collectorEndpoint: String!

    static let TargetDatabase = "ios_it"
    static var sessionPrefix = uuid()
    static var audienceTokens:[String] = []
    static var userSegmentKeys:[String:String] = [:]

    /** Tables used in a single test */
    var tempTables: [String] = []

    override class func setUp() {
        guard let apiKey = ProcessInfo.processInfo.environment["API_MASTER_KEY"] else {
            fatalError("Missing env API_MASTER_KEY")
        }
        guard let apiEndpoint = ProcessInfo.processInfo.environment["API_ENDPOINT"] else {
            fatalError("Missing env API_ENDPOINT")
        }
        guard let collectorEndpoint = ProcessInfo.processInfo.environment["COLLECTOR_ENDPOINT"] else {
            fatalError("Missing env COLLECTOR_ENDPOINT")
        }
        // Syntax: AUDIENCE_TOKENS=token1,token2
        guard let audienceTokensString = ProcessInfo.processInfo.environment["AUDIENCE_TOKENS"] else {
            fatalError("Missing env AUDIENCE_TOKENS")
        }
        // Syntax: USER_SEGMENT_KEYS=key1:value1,key2:value2
        guard let userSegmentKeysString = ProcessInfo.processInfo.environment["USER_SEGMENT_KEYS"] else {
            fatalError("Missing env USER_SEGMENT_KEYS")
        }
        
        IntegrationTests.apiKey = apiKey
        IntegrationTests.collectorEndpoint = collectorEndpoint
        IntegrationTests.audienceTokens = audienceTokensString.split(separator: ",").map { String($0) }
        let keyValueStrings = userSegmentKeysString.split(separator: ",").map { String($0) }
        keyValueStrings.forEach { keyValueString in
            let keyAndValue = keyValueString.split(separator: ":")
            IntegrationTests.userSegmentKeys[String(keyAndValue[0])] = String(keyAndValue[1])
        }

        api = TDAPI.init(endpoint: apiEndpoint, apiKey: apiKey)
        if (!(try! api.isDatabaseExist(TargetDatabase))) {
            fatalError("Either the apiKey is invalid or the target database \(TargetDatabase) is not exist!")
        }
    }

    override class func tearDown() {
        IntegrationTests.api = nil
    }

    override func setUp() {
        TreasureData.initializeApiEndpoint(IntegrationTests.collectorEndpoint)
        sdkClient = TreasureData(apiKey: IntegrationTests.apiKey)
        sdkClient.defaultDatabase = IntegrationTests.TargetDatabase
        tempTables = []
    }

    override func tearDown() {
        let remoteTables = Set<String>(IntegrationTests.api.listTables(database: IntegrationTests.TargetDatabase))
        for sessionTable in tempTables {
            if remoteTables.contains(sessionTable) {
                try! IntegrationTests.api.deleteTable(database: IntegrationTests.TargetDatabase, table: sessionTable)
            } else {
                print("WARN: Skip deleting table '\(IntegrationTests.TargetDatabase).\(sessionTable)' as it is not exist!")
            }
        }
        sdkClient.disableAppLifecycleEvent()
        sdkClient = nil
    }

    func testCustomEvent() {
        sdkClient.enableCustomEvent()
        let table = newTempTable()
        let event = sdkClient.addEvent(["message": "Guten Morgen!"], table: table)
        sdkClient.uploadEvents()
        if event != nil {
            let result = try! IntegrationTests.api.stubbornQuery("select message from \(table) limit 1", database: IntegrationTests.TargetDatabase)
            XCTAssert(result[0][0] as! String == "Guten Morgen!")
        } else {
            XCTFail("Could not create event!")
        }
        
    }

    func testLifeCycleAppOpenedEvent() {
        sdkClient.enableAppLifecycleEvent()
        sdkClient.defaultTable = newTempTable()
        NotificationCenter.default.post(name: Notification.Name("UIApplicationDidFinishLaunchingNotification"), object: nil)
        sdkClient.uploadEvents()
        let result = try! IntegrationTests.api.stubbornQuery(
            "select td_ios_event, td_app_ver, td_app_ver_num from \(sdkClient.defaultTable!) limit 1",
            database: IntegrationTests.TargetDatabase)
        XCTAssertEqual(result[0][0] as! String, "TD_IOS_APP_OPEN")
        XCTAssertNotNil(result[0][1])
        XCTAssertNotNil(result[0][2])
    }

    func testSession() {
        let sessionTable = newTempTable()
        let eventTable = newTempTable()

        sdkClient.startSession(sessionTable)
        let sessionId: String = sdkClient.getSessionId()!

        sdkClient.addEvent(["event": "in_session_event"], table: eventTable)
        sdkClient.endSession(sessionTable)
        sdkClient.addEvent(["event": "not_in_session_event"], table: eventTable)
        sdkClient.uploadEvents()

        let sessionRecords = try! IntegrationTests.api.stubbornQuery(
            "select td_session_event, td_session_id from \(sessionTable)",
            database: IntegrationTests.TargetDatabase)
        let sessionEvents: Set = [sessionRecords[0][0] as! String, sessionRecords[1][0] as! String]
        XCTAssertTrue(sessionEvents.contains("start"))
        XCTAssertTrue(sessionEvents.contains("end"))
        XCTAssertEqual(sessionRecords[0][1] as! String, sessionId)
        XCTAssertEqual(sessionRecords[1][1] as! String, sessionId)

        let eventRecords = try! IntegrationTests.api.stubbornQuery(
            "select td_session_id, event from \(eventTable)",
            database: IntegrationTests.TargetDatabase)
        for event in eventRecords {
            if (event[1] as! String == "in_session_event") {
                XCTAssertEqual(event[0] as? String, sessionId)
            } else if (event[1] as! String == "not_in_session_event") {
                XCTAssertEqual(event[0] as! String, "")
            }
        }
    }

    func testResetUniqId() {
        sdkClient.enableCustomEvent()
        sdkClient.enableAutoAppendUniqId()

        let table = newTempTable()
        sdkClient.addEvent([:], table: table)
        sdkClient.resetUniqId()
        sdkClient.addEvent([:], table: table)
        sdkClient.uploadEvents()

        let result = try! IntegrationTests.api.stubbornQuery("select td_uuid from \(table) limit 2", database: IntegrationTests.TargetDatabase)
        XCTAssert(result[0][0] as! String != result[1][0] as! String)
    }
    
    func testFetchUserSegmentsSucceed() {
        let expectation = self.expectation(description: "fetchUserSegments should succeed")
        sdkClient.fetchUserSegments(tokens: IntegrationTests.audienceTokens, keys: IntegrationTests.userSegmentKeys) { (jsonResponse, error) in
            XCTAssertNil(error)
            XCTAssertNotNil(jsonResponse)
            expectation.fulfill()
        }
        waitForExpectations(timeout: 60, handler: nil)
    }

    func testFetchUserSegmentsServerErrorFailure() {
        let expectation = self.expectation(description: "fetchUserSegments should fail with server error")
        sdkClient.fetchUserSegments(tokens: IntegrationTests.audienceTokens, keys: [:]) { (jsonResponse, error) in
            XCTAssertNil(jsonResponse)
            XCTAssertNotNil(error)
            expectation.fulfill()
        }
        waitForExpectations(timeout: 60, handler: nil)
    }

    private func newTempTable() -> String {
        let table: String = "ios_integration_test_" + NSUUID().uuidString.lowercased().replacingOccurrences(of: "-", with: "_")
        tempTables.append(table)
        return table
    }

    static func uuid() -> String {
        return NSUUID().uuidString.lowercased().replacingOccurrences(of: "-", with: "_")
    }
}
