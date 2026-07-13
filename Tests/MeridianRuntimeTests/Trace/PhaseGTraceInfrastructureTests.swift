import CryptoKit
import Foundation
import Testing
@testable import MeridianRuntime

@Suite("Phase G trace infrastructure")
struct PhaseGTraceInfrastructureTests {
    @Test("SQLite trace store round-trips and filters like JSONL")
    func sqliteRoundTripAndQuery() async throws {
        let url = try makeTempDirectory().appendingPathComponent("trace.sqlite")
        let store = try SQLiteTraceStore(fileURL: url)
        let records = [
            makeRecord(id: "A", at: Date(timeIntervalSince1970: 1), run: "run-1", ingestOrder: 1, tag: .emitted, subject: "alpha"),
            makeRecord(id: "B", at: Date(timeIntervalSince1970: 2), run: "run-1", ingestOrder: 2, tag: .completed, subject: "alpha"),
            makeRecord(id: "C", at: Date(timeIntervalSince1970: 3), run: "run-2", ingestOrder: 3, tag: .emitted, subject: "beta")
        ]
        for record in records {
            try await store.append(record)
        }

        let reopened = try SQLiteTraceStore(fileURL: url)
        let filtered = try await reopened.query(
            scope: .acrossAllRuns,
            scopeSkills: [],
            runID: nil,
            skillName: nil,
            window: nil,
            pattern: TraceQueryPattern(tags: [.emitted], subject: "beta")
        )
        #expect(filtered.map(\.id) == ["C"])

        let runLocal = try await reopened.query(
            scope: .currentRun,
            scopeSkills: [],
            runID: "run-1",
            skillName: nil,
            window: nil,
            pattern: nil
        )
        #expect(runLocal.map(\.id) == ["A", "B"])
    }

    @Test("SQLite storage schema v2 reader loads v1 envelope data")
    func sqliteNMinusOneMigration() async throws {
        let url = try makeTempDirectory().appendingPathComponent("trace-v1.sqlite")
        let database = try SQLiteTraceDatabase(fileURL: url)
        let record = makeRecord(id: "legacy", at: Date(timeIntervalSince1970: 10), run: "run-v1", ingestOrder: 1, tag: .invoked)
        let envelope = SQLiteTraceEnvelope(record: record, checksum: try CanonicalJSON.sha256Hex(for: record))
        try database.appendV1Envelope(envelope)

        let store = try SQLiteTraceStore(fileURL: url)
        let loaded = try await store.query(
            scope: .acrossAllRuns,
            scopeSkills: [],
            runID: nil,
            skillName: nil,
            window: nil,
            pattern: nil
        )
        #expect(loaded.count == 1)
        #expect(loaded[0].id == "legacy")
    }

    @Test("HTTP trace store client appends and queries via protocol")
    func httpTraceStoreClient() async throws {
        let server = MockHTTPTraceServer()
        let client = HTTPTraceStoreClient(transport: server)
        try await client.append(makeRecord(id: "H1", at: Date(timeIntervalSince1970: 1), run: "run-http", ingestOrder: 1, tag: .emitted, subject: "tool"))
        try await client.append(makeRecord(id: "H2", at: Date(timeIntervalSince1970: 2), run: "run-http", ingestOrder: 2, tag: .completed, subject: "tool"))

        let records = try await client.query(
            scope: .currentRun,
            scopeSkills: [],
            runID: "run-http",
            skillName: nil,
            window: nil,
            pattern: TraceQueryPattern(tags: [.completed])
        )
        #expect(records.map(\.id) == ["H2"])
    }

    @Test("OTLP exporter maps trace records to OTLP JSON spans")
    func otlpPayloadShape() throws {
        let record = makeRecord(id: "OTLP01", at: Date(timeIntervalSince1970: 100), run: "run-otlp", ingestOrder: 1, tag: .judged, subject: "planner")
        let request = OTLPTraceExporter.exportRequest(for: [record], serviceName: "meridian-test")
        #expect(request.resourceSpans.count == 1)
        let span = request.resourceSpans[0].scopeSpans[0].spans[0]
        #expect(span.name == "judged")
        #expect(span.attributes.contains { $0.key == "meridian.payload_hash" })
        #expect(request.resourceSpans[0].resource.attributes.contains { $0.key == "service.name" })
        let encoded = try JSONEncoder().encode(request)
        let json = String(decoding: encoded, as: UTF8.self)
        #expect(json.contains("resourceSpans"))
        #expect(json.contains("meridian.payload_hash"))
    }

    @Test("trace batch anchor signs and verifies with HMAC")
    func traceBatchSigningRoundTrip() throws {
        let records = [
            makeRecord(id: "S1", at: Date(timeIntervalSince1970: 1), run: "run-sign", ingestOrder: 1, tag: .emitted),
            makeRecord(id: "S2", at: Date(timeIntervalSince1970: 2), run: "run-sign", ingestOrder: 2, tag: .completed)
        ]
        let key = SymmetricKey(data: Data(repeating: 0xAB, count: 32))
        let anchor = try TraceBatchSigner.anchor(
            records: records,
            runID: "run-sign",
            anchoredAt: Date(timeIntervalSince1970: 3),
            signingKey: key
        )
        #expect(anchor.algorithm == .hmacSHA256)
        #expect(anchor.signature?.isEmpty == false)
        #expect(try TraceBatchSigner.verify(anchor: anchor, key: key))
    }

