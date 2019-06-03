//
//  TDRequestOptionsKey.h
//  TreasureData
//
//  Created by Tung Vu on 6/3/19.
//  Copyright © 2019 Tung Vu. All rights reserved.
//

#if UIKIT_STRING_ENUMS
typedef NSString * TDRequestOptionsKey NS_TYPED_ENUM;
#else
typedef NSString * TDRequestOptionsKey;
#endif

#if UIKIT_STRING_ENUMS
// Timeout interval for request
static TDRequestOptionsKey const _Nonnull TDRequestOptionsTimeoutIntervalKey NS_SWIFT_NAME(timeoutInterval) = @"TDRequestOptionsTimeoutIntervalKey";
// Cache policy for request. See possible values in NSURLRequest.CachePolicy
static TDRequestOptionsKey const _Nonnull TDRequestOptionsCachePolicyKey  NS_SWIFT_NAME(cachePolicy) = @"TDRequestOptionsCachePolicyKey";
#else
// Timeout interval for request
static TDRequestOptionsKey const _Nonnull TDRequestOptionsTimeoutIntervalKey = @"TDRequestOptionsTimeoutIntervalKey";
// Cache policy for request. See possible values in NSURLRequestCachePolicy
static TDRequestOptionsKey const _Nonnull TDRequestOptionsCachePolicyKey = @"TDRequestOptionsCachePolicyKey";
#endif
