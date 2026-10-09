import Testing
@testable import MeridianCore

// the generic `IRPrimitive.proseStep(ProseStepIR)` primitive was
// replaced by two explicit AI-routed primitives — `aiJudgment(AIJudgmentIR)`
// and `aiAutonomy(AIAutonomyIR)` — because judgment and autonomy are handled
// differently by the runtime/codegen and should be auditable separately. This
// suite is the acceptance contract for that split: every surface form that
// used to lower to a generic prose step now lowers to the correct explicit
// primitive, with the matching runtime call and manifest shape.

@Suite("AI primitive split — judgment vs autonomy")
struct AIPrimitiveSplitTests {

    // MARK: - Lowering: which surface forms produce which primitive

    @Test("`use judgment to …:` lowers to IRPrimitive.aiJudgment")
    func useJudgmentLowersToAIJudgment() throws {
        let symbols = SymbolTable()
        let ast = try MeridianParser(symbols: symbols).parse("""
        To triage:
          use judgment to classify the incident:
            Look at severity and blast radius.
        """)
        let workflows = try ASTToIR(symbols: symbols, sourceFile: "test.meridian", engine: DiagnosticEngine()).lower(ast)
        guard case .aiJudgment(let step) = workflows[0].body.statements.first else {
            Issue.record("Expected IRPrimitive.aiJudgment")
            return
        }
        #expect(step.text.contains("classify the incident"))
    }

    @Test("inherited `with discretion` workflow prose lowers to IRPrimitive.aiJudgment")
    func inheritedDiscretionLowersToAIJudgment() throws {
        let symbols = SymbolTable()
        let ast = try MeridianParser(symbols: symbols).parse("""
        To babysit, with discretion:
          inspect the diff and leave only useful comments.
        """)
        let workflows = try ASTToIR(symbols: symbols, sourceFile: "test.meridian", engine: DiagnosticEngine()).lower(ast)
        guard case .aiJudgment = workflows[0].body.statements.first else {
            Issue.record("Expected IRPrimitive.aiJudgment")
            return
        }
    }

    @Test("`with autonomy …:` lowers to IRPrimitive.aiAutonomy carrying AutonomyConfigIR")
    func withAutonomyLowersToAIAutonomy() throws {
        let symbols = SymbolTable()
        let ast = try MeridianParser(symbols: symbols).parse("""
        To stabilize, with autonomy until ci is passed re-plan after 2 failures:
          keep fixing the smallest failing thing.
        """)
        let workflows = try ASTToIR(symbols: symbols, sourceFile: "test.meridian", engine: DiagnosticEngine()).lower(ast)
        guard case .aiAutonomy(let step) = workflows[0].body.statements.first else {
            Issue.record("Expected IRPrimitive.aiAutonomy")
            return
        }
        #expect(step.autonomy.until != nil)
        #expect(step.autonomy.replanAfterFailures == 2)
    }

    @Test("inherited `with autonomy` workflow prose lowers to IRPrimitive.aiAutonomy")
    func inheritedAutonomyLowersToAIAutonomy() throws {
        let symbols = SymbolTable()
        let ast = try MeridianParser(symbols: symbols).parse("""
        To stabilize, with autonomy re-plan after 2 failures:
          keep fixing the smallest failing thing.
        """)
        let workflows = try ASTToIR(symbols: symbols, sourceFile: "test.meridian", engine: DiagnosticEngine()).lower(ast)
        guard case .aiAutonomy(let step) = workflows[0].body.statements.first else {
            Issue.record("Expected IRPrimitive.aiAutonomy")
            return
        }
        #expect(step.autonomy.replanAfterFailures == 2)
    }

    @Test("ai-discretion fuzzy table lowers to IRPrimitive.aiJudgment")
    func aiDiscretionTableLowersToAIJudgment() throws {
        let symbols = SymbolTable()
        let ast = try MeridianParser(symbols: symbols).parse("""
        To triage:
          !!! table (( ai-discretion ))
          | Condition | Action |
          |---|---|
          | user asks for research | spawn a research subagent |
        """)
        let workflows = try ASTToIR(symbols: symbols, sourceFile: "test.meridian", engine: DiagnosticEngine()).lower(ast)
        guard case .aiJudgment = workflows[0].body.statements.first else {
            Issue.record("Expected IRPrimitive.aiJudgment")
            return
        }
    }

