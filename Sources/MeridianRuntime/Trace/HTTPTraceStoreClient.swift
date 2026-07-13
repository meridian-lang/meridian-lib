import Foundation

public struct HTTPTraceAppendRequest: Codable, Sendable, Equatable {
    public let record: TraceRecord
    public let checksum: String

    public init(record: TraceRecord, checksum: String) {
        self.record = record
        self.checksum = checksum
    }
}

public struct HTTPTraceQueryRequest: Sendable, Equatable {
    public let scope: TraceScope
    public let scopeSkills: [String]
    public let runID: String?
    public let skillName: String?
    public let windowStart: Date?
    public let windowEnd: Date?
    public let patternTags: [String]?
    public let patternSubject: String?
    public let patternSubjectKey: String?
    public let patternOutcome: String?

    public init(
        scope: TraceScope,
        scopeSkills: [String] = [],
        runID: String? = nil,
        skillName: String? = nil,
        window: TraceWindow? = nil,
        pattern: TraceQueryPattern? = nil
    ) {
        self.scope = scope
        self.scopeSkills = scopeSkills
        self.runID = runID
        self.skillName = skillName
        self.windowStart = window?.start
        self.windowEnd = window?.end
        self.patternTags = pattern?.tags.map { Array($0.map(\.rawValue)) }
        self.patternSubject = pattern?.subject
        self.patternSubjectKey = pattern?.subjectKey
        self.patternOutcome = pattern?.outcome?.rawValue
    }

    public var window: TraceWindow? {
        guard windowStart != nil || windowEnd != nil else { return nil }
        return TraceWindow(start: windowStart, end: windowEnd)
    }

    public var pattern: TraceQueryPattern? {
        guard patternTags != nil || patternSubject != nil || patternSubjectKey != nil || patternOutcome != nil else {
            return nil
        }
        let tags = patternTags.map { Set($0.compactMap(TraceTag.init(rawValue:))) }
        return TraceQueryPattern(
            tags: tags,
            subject: patternSubject,
            subjectKey: patternSubjectKey,
            outcome: patternOutcome.flatMap(TraceOutcome.init(rawValue:)),
            payloadContains: nil
        )
    }
}

extension HTTPTraceQueryRequest: Codable {
    enum CodingKeys: String, CodingKey {
        case scope, scopeSkills, runID, skillName, windowStart, windowEnd
        case patternTags, patternSubject, patternSubjectKey, patternOutcome
    }
}

public struct HTTPTraceQueryResponse: Codable, Sendable, Equatable {
    public let records: [TraceRecord]

    public init(records: [TraceRecord]) {
        self.records = records
    }
}

public enum HTTPTraceStoreProtocol {
    public static let appendPath = "/meridian/v1/traces/append"
    public static let queryPath = "/meridian/v1/traces/query"
    public static let contentType = "application/json"
    public static let protocolVersion = "meridian-trace-http/1"
}

public protocol HTTPTraceTransport: Sendable {
    func post(path: String, body: Data) async throws -> Data
}

public struct URLSessionHTTPTraceTransport: HTTPTraceTransport {
    private let baseURL: URL
    private let session: URLSession

    public init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    public func post(path: String, body: Data) async throws -> Data {
        let url = baseURL.appendingPathComponent(path.trimmingCharacters(in: CharacterSet(charactersIn: "/")))
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(HTTPTraceStoreProtocol.contentType, forHTTPHeaderField: "Content-Type")
        request.setValue(HTTPTraceStoreProtocol.protocolVersion, forHTTPHeaderField: "X-Meridian-Trace-Protocol")
        request.httpBody = body
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw TraceStoreError.traceStoreFailure("HTTP trace store returned status \(status)")
        }
        return data
    }
}

public actor HTTPTraceStoreClient: TraceStore {
    private let transport: any HTTPTraceTransport
    private let configuration: TraceConfiguration
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(transport: any HTTPTraceTransport, configuration: TraceConfiguration = .default) {
        self.transport = transport
        self.configuration = configuration
        self.encoder = JSONEncoder()
        self.encoder.outputFormatting = [.sortedKeys]
        self.encoder.dateEncodingStrategy = .iso8601
        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601
    }

    public var capabilities: TraceStoreCapabilities {
        TraceStoreCapabilities(
            isPersistent: true,
            supportsHashChaining: configuration.hashChaining,
            supportsCompaction: false,
            payloadRetention: true,
            indexedFields: ["run", "tag", "subject", "at"],
            supportedSchemaVersions: [TraceRecord.currentSchemaVersion, TraceRecord.currentSchemaVersion - 1]
        )
    }

    public func append(_ event: TraceRecord) async throws {
        guard capabilities.supportedSchemaVersions.contains(event.schemaVersion) else {
            throw TraceStoreError.unsupportedSchemaVersion(event.schemaVersion)
        }
        let checksum = try CanonicalJSON.sha256Hex(for: event)
        let request = HTTPTraceAppendRequest(record: event, checksum: checksum)
        let body = try encoder.encode(request)
        _ = try await transport.post(path: HTTPTraceStoreProtocol.appendPath, body: body)
    }

    public func query(
        scope: TraceScope,
        scopeSkills: [String],
        runID: String?,
        skillName: String?,
        window: TraceWindow?,
        pattern: TraceQueryPattern?
    ) async throws -> [TraceRecord] {
        let request = HTTPTraceQueryRequest(
            scope: scope,
            scopeSkills: scopeSkills,
            runID: runID,
            skillName: skillName,
            window: window,
            pattern: pattern
        )
        let body = try encoder.encode(request)
        let data = try await transport.post(path: HTTPTraceStoreProtocol.queryPath, body: body)
        let response = try decoder.decode(HTTPTraceQueryResponse.self, from: data)
        return TraceStoreHelpers.filterAndSort(
            response.records,
            scope: scope,
            scopeSkills: scopeSkills,
            runID: runID,
            skillName: skillName,
            window: window,
            pattern: pattern
        )
    }

    public func compact(retention: Duration, now: Date) async throws {}

    public func verifyChain(runID: String) async throws -> TraceChainVerificationResult {
        let records = try await query(
            scope: .currentRun,
            scopeSkills: [],
            runID: runID,
            skillName: nil,
            window: nil,
            pattern: nil
        )
        return HashChain.verify(records: records, runID: runID)
    }
}
