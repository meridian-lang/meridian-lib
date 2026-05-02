import Foundation
import MeridianRuntime

// MARK: - WorkflowTestHarness
//
// A thin wrapper that bundles the four runtime moving parts a workflow
// test needs: ToolRegistry, InstanceRegistry, InMemoryObserver, and a
// Runtime. The ergonomic shape is a single `await harness.run { rt in
// try await ProcessOrder(order: …).run(runtime: rt) }` call that returns
// a typed `RunResult` covering events, success/failure, and timing.
//
// The harness also exposes:
//   - `stub(tool:_:)` — register a closure tool with one line.
//   - `stub(tool:return:)` — even shorter, for fixed-value stubs.
//   - `events()` — captured `Event` array.
//   - `assertEvents { $0 .startsWith(...) }` — DSL-like assertions.
//
// Lifecycle: each `WorkflowTestHarness` is single-shot. Re-create one per
// test to avoid bleeding events / tool registrations across tests.

public actor WorkflowTestHarness {

    /// Tools, observer, and clock are all internally synchronised
    /// (actor / lock / actor respectively), so callers may touch them
    /// directly without going through the harness actor.
    public nonisolated let toolRegistry: ToolRegistry
    public nonisolated let instanceRegistry: InstanceRegistry
    public nonisolated let observer: InMemoryObserver
    public nonisolated let clock: FixedClock

    private let runtime: Runtime

    // MARK: - Init

    public init(
        instances: InstanceRegistry = .empty,
        clockStart: Date = Date(timeIntervalSince1970: 0),
        runID: String = "test-run"
    ) async {
        let registry = ToolRegistry()
        let observer = InMemoryObserver()
        let clock = FixedClock(now: clockStart)
        self.toolRegistry = registry
        self.instanceRegistry = instances
        self.observer = observer
        self.clock = clock
        self.runtime = Runtime(
            toolRegistry: registry,
            instanceRegistry: instances,
            observer: observer,
            clock: clock,
            runID: runID
        )
    }

    // MARK: - Tool stubbing

    /// Register a closure tool. Existing registrations are overwritten.
    public func stub(
        tool: String,
        _ handler: @escaping @Sendable ([String: Value]) async throws -> Value
    ) async {
        await toolRegistry.register(tool: tool, .closure(handler))
    }

    /// Register a fixed-value tool. Argument-independent.
    public func stub(tool: String, return value: Value) async {
        await stub(tool: tool) { _ in value }
    }

    /// Drop in the `MeridianTools.registerBuiltins(...)` defaults so a test
    /// only has to override the few tools whose answers it cares about.
    /// Re-export needs `MeridianTools` to be linked by the calling target;
    /// we don't import it here to keep `MeridianTestKit` dependency-free.
    /// Tests link MeridianTools directly when they want this.

    // MARK: - Running

    /// Captured outcome of a workflow run.
    public struct RunResult: Sendable {
        public let result: Value
        public let events: [Event]
        public let durationMS: Decimal?
        /// `true` when the captured event stream ends with a workflow.completed.
        public let succeeded: Bool

        public init(result: Value, events: [Event], durationMS: Decimal?, succeeded: Bool) {
            self.result = result
            self.events = events
            self.durationMS = durationMS
            self.succeeded = succeeded
        }
    }

    /// Run a workflow body that takes the harness's `Runtime` and returns
    /// any `Value`. The `body` is the ideal hook for compiler-generated
    /// workflows whose entry-point is `try await Workflow(...).run(runtime:)`.
    public func run(
        _ body: (Runtime) async throws -> Value
    ) async throws -> RunResult {
        let result: Value
        do {
            result = try await body(runtime)
        } catch {
            // Surface failure events too — callers may want to inspect them.
            let events = await observer.events
            return RunResult(
                result: .null,
                events: events,
                durationMS: durationFromEvents(events),
                succeeded: false
            )
        }
        let events = await observer.events
        let succeeded = events.last?.kind == .workflowCompleted
        return RunResult(
            result: result,
            events: events,
            durationMS: durationFromEvents(events),
            succeeded: succeeded
        )
    }

    // MARK: - Event accessors

    /// Snapshot of all captured events.
    public func events() async -> [Event] {
        await observer.events
    }

    /// Convenience: list of `EventKind` values in order.
    public func eventKinds() async -> [EventKind] {
        await observer.events.map(\.kind)
    }

    /// Convenience: lookup the first event with a given kind, or nil.
    public func firstEvent(kind: EventKind) async -> Event? {
        await observer.events.first(where: { $0.kind == kind })
    }

    // MARK: - Helpers

    private func durationFromEvents(_ events: [Event]) -> Decimal? {
        guard let last = events.last(where: { $0.kind == .workflowCompleted }) else {
            return nil
        }
        if case .number(let n) = last.payload["duration_ms"] {
            return n
        }
        return nil
    }
}

// MARK: - FixedClock

/// A deterministic `Clock` that always reports the same instant. Tests that
/// need a tick-by-tick timeline can advance the clock between actions via
/// `advance(by:)`.
public final class FixedClock: @unchecked Sendable, Clock {
    private let lock = NSLock()
    private var current: Date

    public init(now: Date = Date(timeIntervalSince1970: 0)) {
        self.current = now
    }

    public func now() -> Date {
        lock.lock(); defer { lock.unlock() }
        return current
    }

    /// Tests don't want their suite to actually sleep when a workflow
    /// hits a `wait`, so we advance the deterministic clock instead.
    public func sleep(for duration: Duration) async throws {
        let nanos = (duration.components.seconds * 1_000_000_000)
            + Int64(duration.components.attoseconds / 1_000_000_000)
        let secs = TimeInterval(nanos) / 1_000_000_000
        advance(by: secs)
    }

    public func advance(by interval: TimeInterval) {
        lock.lock(); defer { lock.unlock() }
        current = current.addingTimeInterval(interval)
    }
}
