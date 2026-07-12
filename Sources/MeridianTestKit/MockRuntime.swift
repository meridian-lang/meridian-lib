import Foundation
import MeridianRuntime

public struct MockRuntime: Sendable {
    public let registry: ToolRegistry
    public let observer: InMemoryObserver
    public let checkpointer: InMemoryCheckpointer
    public let clock: FixedClock
    public let traceStore: InMemoryTraceStore
    public let runtime: Runtime

    public init(
        runID: String = "mock-run",
        clockStart: Date = Date(timeIntervalSince1970: 0),
        traceConfiguration: TraceConfiguration = .default
    ) async {
        let registry = ToolRegistry()
        let observer = InMemoryObserver()
        let checkpointer = InMemoryCheckpointer()
        let clock = FixedClock(now: clockStart)
        let traceStore = InMemoryTraceStore(configuration: traceConfiguration)
        self.registry = registry
        self.observer = observer
        self.checkpointer = checkpointer
        self.clock = clock
        self.traceStore = traceStore
        self.runtime = Runtime(
            toolRegistry: registry,
            observer: observer,
            traceStore: traceStore,
            checkpointer: checkpointer,
            clock: clock,
            runID: runID,
            traceConfiguration: traceConfiguration
        )
    }

    public func stub(tool: String, return value: Value) async {
        await registry.register(tool: tool, .closure { _ in value })
    }
}
