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

    private let toolRegistry: ToolRegistry
    private let instanceRegistry: InstanceRegistry
    private let observer: any Observer
    private let checkpointer: any Checkpointer
    private let maxNestingDepth: Int

    /// Permission registry used by generated bounded-permission gates.
    /// The default `PermissionRegistry.empty` allows all actions.
    /// Hosts inject an actor-aware resolver to enforce identity-scoped caps.
    public nonisolated let permissionRegistry: PermissionRegistry
    private let parentRunID: String?
    private let parentSequence: Int?

    private var sequenceCounter: Int = 0
    private var _eventCount: Int = 0
    private var _startDate: Date
    private var _isCancelled: Bool = false
    private var _nestingDepth: Int = 0
    private var _activeResumeContext: ResumeContext?

    // MARK: - Wait queues

    /// Signal waiters: signal name → FIFO queue of continuations.
    private var _signalWaiters: [String: [CheckedContinuation<Void, any Error>]] = [:]

    /// Choice-gate waiters: FIFO queue of continuations parked on `.choice`.
    private var _choiceWaiters: [CheckedContinuation<Void, any Error>] = []
    /// The most recent selection delivered via `deliverChoice(_:)`. Read by
    /// generated code immediately after a `.choice` wait resumes.
    private var _lastChoiceSelection: String?

    /// Key used to index approval waiters. Subject `Value` identity plus role string.
    private struct ApprovalKey: Hashable, Sendable {
        let subject: Value
        let role: String
    }
    /// Approval waiters: (subject, role) → FIFO queue of continuations.
    private var _approvalWaiters: [ApprovalKey: [CheckedContinuation<Void, any Error>]] = [:]

    /// An entry in the event-waiter queue.
    private struct EventWaiterEntry: @unchecked Sendable {
        let eventID: String
        let predicate: (@Sendable (Event) -> Bool)?
        var continuation: CheckedContinuation<Void, any Error>
    }
    /// Event waiters: checked against every `emit` and every `deliverEvent` call.
    private var _eventWaiters: [EventWaiterEntry] = []

    // MARK: - Init

    public init(
        toolRegistry: ToolRegistry,
        instanceRegistry: InstanceRegistry = .empty,
        observer: any Observer = JSONLObserver.stdout,
        checkpointer: any Checkpointer = InMemoryCheckpointer(),
        clock: any Clock = SystemClock(),
        runID: String = UUID().uuidString,
        parentRunID: String? = nil,
        parentSequence: Int? = nil,
        maxNestingDepth: Int = 32,
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
        self.checkpointer = checkpointer
        self.clock = clock
        self.runID = runID
        self.parentRunID = parentRunID
        self.parentSequence = parentSequence
        self.maxNestingDepth = maxNestingDepth
        self._startDate = clock.now()
        self.permissionRegistry = permissionRegistry
        self.planner = planner
        self.actPlanner = actPlanner
        self.discretion = discretion
        self.llmProvider = llmProvider
        self.planningLimits = planningLimits
        self.planPolicy = planPolicy
    }

    // MARK: - Tool invocation

    /// Invoke a registered tool. Emits invoke.start and invoke.end/invoke.error events.
    public func invoke(
        tool toolID: String,
        args: [String: Value],
        sourceRange: SourceRange? = nil
    ) async throws -> Value {
        let seq = nextSeq()
        let startDate = clock.now()

        var argsPayload: [String: Value] = ["args": .record(args)]
        let hasTool = await toolRegistry.has(tool: toolID)
        if hasTool {
            let policy = await toolRegistry.redactionPolicy(for: toolID)
            argsPayload = redact(payload: argsPayload, policy: policy)
        }

        await emit(event: Event(
            timestamp: startDate,
            runID: runID,
            sequence: seq,
            kind: .invokeStart,
            payload: mergeDicts(["tool": .string(toolID)], argsPayload),
            sourceRange: sourceRange
        ))

        do {
            let result = try await toolRegistry.dispatch(tool: toolID, args: args)
            let endDate = clock.now()
            let durationMS = (endDate.timeIntervalSince(startDate)) * 1000

            await emit(event: Event(
                timestamp: endDate,
                runID: runID,
                sequence: nextSeq(),
                kind: .invokeEnd,
                payload: [
                    "tool": .string(toolID),
                    "duration_ms": .number(Decimal(durationMS)),
                    "output_summary": .string(summaryOf(result))
                ],
                sourceRange: sourceRange
            ))
            return result
        } catch {
            let endDate = clock.now()
            await emit(event: Event(
                timestamp: endDate,
                runID: runID,
                sequence: nextSeq(),
                kind: .invokeError,
                payload: [
                    "tool": .string(toolID),
                    "error": .string(String(describing: error))
                ],
                sourceRange: sourceRange
            ))
            throw error
        }
    }

    // MARK: - Prose planning

    public func executeProsePlan(
        prose: String,
        snapshot: StateSnapshot,
        scopedTools: [String],
        maxActions: Int = 32,
        sourceRange: SourceRange? = nil
    ) async throws -> [String: Value] {
        try await enforcePlanningInputLimits(prose: prose, sourceRange: sourceRange)
        try await enforceSnapshotLimit(snapshot, sourceRange: sourceRange)
        let scope = Set(scopedTools)
        let schemas = await toolRegistry.schemas(scope)
        let actionLimit = min(maxActions, planningLimits.maxActions)
        let context = PlanContext(
            prose: prose,
            snapshot: snapshot,
            tools: schemas,
            maxActions: actionLimit
        )

        await emit(event: Event(
            timestamp: clock.now(),
            runID: runID,
            sequence: nextSeq(),
            kind: .planStart,
            payload: [
                "mode": .string("plan_then_execute"),
                "tool_count": .number(Decimal(schemas.count))
            ],
            sourceRange: sourceRange
        ))

        do {
            let proposal = try await planner.plan(context)
            try await enforceProposalLimits(proposal, sourceRange: sourceRange)
            guard proposal.actions.count <= actionLimit else {
                throw MeridianRuntimeError.planningFailure(
                    .tooManyActions,
                    message: "planner proposed more than \(actionLimit) actions",
                    sourceRange: sourceRange
                )
            }

            let executor = PlanExecutor(toolRegistry: toolRegistry)
            var bindings: [String: Value] = [:]
            for action in proposal.actions {
                let result = try await validateAndInvoke(action, scope: scope, executor: executor, sourceRange: sourceRange)
                if let binding = action.resultBinding {
                    bindings[binding] = result
                }
                try await checkpoint(label: "prose.plan.action.\(action.toolID)", state: snapshot, sourceRange: sourceRange)
            }

            await emit(event: Event(
                timestamp: clock.now(),
                runID: runID,
                sequence: nextSeq(),
                kind: .planEnd,
                payload: ["action_count": .number(Decimal(proposal.actions.count))],
                sourceRange: sourceRange
            ))
            return bindings
        } catch {
            await emit(event: Event(
                timestamp: clock.now(),
                runID: runID,
                sequence: nextSeq(),
                kind: .planError,
                payload: errorPayload(error),
                sourceRange: sourceRange
            ))
            throw error
        }
    }

    public func executeAutonomousLoop(
        prose: String,
        snapshot: StateSnapshot,
        scopedTools: [String],
        maxSteps: Int = 32,
        replanAfterFailures: Int = 3,
        until: (@Sendable (StateSnapshot) -> Bool)? = nil,
        unless: (@Sendable (StateSnapshot) -> Bool)? = nil,
        sourceRange: SourceRange? = nil
    ) async throws -> [String: Value] {
        try await enforcePlanningInputLimits(prose: prose, sourceRange: sourceRange)
        try await enforceSnapshotLimit(snapshot, sourceRange: sourceRange)
        let scope = Set(scopedTools)
        let schemas = await toolRegistry.schemas(scope)
        let executor = PlanExecutor(toolRegistry: toolRegistry)
        var observations: [ObservationTurn] = []
        var bindings: [String: Value] = [:]
        var loopValues = snapshot.asValues
        var consecutiveFailures = 0

        await emit(event: Event(
            timestamp: clock.now(),
            runID: runID,
            sequence: nextSeq(),
            kind: .autonomyStart,
            payload: ["tool_count": .number(Decimal(schemas.count))],
            sourceRange: sourceRange
        ))

        let initialSnapshot = makeSnapshot(from: loopValues)
        if let reason = checkAutonomyPredicates(snapshot: initialSnapshot, until: until, unless: unless) {
            await emitAutonomyEnd(reason: reason, sourceRange: sourceRange)
            return bindings
        }

        for step in 0..<maxSteps {
            let currentSnapshot = makeSnapshot(from: loopValues)
            if let reason = checkAutonomyPredicates(snapshot: currentSnapshot, until: until, unless: unless) {
                await emitAutonomyEnd(reason: reason, sourceRange: sourceRange)
                return bindings
            }
            try await enforceHistoryLimits(observations, sourceRange: sourceRange)
            let context = ActContext(
                prose: prose,
                snapshot: currentSnapshot,
                tools: schemas,
                observations: observations,
                remainingSteps: maxSteps - step
            )
            let proposal = try await actPlanner.act(context)

            switch proposal {
            case .done(let reason):
                await emitAutonomyEnd(reason: reason ?? "done", sourceRange: sourceRange)
                return bindings

            case .action(let action):
                do {
                    let result = try await validateAndInvoke(action, scope: scope, executor: executor, sourceRange: sourceRange)
                    if let binding = action.resultBinding {
                        bindings[binding] = result
                        loopValues[binding] = result
                    }
                    try await checkpoint(label: "autonomy.action.\(action.toolID)", state: makeSnapshot(from: loopValues), sourceRange: sourceRange)
                    observations.append(ObservationTurn(action: action, outcome: .success(result)))
                    consecutiveFailures = 0
                    await emit(event: Event(
                        timestamp: clock.now(),
                        runID: runID,
                        sequence: nextSeq(),
                        kind: .autonomyStep,
                        payload: ["tool": .string(action.toolID), "status": .string("success")],
                        sourceRange: sourceRange
                    ))
                } catch {
                    observations.append(ObservationTurn(action: action, outcome: .failure(String(describing: error))))
                    consecutiveFailures += 1
                    await emit(event: Event(
                        timestamp: clock.now(),
                        runID: runID,
                        sequence: nextSeq(),
                        kind: .autonomyStep,
                        payload: autonomyFailurePayload(toolID: action.toolID, error: error),
                        sourceRange: sourceRange
                    ))

                    if replanAfterFailures > 0, consecutiveFailures >= replanAfterFailures {
                        try await enforceHistoryLimits(observations, sourceRange: sourceRange)
                        let proposal = try await planner.plan(PlanContext(
                            prose: prose,
                            snapshot: makeSnapshot(from: loopValues),
                            tools: schemas,
                            maxActions: max(1, maxSteps - step - 1)
                        ))
                        try await enforceProposalLimits(proposal, sourceRange: sourceRange)
                        guard proposal.actions.count <= max(1, maxSteps - step - 1) else {
                            throw MeridianRuntimeError.planningFailure(
                                .replanTooManyActions,
                                message: "planner proposed more than \(max(1, maxSteps - step - 1)) actions",
                                sourceRange: sourceRange
                            )
                        }
                        for planned in proposal.actions {
                            let result = try await validateAndInvoke(planned, scope: scope, executor: executor, sourceRange: sourceRange)
                            if let binding = planned.resultBinding {
                                bindings[binding] = result
                                loopValues[binding] = result
                            }
                            try await checkpoint(
                                label: "autonomy.replan.action.\(planned.toolID)",
                                state: makeSnapshot(from: loopValues),
                                sourceRange: sourceRange
                            )
                            observations.append(ObservationTurn(action: planned, outcome: .success(result)))
                        }
                        consecutiveFailures = 0
                    }
                }
            }
        }

        throw MeridianRuntimeError.planningFailure(
            .maxStepsExceeded,
            message: "autonomous loop exceeded \(maxSteps) steps",
            sourceRange: sourceRange
        )
    }

    private func enforcePlanningInputLimits(prose: String, sourceRange: SourceRange?) async throws {
        try await enforceLimit(
            bytes: prose.utf8.count, max: planningLimits.maxProseBytes,
            code: .prosePayloadTooLarge, kind: "prose",
            message: "prose payload exceeds \(planningLimits.maxProseBytes) bytes",
            sourceRange: sourceRange
        )
    }

    private func enforceSnapshotLimit(_ snapshot: StateSnapshot, sourceRange: SourceRange?) async throws {
        let bytes = encodedSize(snapshot) ?? describedSize(snapshot.asValues)
        try await enforceLimit(
            bytes: bytes, max: planningLimits.maxSnapshotBytes,
            code: .snapshotPayloadTooLarge, kind: "snapshot",
            message: "state snapshot exceeds \(planningLimits.maxSnapshotBytes) bytes",
            sourceRange: sourceRange
        )
    }

    private func enforceHistoryLimits(_ observations: [ObservationTurn], sourceRange: SourceRange?) async throws {
        let bytes = observations.reduce(0) { total, turn in
            total + describedSize(turn.action) + describedSize(turn.outcome)
        }
        try await enforceLimit(
            bytes: bytes, max: planningLimits.maxHistoryBytes,
            code: .historyPayloadTooLarge, kind: "history",
            message: "autonomy observation history exceeds \(planningLimits.maxHistoryBytes) bytes",
            sourceRange: sourceRange
        )
    }

    private func enforceProposalLimits(_ proposal: PlanProposal, sourceRange: SourceRange?) async throws {
        let bytes = describedSize(proposal.rationale) + proposal.actions.reduce(0) { total, action in
            total + action.toolID.utf8.count
                + describedSize(action.resultBinding)
                + action.arguments.reduce(0) { argTotal, pair in
                    argTotal + pair.key.utf8.count + describedSize(pair.value)
                }
        }
        try await enforceLimit(
            bytes: bytes, max: planningLimits.maxProposalBytes,
            code: .proposalPayloadTooLarge, kind: "proposal",
            message: "planner proposal exceeds \(planningLimits.maxProposalBytes) bytes",
            sourceRange: sourceRange
        )
    }

    private func enforceActionLimits(_ action: ProposedAction, sourceRange: SourceRange?) async throws {
        let bytes = action.arguments.reduce(0) { total, pair in
            total + pair.key.utf8.count + String(describing: pair.value).utf8.count
        }
        try await enforceLimit(
            bytes: bytes, max: planningLimits.maxToolArgumentBytes,
            code: .toolArgumentsPayloadTooLarge, kind: "tool_arguments",
            message: "tool arguments exceed \(planningLimits.maxToolArgumentBytes) bytes",
            sourceRange: sourceRange
        )
    }

    /// Shared guard/reject/throw tail for every byte-budget limit: emit a
    /// `plan.rejected` event and throw the matching `planningFailure` when
    /// `bytes` exceeds `max`. Each caller keeps its own bespoke byte computation.
    private func enforceLimit(bytes: Int, max: Int, code: PlanningFailureCode, kind: String, message: String, sourceRange: SourceRange?) async throws {
        guard bytes <= max else {
            await emitPlanRejection(code: code, kind: kind, maxBytes: max, sourceRange: sourceRange)
            throw MeridianRuntimeError.planningFailure(code, message: message, sourceRange: sourceRange)
        }
    }

    /// The identical pre-invoke gauntlet a planned action runs in all three
    /// planning paths (prose plan, autonomy step, autonomy replan): limit + host
    /// policy + scoped-tool/schema validation, then dispatch. The divergent
    /// binding / checkpoint / loop-state handling stays at the call sites.
    private func validateAndInvoke(_ action: ProposedAction, scope: Set<String>, executor: PlanExecutor, sourceRange: SourceRange?) async throws -> Value {
        try await enforceActionLimits(action, sourceRange: sourceRange)
        try await enforcePlanPolicy(action, sourceRange: sourceRange)
        try await executor.validate(action, scopedTools: scope, sourceRange: sourceRange)
        return try await invoke(tool: action.toolID, args: action.arguments, sourceRange: sourceRange)
    }

    /// The autonomy loop's `unless`/`until` early-exit check (unless before
    /// until), shared by the pre-loop and per-iteration guards. Returns the exact
    /// `emitAutonomyEnd` reason string, or nil to continue.
    private func checkAutonomyPredicates(snapshot: StateSnapshot,
                                         until: (@Sendable (StateSnapshot) -> Bool)?,
                                         unless: (@Sendable (StateSnapshot) -> Bool)?) -> String? {
        if unless?(snapshot) == true { return "unless_condition_met" }
        if until?(snapshot) == true { return "until_condition_met" }
        return nil
    }

    private func makeSnapshot(from values: [String: Value]) -> StateSnapshot {
        StateSnapshot(bindings: values.mapValues(AnyCodable.init))
    }

    private func encodedSize<T: Encodable>(_ value: T) -> Int? {
        (try? JSONEncoder().encode(value))?.count
    }

    private func describedSize(_ value: Any?) -> Int {
        String(describing: value).utf8.count
    }

    private func enforcePlanPolicy(_ action: ProposedAction, sourceRange: SourceRange?) async throws {
        guard await planPolicy.permits(action) else {
            await emitPlanRejection(
                code: .hostPolicyDenied,
                kind: "policy",
                maxBytes: 0,
                sourceRange: sourceRange
            )
            throw MeridianRuntimeError.planningFailure(
                .hostPolicyDenied,
                message: "host policy denied planner action `\(action.toolID)`",
                sourceRange: sourceRange
            )
        }
    }

    private func emitPlanRejection(
        code: PlanningFailureCode,
        kind: String,
        maxBytes: Int,
        sourceRange: SourceRange?
    ) async {
        await emit(event: Event(
            timestamp: clock.now(),
            runID: runID,
            sequence: nextSeq(),
            kind: .planRejected,
            payload: [
                "code": .string(code.rawValue),
                "kind": .string(kind),
                "max_bytes": .number(Decimal(maxBytes))
            ],
            sourceRange: sourceRange
        ))
    }

    private func emitAutonomyEnd(reason: String, sourceRange: SourceRange?) async {
        await emit(event: Event(
            timestamp: clock.now(),
            runID: runID,
            sequence: nextSeq(),
            kind: .autonomyEnd,
            payload: ["reason": .string(reason)],
            sourceRange: sourceRange
        ))
    }

    private func errorPayload(_ error: any Error) -> [String: Value] {
        var payload = ["error": Value.string(String(describing: error))]
        if let code = implementationErrorCode(error) {
            payload["error_code"] = .string(code)
        }
        return payload
    }

    private func autonomyFailurePayload(toolID: String, error: any Error) -> [String: Value] {
        var payload: [String: Value] = [
            "tool": .string(toolID),
            "status": .string("failure")
        ]
        if let code = implementationErrorCode(error) {
            payload["error_code"] = .string(code)
        }
        return payload
    }

    private func implementationErrorCode(_ error: any Error) -> String? {
        if case .toolError(.implementation(let code, _, _), _) = error as? MeridianRuntimeError {
            return code
        }
        if case .implementation(let code, _, _) = error as? ToolError {
            return code
        }
        return nil
    }

    // MARK: - Events

    /// Emit a domain event. Strict mode: throws on observer failure.
    public func emit(
        event eventID: String,
        payload: [String: Value],
        sourceRange: SourceRange? = nil
    ) async throws {
        await emit(event: Event(
            timestamp: clock.now(),
            runID: runID,
            sequence: nextSeq(),
            kind: .emit,
            payload: mergeDicts(["event": .string(eventID)], payload),
            sourceRange: sourceRange
        ))
    }

    /// Emit a domain event in lenient mode — logs failure but does not halt.
    public func emitLenient(
        event eventID: String,
        payload: [String: Value],
        sourceRange: SourceRange? = nil
    ) async {
        await emit(event: Event(
            timestamp: clock.now(),
            runID: runID,
            sequence: nextSeq(),
            kind: .emit,
            payload: mergeDicts(["event": .string(eventID)], payload),
            sourceRange: sourceRange
        ))
    }

    // MARK: - Assert

    /// Pass-through assertion. Emits `assert.passed` when the condition
    /// holds, or `assert.failed` + throws `MeridianRuntimeError.assertion`
    /// when it does not. Generated codegen calls this for every
    /// `assert X.` statement so failures show up in the JSONL stream
    /// (instead of dying silently inside a `guard`).
    public func assert(
        _ condition: Bool,
        message: String,
        sourceRange: SourceRange? = nil
    ) async throws {
        if condition {
            await emit(event: Event(
                timestamp: clock.now(),
                runID: runID,
                sequence: nextSeq(),
                kind: .assertPassed,
                payload: ["message": .string(message)],
                sourceRange: sourceRange
            ))
            return
        }
        await emit(event: Event(
            timestamp: clock.now(),
            runID: runID,
            sequence: nextSeq(),
            kind: .assertFailed,
            payload: ["message": .string(message)],
            sourceRange: sourceRange
        ))
        throw MeridianRuntimeError.assertion(message: message, sourceRange: sourceRange)
    }

    // MARK: - Wait

    /// Suspend execution on a wait condition.
    ///
    /// - `.duration`: suspends for the given duration via `Clock.sleep`.
    /// - `.signal`: blocks until `deliverSignal(_:)` is called with the same name.
    ///   At-most-once delivery; if no workflow is waiting when a signal arrives it
    ///   is dropped (logged at warning level). FIFO when multiple waiters share a name.
    /// - `.approval`: blocks until `deliverApproval(of:by:verdict:)` is called.
    ///   `.approved` resumes normally; `.denied` throws `MeridianRuntimeError.approvalDenied`.
    /// - `.event`: blocks until `deliverEvent(_:)` fires an event whose `id` and
    ///   predicate (if any) both match. The spec notes this is v1-supported for internal
    ///   events; external delivery uses `deliverEvent`.
    ///
    /// Timeout on signal/approval/event is a v2 feature per the language spec;
    /// passing a non-nil `timeout` with those conditions is ignored in v1.
    public func wait(
        _ condition: WaitCondition,
        timeout: Duration? = nil,
        sourceRange: SourceRange? = nil
    ) async throws {
        await emit(event: Event(
            timestamp: clock.now(),
            runID: runID,
            sequence: nextSeq(),
            kind: .waitStart,
            payload: waitStartPayload(condition),
            sourceRange: sourceRange
        ))

        switch condition {
        case .duration(let d):
            if let t = timeout {
                let sleepDur = min(d, t)
                try await clock.sleep(for: sleepDur)
                if sleepDur == t && t < d {
                    throw MeridianRuntimeError.timeout(condition: condition, sourceRange: sourceRange)
                }
            } else {
                try await clock.sleep(for: d)
            }

        case .signal(let name):
            // Register this continuation in the signal queue, then park.
            // The withCheckedThrowingContinuation closure runs synchronously on
            // the actor executor before suspension, so storing into _signalWaiters
            // is safe without additional hops.
            try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, any Error>) in
                _signalWaiters[name, default: []].append(cont)
            }

        case .approval(let subject, let role):
            let key = ApprovalKey(subject: subject, role: role.identifier)
            try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, any Error>) in
                _approvalWaiters[key, default: []].append(cont)
            }

        case .event(let eventID, let matching):
            try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, any Error>) in
                _eventWaiters.append(EventWaiterEntry(eventID: eventID, predicate: matching, continuation: cont))
            }

        case .choice:
            try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, any Error>) in
                _choiceWaiters.append(cont)
            }
        }

        await emit(event: Event(
            timestamp: clock.now(),
            runID: runID,
            sequence: nextSeq(),
            kind: .waitResume,
            payload: [:],
            sourceRange: sourceRange
        ))
    }

    // MARK: - Wait delivery APIs

    /// Deliver a named signal to the first waiting `wait(.signal(name))` call.
    /// FIFO: if multiple workflow tasks are waiting on the same signal, the
    /// earliest caller is woken. If no one is waiting, the signal is dropped.
    public func deliverSignal(_ name: String) async {
        guard var waiters = _signalWaiters[name], !waiters.isEmpty else { return }
        let cont = waiters.removeFirst()
        _signalWaiters[name] = waiters.isEmpty ? nil : waiters
        cont.resume()
    }

    /// Deliver a user's choice to the first waiting `wait(.choice(...))`.
    /// FIFO; records the selection so the resumed workflow can read it via
    /// `consumeChoiceSelection()`. If no one is waiting, the choice is dropped.
    public func deliverChoice(_ selection: String) async {
        _lastChoiceSelection = selection
        guard !_choiceWaiters.isEmpty else { return }
        let cont = _choiceWaiters.removeFirst()
        cont.resume()
    }

    /// Read and clear the most recent choice selection. Generated code calls
    /// this immediately after a `.choice` wait resumes to bind `choice`.
    public func consumeChoiceSelection() -> String {
        let value = _lastChoiceSelection ?? ""
        _lastChoiceSelection = nil
        return value
    }

    /// Deliver an approval verdict to the first waiting `wait(.approval(of:by:))`.
    ///
    /// - `.approved` resumes normally.
    /// - `.denied` resumes with `MeridianRuntimeError.approvalDenied`, which the
    ///   workflow can catch via a `recover from approval.denied:` block.
    public func deliverApproval(
        of subject: Value,
        by role: RoleRef,
        verdict: RuntimeApprovalVerdict,
        notes: String? = nil
    ) async {
        let key = ApprovalKey(subject: subject, role: role.identifier)
        guard var waiters = _approvalWaiters[key], !waiters.isEmpty else { return }
        let cont = waiters.removeFirst()
        _approvalWaiters[key] = waiters.isEmpty ? nil : waiters
        switch verdict {
        case .approved:
            cont.resume()
        case .denied:
            cont.resume(throwing: MeridianRuntimeError.approvalDenied(
                role: role.identifier, sourceRange: nil))
        }
    }

    /// Deliver an external event to any matching `wait(.event(id, matching:))` callers.
    /// Wakes every waiter whose `eventID` and predicate both match; all others remain.
    public func deliverEvent(_ event: Event) async {
        var remaining: [EventWaiterEntry] = []
        for entry in _eventWaiters {
            let idMatches = entry.eventID.isEmpty || event.payload["event"] == .string(entry.eventID)
            let predMatches = entry.predicate.map { $0(event) } ?? true
            if idMatches && predMatches {
                entry.continuation.resume()
            } else {
                remaining.append(entry)
            }
        }
        _eventWaiters = remaining
    }

    // MARK: - Internal wait helpers

    private func waitStartPayload(_ condition: WaitCondition) -> [String: Value] {
        switch condition {
        case .duration(let d):  return ["kind": .string("duration"), "seconds": .number(Decimal(d.components.seconds))]
        case .signal(let n):    return ["kind": .string("signal"), "name": .string(n)]
        case .approval(_, let r): return ["kind": .string("approval"), "role": .string(r.identifier)]
        case .event(let id, _): return ["kind": .string("event"), "event_id": .string(id)]
        case .choice(let prompt, let options):
            return ["kind": .string("choice"), "prompt": .string(prompt),
                    "options": .list(options.map { .string($0) })]
        }
    }

    // MARK: - Checkpoints

    /// Record a checkpoint. Workflow can resume from here after a crash.
    public func checkpoint(
        label: String? = nil,
        state: StateSnapshot,
        sourceRange: SourceRange? = nil
    ) async throws {
        let seq = nextSeq()
        let cp = Checkpoint(
            runID: runID,
            sequence: seq,
            timestamp: clock.now(),
            label: label,
            stateSnapshot: state,
            sourceRange: sourceRange
        )
        try await checkpointer.write(cp)
        await emit(event: Event(
            timestamp: clock.now(),
            runID: runID,
            sequence: seq,
            kind: .commit,
            payload: label.map { ["label": .string($0)] } ?? [:],
            sourceRange: sourceRange
        ))
    }

    /// Resume an existing run from its last checkpoint.
    ///
    /// Looks up the highest-sequence checkpoint for `runID` from the
    /// configured `Checkpointer`. The returned `ResumeContext` carries the
    /// restored snapshot; callers (typically generated workflow code) feed
    /// it into a fresh `State` via `state.restore(from:)` and then
    /// continue execution from the labeled commit point.
    ///
    /// Throws `MeridianRuntimeError.checkpointFailed` when no checkpoint
    /// exists for the given `runID`, so callers can distinguish "no run"
    /// from a bad-input case at the source line.
    public func resume(runID: String) async throws -> ResumeContext {
        guard let checkpoint = try await checkpointer.latest(forRun: runID) else {
            throw MeridianRuntimeError.checkpointFailed(
                "no checkpoint found for runID `\(runID)`",
                sourceRange: nil
            )
        }
        // The runtime's own `runID` is set at construction; we don't mutate
        // it here. The caller decides how to identify the resumed run
        // (typically by passing `runID:` into the `Runtime` initialiser
        // before calling `resume`).
        return ResumeContext(
            runID: runID,
            lastCheckpointLabel: checkpoint.label,
            restoredState: checkpoint.stateSnapshot
        )
    }

    /// Prepare this runtime to execute a workflow from the latest checkpoint.
    ///
    /// The existing `resume(runID:)` method remains a lookup-only API. This method
    /// records the returned context on the actor so generated workflow code can
    /// restore the `State` snapshot at the start of `run()`.
    @discardableResult
    public func prepareResume(runID: String) async throws -> ResumeContext {
        let context = try await resume(runID: runID)
        _activeResumeContext = context
        await emit(event: Event(
            timestamp: clock.now(),
            runID: self.runID,
            sequence: nextSeq(),
            kind: .workflowResumed,
            payload: [
                "resumed_run_id": .string(runID),
                "last_checkpoint_label": context.lastCheckpointLabel.map(Value.string) ?? .null
            ],
            sourceRange: nil
        ))
        return context
    }

    /// Returns the active resume context, if `prepareResume(runID:)` was called.
    /// Generated workflows call this once at startup and restore state from it.
    public func activeResumeContext() async -> ResumeContext? {
        _activeResumeContext
    }

    /// Return and clear the prepared resume context for one generated run().
    public func consumeResumeContext() async -> ResumeContext? {
        let context = _activeResumeContext
        _activeResumeContext = nil
        return context
    }

    public func clearResumeContext() async {
        _activeResumeContext = nil
    }

    // MARK: - Completion

    /// Mark the workflow as gracefully completed. Call immediately before `return`.
    public func complete(reason: String?, sourceRange: SourceRange? = nil) async {
        let payload: [String: Value] = [
            "reason": reason.map { .string($0) } ?? .null,
            "duration_ms": .number(Decimal(elapsedMS())),
            "event_count": .number(Decimal(_eventCount + 1))
        ]
        await emit(event: Event(
            timestamp: clock.now(),
            runID: runID,
            sequence: nextSeq(),
            kind: .workflowCompleted,
            payload: payload,
            sourceRange: sourceRange
        ))
    }

    // MARK: - Cancellation

    public func cancel(runID: String) async {
        _isCancelled = true
    }

    public nonisolated func isCancelled() -> Bool { false }

    // MARK: - Instances

    public func instance(_ name: String) async throws -> InstanceHandle {
        guard let handle = instanceRegistry.handle(for: name) else {
            throw MeridianRuntimeError.instanceNotFound(name: name)
        }
        return handle
    }

    public func resolveInstanceProperty(
        _ instance: InstanceHandle,
        _ property: String
    ) async throws -> Value {
        guard let propValue = instance.properties[property] else {
            throw MeridianRuntimeError.instanceNotFound(name: "\(instance.name).\(property)")
        }
        switch propValue {
        case .literal(let v): return v
        case .envVar(let name):
            let resolved = ProcessInfo.processInfo.environment[name] ?? ""
            return .string(resolved)
        }
    }

    // MARK: - Diagnostics

    public func elapsedMS() -> Double {
        (clock.now().timeIntervalSince(_startDate)) * 1000
    }

    public func eventCount() -> Int { _eventCount }

    // MARK: - Internal helpers

    private func nextSeq() -> Int {
        sequenceCounter += 1
        _eventCount += 1
        return sequenceCounter
    }

    private func emit(event: Event) async {
        await observer.record(event)
        // Wake any event waiters that match this newly emitted event.
        if !_eventWaiters.isEmpty {
            var remaining: [EventWaiterEntry] = []
            for entry in _eventWaiters {
                let idMatches = entry.eventID.isEmpty || event.payload["event"] == .string(entry.eventID)
                let predMatches = entry.predicate.map { $0(event) } ?? true
                if idMatches && predMatches {
                    entry.continuation.resume()
                } else {
                    remaining.append(entry)
                }
            }
            _eventWaiters = remaining
        }
    }

    private func summaryOf(_ value: Value) -> String {
        switch value {
        case .opaque(let box):
            return "<\(String(describing: box))>"
        default:
            return value.description
        }
    }

    private func redact(payload: [String: Value], policy: RedactionPolicy) -> [String: Value] {
        switch policy {
        case .none: return payload
        case .redactAll: return payload.mapValues { _ in .string("<redacted>") }
        case .redactKeys(let keys):
            let keySet = Set(keys)
            return redactRecord(payload, keys: keySet)
        }
    }

    private func redactRecord(_ dict: [String: Value], keys: Set<String>) -> [String: Value] {
        dict.reduce(into: [:]) { acc, pair in
            acc[pair.key] = keys.contains(pair.key)
                ? .string("<redacted>")
                : redactValue(pair.value, keys: keys)
        }
    }

    private func redactValue(_ value: Value, keys: Set<String>) -> Value {
        switch value {
        case .record(let dict):
            return .record(redactRecord(dict, keys: keys))
        case .list(let values):
            return .list(values.map { redactValue($0, keys: keys) })
        default:
            return value
        }
    }

    // MARK: - Workflow lifecycle

    /// Call at the start of run() to emit workflow.started.
    public func workflowStarted(
        workflowName: String,
        parameters: [String: Value],
        sourceRange: SourceRange? = nil
    ) async {
        var payload: [String: Value] = ["workflow": .string(workflowName)]
        for (k, v) in parameters { payload[k] = v }
        let event = Event(
            timestamp: clock.now(),
            runID: runID,
            sequence: nextSeq(),
            kind: .workflowStarted,
            payload: payload,
            sourceRange: sourceRange,
            parentRunID: parentRunID,
            parentSequence: parentSequence
        )
        await emit(event: event)
    }

    /// Emit a structural event (branch.taken, bind, assert.passed, etc.) from generated code.
    public func recordEvent(
        _ kind: EventKind,
        payload: [String: Value],
        sourceRange: SourceRange? = nil
    ) async {
        await emit(event: Event(
            timestamp: clock.now(),
            runID: runID,
            sequence: nextSeq(),
            kind: kind,
            payload: payload,
            sourceRange: sourceRange
        ))
    }
}

// MARK: - Helpers

private func mergeDicts(_ a: [String: Value], _ b: [String: Value]) -> [String: Value] {
    var result = a
    for (k, v) in b { result[k] = v }
    return result
}
