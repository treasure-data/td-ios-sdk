//
//  TreasureData.swift
//  TreasureData
//
//  Faithful Swift port of the Objective-C `TreasureData` façade (TreasureData.m).
//  Behavior is preserved 1:1; the only structural change is that this talks to
//  the `EventEngine` seam (default: `KeenEventEngine`) instead of holding a
//  `TDClient` directly. Kept as an @objc class named `TreasureData` so the
//  existing Objective-C callers and tests keep working.
//
//  Created by Mitsunori Komatsu on 5/19/14.
//  Copyright (c) 2014 Treasure Data Inc. All rights reserved.
//

import Foundation
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AdSupport)
import AdSupport
#endif

// MARK: - Public callback typealiases (match TreasureData.h)

/// Generic success callback block's definition. (The ObjC typedef spells it
/// `SuccessHander`; kept verbatim so nothing downstream needs renaming.)
public typealias SuccessHander = () -> Void

/// Generic error callback block's definition. Known error codes: `init_error`,
/// `invalid_param`, `invalid_event`, `data_conversion`, `storage_error`,
/// `network_error`, `server_response`, `unknown_error`.
public typealias ErrorHandler = (_ errorCode: String, _ errorMessage: String?) -> Void

@objc(TreasureData)
open class TreasureData: NSObject {

    // MARK: - Constants (mirror TreasureData.m file-scope statics)

    private enum C {
        static let defaultApiEndpoint = "https://us01.records.in.treasuredata.com"
        static let defaultCdpEndpoint = "https://cdp.in.treasuredata.com"
        static let storageKeyOfUuid = "td_sdk_uuid"
        static let storageKeyOfFirstRun = "td_sdk_first_run"
        static let keyOfLocalTimestamp = "time"
        static let keyOfUuid = "td_uuid"
        static let keyOfAdvertisingIdentifier = "td_maid"
        static let keyOfDevice = "td_device"
        static let keyOfModel = "td_model"
        static let keyOfOsVer = "td_os_ver"
        static let keyOfOsType = "td_os_type"
        static let keyOfAppVer = "td_app_ver"
        static let keyOfAppVerNum = "td_app_ver_num"
        static let keyOfPreviousAppVer = "td_app_previous_ver"
        static let keyOfPreviousAppVerNum = "td_app_previous_ver_num"
        static let keyOfLocaleCountry = "td_locale_country"
        static let keyOfLocaleLang = "td_locale_lang"
        static let keyOfSessionId = "td_session_id"
        static let keyOfSessionEvent = "td_session_event"
        static let sessionEventStart = "start"
        static let sessionEventEnd = "end"
        static let errorDomain = "com.treasuredata"
    }

    // Mirror TDConstants.h #define macros (NOT visible to Swift, so inlined).
    private enum TDC {
        static let columnEvent = "td_ios_event"                                  // TD_COLUMN_EVENT
        static let columnUnityEvent = "td_unity_event"                           // TD_COLUMN_UNITY_EVENT
        static let eventAppOpened = "TD_IOS_APP_OPEN"                            // TD_EVENT_APP_OPEN
        static let eventAppInstalled = "TD_IOS_APP_INSTALL"                      // TD_EVENT_APP_INSTALL
        static let eventAppUpdated = "TD_IOS_APP_UPDATE"                         // TD_EVENT_APP_UPDATE
        static let eventAuditResetUuid = "forget_device_uuid"                    // TD_EVENT_AUDIT_RESET_UUID
        static let userDefaultsKeyTrackedAppVersion = "TDTrackedAppVersion"      // TD_USER_DEFAULTS_KEY_TRACKED_APP_VERSION
        static let userDefaultsKeyTrackedAppBuild = "TDTrackedAppBuild"          // TD_USER_DEFAULTS_KEY_TRACKED_APP_BUILD
        static let userDefaultsKeyCustomEventEnabled = "TDCustomEventEnabled"    // TD_USER_DEFAULTS_KEY_CUSTOM_EVENT_ENABLED
        static let userDefaultsKeyAppLifecycleEventEnabled = "TDAppLifecycleEventEnabled" // TD_USER_DEFAULTS_KEY_APP_LIFECYCLE_EVENT_ENABLED
        static let errorCustomEventDisabled = "custom_event_disabled"            // TD_ERROR_CUSTOM_EVENT_DISABLED
        static let defaultDatabase = "td"                                        // TD_DEFAULT_DATABASE
        static let defaultTable = "td_ios"                                       // TD_DEFAULT_TABLE
    }

    // Mirror KeenClient.h #define error codes (NOT visible to Swift).
    private enum ErrorCode {
        static let invalidParam = "invalid_param"  // ERROR_CODE_INVALID_PARAM
        static let initError = "init_error"        // ERROR_CODE_INIT_ERROR
        static let unknownError = "unknown_error"
    }

