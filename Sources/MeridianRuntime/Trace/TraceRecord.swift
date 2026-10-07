import Foundation

public enum TraceTag: String, Sendable, Codable, CaseIterable {
    case invoked
    case completed
    case failed
    case emitted
    case asserted
    case assertFailed = "assert-failed"
    case branched
    case iterated
    case judged
    case committed
    case recovered
    case violated
    case stateSnapshot
}

public enum TraceOutcome: String, Sendable, Codable, CaseIterable {
    case success
    case failure
    case indeterminate
}

public struct TraceSkillIdentity: Sendable, Codable, Equatable {
    public let name: String
    public let versionHash: String

    public init(name: String, versionHash: String) {
        self.name = name
        self.versionHash = versionHash
    }

    public static let unknown = TraceSkillIdentity(name: "unknown", versionHash: "unknown")
}

public enum TraceScope: String, Sendable, Codable, Equatable {
    case currentRun
    case acrossAllRuns
    case acrossSkills
}

public struct TraceWindow: Sendable, Equatable {
    public let start: Date?
    public let end: Date?

    public init(start: Date? = nil, end: Date? = nil) {
        self.start = start
        self.end = end
    }

    public static func last(_ duration: Duration, endingAt end: Date) -> TraceWindow {
        TraceWindow(start: end.addingTimeInterval(-duration.timeInterval), end: end)
    }

    public func contains(_ date: Date) -> Bool {
        if let start, date < start {
            return false
        }
        if let end, date > end {
            return false
        }
        return true
    }
}

public struct TraceQueryPattern: Sendable, Equatable {
    public let tags: Set<TraceTag>?
    public let subject: String?
    public let subjectKey: String?
    public let outcome: TraceOutcome?
    public let payloadContains: [String: Value]?

    public init(
        tags: Set<TraceTag>? = nil,
        subject: String? = nil,
        subjectKey: String? = nil,
        outcome: TraceOutcome? = nil,
        payloadContains: [String: Value]? = nil
    ) {
        self.tags = tags
        self.subject = subject
        self.subjectKey = subjectKey
        self.outcome = outcome
        self.payloadContains = payloadContains
    }

    func matches(_ record: TraceRecord) -> Bool {
        if let tags, !tags.contains(record.tag) {
            return false
        }
        if let subject, record.subject != subject {
            return false
        }
        if let subjectKey, record.subjectKey != subjectKey {
            return false
        }
        if let outcome, record.outcome != outcome {
            return false
        }
        if let payloadContains {
            guard let payload = record.payload else {
                return false
            }
            for (key, value) in payloadContains where payload[key] != value {
                return false
            }
        }
        return true
    }
}

public struct TraceStoreCapabilities: Sendable, Codable, Equatable {
    public let isPersistent: Bool
    public let supportsCompaction: Bool
    /// Whether the store retains full event payloads (vs. hash-only mode, which
    /// keeps `payloadHash` for parity/coherence checking but drops `payload`
    /// content -- the 4.1 capture-policy mitigation for trace-as-data-liability).
    /// `true` for both shipped stores (in-memory, JSONL); a future hash-only
    /// store would report `false` here.
    public let payloadRetention: Bool

    public init(
        isPersistent: Bool,
        supportsCompaction: Bool,
        payloadRetention: Bool = true
    ) {
        self.isPersistent = isPersistent
        self.supportsCompaction = supportsCompaction
        self.payloadRetention = payloadRetention
    }
}

public enum TraceProfile: String, Sendable, Codable, Equatable {
    case development
    case production
}

public enum TraceStoreFailurePolicy: String, Sendable, Codable, Equatable {
    case auto
    case failOpen
    case failClosed
}

public struct TraceConfiguration: Sendable, Codable, Equatable {
    public let retention: Duration
    public let payloadLimit: Int?
    public let usuallyThreshold: Double
    public let rarelyThreshold: Double
    public let sampleFloor: Int
    public let defaultMonitorCadence: Duration
    public let profile: TraceProfile
    public let storeFailurePolicy: TraceStoreFailurePolicy
    public let deploymentZone: String
    public let crossSkillAllowList: [String]
    public let stateHistoryRetention: Bool

    public init(
        retention: Duration = .seconds(60 * 60 * 24 * 30),
        payloadLimit: Int? = nil,
        usuallyThreshold: Double = 0.9,
        rarelyThreshold: Double = 0.1,
        sampleFloor: Int = 20,
        defaultMonitorCadence: Duration = .seconds(60),
        profile: TraceProfile = .development,
        storeFailurePolicy: TraceStoreFailurePolicy = .failClosed,
        deploymentZone: String = "UTC",
        crossSkillAllowList: [String] = [],
        stateHistoryRetention: Bool = false
    ) {
        self.retention = retention
        self.payloadLimit = payloadLimit
        self.usuallyThreshold = usuallyThreshold
        self.rarelyThreshold = rarelyThreshold
        self.sampleFloor = sampleFloor
        self.defaultMonitorCadence = defaultMonitorCadence
        self.profile = profile
        self.storeFailurePolicy = storeFailurePolicy
        self.deploymentZone = deploymentZone
        self.crossSkillAllowList = crossSkillAllowList
        self.stateHistoryRetention = stateHistoryRetention
    }

