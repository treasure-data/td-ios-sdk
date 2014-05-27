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
    [TreasureData initializeWithSecret:@"your_api_key"];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)click_button:(id)sender {
    NSLog(@"Click!!!!");
    [[TreasureData sharedInstance] event:@"foo_db" table:@"bar_tbl"
                              properties:@{
                                           @"name": @"komamitsu",
                                           @"age": @42,
                                           }];
}
@end