    // MARK: - Static state (mirror TreasureData.m file-scope statics)

    private static var isTraceLoggingEnabled = false
    private static var isEventCompressionEnabled = true
    private static var sharedInstanceStorage: TreasureData?
    private static var globalSession: Session?
    private static var sessionTimeoutMilli: Int = -1
    private static var initializeOnceToken = false

    // MARK: - Engine seam (internal — replaces the former public `client`)

    /// The buffering/upload engine. Internal so same-module tests can inject a
    /// custom engine; not part of the documented public API and hidden from ObjC.
    let engine: EventEngine

    /// The injectable URLSession, forwarded to the engine (tests stub the network).
    @objc public var session: URLSession {
        get { engine.session }
        set { engine.session = newValue }
    }

    // MARK: - Public config forwarded to the engine

    @objc public var apiEndpoint: String {
        get { engine.apiEndpoint }
        set { engine.apiEndpoint = newValue }
    }

    @objc public var uploadRetryCount: Int {
        get { engine.retry.maxCount }
        set { engine.retry.maxCount = newValue }
    }

    @objc public var uploadRetryIntervalBase: Int {
        get { engine.retry.intervalBase }
        set { engine.retry.intervalBase = newValue }
    }

    /// (Misspelling preserved intentionally — consumers/tests depend on it.)
    @objc public var uploadRetryIntervalCoeficient: Int {
        get { engine.retry.intervalCoefficient }
        set { engine.retry.intervalCoefficient = newValue }
    }

    /// Whether the client's IP is tracked. Exposed so tests can assert it.
    @objc public var enableTrackingIP: Bool {
        get { engine.isTrackingIP }
        set { engine.isTrackingIP = newValue }
    }

    /// Whether upload retrying is enabled. Exposed so tests can assert/tune it.
    @objc public var enableRetryUploadingFlag: Bool {
        get { engine.retry.isEnabled }
        set { engine.retry.isEnabled = newValue }
    }

    // MARK: - Public properties (from TreasureData.h)

    @objc public var defaultDatabase: String?
    @objc public var defaultTable: String?
    @objc public var cdpEndpoint: String?

    // MARK: - Private / internal state

    private var autoAppendLocalTimestampColumn: String?
    private var autoAppendUniqId = false
    private var autoAppendModelInformation = false
    private var autoAppendAppInformation = false
    private var autoAppendLocaleInformation = false
    private var sessionId: String?
    private var autoAppendRecordUUIDColumn: String?
    private var autoAppendAdvertisingIdColumn: String?

    private var customEventEnabled = false
    private var appLifecycleEventEnabled = false

    private let addEventQueue = DispatchQueue(label: "com.treasuredata.add_event")

    private var _UUID: String?
    private var _defaultValues: [String: [String: Any]]?

    // MARK: - Testing hooks
    //
    // These exist only so the test suite can drive the class without subclassing
    // it (a Swift @objc class in a static library can't be subclassed from ObjC).
    // In production they are inert: the mock* properties default to nil, and
    // capture is off unless `capturingEvents` is enabled.

    /// When non-nil, overrides the value returned by `getAppVersion()`.
    @objc public var mockAppVersion: String?
    /// When non-nil, overrides the value returned by `getBuildNumber()`.
    @objc public var mockBuildNumber: String?
    /// When set, `getTrackedAppVersion()` returns this instead of UserDefaults.
    @objc public var mockTrackedAppVersion: String?
    /// When set, `getTrackedBuildNumber()` returns this instead of UserDefaults.
    @objc public var mockTrackedBuildNumber: String?

    /// Enables the `capturedEvents` buffer. Off in production.
    @objc public var capturingEvents = false
    /// Enriched events recorded when `capturingEvents` is enabled (testing).
    @objc public private(set) var capturedEvents: [[String: Any]] = []

    // MARK: - Initialization

    @objc(initWithApiKey:)
    public convenience init(apiKey: String) {
        self.init(apiKey: apiKey, apiEndpoint: TreasureData.C.defaultApiEndpoint)
    }

    @objc(initWithApiKey:apiEndpoint:)
    public convenience init(apiKey: String, apiEndpoint: String) {
        self.init(engine: SwiftEventEngine(apiKey: apiKey, apiEndpoint: apiEndpoint))
    }

