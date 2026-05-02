import Foundation
import MeridianRuntime

public struct ClockHarness: Sendable {
    public let clock: FixedClock

    public init(start: Date = Date(timeIntervalSince1970: 0)) {
        self.clock = FixedClock(now: start)
    }

    public func runtime(
        registry: ToolRegistry = ToolRegistry(),
        observer: InMemoryObserver = InMemoryObserver(),
        planner: any Planner = NoopPlanner(),
        actPlanner: any ActPlanner = NoopActPlanner()
    ) -> Runtime {
        Runtime(
            toolRegistry: registry,
            observer: observer,
            clock: clock,
            planner: planner,
            actPlanner: actPlanner
        )
    }
}
