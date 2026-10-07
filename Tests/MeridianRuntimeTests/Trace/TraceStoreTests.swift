import Foundation
import Testing
@testable import MeridianRuntime

@Suite("Trace TruthValue")
struct TruthValueTests {
    @Test("SEM-2-10 K3 truth table")
    func sem210() {
        let values = TruthValue.allCases
        let expectedAnd: [TruthValue: [TruthValue: TruthValue]] = [
            .true: [.true: .true, .false: .false, .indeterminate: .indeterminate],
            .false: [.true: .false, .false: .false, .indeterminate: .false],
            .indeterminate: [.true: .indeterminate, .false: .false, .indeterminate: .indeterminate]
        ]
        let expectedOr: [TruthValue: [TruthValue: TruthValue]] = [
            .true: [.true: .true, .false: .true, .indeterminate: .true],
            .false: [.true: .true, .false: .false, .indeterminate: .indeterminate],
            .indeterminate: [.true: .true, .false: .indeterminate, .indeterminate: .indeterminate]
        ]

        for lhs in values {
            for rhs in values {
                #expect(lhs.and(rhs) == expectedAnd[lhs]?[rhs])
                #expect(lhs.or(rhs) == expectedOr[lhs]?[rhs])
            }
        }
        #expect(TruthValue.true.not() == .false)
        #expect(TruthValue.false.not() == .true)
        #expect(TruthValue.indeterminate.not() == .indeterminate)
    }
}

@Suite("Trace utilities")
struct TraceUtilityTests {
    @Test("canonical JSON hash is stable across key order")
    func canonicalJSONStable() throws {
        let left = TraceRecord(
            id: "A",
            at: Date(timeIntervalSince1970: 1_700_000_000),
            ingestOrder: 1,
            run: "run-1",
            step: "step",
            skillName: "skill",
            skillVersionHash: "hash",
            tag: .emitted,
            subject: "subject",
            subjectKey: nil,
            payload: ["b": .number(2), "a": .record(["z": .string("1"), "y": .boolean(true)])],
            payloadHash: "payload",
            outcome: .success
        )
        let right = TraceRecord(
            id: "A",
            at: Date(timeIntervalSince1970: 1_700_000_000),
            ingestOrder: 1,
            run: "run-1",
            step: "step",
            skillName: "skill",
            skillVersionHash: "hash",
            tag: .emitted,
            subject: "subject",
            subjectKey: nil,
            payload: ["a": .record(["y": .boolean(true), "z": .string("1")]), "b": .number(2)],
            payloadHash: "payload",
            outcome: .success
        )

        #expect(try CanonicalJSON.sha256Hex(for: left) == CanonicalJSON.sha256Hex(for: right))
    }

    @Test("canonical JSON serializes every Value shape and escapes control characters")
    func canonicalJSONValueShapes() throws {
        let payload: [String: Value] = [
            "money": .money(Money(amount: Decimal(string: "12.50")!, currency: "USD")),
            "duration": .duration(.seconds(90)),
            "date": .date(Date(timeIntervalSince1970: 1_700_000_000)),
            "dateTime": .dateTime(Date(timeIntervalSince1970: 1_700_000_000)),
            "enum": .enumValue("open", kind: "status"),
            "reference": .reference("order-7"),
            "list": .list([.string("a\tb"), .null, .boolean(false)]),
            "opaque": .opaque(AnyHashableSendable(7)),
            "controls": .string("quote\" back\\ slash\u{08}\u{0C}\r\n\t\u{01}"),
        ]
        let json = String(data: try CanonicalJSON.data(for: payload), encoding: .utf8) ?? ""
        #expect(json.contains("12.5 USD"))
        #expect(json.contains("open"))
        #expect(json.contains("order-7"))
        #expect(json.contains("\\b"))
        #expect(json.contains("\\f"))
        #expect(json.contains("\\r"))
        #expect(json.contains("\\t"))
        #expect(json.contains("\\u0001"))
    }

