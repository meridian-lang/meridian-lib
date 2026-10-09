import Foundation
import MeridianRuntime
import Testing
@testable import MeridianCore

@Suite("Wave 7 verbalizer generative")
struct VerbalizerGenerativeTests {
    private let seed: UInt64 = 0x5EED_7007

    @Test("seeded generated expressions verbalize and reparse structurally")
    func generatedExpressionsRoundTrip() throws {
        var rng = SeededGenerator(seed: seed)
        var failures: [String] = []

        for index in 0..<64 {
            let expression = generatedExpression(rng: &rng, depth: 0)
            let surface = verbalizer().verbalize(expression)
            do {
                let reparsed = try parseBoundExpression(surface, file: "generated-expression-\(index).meri")
                if !IREquality.structurallyEqual(expression, reparsed) {
                    failures.append("seed \(seed), expression \(index): \(surface)\nexpected \(expression)\ngot \(reparsed)")
                }
            } catch {
                failures.append("seed \(seed), expression \(index): \(surface)\n\(error)")
            }
        }

        #expect(failures.isEmpty, Comment(rawValue: "Generated expression failures:\n" + failures.joined(separator: "\n\n")))
    }

    @Test("seeded generated primitives verbalize and reparse structurally")
    func generatedPrimitivesRoundTrip() throws {
        var rng = SeededGenerator(seed: seed ^ 0x00AB_CDEF)
        var failures: [String] = []

        for index in 0..<48 {
            let primitive = generatedPrimitive(rng: &rng)
            let surface = verbalizer().verbalize(primitive)
            do {
                let reparsed = try parsePrimitiveSurface(surface, expected: primitive, file: "generated-primitive-\(index).meri")
                if !generativePrimitivesEqual(primitive, reparsed) {
                    failures.append("seed \(seed), primitive \(index):\n\(surface)\nexpected \(primitive)\ngot \(reparsed)")
                }
            } catch {
                failures.append("seed \(seed), primitive \(index):\n\(surface)\n\(error)")
            }
        }

        #expect(failures.isEmpty, Comment(rawValue: "Generated primitive failures:\n" + failures.joined(separator: "\n\n")))
    }

    @Test("generated and seeded surfaces hit every GrammarTable production marker")
    func generatedProductionCoverage() {
        let generatedSurfaces = generatedCoverageSurfaces()
        let hits = productionHits(in: generatedSurfaces)
        let expected = Set(PegexSurfaceGrammar(lexicon: .default).table.productions.map(\.name))
        let missing = expected.subtracting(hits).sorted()
        #expect(missing.isEmpty, Comment(rawValue: "Missing generated production marker hits: \(missing.joined(separator: ", "))"))
    }

    private func generatedExpression(rng: inout SeededGenerator, depth: Int) -> IRExpression {
        if depth >= 2 {
            return terminalExpression(rng: &rng)
        }
        switch rng.nextInt(upperBound: 5) {
        case 0:
            return terminalExpression(rng: &rng)
        case 1:
            return .propertyAccess(.identifierRef(name: "page"), propertyName: "summary")
        case 2:
            return .comparison(terminalExpression(rng: &rng), comparisonOp(rng: &rng), terminalExpression(rng: &rng))
        case 3:
            return .logical(.and, [
                .comparison(.identifierRef(name: "score"), .greaterOrEqual, .literal(.number(1))),
                .comparison(.identifierRef(name: "score"), .lessOrEqual, .literal(.number(5))),
            ])
        default:
            return .logical(.not, [.comparison(.identifierRef(name: "score"), .equal, .literal(.number(0)))])
        }
    }

    private func terminalExpression(rng: inout SeededGenerator) -> IRExpression {
        switch rng.nextInt(upperBound: 4) {
        case 0:
            return .literal(.number(Decimal(rng.nextInt(upperBound: 10))))
        case 1:
            return .literal(.string("value-\(rng.nextInt(upperBound: 5))"))
        case 2:
            return .literal(.boolean(rng.nextInt(upperBound: 2) == 0))
        default:
            return .identifierRef(name: rng.nextInt(upperBound: 2) == 0 ? "score" : "status")
        }
    }

    private func comparisonOp(rng: inout SeededGenerator) -> ComparisonOp {
        switch rng.nextInt(upperBound: 6) {
        case 0: return .equal
        case 1: return .notEqual
        case 2: return .lessThan
        case 3: return .lessOrEqual
        case 4: return .greaterThan
        default: return .greaterOrEqual
        }
    }

