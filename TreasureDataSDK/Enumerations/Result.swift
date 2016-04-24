//
//  Result.swift
//  TreasureDataSDK
//
//  Created by Yuki Nagai on 4/24/16.
//  Copyright © 2016 Recruit Lifestyle Co., Ltd. All rights reserved.
//

import Foundation

public enum Result {
    case Success
    case NoEventToUpload
    case NetworkError
    case SystemError
    case DatabaseUnavailable
    case Unknown
}
