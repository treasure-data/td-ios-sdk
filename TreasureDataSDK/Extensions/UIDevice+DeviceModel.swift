//
//  UIDevice+DeviceModel.swift
//  TreasureDataSDK
//
//  Created by Yuki Nagai on 4/23/16.
//  Copyright © 2016 Recruit Lifestyle Co., Ltd. All rights reserved.
//

import Foundation

internal extension UIDevice {
    var deviceModel: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machine = systemInfo.machine
        let mirror = Mirror(reflecting: machine)
        let children: [String] = mirror.children.flatMap { child in
            guard let value = child.value as? Int8 where value != 0 else { return nil }
            return String(UnicodeScalar(UInt8(value)))
        }
        return children.joinWithSeparator("")
    }
}
