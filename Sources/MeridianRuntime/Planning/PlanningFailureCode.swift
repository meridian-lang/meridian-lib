public enum PlanningFailureCode: String, Sendable, CaseIterable {
    case prosePayloadTooLarge = "planning.prose_payload_too_large"
    case toolArgumentsPayloadTooLarge = "planning.tool_arguments_payload_too_large"
    case tooManyActions = "planning.too_many_actions"
    case replanTooManyActions = "planning.replan_too_many_actions"
    case maxStepsExceeded = "planning.max_steps_exceeded"
    case hostPolicyDenied = "planning.host_policy_denied"
    case toolOutOfScope = "planning.tool_out_of_scope"
    case toolNotRegistered = "planning.tool_not_registered"
    case missingToolArgument = "planning.missing_tool_argument"
    case unexpectedToolArgument = "planning.unexpected_tool_argument"
    case invalidToolArgumentType = "planning.invalid_tool_argument_type"
    case snapshotPayloadTooLarge = "planning.snapshot_payload_too_large"
    case historyPayloadTooLarge = "planning.history_payload_too_large"
    case proposalPayloadTooLarge = "planning.proposal_payload_too_large"
}

public extension MeridianRuntimeError {
    static func planningFailure(
        _ code: PlanningFailureCode,
        message: String,
        sourceRange: SourceRange? = nil
    ) -> MeridianRuntimeError {
        .toolError(
            .implementation(code: code.rawValue, message: message, cause: nil),
            sourceRange: sourceRange
        )
    }
}
