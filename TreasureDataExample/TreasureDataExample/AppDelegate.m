//
//  AppDelegate.m
//  TreasureDataExample
//
//  Created by Mitsunori Komatsu on 7/13/16.
//  Copyright © 2016 Treasure Data. All rights reserved.
//

#import "AppDelegate.h"
#import "TreasureData.h"
#import "TDConfiguration.h"

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    [TreasureData enableLogging];
    // [TreasureData initializeApiEndpoint:@"https://in.ybi.idcfcloud.net"];

    TDConfiguration *configuration = [TDConfiguration new];

    configuration.encryptionKey = @"hello world";

    configuration.endpoint = @"https://in.treasuredata.com";
    configuration.apiKey = @"your_api_key";

    configuration.defaultDatabase = @"huy";
    configuration.defaultTable = @"mobile";
    configuration.autoAppendUniqId = true;
    configuration.autoAppendRecordUUID = true;
    configuration.autoAppendModelInformation = true;
    configuration.autoAppendAppInformation = true;
    configuration.autoAppendLocaleInformation = true;
    configuration.serverTimestampColumn = @"server_upload_time";

    [TreasureData config:configuration];
    [TreasureData startSession];

    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application
{
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    // [[TreasureData sharedInstance] endSession:@"demotbl"];
    NSLog(@"session_id = %@ before calling `endSession`", [TreasureData getSessionId]);
    [TreasureData endSession];
    NSLog(@"session_id = %@ after calling `endSession`", [TreasureData getSessionId]);
    
    UIBackgroundTaskIdentifier bgTask = [application beginBackgroundTaskWithExpirationHandler:^{}];
    [[TreasureData sharedInstance] uploadEventsWithCallback:^() {
        [application endBackgroundTask:bgTask];
    }
                                                    onError:^(NSString *code, NSString *msg) {
                                                        [application endBackgroundTask:bgTask];
                                                    }
     ];
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    // [[TreasureData sharedInstance] startSession:@"demotbl"];
    NSLog(@"session_id = %@ before calling `startSession`", [TreasureData getSessionId]);
    [TreasureData startSession];
    NSLog(@"session_id = %@ after calling `startSession`", [TreasureData getSessionId]);
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

@end
