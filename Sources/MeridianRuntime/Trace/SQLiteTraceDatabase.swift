import Foundation
import SQLite3

enum SQLiteTraceStoreSchema {
    static let currentVersion = 2
    static let supportedReaderVersions = [1, 2]

    static let createMeta = """
        CREATE TABLE IF NOT EXISTS trace_meta (
            key TEXT PRIMARY KEY NOT NULL,
            value TEXT NOT NULL
        );
        """

    static let createV1 = """
        CREATE TABLE IF NOT EXISTS trace_envelopes_v1 (
            rowid INTEGER PRIMARY KEY AUTOINCREMENT,
            envelope_json TEXT NOT NULL,
            checksum TEXT NOT NULL
        );
        """

    static let createV2 = """
        CREATE TABLE IF NOT EXISTS trace_records (
            id TEXT PRIMARY KEY NOT NULL,
            schema_version INTEGER NOT NULL,
            at REAL NOT NULL,
            ingest_order INTEGER NOT NULL,
            run_id TEXT NOT NULL,
            step TEXT NOT NULL,
            skill_name TEXT NOT NULL,
            skill_version_hash TEXT NOT NULL,
            tag TEXT NOT NULL,
            subject TEXT,
            subject_key TEXT,
            payload_json TEXT,
            payload_hash TEXT NOT NULL,
            outcome TEXT,
            witness TEXT,
            previous_hash TEXT,
            record_hash TEXT,
            operational_detail TEXT,
            legacy_kind TEXT,
            checksum TEXT NOT NULL
        );
        CREATE INDEX IF NOT EXISTS idx_trace_records_run ON trace_records(run_id);
        CREATE INDEX IF NOT EXISTS idx_trace_records_tag ON trace_records(tag);
        CREATE INDEX IF NOT EXISTS idx_trace_records_subject ON trace_records(subject);
        CREATE INDEX IF NOT EXISTS idx_trace_records_at ON trace_records(at, ingest_order, id);
        """
}

struct SQLiteTraceEnvelope: Codable {
    let record: TraceRecord
    let checksum: String
}

enum SQLiteTraceDatabaseError: Error, Sendable, Equatable {
    case openFailed(String)
    case execFailed(String)
    case prepareFailed(String)
    case stepFailed(String)
    case bindFailed(String)
    case unsupportedStorageSchema(Int)
}

final class SQLiteTraceDatabase: @unchecked Sendable {
    private var db: OpaquePointer?
    private(set) var storageSchemaVersion: Int = 0

    init(fileURL: URL) throws {
        var handle: OpaquePointer?
        let flags = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX
        let code = sqlite3_open_v2(fileURL.path, &handle, flags, nil)
        guard code == SQLITE_OK, let handle else {
            throw SQLiteTraceDatabaseError.openFailed(String(cString: sqlite3_errmsg(handle)))
        }
        db = handle
        try exec("PRAGMA journal_mode=WAL;")
        try exec("PRAGMA synchronous=FULL;")
        try ensureSchema()
    }

    deinit {
        if let db {
            sqlite3_close(db)
        }
    }

    func loadAllRecords() throws -> [TraceRecord] {
        switch storageSchemaVersion {
        case 1:
            return try loadV1Records()
        case 2:
            return try loadV2Records()
        default:
            throw SQLiteTraceDatabaseError.unsupportedStorageSchema(storageSchemaVersion)
        }
    }

    func append(record: TraceRecord, checksum: String) throws {
        if storageSchemaVersion == 1 {
            try migrateToV2IfNeeded()
        }
        try insertV2Record(record: record, checksum: checksum)
    }

