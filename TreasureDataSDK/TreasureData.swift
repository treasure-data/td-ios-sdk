//
//  TreasureData.swift
//  TreasureDataSDK
//
//  Created by Yuki Nagai on 3/30/16.
//  Copyright © 2016 Recruit Lifestyle Co., Ltd. All rights reserved.
//

import Foundation

internal let bundleIdentifier = "jp.co.recruit-lifestyle.TreasureDataSDK"

public final class TreasureData {
    public typealias UserInfo = [String: String]
    public typealias UploadingCompletion = Result -> Void

    internal static var defaultInstance: TreasureData?
    internal var sessionIdentifier = ""
    
    public let configuration: Configuration
    /// Configure default instance.
    public static func configure(configuration: Configuration) {
        self.defaultInstance = TreasureData(configuration: configuration)
    }
    
    public init(configuration: Configuration) {
        self.configuration = configuration
    }
    
    public func addEvent(userInfo userInfo: UserInfo = [:]) {
        guard let realm = self.configuration.realm else { return }
        let event = Event().appendInformation(self).appendUserInfo(userInfo)
        do {
            try realm.write {
                realm.add(event)
            }
        } catch let error {
            if self.configuration.debug {
                print(error)
            }
        }
    }
    public static func addEvent(userInfo userInfo: UserInfo = [:]) {
        self.defaultInstance?.addEvent(userInfo: userInfo)
    }
    
    public func uploadEvents(completion: UploadingCompletion? = nil) {
        Uploader(configuration: self.configuration).uploadEvents(completion: completion)
    }
    public static func uploadEvents(completion: UploadingCompletion? = nil) {
        self.defaultInstance?.uploadEvents(completion)
    }
    
    public func startSession() {
        self.sessionIdentifier = NSUUID().UUIDString
    }
    public static func startSession() {
        self.defaultInstance?.startSession()
    }
    
    public func endSession() {
        self.sessionIdentifier = ""
    }
    public static func endSession() {
        self.defaultInstance?.endSession()
    }
}
