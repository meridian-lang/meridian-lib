import Foundation

/// The kind of a runtime emission. `TraceRecord` is the single runtime record
/// type; `kind` is the semantic discriminator that `tag` / `outcome` /
/// `operationalDetail` are projected from.
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
