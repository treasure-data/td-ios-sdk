//
//  UploaderTests.swift
//  TreasureDataSDK
//
//  Created by Yuki Nagai on 4/24/16.
//  Copyright © 2016 Recruit Lifestyle Co., Ltd. All rights reserved.
//

import XCTest
@testable import TreasureDataSDK

final class UploaderTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testNoEventToUpload() {
        let configuration = Configuration(
            key: "KEY",
            database: "DATABASE",
            table: "TABLE",
            inMemoryIdentifier: "inMemoryIdentifier")
        let stub = NSURLSessionStub()
        Uploader(configuration: configuration, session: stub).uploadEvents { result in
            XCTAssertEqual(result.hashValue, Result.NoEventToUpload.hashValue)
        }
    }
    
    func testRequestParameters() {
        let deviceStub = UIDeviceStub()
        Device.device = deviceStub
        let configuration = Configuration(
            key: "KEY",
            database: "DATABASE",
            table: "TABLE",
            inMemoryIdentifier: "inMemoryIdentifier",
            shouldAppendDeviceIdentifier: true,
            shouldAppendModelInformation: true,
            shouldAppendSeverSideTimestamp: true)
        let instance = TreasureData(configuration: configuration)
        instance.startSession()
        instance.addEvent()
        let stub = NSURLSessionStub()
        stub.requestValidation = { request in
            let headers = request.allHTTPHeaderFields!
            XCTAssertEqual(headers["Content-Type"], "application/json")
            XCTAssertEqual(headers["X-TD-Data-Type"], "k")
            XCTAssertEqual(headers["X-TD-Write-Key"], configuration.key)
            let parameters = self.requestParameters(request)
            XCTAssertNotNil(parameters[configuration.schemaName])
            let events = parameters[configuration.schemaName] as! [[String: AnyObject]]
            XCTAssertEqual(events.count, 1)
            let event = events.first!
            XCTAssertNotNil(event["#UUID"])
            XCTAssertEqual(event["#SSUT"] as? Bool, true)
            XCTAssertNotNil(event["timestamp"])
            XCTAssertEqual(event["td_model"] as? String, deviceStub.deviceModel)
            XCTAssertEqual(event["td_os_type"] as? String, deviceStub.systemName)
            XCTAssertEqual(event["td_os_ver"] as? String, deviceStub.systemVersion)
            XCTAssertFalse((event["td_session_id"] as? String)?.isEmpty ?? true)
            XCTAssertEqual(event["td_uuid"] as? String, deviceStub.identifierForVendor?.UUIDString)
        }
        let data = self.dataResponse(configuration: configuration) { _ in return true }
        stub.completionResponse = (data, nil, nil)
        Uploader(configuration: configuration, session: stub).uploadEvents { result in
        }
    }

    func testAllUploaded() {
        let configuration = Configuration(
            key: "KEY",
            database: "DATABASE",
            table: "TABLE",
            inMemoryIdentifier: "inMemoryIdentifier")
        let instance = TreasureData(configuration: configuration)
        instance.addEvent()
        instance.addEvent()
        instance.addEvent()
        instance.addEvent()
        let stub = NSURLSessionStub()
        let data = self.dataResponse(configuration: configuration) { _ in return true }
        stub.completionResponse = (data, nil, nil)
        Uploader(configuration: configuration, session: stub).uploadEvents { result in
            XCTAssertEqual(result.hashValue, Result.Success.hashValue)
            let events = Event.events(configuration: configuration)!.array
            XCTAssertTrue(events.isEmpty)
        }
    }
    
    func testSomeUploaded() {
        let configuration = Configuration(
            key: "KEY",
            database: "DATABASE",
            table: "TABLE",
            inMemoryIdentifier: "inMemoryIdentifier")
        let instance = TreasureData(configuration: configuration)
        instance.addEvent()
        instance.addEvent()
        instance.addEvent()
        instance.addEvent()
        let stub = NSURLSessionStub()
        var uploaded = [String]()
        var failed   = [String]()
        stub.requestValidation = { request in
            let parameters = self.requestParameters(request)[configuration.schemaName] as! [[String: AnyObject]]
            let identifiers = parameters.map { $0["#UUID"] as! String }
            uploaded = identifiers.enumerate().filter { $0.index % 2 == 0 }.map { $0.element }
            failed   = identifiers.enumerate().filter { $0.index % 2 == 1 }.map { $0.element }
        }
        let data = self.dataResponse(configuration: configuration) { index in return index % 2 == 0 }
        stub.completionResponse = (data, nil, nil)
        Uploader(configuration: configuration, session: stub).uploadEvents { result in
            XCTAssertEqual(result.hashValue, Result.Success.hashValue)
            let events = Event.events(configuration: configuration)!.array
            XCTAssertEqual(events.count, 2)
            events.forEach{ event in
                XCTAssertFalse(uploaded.contains(event.id))
                XCTAssertTrue(failed.contains(event.id))
            }
        }
    }
    
    private func dataResponse(configuration configuration: Configuration, condition: Int -> Bool) -> NSData {
        let events = Event.events(configuration: configuration)?.array ?? []
        let results: [[String: Bool]] = events.enumerate().map { index, _ in
            return ["success": condition(index)]
        }
        let response: [String: AnyObject] = [
            "\(configuration.database).\(configuration.table)": results
        ]
        let options = NSJSONWritingOptions()
        let data = try! NSJSONSerialization.dataWithJSONObject(response, options: options)
        return data
    }
    
    private func requestParameters(request: NSURLRequest) -> [String: AnyObject] {
        guard let HTTPBody = request.HTTPBody else { return [:] }
        do {
            let options = NSJSONReadingOptions()
            if let serialized = try NSJSONSerialization.JSONObjectWithData(HTTPBody, options: options) as? [String: AnyObject] {
                return serialized
            } else { return [:] }
            
        } catch {
            return [:]
        }
    }
}
