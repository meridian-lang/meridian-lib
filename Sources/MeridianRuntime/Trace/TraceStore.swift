import Foundation

public enum TraceStoreError: Error, Sendable, Equatable {
    case unsupportedSchemaVersion(Int)
    case invalidLineChecksum
    case corruptedLine(String)
    case traceStoreFailure(String)
}

/// A queryable sink for the runtime's single record type. Conforming stores can
/// also be installed directly as the runtime's `Observer`: the default
/// `record(_:)` implementation appends.
public protocol TraceStore: Observer {
    func append(_ record: TraceRecord) async throws
    func query(
        scope: TraceScope,
        scopeSkills: [String],
        runID: String?,
        skillName: String?,
        window: TraceWindow?,
        pattern: TraceQueryPattern?
    ) async throws -> [TraceRecord]
    func compact(retention: Duration, now: Date) async throws
    var capabilities: TraceStoreCapabilities { get async }
}

public extension TraceStore {
    func record(_ record: TraceRecord) async throws {
        try await append(record)
    }
}
