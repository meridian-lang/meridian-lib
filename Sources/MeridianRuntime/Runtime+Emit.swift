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

    func emitOrThrow(event: Event, hashedPayload: [String: Value]? = nil, witness: String? = nil) async throws {
        await emit(event: event, hashedPayload: hashedPayload, witness: witness)
        try rethrowOperationalFailureIfNeeded()
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
            await emit(event: Event(
                timestamp: clock.now(),
                runID: runID,
                sequence: nextSeq(),
                kind: .emit,
                payload: [
                    "event": .string("runtime.artifact.warning"),
                    "code": .string(warning.code),
                    "message": .string(RuntimeSecretRedaction.redact(warning.message)),
                    "correlation_run_id": .string(warning.runID),
                    "artifact_path": warning.artifactPath.map(Value.string) ?? .null
                ],
                sourceRange: nil
            ))
        }
    }

    func emit(event: Event, hashedPayload: [String: Value]? = nil, witness: String? = nil) async {
        if let traceStore {
            do {
                let record = try await semanticTraceRecord(for: event, hashedPayload: hashedPayload, witness: witness)
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
            try await observer.record(event)
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
            witness: nil,
            previousHash: nil,
            recordHash: nil,
            operationalDetail: "prevented",
            legacyKind: nil
        )
        try await traceStore.append(record)
    }

    private func semanticTraceRecord(for event: Event, hashedPayload: [String: Value]?, witness: String? = nil) async throws -> TraceRecord {
        let workflowName = event.payload["workflow"]?.scalarDescription
        let skillIdentity = workflowName.map { TraceSkillIdentity(name: $0, versionHash: _traceSkillIdentity.versionHash) } ?? _traceSkillIdentity
        let step = event.payload["step"]?.scalarDescription ?? event.kind.rawValue
        let subjectKey = event.payload["subject_key"]?.scalarDescription
        return try TraceRecord(
            legacy: event,
            step: step,
            skillName: skillIdentity.name,
            skillVersionHash: skillIdentity.versionHash,
            id: await traceIDGenerator.nextID(at: event.timestamp),
            ingestOrder: event.sequence,
            subjectKey: subjectKey,
            payload: event.payload,
            hashedPayload: hashedPayload,
            witness: witness
        )
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
            witness: nil,
            previousHash: nil,
            recordHash: nil,
            operationalDetail: "degraded-witnessing-marker",
            legacyKind: nil
        )
    }

}
