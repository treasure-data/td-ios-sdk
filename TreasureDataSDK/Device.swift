//
//  Device.swift
//  TreasureDataSDK
//
//  Created by Yuki Nagai on 4/11/16.
//  Copyright © 2016 Recruit Lifestyle Co., Ltd. All rights reserved.
//

import Foundation

private let currentDevice = UIDevice.currentDevice()

internal struct Device {
    internal static var device = currentDevice
    
    var deviceIdentifier: String {
        if Cached.deviceIdentifier.isEmpty {
            Cached.deviceIdentifier = self.dynamicType.device.identifierForVendor?.UUIDString ?? ""
        }
        return Cached.deviceIdentifier
    }
    
    var systemName: String {
        if Cached.systemName.isEmpty {
            Cached.systemName = self.dynamicType.device.systemName
        }
        return Cached.systemName
    }
    
    var systemVersion: String {
        if Cached.systemVersion.isEmpty {
            Cached.systemVersion = self.dynamicType.device.systemVersion
        }
        return Cached.systemVersion
    }
    
    var deviceModel: String {
        if Cached.deviceModel.isEmpty {
            Cached.deviceModel = self.dynamicType.device.deviceModel
        }
        return Cached.deviceModel
    }
    
    struct Cached {
        static var deviceIdentifier = ""
        static var systemName       = ""
        static var systemVersion    = ""
        static var deviceModel      = ""
    }
}
