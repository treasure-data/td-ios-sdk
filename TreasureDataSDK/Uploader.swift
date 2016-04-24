//
//  Uploader.swift
//  TreasureDataSDK
//
//  Created by Yuki Nagai on 4/24/16.
//  Copyright © 2016 Recruit Lifestyle Co., Ltd. All rights reserved.
//

import Foundation

private let defaultSession = NSURLSession.sharedSession()

internal struct Uploader {
    private let configuration: Configuration
    private let session: NSURLSession
    private typealias JSONType = [String: AnyObject]
    
    init(configuration: Configuration, session: NSURLSession = defaultSession) {
        self.configuration = configuration
        self.session       = session
    }
    
    func uploadEvents(completion completion: TreasureData.UploadingCompletion?) {
        guard let events = Event.events(configuration: self.configuration) else {
            completion?(.DatabaseUnavailable)
            return
        }
        guard events.count > 0 else {
            completion?(.NoEventToUpload)
            return
        }
        let URL = NSURL(string: configuration.endpoint)!.URLByAppendingPathComponent("ios/v3/event")
        let request = NSMutableURLRequest(URL: URL)
        let headers: [String: String] = [
            "Content-Type": "application/json",
            "X-TD-Data-Type": "k",
            "X-TD-Write-Key": configuration.key,
        ]
        headers.forEach { field, value in
            request.addValue(value, forHTTPHeaderField: field)
        }
        // parameters validation is not needed for clients
        let parameters: JSONType = [
            configuration.schemaName: events.map { event -> JSONType in
                var parameters: JSONType = [
                    "#UUID": event.id,
                    "#SSUT": configuration.shouldAppendSeverSideTimestamp,
                    "timestamp": event.timestamp,
                    "td_model": event.deviceModel,
                    "td_os_type": event.systemName,
                    "td_os_ver": event.systemVersion,
                    "td_session_id": event.sessionIdentifier,
                    "td_uuid": event.deviceIdentifier,
                ]
                event.userInfo.forEach { keyValue in
                    let key   = keyValue.key
                    let value = keyValue.value
                    parameters[key] = value
                }
                return parameters
            }
        ]
        request.HTTPMethod = "POST"
        do {
            let options = NSJSONWritingOptions()
            let data = try NSJSONSerialization.dataWithJSONObject(parameters, options: options)
            request.HTTPBody = data
        } catch let error {
            if configuration.debug {
                print(error)
            }
        }
        let task = self.session.dataTaskWithRequest(request) { data, response, error in
            let response = response as? NSHTTPURLResponse
            let result = self.handleCompletion(
                configuration: self.configuration,
                data: data,
                response: response,
                error: error)
            completion?(result)
        }
        task.resume()
    }
    
    private func handleCompletion(
        configuration configuration: Configuration,
        data: NSData?,
        response: NSHTTPURLResponse?,
        error: NSError?) -> Result {
        if let _ = error { return response?.statusCode == 0 ? .NetworkError : .SystemError }
        guard let data = data else { return .Unknown }
        let json: JSONType
        do {
            let options = NSJSONReadingOptions()
            guard let serialized = try NSJSONSerialization.JSONObjectWithData(data, options: options) as? JSONType else { return .Unknown }
            json = serialized
        } catch { return .Unknown }
        // clean events
        let events = Event.events(configuration: self.configuration)!
        let count = events.count
        guard let parameters = json[configuration.schemaName] as? [[String: Bool]] else { return .Unknown }
        let uploaded = parameters.map { $0["success"] ?? false }.enumerate().flatMap { index, value in
            return value && index < count ? events[index] : nil
        }
        let realm = configuration.realm
        do {
            try realm?.write{
                realm?.delete(uploaded)
            }
        } catch let error {
            if configuration.debug {
                print(error)
            }
        }
        return .Success
    }
}
