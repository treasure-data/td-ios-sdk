//
//  EventStore.swift
//  TreasureData
//
//  Pure-Swift port of KeenClient's `KIOEventStore`. Owns the on-disk Buffer:
//  a SQLite database of tracked events, optionally AES-encrypted. This is a
//  faithful, byte-compatible translation — same file path, same schema, same
//  SQL statements, same AES-128/ECB/PKCS7 + base64 encoding — so an app
//  upgrading from the KeenClient-backed engine reads its existing buffer
//  unchanged. The `BufferContractTest` fixtures are the parity oracle.
//
//  Uses the system `libsqlite3` (import SQLite3) rather than the vendored
//  keen_io_sqlite3 amalgamation; both produce the same on-disk format.
//

import Foundation
import SQLite3
import CommonCrypto

// SQLITE_TRANSIENT tells SQLite to copy the bound bytes. The macro isn't
// imported into Swift, so redeclare it.
private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

final class EventStore {

    /// The project id scoping this store's rows (KeenClient's `projectId`).
    var projectId: String = ""

    /// Last SQLite error, mirroring `KIOEventStore.lastErrorMessage`.
    var lastErrorMessage: String?

    /// Process-global encryption key, matching KeenClient's static `encKey`.
    /// nil means events are stored as plaintext JSON.
    private static var encryptionKey: String?
    static func initializeEncryptionKey(_ key: String?) {
        encryptionKey = key
    }

    // Serial queue for all SQLite work. Same label as the ObjC store so nothing
    // about threading behavior changes.
    private let dbQueue = DispatchQueue(label: "com.treasuredata.sqlite")

    private var db: OpaquePointer?
    private var dbIsOpen = false
    private var dbIsTableCreated = false
    private var dbIsStmtPrepared = false

    // Prepared statements, matching the ObjC store one-for-one.
    private var insertStmt: OpaquePointer?
    private var findStmt: OpaquePointer?
    private var countAllStmt: OpaquePointer?
    private var countPendingStmt: OpaquePointer?
    private var makePendingStmt: OpaquePointer?
    private var resetPendingStmt: OpaquePointer?
    private var purgeStmt: OpaquePointer?
    private var deleteStmt: OpaquePointer?
    private var deleteAllStmt: OpaquePointer?
    private var ageOutStmt: OpaquePointer?
    private var convertDateStmt: OpaquePointer?

    init() {
        dbQueue.sync { _ = openAndInitDB() }
    }

    deinit {
        // Finalize statements before closing the connection (order matters).
        dbQueue.sync {
            if dbIsStmtPrepared { releaseStatements() }
            if dbIsOpen { closeDB() }
        }
    }

    // MARK: - Open / schema / statements