    public static let `default` = TraceConfiguration()
}

public struct TraceRecord: Sendable, Equatable, Codable {
    public static let currentSchemaVersion = 2

    public let schemaVersion: Int
    public let id: String
    public let at: Date
    public let ingestOrder: Int
    public let run: String
    public let step: String
    public let skillName: String
    public let skillVersionHash: String
    public let tag: TraceTag
    public let subject: String?
    public let subjectKey: String?
    public let payload: [String: Value]?
    public let payloadHash: String
    public let outcome: TraceOutcome?
    public let operationalDetail: String?
    public let legacyKind: String?

    public init(
        schemaVersion: Int = TraceRecord.currentSchemaVersion,
        id: String,
        at: Date,
        ingestOrder: Int,
        run: String,
        step: String,
        skillName: String,
        skillVersionHash: String,
        tag: TraceTag,
        subject: String? = nil,
        subjectKey: String? = nil,
        payload: [String: Value]? = nil,
        payloadHash: String,
        outcome: TraceOutcome? = nil,
        operationalDetail: String? = nil,
        legacyKind: String? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.id = id
        self.at = at
        self.ingestOrder = ingestOrder
        self.run = run
        self.step = step
        self.skillName = skillName
        self.skillVersionHash = skillVersionHash
        self.tag = tag
        self.subject = subject
        self.subjectKey = subjectKey
        self.payload = payload
        self.payloadHash = payloadHash
        self.outcome = outcome
        self.operationalDetail = operationalDetail
        self.legacyKind = legacyKind
    }

    enum CodingKeys: String, CodingKey {
        case schemaVersion
        case id
        case at
        case ingestOrder
        case run
        case step
        case skillName
        case skillVersionHash
        case tag
        case subject
        case subjectKey
        case payload
        case payloadHash
        case outcome
        case operationalDetail
        case legacyKind
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let encodedPayload = try container.decodeIfPresent([String: AnyCodable].self, forKey: .payload)
        self.init(
            schemaVersion: try container.decode(Int.self, forKey: .schemaVersion),
            id: try container.decode(String.self, forKey: .id),
            at: try container.decode(Date.self, forKey: .at),
            ingestOrder: try container.decode(Int.self, forKey: .ingestOrder),
            run: try container.decode(String.self, forKey: .run),
            step: try container.decode(String.self, forKey: .step),
            skillName: try container.decode(String.self, forKey: .skillName),
            skillVersionHash: try container.decode(String.self, forKey: .skillVersionHash),
            tag: try container.decode(TraceTag.self, forKey: .tag),
            subject: try container.decodeIfPresent(String.self, forKey: .subject),
            subjectKey: try container.decodeIfPresent(String.self, forKey: .subjectKey),
            payload: encodedPayload?.mapValues(\.value),
            payloadHash: try container.decode(String.self, forKey: .payloadHash),
            outcome: try container.decodeIfPresent(TraceOutcome.self, forKey: .outcome),
            operationalDetail: try container.decodeIfPresent(String.self, forKey: .operationalDetail),
            legacyKind: try container.decodeIfPresent(String.self, forKey: .legacyKind)
        )
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(id, forKey: .id)
        try container.encode(at, forKey: .at)
        try container.encode(ingestOrder, forKey: .ingestOrder)
        try container.encode(run, forKey: .run)
        try container.encode(step, forKey: .step)
        try container.encode(skillName, forKey: .skillName)
        try container.encode(skillVersionHash, forKey: .skillVersionHash)
        try container.encode(tag, forKey: .tag)
        try container.encodeIfPresent(subject, forKey: .subject)
        try container.encodeIfPresent(subjectKey, forKey: .subjectKey)
        if let payload {
            try container.encode(payload.mapValues(AnyCodable.init), forKey: .payload)
        }
        try container.encode(payloadHash, forKey: .payloadHash)
        try container.encodeIfPresent(outcome, forKey: .outcome)
        try container.encodeIfPresent(operationalDetail, forKey: .operationalDetail)
        try container.encodeIfPresent(legacyKind, forKey: .legacyKind)
    }
}

extension Duration {
    var timeInterval: TimeInterval {
        Double(components.seconds) + (Double(components.attoseconds) / 1_000_000_000_000_000_000)
    }
}