    @Test("canonical JSON record serialization includes optional fields")
    func canonicalJSONRecordOptionalFields() throws {
        let record = TraceRecord(
            id: "A",
            at: Date(timeIntervalSince1970: 1_700_000_000),
            ingestOrder: 1,
            run: "run-1",
            step: "step",
            skillName: "skill",
            skillVersionHash: "hash",
            tag: .violated,
            subject: "subject",
            subjectKey: "key",
            payload: ["a": .string("b")],
            payloadHash: "payload",
            outcome: .failure,
            operationalDetail: "detail",
            legacyKind: "legacy"
        )
        let json = String(data: try CanonicalJSON.data(for: record), encoding: .utf8) ?? ""
        #expect(json.contains("\"subjectKey\":\"key\""))
        #expect(json.contains("\"operationalDetail\":\"detail\""))
        #expect(json.contains("\"legacyKind\":\"legacy\""))
    }

    @Test("monotonic ULID stays lexicographically ordered")
    func monotonicULID() async {
        let fixedDate = Date(timeIntervalSince1970: 1_700_000_000)
        let generator = TraceIDGenerator(now: { fixedDate }, randomBytes: { count in Array(repeating: 0, count: count) })
        let first = await generator.nextID()
        let second = await generator.nextID()
        let third = await generator.nextID()

        #expect(first < second)
        #expect(second < third)
        #expect(first.count == 26)
    }

    @Test("legacy Event Codable round-trips")
    func legacyEventDecodes() throws {
        let event = Event(
            timestamp: Date(timeIntervalSince1970: 1_700_000_001),
            runID: "run-1",
            sequence: 2,
            kind: .emit,
            payload: ["event": .string("hello"), "count": .number(2)]
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(Event.self, from: encoder.encode(event))

        #expect(decoded.kind == .emit)
        #expect(decoded.payload["event"] == .string("hello"))
        #expect(decoded.payload["count"] == .number(2))
    }
}

@Suite("Trace migration")
struct TraceMigrationTests {
    @Test("SEM_4_04 judgment boundary maps to a judged record carrying a payload hash, kind, and tool scope")
    func sem404JudgmentBoundary() throws {
        // A judgment boundary (`use judgment to …`) lowers to a plan-execution
        // step; its plan/plan-end events project to the `judged` trace tag. The
        // record must carry a content hash (the payload hash), preserve the kind
        // (`legacyKind`), and retain the explicit scoped tool ids from the payload.
        let event = Event(
            timestamp: Date(timeIntervalSince1970: 1_700_000_100),
            runID: "run-judge",
            sequence: 9,
            kind: .planStart,
            payload: [
                "mode": .string("plan_then_execute"),
                "tool_count": .number(Decimal(2)),
                "scoped_tools": .list([.string("ci.fix"), .string("shell.run")]),
                // SEM-4-04's remaining two witnesses beyond tool scope: the
                // input payload hash (fixed at planStart, so it round-trips
                // unchanged into planEnd) and the declared output kind.
                "input_payload_hash": .string("deadbeef"),
                "output_kind": .string("record"),
                "step": .string("root/aiJudgment")
            ]
        )
        let record = try TraceRecord(
            legacy: event,
            step: "root/aiJudgment",
            skillName: "release-sentinel",
            skillVersionHash: "v1",
            id: "01TESTJUDGED0000000000000",
            ingestOrder: 9
        )
        #expect(record.tag == .judged)
        #expect(record.legacyKind == EventKind.planStart.rawValue)
        #expect(!record.payloadHash.isEmpty)
        #expect(record.payload?["tool_count"] == .number(Decimal(2)))
        #expect(record.payload?["scoped_tools"] == .list([.string("ci.fix"), .string("shell.run")]))
        #expect(record.payload?["input_payload_hash"] == .string("deadbeef"))
        #expect(record.payload?["output_kind"] == .string("record"))

        let failure = Event(
            timestamp: Date(timeIntervalSince1970: 1_700_000_200),
            runID: "run-judge",
            sequence: 10,
            kind: .planError,
            payload: ["step": .string("root/aiJudgment")]
        )
        let failureRecord = try TraceRecord(
            legacy: failure,
            step: "root/aiJudgment",
            skillName: "release-sentinel",
            skillVersionHash: "v1",
            id: "01TESTJUDGED0000000000001",
            ingestOrder: 10
        )
        #expect(failureRecord.tag == .judged)
        #expect(failureRecord.outcome == .failure)
    }
}

@Suite("Trace stores")
struct TraceStoreTests {
    @Test("semantic event appends and queries through both stores")
    func verticalSliceThroughRuntime() async throws {
        let memoryStore = InMemoryTraceStore()
        let jsonlURL = try makeTempDirectory().appendingPathComponent("trace.jsonl")
        let jsonlStore = try JSONLTraceStore(fileURL: jsonlURL)

        for store in [memoryStore as any TraceStore, jsonlStore as any TraceStore] {
            let runtime = try Runtime.Builder()
                .setObserver(InMemoryObserver())
                .setTraceStore(store)
                .setTraceSkillIdentity(TraceSkillIdentity(name: "trace-skill", versionHash: "v1"))
                .build()

            await runtime.recordEvent(.emit, payload: ["event": .string("semantic.trace")])
            let records = try await store.query(
                scope: .currentRun,
                scopeSkills: [],
                runID: runtime.runID,
                skillName: "trace-skill",
                window: nil,
                pattern: TraceQueryPattern(tags: [.emitted], subject: "semantic.trace")
            )
            #expect(records.count == 1)
            #expect(records[0].tag == .emitted)
            #expect(records[0].subject == "semantic.trace")
        }
    }

