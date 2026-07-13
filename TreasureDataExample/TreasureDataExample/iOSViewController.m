//
//  ViewController.m
//  TreasureDataExample
//
//  Created by Mitsunori Komatsu on 7/13/16.
//  Copyright © 2016 Treasure Data. All rights reserved.
//

#import "iOSViewController.h"
@import TreasureData;

#import "TreasureDataExample.h"

@interface iOSViewController ()

@property (nonatomic, assign) BOOL isFormDirty;

@end

@implementation iOSViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self.apiEndpointField setText:TreasureData.sharedInstance.apiEndpoint];
    self.apiEndpointField.delegate = self;
    // v2: apiKey is no longer publicly readable (set at initialization only).
    self.apiKeyField.delegate = self;
    [self.cdpEndpointField setText:TreasureData.sharedInstance.cdpEndpoint];
    self.cdpEndpointField.delegate = self;
    [self.targetDatabaseField setText:TreasureData.sharedInstance.defaultDatabase];
    self.targetDatabaseField.delegate = self;

    [self.defaultTableField setText:[[TreasureData sharedInstance] defaultTable]];
    self.defaultTableField.delegate = self;
    [self.targetTableField setText:[TreasureDataExample testTable]];
    self.targetTableField.delegate = self;
    [self.defaultTableField setText:[[TreasureData sharedInstance] defaultTable]];
    self.defaultTableField.delegate = self;

    [self.customEventSwitch setOn:[[TreasureData sharedInstance] isCustomEventEnabled]];
    [self.appLifecycleEventSwitch setOn:[[TreasureData sharedInstance] isAppLifecycleEventEnabled]];
    // TODO(v2 examples): IAP tracking was removed in v2.0. Remove the iapEventSwitch
    // / iapEventToggleLabel outlets and this UI from Main.storyboard in Xcode.
    
    [self.defaultValueField setText:@"Test Default Value"];
    self.defaultValueField.delegate = self;
    [self.defaultValueKeyField setText:@"default_value"];
    self.defaultValueKeyField.delegate = self;
    
    self.defaultValueTargetTableField.delegate = self;
    self.defaultValueTargetDatabaseField.delegate = self;

    [self customEventSwitchChanged:self.customEventSwitch];
    [self appLifecycleEventSwitchChanged:self.appLifecycleEventSwitch];
    // TODO(v2 examples): remove iapEventSwitchChanged: (IAP removed in v2.0).
    
    [TreasureDataExample requestAppTrackingAuthorizationIfNeeded];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)formChanged:(UITextField *)sender {
    self.isFormDirty = YES;
}

#pragma mark - GDPR

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

// TODO(v2 examples): IAP tracking was removed in v2.0. This action is kept as a
// no-op so the existing storyboard connection doesn't crash; remove the switch,
// label, and this method from the project (and Main.storyboard) in Xcode.
- (IBAction)iapEventSwitchChanged:(id)sender {
    self.iapEventToggleLabel.text = @"IAP tracking removed in v2.0";
}

#pragma mark - Actions

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
        // v2: apiKey is fixed at initialization (no public setter). apiEndpoint
        // is now a property directly on TreasureData (was on `client`).
        [[TreasureData sharedInstance] setApiEndpoint:self.apiEndpointField.text];
        [[TreasureData sharedInstance] setCdpEndpoint:self.cdpEndpointField.text];
        [[TreasureData sharedInstance] setDefaultDatabase:self.targetDatabaseField.text];
        [[TreasureData sharedInstance] setDefaultTable:self.defaultTableField.text];
        [[TreasureData sharedInstance] enableAppLifecycleEvent];
        [TreasureDataExample setTestTable:self.targetTableField.text];
    }
}

#pragma mark - Default Values

- (NSString *)defaultValueTargetTable {
    return [_defaultValueTargetTableField.text isEqual: @""] ? nil : _defaultValueTargetTableField.text;
}

- (NSString *)defaultValueTargetDatabase {
    return [_defaultValueTargetDatabaseField.text isEqual: @""] ? nil : _defaultValueTargetDatabaseField.text;
}

- (IBAction)setDefaultValueButtonTapped:(id)sender {
    [[TreasureData sharedInstance] setDefaultValue:_defaultValueField.text forKey:_defaultValueKeyField.text database:[self defaultValueTargetDatabase] table:[self defaultValueTargetTable]];
}

- (IBAction)getDefaultValueButtonTapped:(id)sender {
    NSString* defaultValue = [[TreasureData sharedInstance] defaultValueForKey:_defaultValueKeyField.text database:[self defaultValueTargetDatabase] table:[self defaultValueTargetTable]];
    UIAlertController *alertVC = [UIAlertController alertControllerWithTitle:@"Default Value" message: defaultValue preferredStyle:UIAlertControllerStyleAlert];
    [alertVC addAction: [UIAlertAction actionWithTitle:@"Ok" style:UIAlertActionStyleDefault handler:nil]];
    [self showViewController:alertVC sender:nil];
}

- (IBAction)removeDefaultValueButtonTapped:(id)sender {
    [[TreasureData sharedInstance] removeDefaultValueForKey:_defaultValueKeyField.text database:[self defaultValueTargetDatabase] table:[self defaultValueTargetTable]];
}

#pragma mark - Profile API

- (IBAction)fetchUserSegments:(id)sender {
    [self updateClientIfFormChanged];
    NSArray *audienceTokens = @[@"Your Profile API (Audience) Token here"];
    NSDictionary *keys = @{@"your_key": @"your_value"};
    NSDictionary<NSString *, id> *options = @{
       TDRequestOptionsKey.timeoutInterval: [NSNumber numberWithInteger: 10],
       TDRequestOptionsKey.cachePolicy: [NSNumber numberWithUnsignedInteger: NSURLRequestReloadIgnoringCacheData]
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

#pragma MARK: - UITextFieldDelegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return true;
}

@end