    private func generatedPrimitive(rng: inout SeededGenerator) -> IRPrimitive {
        let condition = IRExpression.comparison(.identifierRef(name: "score"), .greaterOrEqual, .literal(.number(1)))
        let done = IRBlock(statements: [.complete(CompleteIR(reason: "done"))])
        switch rng.nextInt(upperBound: 15) {
        case 0:
            return .bind(BindIR(name: "score", expression: .literal(.number(Decimal(rng.nextInt(upperBound: 9) + 1)))))
        case 1:
            return .bind(BindIR(name: "score", expression: .literal(.number(2)), isRebind: true))
        case 2:
            return .invoke(InvokeIR(toolID: "demoTool", arguments: [InvokeArg("value", .literal(.number(1)))]))
        case 3:
            return .branch(BranchIR(condition: .predicate(condition), thenBlock: done, elseBlock: IRBlock(statements: [.complete(CompleteIR(reason: "skip"))])))
        case 4:
            // Match-branch stays single-statement when otherwise is empty.
            return .branch(BranchIR(
                condition: .match(.identifierRef(name: "choice"), [
                    BranchCase(pattern: .literal(.string("yes")), block: done),
                    BranchCase(pattern: .wildcard, block: done),
                ]),
                thenBlock: IRBlock(statements: [])
            ))
        case 5:
            return .iterate(IterateIR(mode: .whileCondition(condition), body: done))
        case 6:
            return .assert(AssertIR(condition: condition, message: "Expected \(verbalizer().verbalize(condition))"))
        case 7:
            return .emit(EmitIR(eventID: "generated.event", payload: [EmitField("score", .identifierRef(name: "score"))]))
        case 8:
            return .wait(WaitIR(condition: .duration(.seconds(Int64(rng.nextInt(upperBound: 5) + 1)))))
        case 9:
            return .commit(CommitIR(label: "checkpoint-\(rng.nextInt(upperBound: 5))"))
        case 10:
            return .recover(RecoverIR(
                pattern: .named("demo.failure"),
                handler: done,
                attachedTo: IRBlock(statements: [
                    .invoke(InvokeIR(toolID: "demoTool", arguments: [InvokeArg("value", .literal(.number(1)))]))
                ])
            ))
        case 11:
            return .simultaneously(SimultaneouslyIR(branches: [done], detached: true))
        case 12:
            // Guidance folds into `text` on reparse; keep a single-line goal so
            // SEM-8-03 structural equality (via IREquality AI normalization) holds.
            return .aiJudgment(AIJudgmentIR(text: "decide next step"))
        case 13:
            return .aiAutonomy(AIAutonomyIR(
                text: "repair failures",
                autonomy: AutonomyConfigIR(replanAfterFailures: 2, maxSteps: 4)
            ))
        default:
            return .complete(CompleteIR(reason: "done"))
        }
    }

    private func parseBoundExpression(_ surface: String, file: String) throws -> IRExpression {
        let source = """
        ---
        vocabulary: test.merconfig
        ---
        To generated:
          bind generated value = \(surface).
        """
        let model = try VerbalizerTestSupport.compiler().compile(Compiler.CompilationUnit(sources: [Compiler.SourceInput(source: source, file: file)], vocabularies: [VerbalizerTestSupport.baseVocabInput()]))[file]!.model
        guard case .bind(let bind) = model.workflows.first?.body.statements.first else {
            throw GeneratedFailure(message: "expected a bind for \(surface)")
        }
        return bind.expression
    }

    private func parsePrimitiveSurface(_ surface: String, expected: IRPrimitive, file: String) throws -> IRPrimitive {
        let indented = surface.split(separator: "\n", omittingEmptySubsequences: false)
            .map { "  \($0)" }
            .joined(separator: "\n")
        let source = """
        ---
        vocabulary: test.merconfig
        ---
        To generated:
        \(indented)
        """
        let model = try VerbalizerTestSupport.compiler().compile(Compiler.CompilationUnit(sources: [Compiler.SourceInput(source: source, file: file)], vocabularies: [VerbalizerTestSupport.baseVocabInput()]))[file]!.model
        guard let statements = model.workflows.first?.body.statements, !statements.isEmpty else {
            throw GeneratedFailure(message: "expected statements for:\n\(surface)")
        }
        // Single-line primitives must stay a single statement. Multi-line
        // recover / AI / simultaneously surfaces may lower to one primary
        // statement of the same kind (recover attaches prior invokes).
        if !surface.contains("\n") {
            guard statements.count == 1, let primitive = statements.first else {
                throw GeneratedFailure(message: "expected exactly one primitive for:\n\(surface)")
            }
            return primitive
        }
        if let match = statements.first(where: { matchesKind($0, expected) }) {
            return match
        }
        throw GeneratedFailure(message: "missing \(kindName(expected)) in:\n\(surface)\nstatements: \(statements)")
    }

