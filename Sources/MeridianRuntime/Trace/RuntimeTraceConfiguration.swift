import Foundation

public enum TraceStoreKind: String, Sendable, Codable, Equatable {
    case memory
    case file
    case sqlite
    case http
}

public enum TraceCapturePolicy: Sendable, Codable, Equatable {
    case full
    case hashOnly
    case redacted([String])
    case omitted

    public static let `default` = TraceCapturePolicy.full
}

public struct RuntimeTraceConfiguration: Sendable, Codable, Equatable {
    public let store: TraceStoreKind
    public let trace: TraceConfiguration
    public let skillIdentity: TraceSkillIdentity
    public let toolCapturePolicies: [String: TraceCapturePolicy]
    /// Filesystem path for `.sqlite` / `.file` stores when auto-wiring.
    public let storePath: String?
    /// HTTP endpoint base URL for `.http` stores when auto-wiring.
    public let storeEndpoint: URL?

    public init(
        store: TraceStoreKind = .memory,
        trace: TraceConfiguration = .default,
        skillIdentity: TraceSkillIdentity = .unknown,
        toolCapturePolicies: [String: TraceCapturePolicy] = [:],
        storePath: String? = nil,
        storeEndpoint: URL? = nil
    ) {
        self.store = store
        self.trace = trace
        self.skillIdentity = skillIdentity
        self.toolCapturePolicies = toolCapturePolicies
        self.storePath = storePath
        self.storeEndpoint = storeEndpoint
    }

    public static let `default` = RuntimeTraceConfiguration()

    public func capturePolicy(for toolID: String) -> TraceCapturePolicy {
        toolCapturePolicies[toolID] ?? .default
    }
}
