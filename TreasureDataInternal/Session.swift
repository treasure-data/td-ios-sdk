//
//  Session.swift
//  TreasureData
//
//  The Global Session (see CONTEXT.md): a timeout-windowed session shared across
//  TreasureData instances. Faithful port of the Objective-C `Session`
//  (TDSession.{h,m}). Marked @objc so the remaining Objective-C callers
//  (TreasureData.m) and tests can use it.
//

import Foundation

private let defaultSessionPendingMillis = 10 * 1000

@objc(Session)
public class Session: NSObject {

    @objc public var sessionPendingMillis: Int

    private var id: String?
    private var finishedAt: Date?

    // The Objective-C original overrode `+ (Session*) new` to set the default
    // pending window. Here `init()` does that, so the inherited `+new`
    // (alloc+init) that ObjC callers use — `[Session new]` — behaves identically.
    public override init() {
        self.sessionPendingMillis = defaultSessionPendingMillis
        super.init()
    }

    @objc public func start() {
        if id == nil ||
            (finishedAt != nil && finishedAt!.timeIntervalSinceNow * -1000 > Double(sessionPendingMillis)) {
            id = UUID().uuidString
        }
        // FIXME: is this really intended, start will always reset the finish status?
        // Preserved verbatim from the Objective-C implementation.
        finishedAt = nil
    }

    @objc public func finish() {
        if id != nil && finishedAt == nil {
            finishedAt = Date()
        }
    }

    @objc public func getId() -> String? {
        if id == nil || finishedAt != nil {
            return nil
        }
        return id
    }

    @objc public func resetId() {
        id = UUID().uuidString
    }
}
