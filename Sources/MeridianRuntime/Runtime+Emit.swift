import Foundation

// Emit / observer / trace-store plumbing — extracted from Runtime for Phase 3 readability.

extension Runtime {

    // MARK: - Internal helpers

    func nextSeq() -> Int {
        sequenceCounter += 1
        _eventCount += 1
        return sequenceCounter
    }

    func cancelMonitors() {
        for task in _monitorTasks.values {
            task.cancel()
        }
        _monitorTasks.removeAll()
    }

    /// Strict emission: builds the record, appends it to the trace store (when
    /// configured), hands it to the observer, and rethrows any store/observer
    /// failure under the fail-closed policy.
    func emitOrThrow(
        kind: EventKind,
        at timestamp: Date? = nil,
        ingestOrder: Int? = nil,
        step: String? = nil,
        subject: String? = nil,
        subjectKey: String? = nil,
        payload: [String: Value]? = nil,
        hashedPayload: [String: Value]? = nil,
        sourceRange: SourceRange? = nil,
        parentRunID: String? = nil,
        parentSequence: Int? = nil
    ) async throws {
        let record = try await traceRecord(
            kind: kind,
            at: timestamp,
            ingestOrder: ingestOrder,
            step: step,
            subject: subject,
            subjectKey: subjectKey,
            payload: payload,
            hashedPayload: hashedPayload,
            sourceRange: sourceRange,
            parentRunID: parentRunID,
            parentSequence: parentSequence
        )
        await emit(record: record)
        try rethrowOperationalFailureIfNeeded()
    }

    /// Lenient emission: the same build → store → observer → waiter flow as
    /// `emitOrThrow`, but the fail-closed rethrow is swallowed (the diagnostics
    /// and cancellation bookkeeping already happened inside `emit(record:)`).
    func emit(
        kind: EventKind,
        at timestamp: Date? = nil,
        ingestOrder: Int? = nil,
        step: String? = nil,
        subject: String? = nil,
        subjectKey: String? = nil,
        payload: [String: Value]? = nil,
        hashedPayload: [String: Value]? = nil,
        sourceRange: SourceRange? = nil,
        parentRunID: String? = nil,
        parentSequence: Int? = nil
    ) async {
        _ = try? await emitOrThrow(
            kind: kind,
            at: timestamp,
            ingestOrder: ingestOrder,
            step: step,
            subject: subject,
            subjectKey: subjectKey,
            payload: payload,
            hashedPayload: hashedPayload,
            sourceRange: sourceRange,
            parentRunID: parentRunID,
            parentSequence: parentSequence
        )
    }

    var isFailClosedPolicy: Bool {
        switch traceConfiguration.storeFailurePolicy {
        case .failClosed, .auto:
            return true
        case .failOpen:
            return false
        }
    }

    func recordOperationalDiagnostic(code: String, message: String) {
        let redacted = RuntimeSecretRedaction.redact(message)
        let diagnostic = RuntimeOperationalDiagnostic(
            code: code,
            message: redacted,
            runID: runID,
            timestamp: clock.now()
        )
        _operationalDiagnostics.append(diagnostic)
        fputs("meridian-runtime[\(code)] run=\(runID): \(redacted)\n", stderr)
    }

    /// Builds the single record for one runtime emission: the call site owns
    /// kind/payload/step/subject, the runtime owns identity, timing, and skill
    /// attribution. The result is appended to the trace store (when configured)
    /// and handed to the observer — never rebuilt.
    func traceRecord(
        kind: EventKind,
        at timestamp: Date? = nil,
        ingestOrder: Int? = nil,
        step: String? = nil,
        subject: String? = nil,
        subjectKey: String? = nil,
        payload: [String: Value]? = nil,
        hashedPayload: [String: Value]? = nil,
        sourceRange: SourceRange? = nil,
        parentRunID: String? = nil,
        parentSequence: Int? = nil
    ) async throws -> TraceRecord {
        let at = timestamp ?? clock.now()
        let workflowName = payload?["workflow"]?.scalarDescription
        return try TraceRecord(
            kind: kind,
            at: at,
            run: runID,
            ingestOrder: ingestOrder ?? nextSeq(),
            skillName: workflowName ?? _traceSkillIdentity.name,
            skillVersionHash: _traceSkillIdentity.versionHash,
            id: await traceIDGenerator.nextID(at: at),
            step: step,
            subject: subject,
            subjectKey: subjectKey,
            payload: payload,
            hashedPayload: hashedPayload,
            sourceRange: sourceRange,
            parentRunID: parentRunID,
            parentSequence: parentSequence
        )
    }

