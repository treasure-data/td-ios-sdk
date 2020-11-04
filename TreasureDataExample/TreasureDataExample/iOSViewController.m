//
//  ViewController.m
//  TreasureDataExample
//
//  Created by Mitsunori Komatsu on 7/13/16.
//  Copyright © 2016 Treasure Data. All rights reserved.
//

#import "iOSViewController.h"
#import "TreasureData.h"

#import "TreasureDataExample.h"

@interface iOSViewController ()

@property (nonatomic, assign) BOOL isFormDirty;

@end

@implementation iOSViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self.apiEndpointField setText:TreasureData.sharedInstance.client.apiEndpoint];
    [self.apiKeyField setText:TreasureData.sharedInstance.client.apiKey];
    [self.cdpEndpointField setText:TreasureData.sharedInstance.cdpEndpoint];
    [self.targetDatabaseField setText:TreasureData.sharedInstance.defaultDatabase];

    [self.defaultTableField setText:[[TreasureData sharedInstance] defaultTable]];
    [self.targetTableField setText:[TreasureDataExample testTable]];
    [self.defaultTableField setText:[[TreasureData sharedInstance] defaultTable]];

    [self.customEventSwitch setOn:[[TreasureData sharedInstance] isCustomEventEnabled]];
    [self.appLifecycleEventSwitch setOn:[[TreasureData sharedInstance] isAppLifecycleEventEnabled]];
    [self.iapEventSwitch setOn:[[TreasureData sharedInstance] isInAppPurchaseEventEnabled]];

    [self customEventSwitchChanged:self.customEventSwitch];
    [self appLifecycleEventSwitchChanged:self.appLifecycleEventSwitch];
    [self iapEventSwitchChanged:self.iapEventSwitch];
    
    [TreasureDataExample requestAppTrackingAuthorizationIfNeeded];
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

- (IBAction)iapEventSwitchChanged:(id)sender {
    if ([sender isOn]) {
        self.iapEventToggleLabel.text = @"IAP Events Enabled";
        [[TreasureData sharedInstance] enableInAppPurchaseEvent];
    } else {
        self.iapEventToggleLabel.text = @"IAP Events Disabled";
        [[TreasureData sharedInstance] disableAppLifecycleEvent];
    }
}

- (IBAction)addEvent:(id)addEventButton {
    [iOSViewController shiftButton:addEventButton toState:kButtonStatePending withTitle:@"Adding Event..."];

    [self updateClientIfFormChanged];

    [[TreasureData sharedInstance]
     addEventWithCallback:@{
                            @"name": @"komamitsu",
                            @"age": @99
                            }
     table:[TreasureDataExample testTable]
     onSuccess:^(){
         dispatch_async(dispatch_get_main_queue(), ^{
             [iOSViewController shiftButton:addEventButton toState:kButtonStateSuccess withTitle:@"Add Event Success!"];
             [NSTimer scheduledTimerWithTimeInterval:1.0 repeats:NO block:^(NSTimer *timer) {
                 [iOSViewController shiftButton:addEventButton toState:kButtonStateNormal withTitle:@"Add Test Event"];
             }];
         });
     }
     onError:^(NSString* errorCode, NSString* message) {
         NSLog(@"addEvent: error. errorCode=%@, message=%@", errorCode, message);
         dispatch_async(dispatch_get_main_queue(), ^{
             NSString *text = [errorCode isEqualToString:@"custom_event_unallowed"] ? @"Add Event Denied!" : @"Add Event Error!";
             [iOSViewController shiftButton:addEventButton toState:kButtonStateFailed withTitle:text];
             [NSTimer scheduledTimerWithTimeInterval:1.0 repeats:NO block:^(NSTimer *timer) {
                 [iOSViewController shiftButton:addEventButton toState:kButtonStateNormal withTitle:@"Add Test Event"];
             }];
         });
     }];
}

- (IBAction)uploadEvents:(id)uploadButton {
    [iOSViewController shiftButton:uploadButton toState:kButtonStatePending withTitle:@"Uploading Events..."];

    [self updateClientIfFormChanged];

    [[TreasureData sharedInstance] uploadEventsWithCallback:^(){
        NSLog(@"uploadEvents: success");
        dispatch_async(dispatch_get_main_queue(), ^{
            [iOSViewController shiftButton:uploadButton toState:kButtonStateSuccess withTitle:@"Upload Events Success!"];
            [NSTimer scheduledTimerWithTimeInterval:1.5 repeats:NO block:^(NSTimer* timer) {
                [iOSViewController shiftButton:uploadButton toState:kButtonStateNormal withTitle:@"Upload Events"];
            }];
        });
    } onError:^(NSString* errorCode, NSString* message) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [iOSViewController shiftButton:uploadButton toState:kButtonStateFailed withTitle:@"Upload Events Error!"];
            [NSTimer scheduledTimerWithTimeInterval:1.5 repeats:NO block:^(NSTimer* timer) {
                [iOSViewController shiftButton:uploadButton toState:kButtonStateNormal withTitle:@"Upload Events"];
            }];
        });
        NSLog(@"uploadEvents: error. errorCode=%@, message=%@", errorCode, message);
    }];
}

- (IBAction)resetDeviceUniqueID:(id)sender {
    [[TreasureData sharedInstance] resetUniqId];
    [iOSViewController shiftButton:sender toState:kButtonStateSuccess withTitle:@"Device Unique ID is Reset!"];
    [NSTimer scheduledTimerWithTimeInterval:1 repeats:NO block:^(NSTimer* timer) {
        [iOSViewController shiftButton:sender toState:kButtonStateNormal withTitle:@"Reset Device Unique ID"];
    }];
}

- (void)updateClientIfFormChanged {
    if (self.isFormDirty) {
        self.isFormDirty = NO;
        [[[TreasureData sharedInstance] client] setApiKey:self.apiKeyField.text];
        [[[TreasureData sharedInstance] client] setApiEndpoint:self.apiEndpointField.text];
        [[TreasureData sharedInstance] setCdpEndpoint:self.cdpEndpointField.text];
        [[TreasureData sharedInstance] setDefaultDatabase:self.targetDatabaseField.text];
        [[TreasureData sharedInstance] setDefaultTable:self.defaultTableField.text];
        [[TreasureData sharedInstance] enableAppLifecycleEvent];
        [TreasureDataExample setTestTable:self.targetTableField.text];
    }
}

- (IBAction)fetchUserSegments:(id)sender {
    [self updateClientIfFormChanged];
    NSArray *audienceTokens = @[@"Your Profile API (Audience) Token here"];
    NSDictionary *keys = @{@"your_key": @"your_value"};
    NSDictionary<TDRequestOptionsKey, id> *options = @{
       TDRequestOptionsTimeoutIntervalKey: [NSNumber numberWithInteger: 10],
       TDRequestOptionsCachePolicyKey: [NSNumber numberWithUnsignedInteger: NSURLRequestReloadIgnoringCacheData]
    };
    [[TreasureData sharedInstance] fetchUserSegments:audienceTokens
                                                keys:keys
                                             options:options
                                   completionHandler:^(NSArray * _Nullable jsonResponse, NSError * _Nullable error) {
        NSLog(@"fetchUserSegments jsonResponse: %@", jsonResponse);
        NSLog(@"fetchUserSegments error: %@", error);
    }];
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
