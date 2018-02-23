//
//  TDConfiguration.h
//  TreasureData
//
//  Created by Huy Le on 1/31/18.
//  Copyright © 2018 Huy Le. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface TDConfiguration : NSObject

@property (nonatomic, copy, readwrite, nonnull) NSString *endpoint;
@property (nonatomic, copy, readwrite, nonnull) NSString *encryptionKey;
@property (nonatomic, copy, readwrite, nonnull) NSString *apiKey;
@property (nonatomic, copy, readwrite, nonnull) NSString *defaultDatabase;
@property (nonatomic, copy, readwrite, nonnull) NSString *defaultTable;

@property (nonatomic, assign) BOOL autoAppendUniqId;
@property (nonatomic, assign) BOOL autoAppendRecordUUID;
@property (nonatomic, strong, nullable) NSString *autoAppendRecordUUIDColumn;
@property (nonatomic, assign) BOOL autoAppendModelInformation;
@property (nonatomic, assign) BOOL autoAppendAppInformation;
@property (nonatomic, assign) BOOL autoAppendLocaleInformation;
@property (nonatomic, assign) BOOL shouldRetryUploading;
@property (nonatomic, assign) BOOL enableServerSideUploadTimestamp;
@property (nonatomic, strong, nullable) NSString *serverTimestampColumn;


- (BOOL)isValid;
- (NSArray<NSString *> * _Nonnull)violations;


@end
