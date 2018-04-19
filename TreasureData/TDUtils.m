//
//  TDUtils.m
//  TreasureData
//
//  Created by Huy Le on 3/1/18.
//  Copyright © 2018 Treasure Data. All rights reserved.
//

#import "TDUtils.h"

static NSString *const TD_EVENT_KEY_PRIVATE_AUTO_TRACKED_EVENT_TYPE = @"__is_auto_tracked_event";

@implementation TDUtils

+ (NSString *)requireNonBlank:(NSString *)str defaultValue:(NSString *)defaultStr message:(NSString *)message
{
    if ([str length] == 0) {
        NSLog(@"%@", message);
        return defaultStr;
    } else {
        return str;
    }
}

+ (NSDictionary *)markAsBuiltinEvent:(NSDictionary *)event {
    NSDictionary *augmentedEvent = [NSMutableDictionary dictionaryWithDictionary:event];
    [augmentedEvent setValue:@YES forKey:@""];
    return [NSDictionary dictionaryWithDictionary:augmentedEvent];
}

+ (BOOL)isAppLifecycleEvent:(NSDictionary *)event {
    return [[event objectForKey:TD_EVENT_KEY_PRIVATE_AUTO_TRACKED_EVENT_TYPE] boolValue];
}

+ (BOOL)isCustomEvent:(NSDictionary *)event {
    return ![TDUtils isAppLifecycleEvent:event];
}

@end
