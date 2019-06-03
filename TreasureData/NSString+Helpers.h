//
//  NSString+Helpers.h
//  TreasureData
//
//  Created by Tung Vu on 6/3/19.
//  Copyright © 2019 Treasure Data. All rights reserved.
//

static NSString *toString(id object) {
    return [NSString stringWithFormat: @"%@", object];
}

static NSString *urlEncode(id object) {
    NSString *string = toString(object);
    return [string stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet alphanumericCharacterSet]];
}
