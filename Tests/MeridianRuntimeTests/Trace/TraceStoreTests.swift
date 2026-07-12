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
    @Test("all legacy EventKind cases round-trip through semantic trace projection")
    func allKindsRoundTrip() throws {
        for kind in allEventKinds {
            let event = Event(
                timestamp: Date(timeIntervalSince1970: 1_700_000_002),
                runID: "run-1",
                sequence: 3,
                kind: kind,
                payload: samplePayload(for: kind)
            )
            let record = try TraceRecord(
                legacy: event,
                step: "trace.step",
                skillName: "skill",
                skillVersionHash: "hash",
                id: "01TESTTRACE00000000000000",
                ingestOrder: 3
            )
            let projected = Event(fromSemantic: record)
            #expect(projected.kind == kind, Comment(rawValue: "kind \(kind.rawValue) projected as \(projected.kind.rawValue)"))
            #expect(record.legacyKind == kind.rawValue)
        }
    }

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

    @Test("8A capability flags: both shipped stores report payload retention and hash chaining per configuration")
    func capabilityFlags() async throws {
        let memoryStore = InMemoryTraceStore(configuration: TraceConfiguration(hashChaining: true))
        let jsonlURL = try makeTempDirectory().appendingPathComponent("trace.jsonl")
        let jsonlStore = try JSONLTraceStore(fileURL: jsonlURL, configuration: TraceConfiguration(hashChaining: false))

        let memoryCaps = await memoryStore.capabilities
        #expect(memoryCaps.payloadRetention)
        #expect(memoryCaps.supportsHashChaining)
        #expect(!memoryCaps.isPersistent)

        let jsonlCaps = await jsonlStore.capabilities
        #expect(jsonlCaps.payloadRetention)
        #expect(!jsonlCaps.supportsHashChaining)
        #expect(jsonlCaps.isPersistent)
    }

    @Test("SEM-4-01 append-only within retention and retention compaction drops expired only")
    func sem401Compaction() async throws {
        let store = InMemoryTraceStore()
        let now = Date(timeIntervalSince1970: 1_700_001_000)
        try await store.append(makeRecord(id: "A", at: now.addingTimeInterval(-7_200), run: "run-1", ingestOrder: 1, tag: .emitted))
        try await store.append(makeRecord(id: "B", at: now.addingTimeInterval(-60), run: "run-1", ingestOrder: 2, tag: .emitted))
        try await store.append(makeRecord(id: "C", at: now, run: "run-1", ingestOrder: 3, tag: .completed))

        try await store.compact(retention: .seconds(3_600), now: now)
        let records = try await store.query(scope: .currentRun, runID: "run-1", skillName: nil, window: nil, pattern: nil)

        #expect(records.map(\.id) == ["B", "C"])
    }

    @Test("SEM-4-02 ordering uses run order locally and at-ingest-id globally")
    func sem402Ordering() async throws {
        let store = InMemoryTraceStore()
        let t0 = Date(timeIntervalSince1970: 100)
        try await store.append(makeRecord(id: "Z", at: t0, run: "run-1", ingestOrder: 2, tag: .emitted))
        try await store.append(makeRecord(id: "A", at: t0, run: "run-1", ingestOrder: 1, tag: .invoked))
        try await store.append(makeRecord(id: "M", at: t0.addingTimeInterval(1), run: "run-2", ingestOrder: 1, tag: .completed))

        let runLocal = try await store.query(scope: .currentRun, runID: "run-1", skillName: nil, window: nil, pattern: nil)
        let global = try await store.query(scope: .acrossAllRuns, runID: nil, skillName: nil, window: nil, pattern: nil)

        #expect(runLocal.map(\.id) == ["A", "Z"])
        #expect(global.map(\.id) == ["A", "Z", "M"])
    }

    @Test("run-local ordering falls back to timestamp when ingest order ties")
    func runLocalOrderingUsesTimestampTieBreak() async throws {
        let store = InMemoryTraceStore()
        let t0 = Date(timeIntervalSince1970: 100)
        try await store.append(makeRecord(id: "late", at: t0.addingTimeInterval(1), run: "run-1", ingestOrder: 1, tag: .emitted))
        try await store.append(makeRecord(id: "early", at: t0, run: "run-1", ingestOrder: 1, tag: .invoked))

        let records = try await store.query(scope: .currentRun, runID: "run-1", skillName: nil, window: nil, pattern: nil)
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
        let records = try await store.query(scope: .currentRun, runID: "run-1", skillName: nil, window: nil, pattern: nil)

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

        let memoryRecords = try await memory.query(scope: .acrossAllRuns, runID: nil, skillName: nil, window: nil, pattern: nil)
        let jsonlRecords = try await jsonl.query(scope: .acrossAllRuns, runID: nil, skillName: nil, window: nil, pattern: nil)
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

        let records = try await store.query(scope: .acrossAllRuns, runID: nil, skillName: "deploy", window: nil, pattern: nil)
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
        let records = try await reopened.query(scope: .acrossAllRuns, runID: nil, skillName: nil, window: nil, pattern: nil)
        let sidecars = try FileManager.default.contentsOfDirectory(at: tempRoot, includingPropertiesForKeys: nil)
        #expect(records.count == 1)
        #expect(sidecars.contains { $0.lastPathComponent.contains(".quarantine-") })
    }

    @Test("hash chain verifies and detects tampering")
    func hashChainVerification() async throws {
        let store = InMemoryTraceStore(configuration: TraceConfiguration(hashChaining: true))
        try await store.append(makeRecord(id: "A", at: Date(timeIntervalSince1970: 1), run: "run-1", ingestOrder: 1, tag: .emitted))
        try await store.append(makeRecord(id: "B", at: Date(timeIntervalSince1970: 2), run: "run-1", ingestOrder: 2, tag: .completed))

        let valid = try await store.verifyChain(runID: "run-1")
        #expect(valid.isValid)

        let records = try await store.query(scope: .currentRun, runID: "run-1", skillName: nil, window: nil, pattern: nil)
        let tampered = TraceRecord(
            schemaVersion: records[1].schemaVersion,
            id: records[1].id,
            at: records[1].at,
            ingestOrder: records[1].ingestOrder,
            run: records[1].run,
            step: records[1].step,
            skillName: records[1].skillName,
            skillVersionHash: records[1].skillVersionHash,
            tag: records[1].tag,
            subject: records[1].subject,
            subjectKey: records[1].subjectKey,
            payload: ["tampered": .boolean(true)],
            payloadHash: records[1].payloadHash,
            outcome: records[1].outcome,
            witness: records[1].witness,
            previousHash: records[1].previousHash,
            recordHash: records[1].recordHash,
            operationalDetail: records[1].operationalDetail,
            legacyKind: records[1].legacyKind
        )
        let tamperedResult = HashChain.verify(records: [records[0], tampered], runID: "run-1")
        #expect(!tamperedResult.isValid)
        #expect(tamperedResult.failure?.reason == .recordHashMismatch)
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
            runID: nil,
            skillName: nil,
            window: nil,
            pattern: TraceQueryPattern(tags: [.emitted], subject: "beta")
        )

        #expect(records.map(\.id) == ["C"])
    }
}

