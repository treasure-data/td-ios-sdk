//
//  Configuration.swift
//  TreasureDataSDK
//
//  Created by Yuki Nagai on 3/30/16.
//  Copyright © 2016 Recruit Lifestyle Co., Ltd. All rights reserved.
//

import RealmSwift

public struct Configuration {
    public let debug: Bool
    public let endpoint: String
    public let key: String
    public let database: String
    public let table: String
    public let fileURL: NSURL?
    public let inMemoryIdentifier: String?
    public let encriptionKey: NSData?
    public let schemaVersion: UInt64
    public let shouldAppendDeviceIdentifier: Bool
    public let shouldAppendModelInformation: Bool
    public let shouldAppendSeverSideTimestamp: Bool
    
    /**
     - parameters:
        - debug: [OPTIONAL] Enable debug log to console. The default is false.
        - endpoint: [OPTIONAL] TreasureData API endpoint. The default is "https://in.treasuredata.com".
        - key: [REQUIRED] TreasureData API key.
        - database: [REQUIRED] TreasureData database name you want to send.
        - table: [REQUIRED] TreasureData table name you want to send.
        - fileURL: [OPTIONAL] Local URL to the realm file. The default is in Application Support directory. Mutually exclusive with inMemoryIdentifier.
        - inMemoryIdentifier: [OPTIONAL] A string used to identify a particular in-memory Realm. Mutually exclusive with path.
        - encriptionKey: [OPTIONAL] 64-byte key to use to encrypt the data.
        - shouldAppendDeviceIdentifier: [OPTIONAL] Automatically appended device identifier if it is true. The default is false.
        - shouldAppendModelInformation: [OPTIONAL] Automatically appended device information if it is true. The default is false.
        - shouldAppendSeverSideTimestamp: [OPTIONAL] Request append server side timestamp if it is true. The default is false.
     */
    public init(
        debug: Bool = false,
        endpoint: String = "https://in.treasuredata.com",
        key:      String,
        database: String,
        table:    String,
        fileURL:            NSURL?  = nil,
        inMemoryIdentifier: String? = nil,
        encriptionKey:      NSData? = nil,
        schemaVersion:      UInt64  = 1,
        shouldAppendDeviceIdentifier:   Bool = false,
        shouldAppendModelInformation:   Bool = false,
        shouldAppendSeverSideTimestamp: Bool = false) {
        self.debug = debug
        self.endpoint = endpoint
        self.key      = key
        self.database = database
        self.table    = table
        // Realm configuration
        switch (fileURL, inMemoryIdentifier) {
        case (let filePath?, _):
            self.fileURL            = filePath
            self.inMemoryIdentifier = nil
        case (nil, let inMemoryIdentifier?):
            self.fileURL            = nil
            self.inMemoryIdentifier = inMemoryIdentifier
        default:
            self.fileURL           = self.dynamicType.defaultFileURL()
            self.inMemoryIdentifier = nil
        }
        self.encriptionKey      = encriptionKey
        self.schemaVersion      = schemaVersion
        self.shouldAppendDeviceIdentifier   = shouldAppendDeviceIdentifier
        self.shouldAppendModelInformation   = shouldAppendModelInformation
        self.shouldAppendSeverSideTimestamp = shouldAppendSeverSideTimestamp
    }
    
    internal static func defaultFileURL() -> NSURL {
        let applicationSupportDirectoryURL = NSFileManager.defaultManager().URLsForDirectory(.ApplicationSupportDirectory, inDomains: .UserDomainMask).first!
        let bundleIdentifier = NSBundle.mainBundle().bundleIdentifier ?? "."
        let directoryURL = applicationSupportDirectoryURL.URLByAppendingPathComponent(bundleIdentifier)
        do {
            try NSFileManager.defaultManager().createDirectoryAtURL(directoryURL, withIntermediateDirectories: true, attributes: nil)
        } catch {}
        return directoryURL.URLByAppendingPathComponent("TreasureDataSDK.realm")
    }
    
    internal var realm: RealmSwift.Realm? {
        let configuration = Realm.Configuration(
            fileURL: self.fileURL,
            inMemoryIdentifier: self.inMemoryIdentifier,
            encryptionKey: self.encriptionKey,
            readOnly: false,
            schemaVersion: self.schemaVersion,
            migrationBlock: { migration, oldSchemaVersion in
                guard oldSchemaVersion > self.schemaVersion else {
                    return
                }
                for objectSchema in migration.oldSchema.objectSchema {
                    migration.deleteData(objectSchema.className)
                }
            })
        do {
            return try Realm(configuration: configuration)
        } catch let error {
            if self.debug {
                print(error)
            }
        }
        return nil
    }
    
    internal var schemaName: String {
        return "\(self.database).\(self.table)"
    }
}