    private func insertV2Record(record: TraceRecord, checksum: String) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let payloadJSON: String?
        if let payload = record.payload {
            payloadJSON = String(decoding: try encoder.encode(payload.mapValues(AnyCodable.init)), as: UTF8.self)
        } else {
            payloadJSON = nil
        }
        let sql = """
            INSERT INTO trace_records (
                id, schema_version, at, ingest_order, run_id, step, skill_name, skill_version_hash,
                tag, subject, subject_key, payload_json, payload_hash, outcome, witness,
                previous_hash, record_hash, operational_detail, legacy_kind, checksum
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
            """
        let statement = try prepare(sql)
        defer { sqlite3_finalize(statement) }
        let atSeconds = record.at.timeIntervalSince1970
        try bindText(statement, index: 1, record.id)
        try bindInt(statement, index: 2, record.schemaVersion)
        try bindDouble(statement, index: 3, atSeconds)
        try bindInt(statement, index: 4, record.ingestOrder)
        try bindText(statement, index: 5, record.run)
        try bindText(statement, index: 6, record.step)
        try bindText(statement, index: 7, record.skillName)
        try bindText(statement, index: 8, record.skillVersionHash)
        try bindText(statement, index: 9, record.tag.rawValue)
        try bindOptionalText(statement, index: 10, record.subject)
        try bindOptionalText(statement, index: 11, record.subjectKey)
        try bindOptionalText(statement, index: 12, payloadJSON)
        try bindText(statement, index: 13, record.payloadHash)
        try bindOptionalText(statement, index: 14, record.outcome?.rawValue)
        try bindOptionalText(statement, index: 15, record.witness)
        try bindOptionalText(statement, index: 16, record.previousHash)
        try bindOptionalText(statement, index: 17, record.recordHash)
        try bindOptionalText(statement, index: 18, record.operationalDetail)
        try bindOptionalText(statement, index: 19, record.legacyKind)
        try bindText(statement, index: 20, checksum)
        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw SQLiteTraceDatabaseError.stepFailed(errorMessage)
        }
    }

    func deleteRecords(before cutoff: Date) throws {
        if storageSchemaVersion == 1 {
            try migrateToV2IfNeeded()
        }
        let sql = "DELETE FROM trace_records WHERE at < ?;"
        let statement = try prepare(sql)
        defer { sqlite3_finalize(statement) }
        try bindDouble(statement, index: 1, cutoff.timeIntervalSince1970)
        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw SQLiteTraceDatabaseError.stepFailed(errorMessage)
        }
    }

    private func ensureSchema() throws {
        try exec(SQLiteTraceStoreSchema.createMeta)
        if let version = try readMeta(key: "storage_schema_version") {
            storageSchemaVersion = Int(version) ?? 0
        } else {
            try exec(SQLiteTraceStoreSchema.createV1)
            try setMeta(key: "storage_schema_version", value: "1")
            storageSchemaVersion = 1
        }
        if storageSchemaVersion == 2 {
            try exec(SQLiteTraceStoreSchema.createV2)
        }
        guard SQLiteTraceStoreSchema.supportedReaderVersions.contains(storageSchemaVersion) else {
            throw SQLiteTraceDatabaseError.unsupportedStorageSchema(storageSchemaVersion)
        }
    }

    private func migrateToV2IfNeeded() throws {
        guard storageSchemaVersion == 1 else { return }
        let records = try loadV1Records()
        try exec(SQLiteTraceStoreSchema.createV2)
        for record in records {
            let checksum = try CanonicalJSON.sha256Hex(for: record)
            try insertV2Record(record: record, checksum: checksum)
        }
        try exec("DROP TABLE IF EXISTS trace_envelopes_v1;")
        try setMeta(key: "storage_schema_version", value: "2")
        storageSchemaVersion = 2
    }

    private func loadV1Records() throws -> [TraceRecord] {
        let sql = "SELECT envelope_json, checksum FROM trace_envelopes_v1 ORDER BY rowid ASC;"
        let statement = try prepare(sql)
        defer { sqlite3_finalize(statement) }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        var records: [TraceRecord] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let jsonCString = sqlite3_column_text(statement, 0),
                  let checksumCString = sqlite3_column_text(statement, 1) else {
                continue
            }
            let json = String(cString: jsonCString)
            let checksum = String(cString: checksumCString)
            let envelope = try decoder.decode(SQLiteTraceEnvelope.self, from: Data(json.utf8))
            let expected = try CanonicalJSON.sha256Hex(for: envelope.record)
            guard expected == checksum else {
                throw TraceStoreError.invalidLineChecksum
            }
            records.append(envelope.record)
        }
        return records
    }

    private func loadV2Records() throws -> [TraceRecord] {
        let sql = """
            SELECT schema_version, id, at, ingest_order, run_id, step, skill_name, skill_version_hash,
                   tag, subject, subject_key, payload_json, payload_hash, outcome, witness,
                   previous_hash, record_hash, operational_detail, legacy_kind, checksum
            FROM trace_records ORDER BY ingest_order ASC, at ASC, id ASC;
            """
        let statement = try prepare(sql)
        defer { sqlite3_finalize(statement) }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        var records: [TraceRecord] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            let schemaVersion = Int(sqlite3_column_int(statement, 0))
            let id = columnText(statement, 1)
            let at = Date(timeIntervalSince1970: sqlite3_column_double(statement, 2))
            let ingestOrder = Int(sqlite3_column_int(statement, 3))
            let run = columnText(statement, 4)
            let step = columnText(statement, 5)
            let skillName = columnText(statement, 6)
            let skillVersionHash = columnText(statement, 7)
            let tag = TraceTag(rawValue: columnText(statement, 8)) ?? .emitted
            let subject = columnOptionalText(statement, 9)
            let subjectKey = columnOptionalText(statement, 10)
            let payloadJSON = columnOptionalText(statement, 11)
            let payloadHash = columnText(statement, 12)
            let outcomeRaw = columnOptionalText(statement, 13)
            let witness = columnOptionalText(statement, 14)
            let previousHash = columnOptionalText(statement, 15)
            let recordHash = columnOptionalText(statement, 16)
            let operationalDetail = columnOptionalText(statement, 17)
            let legacyKind = columnOptionalText(statement, 18)
            let checksum = columnText(statement, 19)
            let payload: [String: Value]?
            if let payloadJSON {
                let decoded = try decoder.decode([String: AnyCodable].self, from: Data(payloadJSON.utf8))
                payload = decoded.mapValues(\.value)
            } else {
                payload = nil
            }
            let record = TraceRecord(
                schemaVersion: schemaVersion,
                id: id,
                at: at,
                ingestOrder: ingestOrder,
                run: run,
                step: step,
                skillName: skillName,
                skillVersionHash: skillVersionHash,
                tag: tag,
                subject: subject,
                subjectKey: subjectKey,
                payload: payload,
                payloadHash: payloadHash,
                outcome: outcomeRaw.flatMap(TraceOutcome.init(rawValue:)),
                witness: witness,
                previousHash: previousHash,
                recordHash: recordHash,
                operationalDetail: operationalDetail,
                legacyKind: legacyKind
            )
            let expected = try CanonicalJSON.sha256Hex(for: record)
            guard expected == checksum else {
                throw TraceStoreError.invalidLineChecksum
            }
            records.append(record)
        }
        return records
    }

    func appendV1Envelope(_ envelope: SQLiteTraceEnvelope) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let json = String(decoding: try encoder.encode(envelope), as: UTF8.self)
        let sql = "INSERT INTO trace_envelopes_v1 (envelope_json, checksum) VALUES (?, ?);"
        let statement = try prepare(sql)
        defer { sqlite3_finalize(statement) }
        try bindText(statement, index: 1, json)
        try bindText(statement, index: 2, envelope.checksum)
        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw SQLiteTraceDatabaseError.stepFailed(errorMessage)
        }
    }

    private func readMeta(key: String) throws -> String? {
        let sql = "SELECT value FROM trace_meta WHERE key = ? LIMIT 1;"
        let statement = try prepare(sql)
        defer { sqlite3_finalize(statement) }
        try bindText(statement, index: 1, key)
        guard sqlite3_step(statement) == SQLITE_ROW else { return nil }
        guard let cString = sqlite3_column_text(statement, 0) else { return nil }
        return String(cString: cString)
    }

    private func setMeta(key: String, value: String) throws {
        let sql = "INSERT INTO trace_meta(key, value) VALUES(?, ?) ON CONFLICT(key) DO UPDATE SET value = excluded.value;"
        let statement = try prepare(sql)
        defer { sqlite3_finalize(statement) }
        try bindText(statement, index: 1, key)
        try bindText(statement, index: 2, value)
        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw SQLiteTraceDatabaseError.stepFailed(errorMessage)
        }
    }

    private func exec(_ sql: String) throws {
        guard sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK else {
            throw SQLiteTraceDatabaseError.execFailed(errorMessage)
        }
    }

    private func prepare(_ sql: String) throws -> OpaquePointer? {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw SQLiteTraceDatabaseError.prepareFailed(errorMessage)
        }
        return statement
    }

    private func bindText(_ statement: OpaquePointer?, index: Int32, _ value: String) throws {
        guard sqlite3_bind_text(statement, index, value, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self)) == SQLITE_OK else {
            throw SQLiteTraceDatabaseError.bindFailed(errorMessage)
        }
    }

    private func bindOptionalText(_ statement: OpaquePointer?, index: Int32, _ value: String?) throws {
        if let value {
            try bindText(statement, index: index, value)
        } else {
            guard sqlite3_bind_null(statement, index) == SQLITE_OK else {
                throw SQLiteTraceDatabaseError.bindFailed(errorMessage)
            }
        }
    }

    private func bindInt(_ statement: OpaquePointer?, index: Int32, _ value: Int) throws {
        guard sqlite3_bind_int(statement, index, Int32(value)) == SQLITE_OK else {
            throw SQLiteTraceDatabaseError.bindFailed(errorMessage)
        }
    }

    private func bindDouble(_ statement: OpaquePointer?, index: Int32, _ value: Double) throws {
        guard sqlite3_bind_double(statement, index, value) == SQLITE_OK else {
            throw SQLiteTraceDatabaseError.bindFailed(errorMessage)
        }
    }

    private var errorMessage: String {
        guard let db else { return "database not open" }
        return String(cString: sqlite3_errmsg(db))
    }

    private func columnText(_ statement: OpaquePointer?, _ index: Int32) -> String {
        guard let cString = sqlite3_column_text(statement, index) else { return "" }
        return String(cString: cString)
    }

    private func columnOptionalText(_ statement: OpaquePointer?, _ index: Int32) -> String? {
        guard sqlite3_column_type(statement, index) != SQLITE_NULL else { return nil }
        return columnText(statement, index)
    }
}
