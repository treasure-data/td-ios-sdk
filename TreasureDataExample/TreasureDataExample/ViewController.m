//
//  ViewController.m
//  TreasureDataExample
//
//  Created by Mitsunori Komatsu on 7/13/16.
//  Copyright © 2016 Treasure Data. All rights reserved.
//

#import "ViewController.h"
#import "TreasureData-iOS-SDK/TreasureData.h"

#import "TreasureDataExample.h"

@interface ViewController ()

@property (assign, nonatomic) BOOL isDirty;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self.apiEndpointField setText:TreasureData.sharedInstance.client.apiEndpoint];
    [self.apiKeyField setText:TreasureData.sharedInstance.client.apiKey];
    [self.targetDatabaseField setText:TreasureData.sharedInstance.defaultDatabase];
    [self.eventCollectingSwitch setOn:![[TreasureData sharedInstance] isCustomEventsBlocked]];
    [self.autoEventSwitch setOn:![[TreasureData sharedInstance] isAppLifecycleEventsBlocked]];
    [self.autoTrackTableField setText:[[NSUserDefaults standardUserDefaults] stringForKey:@"TDAutoTrackingEnabled"]];
    self.eventCollectingSwitch.onTintColor = [UIColor colorWithRed:231/255.0 green:76/255.0 blue:60/255.0 alpha:1.0];
    self.autoEventSwitch.onTintColor = [UIColor colorWithRed:231/255.0 green:76/255.0 blue:60/255.0 alpha:1.0];

    [self.targetTableField setText:@"mobile_events"];
    [self.autoTrackTableField setText:@"auto_tracked_mobile_events"];
    [[TreasureData sharedInstance] enableAppLifecycleEventsTrackingWithTable:@"auto_tracked_events"];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)formChanged:(UITextField *)sender {
    NSLog(@"Detect form changed");
    self.isDirty = YES;
}

- (IBAction)eventCollectingSwitchChanged:(UISwitch *)sender {
    if ([sender isOn]) {
        NSLog(@"unblockCustomEvents");
        [[TreasureData sharedInstance] unblockCustomEvents];
    } else {
        NSLog(@"blockCustomEvents");
        [[TreasureData sharedInstance] blockCustomEvents];
    }
}

- (IBAction)autoEventSwitchChanged:(id)sender {
    if ([sender isOn]) {
        [[TreasureData sharedInstance] unblockAppLifecycleEvents];
    } else {
        [[TreasureData sharedInstance] blockAppLifecycleEvents];
    }
}

- (IBAction)addEvent:(id)sender {
    [ViewController shiftButton:self.addEventButton toState:kButtonStatePending withTitle:@"Adding Event..."];

    if (self.isDirty) {
        self.isDirty = NO;
        [TreasureDataExample
         setupTreasureDataWithEndpoint:self.apiEndpointField.text
         apiKey:self.apiKeyField.text
         database:self.targetDatabaseField.text];
    }

    [[TreasureData sharedInstance]
     addEventWithCallback:@{
                            @"name": @"komamitsu",
                            @"age": @99
                            }
     table:self.targetTableField.text
     onSuccess:^(){
         dispatch_async(dispatch_get_main_queue(), ^{
             [ViewController shiftButton:self.addEventButton toState:kButtonStateSuccess withTitle:@"Add Event Success!"];
             [NSTimer scheduledTimerWithTimeInterval:1.0 repeats:NO block:^(NSTimer *timer) {
                 [ViewController shiftButton:self.addEventButton toState:kButtonStateNormal withTitle:@"Add Test Event"];
             }];
         });
     }
     onError:^(NSString* errorCode, NSString* message) {
         NSLog(@"addEvent: error. errorCode=%@, message=%@", errorCode, message);
     }
     ];
}

- (IBAction)uploadEvents:(id)sender {
    [ViewController shiftButton:self.uploadButton toState:kButtonStatePending withTitle:@"Uploading Event..."];
    [[TreasureData sharedInstance] uploadEventsWithCallback:^(){
        NSLog(@"uploadEvents: success");
        dispatch_async(dispatch_get_main_queue(), ^{
            [ViewController shiftButton:self.uploadButton toState:kButtonStateSuccess withTitle:@"Upload Event Success!"];
            [NSTimer scheduledTimerWithTimeInterval:1.5 repeats:NO block:^(NSTimer* timer) {
                [ViewController shiftButton:self.uploadButton toState:kButtonStateNormal withTitle:@"Upload Events"];
            }];
        });
    } onError:^(NSString* errorCode, NSString* message) {
        NSLog(@"uploadEvents: error. errorCode=%@, message=%@", errorCode, message);
    }];
}

typedef enum {
    kButtonStateNormal,
    kButtonStatePending,
    kButtonStateSuccess
} ButtonState;

+ (void)shiftButton:(UIButton *)button toState:(ButtonState)state withTitle:(NSString *)title {
    [button setTitle:title forState:UIControlStateNormal];
    switch (state) {
        case kButtonStateSuccess:
            [button setTitleColor:[UIColor colorWithRed:39/255.0 green:174/255.0 blue:96/255.0 alpha:1.0] forState:UIControlStateNormal];
            button.userInteractionEnabled = NO;
            break;
        case kButtonStatePending:
            [button setTitleColor:[UIColor colorWithRed:243/255.0 green:156/255.0 blue:18/255.0 alpha:1.0] forState:UIControlStateNormal];
            button.userInteractionEnabled = NO;
            break;
        case kButtonStateNormal:
            [button setTitleColor:[UIView new].tintColor forState:UIControlStateNormal];
            button.userInteractionEnabled = YES;
            break;
    }
}

@end
