import Foundation

// Completion / cancellation / instances / workflow lifecycle — extracted from Runtime for Phase 3 readability.

extension Runtime {

    // MARK: - Completion

    /// Mark the workflow as gracefully completed. Call immediately before `return`.
    public func complete(reason: String?, step: String? = nil, sourceRange: SourceRange? = nil) async {
        cancelMonitors()
        let payload: [String: Value] = [
            "reason": reason.map { .string($0) } ?? .null,
            "duration_ms": .number(Decimal(elapsedMS())),
            "event_count": .number(Decimal(_eventCount + 1)),
            "step": step.map(Value.string) ?? .null
        ]
        await emit(kind: .workflowCompleted, payload: payload, sourceRange: sourceRange)
    }

    // MARK: - Cancellation

    public func cancel(runID: String) async {
        _isCancelled = true
        cancelMonitors()
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


    // MARK: - Workflow lifecycle

    /// Call at the start of run() to emit workflow.started.
    public func workflowStarted(
        workflowName: String,
        parameters: [String: Value],
        sourceRange: SourceRange? = nil
    ) async {
        _activeWorkflowName = workflowName
        var payload: [String: Value] = ["workflow": .string(workflowName)]
        for (k, v) in parameters { payload[k] = v }
        await emit(
            kind: .workflowStarted,
            payload: payload,
            sourceRange: sourceRange,
            parentRunID: parentRunID,
            parentSequence: parentSequence
        )
    }

    /// Emit a terminal workflow.failed event before rethrowing a run() error.
    /// Cancellation is not recorded — callers should rethrow `CancellationError` unchanged.
    public func workflowFailed(
        workflowName: String,
        error: any Error,
        step: String? = nil,
        sourceRange: SourceRange? = nil
    ) async throws {
        if error is CancellationError { return }
        cancelMonitors()
        var payload: [String: Value] = [
            "workflow": .string(workflowName),
            "error": .string(String(describing: error)),
            "duration_ms": .number(Decimal(elapsedMS())),
            "event_count": .number(Decimal(_eventCount + 1)),
            "step": step.map(Value.string) ?? .null,
            "cancelled": .boolean(false)
        ]
        if let code = implementationErrorCode(error) {
            payload["error_code"] = .string(code)
        }
        try await emitOrThrow(
            kind: .workflowFailed,
            payload: payload,
            sourceRange: sourceRange,
            parentRunID: parentRunID,
            parentSequence: parentSequence
        )
    }

    /// Emit a structural event (branch.taken, bind, assert.passed, etc.) from generated code.
    public func recordEvent(
        _ kind: EventKind,
        payload: [String: Value],
        sourceRange: SourceRange? = nil
    ) async {
        await emit(kind: kind, payload: payload, sourceRange: sourceRange)
    }

}
