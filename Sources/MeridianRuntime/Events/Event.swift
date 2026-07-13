import Foundation

// MARK: - EventKind

public enum EventKind: String, Codable, Sendable, CaseIterable {
    case workflowStarted = "workflow.started"
    case workflowCompleted = "workflow.completed"
    case workflowFailed = "workflow.failed"
    case workflowCancelled = "workflow.cancelled"
    case workflowSuspended = "workflow.suspended"
    case workflowResumed = "workflow.resumed"
    case bind
    case invokeStart = "invoke.start"
    case invokeEnd = "invoke.end"
    case invokeError = "invoke.error"
    case planStart = "plan.start"
    case planEnd = "plan.end"
    case planError = "plan.error"
    case planRejected = "plan.rejected"
    case autonomyStart = "autonomy.start"
    case autonomyStep = "autonomy.step"
    case autonomyEnd = "autonomy.end"
    case branchTaken = "branch.taken"
    case branchEnded = "branch.end"
    case iterateStart = "iterate.start"
    case iterateIteration = "iterate.iteration"
    case iterateEnd = "iterate.end"
    case assertPassed = "assert.passed"
    case assertFailed = "assert.failed"
    case emit
    case emitError = "emit.error"
    case waitStart = "wait.start"
    case waitResume = "wait.resume"
    case commit
    case recoverEngaged = "recover.engaged"
    case violated
}

// MARK: - Event

public struct Event: Sendable, Codable {
    public let timestamp: Date
    public let runID: String
    public let sequence: Int
    public let kind: EventKind
    public let payload: [String: Value]
    public let sourceRange: SourceRange?

    // Optional correlation fields for child/parent workflows
    public let parentRunID: String?
    public let parentSequence: Int?

    public init(
        timestamp: Date,
        runID: String,
        sequence: Int,
        kind: EventKind,
        payload: [String: Value],
        sourceRange: SourceRange? = nil,
        parentRunID: String? = nil,
        parentSequence: Int? = nil
    ) {
        self.timestamp = timestamp
        self.runID = runID
        self.sequence = sequence
        self.kind = kind
        self.payload = payload
        self.sourceRange = sourceRange
        self.parentRunID = parentRunID
        self.parentSequence = parentSequence
    }

    enum CodingKeys: String, CodingKey {
        case timestamp
        case runID
        case sequence
        case kind
        case payload
        case sourceRange
        case parentRunID
        case parentSequence
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            timestamp: try container.decode(Date.self, forKey: .timestamp),
            runID: try container.decode(String.self, forKey: .runID),
            sequence: try container.decode(Int.self, forKey: .sequence),
            kind: try container.decode(EventKind.self, forKey: .kind),
            payload: try container.decode([String: AnyCodable].self, forKey: .payload).mapValues(\.value),
            sourceRange: try container.decodeIfPresent(SourceRange.self, forKey: .sourceRange),
            parentRunID: try container.decodeIfPresent(String.self, forKey: .parentRunID),
            parentSequence: try container.decodeIfPresent(Int.self, forKey: .parentSequence)
        )
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(runID, forKey: .runID)
        try container.encode(sequence, forKey: .sequence)
        try container.encode(kind, forKey: .kind)
        try container.encode(payload.mapValues(AnyCodable.init), forKey: .payload)
        try container.encodeIfPresent(sourceRange, forKey: .sourceRange)
        try container.encodeIfPresent(parentRunID, forKey: .parentRunID)
        try container.encodeIfPresent(parentSequence, forKey: .parentSequence)
    }
}
