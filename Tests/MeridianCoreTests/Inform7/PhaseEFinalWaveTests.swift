import Foundation
import Testing
@testable import MeridianCore

@Suite("Phase E final wave closure")
struct PhaseEFinalWaveTests {
    @Test("SEM unknown-handling sugar `treating unknown as true` lowers policy")
    func unknownHandlingAsTrue() throws {
        let workflow = try loweredWorkflow(
            mer: """
            To inspect traces:
              if the deploy step has ever failed treating unknown as true,
                complete.
              otherwise,
                complete.
            """,
            cfg: ""
        )
        guard case .branch(let branch) = workflow.body.statements.first else {
            Issue.record("expected branch")
            return
        }
        #expect(branch.unknownPolicy == .asTrue)
        #expect(branch.unknownBlock == nil)
    }

    @Test("SEM unknown-handling sugar verbalizes on round-trip")
    func unknownHandlingVerbalizerRoundTrip() throws {
        let workflow = try loweredWorkflow(
            mer: """
            To inspect traces:
              if the deploy step has ever failed treating unknown as false,
                complete.
              otherwise,
                complete.
            """,
            cfg: ""
        )
        let text = try Verbalizer(model: VerbalizerModel(
            workflows: [workflow],
            loweredDefinitions: [],
            inlineDefinitions: [],
            symbols: SymbolTable(trace: .silent()),
            lexicon: .default,
            sourceFileName: "t.meridian",
            authoredSource: ""
        )).verbalize()
        #expect(text.contains("treating unknown as false"))
    }

    @Test("SEM_4_12 state-history since-last lowers when retention enabled")
    func sem412StateHistorySinceLast() throws {
        let cfg = """
        === trace ===
        state history: enabled
        === vocabulary ===
        A service is a kind of thing.
        A service has a text called the status.
        """
        let workflow = try loweredWorkflow(
            mer: """
            To inspect a service:
              if the status is "healthy" since the last deploy step succeeded,
                complete.
              if it is unknown whether:
                complete.
              otherwise,
                complete.
            """,
            cfg: cfg
        )
        guard let temporal = firstTraceTemporal(in: workflow.body) else {
            Issue.record("expected temporal branch")
            return
        }
        guard case .sinceLast(_, _, let holdsPattern, let usesStateHistory) = temporal.kind else {
            Issue.record("expected sinceLast kind")
            return
        }
        #expect(usesStateHistory)
        #expect(holdsPattern == nil)
    }

    @Test("SEM_5_12 bounded future monitor lowers in assert context")
    func sem512BoundedFutureInAssert() throws {
        let workflow = try loweredWorkflow(
            mer: """
            To inspect traces:
              assert eventually within 5 minutes, the deploy step has ever succeeded.
            """,
            cfg: ""
        )
        guard case .assert(let assertion) = workflow.body.statements.first else {
            Issue.record("expected assert")
            return
        }
        guard case .traceTemporal(let temporal) = assertion.condition else {
            Issue.record("expected temporal assert condition")
            return
        }
        guard case .boundedFutureMonitor(_, let horizon, let mode) = temporal.kind else {
            Issue.record("expected bounded future monitor")
            return
        }
        #expect(mode == .eventuallyWithin)
        #expect(horizon == .seconds(300))
    }

    @Test("SEM_5_12 bounded future monitor rejected in branch predicate")
    func sem512BoundedFutureRejectedInBranch() throws {
        try expectDiagnostic(
            mer: """
            To inspect traces:
              if eventually within 5 minutes, the deploy step has ever succeeded,
                complete.
            """,
            cfg: "",
            code: .traceFuture
        )
    }

    @Test("SEM_2_13 calendar amount literals parse via lexicon grammar units")
    func sem213CalendarAmountSurfaceParsing() throws {
        let workflow = try loweredWorkflow(
            mer: """
            To inspect timing:
              let the grace period be 3 calendar days.
            """,
            cfg: ""
        )
        guard case .bind(let bind) = workflow.body.statements.first else {
            Issue.record("expected bind")
            return
        }
        guard case .literal(.calendarAmount(let amount)) = bind.expression else {
            Issue.record("expected calendar amount literal")
            return
        }
        #expect(amount.magnitude == 3)
        #expect(amount.unit == .calendarDays)
    }

    private func loweredWorkflow(mer: String, cfg: String) throws -> IRWorkflow {
        let config = try MerConfigParser(trace: .silent()).parse(cfg, file: "t.merconfig")
        let symbols = SymbolTable.build(from: config, sourceFile: "t.merconfig", trace: .silent())
        let file = try MeridianParser(symbols: symbols, trace: .silent()).parse(mer, file: "t.meridian")
        guard let workflow = try ASTToIR(symbols: symbols, sourceFile: "t.meridian", trace: .silent()).lower(file).first else {
            throw CompilerError.codegenError(message: "expected lowered workflow")
        }
        return workflow
    }

    private func firstTraceTemporal(in block: IRBlock) -> TraceTemporalIR? {
        for statement in block.statements {
            if case .branch(let branch) = statement,
               case .predicate(let predicate) = branch.condition,
               case .traceTemporal(let temporal) = predicate {
                return temporal
            }
            if case .assert(let assertion) = statement,
               case .traceTemporal(let temporal) = assertion.condition {
                return temporal
            }
        }
        return nil
    }

    private func expectDiagnostic(mer: String, cfg: String, code: DiagnosticCode) throws {
        do {
            _ = try loweredWorkflow(mer: mer, cfg: cfg)
            Issue.record("expected \(code.id)")
        } catch let error as CompilerError {
            #expect(error.diagnostics.contains { $0.code == code },
                    Comment(rawValue: "expected \(code.id), got \(error.diagnostics.map { $0.code.id })"))
        }
    }
}
