import Foundation
import Testing
@testable import MeridianCore

@Suite("Wave 7 verbalizer totality")
struct VerbalizerTotalityTests {
    private func verbalizer() -> Verbalizer {
        Verbalizer(model: VerbalizerModel(
            workflows: [],
            loweredDefinitions: [],
            inlineDefinitions: [],
            symbols: SymbolTable(trace: .silent()),
            lexicon: .default,
            sourceFileName: "test.meridian",
            authoredSource: ""
        ))
    }

    @Test("all expression variants verbalize to text")
    func expressionTotality() {
        let v = verbalizer()
        let description = DescriptionIR(
            collection: .identifierRef(name: "pages"),
            elementVar: "page",
            filters: [.comparison(.propertyAccess(.identifierRef(name: "page"), propertyName: "summary"), .isNotEmpty, .literal(.boolean(true)))],
            sort: (path: "createdAt", ascending: true),
            take: 2
        )
        let quantifier = QuantifierIR(
            kind: .atLeast(1),
            description: description,
            body: .comparison(.identifierRef(name: "page"), .identifies, .identifierRef(name: "target"))
        )
        let expressions: [IRExpression] = [
            .literal(.string("hello")),
            .constantRef(name: "max score"),
            .identifierRef(name: "score"),
            .instanceRef(name: "primary mailer"),
            .propertyAccess(.identifierRef(name: "order"), propertyName: "score"),
            .relationTraversal(.identifierRef(name: "page"), relationName: "mentions", target: .identifierRef(name: "entity")),
            .comparison(.identifierRef(name: "score"), .greaterThan, .literal(.number(1))),
            .logical(.or, [.literal(.boolean(true)), .literal(.boolean(false))]),
            .envVar(name: "HOME"),
            .nowExpression,
            .invocation(InvokeIR(toolID: "runtime.discretion.decide", arguments: [InvokeArg("question", .literal(.string("continue"))) ])),
            .interpolatedString([
                .literal("hello "),
                .expression(.identifierRef(name: "name")),
                .conditional(condition: .literal(.boolean(true)), then: [.literal(" yes")], otherwise: [.literal(" no")]),
                .forEach(variable: "item", collection: .identifierRef(name: "items"), body: [.expression(.identifierRef(name: "item"))]),
                .formatted(.identifierRef(name: "score"), formatter: "integer"),
                .shellEscapedExpression(.identifierRef(name: "path")),
            ]),
            .recordList(fields: ["name"], rows: [[.literal(.string("Ada"))]]),
            .tableLookup(table: "routing", keyColumn: "trigger phrase", key: .literal(.string("daily")), valueColumn: "skill"),
            .definitionPredicate(functionName: "meridianDef_Page_stale", subject: .identifierRef(name: "page")),
            .quantified(quantifier),
            .description(description),
            .aggregate(.count, description),
            .superlative(SuperlativeIR(description: description, sortPath: "createdAt", ascending: false)),
            .eventPattern(EventPatternIR(subject: .step("deploy"), outcome: .failed)),
            .traceTemporal(TraceTemporalIR(scope: .currentRun, kind: .ever(EventPatternIR(subject: .step("deploy"), outcome: .failed)))),
            .traceTemporal(TraceTemporalIR(scope: .currentRun, kind: .withinWindow(EventPatternIR(subject: .step("deploy"), outcome: .failed), duration: .seconds(300)))),
            .traceTemporal(TraceTemporalIR(scope: .currentRun, kind: .countInWindow(EventPatternIR(subject: .step("deploy"), outcome: .failed), comparator: .atLeast(2), duration: .seconds(300)))),
            .traceTemporal(TraceTemporalIR(scope: .currentRun, kind: .inARow(EventPatternIR(subject: .step("deploy"), outcome: .failed), count: 2))),
            .traceTemporal(TraceTemporalIR(scope: .currentRun, kind: .sinceLast(anchor: EventPatternIR(subject: .step("deploy"), outcome: .succeeded), holds: .comparison(.identifierRef(name: "service"), .equal, .literal(.string("healthy"))), holdsPattern: EventPatternIR(subject: .step("deploy"), outcome: .failed)))),
            .traceStatistical(TraceStatisticalIR(
                scope: .currentRun,
                pattern: TraceStatisticalPatternIR(subject: .step("deploy")),
                outcome: .succeeds,
                bound: .atLeast(0.9),
                denominator: .runs,
                window: .seconds(300),
                monitorCadence: .seconds(60),
                blocking: true
            )),
        ]

        for expression in expressions {
            let text = v.verbalize(expression)
            #expect(!text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, Comment(rawValue: "\(expression)"))
        }
    }

