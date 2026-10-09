import Foundation
import Testing
@testable import MeridianRuntime
import MeridianTestKit

@Suite("CLI command — trace verify (process)")
struct TraceVerifyCLISlowTests {
    @Test("trace verify succeeds on a valid semantic chain")
    func success() async throws {
        let fixture = try await makeTraceVerifyFixture()
        let bin = try slowLocateMeridianBinary()
        let verify = try slowRunMeridian(bin, [
            "trace", "verify", fixture.fileURL.path, "--run", fixture.runID
        ])
        #expect(verify.exitCode == 0, Comment(rawValue: verify.stderr + verify.stdout))
        #expect(verify.stdout.contains("Trace verification passed"), Comment(rawValue: verify.stdout))
        #expect(verify.stdout.contains("content: ok"), Comment(rawValue: verify.stdout))
    }

    @Test("trace-verify reports tampering and exits non-zero")
    func tamperFailure() async throws {
        let fixture = try await makeTraceVerifyFixture()
        try tamperTracePayload(in: fixture.fileURL, targetLine: 2)

        let bin = try slowLocateMeridianBinary()
        let verify = try slowRunMeridian(bin, [
            "trace-verify", fixture.fileURL.path, "--run", fixture.runID
        ])
        #expect(verify.exitCode == 1, Comment(rawValue: verify.stderr + verify.stdout))
        #expect(verify.stdout.contains("Trace verification failed"), Comment(rawValue: verify.stdout))
        #expect(verify.stdout.contains("line_checksum_mismatch"), Comment(rawValue: verify.stdout))
    }

    @Test("trace verify --json emits the stable schema fields")
    func jsonSchema() async throws {
        let fixture = try await makeTraceVerifyFixture()
        let bin = try slowLocateMeridianBinary()
        let verify = try slowRunMeridian(bin, [
            "trace", "verify", fixture.fileURL.path, "--run", fixture.runID, "--json"
        ])
        #expect(verify.exitCode == 0, Comment(rawValue: verify.stderr + verify.stdout))

        let report = try decodeTraceVerifyJSON(verify.stdout)
        #expect(report.file.hasSuffix("events.jsonl"))
        #expect(report.runID == fixture.runID)
        #expect(report.ok)
        #expect(report.lineCount >= 3)
        #expect(report.matchedRunRecords == 3)
        #expect(report.schemaVersions.contains(TraceRecord.currentSchemaVersion))
        #expect(report.checks.schema)
        #expect(report.checks.checksums)
        #expect(report.checks.order)
        #expect(report.checks.content)
        #expect(!report.quarantine.present)
    }
}

private struct TraceVerifyJSONChecks: Decodable {
    var schema: Bool
    var checksums: Bool
    var order: Bool
    var content: Bool
}

private struct TraceVerifyJSONQuarantine: Decodable {
    var present: Bool
    var files: [String]
}

private struct TraceVerifyJSONReport: Decodable {
    var file: String
    var runID: String
    var ok: Bool
    var lineCount: Int
    var matchedRunRecords: Int
    var schemaVersions: [Int]
    var checks: TraceVerifyJSONChecks
    var quarantine: TraceVerifyJSONQuarantine
    var issues: [TraceVerifyJSONIssue]

    enum CodingKeys: String, CodingKey {
        case file
        case runID = "run_id"
        case ok
        case lineCount = "line_count"
        case matchedRunRecords = "matched_run_records"
        case schemaVersions = "schema_versions"
        case checks
        case quarantine
        case issues
    }
}

private struct TraceVerifyJSONIssue: Decodable {
    var kind: String
    var message: String
    var line: Int?
    var recordID: String?

    enum CodingKeys: String, CodingKey {
        case kind
        case message
        case line
        case recordID = "record_id"
    }
}

private struct TraceVerifyFixture {
    var dir: SlowTempDir
    var fileURL: URL
    var runID: String
}

private struct TestTraceLineEnvelope: Codable {
    var record: TraceRecord
    var checksum: String
}

private func decodeTraceVerifyJSON(_ text: String) throws -> TraceVerifyJSONReport {
    try JSONDecoder().decode(TraceVerifyJSONReport.self, from: Data(text.utf8))
}