    @Test("8A capability flags: both shipped stores report payload retention and persistence")
    func capabilityFlags() async throws {
        let memoryStore = InMemoryTraceStore()
        let jsonlURL = try makeTempDirectory().appendingPathComponent("trace.jsonl")
        let jsonlStore = try JSONLTraceStore(fileURL: jsonlURL)

        let memoryCaps = await memoryStore.capabilities
        #expect(memoryCaps.payloadRetention)
        #expect(!memoryCaps.isPersistent)

        let jsonlCaps = await jsonlStore.capabilities
        #expect(jsonlCaps.payloadRetention)
        #expect(jsonlCaps.isPersistent)
    }

    @Test("schema v1 records remain readable in v2 stores (N-1 reader)")
    func schemaV1ReaderRegression() async throws {
        let url = try makeTempDirectory().appendingPathComponent("v1.jsonl")
        let payload: [String: Value] = ["event": .string("legacy.trace")]
        let payloadHash = try CanonicalJSON.sha256Hex(for: payload)
        let v1Record: [String: Any] = [
            "schemaVersion": 1,
            "id": "01V1RECORD0000000000000000",
            "at": "2024-07-18T00:00:00Z",
            "ingestOrder": 1,
            "run": "run-v1",
            "step": "root",
            "skillName": "legacy-skill",
            "skillVersionHash": "v1",
            "tag": "emitted",
            "subject": "legacy.trace",
            "payload": ["event": "legacy.trace"],
            "payloadHash": payloadHash,
            "outcome": "success",
            "witness": "legacy-witness-field",
            "previousHash": "legacy-previous-hash",
            "recordHash": "legacy-record-hash",
            "legacyKind": "emit"
        ]
        let recordJSON = try JSONSerialization.data(withJSONObject: v1Record)
        let recordText = String(decoding: recordJSON, as: UTF8.self)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let checksum = try CanonicalJSON.sha256Hex(
            for: decoder.decode(TraceRecord.self, from: recordJSON)
        )
        let envelope = "{\"checksum\":\"\(checksum)\",\"record\":\(recordText)}\n"
        try Data(envelope.utf8).write(to: url)

        let store = try JSONLTraceStore(fileURL: url)
        let records = try await store.query(
            scope: .currentRun,
            scopeSkills: [],
            runID: "run-v1",
            skillName: nil,
            window: nil,
            pattern: nil
        )
        #expect(records.count == 1)
        #expect(records[0].id == "01V1RECORD0000000000000000")
        #expect(records[0].legacyKind == "emit")
    }

