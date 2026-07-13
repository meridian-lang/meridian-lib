import Foundation
import Testing
@testable import MeridianCore
import MeridianRuntime

@Suite("Observability coverage closeout — core")
struct ObservabilityCoverageCloseoutTests {

    private func range(_ file: String = "t.meridian") -> SourceRange {
        SourceRange(file: file, startLine: 1, startColumn: 1, endLine: 1, endColumn: 5)
    }

    // MARK: - IRWalker.hasBlockingAssert

    @Test("hasBlockingAssert detects ordinary and blocking monitored asserts")
    func hasBlockingAssert() {
        let ordinary = IRWorkflow(name: "a", parameters: [], body: IRBlock(statements: [
            .assert(AssertIR(condition: .literal(.boolean(true)), monitored: false, blocking: false)),
        ]))
        let monitoredNonBlocking = IRWorkflow(name: "b", parameters: [], body: IRBlock(statements: [
            .assert(AssertIR(condition: .literal(.boolean(true)), monitored: true, cadence: .seconds(60), blocking: false)),
        ]))
        let blockingMonitor = IRWorkflow(name: "c", parameters: [], body: IRBlock(statements: [
            .assert(AssertIR(condition: .literal(.boolean(true)), monitored: true, cadence: .seconds(60), blocking: true)),
        ]))
        let benign = IRWorkflow(name: "d", parameters: [], body: IRBlock(statements: [
            .complete(CompleteIR(reason: nil)),
        ]))

        #expect(IRWalker.hasBlockingAssert(in: [ordinary]))
        #expect(!IRWalker.hasBlockingAssert(in: [monitoredNonBlocking]))
        #expect(IRWalker.hasBlockingAssert(in: [blockingMonitor]))
        #expect(!IRWalker.hasBlockingAssert(in: [benign]))
    }

    // MARK: - IRValidator trace + empty pattern subjects

    @Test("IRValidator rejects empty event-pattern and statistical-pattern subjects")
    func irValidatorEmptyPatternSubjects() {
        let emptyStep = validationDiagnostics(.eventPattern(
            EventPatternIR(subject: .step(" "), outcome: .succeeded)))
        #expect(emptyStep.contains { $0.message.contains("event pattern step subject is empty") })

        let emptyNamed = validationDiagnostics(.eventPattern(
            EventPatternIR(subject: .named(" "), outcome: .succeeded)))
        #expect(emptyNamed.contains { $0.message.contains("event pattern subject is empty") })

        let emptyStat = validationDiagnostics(.traceStatistical(TraceStatisticalIR(
            pattern: TraceStatisticalPatternIR(subject: .step(" ")),
            outcome: .succeeds,
            bound: .atLeast(0.9),
            denominator: .occurrences)))
        #expect(emptyStat.contains { $0.message.contains("statistical pattern subject is empty") })

        let predicateStat = validationDiagnostics(.traceStatistical(TraceStatisticalIR(
            pattern: TraceStatisticalPatternIR(
                subject: .step("deploy"),
                payloadPredicate: .propertyAccess(.identifierRef(name: "order"), propertyName: " ")),
            outcome: .succeeds,
            bound: .atLeast(0.9),
            denominator: .occurrences)))
        #expect(!predicateStat.isEmpty)
    }

    @Test("IRValidator closes validation spans when tracing is enabled")
    func irValidatorTraceFailureSpan() {
        let cap = ParserTrace.capturing(categories: [.validation])
        do {
            try IRValidator.validate(IRExpression.logical(.and, []), sourceFile: "invalid.ir", trace: cap.trace)
            Issue.record("expected invalidIR")
        } catch {
            // expected
        }
        let lines = cap.lines()
        #expect(lines.contains { $0.contains("validation") })
    }

    // MARK: - Diagnostic phase / related / remediation

    @Test("warning builder preserves phase and related ranges")
    func warningPhaseAndRelated() {
        let related = SourceRange(file: "cfg.merconfig", line: 2, column: 1)
        let warning = Diagnostic.warning(
            .swiftFormatFailed,
            message: "format failed",
            range: range(),
            help: "pass --no-format",
            phase: "codegen",
            relatedRanges: [related])
        #expect(warning.phase == "codegen")
        #expect(warning.relatedRanges == [related])
    }

    @Test("error builder keeps explicit help when suggestions are present")
    func errorExplicitHelpWithSuggestions() {
        let suggestion = Suggestion(replacement: "payment", range: range(), rationale: "did you mean")
        let diagnostic = Diagnostic.error(
            .unknownTool,
            message: "unknown tool",
            range: range(),
            suggestions: [suggestion],
            help: "pick a registered tool")
        #expect(diagnostic.help == "pick a registered tool")
    }