    func surfacePendingArtifactWarnings() async {
        var warnings: [RuntimeArtifactWarning] = []
        if let source = checkpointer as? any ArtifactWarningSource {
            warnings.append(contentsOf: await source.consumeArtifactWarnings())
        }
        if let source = traceStore as? any ArtifactWarningSource {
            warnings.append(contentsOf: await source.consumeArtifactWarnings())
        }
        for warning in warnings {
            recordOperationalDiagnostic(code: warning.code, message: warning.message)
            await emit(
                kind: .emit,
                payload: [
                    "event": .string("runtime.artifact.warning"),
                    "code": .string(warning.code),
                    "message": .string(RuntimeSecretRedaction.redact(warning.message)),
                    "correlation_run_id": .string(warning.runID),
                    "artifact_path": warning.artifactPath.map(Value.string) ?? .null
                ]
            )
        }
    }

    func emit(record: TraceRecord) async {
        if let traceStore {
            do {
                try await traceStore.append(record)
                if _degradedTraceMarkerPending {
                    let degradedRecord = try await degradedTraceRecoveryRecord()
                    try await traceStore.append(degradedRecord)
                    _degradedTraceMarkerPending = false
                    _lastTraceStoreFailureDescription = nil
                }
                _traceStoreFailure = nil
            } catch is CancellationError {
                return
            } catch {
                _traceStoreFailure = error
                recordOperationalDiagnostic(code: "trace-store.append", message: String(describing: error))
                if isFailClosedPolicy {
                    _isCancelled = true
                } else {
                    _degradedTraceMarkerPending = true
                    _lastTraceStoreFailureDescription = String(describing: error)
                }
            }
            await surfacePendingArtifactWarnings()
        }

        do {
            try await observer.record(record)
            _observerFailure = nil
        } catch is CancellationError {
            return
        } catch {
            _observerFailure = error
            recordOperationalDiagnostic(code: "observer.record", message: String(describing: error))
            if isFailClosedPolicy {
                _isCancelled = true
            }
        }
        // Wake any event waiters that match this newly emitted record.
        if !_eventWaiters.isEmpty {
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
    }

    func rethrowOperationalFailureIfNeeded() throws {
        guard isFailClosedPolicy else { return }
        if let error = _traceStoreFailure {
            throw MeridianRuntimeError.traceStoreFailure(String(describing: error))
        }
        if let error = _observerFailure {
            throw MeridianRuntimeError.observerFailure(String(describing: error))
        }
    }

    func emitMonitorViolation(
        message: String,
        step: String?,
        subjectKey: String?,
        sourceRange: SourceRange?
    ) async throws {
        guard let traceStore else { return }
        let payload: [String: Value] = [
            "message": .string(message),
            "step": step.map(Value.string) ?? .null,
            "subject_key": subjectKey.map(Value.string) ?? .null
        ]
        let record = TraceRecord(
            id: await traceIDGenerator.nextID(at: clock.now()),
            at: clock.now(),
            ingestOrder: 0,
            run: runID,
            step: step ?? "monitor.violation",
            skillName: _traceSkillIdentity.name,
            skillVersionHash: _traceSkillIdentity.versionHash,
            tag: .violated,
            subject: step ?? "monitor",
            subjectKey: subjectKey,
            payload: payload,
            payloadHash: try CanonicalJSON.sha256Hex(for: payload),
            outcome: .failure,
            operationalDetail: "prevented",
            kind: .violated
        )
        try await traceStore.append(record)
    }

    private func degradedTraceRecoveryRecord() async throws -> TraceRecord {
        let payload: [String: Value] = [
            "message": .string("trace store append recovered after degraded witnessing"),
            "last_error": .string(_lastTraceStoreFailureDescription ?? "unknown")
        ]
        return TraceRecord(
            id: await traceIDGenerator.nextID(at: clock.now()),
            at: clock.now(),
            ingestOrder: 0,
            run: runID,
            step: "trace-store.recovery",
            skillName: _traceSkillIdentity.name,
            skillVersionHash: _traceSkillIdentity.versionHash,
            tag: .failed,
            subject: "trace-store",
            subjectKey: nil,
            payload: payload,
            payloadHash: try CanonicalJSON.sha256Hex(for: payload),
            outcome: .failure,
            operationalDetail: "degraded-witnessing-marker",
            kind: .emit
        )
    }

}
