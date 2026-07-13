//
//  TDRequestOptionsKey.swift
//  TreasureData
//
//  Keys for the `options` dictionary of `fetchUserSegments(...)`. Swift port of
//  the former TDRequestOptionsKey.h. The raw string values are unchanged so
//  existing callers (and the on-the-wire behavior) are preserved.
//

import Foundation

/// Option keys for `fetchUserSegments`. See `URLRequest` for possible values of
/// each option.
@objc(TDRequestOptionsKey)
public class TDRequestOptionsKey: NSObject {

    /// Timeout interval for the request (`NSNumber` seconds).
    @objc public static let timeoutInterval = "TDRequestOptionsTimeoutIntervalKey"

    /// Cache policy for the request (`NSNumber` of `URLRequest.CachePolicy` raw value).
    @objc public static let cachePolicy = "TDRequestOptionsCachePolicyKey"
}
