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
    [[TreasureData sharedInstance] enableAutoAppendUniqId];
    [[TreasureData sharedInstance] enableAutoAppendModelInformation];

    if (![[NSUserDefaults standardUserDefaults] boolForKey:@"HasLaunchedOnce"]) {
        [[TreasureData sharedInstance] addEventWithCallback:@{ @"event": @"installed" }
                                                   database:@"database_a"
                                                      table:@"table_b"
                                                  onSuccess:^(){
                                                      [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"HasLaunchedOnce"];
                                                      [[NSUserDefaults standardUserDefaults] synchronize];
                                                      [[TreasureData sharedInstance] uploadEvents];
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
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
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
