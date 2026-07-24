//
//  TreasureDataEngage.swift
//  TreasureDataEngage
//
//  The TDEngage / campaign-WebView layer, built on top of the core
//  `TreasureData` SDK. iOS-only (WebKit is unavailable on tvOS). Module-wide
//  shared helpers live here.
//

#if canImport(WebKit)
import Foundation

/// Debug-logging gate for the Engage module. Core's logger is internal to the
/// `TreasureData` module, so Engage keeps its own flag rather than widening
/// core's public surface for a debug helper. Off by default.
enum EngageLog {
    static var isEnabled = false
    static func log(_ message: @autoclosure () -> String) {
        if isEnabled { NSLog("%@", message()) }
    }
}
#endif
