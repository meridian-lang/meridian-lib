import Foundation

// Prose planning / autonomy / judgment witnessing — extracted from Runtime
// for Phase 3 readability.

extension Runtime {

    // MARK: - Prose planning

    public func executeProsePlan(
        prose: String,
        snapshot: StateSnapshot,
        scopedTools: [String],
        maxActions: Int = 32,
        outputKind: String = "record",
        step traceStep: String? = nil,
        guidance: String? = nil,
        sourceRange: SourceRange? = nil
    ) async throws -> [String: Value] {
        try await enforcePlanningInputLimits(prose: prose, sourceRange: sourceRange)
        try await enforceSnapshotLimit(snapshot, sourceRange: sourceRange)
        let scope = Set(scopedTools)
        let schemas = await toolRegistry.schemas(scope)
        let scopePayload = scopedToolPayload(scope)
        let actionLimit = min(maxActions, planningLimits.maxActions)
        let context = PlanContext(
            prose: prose,
            snapshot: snapshot,
            tools: schemas,
            maxActions: actionLimit,
            guidance: guidance
        )

        // SEM-4-04: every judgment invocation witnesses an input payload hash,
        // an output payload hash, and its declared output kind, alongside tool
        // scope (already present as `scoped_tools`). The input hash covers
        // exactly what the planner sees — prose, guidance, and the state
        // snapshot — so replaying the same judgment call is detectable.
        let inputHash = judgmentPayloadHash(judgmentInputPayload(prose: prose, guidance: guidance, snapshot: snapshot))

        try await emitOrThrow(event: Event(
            timestamp: clock.now(),
            runID: runID,
            sequence: nextSeq(),
            kind: .planStart,
            payload: [
                "mode": .string("plan_then_execute"),
                "tool_count": .number(Decimal(schemas.count)),
                "scoped_tools": scopePayload,
                "input_payload_hash": inputHash,
                "output_kind": .string(outputKind),
                "step": traceStep.map(Value.string) ?? .null
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
                try await checkpoint(label: "prose.plan.action.\(action.toolID)", state: snapshot, step: traceStep, sourceRange: sourceRange)
            }

            try await emitOrThrow(event: Event(
                timestamp: clock.now(),
                runID: runID,
                sequence: nextSeq(),
                kind: .planEnd,
                payload: [
                    "action_count": .number(Decimal(proposal.actions.count)),
                    "scoped_tools": scopePayload,
                    "input_payload_hash": inputHash,
                    "output_payload_hash": judgmentPayloadHash(bindings),
                    "output_kind": .string(outputKind),
                    "step": traceStep.map(Value.string) ?? .null
                ],
                sourceRange: sourceRange
            ))
            return bindings
        } catch {
            try await emitOrThrow(event: Event(
                timestamp: clock.now(),
                runID: runID,
                sequence: nextSeq(),
                kind: .planError,
                payload: mergeDicts(
                    mergeDicts(errorPayload(error), ["scoped_tools": scopePayload]),
                    traceStep.map { ["step": Value.string($0)] } ?? [:]
                ),
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
        outputKind: String = "record",
        step traceStep: String? = nil,
        until: (@Sendable (StateSnapshot) -> Bool)? = nil,
        unless: (@Sendable (StateSnapshot) -> Bool)? = nil,
        guidance: String? = nil,
        sourceRange: SourceRange? = nil
    ) async throws -> [String: Value] {
        try await enforcePlanningInputLimits(prose: prose, sourceRange: sourceRange)
        try await enforceSnapshotLimit(snapshot, sourceRange: sourceRange)
        let scope = Set(scopedTools)
        let schemas = await toolRegistry.schemas(scope)
        let scopePayload = scopedToolPayload(scope)
        let executor = PlanExecutor(toolRegistry: toolRegistry)
        var observations: [ObservationTurn] = []
        var bindings: [String: Value] = [:]
        var loopValues = snapshot.asValues
        var consecutiveFailures = 0

        // SEM-4-04 — see `executeProsePlan`'s matching comment: same witness
        // shape (input hash / output hash / declared output kind) for the
        // autonomy dispatch path.
        let inputHash = judgmentPayloadHash(judgmentInputPayload(prose: prose, guidance: guidance, snapshot: snapshot))

        try await emitOrThrow(event: Event(
            timestamp: clock.now(),
            runID: runID,
            sequence: nextSeq(),
            kind: .autonomyStart,
            payload: [
                "tool_count": .number(Decimal(schemas.count)),
                "scoped_tools": scopePayload,
                "input_payload_hash": inputHash,
                "output_kind": .string(outputKind),
                "step": traceStep.map(Value.string) ?? .null
            ],
            sourceRange: sourceRange
        ))

        let initialSnapshot = makeSnapshot(from: loopValues)
        if let reason = checkAutonomyPredicates(snapshot: initialSnapshot, until: until, unless: unless) {
            await emitAutonomyEnd(reason: reason, scopedTools: scopePayload, inputHash: inputHash, outputKind: outputKind, bindings: bindings, step: traceStep, sourceRange: sourceRange)
            return bindings
        }

        for step in 0..<maxSteps {
            let currentSnapshot = makeSnapshot(from: loopValues)
            if let reason = checkAutonomyPredicates(snapshot: currentSnapshot, until: until, unless: unless) {
                await emitAutonomyEnd(reason: reason, scopedTools: scopePayload, inputHash: inputHash, outputKind: outputKind, bindings: bindings, step: traceStep, sourceRange: sourceRange)
                return bindings
            }
            try await enforceHistoryLimits(observations, sourceRange: sourceRange)
            let context = ActContext(
                prose: prose,
                snapshot: currentSnapshot,
                tools: schemas,
                observations: observations,
                remainingSteps: maxSteps - step,
                guidance: guidance
            )
            let proposal = try await actPlanner.act(context)

            switch proposal {
            case .done(let reason):
                await emitAutonomyEnd(reason: reason ?? "done", scopedTools: scopePayload, inputHash: inputHash, outputKind: outputKind, bindings: bindings, step: traceStep, sourceRange: sourceRange)
                return bindings

            case .action(let action):
                do {
                    let result = try await validateAndInvoke(action, scope: scope, executor: executor, sourceRange: sourceRange)
                    if let binding = action.resultBinding {
                        bindings[binding] = result
                        loopValues[binding] = result
                    }
                    try await checkpoint(label: "autonomy.action.\(action.toolID)", state: makeSnapshot(from: loopValues), step: traceStep, sourceRange: sourceRange)
                    observations.append(ObservationTurn(action: action, outcome: .success(result)))
                    consecutiveFailures = 0
                    try await emitOrThrow(event: Event(
                        timestamp: clock.now(),
                        runID: runID,
                        sequence: nextSeq(),
                        kind: .autonomyStep,
                        payload: ["tool": .string(action.toolID), "status": .string("success"), "step": traceStep.map(Value.string) ?? .null],
                        sourceRange: sourceRange
                    ))
                } catch {
                    observations.append(ObservationTurn(action: action, outcome: .failure(String(describing: error))))
                    consecutiveFailures += 1
                    try await emitOrThrow(event: Event(
                        timestamp: clock.now(),
                        runID: runID,
                        sequence: nextSeq(),
                        kind: .autonomyStep,
                        payload: mergeDicts(autonomyFailurePayload(toolID: action.toolID, error: error), traceStep.map { ["step": Value.string($0)] } ?? [:]),
                        sourceRange: sourceRange
                    ))

                    if replanAfterFailures > 0, consecutiveFailures >= replanAfterFailures {
                        try await enforceHistoryLimits(observations, sourceRange: sourceRange)
                        let proposal = try await planner.plan(PlanContext(
                            prose: prose,
                            snapshot: makeSnapshot(from: loopValues),
                            tools: schemas,
                            maxActions: max(1, maxSteps - step - 1),
                            guidance: guidance
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

    func enforcePlanningInputLimits(prose: String, sourceRange: SourceRange?) async throws {
        try await enforceLimit(
            bytes: prose.utf8.count, max: planningLimits.maxProseBytes,
            code: .prosePayloadTooLarge, kind: "prose",
            message: "prose payload exceeds \(planningLimits.maxProseBytes) bytes",
            sourceRange: sourceRange
        )
    }

    func enforceSnapshotLimit(_ snapshot: StateSnapshot, sourceRange: SourceRange?) async throws {
        let bytes = encodedSize(snapshot) ?? describedSize(snapshot.asValues)
        try await enforceLimit(
            bytes: bytes, max: planningLimits.maxSnapshotBytes,
            code: .snapshotPayloadTooLarge, kind: "snapshot",
            message: "state snapshot exceeds \(planningLimits.maxSnapshotBytes) bytes",
            sourceRange: sourceRange
        )
    }

    func enforceHistoryLimits(_ observations: [ObservationTurn], sourceRange: SourceRange?) async throws {
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

    func enforceProposalLimits(_ proposal: PlanProposal, sourceRange: SourceRange?) async throws {
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

    func enforceActionLimits(_ action: ProposedAction, sourceRange: SourceRange?) async throws {
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
    func enforceLimit(bytes: Int, max: Int, code: PlanningFailureCode, kind: String, message: String, sourceRange: SourceRange?) async throws {
        guard bytes <= max else {
            try await emitPlanRejection(code: code, kind: kind, maxBytes: max, sourceRange: sourceRange)
            throw MeridianRuntimeError.planningFailure(code, message: message, sourceRange: sourceRange)
        }
    }

    /// The identical pre-invoke gauntlet a planned action runs in all three
    /// planning paths (prose plan, autonomy step, autonomy replan): limit + host
    /// policy + scoped-tool/schema validation, then dispatch. The divergent
    /// binding / checkpoint / loop-state handling stays at the call sites.
    func validateAndInvoke(_ action: ProposedAction, scope: Set<String>, executor: PlanExecutor, sourceRange: SourceRange?) async throws -> Value {
        try await enforceActionLimits(action, sourceRange: sourceRange)
        try await enforcePlanPolicy(action, sourceRange: sourceRange)
        try await executor.validate(
            action, scopedTools: scope, permissionRegistry: permissionRegistry, sourceRange: sourceRange)
        return try await invoke(tool: action.toolID, args: action.arguments, sourceRange: sourceRange)
    }

    /// The autonomy loop's `unless`/`until` early-exit check (unless before
    /// until), shared by the pre-loop and per-iteration guards. Returns the exact
    /// `emitAutonomyEnd` reason string, or nil to continue.
    func checkAutonomyPredicates(snapshot: StateSnapshot,
                                         until: (@Sendable (StateSnapshot) -> Bool)?,
                                         unless: (@Sendable (StateSnapshot) -> Bool)?) -> String? {
        if unless?(snapshot) == true { return "unless_condition_met" }
        if until?(snapshot) == true { return "until_condition_met" }
        return nil
    }

    func makeSnapshot(from values: [String: Value]) -> StateSnapshot {
        StateSnapshot(bindings: values.mapValues(AnyCodable.init))
    }

    func encodedSize<T: Encodable>(_ value: T) -> Int? {
        (try? JSONEncoder().encode(value))?.count
    }

    func describedSize(_ value: Any?) -> Int {
        String(describing: value).utf8.count
    }

    func enforcePlanPolicy(_ action: ProposedAction, sourceRange: SourceRange?) async throws {
        guard await planPolicy.permits(action) else {
            try await emitPlanRejection(
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

    func emitPlanRejection(
        code: PlanningFailureCode,
        kind: String,
        maxBytes: Int,
        sourceRange: SourceRange?
    ) async throws {
        try await emitOrThrow(event: Event(
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

    func emitAutonomyEnd(reason: String, scopedTools: Value, inputHash: Value, outputKind: String, bindings: [String: Value], step: String?, sourceRange: SourceRange?) async {
        await emit(event: Event(
            timestamp: clock.now(),
            runID: runID,
            sequence: nextSeq(),
            kind: .autonomyEnd,
            payload: [
                "reason": .string(reason),
                "scoped_tools": scopedTools,
                "input_payload_hash": inputHash,
                "output_payload_hash": judgmentPayloadHash(bindings),
                "output_kind": .string(outputKind),
                "step": step.map(Value.string) ?? .null
            ],
            sourceRange: sourceRange
        ))
    }

    func scopedToolPayload(_ scope: Set<String>) -> Value {
        .list(scope.sorted().map(Value.string))
    }

    // MARK: - SEM-4-04 judgment witnessing

    /// Exactly what the planner/actor sees for one judgment call: the prose
    /// goal, its optional guidance, and the state snapshot. Hashing this (not
    /// the whole `PlanContext`, which also carries the tool schema list
    /// already witnessed separately as `scoped_tools`) gives a stable input
    /// fingerprint that changes iff the judgment's actual inputs change.
    func judgmentInputPayload(prose: String, guidance: String?, snapshot: StateSnapshot) -> [String: Value] {
        [
            "prose": .string(prose),
            "guidance": guidance.map(Value.string) ?? .null,
            "snapshot": .record(snapshot.asValues)
        ]
    }

    /// `CanonicalJSON.sha256Hex(for:)` only declares `throws` for signature
    /// symmetry with the `TraceRecord` overload; encoding a `[String: Value]`
    /// cannot actually fail. `try?` keeps this witness from ever aborting a
    /// judgment call over a hashing concern.
    func judgmentPayloadHash(_ payload: [String: Value]) -> Value {
        guard let hash = try? CanonicalJSON.sha256Hex(for: payload) else { return .null }
        return .string(hash)
    }

    func errorPayload(_ error: any Error) -> [String: Value] {
        var payload = ["error": Value.string(String(describing: error))]
        if let code = implementationErrorCode(error) {
            payload["error_code"] = .string(code)
        }
        return payload
    }

    func autonomyFailurePayload(toolID: String, error: any Error) -> [String: Value] {
        var payload: [String: Value] = [
            "tool": .string(toolID),
            "status": .string("failure")
        ]
        if let code = implementationErrorCode(error) {
            payload["error_code"] = .string(code)
        }
        return payload
    }

    func implementationErrorCode(_ error: any Error) -> String? {
        if case .toolError(.implementation(let code, _, _), _) = error as? MeridianRuntimeError {
            return code
        }
        if case .implementation(let code, _, _) = error as? ToolError {
            return code
        }
        return nil
    }

}
