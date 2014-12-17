//
//  AppDelegate.m
//  TreasureDataExample
//
//  Created by Mitsunori Komatsu on 5/20/14.
//  Copyright (c) 2014 Treasure Data Inc. All rights reserved.
//

#import "AppDelegate.h"
#import "TreasureData.h"

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    [TreasureData enableLogging];
    // [TreasureData initializeApiEndpoint:@"https://mobile-ybi.jp-east.idcfcloud.com"];
    [TreasureData initializeEncryptionKey:@"hello world"];
    [TreasureData initializeWithApiKey:@"your_api_key"];
    [[TreasureData sharedInstance] setDefaultDatabase:@"testdb"];
    [[TreasureData sharedInstance] enableAutoAppendUniqId];
    [[TreasureData sharedInstance] enableAutoAppendModelInformation];
    // [[TreasureData sharedInstance] disableRetryUploading];
    [[TreasureData sharedInstance] startSession:@"demotbl"];
    
    if ([[TreasureData sharedInstance] isFirstRun]) {
        [[TreasureData sharedInstance] addEventWithCallback:@{ @"event": @"installed" }
                                                   database:@"testdb"
                                                      table:@"demotbl"
                                                  onSuccess:^(){
                                                      [[TreasureData sharedInstance] uploadEventsWithCallback:^() {
                                                          [[TreasureData sharedInstance] clearFitstRun];
                                                        }
                                                        onError:^(NSString* errorCode, NSString* message) {
                                                          NSLog(@"uploadEvents: error. errorCode=%@, message=%@", errorCode, message);
                                                        }
                                                       ];
                                                    }
                                                    onError:^(NSString* errorCode, NSString* message) {
                                                        NSLog(@"addEvent: error. errorCode=%@, message=%@", errorCode, message);
                                                    }];
    }
    return YES;
}
							
- (void)applicationWillResignActive:(UIApplication *)application
{
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    [[TreasureData sharedInstance] endSession:@"demotbl"];
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
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

@end
