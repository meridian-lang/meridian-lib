import Foundation

public extension Runtime {
    final class Builder {
        private var toolRegistry: ToolRegistry = ToolRegistry()
        private var instanceRegistry: InstanceRegistry = .empty
        private var observer: any Observer = JSONLObserver.stdout
        private var checkpointer: any Checkpointer = InMemoryCheckpointer()
        private var clock: any Clock = SystemClock()
        private var runID: String = UUID().uuidString
        private var maxNestingDepth: Int = 32
        private var permissionRegistry: PermissionRegistry = .empty
        private var planner: any Planner = NoopPlanner()
        private var actPlanner: any ActPlanner = NoopActPlanner()
        private var discretion: any Discretion = DefaultDiscretion()
        private var llmProvider: (any LLMProvider)?
        private var planningLimits: PlanningResourceLimits = .default
        private var planPolicy: any PlanPolicy = AllowAllPlanPolicy()

        public init() {}

        @discardableResult
        public func setToolRegistry(_ toolRegistry: ToolRegistry) -> Builder {
            self.toolRegistry = toolRegistry
            return self
        }

        @discardableResult
        public func setInstanceRegistry(_ instanceRegistry: InstanceRegistry) -> Builder {
            self.instanceRegistry = instanceRegistry
            return self
        }

        @discardableResult
        public func setObserver(_ observer: any Observer) -> Builder {
            self.observer = observer
            return self
        }

        @discardableResult
        public func setCheckpointer(_ checkpointer: any Checkpointer) -> Builder {
            self.checkpointer = checkpointer
            return self
        }

        @discardableResult
        public func setClock(_ clock: any Clock) -> Builder {
            self.clock = clock
            return self
        }

        @discardableResult
        public func setRunID(_ runID: String) -> Builder {
            self.runID = runID
            return self
        }

        @discardableResult
        public func setMaxNestingDepth(_ maxNestingDepth: Int) -> Builder {
            self.maxNestingDepth = maxNestingDepth
            return self
        }

        @discardableResult
        public func setPermissionRegistry(_ permissionRegistry: PermissionRegistry) -> Builder {
            self.permissionRegistry = permissionRegistry
            return self
        }

        @discardableResult
        public func setPlanner(_ planner: any Planner) -> Builder {
            self.planner = planner
            return self
        }

        @discardableResult
        public func setActPlanner(_ actPlanner: any ActPlanner) -> Builder {
            self.actPlanner = actPlanner
            return self
        }

        @discardableResult
        public func setDiscretion(_ discretion: any Discretion) -> Builder {
            self.discretion = discretion
            return self
        }

        @discardableResult
        public func setLLMProvider(_ llmProvider: (any LLMProvider)?) -> Builder {
            self.llmProvider = llmProvider
            return self
        }

        @discardableResult
        public func setPlanningLimits(_ planningLimits: PlanningResourceLimits) -> Builder {
            self.planningLimits = planningLimits
            return self
        }

        @discardableResult
        public func setPlanPolicy(_ planPolicy: any PlanPolicy) -> Builder {
            self.planPolicy = planPolicy
            return self
        }

        public func build() -> Runtime {
            Runtime(
                toolRegistry: toolRegistry,
                instanceRegistry: instanceRegistry,
                observer: observer,
                checkpointer: checkpointer,
                clock: clock,
                runID: runID,
                maxNestingDepth: maxNestingDepth,
                permissionRegistry: permissionRegistry,
                planner: planner,
                actPlanner: actPlanner,
                discretion: discretion,
                llmProvider: llmProvider,
                planningLimits: planningLimits,
                planPolicy: planPolicy
            )
        }
    }
}
