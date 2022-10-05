//
//  TDUtils.h
//  TreasureData
//
//  Created by Huy Le on 3/1/18.
//  Copyright © 2018 Treasure Data. All rights reserved.
//

#import <Foundation/Foundation.h>

static NSString *const TDEventClassKey = @"__td_event_class";
static NSString *const TDEventClassCustom = @"custom";
static NSString *const TDEventClassAppLifecycle = @"app_lifecycle";
static NSString *const TDEventClassAudit = @"audit";
static NSString *const TDEventClassIAP = @"iap";

@interface TDUtils : NSObject

+ (NSString *)requireNonBlank:(NSString *)str defaultValue:(NSString *)defaultStr message:(NSString *)message;

+ (NSDictionary *)markAsAppLifecycleEvent:(NSDictionary *)event;

+ (NSDictionary *)markAsAuditEvent:(NSDictionary *)event;

+ (NSDictionary *)markAsCustomEvent:(NSDictionary *)event;

+ (NSDictionary *)markAsIAPEvent:(NSDictionary *)event;

+ (BOOL)isAuditEvent:(NSDictionary *)event;

+ (BOOL)isAppLifecycleEvent:(NSDictionary *)event;

+ (BOOL)isCustomEvent:(NSDictionary *)event;

+ (BOOL)isIAPEvent:(NSDictionary *)event;

+ (NSDictionary *)stripNonEventData:(NSDictionary *)event;

+ (BOOL)isRunningWithUnity;

+ (BOOL)isStoreKitAvailable;

@end
