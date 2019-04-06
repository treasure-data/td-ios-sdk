//
//  TDUtils.m
//  TreasureData
//
//  Created by Huy Le on 3/1/18.
//  Copyright © 2018 Treasure Data. All rights reserved.
//

#import "TDUtils.h"
#import "Constants.h"
#import "KeenClientTD/KeenClient.h"

@implementation TDUtils

+ (NSString *)requireNonBlank:(NSString *)str
                 defaultValue:(NSString *)defaultStr
                      message:(NSString *)message {
    if ([str length] == 0) {
        KCLog(@"%@", message);
        return defaultStr;
    } else {
        return str;
    }
}

+ (NSDictionary *)markAsAppLifecycleEvent:(NSDictionary *)event {
    NSMutableDictionary *appLifecycleEvent = [NSMutableDictionary dictionaryWithDictionary:event];
    appLifecycleEvent[TDEventClassKey] = TDEventClassAppLifecycle;
    return [NSDictionary dictionaryWithDictionary:appLifecycleEvent];
}


+ (NSDictionary *)markAsAuditEvent:(NSDictionary *)event {
    NSMutableDictionary *auditEvent = [NSMutableDictionary dictionaryWithDictionary:event];
    auditEvent[TDEventClassKey] = TDEventClassAudit;
    return [NSDictionary dictionaryWithDictionary:auditEvent];
}

+ (NSDictionary *)markAsCustomEvent:(NSDictionary *)event {
    NSMutableDictionary *auditEvent = [NSMutableDictionary dictionaryWithDictionary:event];
    auditEvent[TDEventClassKey] = TDEventClassCustom;
    return [NSDictionary dictionaryWithDictionary:auditEvent];
}

+ (NSDictionary *)markAsIAPEvent:(NSDictionary *)event {
    NSMutableDictionary *iapEvent = [NSMutableDictionary dictionaryWithDictionary:event];
    iapEvent[TDEventClassKey] = TDEventClassIAP;
    return [NSDictionary dictionaryWithDictionary:iapEvent];
}

+ (BOOL)isAppLifecycleEvent:(NSDictionary *)event {
    return [event[TDEventClassKey] isEqualToString:TDEventClassAppLifecycle];
}

+ (BOOL)isAuditEvent:(NSDictionary *)event {
    return [event[TDEventClassKey] isEqualToString:TDEventClassAudit];
}

/// Either the `TDEventClassKey` ("__td_event_class") is "custom" or absence
+ (BOOL)isCustomEvent:(NSDictionary *)event {
    return event[TDEventClassKey] == nil
            || [event[TDEventClassKey] isEqualToString:TDEventClassCustom];
}

+ (BOOL)isIAPEvent:(NSDictionary *)event {
    return [event[TDEventClassKey] isEqualToString:TDEventClassIAP];
}

+ (NSDictionary *)stripNonEventData:(NSDictionary *)event {
    NSMutableDictionary *result = [NSMutableDictionary dictionaryWithDictionary:event];
    [result removeObjectForKey:TDEventClassKey];
    return [NSDictionary dictionaryWithDictionary:result];
}

+ (BOOL)isRunningWithUnity {
    return [[NSUserDefaults standardUserDefaults] boolForKey:TD_USER_DEFAULTS_KEY_IS_UNITY];
}

+ (BOOL)isStoreKitAvailable {
    for (NSBundle *bundle in NSBundle.allFrameworks) {
        if ([bundle classNamed:@"SKStoreProductViewController"]) {
            return YES;
        }
    }
    return NO;
}

@end
