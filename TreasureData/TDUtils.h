//
//  TDUtils.h
//  TreasureData
//
//  Created by Huy Le on 3/1/18.
//  Copyright © 2018 Huy Le. All rights reserved.
//

@interface TDUtils : NSObject

+ (NSString *)requireNonBlank:(NSString *)str defaultValue:(NSString *)defaultStr message:(NSString *)message;

@end
