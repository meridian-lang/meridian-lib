import Foundation

public enum TraceStoreError: Error, Sendable, Equatable {
    case unsupportedSchemaVersion(Int)
    case invalidLineChecksum
    case corruptedLine(String)
    case traceStoreFailure(String)
}

public protocol TraceStore: Sendable {
    func append(_ event: TraceRecord) async throws
    func query(
        scope: TraceScope,
        runID: String?,
        skillName: String?,
        window: TraceWindow?,
        pattern: TraceQueryPattern?
    ) async throws -> [TraceRecord]
    func compact(retention: Duration, now: Date) async throws
    var capabilities: TraceStoreCapabilities { get async }
    func verifyChain(runID: String) async throws -> TraceChainVerificationResult
}
