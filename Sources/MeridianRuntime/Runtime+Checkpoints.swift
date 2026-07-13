import Foundation

// Checkpoint / resume / state-snapshot APIs — extracted from Runtime for Phase 3 readability.

extension Runtime {

    // MARK: - Checkpoints

    /// Record a checkpoint. Workflow can resume from here after a crash.
    public func checkpoint(
        label: String? = nil,
        state: StateSnapshot,
        step: String? = nil,
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
        do {
            try await checkpointer.write(cp)
        } catch {
            recordOperationalDiagnostic(code: "checkpoint.write", message: String(describing: error))
            throw MeridianRuntimeError.checkpointFailed(
                String(describing: error),
                sourceRange: sourceRange
            )
        }
        try await emitOrThrow(event: Event(
            timestamp: clock.now(),
            runID: runID,
            sequence: seq,
            kind: .commit,
            payload: mergeDicts(label.map { ["label": Value.string($0)] } ?? [:], step.map { ["step": Value.string($0)] } ?? [:]),
            sourceRange: sourceRange
        ))
        try await recordStateSnapshotIfEnabled(
            state: state,
            operation: "commit",
            key: nil,
            step: step,
            sourceRange: sourceRange
        )
    }

    /// When `state history: enabled` is set in trace configuration, append a
    /// `.stateSnapshot` trace record after bind/rebind/commit mutations.
    public func recordStateSnapshotIfEnabled(
        state: StateSnapshot,
        operation: String,
        key: String? = nil,
        step: String? = nil,
        sourceRange: SourceRange? = nil
    ) async throws {
        guard traceConfiguration.stateHistoryRetention, let traceStore else { return }
        var payload = state.asValues
        payload["operation"] = .string(operation)
        if let key {
            payload["key"] = .string(key)
        }
        let record = TraceRecord(
            id: await traceIDGenerator.nextID(at: clock.now()),
            at: clock.now(),
            ingestOrder: nextSeq(),
            run: runID,
            step: step ?? operation,
            skillName: _traceSkillIdentity.name,
            skillVersionHash: _traceSkillIdentity.versionHash,
            tag: .stateSnapshot,
            subject: key ?? operation,
            subjectKey: key,
            payload: payload,
            payloadHash: try CanonicalJSON.sha256Hex(for: payload),
            outcome: .success,
            witness: nil,
            previousHash: nil,
            recordHash: nil,
            operationalDetail: operation,
            legacyKind: nil
        )
        try await traceStore.append(record)
        try rethrowOperationalFailureIfNeeded()
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
        let checkpoint = try await checkpointer.latest(forRun: runID)
        await surfacePendingArtifactWarnings()
        guard let checkpoint else {
            recordOperationalDiagnostic(
                code: "checkpoint.resume",
                message: "no checkpoint found for runID `\(runID)`"
            )
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
        try await emitOrThrow(event: Event(
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


}
