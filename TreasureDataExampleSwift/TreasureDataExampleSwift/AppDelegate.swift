//
//  AppDelegate.swift
//  TreasureDataExampleSwift
//
//  Created by Mitsunori Komatsu on 1/2/16.
//  Copyright © 2016 Treasure Data. All rights reserved.
//

import UIKit
import TreasureData_iOS_SDK

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {

        TreasureData.enableLogging()
        // TreasureData.initializeApiEndpoint("https://in.ybi.idcfcloud.net")
        TreasureData.initializeEncryptionKey("hello world")
        TreasureData.initializeWithApiKey("your_api_key")
        TreasureData.sharedInstance().defaultDatabase = "testdb"
        TreasureData.sharedInstance().enableAutoAppendUniqId()
        TreasureData.sharedInstance().enableAutoAppendModelInformation()
        TreasureData.sharedInstance().disableRetryUploading()
        TreasureData.sharedInstance().startSession("demotbl")
        
        if (TreasureData.sharedInstance().isFirstRun()) {
            TreasureData.sharedInstance().addEventWithCallback(
                ["event": "installed"],
                database: "testdb",
                table: "demotbl",
                onSuccess:{()-> Void in
                    TreasureData.sharedInstance().clearFirstRun()
                },
                onError:{(errorCode, message) -> Void in
                    print("addEvent: error. errorCode=%@, message=%@", errorCode, message)
            })
        }

        return true
    }

    func applicationWillResignActive(application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(application: UIApplication) {
        TreasureData.sharedInstance().endSession("demotbl")
        let application = UIApplication.sharedApplication()
        var bgTask : UIBackgroundTaskIdentifier = 0
        bgTask = application.beginBackgroundTaskWithExpirationHandler({
            application.endBackgroundTask(bgTask)
            bgTask = UIBackgroundTaskInvalid
        })
        TreasureData.sharedInstance().uploadEventsWithCallback({
            application.endBackgroundTask(bgTask)
            bgTask = UIBackgroundTaskInvalid
            },
            onError: {(errorCode, message) -> Void in
                print("uploadEvents: error. errorCode=%@, message=%@", errorCode, message)
                application.endBackgroundTask(bgTask)
                bgTask = UIBackgroundTaskInvalid
        })
    }

    func applicationWillEnterForeground(application: UIApplication) {
        // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }
}

