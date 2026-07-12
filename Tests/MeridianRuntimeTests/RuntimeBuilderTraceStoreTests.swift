import Foundation
import Testing
@testable import MeridianRuntime

@Suite("Runtime.Builder TraceStore auto-wiring")
struct RuntimeBuilderTraceStoreTests {

    @Test("setRuntimeTraceConfiguration auto-wires an InMemoryTraceStore")
    func autoWiresMemoryStore() async throws {
        let bare = Runtime(toolRegistry: ToolRegistry(), runID: "no-store")
        let wired = try Runtime.Builder()
            .setObserver(InMemoryObserver())
            .setRunID("builder-auto-memory")
            .setRuntimeTraceConfiguration(RuntimeTraceConfiguration(
                store: .memory,
                trace: TraceConfiguration(sampleFloor: 1, storeFailurePolicy: .failClosed),
                skillIdentity: TraceSkillIdentity(name: "auto", versionHash: "v1")
            ))
            .build()

        let temporal = TraceTemporalQuery(kind: .ever(
            TraceEventPatternQuery(subject: .step("deploy"), outcome: .succeeded)))
        #expect(try await bare.evaluateTrace(temporal, evaluationInstant: Date()) == .indeterminate)
        // Empty wired store evaluates to false (not the nil-store indeterminate).
        #expect(try await wired.evaluateTrace(temporal, evaluationInstant: Date()) == .false)
    }

    @Test("setRuntimeTraceConfiguration auto-wires a JSONLTraceStore for .file")
    func autoWiresFileStore() async throws {
        let runtime = try Runtime.Builder()
            .setRunID("builder-auto-file-\(UUID().uuidString)")
            .setObserver(InMemoryObserver())
            .setRuntimeTraceConfiguration(RuntimeTraceConfiguration(
                store: .file,
                trace: TraceConfiguration(sampleFloor: 1, storeFailurePolicy: .failClosed),
                skillIdentity: TraceSkillIdentity(name: "auto-file", versionHash: "v1")
            ))
            .build()
        let temporal = TraceTemporalQuery(kind: .ever(
            TraceEventPatternQuery(subject: .step("probe"), outcome: .emitted)))
        #expect(try await runtime.evaluateTrace(temporal, evaluationInstant: Date()) == .false)
    }

    @Test("Builder without setRuntimeTraceConfiguration leaves store nil")
    func withoutConfigLeavesStoreNil() async throws {
        let runtime = try Runtime.Builder()
            .setObserver(InMemoryObserver())
            .setRunID("builder-no-config")
            .build()
        let temporal = TraceTemporalQuery(kind: .ever(
            TraceEventPatternQuery(subject: .step("anything"), outcome: .succeeded)))
        #expect(try await runtime.evaluateTrace(temporal, evaluationInstant: Date()) == .indeterminate)
    }

    @Test("explicit setTraceStore wins over auto-wire")
    func explicitStoreWins() async throws {
        let store = InMemoryTraceStore(configuration: TraceConfiguration(sampleFloor: 1))
        let runtime = try Runtime.Builder()
            .setObserver(InMemoryObserver())
            .setRunID("builder-explicit-store")
            .setRuntimeTraceConfiguration(RuntimeTraceConfiguration(
                store: .file,
                skillIdentity: TraceSkillIdentity(name: "deploy", versionHash: "v1")
            ))
            .setTraceStore(store)
            .build()
        try await store.append(TraceRecord(
            id: UUID().uuidString,
            at: Date(timeIntervalSince1970: 1),
            ingestOrder: 1,
            run: "builder-explicit-store",
            step: "deploy",
            skillName: "deploy",
            skillVersionHash: "v1",
            tag: .completed,
            subject: "deploy",
            payload: [:],
            payloadHash: "payload",
            outcome: .success,
            witness: nil,
            previousHash: nil,
            recordHash: nil,
            operationalDetail: nil,
            legacyKind: nil
        ))
        let temporal = TraceTemporalQuery(kind: .ever(
            TraceEventPatternQuery(subject: .step("deploy"), outcome: .succeeded)))
        #expect(try await runtime.evaluateTrace(temporal, evaluationInstant: Date(timeIntervalSince1970: 10)) == .true)
    }
}
