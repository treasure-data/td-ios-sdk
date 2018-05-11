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

@property (nonatomic, assign) BOOL isFormDirty;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self.apiEndpointField setText:TreasureData.sharedInstance.client.apiEndpoint];
    [self.apiKeyField setText:TreasureData.sharedInstance.client.apiKey];
    [self.targetDatabaseField setText:TreasureData.sharedInstance.defaultDatabase];
    [self.customEventSwitch setOn:[[TreasureData sharedInstance] isCustomEventEnabled]];
    [self.appLifecycleEventSwitch setOn:[[TreasureData sharedInstance] isAppLifecycleEventEnabled]];
    [self.defaultTableField setText:[[TreasureData sharedInstance] defaultTable]];
    [self customEventSwitchChanged:self.customEventSwitch];
    [self appLifecycleEventSwitchChanged:self.appLifecycleEventSwitch];
    [self.targetTableField setText:[TreasureDataExample testTable]];
    [self.defaultTableField setText:[[TreasureData sharedInstance] defaultTable]];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)formChanged:(UITextField *)sender {
    self.isFormDirty = YES;
}

- (IBAction)customEventSwitchChanged:(UISwitch *)sender {
    if ([sender isOn]) {
        self.customEventToggleLabel.text = @"Custom Events Enabled";
        [[TreasureData sharedInstance] enableCustomEvent];
    } else {
        self.customEventToggleLabel.text = @"Custom Events Disabled";
        [[TreasureData sharedInstance] disableCustomEvent];
    }
}

- (IBAction)appLifecycleEventSwitchChanged:(id)sender {
    if ([sender isOn]) {
        self.appLifecycleEventToggleLabel.text = @"App Lifecycle Events Enabled";
        [[TreasureData sharedInstance] enableAppLifecycleEvent];
    } else {
        self.appLifecycleEventToggleLabel.text = @"App Lifecycle Events Disabled";
        [[TreasureData sharedInstance] disableAppLifecycleEvent];
    }
}

- (IBAction)addEvent:(id)addEventButton {
    [ViewController shiftButton:addEventButton toState:kButtonStatePending withTitle:@"Adding Event..."];

    [self updateClientIfFormChanged];

    [[TreasureData sharedInstance]
     addEventWithCallback:@{
                            @"name": @"komamitsu",
                            @"age": @99
                            }
     table:[TreasureDataExample testTable]
     onSuccess:^(){
         dispatch_async(dispatch_get_main_queue(), ^{
             [ViewController shiftButton:addEventButton toState:kButtonStateSuccess withTitle:@"Add Event Success!"];
             [NSTimer scheduledTimerWithTimeInterval:1.0 repeats:NO block:^(NSTimer *timer) {
                 [ViewController shiftButton:addEventButton toState:kButtonStateNormal withTitle:@"Add Test Event"];
             }];
         });
     }
     onError:^(NSString* errorCode, NSString* message) {
         NSLog(@"addEvent: error. errorCode=%@, message=%@", errorCode, message);
         dispatch_async(dispatch_get_main_queue(), ^{
             NSString *text = [errorCode isEqualToString:@"custom_event_unallowed"] ? @"Add Event Denied!" : @"Add Event Error!";
             [ViewController shiftButton:addEventButton toState:kButtonStateFailed withTitle:text];
             [NSTimer scheduledTimerWithTimeInterval:1.0 repeats:NO block:^(NSTimer *timer) {
                 [ViewController shiftButton:addEventButton toState:kButtonStateNormal withTitle:@"Add Test Event"];
             }];
         });
     }];
}

- (IBAction)uploadEvents:(id)uploadButton {
    [ViewController shiftButton:uploadButton toState:kButtonStatePending withTitle:@"Uploading Events..."];

    [self updateClientIfFormChanged];

    [[TreasureData sharedInstance] uploadEventsWithCallback:^(){
        NSLog(@"uploadEvents: success");
        dispatch_async(dispatch_get_main_queue(), ^{
            [ViewController shiftButton:uploadButton toState:kButtonStateSuccess withTitle:@"Upload Events Success!"];
            [NSTimer scheduledTimerWithTimeInterval:1.5 repeats:NO block:^(NSTimer* timer) {
                [ViewController shiftButton:uploadButton toState:kButtonStateNormal withTitle:@"Upload Events"];
            }];
        });
    } onError:^(NSString* errorCode, NSString* message) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [ViewController shiftButton:uploadButton toState:kButtonStateFailed withTitle:@"Upload Events Error!"];
            [NSTimer scheduledTimerWithTimeInterval:1.5 repeats:NO block:^(NSTimer* timer) {
                [ViewController shiftButton:uploadButton toState:kButtonStateNormal withTitle:@"Upload Events"];
            }];
        });
        NSLog(@"uploadEvents: error. errorCode=%@, message=%@", errorCode, message);
    }];
}

- (IBAction)resetDeviceUniqueID:(id)sender {
    [[TreasureData sharedInstance] resetUniqId];
    [ViewController shiftButton:sender toState:kButtonStateSuccess withTitle:@"Device Unique ID is Reset!"];
    [NSTimer scheduledTimerWithTimeInterval:1 repeats:NO block:^(NSTimer* timer) {
        [ViewController shiftButton:sender toState:kButtonStateNormal withTitle:@"Reset Device Unique ID"];
    }];
}

- (void)updateClientIfFormChanged {
    if (self.isFormDirty) {
        self.isFormDirty = NO;
        [[[TreasureData sharedInstance] client] setApiKey:self.apiKeyField.text];
        [[[TreasureData sharedInstance] client] setApiEndpoint:self.apiEndpointField.text];
        [[TreasureData sharedInstance] setDefaultDatabase:self.targetDatabaseField.text];
        [[TreasureData sharedInstance] setDefaultTable:self.targetTableField.text];
        [[TreasureData sharedInstance] enableAppLifecycleEvent];
        [TreasureDataExample setTestTable:self.targetTableField.text];
    }
}

typedef enum {
    kButtonStateNormal,
    kButtonStatePending,
    kButtonStateSuccess,
    kButtonStateFailed
} ButtonState;

+ (void)shiftButton:(UIButton *)button toState:(ButtonState)state withTitle:(NSString *)title {
    [button setTitle:title forState:UIControlStateNormal];
    switch (state) {
        case kButtonStateSuccess:
            [button setTitleColor:[UIColor colorWithRed:39/255.0 green:174/255.0 blue:96/255.0 alpha:1.0] forState:UIControlStateNormal];
            button.userInteractionEnabled = NO;
            break;
        case kButtonStateFailed:
            // rgb(231, 76, 60)
            [button setTitleColor:[UIColor colorWithRed:231/255.0 green:76/255.0 blue:60/255.0 alpha:1.0] forState:UIControlStateNormal];
            button.userInteractionEnabled = YES;
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