    private func databaseFilePath() -> String {
        #if os(tvOS)
        let base = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true)[0]
        #else
        let base = NSSearchPathForDirectoriesInDomains(.libraryDirectory, .userDomainMask, true)[0]
        #endif
        return (base as NSString).appendingPathComponent("keenEvents.sqlite")
    }

    private func isDatabaseFileAccessible() -> Bool {
        let path = databaseFilePath()
        if FileManager.default.fileExists(atPath: path) {
            // Match the ObjC accessibility probe: I/O can fail after Data
            // Protection kicks in even when the file exists.
            guard let f = fopen(path, "r") else {
                NSLog("Failed to open database file!")
                return false
            }
            fclose(f)
        }
        return true
    }

    @discardableResult
    private func openAndInitDB() -> Bool {
        if !dbIsOpen {
            if !isDatabaseFileAccessible() {
                KCLogString("Database file isn't accessible now")
                return false
            }
            if !openDB() { return false }
        }
        if !dbIsTableCreated {
            if !createTable() {
                KCLogString("Failed to create SQLite table!")
                return false
            }
        }
        if !dbIsStmtPrepared {
            if !prepareAllStatements() {
                KCLogString("Failed to prepare statements!")
                return false
            }
        }
        return true
    }

    private func openDB() -> Bool {
        // The ObjC store called sqlite3_config(SQLITE_CONFIG_MULTITHREAD) before
        // opening; that API is variadic and unavailable to Swift, and Apple's
        // system libsqlite3 is already built multithread-safe (SQLITE_THREADSAFE=2),
        // so it was a no-op here. It never touched the on-disk format either.
        // ponytail: dropped config dance — default mode already matches, format unaffected.
        if sqlite3_open(databaseFilePath(), &db) == SQLITE_OK {
            dbIsOpen = true
        } else {
            handleFailure("create database")
        }
        return dbIsOpen
    }

    private func createTable() -> Bool {
        let sql = "CREATE TABLE IF NOT EXISTS 'events' (ID INTEGER PRIMARY KEY AUTOINCREMENT, collection TEXT, projectId TEXT, eventData BLOB, pending INTEGER, dateCreated TIMESTAMP DEFAULT CURRENT_TIMESTAMP);"
        var err: UnsafeMutablePointer<CChar>?
        if sqlite3_exec(db, sql, nil, nil, &err) != SQLITE_OK {
            if let err = err {
                KCLogString("Failed to create table: \(String(cString: err))")
                sqlite3_free(err)
            }
            closeDB()
            dbIsTableCreated = false
            return false
        }
        dbIsTableCreated = true
        return true
    }

    private func prepare(_ sql: String, _ stmt: inout OpaquePointer?, _ what: String) -> Bool {
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) != SQLITE_OK {
            handleFailure("prepare \(what) statement")
            return false
        }
        return true
    }

    private func prepareAllStatements() -> Bool {
        guard prepare("INSERT INTO events (projectId, collection, eventData, pending) VALUES (?, ?, ?, 0)", &insertStmt, "insert"),
              prepare("SELECT id, collection, eventData FROM events WHERE pending=0 AND projectId=?", &findStmt, "find"),
              prepare("SELECT count(*) FROM events WHERE projectId=?", &countAllStmt, "count all"),
              prepare("SELECT count(*) FROM events WHERE pending=1 AND projectId=?", &countPendingStmt, "count pending"),
              prepare("UPDATE events SET pending=1 WHERE id=?", &makePendingStmt, "pending"),
              prepare("UPDATE events SET pending=0 WHERE projectId=?", &resetPendingStmt, "reset pending"),
              prepare("DELETE FROM events WHERE pending=1 AND projectId=?", &purgeStmt, "purge"),
              prepare("DELETE FROM events WHERE id=?", &deleteStmt, "delete"),
              prepare("DELETE FROM events", &deleteAllStmt, "delete all"),
              prepare("DELETE FROM events WHERE id <= (SELECT id FROM events ORDER BY id DESC LIMIT 1 OFFSET ?)", &ageOutStmt, "age out"),
              prepare("SELECT strftime('%Y-%m-%dT%H:%M:%S',datetime(?,'unixepoch','localtime'))", &convertDateStmt, "convert date")
        else {
            return false
        }
        dbIsStmtPrepared = true
        return true
    }

    private func closeDB() {
        // sqlite3_close_v2 (not _close) always releases the connection object
        // even if statements are unfinalized or work is pending — it defers the
        // actual free until safe. Always clear our state: keeping db/dbIsOpen
        // pointing at a half-closed handle would make openAndInitDB's
        // `if !dbIsOpen` guard skip reopening and run ops against a dead handle.
        let rc = sqlite3_close_v2(db)
        if rc != SQLITE_OK {
            KCLogString("SQLite close returned rc=\(rc)")
        }
        db = nil
        dbIsOpen = false
    }

    private func releaseStatements() {
        for s in [insertStmt, findStmt, countAllStmt, countPendingStmt, makePendingStmt,
                  resetPendingStmt, purgeStmt, deleteStmt, deleteAllStmt, ageOutStmt, convertDateStmt] {
            sqlite3_finalize(s)
        }
        dbIsStmtPrepared = false
    }

    // MARK: - Add / read

    @discardableResult
    func addEvent(_ eventData: Data, collection: String) -> Bool {
        var data = eventData
        if EventStore.encryptionKey != nil {
            if let encrypted = encrypt(eventData), let d = encrypted.data(using: .utf8) {
                data = d
            } else {
                KCLogString("Encryption failed. Storing it as a plain...")
                EventStore.encryptionKey = nil
            }
        }

        var added = false
        dbQueue.sync {
            guard openAndInitDB() else {
                KCLogString("DB is closed, skipping addEvent")
                return
            }
            guard sqlite3_bind_text(insertStmt, 1, projectId, -1, SQLITE_TRANSIENT) == SQLITE_OK else {
                handleFailure("bind pid to add event statement"); return
            }
            guard sqlite3_bind_text(insertStmt, 2, collection, -1, SQLITE_TRANSIENT) == SQLITE_OK else {
                handleFailure("bind coll to add event statement"); return
            }
            let ok: Int32 = data.withUnsafeBytes { buf in
                sqlite3_bind_blob(insertStmt, 3, buf.baseAddress, Int32(buf.count), SQLITE_TRANSIENT)
            }
            guard ok == SQLITE_OK else { handleFailure("bind insert statement"); return }
            guard sqlite3_step(insertStmt) == SQLITE_DONE else { handleFailure("insert event"); return }
            added = true
            sqlite3_reset(insertStmt)
            sqlite3_clear_bindings(insertStmt)
        }
        return added
    }

    /// Returns events keyed by collection, then by event id — matching
    /// `KIOEventStore.getEvents`. Marks returned events pending.
    func getEvents() -> [String: [NSNumber: Data]] {
        if hasPendingEvents() { resetPendingEvents() }

        var events: [String: [NSNumber: Data]] = [:]
        dbQueue.sync {
            guard openAndInitDB() else {
                KCLogString("DB is closed, skipping getEvents")
                return
            }
            guard sqlite3_bind_text(findStmt, 1, projectId, -1, SQLITE_TRANSIENT) == SQLITE_OK else {
                handleFailure("bind pid to find statement"); return
            }
            while sqlite3_step(findStmt) == SQLITE_ROW {
                let eventId = sqlite3_column_int64(findStmt, 0)
                let coll = String(cString: sqlite3_column_text(findStmt, 1))
                let dataSize = sqlite3_column_bytes(findStmt, 2)
                // sqlite3_column_blob returns NULL both for SQL NULL and for a
                // zero-length blob; only the former (size <= 0) is a corrupt row
                // worth dropping. A NULL pointer with size > 0 can't happen.
                guard let dataPtr = sqlite3_column_blob(findStmt, 2), dataSize > 0 else {
                    KCLogString("Event row has empty/NULL eventData. Deleting it")
                    deleteEvent(NSNumber(value: eventId))
                    continue
                }
                var data = Data(bytes: dataPtr, count: Int(dataSize))
                // Mark this event pending.
                guard sqlite3_bind_int64(makePendingStmt, 1, eventId) == SQLITE_OK else {
                    handleFailure("bind int for make pending"); return
                }
                guard sqlite3_step(makePendingStmt) == SQLITE_DONE else {
                    handleFailure("mark event pending"); return
                }
                sqlite3_reset(makePendingStmt)
                sqlite3_clear_bindings(makePendingStmt)

                if EventStore.encryptionKey != nil {
                    // Try to decrypt; fall back to treating the row as plain JSON,
                    // and drop it if it is neither — exactly as the ObjC store.
                    if let decrypted = decrypt(String(data: data, encoding: .utf8) ?? ""),
                       (try? JSONSerialization.jsonObject(with: decrypted)) != nil {
                        data = decrypted
                    } else if (try? JSONSerialization.jsonObject(with: data)) == nil {
                        KCLogString("This event can't be handled as a plain JSON. Deleting it")
                        deleteEvent(NSNumber(value: eventId))
                        continue
                    }
                } else {
                    if (try? JSONSerialization.jsonObject(with: data)) == nil {
                        KCLogString("This event can't be handled as a plain JSON. Deleting it")
                        deleteEvent(NSNumber(value: eventId))
                        continue
                    }
                }

                events[coll, default: [:]][NSNumber(value: eventId)] = data
            }
            sqlite3_reset(findStmt)
            sqlite3_clear_bindings(findStmt)
        }
        return events
    }

    // MARK: - Pending / counts

    func resetPendingEvents() {
        dbQueue.sync {
            guard self.openAndInitDB() else { KCLogString("DB is closed, skipping resetPendingEvents"); return }
            guard sqlite3_bind_text(self.resetPendingStmt, 1, self.projectId, -1, SQLITE_TRANSIENT) == SQLITE_OK else {
                self.handleFailure("bind pid to reset pending statement"); return
            }
            guard sqlite3_step(self.resetPendingStmt) == SQLITE_DONE else {
                self.handleFailure("reset pending events"); return
            }
            sqlite3_reset(self.resetPendingStmt)
            sqlite3_clear_bindings(self.resetPendingStmt)
        }
    }

    func hasPendingEvents() -> Bool {
        return getPendingEventCount() > 0
    }

    private func count(_ stmt: OpaquePointer?, _ what: String) -> UInt {
        var result: UInt = 0
        dbQueue.sync {
            guard openAndInitDB() else { KCLogString("DB is closed, skipping \(what)"); return }
            guard sqlite3_bind_text(stmt, 1, projectId, -1, SQLITE_TRANSIENT) == SQLITE_OK else {
                handleFailure("bind pid to \(what) statement"); return
            }
            if sqlite3_step(stmt) == SQLITE_ROW {
                result = UInt(sqlite3_column_int(stmt, 0))
            } else {
                handleFailure(what)
            }
            sqlite3_reset(stmt)
            sqlite3_clear_bindings(stmt)
        }
        return result
    }

    func getPendingEventCount() -> UInt { count(countPendingStmt, "get count of pending rows") }
    func getTotalEventCount() -> UInt { count(countAllStmt, "get count of total rows") }

    // MARK: - Delete

    func deleteEvent(_ eventId: NSNumber) {
        dbQueue.async {
            guard self.openAndInitDB() else { KCLogString("DB is closed, skipping deleteEvent"); return }
            guard sqlite3_bind_int64(self.deleteStmt, 1, eventId.int64Value) == SQLITE_OK else {
                self.handleFailure("bind eventid to delete statement"); return
            }
            guard sqlite3_step(self.deleteStmt) == SQLITE_DONE else {
                self.handleFailure("delete event"); return
            }
            sqlite3_reset(self.deleteStmt)
            sqlite3_clear_bindings(self.deleteStmt)
        }
    }

    func deleteAllEvents() {
        dbQueue.async { self.deleteAllEventsLocked() }
    }

    /// Synchronous delete-all, for test reset where the caller must observe an
    /// empty buffer immediately.
    func deleteAllEventsSync() {
        dbQueue.sync { self.deleteAllEventsLocked() }
    }

    private func deleteAllEventsLocked() {
        guard openAndInitDB() else { KCLogString("DB is closed, skipping deleteAllEvents"); return }
        guard sqlite3_step(deleteAllStmt) == SQLITE_DONE else {
            handleFailure("delete all events"); return
        }
        sqlite3_reset(deleteAllStmt)
        sqlite3_clear_bindings(deleteAllStmt)
    }

    func deleteEvents(fromOffset offset: NSNumber) {
        dbQueue.async {
            guard self.openAndInitDB() else { KCLogString("DB is closed, skipping deleteEventsFromOffset"); return }
            guard sqlite3_bind_int64(self.ageOutStmt, 1, offset.int64Value) == SQLITE_OK else {
                self.handleFailure("bind offset to ageOut statement"); return
            }
            guard sqlite3_step(self.ageOutStmt) == SQLITE_DONE else {
                self.handleFailure("age out events"); return
            }
            sqlite3_reset(self.ageOutStmt)
            sqlite3_clear_bindings(self.ageOutStmt)
        }
    }

    func purgePendingEvents() {
        dbQueue.async {
            guard self.openAndInitDB() else { KCLogString("DB is closed, skipping purgePendingEvents"); return }
            guard sqlite3_bind_text(self.purgeStmt, 1, self.projectId, -1, SQLITE_TRANSIENT) == SQLITE_OK else {
                self.handleFailure("bind pid to purge statement"); return
            }
            guard sqlite3_step(self.purgeStmt) == SQLITE_DONE else {
                self.handleFailure("purge pending events"); return
            }
            sqlite3_reset(self.purgeStmt)
            sqlite3_clear_bindings(self.purgeStmt)
        }
    }

    // MARK: - Date → ISO-8601

    /// ISO-8601 string with timezone offset, computed exactly like
    /// `KIOEventStore.convertNSDateToISO8601`: sqlite does the strftime (avoids a
    /// non-thread-safe NSDateFormatter) and the offset is appended by hand.
    func convertToISO8601(_ date: Date) -> String {
        // Offset in hours; the original splits on the decimal point to sidestep
        // number formatting (also not thread-safe).
        let offset = Double(TimeZone.current.secondsFromGMT(for: date)) / 3600.0
        let offsetParts = String(format: "%f", offset).components(separatedBy: ".")
        var hour = offsetParts[0].replacingOccurrences(of: "-", with: "")
        var minute = String(offsetParts[1].prefix(2))

        while hour.count < 2 { hour = "0" + hour }
        if minute == "25" { minute = "15" }
        if minute == "50" { minute = "30" }
        if minute == "75" { minute = "45" }

        var offsetString = "\(hour):\(minute)"
        offsetString = (offset >= 0 ? "+" : "-") + offsetString

        var iso8601 = ""
        dbQueue.sync {
            guard openAndInitDB() else { KCLogString("DB is closed, skipping convertToISO8601"); return }
            let epoch = String(format: "%f", date.timeIntervalSince1970)
            guard sqlite3_bind_text(convertDateStmt, 1, epoch, -1, SQLITE_TRANSIENT) == SQLITE_OK else {
                handleFailure("bind date to date conversion statement"); return
            }
            guard sqlite3_step(convertDateStmt) == SQLITE_ROW else {
                handleFailure("date conversion"); return
            }
            iso8601 = String(cString: sqlite3_column_text(convertDateStmt, 0)) + offsetString
            sqlite3_reset(convertDateStmt)
            sqlite3_clear_bindings(convertDateStmt)
        }
        return iso8601
    }

    // MARK: - Encryption (AES-128 / ECB / PKCS7, base64) — byte-compatible

    private func encdec(_ op: CCOperation, _ data: Data) -> Data? {
        guard let key = EventStore.encryptionKey else { return nil }

        // Key = raw UTF-8 bytes truncated/zero-padded to 16, matching the ObjC
        // `getCString:maxLength:kCCKeySizeAES128+1`.
        var keyBuf = [UInt8](repeating: 0, count: kCCKeySizeAES128)
        let keyBytes = Array(key.utf8.prefix(kCCKeySizeAES128))
        for (i, b) in keyBytes.enumerated() { keyBuf[i] = b }

        let bufSize = data.count + kCCBlockSizeAES128
        var out = [UInt8](repeating: 0, count: bufSize)
        var moved = 0
        let status = data.withUnsafeBytes { dataPtr in
            CCCrypt(op, CCAlgorithm(kCCAlgorithmAES128),
                    CCOptions(kCCOptionPKCS7Padding | kCCOptionECBMode),
                    keyBuf, kCCKeySizeAES128, nil,
                    dataPtr.baseAddress, data.count,
                    &out, bufSize, &moved)
        }
        guard status == kCCSuccess else { return nil }
        return Data(out.prefix(moved))
    }

    private func encrypt(_ data: Data) -> String? {
        guard let encrypted = encdec(CCOperation(kCCEncrypt), data) else { return nil }
        return encrypted.base64EncodedString()
    }

    private func decrypt(_ base64: String) -> Data? {
        guard let raw = Data(base64Encoded: base64) else { return nil }
        return encdec(CCOperation(kCCDecrypt), raw)
    }

    // MARK: - Failure handling

    private func handleFailure(_ msg: String) {
        let sqliteMsg = String(cString: sqlite3_errmsg(db))
        NSLog("Failed to \(msg): \(sqliteMsg)")
        if dbIsStmtPrepared { releaseStatements() }
        if dbIsOpen { closeDB() }
        lastErrorMessage = "Failed to \(msg): \(sqliteMsg)"
    }
}
