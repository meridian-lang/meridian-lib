import Foundation

public extension Runtime {
    final class Builder {
        private var toolRegistry: ToolRegistry = ToolRegistry()
        private var instanceRegistry: InstanceRegistry = .empty
        private var observer: any Observer = JSONLObserver.stdout
        private var traceStore: (any TraceStore)?
        private var checkpointer: any Checkpointer = InMemoryCheckpointer()
        private var clock: any Clock = SystemClock()
        private var runID: String = UUID().uuidString
        private var maxNestingDepth: Int = 32
        private var traceConfiguration: TraceConfiguration = .default
        private var traceSkillIdentity: TraceSkillIdentity = .unknown
        private var traceStoreKind: TraceStoreKind = .memory
        private var traceStorePath: String?
        /// When true, `build()` instantiates a store from `traceStoreKind` if none was set.
        private var shouldAutoWireTraceStore = false
        private var traceIDGenerator: TraceIDGenerator = TraceIDGenerator()
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
        public func setTraceStore(_ traceStore: (any TraceStore)?) -> Builder {
            self.traceStore = traceStore
            // An explicit non-nil store owns wiring. Explicit `nil` clears the
            // store but leaves auto-wire armed if `setRuntimeTraceConfiguration`
            // was called earlier — callers who want no store after config must
            // not call `setRuntimeTraceConfiguration`.
            if traceStore != nil {
                shouldAutoWireTraceStore = false
            }
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
        public func setTraceConfiguration(_ traceConfiguration: TraceConfiguration) -> Builder {
            self.traceConfiguration = traceConfiguration
            return self
        }

        @discardableResult
        public func setTraceSkillIdentity(_ traceSkillIdentity: TraceSkillIdentity) -> Builder {
            self.traceSkillIdentity = traceSkillIdentity
            return self
        }

        /// Applies compile-time trace identity and marks the builder to auto-create
        /// a matching `TraceStore` on `build()` when none was set via `setTraceStore`.
        @discardableResult
        public func setRuntimeTraceConfiguration(_ runtimeTraceConfiguration: RuntimeTraceConfiguration) -> Builder {
            self.traceStoreKind = runtimeTraceConfiguration.store
            self.traceConfiguration = runtimeTraceConfiguration.trace
            self.traceSkillIdentity = runtimeTraceConfiguration.skillIdentity
            self.traceStorePath = runtimeTraceConfiguration.storePath
            self.shouldAutoWireTraceStore = traceStore == nil
            return self
        }

        @discardableResult
        public func setTraceIDGenerator(_ traceIDGenerator: TraceIDGenerator) -> Builder {
            self.traceIDGenerator = traceIDGenerator
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

        /// Builds a `Runtime`. Throws when auto-wiring a `.file` `JSONLTraceStore` fails.
        public func build() throws -> Runtime {
            Runtime(
                toolRegistry: toolRegistry,
                instanceRegistry: instanceRegistry,
                observer: observer,
                traceStore: try resolveTraceStore(),
                checkpointer: checkpointer,
                clock: clock,
                runID: runID,
                maxNestingDepth: maxNestingDepth,
                traceConfiguration: traceConfiguration,
                traceSkillIdentity: traceSkillIdentity,
                traceIDGenerator: traceIDGenerator,
                permissionRegistry: permissionRegistry,
                planner: planner,
                actPlanner: actPlanner,
                discretion: discretion,
                llmProvider: llmProvider,
                planningLimits: planningLimits,
                planPolicy: planPolicy
            )
        }

        private func resolveTraceStore() throws -> (any TraceStore)? {
            if let traceStore { return traceStore }
            guard shouldAutoWireTraceStore else { return nil }
            switch traceStoreKind {
            case .memory:
                return InMemoryTraceStore(configuration: traceConfiguration)
            case .file:
                let url: URL
                if let storePath = traceStorePath {
                    url = URL(fileURLWithPath: storePath).standardizedFileURL
                } else {
                    url = FileManager.default.temporaryDirectory
                        .appendingPathComponent("meridian-builder-trace-\(runID).jsonl")
                }
                return try JSONLTraceStore(fileURL: url, configuration: traceConfiguration)
            }
        }
    }
}
