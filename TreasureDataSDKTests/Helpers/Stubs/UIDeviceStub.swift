//
//  UIDeviceStub.swift
//  TreasureDataSDK
//
//  Created by Yuki Nagai on 4/23/16.
//  Copyright © 2016 Recruit Lifestyle Co., Ltd. All rights reserved.
//

import Foundation
@testable import TreasureDataSDK

final class UIDeviceStub: UIDevice {
    override var identifierForVendor: NSUUID? {
        return NSUUID(UUIDString: "E621E1F8-C36C-495A-93FC-0C247A3E6E5F")
    }
    override var systemName: String {
        return "systemName"
    }
    override var systemVersion: String {
        return "systemVersion"
    }
    override var deviceModel: String {
        return "deviceModel"
    }
}
