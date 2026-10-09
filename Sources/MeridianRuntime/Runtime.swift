import Foundation

// MARK: - Runtime

/// The central coordinator for compiled workflow execution.
/// All methods that mutate state are async-isolated via the actor model.
/// Multiple workflow runs may share a single Runtime safely.
public actor Runtime {

    // MARK: - Properties

    public nonisolated let runID: String
    public nonisolated let clock: any Clock
    public nonisolated let planner: any Planner
    public nonisolated let actPlanner: any ActPlanner
    public nonisolated let discretion: any Discretion
    public nonisolated let llmProvider: (any LLMProvider)?
    public nonisolated let planningLimits: PlanningResourceLimits
    public nonisolated let planPolicy: any PlanPolicy

    let toolRegistry: ToolRegistry
    let instanceRegistry: InstanceRegistry
    let observer: any Observer
    let traceStore: (any TraceStore)?
    let checkpointer: any Checkpointer
    private let maxNestingDepth: Int
    let traceConfiguration: TraceConfiguration
    let traceIDGenerator: TraceIDGenerator

    /// Permission registry used by generated bounded-permission gates.
    /// The default `PermissionRegistry.empty` allows all actions.
    /// Hosts inject an actor-aware resolver to enforce identity-scoped caps.
    public nonisolated let permissionRegistry: PermissionRegistry
    let parentRunID: String?
    let parentSequence: Int?

    var sequenceCounter: Int = 0
    var _eventCount: Int = 0
    var _startDate: Date
    var _isCancelled: Bool = false
    private var _nestingDepth: Int = 0
    var _activeResumeContext: ResumeContext?
    var _traceSkillIdentity: TraceSkillIdentity
    var _traceStoreFailure: (any Error)?
    var _observerFailure: (any Error)?
    var _degradedTraceMarkerPending = false
    var _lastTraceStoreFailureDescription: String?
    var _operationalDiagnostics: [RuntimeOperationalDiagnostic] = []
    var _activeWorkflowName: String?

    // MARK: - Wait queues

    /// Signal waiters: signal name → FIFO queue of continuations.
    var _signalWaiters: [String: [CheckedContinuation<Void, any Error>]] = [:]

    /// Choice-gate waiters: FIFO queue of continuations parked on `.choice`.
    var _choiceWaiters: [CheckedContinuation<Void, any Error>] = []
    /// The most recent selection delivered via `deliverChoice(_:)`. Read by
    /// generated code immediately after a `.choice` wait resumes.
    var _lastChoiceSelection: String?

    /// Key used to index approval waiters. Subject `Value` identity plus role string.
    struct ApprovalKey: Hashable, Sendable {
        let subject: Value
        let role: String
    }
    /// Approval waiters: (subject, role) → FIFO queue of continuations.
    var _approvalWaiters: [ApprovalKey: [CheckedContinuation<Void, any Error>]] = [:]

    /// An entry in the event-waiter queue.
    struct EventWaiterEntry: @unchecked Sendable {
        let eventID: String
        let predicate: (@Sendable (TraceRecord) -> Bool)?
        var continuation: CheckedContinuation<Void, any Error>
    }
    /// Event waiters: checked against every `emit` and every `deliverEvent` call.
    var _eventWaiters: [EventWaiterEntry] = []

    /// Background statistical monitors registered by monitored assertions.
    var _monitorTasks: [UUID: Task<Void, Never>] = [:]

    // MARK: - Init

    public init(
        toolRegistry: ToolRegistry,
        instanceRegistry: InstanceRegistry = .empty,
        observer: any Observer = JSONLObserver.stdout,
        traceStore: (any TraceStore)? = nil,
        checkpointer: any Checkpointer = InMemoryCheckpointer(),
        clock: any Clock = SystemClock(),
        runID: String = UUID().uuidString,
        parentRunID: String? = nil,
        parentSequence: Int? = nil,
        maxNestingDepth: Int = 32,
        traceConfiguration: TraceConfiguration = .default,
        traceSkillIdentity: TraceSkillIdentity = .unknown,
        traceIDGenerator: TraceIDGenerator = TraceIDGenerator(),
        permissionRegistry: PermissionRegistry = .empty,
        planner: any Planner = NoopPlanner(),
        actPlanner: any ActPlanner = NoopActPlanner(),
        discretion: any Discretion = DefaultDiscretion(),
        llmProvider: (any LLMProvider)? = nil,
        planningLimits: PlanningResourceLimits = .default,
        planPolicy: any PlanPolicy = AllowAllPlanPolicy()
    ) {
        self.toolRegistry = toolRegistry
        self.instanceRegistry = instanceRegistry
        self.observer = observer
        self.traceStore = traceStore
        self.checkpointer = checkpointer
        self.clock = clock
        self.runID = runID
        self.parentRunID = parentRunID
        self.parentSequence = parentSequence
        self.maxNestingDepth = maxNestingDepth
        self._startDate = clock.now()
        self.traceConfiguration = traceConfiguration
        self.traceIDGenerator = traceIDGenerator
        self._traceSkillIdentity = traceSkillIdentity
        self.permissionRegistry = permissionRegistry
        self.planner = planner
        self.actPlanner = actPlanner
        self.discretion = discretion
        self.llmProvider = llmProvider
        self.planningLimits = planningLimits
        self.planPolicy = planPolicy
    }

}

// MARK: - Helpers

func mergeDicts(_ a: [String: Value], _ b: [String: Value]) -> [String: Value] {
    var result = a
    for (k, v) in b { result[k] = v }
    return result
}