    @Test("ai-autonomy fuzzy checklist lowers to IRPrimitive.aiAutonomy")
    func aiAutonomyChecklistLowersToAIAutonomy() throws {
        let symbols = SymbolTable()
        let ast = try MeridianParser(symbols: symbols).parse("""
        To audit:
          !!! checklist (( ai-autonomy ))
          - [ ] all entity pages are cross-linked
          - [ ] no DRY violations across skills
        """)
        let workflows = try ASTToIR(symbols: symbols, sourceFile: "test.meridian", engine: DiagnosticEngine()).lower(ast)
        guard case .aiAutonomy = workflows[0].body.statements.first else {
            Issue.record("Expected IRPrimitive.aiAutonomy")
            return
        }
    }

    // MARK: - Codegen: each primitive calls the matching runtime API only

    @Test("aiJudgment codegen calls executeProsePlan, never executeAutonomousLoop")
    func judgmentCodegenCallsExecuteProsePlan() throws {
        let workflow = IRWorkflow(
            name: "Demo", parameters: [],
            body: IRBlock(statements: [.aiJudgment(AIJudgmentIR(text: "decide"))])
        )
        let out = try SwiftEmitter(options: .init(emitSourceLineComments: false)).emit(workflows: [workflow]).combined
        #expect(out.contains("runtime.executeProsePlan"))
        #expect(!out.contains("runtime.executeAutonomousLoop"))
    }

    @Test("aiAutonomy codegen calls executeAutonomousLoop, never executeProsePlan")
    func autonomyCodegenCallsExecuteAutonomousLoop() throws {
        let workflow = IRWorkflow(
            name: "Demo", parameters: [],
            body: IRBlock(statements: [.aiAutonomy(AIAutonomyIR(text: "keep fixing"))])
        )
        let out = try SwiftEmitter(options: .init(emitSourceLineComments: false)).emit(workflows: [workflow]).combined
        #expect(out.contains("runtime.executeAutonomousLoop"))
        #expect(!out.contains("runtime.executeProsePlan"))
    }

    // MARK: - Manifest: judgment/autonomy are separately auditable

    @Test("manifest exposes judgment_steps and autonomy_steps as separate arrays, never a generic prose_steps/ai_steps key")
    func manifestSeparatesJudgmentAndAutonomy() throws {
        let workflow = IRWorkflow(
            name: "do both", parameters: [],
            body: IRBlock(statements: [
                .aiJudgment(AIJudgmentIR(text: "decide what to do")),
                .aiAutonomy(AIAutonomyIR(text: "keep fixing", autonomy: AutonomyConfigIR(maxSteps: 4))),
            ])
        )
        let json = try ManifestEmitter().emit(ManifestEmitter.Input(workflows: [workflow]))
        #expect(json.contains("judgment_steps"))
        #expect(json.contains("autonomy_steps"))
        #expect(!json.contains("prose_steps"))
        #expect(!json.contains("\"ai_steps\""))
    }

    // MARK: - Expression-level `decide whether …` is unaffected by the split

    @Test("expression-level `decide whether …` stays InvokeIR(toolID: runtime.discretion.decide), not folded into AIJudgmentIR")
    func decideWhetherStaysInlineInvocation() throws {
        let symbols = SymbolTable()
        let ast = try MeridianParser(symbols: symbols).parse("""
        To gate:
          bind should act = decide whether the request looks risky.
          complete.
        """)
        let workflows = try ASTToIR(symbols: symbols, sourceFile: "test.meridian", engine: DiagnosticEngine()).lower(ast)
        guard case .bind(let bind) = workflows[0].body.statements.first,
              case .invocation(let inv) = bind.expression else {
            Issue.record("Expected a bind whose expression is an inline InvokeIR")
            return
        }
        #expect(inv.toolID == "runtime.discretion.decide")
    }

    // MARK: - Primitive kind coverage

    @Test("IRPrimitiveKind has aiJudgment and aiAutonomy, and no generic proseStep")
    func primitiveKindSplit() {
        let raws = IRPrimitiveKind.allCases.map(\.rawValue)
        #expect(raws.contains("aiJudgment"))
        #expect(raws.contains("aiAutonomy"))
        #expect(!raws.contains("proseStep"))
    }
}