private let allEventKinds: [EventKind] = [
    .workflowStarted,
    .workflowCompleted,
    .workflowFailed,
    .workflowCancelled,
    .workflowSuspended,
    .workflowResumed,
    .bind,
    .invokeStart,
    .invokeEnd,
    .invokeError,
    .planStart,
    .planEnd,
    .planError,
    .planRejected,
    .autonomyStart,
    .autonomyStep,
    .autonomyEnd,
    .branchTaken,
    .iterateStart,
    .iterateIteration,
    .iterateEnd,
    .assertPassed,
    .assertFailed,
    .emit,
    .emitError,
    .waitStart,
    .waitResume,
    .commit,
    .recoverEngaged
]

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

private func samplePayload(for kind: EventKind) -> [String: Value] {
    switch kind {
    case .workflowStarted, .workflowCompleted, .workflowFailed:
        return ["workflow": .string("workflow")]
    case .invokeStart, .invokeEnd, .invokeError, .autonomyStep:
        return ["tool": .string("tool")]
    case .emit:
        return ["event": .string("event")]
    case .waitStart:
        return ["kind": .string("signal"), "name": .string("approval")]
    default:
        return ["message": .string(kind.rawValue)]
    }
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
        runID: String?,
        skillName: String?,
        window: TraceWindow?,
        pattern: TraceQueryPattern?
    ) async throws -> [TraceRecord] {
        try await backing.query(scope: scope, runID: runID, skillName: skillName, window: window, pattern: pattern)
    }

    func compact(retention: Duration, now: Date) async throws {
        try await backing.compact(retention: retention, now: now)
    }

    func verifyChain(runID: String) async throws -> TraceChainVerificationResult {
        try await backing.verifyChain(runID: runID)
    }
}
