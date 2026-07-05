import Testing
import Foundation
@testable import MeridianCore
import MeridianRuntime

/// Direct `ConventionInjector` coverage for every `RulebookPhase` placement
/// arm and the match/skip edges the gbrain corpus does not hit in isolation.
@Suite("ConventionInjector — direct coverage")
struct ConventionInjectorCoverageTests {

    private func injector(
        lowerBody: @escaping (String, Int) throws -> [IRPrimitive] = { _, _ in
            [.complete(CompleteIR(reason: "injected"))]
        }
    ) -> ConventionInjector {
        ConventionInjector(lexicon: .default, trace: .silent(), lowerBody: lowerBody)
    }

    private func matchingWorkflow(body: [IRPrimitive] = [.complete(CompleteIR())]) -> IRWorkflow {
        IRWorkflow(
            name: "write a page that mentions an entity",
            parameters: [
                IRParameter(name: "page", kind: KindRef("page")),
                IRParameter(name: "entity", kind: KindRef("entity")),
            ],
            body: IRBlock(statements: body)
        )
    }

    private func convention(
        phase: RulebookPhase,
        action: String = "writing a page that mentions an entity",
        body: String = "complete."
    ) -> RulebookRule {
        RulebookRule(
            phase: phase,
            action: action,
            body: body,
            outcome: .continueRulebook,
            sourceLine: 3
        )
    }

    @Test("an empty convention list is a no-op")
    func emptyConventionsNoOp() throws {
        let wf = matchingWorkflow()
        let out = try injector().inject(conventions: [], into: [wf])
        #expect(out.count == 1)
        #expect(out[0].body.statements.count == wf.body.statements.count)
    }

    @Test("before and check phases prepend lowered primitives")
    func prependPhases() throws {
        let wf = matchingWorkflow()
        for phase in [RulebookPhase.before, .check] {
            let out = try injector().inject(conventions: [convention(phase: phase)], into: [wf])
            guard case .complete(let c) = out[0].body.statements.first,
                  case .complete = out[0].body.statements.last else {
                Issue.record("expected injected complete prepended for \(phase)"); return
            }
            #expect(c.reason == "injected")
        }
    }

    @Test("after, report, and carry-out phases append lowered primitives")
    func appendPhases() throws {
        let wf = matchingWorkflow()
        for phase in [RulebookPhase.after, .report, .carryOut] {
            let out = try injector().inject(conventions: [convention(phase: phase)], into: [wf])
            guard case .complete = out[0].body.statements.first,
                  case .complete(let c) = out[0].body.statements.last else {
                Issue.record("expected injected complete appended for \(phase)"); return
            }
            #expect(c.reason == "injected")
        }
    }

    @Test("instead phase replaces the workflow body")
    func insteadReplacesBody() throws {
        let wf = matchingWorkflow(body: [.complete(CompleteIR(reason: "original"))])
        let out = try injector().inject(conventions: [convention(phase: .instead)], into: [wf])
        #expect(out[0].body.statements.count == 1)
        guard case .complete(let c) = out[0].body.statements.first else {
            Issue.record("expected replaced body"); return
        }
        #expect(c.reason == "injected")
    }

    @Test("an empty lowered body skips injection")
    func emptyLoweredBodySkips() throws {
        let wf = matchingWorkflow()
        let inj = injector(lowerBody: { _, _ in [] })
        let out = try inj.inject(conventions: [convention(phase: .before)], into: [wf])
        #expect(out[0].body.statements.count == 1)
    }

    @Test("conventions do not attach when action overlap is below the threshold")
    func weakActionMatchSkips() throws {
        let wf = IRWorkflow(name: "run", parameters: [], body: IRBlock(statements: [.complete(CompleteIR())]))
        let out = try injector().inject(
            conventions: [convention(phase: .after, action: "writing a page that mentions an entity")],
            into: [wf]
        )
        #expect(out[0].body.statements.count == 1)
    }

    @Test("full compile injects rulebook conventions into matching workflows")
    func compileInjectsConventions() throws {
        let rules = """
        === conventions ===
        after writing a page that mentions an entity:
          complete with reason "convention".
        """
        let mer = """
        ---
        vocabulary: t.merconfig
        rulebooks: brain.merrules
        ---

        To write a page that mentions an entity:
          complete with reason "workflow".
        """
        let cfg = """
        === vocabulary ===
        page is a kind of thing.
        entity is a kind of thing.
        """
        let swift = try Compiler(options: .init()).compile(
            meridianSource: mer,
            meridianFile: "t.meridian",
            vocabularies: [Compiler.VocabularyInput(name: "t", file: "t.merconfig", source: cfg)],
            rulebooks: [RulebookInput(name: "brain", file: "brain.merrules", source: rules)]
        )
        #expect(swift.contains("convention"))
    }
}
