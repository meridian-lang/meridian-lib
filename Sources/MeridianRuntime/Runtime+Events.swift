import Foundation

// Domain emit APIs — extracted from Runtime for Phase 3 readability.

extension Runtime {

    // MARK: - Events

    /// Emit a domain event. Strict mode: throws on observer failure.
    public func emit(
        event eventID: String,
        payload: [String: Value],
        step: String? = nil,
        sourceRange: SourceRange? = nil
    ) async throws {
        let fullPayload = mergeDicts(mergeDicts(["event": .string(eventID)], payload), step.map { ["step": Value.string($0)] } ?? [:])
        try await emitOrThrow(event: Event(
            timestamp: clock.now(),
            runID: runID,
            sequence: nextSeq(),
            kind: .emit,
            payload: fullPayload,
            sourceRange: sourceRange
        ))
    }

    /// Emit a domain event in lenient mode — logs failure but does not halt.
    public func emitLenient(
        event eventID: String,
        payload: [String: Value],
        step: String? = nil,
        sourceRange: SourceRange? = nil
    ) async {
        await emit(event: Event(
            timestamp: clock.now(),
            runID: runID,
            sequence: nextSeq(),
            kind: .emit,
            payload: mergeDicts(mergeDicts(["event": .string(eventID)], payload), step.map { ["step": Value.string($0)] } ?? [:]),
            sourceRange: sourceRange
        ))
    }


}