    @Test("SEM-4-01 append-only within retention and retention compaction drops expired only")
    func sem401Compaction() async throws {
        let store = InMemoryTraceStore()
        let now = Date(timeIntervalSince1970: 1_700_001_000)
        try await store.append(makeRecord(id: "A", at: now.addingTimeInterval(-7_200), run: "run-1", ingestOrder: 1, tag: .emitted))
        try await store.append(makeRecord(id: "B", at: now.addingTimeInterval(-60), run: "run-1", ingestOrder: 2, tag: .emitted))
        try await store.append(makeRecord(id: "C", at: now, run: "run-1", ingestOrder: 3, tag: .completed))

        try await store.compact(retention: .seconds(3_600), now: now)
        let records = try await store.query(scope: .currentRun, scopeSkills: [], runID: "run-1", skillName: nil, window: nil, pattern: nil)

        #expect(records.map(\.id) == ["B", "C"])
    }

    @Test("SEM-4-02 ordering uses run order locally and at-ingest-id globally")
    func sem402Ordering() async throws {
        let store = InMemoryTraceStore()
        let t0 = Date(timeIntervalSince1970: 100)
        try await store.append(makeRecord(id: "Z", at: t0, run: "run-1", ingestOrder: 2, tag: .emitted))
        try await store.append(makeRecord(id: "A", at: t0, run: "run-1", ingestOrder: 1, tag: .invoked))
        try await store.append(makeRecord(id: "M", at: t0.addingTimeInterval(1), run: "run-2", ingestOrder: 1, tag: .completed))

        let runLocal = try await store.query(scope: .currentRun, scopeSkills: [], runID: "run-1", skillName: nil, window: nil, pattern: nil)
        let global = try await store.query(scope: .acrossAllRuns, scopeSkills: [], runID: nil, skillName: nil, window: nil, pattern: nil)

        #expect(runLocal.map(\.id) == ["A", "Z"])
        #expect(global.map(\.id) == ["A", "Z", "M"])
    }

    @Test("run-local ordering falls back to timestamp when ingest order ties")
    func runLocalOrderingUsesTimestampTieBreak() async throws {
        let store = InMemoryTraceStore()
        let t0 = Date(timeIntervalSince1970: 100)
        try await store.append(makeRecord(id: "late", at: t0.addingTimeInterval(1), run: "run-1", ingestOrder: 1, tag: .emitted))
        try await store.append(makeRecord(id: "early", at: t0, run: "run-1", ingestOrder: 1, tag: .invoked))

        let records = try await store.query(scope: .currentRun, scopeSkills: [], runID: "run-1", skillName: nil, window: nil, pattern: nil)
        #expect(records.map(\.id) == ["early", "late"])
    }

    @Test("append rejects unsupported trace schema versions")
    func unsupportedSchemaRejected() async throws {
        let store = InMemoryTraceStore()
        let record = TraceRecord(
            schemaVersion: TraceRecord.currentSchemaVersion + 10,
            id: "future",
            at: Date(timeIntervalSince1970: 100),
            ingestOrder: 1,
            run: "run-1",
            step: "trace.step",
            skillName: "skill",
            skillVersionHash: "hash",
            tag: .emitted,
            subject: "subject",
            subjectKey: nil,
            payload: [:],
            payloadHash: "hash",
            outcome: .success
        )

        await #expect(throws: TraceStoreError.self) {
            try await store.append(record)
        }
    }

