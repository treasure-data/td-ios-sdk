//
//  TDUtils.swift
//  TreasureData
//
//  Faithful port of the Objective-C TDUtils. Kept as an @objc class named
//  `TDUtils` (and exposing the event-class constants as class properties) so the
//  remaining Objective-C callers and tests keep working.
//

import Foundation

/// Process-global debug-logging flag. Off by default.
enum TDLogging {
    static var isEnabled = false
}

/// Log only when debug logging is enabled.
func KCLogString(_ message: String) {
    if TDLogging.isEnabled {
        NSLog("%@", message)
    }
}

@objc(TDUtils)
public class TDUtils: NSObject {

    // Event-class marker constants. These live under the private "__td_event_class"
    // key and are stripped before an event is buffered.
    @objc public static let eventClassKey = "__td_event_class"
    @objc public static let eventClassCustom = "custom"
    @objc public static let eventClassAppLifecycle = "app_lifecycle"
    @objc public static let eventClassAudit = "audit"

    // Mirrors TD_USER_DEFAULTS_KEY_IS_UNITY in TDConstants.h (still ObjC; the
    // #define isn't visible to Swift, so the literal is duplicated here).
    private static let userDefaultsKeyIsUnity = "TDIsUnity"

    @objc public class func requireNonBlank(_ str: String?,
                                            defaultValue defaultStr: String?,
                                            message: String?) -> String? {
        if (str?.count ?? 0) == 0 {
            if let message = message { KCLogString(message) }
            return defaultStr
        }
        return str
    }

    @objc public class func markAsAppLifecycleEvent(_ event: [String: Any]) -> [String: Any] {
        return mark(event, as: eventClassAppLifecycle)
    }

    @objc public class func markAsAuditEvent(_ event: [String: Any]) -> [String: Any] {
        return mark(event, as: eventClassAudit)
    }

    @objc public class func markAsCustomEvent(_ event: [String: Any]) -> [String: Any] {
        return mark(event, as: eventClassCustom)
    }

    private class func mark(_ event: [String: Any], as eventClass: String) -> [String: Any] {
        var marked = event
        marked[eventClassKey] = eventClass
        return marked
    }

    @objc public class func isAppLifecycleEvent(_ event: [String: Any]) -> Bool {
        return (event[eventClassKey] as? String) == eventClassAppLifecycle
    }

    @objc public class func isAuditEvent(_ event: [String: Any]) -> Bool {
        return (event[eventClassKey] as? String) == eventClassAudit
    }

    /// Either the event-class key ("__td_event_class") is "custom" or absent.
    @objc public class func isCustomEvent(_ event: [String: Any]) -> Bool {
        guard let eventClass = event[eventClassKey] as? String else { return true }
        return eventClass == eventClassCustom
    }

    @objc public class func stripNonEventData(_ event: [String: Any]) -> [String: Any] {
        var result = event
        result.removeValue(forKey: eventClassKey)
        return result
    }

    @objc public class func isRunningWithUnity() -> Bool {
        return UserDefaults.standard.bool(forKey: userDefaultsKeyIsUnity)
    }
}
