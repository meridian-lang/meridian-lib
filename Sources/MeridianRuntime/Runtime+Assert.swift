import Foundation

// Assert / monitors / branch-iterate-recover instrumentation — extracted
// from Runtime for Phase 3 readability.

extension Runtime {

    // MARK: - Assert

    /// Pass-through assertion. Emits `assert.passed` when the condition
    /// holds, or `assert.failed` + throws `MeridianRuntimeError.assertion`
    /// when it does not. Generated codegen calls this for every
    /// `assert X.` statement so failures show up in the JSONL stream
    /// (instead of dying silently inside a `guard`).
    public func assert(
        _ condition: Bool,
        message: String,
        step: String? = nil,
        sourceRange: SourceRange? = nil
    ) async throws {
        try await assert(TruthValue.from(condition), message: message, step: step, sourceRange: sourceRange)
    }

    public func assert(
        _ condition: TruthValue,
        message: String,
        step: String? = nil,
        sourceRange: SourceRange? = nil
    ) async throws {
        try await recordAssertionOutcome(
            condition,
            message: message,
            step: step,
            sourceRange: sourceRange,
            throwOnFailure: true
        )
    }

    public func registerMonitor(
        query: TraceStatisticalQuery,
        cadence: Duration,
        message: String,
        blocking: Bool = false,
        step: String? = nil,
        sourceRange: SourceRange? = nil
    ) {
        let id = UUID()
        let task = Task { [clock] in
            while !Task.isCancelled {
                do {
                    try await clock.sleep(for: cadence)
                } catch {
                    return
                }
                if Task.isCancelled {
                    return
                }
                await self.runMonitorTick(
                    query: query,
                    message: message,
                    blocking: blocking,
                    step: step,
                    sourceRange: sourceRange
                )
            }
        }
        _monitorTasks[id] = task
    }

    func runMonitorTick(
        query: TraceStatisticalQuery,
        message: String,
        blocking: Bool,
        step: String?,
        sourceRange: SourceRange?
    ) async {
        let outcome: TruthValue
        do {
            outcome = try await evaluateTrace(query, evaluationInstant: currentDate())
        } catch {
            if error is CancellationError { return }
            recordOperationalDiagnostic(code: "monitor.evaluate", message: String(describing: error))
            _traceStoreFailure = error
            if isFailClosedPolicy {
                _isCancelled = true
            }
            return
        }
        do {
            if blocking, outcome == .false {
                try await emitMonitorViolation(
                    message: message,
                    step: step,
                    subjectKey: query.pattern.subjectKey,
                    sourceRange: sourceRange
                )
            }
            try await recordAssertionOutcome(
                outcome,
                message: message,
                step: step,
                sourceRange: sourceRange,
                throwOnFailure: blocking,
                subjectKey: query.pattern.subjectKey
            )
        } catch is CancellationError {
            return
        } catch {
            recordOperationalDiagnostic(code: "monitor.assertion", message: String(describing: error))
            _isCancelled = true
        }
    }

    func recordAssertionOutcome(
        _ condition: TruthValue,
        message: String,
        step: String?,
        sourceRange: SourceRange?,
        throwOnFailure: Bool,
        subjectKey: String? = nil
    ) async throws {
        let subjectKeyPayload = subjectKey.map { ["subject_key": Value.string($0)] } ?? [:]
        switch condition {
        case .true:
            try await emitOrThrow(event: Event(
                timestamp: clock.now(),
                runID: runID,
                sequence: nextSeq(),
                kind: .assertPassed,
                payload: mergeDicts([
                    "message": .string(message),
                    "outcome": .string(TruthValue.true.rawValue),
                    "step": step.map(Value.string) ?? .null
                ], subjectKeyPayload),
                sourceRange: sourceRange
            ))
        case .indeterminate:
            try await emitOrThrow(event: Event(
                timestamp: clock.now(),
                runID: runID,
                sequence: nextSeq(),
                kind: .assertPassed,
                payload: mergeDicts([
                    "message": .string(message),
                    "outcome": .string(TruthValue.indeterminate.rawValue),
                    "step": step.map(Value.string) ?? .null
                ], subjectKeyPayload),
                sourceRange: sourceRange
            ))
        case .false:
            try await emitOrThrow(event: Event(
                timestamp: clock.now(),
                runID: runID,
                sequence: nextSeq(),
                kind: .assertFailed,
                payload: mergeDicts([
                    "message": .string(message),
                    "step": step.map(Value.string) ?? .null
                ], subjectKeyPayload),
                sourceRange: sourceRange
            ))
            if throwOnFailure {
                throw MeridianRuntimeError.assertion(message: message, sourceRange: sourceRange)
            }
        }
    }