private func makeTraceVerifyFixture() async throws -> TraceVerifyFixture {
    let t = SlowTempDir(prefix: "meridian-trace-verify")
    let fileURL = t.url.appendingPathComponent("events.jsonl")
    let store = try JSONLTraceStore(fileURL: fileURL)
    let runID = "trace-verify-run"
    let base = Date(timeIntervalSince1970: 1_720_656_000)

    let validatePayload: [String: Value] = [
        "tool": .string("validateOrder")
    ]
    try await store.append(TraceRecord(
        id: "rec-1",
        at: base,
        ingestOrder: 0,
        run: runID,
        step: "root/validate",
        skillName: "TraceVerifyFlow",
        skillVersionHash: "v1",
        tag: .invoked,
        subject: "validateOrder",
        payload: validatePayload,
        payloadHash: try CanonicalJSON.sha256Hex(for: validatePayload),
        outcome: .success,
        operationalDetail: nil,
        kind: .invokeStart
    ))

    let riskPayload: [String: Value] = [
        "decision": .string("approve"),
        "score": .number(Decimal(string: "0.9")!)
    ]
    try await store.append(TraceRecord(
        id: "rec-2",
        at: base.addingTimeInterval(1),
        ingestOrder: 0,
        run: runID,
        step: "root/risk",
        skillName: "TraceVerifyFlow",
        skillVersionHash: "v1",
        tag: .judged,
        subject: "risk-check",
        payload: riskPayload,
        payloadHash: try CanonicalJSON.sha256Hex(for: riskPayload),
        outcome: .success,
        operationalDetail: nil,
        kind: .planEnd
    ))

    let completePayload: [String: Value] = [
        "duration_ms": .number(Decimal(12))
    ]
    try await store.append(TraceRecord(
        id: "rec-3",
        at: base.addingTimeInterval(2),
        ingestOrder: 0,
        run: runID,
        step: "root",
        skillName: "TraceVerifyFlow",
        skillVersionHash: "v1",
        tag: .completed,
        subject: "workflow",
        payload: completePayload,
        payloadHash: try CanonicalJSON.sha256Hex(for: completePayload),
        outcome: .success,
        operationalDetail: nil,
        kind: .workflowCompleted
    ))

    return TraceVerifyFixture(dir: t, fileURL: fileURL, runID: runID)
}

private func tamperTracePayload(in fileURL: URL, targetLine: Int) throws {
    var lines = try String(contentsOf: fileURL, encoding: .utf8)
        .split(separator: "\n", omittingEmptySubsequences: false)
        .map(String.init)
    guard targetLine >= 1, targetLine <= lines.count else { return }

    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    encoder.outputFormatting = [.sortedKeys]

    var envelope = try decoder.decode(TestTraceLineEnvelope.self, from: Data(lines[targetLine - 1].utf8))
    var payload = envelope.record.payload ?? [:]
    payload["tampered"] = .boolean(true)
    envelope.record = TraceRecord(
        schemaVersion: envelope.record.schemaVersion,
        id: envelope.record.id,
        at: envelope.record.at,
        ingestOrder: envelope.record.ingestOrder,
        run: envelope.record.run,
        step: envelope.record.step,
        skillName: envelope.record.skillName,
        skillVersionHash: envelope.record.skillVersionHash,
        tag: envelope.record.tag,
        subject: envelope.record.subject,
        subjectKey: envelope.record.subjectKey,
        payload: payload,
        payloadHash: envelope.record.payloadHash,
        outcome: envelope.record.outcome,
        operationalDetail: envelope.record.operationalDetail,
        kind: envelope.record.kind,
        sourceRange: envelope.record.sourceRange,
        parentRunID: envelope.record.parentRunID,
        parentSequence: envelope.record.parentSequence
    )
    let tampered = try encoder.encode(envelope)
    lines[targetLine - 1] = String(decoding: tampered, as: UTF8.self)
    try (lines.joined(separator: "\n") + "\n").write(to: fileURL, atomically: true, encoding: .utf8)
}
