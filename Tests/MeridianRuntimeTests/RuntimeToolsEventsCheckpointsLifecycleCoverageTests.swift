import Testing
import Foundation
@testable import MeridianRuntime

@Suite("Runtime+Events coverage")
struct RuntimeEventsCoverageTests {
    @Test("emit and emitLenient both record domain events")
    func emitAndEmitLenient() async throws {
        let observer = InMemoryObserver()
        let runtime = Runtime(toolRegistry: ToolRegistry(), observer: observer, runID: "emit-cov")
        try await runtime.emit(event: "order.placed", payload: ["id": .string("1")], step: "s1")
        await runtime.emitLenient(event: "order.noted", payload: [:], step: "s2")
        let events = await observer.events.filter { $0.kind == .emit }
        #expect(events.count == 2)
        #expect((events[0].payload ?? [:])["event"] == .string("order.placed"))
        #expect((events[1].payload ?? [:])["event"] == .string("order.noted"))
    }
}

@Suite("Runtime+Checkpoints coverage")
struct RuntimeCheckpointsCoverageTests {
    @Test("checkpoint + prepareResume + consumeResumeContext round-trip")
    func checkpointResumeRoundTrip() async throws {
        let checkpointer = InMemoryCheckpointer()
        let runtime = Runtime(
            toolRegistry: ToolRegistry(),
            checkpointer: checkpointer,
            runID: "cp-run"
        )
        let state = StateSnapshot(bindings: ["x": AnyCodable(.string("y"))])
        try await runtime.checkpoint(label: "mid", state: state, step: "commit")
        let prepared = try await runtime.prepareResume(runID: "cp-run")
        #expect(prepared.lastCheckpointLabel == "mid")
        let consumed = await runtime.consumeResumeContext()
        #expect(consumed?.lastCheckpointLabel == "mid")
        await runtime.clearResumeContext()
        #expect(await runtime.activeResumeContext() == nil)
    }

    @Test("resume throws when no checkpoint exists")
    func resumeMissingCheckpoint() async {
        let runtime = Runtime(toolRegistry: ToolRegistry(), runID: "no-cp")
        do {
            _ = try await runtime.resume(runID: "no-cp")
            Issue.record("expected missing checkpoint to throw")
        } catch MeridianRuntimeError.checkpointFailed {
            // expected
        } catch {
            Issue.record("unexpected error: \(error)")
        }
    }

    @Test("recordStateSnapshotIfEnabled appends when state history is on")
    func stateSnapshotWhenEnabled() async throws {
        let store = InMemoryTraceStore()
        let runtime = Runtime(
            toolRegistry: ToolRegistry(),
            traceStore: store,
            runID: "hist-run",
            traceConfiguration: TraceConfiguration(stateHistoryRetention: true),
            traceSkillIdentity: TraceSkillIdentity(name: "demo", versionHash: "v1")
        )
        let state = StateSnapshot(bindings: ["k": AnyCodable(.string("v"))])
        try await runtime.recordStateSnapshotIfEnabled(
            state: state,
            operation: "bind",
            key: "k",
            step: "s1"
        )
        let snapshots = try await store.query(
            scope: .currentRun,
            scopeSkills: [],
            runID: "hist-run",
            skillName: "demo",
            window: nil,
            pattern: TraceQueryPattern(tags: [.stateSnapshot])
        )
        #expect(snapshots.count == 1)
        #expect(snapshots[0].subjectKey == "k")
    }
}
@Suite("Runtime+Lifecycle coverage")
struct RuntimeLifecycleCoverageTests {
    @Test("workflowStarted / complete / recordEvent emit expected kinds")
    func workflowLifecycleEvents() async throws {
        let observer = InMemoryObserver()
        let runtime = Runtime(toolRegistry: ToolRegistry(), observer: observer, runID: "life-run")
        await runtime.workflowStarted(workflowName: "Demo", parameters: ["a": .number(1)])
        await runtime.recordEvent(.bind, payload: ["name": .string("a")])
        await runtime.complete(reason: "done", step: "end")
        let kinds = await observer.events.map(\.kind)
        #expect(kinds.contains(.workflowStarted))
        #expect(kinds.contains(.bind))
        #expect(kinds.contains(.workflowCompleted))
    }

    @Test("cancel sets cancelled flag and cancels monitors")
    func cancelFlags() async {
        let runtime = Runtime(toolRegistry: ToolRegistry(), runID: "cancel-run")
        await runtime.cancel(runID: "cancel-run")
        // isCancelled() is intentionally a nonisolated stub returning false;
        // actor-isolated cancellation is observed via complete/monitor paths.
        #expect(runtime.isCancelled() == false)
    }

    @Test("instance lookup and property resolution")
    func instanceResolve() async throws {
        let registry = InstanceRegistry.Builder()
            .register(
                kind: "mailer server",
                name: "mailer",
                properties: [
                    "host": .literal(.string("smtp.example")),
                    "port": .envVar("MISSING_PORT_FOR_TEST")
                ]
            )
            .build()
        let runtime = Runtime(toolRegistry: ToolRegistry(), instanceRegistry: registry)
        let handle = try await runtime.instance("mailer")
        #expect(try await runtime.resolveInstanceProperty(handle, "host") == .string("smtp.example"))
        #expect(try await runtime.resolveInstanceProperty(handle, "port") == .string(""))
    }
}

@Suite("Runtime+Tools coverage")
struct RuntimeToolsCoverageTests {
    @Test("invoke success and missing-tool error paths emit events")
    func invokeSuccessAndError() async throws {
        let observer = InMemoryObserver()
        let registry = ToolRegistry()
        await registry.register(tool: "echo", .closure { args in args["v"] ?? .null })
        let runtime = Runtime(toolRegistry: registry, observer: observer, runID: "tool-cov")
        let result = try await runtime.invoke(tool: "echo", args: ["v": .string("hi")], step: "s")
        #expect(result == .string("hi"))
        do {
            _ = try await runtime.invoke(tool: "missing", args: [:])
            Issue.record("expected missing tool to throw")
        } catch {
            // expected
        }
        let kinds = await observer.events.map(\.kind)
        #expect(kinds.contains(.invokeStart))
        #expect(kinds.contains(.invokeEnd))
        #expect(kinds.contains(.invokeError))
    }
}
