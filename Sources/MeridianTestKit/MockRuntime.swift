import Foundation
import MeridianRuntime

public struct MockRuntime: Sendable {
    public let registry: ToolRegistry
    public let observer: InMemoryObserver
    public let checkpointer: InMemoryCheckpointer
    public let clock: FixedClock
    public let runtime: Runtime

    public init(runID: String = "mock-run", clockStart: Date = Date(timeIntervalSince1970: 0)) async {
        let registry = ToolRegistry()
        let observer = InMemoryObserver()
        let checkpointer = InMemoryCheckpointer()
        let clock = FixedClock(now: clockStart)
        self.registry = registry
        self.observer = observer
        self.checkpointer = checkpointer
        self.clock = clock
        self.runtime = Runtime(
            toolRegistry: registry,
            observer: observer,
            checkpointer: checkpointer,
            clock: clock,
            runID: runID
        )
    }

    public func stub(tool: String, return value: Value) async {
        await registry.register(tool: tool, .closure { _ in value })
    }
}
