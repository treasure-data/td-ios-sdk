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
@property (weak, nonatomic) IBOutlet UITextField *targetDatabaseField;
@property (weak, nonatomic) IBOutlet UITextField *targetTableField;
@property (weak, nonatomic) IBOutlet UITextField *defaultTableField;

@property (weak, nonatomic) IBOutlet UILabel *customEventToggleLabel;
@property (weak, nonatomic) IBOutlet UILabel *appLifecycleEventToggleLabel;
@property (weak, nonatomic) IBOutlet UISwitch *customEventSwitch;
@property (weak, nonatomic) IBOutlet UISwitch *appLifecycleEventSwitch;

- (IBAction)formChanged:(UITextField *)sender;
- (IBAction)customEventSwitchChanged:(UISwitch *)sender;
- (IBAction)appLifecycleEventSwitchChanged:(UISwitch *)sender;

- (IBAction)addEvent:(id)sender;
- (IBAction)uploadEvents:(id)sender;
- (IBAction)resetDeviceUniqueID:(id)sender;

@end
