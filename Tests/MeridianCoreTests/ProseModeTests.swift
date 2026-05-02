import Testing
@testable import MeridianCore

@Suite("Prose mode")
struct ProseModeTests {

    @Test("unmatched line in discretion workflow lowers to ProseStepIR")
    func discretionUnmatchedLineBecomesProseStep() throws {
        let symbols = SymbolTable()
        let ast = try MeridianParser(symbols: symbols, trace: .silent()).parse("""
        To babysit, with discretion:
          inspect the diff and leave only useful comments.
        """)

        let workflows = try ASTToIR(symbols: symbols, sourceFile: "test.meridian", trace: .silent()).lower(ast)
        guard case .proseStep(let step) = workflows[0].body.statements.first else {
            Issue.record("Expected ProseStepIR")
            return
        }
        #expect(step.text == "inspect the diff and leave only useful comments")
        #expect(step.dispatchMode == .planThenExecute)
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

    @Test("ProseStepIR emits runtime executeProsePlan call")
    func proseStepCodegen() throws {
        let workflow = IRWorkflow(
            name: "Demo",
            parameters: [],
            body: IRBlock(statements: [
                .proseStep(ProseStepIR(
                    text: "inspect the diff",
                    scopedTools: ["github.comment"],
                    dispatchMode: .planThenExecute
                ))
            ])
        )

        let out = SwiftEmitter(options: .init(emitSourceLineComments: false)).emitFile(workflows: [workflow])
        #expect(out.contains("runtime.executeProsePlan"))
        #expect(out.contains("github.comment"))
    }
}
