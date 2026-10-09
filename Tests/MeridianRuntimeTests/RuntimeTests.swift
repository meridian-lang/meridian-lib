import Testing
import Foundation
@testable import MeridianRuntime

@Suite("Runtime invoke/emit/complete")
struct RuntimeTests {

    private func makeRuntime(observer: any Observer = InMemoryObserver()) async -> Runtime {
        let registry = ToolRegistry()
        await registry.register(tool: "echo", .closure { args in
            return args["value"] ?? .null
        })
        await registry.register(tool: "fail", .closure { _ in
            throw ToolError.implementation(code: "err", message: "boom", cause: nil)
        })
        return Runtime(
            toolRegistry: registry,
            observer: observer,
            runID: "r-test"
        )
    }

    @Test("invoke returns tool result")
    func invokeReturnsResult() async throws {
        let runtime = await makeRuntime()
        let result = try await runtime.invoke(tool: "echo", args: ["value": .string("hi")])
        #expect(result == .string("hi"))
    }

    @Test("invoke emits invokeStart and invokeEnd events")
    func invokeEmitsEvents() async throws {
        let observer = InMemoryObserver()
        let runtime = await makeRuntime(observer: observer)
        _ = try await runtime.invoke(tool: "echo", args: ["value": .null])
        let events = await observer.events
        let kinds = events.map(\.kind)
        #expect(kinds.contains(.invokeStart))
        #expect(kinds.contains(.invokeEnd))
    }

    @Test("invoke failure emits invokeError event")
    func invokeEmitsErrorEvent() async throws {
        let observer = InMemoryObserver()
        let runtime = await makeRuntime(observer: observer)
        _ = try? await runtime.invoke(tool: "fail", args: [:])
        let events = await observer.events
        let kinds = events.map(\.kind)
        #expect(kinds.contains(.invokeError))
    }

    @Test("emit records domain event")
    func emitDomainEvent() async throws {
        let observer = InMemoryObserver()
        let runtime = await makeRuntime(observer: observer)
        try await runtime.emit(event: "order.approved", payload: ["order_id": .string("o-1")])
        let events = await observer.events
        let emitEvent = events.first { $0.kind == .emit }
        #expect(emitEvent != nil)
    }

    @Test("emitLenient does not throw on observer failure")
    func emitLenientDoesNotThrow() async throws {
        let runtime = await makeRuntime()
        await runtime.emitLenient(event: "analytics.test", payload: [:])
    }

    @Test("complete emits workflow.completed event")
    func completeEmitsEvent() async throws {
        let observer = InMemoryObserver()
        let runtime = await makeRuntime(observer: observer)
        await runtime.complete(reason: "test_reason")
        let events = await observer.events
        let completedEvent = events.first { $0.kind == .workflowCompleted }
        #expect(completedEvent != nil)
        if case .string(let r) = (completedEvent?.payload ?? [:])["reason"] {
            #expect(r == "test_reason")
        }
    }

    @Test("complete with nil reason encodes as null")
    func completeNilReason() async throws {
        let observer = InMemoryObserver()
        let runtime = await makeRuntime(observer: observer)
        await runtime.complete(reason: nil)
        let events = await observer.events
        let completedEvent = events.first { $0.kind == .workflowCompleted }
        #expect((completedEvent?.payload ?? [:])["reason"] == .null)
    }

    @Test("eventCount increments with each event")
    func eventCount() async throws {
        let runtime = await makeRuntime()
        let before = await runtime.eventCount()
        _ = try await runtime.invoke(tool: "echo", args: ["value": .null])
        let after = await runtime.eventCount()
        // invoke emits invokeStart + invokeEnd = 2 events
        #expect(after == before + 2)
    }