    /// A branch/match statement entered a specific arm.
    public func recordBranchTaken(
        condition: String,
        into: String,
        step: String? = nil,
        sourceRange: SourceRange? = nil
    ) async throws {
        try await emitOrThrow(event: Event(
            timestamp: clock.now(),
            runID: runID,
            sequence: nextSeq(),
            kind: .branchTaken,
            payload: [
                "condition": .string(condition),
                "into": .string(into),
                "step": step.map(Value.string) ?? .null
            ],
            sourceRange: sourceRange
        ))
    }

    /// Closes a branch arm opened by `recordBranchTaken`, so trace trees can
    /// nest the arm body under the decision (paired with `branch.end`).
    public func recordBranchEnded(
        into: String,
        step: String? = nil,
        sourceRange: SourceRange? = nil
    ) async throws {
        try await emitOrThrow(event: Event(
            timestamp: clock.now(),
            runID: runID,
            sequence: nextSeq(),
            kind: .branchEnded,
            payload: [
                "into": .string(into),
                "step": step.map(Value.string) ?? .null
            ],
            sourceRange: sourceRange
        ))
    }

    /// Records a deontic violation witness (`TraceTag.violated`) without invoking
    /// the guarded tool. PREVENTED dispositions block the invoke; OBSERVED
    /// dispositions accompany norm assert failures.
    public func recordViolation(
        obligationId: String,
        disposition: String,
        blocking: Bool,
        toolID: String? = nil,
        step: String? = nil,
        sourceRange: SourceRange? = nil
    ) async throws {
        var payload: [String: Value] = [
            "obligation_id": .string(obligationId),
            "disposition": .string(disposition),
            "blocking": .boolean(blocking),
            "step": step.map(Value.string) ?? .null,
        ]
        if let toolID {
            payload["tool_id"] = .string(toolID)
        }
        try await emitOrThrow(
            event: Event(
                timestamp: clock.now(),
                runID: runID,
                sequence: nextSeq(),
                kind: .violated,
                payload: payload,
                sourceRange: sourceRange
            ),
            hashedPayload: payload
        )
        if blocking {
            throw MeridianRuntimeError.violation(
                message: "deontic violation (\(disposition)) for obligation \(obligationId)",
                sourceRange: sourceRange
            )
        }
    }

    /// A loop began iterating over `over` (a collection description or loop kind).
    public func recordIterateStart(
        over: String,
        step: String? = nil,
        sourceRange: SourceRange? = nil
    ) async throws {
        try await emitOrThrow(event: Event(
            timestamp: clock.now(),
            runID: runID,
            sequence: nextSeq(),
            kind: .iterateStart,
            payload: ["over": .string(over), "step": step.map(Value.string) ?? .null],
            sourceRange: sourceRange
        ))
    }

    /// One loop body execution, keyed by its zero-based `index`.
    public func recordIterateIteration(
        index: Int,
        step: String? = nil,
        sourceRange: SourceRange? = nil
    ) async throws {
        try await emitOrThrow(event: Event(
            timestamp: clock.now(),
            runID: runID,
            sequence: nextSeq(),
            kind: .iterateIteration,
            payload: ["index": .number(Decimal(index)), "step": step.map(Value.string) ?? .null],
            sourceRange: sourceRange
        ))
    }

    /// A loop finished; `count` is the total number of iterations run.
    public func recordIterateEnd(
        over: String,
        count: Int,
        step: String? = nil,
        sourceRange: SourceRange? = nil
    ) async throws {
        try await emitOrThrow(event: Event(
            timestamp: clock.now(),
            runID: runID,
            sequence: nextSeq(),
            kind: .iterateEnd,
            payload: ["over": .string(over), "count": .number(Decimal(count)), "step": step.map(Value.string) ?? .null],
            sourceRange: sourceRange
        ))
    }

    /// A `recover`'s catch handler engaged for the given error `pattern` description.
    public func recordRecoverEngaged(
        pattern: String,
        step: String? = nil,
        sourceRange: SourceRange? = nil
    ) async throws {
        try await emitOrThrow(event: Event(
            timestamp: clock.now(),
            runID: runID,
            sequence: nextSeq(),
            kind: .recoverEngaged,
            payload: ["pattern": .string(pattern), "step": step.map(Value.string) ?? .null],
            sourceRange: sourceRange
        ))
    }

}
