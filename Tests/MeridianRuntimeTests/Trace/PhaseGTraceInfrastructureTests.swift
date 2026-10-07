import Foundation
import Testing
@testable import MeridianRuntime

@Suite("Phase G trace infrastructure")
struct PhaseGTraceInfrastructureTests {
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

    @Test("recordViolation emits a violated record on the trace store")
    func recordViolationEmitsViolatedRecord() async throws {
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
                normID: "no-shell",
                disposition: "prevented",
                blocking: true
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
    }
}