    /// Designated initializer. `engine` is injectable for testing; production
    /// callers get a `KeenEventEngine` via the convenience initializers above.
    /// Internal (Swift-only) so the protocol stays out of the public/ObjC surface.
    init(engine: EventEngine) {
        self.engine = engine
        super.init()

        enableAutoAppendLocalTimestamp()

        let defaults = UserDefaults.standard
        if defaults.object(forKey: TDC.userDefaultsKeyCustomEventEnabled) != nil {
            self.customEventEnabled = defaults.bool(forKey: TDC.userDefaultsKeyCustomEventEnabled)
        } else {
            // Unless explicitly disabled, custom events are allowed.
            self.customEventEnabled = true
        }
        // Unlike custom events, app lifecycle events must be explicitly enabled.
        self.appLifecycleEventEnabled = defaults.bool(forKey: TDC.userDefaultsKeyAppLifecycleEventEnabled)

        observeLifecycleEvents()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Tracking events

    @objc(addEvent:table:)
    @discardableResult
    public func addEvent(_ record: [String: Any], table: String) -> [String: Any]? {
        return addEventWithCallback(record, database: defaultDatabase, table: table,
                                    onSuccess: nil, onError: nil)
    }

    @objc(addEvent:database:table:)
    @discardableResult
    public func addEvent(_ record: [String: Any], database: String?, table: String?) -> [String: Any]? {
        return addEventWithCallback(record, database: database, table: table, onSuccess: nil, onError: nil)
    }

    @objc(addEventWithCallback:table:onSuccess:onError:)
    @discardableResult
    public func addEventWithCallback(_ record: [String: Any],
                                     table: String,
                                     onSuccess: SuccessHander?,
                                     onError: ErrorHandler?) -> [String: Any]? {
        return addEventWithCallback(record, database: defaultDatabase, table: table,
                                    onSuccess: onSuccess, onError: onError)
    }

    @objc(addEventWithCallback:database:table:onSuccess:onError:)
    @discardableResult
    open func addEventWithCallback(_ record: [String: Any],
                                   database: String?,
                                   table: String?,
                                   onSuccess: SuccessHander?,
                                   onError: ErrorHandler?) -> [String: Any]? {
        var event: [String: Any]?

        // Fire callbacks on the main thread (dispatch there if not already).
        let success: EngineSuccessHandler = {
            guard let onSuccess = onSuccess else { return }
            if Thread.isMainThread { onSuccess() }
            else { DispatchQueue.main.sync { onSuccess() } }
        }
        let error: (String, String?) -> Void = { errorCode, errorMessage in
            guard let onError = onError else { return }
            if Thread.isMainThread { onError(errorCode, errorMessage) }
            else { DispatchQueue.main.sync { onError(errorCode, errorMessage) } }
        }

        // Serial queue as this may do intensive work; dispatch_sync preserves the
        // synchronous return of the enriched record.
        addEventQueue.sync {
            if TDUtils.isCustomEvent(record) && !isCustomEventEnabled() {
                error(TDC.errorCustomEventDisabled,
                      "You configured to deny tracking of custom events. This is a persistent setting, it will unharmfully drop the any custom events called through `addEvent...` methods family.")
                return
            }

            if TDUtils.isAppLifecycleEvent(record) && !isAppLifecycleEventEnabled() {
                return
            }

            if let database = database, let table = table {
                let pattern = "^[0-9a-z_]{3,255}$"
                let regex = try? NSRegularExpression(pattern: pattern, options: [])
                let dbMatches = regex?.firstMatch(in: database, options: [],
                                                  range: NSRange(location: 0, length: (database as NSString).length)) != nil
                let tableMatches = regex?.firstMatch(in: table, options: [],
                                                     range: NSRange(location: 0, length: (table as NSString).length)) != nil
                if !(dbMatches && tableMatches) {
                    let errMsg = "database and table need to be consist of lower letters, numbers or '_': database=\(database), table=\(table)"
                    KCLogString(errMsg)
                    error(ErrorCode.invalidParam, errMsg)
                } else {
                    let tag = "\(database).\(table)"
                    let enrichedRecord = enrichEventRecord(record, database: database, table: table)
                    engine.addEvent(enrichedRecord, collection: tag, onSuccess: success, onError: { errorCode, errorMessage in
                        error(errorCode ?? ErrorCode.unknownError, errorMessage)
                    })
                    event = enrichedRecord
                    if capturingEvents { capturedEvents.append(enrichedRecord) }
                }
            } else {
                let errMsg = "database or table is nil: database=\(database ?? "(null)"), table=\(table ?? "(null)")"
                KCLogString(errMsg)
                error(ErrorCode.invalidParam, errMsg)
            }
        }

        return event
    }

    // MARK: - Enrichment

    private func enrichEventRecord(_ origRecord: [String: Any], database: String, table: String) -> [String: Any] {
        var enrichedRecord = prependDefaultValues(origRecord, database: database, table: table)
        enrichedRecord = TDUtils.stripNonEventData(enrichedRecord)

        if autoAppendLocalTimestampColumn != nil { enrichedRecord = appendLocalTimestamp(enrichedRecord) }
        if autoAppendUniqId { enrichedRecord = appendUniqId(enrichedRecord) }
        if autoAppendRecordUUIDColumn != nil { enrichedRecord = appendRecordUUID(enrichedRecord) }
        if autoAppendModelInformation { enrichedRecord = appendModelInformation(enrichedRecord) }
        if TreasureData.globalSession != nil || sessionId != nil { enrichedRecord = appendSessionId(enrichedRecord) }
        if autoAppendAppInformation { enrichedRecord = appendAppInformation(enrichedRecord) }
        if autoAppendLocaleInformation { enrichedRecord = appendLocaleInformation(enrichedRecord) }
        if autoAppendAdvertisingIdColumn != nil { enrichedRecord = appendAdvertisingIdentifier(enrichedRecord) }
        return enrichedRecord
    }

    private func prependDefaultValues(_ origRecord: [String: Any], database: String, table: String) -> [String: Any] {
        guard let defaultValues = _defaultValues else { return origRecord }
        var record = [String: Any]()
        // Precedence (low -> high), original record last:
        //   "."  ->  "db."  ->  ".table"  ->  "db.table"  ->  origRecord
        if let d = defaultValues["."] { record.merge(d) { _, new in new } }
        if let d = defaultValues["\(database)."] { record.merge(d) { _, new in new } }
        if let d = defaultValues[".\(table)"] { record.merge(d) { _, new in new } }
        if let d = defaultValues["\(database).\(table)"] { record.merge(d) { _, new in new } }
        record.merge(origRecord) { _, new in new }
        return record
    }

    @objc public func getUUID() -> String {
        if _UUID == nil {
            _UUID = UserDefaults.standard.string(forKey: TreasureData.C.storageKeyOfUuid)
        }
        if _UUID == nil {
            let uuid = UUID().uuidString
            _UUID = uuid
            UserDefaults.standard.set(uuid, forKey: TreasureData.C.storageKeyOfUuid)
        }
        return _UUID!
    }

    private func appendLocalTimestamp(_ origRecord: [String: Any]) -> [String: Any] {
        var record = origRecord
        // ObjC used (int)now.timeIntervalSince1970 wrapped in NSNumber.
        let timestamp = Int32(Date().timeIntervalSince1970)
        if let column = autoAppendLocalTimestampColumn {
            record[column] = NSNumber(value: timestamp)
        }
        return record
    }

    private func appendUniqId(_ origRecord: [String: Any]) -> [String: Any] {
        var record = origRecord
        record[TreasureData.C.keyOfUuid] = getUUID()
        return record
    }

    private func appendRecordUUID(_ origRecord: [String: Any]) -> [String: Any] {
        let uuid = UUID().uuidString
        var record = origRecord
        if let column = autoAppendRecordUUIDColumn { record[column] = uuid }
        return record
    }

    private func appendModelInformation(_ origRecord: [String: Any]) -> [String: Any] {
        var record = origRecord
        #if canImport(UIKit)
        let dev = UIDevice.current
        record[TreasureData.C.keyOfDevice] = dev.model
        record[TreasureData.C.keyOfModel] = dev.model
        record[TreasureData.C.keyOfOsVer] = dev.systemVersion
        #endif
        #if os(tvOS)
        record[TreasureData.C.keyOfOsType] = "tvOS"
        #else
        record[TreasureData.C.keyOfOsType] = "iOS"
        #endif
        return record
    }

    private func appendAppInformation(_ origRecord: [String: Any]) -> [String: Any] {
        var record = origRecord
        record[TreasureData.C.keyOfAppVer] = getAppVersion()
        record[TreasureData.C.keyOfAppVerNum] = getBuildNumber()
        return record
    }

    // Overridable by the MyTreasureData test subclass — @objc dynamic in the
    // class body (not an extension) so the ObjC override takes effect.
    @objc dynamic open func getAppVersion() -> String? {
        if let mockAppVersion = mockAppVersion { return mockAppVersion }
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
    }

    @objc dynamic open func getBuildNumber() -> String? {
        if let mockBuildNumber = mockBuildNumber { return mockBuildNumber }
        return Bundle.main.infoDictionary?["CFBundleVersion"] as? String
    }

    @objc dynamic open func getTrackedAppVersion() -> String? {
        // In test mode the mock fully owns the tracked value (even nil), matching
        // the former test subclass which returned its ivar directly. Production
        // (capturingEvents == false) reads the persisted value.
        if capturingEvents { return mockTrackedAppVersion }
        return UserDefaults.standard.string(forKey: TDC.userDefaultsKeyTrackedAppVersion)
    }

    @objc dynamic open func getTrackedBuildNumber() -> String? {
        if capturingEvents { return mockTrackedBuildNumber }
        return UserDefaults.standard.string(forKey: TDC.userDefaultsKeyTrackedAppBuild)
    }

    private func appendLocaleInformation(_ origRecord: [String: Any]) -> [String: Any] {
        var record = origRecord
        let locale = Locale.current as NSLocale
        record[TreasureData.C.keyOfLocaleCountry] = locale.object(forKey: .countryCode) as? String
        record[TreasureData.C.keyOfLocaleLang] = locale.object(forKey: .languageCode) as? String
        return record
    }

    private func appendAdvertisingIdentifier(_ origRecord: [String: Any]) -> [String: Any] {
        var advertisingIdentifier: String?
        #if canImport(AdSupport)
        if NSClassFromString("ASIdentifierManager") != nil {
            advertisingIdentifier = ASIdentifierManager.shared().advertisingIdentifier.uuidString
        }
        #endif
        var record = origRecord
        // setValue:forKey: with nil is a no-op on NSMutableDictionary — an absent
        // IDFA simply doesn't add the column; match that.
        if let column = autoAppendAdvertisingIdColumn, let advertisingIdentifier = advertisingIdentifier {
            record[column] = advertisingIdentifier
        }
        return record
    }

    private func appendSessionId(_ origRecord: [String: Any]) -> [String: Any] {
        if TreasureData.globalSession != nil && sessionId != nil {
            KCLogString("instance method TreasureData#startSession(String) and static method TreasureData.startSession() are both enabled, but the instance method will be ignored.")
        }
        var record = origRecord
        if let session = TreasureData.globalSession {
            // Global (static) session wins when both are set.
            if let sessionId = session.getId() { record[TreasureData.C.keyOfSessionId] = sessionId }
        } else if let sessionId = sessionId {
            record[TreasureData.C.keyOfSessionId] = sessionId
        }
        return record
    }

    // MARK: - Upload

    /// Clears the testing `capturedEvents` buffer.
    @objc public func clearCapturedEvents() { capturedEvents.removeAll() }

    /// Test hook: synchronously drop all buffered events via the live engine.
    @objc public func clearAllBufferedEvents() { engine.deleteAllBufferedEvents() }

    @objc(uploadEventsWithCallback:onError:)
    open func uploadEventsWithCallback(_ onSuccess: SuccessHander?, onError: ErrorHandler?) {
        // The former test subclass cleared captured events at upload time; keep
        // that behavior so per-upload assertions stay correct.
        if capturingEvents { capturedEvents.removeAll() }
        engine.upload(compression: TreasureData.isEventCompressionEnabled,
                      onSuccess: onSuccess,
                      onError: { errorCode, errorMessage in
                          onError?(errorCode ?? ErrorCode.unknownError, errorMessage)
                      })
    }

    @objc public func uploadEvents() {
        uploadEventsWithCallback(nil, onError: nil)
    }

    // MARK: - Auto-append toggles

    @objc public func disableAutoAppendUniqId() { autoAppendUniqId = false }
    @objc public func enableAutoAppendUniqId() { autoAppendUniqId = true }

    @objc public func disableAutoAppendModelInformation() { autoAppendModelInformation = false }
    @objc public func enableAutoAppendModelInformation() { autoAppendModelInformation = true }

    @objc public func enableAutoAppendAppInformation() { autoAppendAppInformation = true }
    @objc public func disableAutoAppendAppInformation() { autoAppendAppInformation = false }

    @objc public func enableAutoAppendLocaleInformation() { autoAppendLocaleInformation = true }
    @objc public func disableAutoAppendLocaleInformation() { autoAppendLocaleInformation = false }

    @objc public func enableAutoAppendLocalTimestamp() {
        autoAppendLocalTimestampColumn = TreasureData.C.keyOfLocalTimestamp
    }

    @objc(enableAutoAppendLocalTimestamp:)
    public func enableAutoAppendLocalTimestamp(_ columnName: String?) {
        guard let columnName = columnName else {
            KCLogString("WARN: the specified columnName for local timestamp is nil. This call is noop")
            return
        }
        autoAppendLocalTimestampColumn = columnName
    }

    @objc public func disableAutoAppendLocalTimestamp() { autoAppendLocalTimestampColumn = nil }

    @objc public func enableAutoAppendRecordUUID() { autoAppendRecordUUIDColumn = "record_uuid" }

    @objc(enableAutoAppendRecordUUID:)
    public func enableAutoAppendRecordUUID(_ columnName: String?) {
        guard let columnName = columnName else {
            KCLogString("WARN: the specified columnName for record UUID is nil; auto appending record UUID won't be enabled.")
            return
        }
        autoAppendRecordUUIDColumn = columnName
    }

    @objc public func disableAutoAppendRecordUUID() { autoAppendRecordUUIDColumn = nil }

    @objc public func enableAutoAppendAdvertisingIdentifier() {
        enableAutoAppendAdvertisingIdentifier(TreasureData.C.keyOfAdvertisingIdentifier)
    }

    @objc(enableAutoAppendAdvertisingIdentifier:)
    public func enableAutoAppendAdvertisingIdentifier(_ columnName: String) {
        if NSClassFromString("ASIdentifierManager") == nil {
            NSLog("ERROR: You are attempting to enable auto append Advertising Identifer but ASIdentifierManager class is not detected. To use this feature, you must link AdSupport framework in your project")
        } else {
            autoAppendAdvertisingIdColumn = columnName
        }
    }

    @objc public func disableAutoAppendAdvertisingIdentifier() { autoAppendAdvertisingIdColumn = nil }

    @objc public func enableAutoTrackingIP() { engine.isTrackingIP = true }
    @objc public func disableAutoTrackingIP() { engine.isTrackingIP = false }

    // MARK: - Retry

    @objc public func disableRetryUploading() { engine.retry.isEnabled = false }
    @objc public func enableRetryUploading() { engine.retry.isEnabled = true }

    // MARK: - First run

    @objc public func isFirstRun() -> Bool {
        return UserDefaults.standard.integer(forKey: TreasureData.C.storageKeyOfFirstRun) == 0
    }

    @objc public func clearFirstRun() {
        UserDefaults.standard.set(1, forKey: TreasureData.C.storageKeyOfFirstRun)
        UserDefaults.standard.synchronize()
    }

    /// Exposed for testing.
    @objc public func initializeFirstRun() {
        UserDefaults.standard.set(0, forKey: TreasureData.C.storageKeyOfFirstRun)
        UserDefaults.standard.synchronize()
    }

    // MARK: - Instance session

    @objc(startSession:)
    public func startSession(_ table: String) {
        startSession(table, database: defaultDatabase ?? "")
    }

    @objc(startSession:database:)
    public func startSession(_ table: String, database: String) {
        sessionId = UUID().uuidString
        addEvent([TreasureData.C.keyOfSessionEvent: TreasureData.C.sessionEventStart],
                 database: database, table: table)
    }

    @objc(endSession:)
    public func endSession(_ table: String) {
        endSession(table, database: defaultDatabase ?? "")
    }

    @objc(endSession:database:)
    public func endSession(_ table: String, database: String) {
        addEvent([TreasureData.C.keyOfSessionEvent: TreasureData.C.sessionEventEnd],
                 database: database, table: table)
        sessionId = nil
    }

    @objc public func getSessionId() -> String? { sessionId }

    // MARK: - Global (static) session

    @objc public class func startSession() {
        if globalSession == nil {
            let s = Session()
            if sessionTimeoutMilli > 0 { s.sessionPendingMillis = sessionTimeoutMilli }
            globalSession = s
        }
        globalSession?.start()
    }

    @objc public class func endSession() { globalSession?.finish() }

    @objc public class func getSessionId() -> String? { globalSession?.getId() }

    @objc public class func resetSessionId() { globalSession?.resetId() }

    @objc public class func setSessionTimeoutMilli(_ to: Int) { sessionTimeoutMilli = to }

    // MARK: - Shared instance / class initialization

    @objc public class func sharedInstance() -> TreasureData {
        assert(sharedInstanceStorage != nil,
               "TreasureData sharedInstance is called before [TreasureData initializeWithApiKey:]")
        return sharedInstanceStorage!
    }

    @objc(initializeWithApiKey:)
    public class func initializeWithApiKey(_ apiKey: String) {
        initializeWithApiKey(apiKey, apiEndpoint: C.defaultApiEndpoint)
    }

    @objc(initializeWithApiKey:apiEndpoint:)
    public class func initializeWithApiKey(_ apiKey: String, apiEndpoint: String) {
        // dispatch_once semantics: only the first call wins.
        objc_sync_enter(self)
        defer { objc_sync_exit(self) }
        if !initializeOnceToken {
            initializeOnceToken = true
            sharedInstanceStorage = TreasureData(apiKey: apiKey, apiEndpoint: apiEndpoint)
        }
    }

    @objc(initializeEncryptionKey:)
    public class func initializeEncryptionKey(_ encryptionKey: String?) {
        SwiftEventEngine.initializeEncryptionKey(encryptionKey)
    }

    // MARK: - Compression / logging / trace

    @objc public class func disableEventCompression() { isEventCompressionEnabled = false }
    @objc public class func enableEventCompression() { isEventCompressionEnabled = true }

    @objc public class func disableLogging() { TDLogging.isEnabled = false }
    @objc public class func enableLogging() { TDLogging.isEnabled = true }

    @objc public class func disableTraceLogging() { isTraceLoggingEnabled = false }
    @objc public class func enableTraceLogging() { isTraceLoggingEnabled = true }

    // MARK: - App lifecycle observation

    private func observeLifecycleEvents() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppDidLaunching(_:)),
            name: NSNotification.Name("UIApplicationDidFinishLaunchingNotification"),
            object: nil)
    }

    @objc private func handleAppDidLaunching(_ notification: Notification) {
        guard isAppLifecycleEventEnabled() else { return }

        let targetDatabase = TDUtils.requireNonBlank(
            defaultDatabase, defaultValue: TDC.defaultDatabase,
            message: "WARN: defaultDatabase was not set. \"\(TDC.defaultDatabase)\" will be used as the target database for app lifecycle events.") ?? TDC.defaultDatabase
        let targetTable = TDUtils.requireNonBlank(
            defaultTable, defaultValue: TDC.defaultTable,
            message: "WARN: defaultTable was not set. \"\(TDC.defaultTable)\" will be used as the target table for app lifecycle events.") ?? TDC.defaultTable

        let currentVersion = getAppVersion()
        let currentBuild = getBuildNumber()
        let previousVersion = getTrackedAppVersion()
        let previousBuild = getTrackedBuildNumber()

        // For lifecycle events the app version/build is always attached,
        // regardless of the autoAppendAppInformation setting.
        if previousVersion == nil {
            addEvent(TDUtils.markAsAppLifecycleEvent([
                TDC.columnEvent: TDC.eventAppInstalled,
                C.keyOfAppVer: currentVersion as Any,
                C.keyOfAppVerNum: currentBuild as Any
            ]), database: targetDatabase, table: targetTable)
        } else if previousVersion != currentVersion {
            addEvent(TDUtils.markAsAppLifecycleEvent([
                TDC.columnEvent: TDC.eventAppUpdated,
                C.keyOfPreviousAppVer: previousVersion as Any,
                C.keyOfPreviousAppVerNum: previousBuild as Any,
                C.keyOfAppVer: currentVersion as Any,
                C.keyOfAppVerNum: currentBuild as Any
            ]), database: targetDatabase, table: targetTable)
        }

        addEvent(TDUtils.markAsAppLifecycleEvent([
            TDC.columnEvent: TDC.eventAppOpened,
            C.keyOfAppVer: currentVersion as Any,
            C.keyOfAppVerNum: currentBuild as Any
        ]), database: targetDatabase, table: targetTable)

        UserDefaults.standard.set(currentVersion, forKey: TDC.userDefaultsKeyTrackedAppVersion)
        UserDefaults.standard.set(currentBuild, forKey: TDC.userDefaultsKeyTrackedAppBuild)
    }

    // MARK: - GDPR Compliance

    @objc public func enableCustomEvent() {
        customEventEnabled = true
        UserDefaults.standard.set(true, forKey: TDC.userDefaultsKeyCustomEventEnabled)
    }

    @objc public func disableCustomEvent() {
        customEventEnabled = false
        UserDefaults.standard.set(false, forKey: TDC.userDefaultsKeyCustomEventEnabled)
    }

    @objc(isCustomEventEnabled)
    public func isCustomEventEnabled() -> Bool { customEventEnabled }

    @objc public func enableAppLifecycleEvent() {
        appLifecycleEventEnabled = true
        UserDefaults.standard.set(true, forKey: TDC.userDefaultsKeyAppLifecycleEventEnabled)
    }

    @objc public func disableAppLifecycleEvent() {
        appLifecycleEventEnabled = false
        UserDefaults.standard.set(false, forKey: TDC.userDefaultsKeyAppLifecycleEventEnabled)
    }

    @objc(isAppLifecycleEventEnabled)
    public func isAppLifecycleEventEnabled() -> Bool { appLifecycleEventEnabled }

    @objc public func resetUniqId() {
        // The ObjC assigns a fresh UUID both before AND after the audit event.
        _UUID = UUID().uuidString
        UserDefaults.standard.set(_UUID, forKey: TreasureData.C.storageKeyOfUuid)

        let eventTypeColumn = TDUtils.isRunningWithUnity() ? TDC.columnUnityEvent : TDC.columnEvent
        let table = TDUtils.requireNonBlank(
            defaultTable, defaultValue: TDC.defaultTable,
            message: "WARN: defaultTable was not set. \"\(TDC.defaultTable)\" will be used as the target table.") ?? TDC.defaultTable
        addEvent(TDUtils.markAsAuditEvent([eventTypeColumn: TDC.eventAuditResetUuid]), table: table)

        _UUID = UUID().uuidString
        UserDefaults.standard.set(_UUID, forKey: TreasureData.C.storageKeyOfUuid)
    }

    // MARK: - Personalization API

    @objc(fetchUserSegments:keys:options:completionHandler:)
    public func fetchUserSegments(tokens audienceTokens: [String],
                                  keys: [String: Any],
                                  options: [String: Any]? = nil,
                                  completionHandler handler: @escaping (_ jsonResponse: [Any]?, _ error: Error?) -> Void) {
        let cdpEndpoint = self.cdpEndpoint ?? TreasureData.C.defaultCdpEndpoint
        let encodedAudienceTokens = audienceTokens.map { TreasureData.urlEncode($0) }
        let audienceString = "&token=\(encodedAudienceTokens.joined(separator: ","))"
        var keyString = ""
        for (key, value) in keys {
            keyString += "&key.\(TreasureData.urlEncode(key))=\(TreasureData.urlEncode(value))"
        }
        var urlString = cdpEndpoint
        urlString += "/cdp/lookup/collect/segments?version=2"
        urlString += audienceString
        urlString += keyString
        guard let url = URL(string: urlString) else {
            handler(nil, NSError(domain: TreasureData.C.errorDomain, code: -1, userInfo: nil))
            return
        }

        // Option keys mirror TDRequestOptionsKey.h.
        let timeoutNumber = options?["TDRequestOptionsTimeoutIntervalKey"] as? NSNumber
        let timeout: TimeInterval = timeoutNumber?.doubleValue ?? 60
        let cachePolicyNumber = options?["TDRequestOptionsCachePolicyKey"] as? NSNumber
        let cachePolicy: URLRequest.CachePolicy = cachePolicyNumber
            .flatMap { URLRequest.CachePolicy(rawValue: $0.uintValue) } ?? .useProtocolCachePolicy
        let urlRequest = URLRequest(url: url, cachePolicy: cachePolicy, timeoutInterval: timeout)

        let dataTask = engine.session.dataTask(with: urlRequest) { data, response, connectionError in
            if let connectionError = connectionError {
                handler(nil, connectionError)
                return
            }
            let jsonResponse = data.flatMap { try? JSONSerialization.jsonObject(with: $0, options: []) }
            if let array = jsonResponse as? [Any] {
                handler(array, nil)
            } else if let dict = jsonResponse as? [String: Any], dict["error"] != nil {
                var userInfo = [String: Any]()
                if let err = dict["error"] { userInfo[NSLocalizedDescriptionKey] = err }
                if let message = dict["message"] { userInfo[NSLocalizedFailureReasonErrorKey] = message }
                let code = (dict["status"] as? NSNumber)?.intValue ?? 0
                handler(nil, NSError(domain: TreasureData.C.errorDomain, code: code, userInfo: userInfo))
            } else {
                let userInfo: [String: Any] = [
                    NSLocalizedDescriptionKey: NSLocalizedString("Invalid reponse format", comment: ""),
                    NSLocalizedFailureReasonErrorKey: NSLocalizedString("Server returned unrecognizable response format", comment: "")
                ]
                handler(nil, NSError(domain: TreasureData.C.errorDomain, code: -1, userInfo: userInfo))
            }
        }
        dataTask.resume()
    }

    /// Percent-escapes a query-string component. Re-implemented in Swift because
    /// the ObjC `urlEncode` is a `static inline` C function (invisible to Swift).
    private static func urlEncode(_ object: Any) -> String {
        let string = "\(object)"
        return string.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? string
    }

    // MARK: - Default values

    private func defaultValueTableKey(forDatabase database: String?, table: String?) -> String {
        return "\(database ?? "").\(table ?? "")"
    }

    @objc(setDefaultValue:forKey:database:table:)
    public func setDefaultValue(_ value: Any, forKey key: String, database: String?, table: String?) {
        if _defaultValues == nil { _defaultValues = [:] }
        let tableKey = defaultValueTableKey(forDatabase: database, table: table)
        var tableDictionary = _defaultValues?[tableKey] ?? [:]
        tableDictionary[key] = value
        _defaultValues?[tableKey] = tableDictionary
    }

    @objc(defaultValueForKey:database:table:)
    public func defaultValue(forKey key: String, database: String?, table: String?) -> Any? {
        let tableKey = defaultValueTableKey(forDatabase: database, table: table)
        return _defaultValues?[tableKey]?[key]
    }

    @objc(removeDefaultValueForKey:database:table:)
    public func removeDefaultValue(forKey key: String, database: String?, table: String?) {
        let tableKey = defaultValueTableKey(forDatabase: database, table: table)
        guard var tableDictionary = _defaultValues?[tableKey] else { return }
        tableDictionary.removeValue(forKey: key)
        _defaultValues?[tableKey] = tableDictionary
    }

    // MARK: - Exposed for testing

    @objc public class func resetSession() { globalSession = nil }
}
