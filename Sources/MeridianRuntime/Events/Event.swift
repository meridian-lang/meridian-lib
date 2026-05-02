import Foundation

// MARK: - EventKind

public enum EventKind: String, Codable, Sendable {
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
}

// MARK: - Event

public struct Event: Sendable {
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
}