    @Test("note severity participates in ordering")
    func noteSeverityOrdering() {
        #expect(DiagnosticSeverity.note < .warning)
        #expect(DiagnosticSeverity.warning < .error)
        let note = DiagnosticNote("see declaration", range: range("cfg.merconfig"))
        #expect(note.message == "see declaration")
    }

    // MARK: - Suggester empty inputs

    @Test("closestAmbiguous ignores empty targets and blank candidates")
    func suggesterEmptyInputs() {
        let suggester = Suggester()
        #expect(suggester.closestAmbiguous("   ", among: ["payment"]) == nil)
        #expect(suggester.closestAmbiguous("paymnt", among: ["", "payment"])?.primary == "payment")
        #expect(suggester.ranked("target", among: ["", "alpha", "beta"]).count == 2)
        #expect(Suggester.levenshtein("", "") == 0)
        let tied = suggester.closestAmbiguous("foo", among: ["foe", "fog"])
        #expect(tied?.primary == "foe")
        #expect(tied?.alternates == ["fog"])
    }

    @Test("Diagnostic unresolved single-match path and remediated error without notes")
    func diagnosticBuilderEdgeCases() {
        let range = SourceRange(file: "t.meridian", line: 1, column: 1)
        let single = Diagnostic.unresolved(
            .unknownTool, target: "chargePaymnt", among: ["chargePayment"], range: range, noun: "tool")
        #expect(single.suggestions.count == 1)

        let withNote = Diagnostic.error(
            .unknownTool, message: "bad", range: range,
            notes: [DiagnosticNote("hint")], help: nil)
        #expect(withNote.help == nil)

        let withSuggestion = Diagnostic.error(
            .unknownTool, message: "bad", range: range,
            suggestions: [Suggestion(replacement: "x", range: range, rationale: "why")],
            help: nil)
        #expect(withSuggestion.help == nil)
    }

    @Test("ParserTrace env activation, jsonl ranges, and trace-file fallback")
    func parserTraceObservabilityPaths() {
        setenv("MERIDIAN_TRACE", "validation", 1)
        defer { unsetenv("MERIDIAN_TRACE") }
        let envTrace = ParserTrace()
        envTrace.log(ParserTrace.Category.validation, "from env")

        let jsonTrace = ParserTrace()
        jsonTrace.enable([.validation])
        jsonTrace.outputFormat = .jsonl
        let ranged = jsonTrace.openSpan(.validation, "with range",
                                        range: SourceRange(file: "t.meridian", line: 2, column: 3))
        jsonTrace.closeSpan(ranged, outcome: .success)

        let fileTrace = ParserTrace()
        fileTrace.enable([.validation])
        fileTrace.sink = .file(URL(fileURLWithPath: NSTemporaryDirectory()))
        fileTrace.log(.validation, "fallback probe")

        let mismatchTrace = ParserTrace()
        mismatchTrace.enable([.validation])
        let outer = mismatchTrace.openSpan(.validation, "outer")
        _ = mismatchTrace.openSpan(.validation, "inner")
        mismatchTrace.closeSpan(outer, outcome: .success)
    }

    @Test("EmptinessTemporalGrammar negated window comparisons strip trailing not")
    func emptinessTemporalNegatedWindow() {
        let grammar = EmptinessTemporalGrammar(lexicon: .default) { .identifierRef($0) }
        #expect(grammar.parse("service is not within the last 2 days") != nil)
    }

    @Test("Verbalizer quoted data cells and fractional statistical percentages")
    func verbalizerDataCellAndPercent() {
        let model = VerbalizerModel(
            workflows: [],
            loweredDefinitions: [],
            inlineDefinitions: [],
            symbols: SymbolTable(trace: .silent()),
            lexicon: .default,
            sourceFileName: "test.meri",
            authoredSource: "",
            metadata: nil,
            toolsUsed: [])
        let v = Verbalizer(model: model)
        let dataTable = v.verbalize(.bind(BindIR(
            name: "orders",
            expression: .recordList(
                fields: ["amount"],
                rows: [[.propertyAccess(.identifierRef(name: "order"), propertyName: "total")]])
        )))
        #expect(dataTable.contains("| \"the order's total\" |"), Comment(rawValue: dataTable))

        let fractional = v.verbalize(.traceStatistical(TraceStatisticalIR(
            pattern: TraceStatisticalPatternIR(subject: .step("deploy")),
            outcome: .succeeds,
            bound: .atLeast(0.9125),
            denominator: .occurrences)))
        #expect(fractional.contains("91.25"), Comment(rawValue: fractional))
    }

