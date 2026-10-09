import Foundation

// Wait / delivery APIs / park helpers — extracted from Runtime for Phase 3
// readability.

extension Runtime {

    // MARK: - Wait

    /// Suspend execution on a wait condition.
    ///
    /// - `.duration`: suspends for the given duration via `Clock.sleep`.
    /// - `.signal`: blocks until `deliverSignal(_:)` is called with the same name.
    ///   At-most-once delivery; if no workflow is waiting when a signal arrives it
    ///   is dropped (logged at warning level). FIFO when multiple waiters share a name.
    /// - `.approval`: blocks until `deliverApproval(of:by:verdict:)` is called.
    ///   `.approved` resumes normally; `.denied` throws `MeridianRuntimeError.approvalDenied`.
    /// - `.event`: blocks until `deliverEvent(id:payload:)` fires an event whose `id` and
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
        try await emitOrThrow(
            kind: .waitStart,
            payload: waitStartPayload(condition),
            sourceRange: sourceRange
        )

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
            if let t = timeout {
                try await waitWithTimeout(t, sourceRange: sourceRange) {
                    try await self.parkForSignal(name)
                }
            } else {
                try await parkForSignal(name)
            }

        case .approval(let subject, let role):
            let key = ApprovalKey(subject: subject, role: role.identifier)
            if let t = timeout {
                try await waitWithTimeout(t, sourceRange: sourceRange) {
                    try await self.parkForApproval(key)
                }
            } else {
                try await parkForApproval(key)
            }

        case .event(let eventID, let matching):
            if let t = timeout {
                try await waitWithTimeout(t, sourceRange: sourceRange) {
                    try await self.parkForEvent(eventID: eventID, matching: matching)
                }
            } else {
                try await parkForEvent(eventID: eventID, matching: matching)
            }

        case .choice:
            if let t = timeout {
                try await waitWithTimeout(t, sourceRange: sourceRange) {
                    try await self.parkForChoice()
                }
            } else {
                try await parkForChoice()
            }
        }

        try await emitOrThrow(
            kind: .waitResume,
            payload: [:],
            sourceRange: sourceRange
        )
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
    /// The matching record is never persisted, so it consumes no sequence number.
    public func deliverEvent(id: String, payload: [String: Value] = [:]) async {
        guard let record = try? await traceRecord(
            kind: .emit,
            ingestOrder: 0,
            payload: mergeDicts(["event": .string(id)], payload)
        ) else {
            return
        }
        var remaining: [EventWaiterEntry] = []
        for entry in _eventWaiters {
            let idMatches = entry.eventID.isEmpty || record.payload?["event"] == .string(entry.eventID)
            let predMatches = entry.predicate.map { $0(record) } ?? true
            if idMatches && predMatches {
                entry.continuation.resume()
            } else {
                remaining.append(entry)
            }
        }
        _eventWaiters = remaining
    }

    // MARK: - Internal wait helpers

    func parkForSignal(_ name: String) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, any Error>) in
            _signalWaiters[name, default: []].append(cont)
        }
    }

    func parkForApproval(_ key: ApprovalKey) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, any Error>) in
            _approvalWaiters[key, default: []].append(cont)
        }
    }

    func parkForEvent(
        eventID: String,
        matching: (@Sendable (TraceRecord) -> Bool)?
    ) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, any Error>) in
            _eventWaiters.append(EventWaiterEntry(eventID: eventID, predicate: matching, continuation: cont))
        }
    }

    func parkForChoice() async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, any Error>) in
            _choiceWaiters.append(cont)
        }
    }

    func waitWithTimeout(
        _ timeout: Duration,
        sourceRange: SourceRange?,
        operation: @escaping @Sendable () async throws -> Void
    ) async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask { try await operation() }
            group.addTask {
                try await self.clock.sleep(for: timeout)
                throw MeridianRuntimeError.timeout(condition: .duration(timeout), sourceRange: sourceRange)
            }
            try await group.next()
            group.cancelAll()
        }
    }

    func waitStartPayload(_ condition: WaitCondition) -> [String: Value] {
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


}
