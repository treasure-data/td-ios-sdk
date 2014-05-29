//
//  ViewController.m
//  TreasureDataExample
//
//  Created by Mitsunori Komatsu on 5/20/14.
//  Copyright (c) 2014 Treasure Data. All rights reserved.
//

#import "ViewController.h"
#import "TreasureData-iOS-SDK/TreasureData.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    [TreasureData enableLogging];
    [TreasureData initializeWithSecret:@"your_api_key"];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)addEvent:(id)sender {
    NSLog(@"Click!!!!");
    [[TreasureData sharedInstance] event:@"foo_db" table:@"bar_tbl"
                              properties:@{
                                           @"name": @"komamitsu",
                                           @"age": @42,
                                           }];
}

- (IBAction)uploadEvents:(id)sender {
    UIBackgroundTaskIdentifier taskId =
        [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^(void) {
            NSLog(@"Uploaded");
        }];
    
    [[TreasureData sharedInstance] uploadWithBlock:^(void) {
        [[UIApplication sharedApplication] endBackgroundTask:taskId];
    }];
}

@end