    @Test("trace batch anchor signs and verifies with Ed25519")
    func traceBatchEd25519SigningRoundTrip() throws {
        let records = [
            makeRecord(id: "E1", at: Date(timeIntervalSince1970: 1), run: "run-ed", ingestOrder: 1, tag: .emitted),
            makeRecord(id: "E2", at: Date(timeIntervalSince1970: 2), run: "run-ed", ingestOrder: 2, tag: .completed)
        ]
        let privateKey = Curve25519.Signing.PrivateKey()
        let anchor = try TraceBatchSigner.anchor(
            records: records,
            runID: "run-ed",
            anchoredAt: Date(timeIntervalSince1970: 3),
            ed25519PrivateKey: privateKey
        )
        #expect(anchor.algorithm == .ed25519)
        #expect(anchor.signature?.isEmpty == false)
        #expect(try TraceBatchSigner.verify(anchor: anchor, publicKey: privateKey.publicKey))
    }

    @Test("D12 witness envelope capture modes redact PII and omit body")
    func witnessCaptureModes() throws {
        let body: [String: Value] = [
            "email": .string("user@example.com"),
            "order_id": .string("42")
        ]
        let full = try WitnessCapture.buildEnvelope(body: body, mode: .full)
        #expect(full.body?["email"] == .string("user@example.com"))

        let redacted = try WitnessCapture.buildEnvelope(
            body: body,
            mode: .redacted,
            redactedFields: ["email"]
        )
        #expect(redacted.body?["email"] == .string("<redacted>"))
        #expect(redacted.witnessHash == full.witnessHash)

        let hashOnly = try WitnessCapture.buildEnvelope(body: body, mode: .hashOnly, subjectKey: "42")
        #expect(hashOnly.body == nil)
        #expect(hashOnly.subjectKey == "42")

        let omitted = try WitnessCapture.buildEnvelope(body: body, mode: .omitted, subjectKey: "42")
        #expect(omitted.body == nil)
        #expect(omitted.subjectKey == nil)
    }

    @Test("shell.run invoke traces redact command and output_summary")
    func shellHoleRedaction() async throws {
        let observer = InMemoryObserver()
        let registry = ToolRegistry()
        await registry.register(tool: "shell.run", .closure { _ in .string("secret-output") })
        let runtime = Runtime(toolRegistry: registry, observer: observer, runID: "shell-redact")

        _ = try await runtime.invoke(
            tool: "shell.run",
            args: ["command": .string("echo secret")],
            capturePolicy: .redacted(["command"])
        )

        let starts = await observer.events.filter { $0.kind == .invokeStart }
        let ends = await observer.events.filter { $0.kind == .invokeEnd }
        if case .record(let args) = starts[0].payload["args"] {
            #expect(args["command"] == .string("<redacted>"))
        } else {
            Issue.record("expected invoke args record")
        }
        #expect(ends[0].payload["output_summary"] == .string("<redacted>"))
    }

    @Test("recordViolation emits D12 witness envelope on trace store")
    func recordViolationWitnessEnvelope() async throws {
        let store = InMemoryTraceStore()
        let runtime = Runtime(
            toolRegistry: ToolRegistry(),
            observer: InMemoryObserver(),
            traceStore: store,
            runID: "violation-run",
            traceSkillIdentity: TraceSkillIdentity(name: "policy", versionHash: "v1")
        )
        await #expect(throws: MeridianRuntimeError.self) {
            try await runtime.recordViolation(
                obligationId: "no-shell",
                disposition: "prevented",
                blocking: true,
                witness: ["email": .string("leak@corp.com"), "command": .string("rm -rf /")],
                witnessCapture: .redacted,
                witnessSubjectKey: "user-1",
                failingCount: 2
            )
        }
        let records = try await store.query(
            scope: .acrossAllRuns,
            scopeSkills: [],
            runID: nil,
            skillName: "policy",
            window: nil,
            pattern: TraceQueryPattern(tags: [.violated])
        )
        #expect(records.count == 1)
        #expect(records[0].witness?.contains("witnessHash") == true)
        #expect(records[0].witness?.contains("<redacted>") == true)
        #expect(records[0].witness?.contains("leak@corp.com") == false)
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
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("phase-g-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

private actor MockHTTPTraceServer: HTTPTraceTransport {
    private var records: [TraceRecord] = []
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init() {
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    func post(path: String, body: Data) async throws -> Data {
        if path.hasSuffix("append") {
            let request = try decoder.decode(HTTPTraceAppendRequest.self, from: body)
            let expected = try CanonicalJSON.sha256Hex(for: request.record)
            guard expected == request.checksum else {
                throw TraceStoreError.invalidLineChecksum
            }
            records.append(request.record)
            return Data("{}".utf8)
        }
        if path.hasSuffix("query") {
            let request = try decoder.decode(HTTPTraceQueryRequest.self, from: body)
            let filtered = TraceStoreHelpers.filterAndSort(
                records,
                scope: request.scope,
                scopeSkills: request.scopeSkills,
                runID: request.runID,
                skillName: request.skillName,
                window: request.window,
                pattern: request.pattern
            )
            return try encoder.encode(HTTPTraceQueryResponse(records: filtered))
        }
        throw TraceStoreError.traceStoreFailure("unknown path \(path)")
    }
}
