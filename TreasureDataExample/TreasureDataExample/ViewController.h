//
//  ViewController.h
//  TreasureDataExample
//
//  Created by Mitsunori Komatsu on 7/13/16.
//  Copyright © 2016 Treasure Data. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface ViewController : UITableViewController

@property (weak, nonatomic) IBOutlet UITextField *apiEndpointField;
@property (weak, nonatomic) IBOutlet UITextField *apiKeyField;
@property (weak, nonatomic) IBOutlet UITextField *cdpEndpointField;
@property (weak, nonatomic) IBOutlet UITextField *targetDatabaseField;
@property (weak, nonatomic) IBOutlet UITextField *targetTableField;
@property (weak, nonatomic) IBOutlet UITextField *defaultTableField;

@property (weak, nonatomic) IBOutlet UILabel *customEventToggleLabel;
@property (weak, nonatomic) IBOutlet UILabel *appLifecycleEventToggleLabel;
@property (weak, nonatomic) IBOutlet UILabel *iapEventToggleLabel;

@property (weak, nonatomic) IBOutlet UITextField *defaultValueField;
@property (weak, nonatomic) IBOutlet UITextField *defaultValueKeyField;

@property (weak, nonatomic) IBOutlet UISwitch *customEventSwitch;
@property (weak, nonatomic) IBOutlet UISwitch *appLifecycleEventSwitch;
@property (weak, nonatomic) IBOutlet UISwitch *iapEventSwitch;

- (IBAction)formChanged:(UITextField *)sender;
- (IBAction)customEventSwitchChanged:(UISwitch *)sender;
- (IBAction)appLifecycleEventSwitchChanged:(UISwitch *)sender;
- (IBAction)iapEventSwitchChanged:(id)sender;

- (IBAction)addEvent:(id)sender;
- (IBAction)uploadEvents:(id)sender;
- (IBAction)resetDeviceUniqueID:(id)sender;

- (void)updateClientIfFormChanged;

@end
