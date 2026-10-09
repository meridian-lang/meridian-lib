import Testing
@testable import MeridianCore

@Suite("Prose mode")
struct ProseModeTests {

    @Test("unmatched line in discretion workflow lowers to AIJudgmentIR")
    func discretionUnmatchedLineBecomesProseStep() throws {
        let symbols = SymbolTable()
        let ast = try MeridianParser(symbols: symbols).parse("""
        To babysit, with discretion:
          inspect the diff and leave only useful comments.
        """)

        let workflows = try ASTToIR(symbols: symbols, sourceFile: "test.meridian", engine: DiagnosticEngine()).lower(ast)
        guard case .aiJudgment(let step) = workflows[0].body.statements.first else {
            Issue.record("Expected AIJudgmentIR")
            return
        }
        #expect(step.text == "inspect the diff and leave only useful comments")
    }

    @Test("unmatched line outside discretion still raises a semantic error")
    func strictUnmatchedLineStillErrors() throws {
        let symbols = SymbolTable()
        let ast = try MeridianParser(symbols: symbols).parse("""
        To babysit:
          inspect the diff and leave only useful comments.
        """)

        // The lowerer's batch engine collects; the pipeline caller checkpoints.
        let engine = DiagnosticEngine()
        #expect(throws: CompilerError.self) {
            _ = try ASTToIR(symbols: symbols, sourceFile: "test.meridian", engine: engine).lower(ast)
            try engine.throwIfErrors()
        }
    }

    @Test("AIJudgmentIR emits runtime executeProsePlan call")
    func proseStepCodegen() throws {
        let workflow = IRWorkflow(
            name: "Demo",
            parameters: [],
            body: IRBlock(statements: [
                .aiJudgment(AIJudgmentIR(
                    text: "inspect the diff",
                    scopedTools: ["github.comment"]
                ))
            ])
        )

        let out = try SwiftEmitter(options: .init(emitSourceLineComments: false)).emit(workflows: [workflow]).combined
        #expect(out.contains("runtime.executeProsePlan"))
        #expect(out.contains("github.comment"))
    }

    // no surface syntax declares a judgment's output kind yet, so
    // `ASTToIR.makeAIPrimitive` always lowers to the honest structural
    // default `"record"` — asserted here so a future single-value output
    // syntax has a pinned baseline to change.
    @Test("unmatched line in discretion workflow lowers to AIJudgmentIR with the record output-kind default")
    func discretionProseStepDefaultsToRecordOutputKind() throws {
        let symbols = SymbolTable()
        let ast = try MeridianParser(symbols: symbols).parse("""
        To babysit, with discretion:
          inspect the diff and leave only useful comments.
        """)

        let workflows = try ASTToIR(symbols: symbols, sourceFile: "test.meridian", engine: DiagnosticEngine()).lower(ast)
        guard case .aiJudgment(let step) = workflows[0].body.statements.first else {
            Issue.record("Expected AIJudgmentIR"); return
        }
        #expect(step.outputKind == "record")
    }

    @Test("AIJudgmentIR.outputKind emits an outputKind: argument before step:")
    func proseStepOutputKindCodegen() throws {
        let workflow = IRWorkflow(
            name: "Demo",
            parameters: [],
            body: IRBlock(statements: [
                .aiJudgment(AIJudgmentIR(
                    text: "inspect the diff",
                    scopedTools: ["github.comment"],
                    outputKind: "text"
                ))
            ])
        )

        let out = try SwiftEmitter(options: .init(emitSourceLineComments: false)).emit(workflows: [workflow]).combined
        #expect(out.contains("outputKind: \"text\","))
        guard let outputKindRange = out.range(of: "outputKind: \"text\","),
              let stepRange = out.range(of: "step:", range: outputKindRange.upperBound..<out.endIndex) else {
            Issue.record("expected outputKind: before step: in:\n\(out)")
            return
        }
        #expect(outputKindRange.lowerBound < stepRange.lowerBound)
    }

    @Test("AIJudgmentIR.guidance emits an escaped guidance: argument (plan-then-execute)")
    func proseStepGuidanceCodegenPlanThenExecute() throws {
        let workflow = IRWorkflow(
            name: "Demo",
            parameters: [],
            body: IRBlock(statements: [
                .aiJudgment(AIJudgmentIR(
                    text: "follow the install guidance",
                    scopedTools: ["shell.run"],
                    guidance: "Run \"gbrain doctor\" first."
                ))
            ])
        )

        let out = try SwiftEmitter(options: .init(emitSourceLineComments: false)).emit(workflows: [workflow]).combined
        #expect(out.contains("runtime.executeProsePlan"))
        #expect(out.contains("scopedTools: [\"shell.run\"],"))
        #expect(out.contains("guidance: \"Run \\\"gbrain doctor\\\" first.\""))
    }

    @Test("AIAutonomyIR.guidance emits after autonomy config args (autonomous loop)")
    func proseStepGuidanceCodegenAutonomousLoop() throws {
        let workflow = IRWorkflow(
            name: "Demo",
            parameters: [],
            body: IRBlock(statements: [
                .aiAutonomy(AIAutonomyIR(
                    text: "follow the repair guidance",
                    autonomy: AutonomyConfigIR(),
                    guidance: "Repair every missing back-link."
                ))
            ])
        )

        let out = try SwiftEmitter(options: .init(emitSourceLineComments: false)).emit(workflows: [workflow]).combined
        #expect(out.contains("runtime.executeAutonomousLoop"))
        #expect(out.contains("replanAfterFailures: 3,"))
        #expect(out.contains("guidance: \"Repair every missing back-link.\""))
    }

    @Test("AIAutonomyIR.outputKind emits an outputKind: argument between replanAfterFailures: and step:")
    func autonomyStepOutputKindCodegen() throws {
        let workflow = IRWorkflow(
            name: "Demo",
            parameters: [],
            body: IRBlock(statements: [
                .aiAutonomy(AIAutonomyIR(
                    text: "keep fixing",
                    autonomy: AutonomyConfigIR(),
                    outputKind: "text"
                ))
            ])
        )

        let out = try SwiftEmitter(options: .init(emitSourceLineComments: false)).emit(workflows: [workflow]).combined
        guard let replanRange = out.range(of: "replanAfterFailures: 3,"),
              let outputKindRange = out.range(of: "outputKind: \"text\",", range: replanRange.upperBound..<out.endIndex),
              let stepRange = out.range(of: "step:", range: outputKindRange.upperBound..<out.endIndex) else {
            Issue.record("expected replanAfterFailures: then outputKind: then step: in:\n\(out)")
            return
        }
        #expect(replanRange.lowerBound < outputKindRange.lowerBound)
        #expect(outputKindRange.lowerBound < stepRange.lowerBound)
    }

    @Test("use judgment to follow the <heading> guidance: threads AST guidance through IR and codegen")
    func judgmentFollowGuidanceThreadsThroughFullPipeline() throws {
        let symbols = SymbolTable()
        let ast = try MeridianParser(symbols: symbols).parse("""
        To run diagnostics:
          use judgment to follow the Diagnostics guidance:
            Check the golden path first.

            Then check the fallback path.
        """)

        let workflows = try ASTToIR(symbols: symbols, sourceFile: "test.meridian", engine: DiagnosticEngine()).lower(ast)
        guard case .aiJudgment(let step) = workflows[0].body.statements.first else {
            Issue.record("Expected AIJudgmentIR")
            return
        }
        #expect(step.text == "follow the Diagnostics guidance")
        #expect(step.guidance == "Check the golden path first\nThen check the fallback path")

        let out = try SwiftEmitter(options: .init(emitSourceLineComments: false)).emit(workflows: workflows).combined
        #expect(out.contains("guidance: \"Check the golden path first\\nThen check the fallback path\""))
    }
}
