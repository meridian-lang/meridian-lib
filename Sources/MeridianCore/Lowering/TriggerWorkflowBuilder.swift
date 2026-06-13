import MeridianRuntime

/// The standard trigger-workflow IR shell: a parameter-less workflow that waits
/// for an external event, then fans out a `trigger.<name>.fired` event whose
/// payload hosts subscribe to for dispatch. Shared by `RuleInjector` (`when …`
/// rule triggers) and `SkillTriggers` (frontmatter `triggers:`), which differ
/// only in the wait-event name, fire-event id, payload fields, and workflow name.
enum TriggerWorkflowBuilder {
    static func make(name: String,
                     waitEvent: String,
                     fireEventID: String,
                     payload: [EmitField],
                     sourceFile: String,
                     line: Int,
                     explicitStructName: String? = nil) -> IRWorkflow {
        let sr = SourceRange(file: sourceFile, line: line, column: 0)
        let waitIR = WaitIR(condition: .event(waitEvent, matching: nil), timeout: nil, sourceRange: sr)
        let emitIR = EmitIR(eventID: fireEventID, payload: payload, strict: true, sourceRange: sr)
        return IRWorkflow(
            name: name,
            parameters: [],
            body: IRBlock(statements: [.wait(waitIR), .emit(emitIR)], sourceRange: sr),
            mode: .strict,
            sourceFile: sourceFile,
            sourceRange: sr,
            explicitStructName: explicitStructName
        )
    }
}
