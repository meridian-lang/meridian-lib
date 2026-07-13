import Foundation

// Public diagnostics / trace evaluation — extracted from Runtime for Phase 3 readability.

extension Runtime {

    // MARK: - Diagnostics

    public func elapsedMS() -> Double {
        (clock.now().timeIntervalSince(_startDate)) * 1000
    }

    public func eventCount() -> Int { _eventCount }

    public func operationalDiagnostics() -> [RuntimeOperationalDiagnostic] {
        _operationalDiagnostics
    }

    public func currentDate() -> Date { clock.now() }

    public func evaluateTrace(
        _ temporal: TraceTemporalQuery,
        evaluationInstant: Date
    ) async throws -> TruthValue {
        guard let traceStore else {
            return .indeterminate
        }
        let result = try await TraceEvaluator.evaluate(
            temporal: temporal,
            store: traceStore,
            context: TraceEvaluationContext(
                runID: runID,
                skillName: _traceSkillIdentity.name,
                evaluationInstant: evaluationInstant,
                sampleFloor: traceConfiguration.sampleFloor
            )
        )
        await surfacePendingArtifactWarnings()
        return result
    }

    public func evaluateTrace(
        _ statistical: TraceStatisticalQuery,
        evaluationInstant: Date
    ) async throws -> TruthValue {
        guard let traceStore else {
            return .indeterminate
        }
        let result = try await TraceEvaluator.evaluate(
            statistical: statistical,
            store: traceStore,
            context: TraceEvaluationContext(
                runID: runID,
                skillName: _traceSkillIdentity.name,
                evaluationInstant: evaluationInstant,
                sampleFloor: traceConfiguration.sampleFloor
            )
        )
        await surfacePendingArtifactWarnings()
        return result
    }

}
