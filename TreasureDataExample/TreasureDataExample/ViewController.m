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
    // [TreasureData enableLogging];
    [TreasureData initializeWithApiKey:@"your_api_key"];
    [[TreasureData sharedInstance] setDefaultDatabase:@"foo_db"];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

- (IBAction)addEvent:(id)sender {
    NSLog(@"Click!!!!");
    [[TreasureData sharedInstance] event:@{
                                           @"name": @"komamitsu",
                                           @"age": @99
                                           }
                                   table:@"bar_tbl"
     ];
}

- (IBAction)uploadEvents:(id)sender {
    [[TreasureData sharedInstance] uploadWithBlock:^(void) {
        NSLog(@"Uploaded");
    }];
}

@end
