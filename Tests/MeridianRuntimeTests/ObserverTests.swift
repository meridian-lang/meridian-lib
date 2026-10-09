import Testing
import Foundation
@testable import MeridianRuntime

private func makeRecord(
    _ kind: EventKind,
    at timestamp: Date = Date(),
    runID: String = "r-1",
    sequence: Int = 1,
    payload: [String: Value] = [:],
    parentRunID: String? = nil,
    parentSequence: Int? = nil
) throws -> TraceRecord {
    try TraceRecord(
        kind: kind,
        at: timestamp,
        run: runID,
        ingestOrder: sequence,
        skillName: "skill",
        skillVersionHash: "h",
        id: "id-\(sequence)",
        payload: payload,
        parentRunID: parentRunID,
        parentSequence: parentSequence
    )
}

@Suite("InMemoryObserver")
struct ObserverTests {

    @Test("records events in order")
    func recordsInOrder() async throws {
        let observer = InMemoryObserver()
        let e1 = try makeRecord(.workflowStarted, sequence: 1)
        let e2 = try makeRecord(.bind, sequence: 2, payload: ["name": .string("x")])
        try await observer.record(e1)
        try await observer.record(e2)
        let events = await observer.events
        #expect(events.count == 2)
        #expect(events[0].kind == .workflowStarted)
        #expect(events[1].kind == .bind)
    }

    @Test("clear empties the store")
    func clearEmpties() async throws {
        let observer = InMemoryObserver()
        try await observer.record(try makeRecord(.bind))
        await observer.clear()
        let events = await observer.events
        #expect(events.isEmpty)
    }

    @Test("CompositeObserver fans out to all observers")
    func compositeObserver() async throws {
        let o1 = InMemoryObserver()
        let o2 = InMemoryObserver()
        let composite = CompositeObserver([o1, o2])
        let e = try makeRecord(.workflowStarted)
        try await composite.record(e)
        let c1 = await o1.events.count
        let c2 = await o2.events.count
        #expect(c1 == 1)
        #expect(c2 == 1)
    }

    @Test("CompositeObserver fails fast on the first throwing observer")
    func compositeFailsFast() async throws {
        let succeeding = InMemoryObserver()
        let failingDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("meridian-observer-fail-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: failingDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: failingDir) }
        let failingFile = failingDir.appendingPathComponent("events.jsonl")
        try Data("not-a-directory".utf8).write(to: failingFile)
        try FileManager.default.setAttributes([.posixPermissions: 0o444], ofItemAtPath: failingDir.path)
        let failing = try JSONLObserver.file(failingDir.appendingPathComponent("blocked.jsonl"))

        let composite = CompositeObserver([succeeding, failing])
        let event = try makeRecord(.bind)

        await #expect(throws: (any Error).self) {
            try await composite.record(event)
        }
        let recorded = await succeeding.events
        #expect(recorded.count == 1)
    }
}

@Suite("JSONLObserver")
struct JSONLObserverTests {

    @Test("formats workflow.started event as valid JSON")
    func formatsWorkflowStarted() async throws {
        let tmpURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("meridian_test_\(UUID().uuidString).jsonl")
        defer { try? FileManager.default.removeItem(at: tmpURL) }

        FileManager.default.createFile(atPath: tmpURL.path, contents: nil)

        let observer = try JSONLObserver.file(tmpURL)
        let event = try makeRecord(
            .workflowStarted,
            at: Date(timeIntervalSince1970: 1_745_913_600),
            runID: "r-test",
            payload: ["workflow": .string("ProcessOrder")]
        )
        try await observer.record(event)

        let content = try String(contentsOf: tmpURL, encoding: .utf8)
        let line = content.trimmingCharacters(in: .whitespacesAndNewlines)
        #expect(!line.isEmpty)

        let data = Data(line.utf8)
        let parsed = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(parsed != nil)
        #expect(parsed?["run_id"] as? String == "r-test")
        #expect(parsed?["seq"] as? Int == 1)
        #expect(parsed?["kind"] as? String == "workflow.started")
    }

    @Test("throws when the file destination is not writable")
    func throwsOnUnwritableDestination() async throws {
        let failingDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("meridian-jsonl-fail-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: failingDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: failingDir) }
        try FileManager.default.setAttributes([.posixPermissions: 0o444], ofItemAtPath: failingDir.path)

        let observer = try JSONLObserver.file(failingDir.appendingPathComponent("events.jsonl"))
        let event = try makeRecord(.bind)

        await #expect(throws: (any Error).self) {
            try await observer.record(event)
        }
    }

    @Test("observer failure aborts strict runtime emits")
    func observerFailureAbortsFailClosedRuntime() async throws {
        let failingDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("meridian-runtime-obs-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: failingDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: failingDir) }
        try FileManager.default.setAttributes([.posixPermissions: 0o444], ofItemAtPath: failingDir.path)

        let observer = try JSONLObserver.file(failingDir.appendingPathComponent("events.jsonl"))
        let runtime = Runtime(
            toolRegistry: ToolRegistry(),
            observer: observer,
            runID: "run-1",
            traceConfiguration: TraceConfiguration(storeFailurePolicy: .failClosed)
        )

        await #expect(throws: MeridianRuntimeError.self) {
            try await runtime.emit(event: "demo.event", payload: [:])
        }
        let diagnostics = await runtime.operationalDiagnostics()
        #expect(diagnostics.contains { $0.code == "observer.record" })
    }
}
