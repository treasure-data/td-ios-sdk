//
//  AppDelegate.m
//  TreasureDataExample
//
//  Created by Mitsunori Komatsu on 7/13/16.
//  Copyright © 2016 Treasure Data. All rights reserved.
//

#import "AppDelegate.h"
#import "TreasureData.h"
#import "TreasureDataExample.h"

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    [TreasureDataExample setupTreasureData];
    NSLog(@"session_id = %@ before calling `startSession`", [TreasureData getSessionId]);
    [TreasureData startSession];  // Or [[TreasureData sharedInstance] startSession:@"demotbl"];
    NSLog(@"session_id = %@ after calling `startSession`", [TreasureData getSessionId]);
    return YES;
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
    NSLog(@"session_id = %@ before calling `startSession`", [TreasureData getSessionId]);
    [TreasureData startSession];  // Or // [[TreasureData sharedInstance] startSession:@"demotbl"];
    NSLog(@"session_id = %@ after calling `startSession`", [TreasureData getSessionId]);
}

@end
