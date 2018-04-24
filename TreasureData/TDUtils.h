//
//  TDUtils.h
//  TreasureData
//
//  Created by Huy Le on 3/1/18.
//  Copyright © 2018 Treasure Data. All rights reserved.
//

@interface TDUtils : NSObject

+ (NSString *)requireNonBlank:(NSString *)str defaultValue:(NSString *)defaultStr message:(NSString *)message;

+ (NSDictionary *)markAsAppLifecycleEvent:(NSDictionary *)event;

+ (NSDictionary *)markAsAuditEvent:(NSDictionary *)event;

+ (NSDictionary *)markAsCustomEvent:(NSDictionary *)event;

+ (BOOL)isAuditEvent:(NSDictionary *)event;

+ (BOOL)isAppLifecycleEvent:(NSDictionary *)event;

+ (BOOL)isCustomEvent:(NSDictionary *)event;


@end
