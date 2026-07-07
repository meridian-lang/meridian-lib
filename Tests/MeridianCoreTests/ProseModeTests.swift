import Testing
@testable import MeridianCore

@Suite("Prose mode")
struct ProseModeTests {

    @Test("unmatched line in discretion workflow lowers to AIJudgmentIR")
    func discretionUnmatchedLineBecomesProseStep() throws {
        let symbols = SymbolTable()
        let ast = try MeridianParser(symbols: symbols, trace: .silent()).parse("""
        To babysit, with discretion:
          inspect the diff and leave only useful comments.
        """)

        let workflows = try ASTToIR(symbols: symbols, sourceFile: "test.meridian", trace: .silent()).lower(ast)
        guard case .aiJudgment(let step) = workflows[0].body.statements.first else {
            Issue.record("Expected AIJudgmentIR")
            return
        }
        #expect(step.text == "inspect the diff and leave only useful comments")
    }

    @Test("unmatched line outside discretion still raises a semantic error")
    func strictUnmatchedLineStillErrors() throws {
        let symbols = SymbolTable()
        let ast = try MeridianParser(symbols: symbols, trace: .silent()).parse("""
        To babysit:
          inspect the diff and leave only useful comments.
        """)

        #expect(throws: CompilerError.self) {
            _ = try ASTToIR(symbols: symbols, sourceFile: "test.meridian", trace: .silent()).lower(ast)
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

        let out = SwiftEmitter(options: .init(emitSourceLineComments: false)).emitFile(workflows: [workflow])
        #expect(out.contains("runtime.executeProsePlan"))
        #expect(out.contains("github.comment"))
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

        let out = SwiftEmitter(options: .init(emitSourceLineComments: false)).emitFile(workflows: [workflow])
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

        let out = SwiftEmitter(options: .init(emitSourceLineComments: false)).emitFile(workflows: [workflow])
        #expect(out.contains("runtime.executeAutonomousLoop"))
        #expect(out.contains("replanAfterFailures: 3,"))
        #expect(out.contains("guidance: \"Repair every missing back-link.\""))
    }

    @Test("use judgment to follow the <heading> guidance: threads AST guidance through IR and codegen")
    func judgmentFollowGuidanceThreadsThroughFullPipeline() throws {
        let symbols = SymbolTable()
        let ast = try MeridianParser(symbols: symbols, trace: .silent()).parse("""
        To run diagnostics:
          use judgment to follow the Diagnostics guidance:
            Check the golden path first.

            Then check the fallback path.
        """)

        let workflows = try ASTToIR(symbols: symbols, sourceFile: "test.meridian", trace: .silent()).lower(ast)
        guard case .aiJudgment(let step) = workflows[0].body.statements.first else {
            Issue.record("Expected AIJudgmentIR")
            return
        }
        #expect(step.text == "follow the Diagnostics guidance")
        #expect(step.guidance == "Check the golden path first\nThen check the fallback path")

        let out = SwiftEmitter(options: .init(emitSourceLineComments: false)).emitFile(workflows: workflows)
        #expect(out.contains("guidance: \"Check the golden path first\\nThen check the fallback path\""))
    }
}