    @Test("all primitive variants verbalize to text")
    func primitiveTotality() {
        let v = verbalizer()
        let condition = IRExpression.comparison(.identifierRef(name: "score"), .greaterOrEqual, .literal(.number(1)))
        let block = IRBlock(statements: [.complete(CompleteIR())])
        let primitives: [IRPrimitive] = [
            .invoke(InvokeIR(toolID: "shell.run", arguments: [InvokeArg("command", .interpolatedString([.literal("echo "), .expression(.identifierRef(name: "score"))]))], comment: "say score")),
            .bind(BindIR(name: "score", expression: .literal(.number(1)))),
            .branch(BranchIR(condition: .match(.identifierRef(name: "choice"), [
                BranchCase(pattern: .literal(.string("yes")), block: block),
                BranchCase(pattern: .enumValue("approved", kind: "Verdict"), block: block),
                BranchCase(pattern: .wildcard, block: block),
            ]), thenBlock: block)),
            .iterate(IterateIR(
                mode: .overCollection(parameter: "page", kind: KindRef("Page"), collection: .identifierRef(name: "pages")),
                body: block,
                source: IRIterationRefinement(filters: [condition], sort: (path: "createdAt", ascending: false), take: 2)
            )),
            .assert(AssertIR(condition: condition, message: "Expected score is at least 1", otherwiseAction: block)),
            .emit(EmitIR(eventID: "demo.event", payload: [EmitField("score", .identifierRef(name: "score"))], strict: true)),
            .wait(WaitIR(condition: .duration(.seconds(1)))),
            .commit(CommitIR(label: "after-score")),
            .recover(RecoverIR(pattern: .named("demo.failure"), handler: block, attachedTo: block)),
            .simultaneously(SimultaneouslyIR(branches: [block, IRBlock(statements: [.commit(CommitIR())])], detached: false)),
            .aiJudgment(AIJudgmentIR(text: "choose next action", scopedTools: ["shell.run"], guidance: "Prefer deterministic checks.")),
            .aiAutonomy(AIAutonomyIR(text: "repair failures", autonomy: AutonomyConfigIR(until: condition, replanAfterFailures: 2, maxSteps: 5))),
            .complete(CompleteIR(reason: "done")),
        ]

        for primitive in primitives {
            let text = v.verbalize(primitive)
            #expect(!text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, Comment(rawValue: "\(primitive)"))
        }
    }

    @Test("canonical forms source has no unfinished markers")
    func canonicalFormsSourceClean() throws {
        let source = try String(contentsOf: canonicalFormsURL(), encoding: .utf8)
        #expect(!source.contains("TODO"))
        #expect(!source.contains("FIXME"))
        #expect(!source.localizedCaseInsensitiveContains("placeholder"))
    }

    private func canonicalFormsURL() throws -> URL {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<8 {
            let candidate = url.appendingPathComponent("Sources/MeridianCore/Verbalizer/CanonicalForms.swift")
            if FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
            url.deleteLastPathComponent()
        }
        throw CompilerError.codegenError(message: "could not locate CanonicalForms.swift")
    }
}