    @Test("SEM-4-05 ingest fallback assigns monotone ingest order")
    func sem405IngestFallback() async throws {
        let store = InMemoryTraceStore()
        let at = Date(timeIntervalSince1970: 200)
        try await store.append(makeRecord(id: "A", at: at, run: "run-1", ingestOrder: 0, tag: .emitted))
        try await store.append(makeRecord(id: "B", at: at, run: "run-1", ingestOrder: 0, tag: .emitted))
        let records = try await store.query(scope: .currentRun, scopeSkills: [], runID: "run-1", skillName: nil, window: nil, pattern: nil)

        #expect(records[0].ingestOrder == 1)
        #expect(records[1].ingestOrder == 2)
    }

    @Test("RISK-W8-05 in-memory and JSONL stores stay behaviorally aligned")
    func differentialStores() async throws {
        let tempRoot = try makeTempDirectory()
        let memory = InMemoryTraceStore()
        let jsonl = try JSONLTraceStore(fileURL: tempRoot.appendingPathComponent("trace.jsonl"))
        let inputs = [
            makeRecord(id: "A", at: Date(timeIntervalSince1970: 1), run: "r-1", ingestOrder: 0, tag: .invoked, subject: "tool"),
            makeRecord(id: "B", at: Date(timeIntervalSince1970: 2), run: "r-1", ingestOrder: 0, tag: .completed, subject: "tool"),
            makeRecord(id: "C", at: Date(timeIntervalSince1970: 2), run: "r-2", ingestOrder: 0, tag: .failed, subject: "tool")
        ]

        for record in inputs {
            try await memory.append(record)
            try await jsonl.append(record)
        }

        let memoryRecords = try await memory.query(scope: .acrossAllRuns, scopeSkills: [], runID: nil, skillName: nil, window: nil, pattern: nil)
        let jsonlRecords = try await jsonl.query(scope: .acrossAllRuns, scopeSkills: [], runID: nil, skillName: nil, window: nil, pattern: nil)
        #expect(memoryRecords == jsonlRecords)
    }

    @Test("SEM-4-07 fail-open emits a degraded-witnessing marker after recovery")
    func sem407FailOpenRecoveryMarker() async throws {
        let observer = InMemoryObserver()
        let store = FailingTraceStore(failuresRemaining: 1)
        let runtime = Runtime(
            toolRegistry: ToolRegistry(),
            observer: observer,
            traceStore: store,
            runID: "run-1",
            traceConfiguration: TraceConfiguration(storeFailurePolicy: .failOpen),
            traceSkillIdentity: TraceSkillIdentity(name: "deploy", versionHash: "v1")
        )

        await runtime.recordEvent(.emit, payload: ["event": .string("first"), "step": .string("/deploy/root")])
        await runtime.recordEvent(.emit, payload: ["event": .string("second"), "step": .string("/deploy/root")])

        let records = try await store.query(scope: .acrossAllRuns, scopeSkills: [], runID: nil, skillName: "deploy", window: nil, pattern: nil)
        #expect(records.compactMap(\.subject).contains("trace-store"),
                Comment(rawValue: records.map { $0.subject ?? "<nil>" }.joined(separator: ", ")))
        #expect(records.contains { $0.subject == "trace-store" && $0.operationalDetail == "degraded-witnessing-marker" })
        #expect(records.contains { $0.payloadHash.isEmpty == false })
    }

    @Test("SEM-4-07 fail-closed rethrows append failures on strict emits")
    func sem407FailClosed() async throws {
        let runtime = Runtime(
            toolRegistry: ToolRegistry(),
            observer: InMemoryObserver(),
            traceStore: FailingTraceStore(failuresRemaining: 1),
            runID: "run-1",
            traceConfiguration: TraceConfiguration(storeFailurePolicy: .failClosed),
            traceSkillIdentity: TraceSkillIdentity(name: "deploy", versionHash: "v1")
        )

        await #expect(throws: MeridianRuntimeError.self) {
            try await runtime.emit(event: "deploy.failed", payload: [:], step: "/deploy/root")
        }
    }

    @Test("torn final JSONL line is quarantined and ignored on reopen")
    func tornFinalLineRecovery() async throws {
        let tempRoot = try makeTempDirectory()
        let fileURL = tempRoot.appendingPathComponent("trace.jsonl")
        let store = try JSONLTraceStore(fileURL: fileURL)
        try await store.append(makeRecord(id: "A", at: Date(timeIntervalSince1970: 1), run: "run-1", ingestOrder: 1, tag: .emitted))

        if let handle = try? FileHandle(forWritingTo: fileURL) {
            try handle.seekToEnd()
            try handle.write(contentsOf: Data("{\"broken\":".utf8))
            try handle.close()
        }

        let reopened = try JSONLTraceStore(fileURL: fileURL)
        let records = try await reopened.query(scope: .acrossAllRuns, scopeSkills: [], runID: nil, skillName: nil, window: nil, pattern: nil)
        let sidecars = try FileManager.default.contentsOfDirectory(at: tempRoot, includingPropertiesForKeys: nil)
        #expect(records.count == 1)
        #expect(sidecars.contains { $0.lastPathComponent.contains(".quarantine-") })
    }

    @Test("indexed query smoke narrows by tag and subject")
    func indexedQuerySmoke() async throws {
        let tempRoot = try makeTempDirectory()
        let store = try JSONLTraceStore(fileURL: tempRoot.appendingPathComponent("trace.jsonl"))
        try await store.append(makeRecord(id: "A", at: Date(timeIntervalSince1970: 1), run: "run-1", ingestOrder: 1, tag: .emitted, subject: "alpha"))
        try await store.append(makeRecord(id: "B", at: Date(timeIntervalSince1970: 2), run: "run-1", ingestOrder: 2, tag: .completed, subject: "alpha"))
        try await store.append(makeRecord(id: "C", at: Date(timeIntervalSince1970: 3), run: "run-2", ingestOrder: 3, tag: .emitted, subject: "beta"))

        let records = try await store.query(
            scope: .acrossAllRuns,
            scopeSkills: [],
            runID: nil,
            skillName: nil,
            window: nil,
            pattern: TraceQueryPattern(tags: [.emitted], subject: "beta")
        )

        #expect(records.map(\.id) == ["C"])
    }
}