    /// Generative AI primitives ignore `scopedTools` (the base vocab injects
    /// every tool into AI steps on reparse). Compare text/config with tools
    /// cleared so SEM-8-03 still holds for the verbalized surface.
    private func generativePrimitivesEqual(_ expected: IRPrimitive, _ actual: IRPrimitive) -> Bool {
        switch (expected, actual) {
        case (.aiJudgment(let lhs), .aiJudgment(let rhs)):
            return IREquality.structurallyEqual(
                .aiJudgment(AIJudgmentIR(text: lhs.text, snapshotKeys: lhs.snapshotKeys, guidance: lhs.guidance)),
                .aiJudgment(AIJudgmentIR(text: rhs.text, snapshotKeys: rhs.snapshotKeys, guidance: rhs.guidance))
            )
        case (.aiAutonomy(let lhs), .aiAutonomy(let rhs)):
            return IREquality.structurallyEqual(
                .aiAutonomy(AIAutonomyIR(text: lhs.text, snapshotKeys: lhs.snapshotKeys, autonomy: lhs.autonomy, guidance: lhs.guidance)),
                .aiAutonomy(AIAutonomyIR(text: rhs.text, snapshotKeys: rhs.snapshotKeys, autonomy: rhs.autonomy, guidance: rhs.guidance))
            )
        default:
            return IREquality.structurallyEqual(expected, actual)
        }
    }

    private func matchesKind(_ candidate: IRPrimitive, _ expected: IRPrimitive) -> Bool {
        switch (candidate, expected) {
        case (.recover, .recover), (.simultaneously, .simultaneously),
             (.aiJudgment, .aiJudgment), (.aiAutonomy, .aiAutonomy),
             (.complete, .complete), (.commit, .commit), (.bind, .bind),
             (.invoke, .invoke), (.branch, .branch), (.iterate, .iterate),
             (.assert, .assert), (.emit, .emit), (.wait, .wait):
            return true
        default:
            return false
        }
    }

    private func kindName(_ primitive: IRPrimitive) -> String {
        switch primitive {
        case .bind: return "bind"
        case .invoke: return "invoke"
        case .branch: return "branch"
        case .iterate: return "iterate"
        case .assert: return "assert"
        case .emit: return "emit"
        case .wait: return "wait"
        case .commit: return "commit"
        case .recover: return "recover"
        case .simultaneously: return "simultaneously"
        case .aiJudgment: return "aiJudgment"
        case .aiAutonomy: return "aiAutonomy"
        case .complete: return "complete"
        }
    }

    private func verbalizer() -> Verbalizer {
        Verbalizer(model: VerbalizerModel(
            workflows: [],
            loweredDefinitions: [],
            inlineDefinitions: [],
            symbols: SymbolTable.build(
                from: try! MerConfigParser().parse(VerbalizerTestSupport.baseVocabulary, file: "test.merconfig"),
                sourceFile: "test.merconfig"
            ),
            lexicon: .default,
            sourceFileName: "generated.meri",
            authoredSource: ""
        ))
    }

