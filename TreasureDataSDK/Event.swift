//
//  Event.swift
//  TreasureDataSDK
//
//  Created by Yuki Nagai on 3/30/16.
//  Copyright © 2016 Recruit Lifestyle Co., Ltd. All rights reserved.
//

import RealmSwift

internal final class Event: RealmSwift.Object {
    private(set) dynamic var id        = ""
    private(set) dynamic var timestamp = NSTimeInterval(0)
    private(set) dynamic var database  = ""
    private(set) dynamic var table     = ""
    // appended according to configuration
    private(set) dynamic var deviceIdentifier  = ""
    private(set) dynamic var systemName        = ""
    private(set) dynamic var systemVersion     = ""
    private(set) dynamic var deviceModel       = ""
    private(set) dynamic var sessionIdentifier = ""
    // user extra information
    let userInfo = List<KeyValue>()
    
    override static func primaryKey() -> String? {
        return "id"
    }
    override static func indexedProperties() -> [String] {
        return ["database", "table"]
    }
    
    func appendInformation(instance: TreasureData) -> Event {
        let event = Event(value: self)
        event.id          = NSUUID().UUIDString
        event.timestamp   = NSDate().timeIntervalSince1970
        event.database  = instance.configuration.database
        event.table     = instance.configuration.table
        let device = Device()
        if instance.configuration.shouldAppendDeviceIdentifier {
            event.deviceIdentifier = device.deviceIdentifier
        }
        if instance.configuration.shouldAppendModelInformation {
            event.systemName    = device.systemName
            event.systemVersion = device.systemVersion
            event.deviceModel   = device.deviceModel
        }
        event.sessionIdentifier = instance.sessionIdentifier
        return event
    }
    
    func appendUserInfo(userInfo: TreasureData.UserInfo) -> Event {
        let event = Event(value: self)
        userInfo.forEach { key, value in
            guard !key.isEmpty else { return }
            let keyValue = KeyValue()
            keyValue.key   = key
            keyValue.value = value
            event.userInfo.append(keyValue)
        }
        return event
    }
    
    static func events(configuration configuration: Configuration) -> RealmSwift.Results<Event>? {
        let predicate = NSPredicate(format: "database = %@ AND table = %@", configuration.database, configuration.table)
        return configuration.realm?.objects(Event).filter(predicate)
    }
}

internal final class KeyValue: RealmSwift.Object {
    dynamic var key   = ""
    dynamic var value = ""
}

internal extension List {
    var array: [T] {
        return self.map { $0 }
    }
}

internal extension Results {
    var array: [T] {
        return self.map { $0 }
    }
}