private func makeRecord(
    id: String,
    at: Date,
    run: String,
    ingestOrder: Int,
    tag: TraceTag,
    subject: String? = "subject",
    skillName: String = "skill",
    skillVersionHash: String = "hash"
) -> TraceRecord {
    let payload: [String: Value] = ["id": .string(id)]
    return TraceRecord(
        id: id,
        at: at,
        ingestOrder: ingestOrder,
        run: run,
        step: "trace.step",
        skillName: skillName,
        skillVersionHash: skillVersionHash,
        tag: tag,
        subject: subject,
        subjectKey: nil,
        payload: payload,
        payloadHash: (try? CanonicalJSON.sha256Hex(for: payload)) ?? "",
        outcome: tag == .failed || tag == .assertFailed ? .failure : .success
    )
}

private func makeTempDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("trace-tests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

private actor FailingTraceStore: TraceStore {
    private var failuresRemaining: Int
    private let backing = InMemoryTraceStore()

    init(failuresRemaining: Int) {
        self.failuresRemaining = failuresRemaining
    }

    var capabilities: TraceStoreCapabilities {
        get async { await backing.capabilities }
    }

    func append(_ event: TraceRecord) async throws {
        if failuresRemaining > 0 {
            failuresRemaining -= 1
            throw TraceStoreError.traceStoreFailure("simulated append failure")
        }
        try await backing.append(event)
    }

    func query(
        scope: TraceScope,
        scopeSkills: [String],
        runID: String?,
        skillName: String?,
        window: TraceWindow?,
        pattern: TraceQueryPattern?
    ) async throws -> [TraceRecord] {
        try await backing.query(
            scope: scope,
            scopeSkills: scopeSkills,
            runID: runID,
            skillName: skillName,
            window: window,
            pattern: pattern
        )
    }

    func compact(retention: Duration, now: Date) async throws {
        try await backing.compact(retention: retention, now: now)
    }
}