    private func generatedCoverageSurfaces() -> [String] {
        [
            "\"literal\"",
            "the page's summary",
            "score equals 1",
            "score equals 1 and status equals \"open\"",
            "the page's last reviewed is within the last 7 seconds",
            "the page's summary is empty",
            "at least 2 pages whose status is \"published\" have a summary",
            "the number of pages whose status is \"draft\"",
            "the largest deal by amount",
            "the first 2 pages whose status is \"draft\" sorted by status, ascending",
            "the user owns the page",
            "the task assigned to the user",
            "the skill corresponding to the trigger phrase \"daily\" in the dispatch table",
            "[if score equals 1]one[otherwise]other[end if]",
            "[for each row in rows]{{ row }}[end for]",
            "{{ score as a integer }}",
            "after score equals 1, complete",
            "complete except when score equals 1",
            "try complete; if it fails recover",
            "complete only when score equals 1",
            // Wave 8 trace / statistical / compound-note surfaces. These mirror
            // the canonical examples on the matching `GrammarProduction`s; the
            // coverage checklist only substring-scans them (it does not parse).
            "the deploy step failed",
            "the deploy step has ever failed",
            "the deploy step failed within the last 7 days",
            "the deploy step failed at least 3 times within the last 7 days",
            "the deploy step failed 3 times in a row",
            "the service is healthy since the last deploy step succeeded",
            "across all runs, the deploy step has ever failed",
            "the fetch step succeeds in at least 95% of runs, checked every 1 days",
            "proceed, and note \"thin history\" in the receipt trailer",
        ]
    }

    private func productionHits(in surfaces: [String]) -> Set<String> {
        var hits: Set<String> = []
        for surface in surfaces.map({ $0.lowercased() }) {
            if surface.contains("\"") || surface.contains("true") || surface.contains("false") { hits.insert("literal-atom") }
            if surface.contains("'s") { hits.insert("possessive-chain") }
            if surface.contains(" equals ") || surface.contains(" is at least ") || surface.contains(" is within ") { hits.insert("comparison") }
            if surface.contains(" and ") || surface.hasPrefix("not ") || surface.hasPrefix("either ") { hits.insert("boolean") }
            if surface.contains("within the last") || surface.contains("in the next") { hits.insert("temporal-window") }
            if surface.contains(" is empty") || surface.contains(" has no ") { hits.insert("emptiness") }
            if surface.hasPrefix("all ") || surface.hasPrefix("any ") || surface.hasPrefix("no ") || surface.hasPrefix("at least ") { hits.insert("quantifier") }
            if surface.contains("the number of") || surface.contains("the list of") { hits.insert("aggregate") }
            if surface.contains("largest ") || surface.contains("smallest ") || surface.contains("oldest ") { hits.insert("superlative") }
            if surface.contains(" whose ") || surface.contains(" sorted by ") || surface.contains("the first ") { hits.insert("description") }
            if surface.contains(" owns ") { hits.insert("active-verb") }
            if surface.contains(" assigned to ") { hits.insert("scalar-navigation") }
            if surface.contains(" corresponding to ") && surface.contains(" in the ") { hits.insert("table-lookup") }
            if surface.contains("[if ") && surface.contains("[end if]") { hits.insert("template-conditional") }
            if surface.contains("[for each ") && surface.contains("[end for]") { hits.insert("template-loop") }
            if surface.contains(" as a ") { hits.insert("template-formatter") }
            if surface.hasPrefix("after ") { hits.insert("after-idiom") }
            if surface.contains(" except when ") { hits.insert("except-when-idiom") }
            if surface.hasPrefix("try ") && surface.contains("if it fails") { hits.insert("try-recover-idiom") }
            if surface.contains(" only when ") { hits.insert("suffix-conditional") }
            // Wave 8 trace / statistical / compound-note markers.
            if surface.contains(" step failed") || surface.contains(" step succeeded") { hits.insert("trace-event-pattern") }
            if surface.contains("across all runs") { hits.insert("trace-scope-marker") }
            if surface.contains("has ever ") { hits.insert("trace-temporal-ever") }
            if surface.contains("times within the last") { hits.insert("trace-temporal-count") }
            if surface.contains("within the last") && surface.contains(" step ") && !surface.contains("times within") { hits.insert("trace-temporal-window") }
            if surface.contains(" in a row") { hits.insert("trace-temporal-in-a-row") }
            if surface.contains("since the last") { hits.insert("trace-temporal-since") }
            if surface.contains("% of runs") || surface.contains("% of occurrences") || surface.contains("checked every") { hits.insert("trace-statistical-frequency") }
            if surface.contains("proceed, and note") { hits.insert("compound-note") }
        }
        return hits
    }

    private struct SeededGenerator {
        private var state: UInt64

        init(seed: UInt64) {
            self.state = seed
        }

        mutating func nextInt(upperBound: Int) -> Int {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return Int(state % UInt64(upperBound))
        }
    }

    private struct GeneratedFailure: Error, CustomStringConvertible {
        let message: String
        var description: String { message }
    }
}