    @Test("Verbalizer synthesizes deontic norms and obligation-ID annotations")
    func verbalizerSynthesizedDeonticNorms() {
        let range = SourceRange(file: "t.meridian", line: 1, column: 1)
        let symbols = SymbolTable.build(from: MerConfigFile(tools: [
            ToolDeclaration(
                displayName: "Time Now",
                methodName: "time.now",
                parameters: [ToolParameterAST(name: "channel", type: "String")],
                returnType: "String"
            ),
        ]), trace: .silent())
        let v = Verbalizer(model: VerbalizerModel(
            workflows: [],
            loweredDefinitions: [],
            inlineDefinitions: [],
            symbols: symbols,
            lexicon: .default,
            sourceFileName: "t.meridian",
            authoredSource: ""
        ))

        let prohibition = NormIR(
            id: "OBL-P1",
            kind: .prohibition,
            scope: .kind("Customer"),
            actionPattern: ActionPatternIR(
                toolID: "time.now",
                argumentConstraints: [
                    ActionArgumentConstraint(path: "channel", op: .equal, value: .literal(.string("#alerts"))),
                ]
            ),
            blocking: true,
            sourceRange: range,
            originalText: ""
        )
        let prohibitionText = v.verbalize(prohibition, annotateObligationID: true)
        #expect(prohibitionText.contains("must not"))
        #expect(prohibitionText.contains("[OBL-P1]"))

        let obligation = NormIR(
            kind: .obligation,
            scope: .workflow("NotifyCustomer"),
            condition: .literal(.boolean(true)),
            blocking: true,
            sourceRange: range,
            originalText: ""
        )
        #expect(v.verbalize(obligation).contains("must hold"))

        let permission = NormIR(
            kind: .permission,
            scope: .section(stablePath: "deploy.step"),
            actionPattern: ActionPatternIR(toolID: "time.now"),
            sourceRange: range,
            originalText: ""
        )
        #expect(v.verbalize(permission).contains("may invoke"))
    }

    @Test("Verbalizer covers branch unknown-policy and trace scope variants")
    func verbalizerBranchAndTraceScopes() {
        let v = Verbalizer(model: VerbalizerModel(
            workflows: [],
            loweredDefinitions: [],
            inlineDefinitions: [],
            symbols: SymbolTable(trace: .silent()),
            lexicon: .default,
            sourceFileName: "t.meridian",
            authoredSource: ""
        ))
        let inner = IRBlock(statements: [.complete(CompleteIR())])
        let unlessBranch = BranchIR(
            condition: .predicate(.logical(.not, [.identifierRef(name: "ready")])),
            thenBlock: inner,
            unknownPolicy: .asTrue,
            authoredForm: .unlessHeader,
            sourceRange: SourceRange(file: "t.meridian", line: 1, column: 1)
        )
        let unlessText = v.verbalize(.branch(unlessBranch))
        #expect(unlessText.contains("treating unknown as true"))

        let pattern = EventPatternIR(subject: .step("deploy"), outcome: .failed)
        let acrossSkills = v.verbalize(.traceTemporal(TraceTemporalIR(
            scope: .acrossSkills(["skill-a", "skill-b"]),
            kind: .ever(pattern)
        )))
        #expect(acrossSkills.contains("skill-a"))

        let bounded = v.verbalize(.traceTemporal(TraceTemporalIR(
            scope: .currentRun,
            kind: .boundedFutureMonitor(
                condition: .literal(.boolean(true)),
                horizon: .seconds(60),
                mode: .eventuallyWithin
            )
        )))
        #expect(bounded.contains("eventually within"))

        let confidence = v.verbalize(.traceStatistical(TraceStatisticalIR(
            pattern: TraceStatisticalPatternIR(subject: .step("deploy")),
            outcome: .succeeds,
            bound: .atLeast(0.9),
            denominator: .occurrences,
            confidencePercent: 0.95
        )))
        #expect(confidence.contains("95%"))
    }

    // MARK: - TrialLowering.ProbeTally

    @Test("ProbeTally records probe outcomes and renders a summary line")
    func probeTallySummary() throws {
        let knowledge = try Compiler(options: .init(trace: .silent())).knowledge(
            forSource: "", sourceFile: "<test>",
            vocabularies: [TrialLoweringTests.orderVocab])
        let tally = TrialLowering.ProbeTally()
        let trial = TrialLowering(knowledge: knowledge, probeTally: tally)
        #expect(trial.lowersAsStatement("Validate the order."))
        #expect(!trial.lowersAsStatement("frobnicate the wibble."))
        let summary = tally.summaryLine
        #expect(summary?.contains("2 probe") == true)
        #expect(summary?.contains("1 lowered") == true)
        #expect(summary?.contains("1 rejected") == true)
    }

    private func validationDiagnostics(_ expression: IRExpression) -> [Diagnostic] {
        do {
            try IRValidator.validate(expression, sourceFile: "invalid.ir")
            return []
        } catch IRValidationError.diagnostics(let diagnostics) {
            return diagnostics
        } catch {
            Issue.record("unexpected validation error: \(error)")
            return []
        }
    }
}
