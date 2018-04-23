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
@property (weak, nonatomic) IBOutlet UIButton *addEventButton;
@property (weak, nonatomic) IBOutlet UIButton *uploadButton;
@property (weak, nonatomic) IBOutlet UITextField *autoTrackTableField;

@property (weak, nonatomic) IBOutlet UILabel *customEventToggleLabel;
@property (weak, nonatomic) IBOutlet UILabel *appLifecycleEventToggleLabel;
@property (weak, nonatomic) IBOutlet UISwitch *eventCollectingSwitch;
@property (weak, nonatomic) IBOutlet UISwitch *autoEventSwitch;

- (IBAction)formChanged:(UITextField *)sender;
- (IBAction)eventCollectingSwitchChanged:(UISwitch *)sender;
- (IBAction)autoEventSwitchChanged:(UISwitch *)sender;

- (IBAction)addEvent:(id)sender;
- (IBAction)uploadEvents:(id)sender;

@end