    @Test("instanceNotFound throws on unknown instance")
    func instanceNotFound() async throws {
        let runtime = await makeRuntime()
        await #expect(throws: MeridianRuntimeError.self) {
            _ = try await runtime.instance("nonexistent")
        }
    }

    @Test("instance resolves registered instance")
    func instanceResolved() async throws {
        let registry = ToolRegistry()
        let instances = InstanceRegistry.Builder()
            .register(kind: "mailer_server", name: "primary_mailer", properties: [
                "host": .literal(.string("smtp.example.com"))
            ])
            .build()
        let runtime = Runtime(toolRegistry: registry, instanceRegistry: instances)
        let handle = try await runtime.instance("primary_mailer")
        #expect(handle.name == "primary_mailer")
        #expect(handle.kind == "mailer_server")
    }

    @Test("resolveInstanceProperty returns literal value")
    func resolveInstancePropertyLiteral() async throws {
        let registry = ToolRegistry()
        let instances = InstanceRegistry.Builder()
            .register(kind: "server", name: "s1", properties: [
                "host": .literal(.string("localhost"))
            ])
            .build()
        let runtime = Runtime(toolRegistry: registry, instanceRegistry: instances)
        let handle = try await runtime.instance("s1")
        let value = try await runtime.resolveInstanceProperty(handle, "host")
        #expect(value == .string("localhost"))
    }

    @Test("resolveInstanceProperty resolves an env-var-backed property from the process environment")
    func resolveInstancePropertyEnvVar() async throws {
        setenv("MERIDIAN_RUNTIME_TESTS_API_KEY", "sk-test-123", 1)
        defer { unsetenv("MERIDIAN_RUNTIME_TESTS_API_KEY") }
        let registry = ToolRegistry()
        let instances = InstanceRegistry.Builder()
            .register(kind: "server", name: "s1", properties: [
                "apiKey": .envVar("MERIDIAN_RUNTIME_TESTS_API_KEY")
            ])
            .build()
        let runtime = Runtime(toolRegistry: registry, instanceRegistry: instances)
        let handle = try await runtime.instance("s1")
        let value = try await runtime.resolveInstanceProperty(handle, "apiKey")
        #expect(value == .string("sk-test-123"))
    }

    @Test("resolveInstanceProperty resolves an unset env var as an empty string")
    func resolveInstancePropertyUnsetEnvVar() async throws {
        let registry = ToolRegistry()
        let instances = InstanceRegistry.Builder()
            .register(kind: "server", name: "s1", properties: [
                "apiKey": .envVar("MERIDIAN_RUNTIME_TESTS_DEFINITELY_UNSET")
            ])
            .build()
        let runtime = Runtime(toolRegistry: registry, instanceRegistry: instances)
        let handle = try await runtime.instance("s1")
        let value = try await runtime.resolveInstanceProperty(handle, "apiKey")
        #expect(value == .string(""))
    }

    @Test("resolveInstanceProperty throws instanceNotFound for an unknown property")
    func resolveInstancePropertyUnknownProperty() async throws {
        let registry = ToolRegistry()
        let instances = InstanceRegistry.Builder()
            .register(kind: "server", name: "s1", properties: [
                "host": .literal(.string("localhost"))
            ])
            .build()
        let runtime = Runtime(toolRegistry: registry, instanceRegistry: instances)
        let handle = try await runtime.instance("s1")
        await #expect(throws: MeridianRuntimeError.self) {
            _ = try await runtime.resolveInstanceProperty(handle, "missing")
        }
    }

    // MARK: - Cancellation / resume context clearing

    @Test("clearResumeContext discards any active resume context")
    func clearResumeContextDiscards() async throws {
        let cp = InMemoryCheckpointer()
        let snapshot = StateSnapshot(bindings: ["v": AnyCodable(.string("restored"))])
        try await cp.write(Checkpoint(
            runID: "r-clear", sequence: 1, timestamp: Date(),
            label: "after_commit", stateSnapshot: snapshot, sourceRange: nil
        ))
        let runtime = Runtime(toolRegistry: ToolRegistry(), checkpointer: cp, runID: "r-clear")
        _ = try await runtime.prepareResume(runID: "r-clear")
        #expect(await runtime.activeResumeContext() != nil)
        await runtime.clearResumeContext()
        #expect(await runtime.activeResumeContext() == nil)
    }

    @Test("cancel(runID:) does not throw and isCancelled remains a stable nonisolated read")
    func cancelAndIsCancelled() async throws {
        let runtime = await makeRuntime()
        await runtime.cancel(runID: "r-test")
        #expect(runtime.isCancelled() == false)
    }

    // MARK: - Assert

    @Test("assert(true) emits assertPassed")
    func assertPassedEmits() async throws {
        let observer = InMemoryObserver()
        let runtime = await makeRuntime(observer: observer)
        try await runtime.assert(true, message: "x is non-nil")
        let events = await observer.events
        #expect(events.contains { $0.kind == .assertPassed })
    }

    @Test("assert(false) emits assertFailed and throws")
    func assertFailedEmitsAndThrows() async throws {
        let observer = InMemoryObserver()
        let runtime = await makeRuntime(observer: observer)
        await #expect(throws: MeridianRuntimeError.self) {
            try await runtime.assert(false, message: "x is non-nil")
        }
        let events = await observer.events
        let failed = events.first { $0.kind == .assertFailed }
        #expect(failed != nil)
        #expect((failed?.payload ?? [:])["message"] == .string("x is non-nil"))
    }

    // MARK: - Primitive-boundary instrumentation (8B/E)

    @Test("recordBranchTaken emits branchTaken with condition/into/step payload")
    func recordBranchTakenEmits() async throws {
        let observer = InMemoryObserver()
        let runtime = await makeRuntime(observer: observer)
        try await runtime.recordBranchTaken(condition: "x > 0", into: "then", step: "branch.step")
        let events = await observer.events
        let event = events.first { $0.kind == .branchTaken }
        #expect(event != nil)
        #expect((event?.payload ?? [:])["condition"] == .string("x > 0"))
        #expect((event?.payload ?? [:])["into"] == .string("then"))
        #expect((event?.payload ?? [:])["step"] == .string("branch.step"))
    }

    @Test("recordBranchEnded emits branchEnded with into/step payload")
    func recordBranchEndedEmits() async throws {
        let observer = InMemoryObserver()
        let runtime = await makeRuntime(observer: observer)
        try await runtime.recordBranchEnded(into: "then", step: "branch.step")
        let events = await observer.events
        let event = events.first { $0.kind == .branchEnded }
        #expect(event != nil)
        #expect((event?.payload ?? [:])["into"] == .string("then"))
        #expect((event?.payload ?? [:])["step"] == .string("branch.step"))
    }

    @Test("recordIterateStart/Iteration/End emit the paired iterate events")
    func recordIterateEmitsPairedEvents() async throws {
        let observer = InMemoryObserver()
        let runtime = await makeRuntime(observer: observer)
        try await runtime.recordIterateStart(over: "the items", step: "iterate.step")
        try await runtime.recordIterateIteration(index: 0, step: "iterate.step")
        try await runtime.recordIterateIteration(index: 1, step: "iterate.step")
        try await runtime.recordIterateEnd(over: "the items", count: 2, step: "iterate.step")
        let events = await observer.events
        let kinds = events.map(\.kind)
        #expect(kinds.filter { $0 == .iterateIteration }.count == 2)
        let start = events.first { $0.kind == .iterateStart }
        #expect((start?.payload ?? [:])["over"] == .string("the items"))
        let end = events.first { $0.kind == .iterateEnd }
        #expect((end?.payload ?? [:])["count"] == .number(2))
    }

    @Test("recordRecoverEngaged emits recoverEngaged with the pattern payload")
    func recordRecoverEngagedEmits() async throws {
        let observer = InMemoryObserver()
        let runtime = await makeRuntime(observer: observer)
        try await runtime.recordRecoverEngaged(pattern: "any", step: "recover.step")
        let events = await observer.events
        let event = events.first { $0.kind == .recoverEngaged }
        #expect((event?.payload ?? [:])["pattern"] == .string("any"))
        #expect((event?.payload ?? [:])["step"] == .string("recover.step"))
    }

    // MARK: - Resume

    @Test("resume returns ResumeContext from latest checkpoint")
    func resumeReturnsLatestContext() async throws {
        let cp = InMemoryCheckpointer()
        // Seed two checkpoints; resume should pick the highest-sequence one.
        let snap1 = StateSnapshot(bindings: ["v": AnyCodable(.string("first"))])
        let snap2 = StateSnapshot(bindings: ["v": AnyCodable(.string("second"))])
        try await cp.write(Checkpoint(runID: "r-resume", sequence: 1, timestamp: Date(),
                                       label: "after_validation", stateSnapshot: snap1, sourceRange: nil))
        try await cp.write(Checkpoint(runID: "r-resume", sequence: 2, timestamp: Date(),
                                       label: "after_payment", stateSnapshot: snap2, sourceRange: nil))

        let registry = ToolRegistry()
        let runtime = Runtime(
            toolRegistry: registry,
            checkpointer: cp,
            runID: "r-resume"
        )
        let ctx = try await runtime.resume(runID: "r-resume")
        #expect(ctx.runID == "r-resume")
        #expect(ctx.lastCheckpointLabel == "after_payment")
        #expect(ctx.restoredState.asValues["v"] == .string("second"))
    }

    @Test("resume throws when no checkpoint exists for runID")
    func resumeUnknownRunIDThrows() async throws {
        let cp = InMemoryCheckpointer()
        let runtime = Runtime(
            toolRegistry: ToolRegistry(),
            checkpointer: cp,
            runID: "ghost"
        )
        await #expect(throws: MeridianRuntimeError.self) {
            _ = try await runtime.resume(runID: "ghost")
        }
    }

    @Test("prepareResume stores active context and emits workflow.resumed")
    func prepareResumeStoresActiveContext() async throws {
        let cp = InMemoryCheckpointer()
        let snapshot = StateSnapshot(bindings: ["v": AnyCodable(.string("restored"))])
        try await cp.write(Checkpoint(
            runID: "r-resume-active",
            sequence: 1,
            timestamp: Date(),
            label: "after_commit",
            stateSnapshot: snapshot,
            sourceRange: nil
        ))
        let observer = InMemoryObserver()
        let runtime = Runtime(
            toolRegistry: ToolRegistry(),
            observer: observer,
            checkpointer: cp,
            runID: "r-resume-active"
        )

        let ctx = try await runtime.prepareResume(runID: "r-resume-active")
        let active = await runtime.activeResumeContext()
        #expect(active?.restoredState.asValues["v"] == .string("restored"))
        let consumed = await runtime.consumeResumeContext()
        #expect(consumed?.restoredState.asValues["v"] == .string("restored"))
        #expect(await runtime.activeResumeContext() == nil)
        #expect(ctx.lastCheckpointLabel == "after_commit")

        let events = await observer.events
        #expect(events.contains { $0.kind == .workflowResumed })
    }

    @Test("generated resume guard skips pre-checkpoint invoke and continues after checkpoint")
    func resumeGuardSkipsPreCheckpointInvoke() async throws {
        let checkpointer = InMemoryCheckpointer()
        let registry = ToolRegistry()
        let first = Counter()
        let second = Counter()
        await registry.register(tool: "first", .closure { _ in
            await first.increment()
            return .string("first")
        })
        await registry.register(tool: "second", .closure { _ in
            await second.increment()
            return .string("second")
        })

        let initialRuntime = Runtime(
            toolRegistry: registry,
            observer: InMemoryObserver(),
            checkpointer: checkpointer,
            runID: "resume-guard"
        )
        try await runUntilCrashAfterFirstCheckpoint(runtime: initialRuntime)

        let resumedRuntime = Runtime(
            toolRegistry: registry,
            observer: InMemoryObserver(),
            checkpointer: checkpointer,
            runID: "resume-guard"
        )
        try await resumedRuntime.prepareResume(runID: "resume-guard")
        try await runWithGeneratedResumeGuard(runtime: resumedRuntime)

        #expect(await first.value == 1)
        #expect(await second.value == 1)
    }

    private func runUntilCrashAfterFirstCheckpoint(runtime: Runtime) async throws {
        var state = State()
        let firstResult = try await runtime.invoke(tool: "first", args: [:])
        state.bind("firstResult", firstResult)
        try await runtime.checkpoint(label: "progress:0.0:L1:C1", state: state.snapshot())
    }

    private func runWithGeneratedResumeGuard(runtime: Runtime) async throws {
        var state = State()
        let resumeContext = await runtime.consumeResumeContext()
        if let resumeContext {
            state.restore(from: resumeContext.restoredState)
        }
        var resumeTarget = resumeContext?.lastCheckpointLabel
        func shouldRun(_ label: String) -> Bool {
            guard let target = resumeTarget else { return true }
            if target == label { resumeTarget = nil }
            return false
        }

        if shouldRun("progress:0.0:L1:C1") {
            let firstResult = try await runtime.invoke(tool: "first", args: [:])
            state.bind("firstResult", firstResult)
            try await runtime.checkpoint(label: "progress:0.0:L1:C1", state: state.snapshot())
        }
        if shouldRun("progress:0.1:L2:C1") {
            let secondResult = try await runtime.invoke(tool: "second", args: [:])
            state.bind("secondResult", secondResult)
            try await runtime.checkpoint(label: "progress:0.1:L2:C1", state: state.snapshot())
        }
    }
}

private actor Counter {
    private var count = 0

    var value: Int { count }

    func increment() {
        count += 1
    }
}
