import Foundation
import Testing
@testable import MeridianCore
import MeridianRuntime

@Suite("TraceTemporal compiler semantics")
struct TraceTemporalInform7Tests {
    @Test("SEM_5_10 temporal definition on unkeyed kind reports MER-TMP-016")
    func sem509() throws {
        let cfg = """
        === vocabulary ===
        A service is a kind of thing.
        A service has a text called the status.
        """
        let mer = """
        Definition: a service is flaky if the deploy step has ever failed.

        To inspect a service:
          complete.
        """

        let diagnostic = try requireLoweringDiagnostic(
            mer: mer,
            cfg: cfg,
            code: .traceUnkeyedDefinition
        )
        #expect(diagnostic.message.contains("requires `service` to declare a key property"),
                Comment(rawValue: diagnostic.message))
    }

    @Test("SEM_5_09 keyed temporal definition threads subject key into lowered IR")
    func sem510KeyedDefinition() throws {
        let cfg = """
        === vocabulary ===
        A service is a kind of thing.
        A service has a text called the name.
        A service has a text called the status.
        A service is keyed by the name.
        """
        let mer = """
        Definition: a service is flaky if the deploy step has ever failed.

        To inspect a service:
          complete.
        """

        let defs = try loweredDefinitions(mer: mer, cfg: cfg)
        guard let only = defs.first else {
            Issue.record("expected one lowered definition")
            return
        }
        guard case .traceTemporal(let temporal) = only.body else {
            Issue.record("expected temporal body, got \(only.body)")
            return
        }
        #expect(temporal.subjectKeyExpr != nil)
    }

    @Test("SEM_5_07 temporal operators compose inside definitions and yield temporal adjectives")
    func sem507TemporalDefinitionsCompose() throws {
        let defs = try loweredDefinitions(
            mer: """
            Definition: a service is flaky if the deploy step has ever failed.
            Definition: a service is recoverable if the service is flaky since the last deploy step succeeded.

            To inspect a service:
              if the service is recoverable,
                complete.
              if it is unknown whether:
                complete.
              otherwise,
                complete.
            """,
            cfg: keyedServiceCfg
        )
        #expect(defs.count == 2)
        guard let recoverable = defs.last else {
            Issue.record("expected composed temporal definition")
            return
        }
        guard case .traceTemporal(let temporal) = recoverable.body else {
            Issue.record("expected temporal adjective body, got \(recoverable.body)")
            return
        }
        #expect(temporal.subjectKeyExpr != nil)
        guard case .sinceLast(_, _, let holdsPattern, _) = temporal.kind else {
            Issue.record("expected composed since-the-last temporal definition, got \(temporal.kind)")
            return
        }
        guard let holdsPattern else {
            Issue.record("expected composed since-the-last holdsPattern")
            return
        }
        guard case .step("deploy") = holdsPattern.subject else {
            Issue.record("expected composed holdsPattern subject `deploy`, got \(holdsPattern.subject)")
            return
        }
        guard case .failed = holdsPattern.outcome else {
            Issue.record("expected composed holdsPattern outcome `failed`, got \(String(describing: holdsPattern.outcome))")
            return
        }
    }

    private func loweredDefinitions(mer: String, cfg: String) throws -> [LoweredDefinition] {
        let config = try MerConfigParser(trace: .silent()).parse(cfg, file: "t.merconfig")
        let symbols = SymbolTable.build(from: config, sourceFile: "t.merconfig", trace: .silent())
        let file = try MeridianParser(symbols: symbols, trace: .silent()).parse(mer, file: "t.meridian")
        let lowering = ASTToIR(symbols: symbols, sourceFile: "t.meridian", trace: .silent(), engine: DiagnosticEngine())
        _ = try lowering.lower(file)
        return try lowering.lowerRegisteredDefinitions()
    }

    private var keyedServiceCfg: String {
        """
        === vocabulary ===
        A service is a kind of thing.
        A service has a text called the name.
        A service has a text called the status.
        A service is keyed by the name.
        """
    }

    private func requireLoweringDiagnostic(
        mer: String,
        cfg: String,
        code: DiagnosticCode
    ) throws -> Diagnostic {
        do {
            _ = try loweredDefinitions(mer: mer, cfg: cfg)
            Issue.record("expected \(code.id)")
            throw CompilerError.codegenError(message: "expected diagnostic \(code.id)")
        } catch let error as CompilerError {
            guard let diagnostic = error.diagnostics.first(where: { $0.code == code }) else {
                Issue.record("expected \(code.id), got \(error.diagnostics.map { $0.code.id })")
                throw CompilerError.codegenError(message: "missing diagnostic \(code.id)")
            }
            return diagnostic
        }
    }
}

@Suite("BrokenTwin diagnostics")
struct BrokenTwinDiagnosticsTests {
    @Test("NS-C-01 Broken Twin line 1 reports MER-TMP-010")
    func brokenTwin1() throws {
        let diagnostic = try requireExpressionDiagnostic(
            "the deploy step has failed",
            code: .traceBarePerfect
        )
        #expect(diagnostic.message.contains("explicit operator"), Comment(rawValue: diagnostic.message))
        #expect(diagnostic.message.contains("has ever"), Comment(rawValue: diagnostic.message))
    }

    @Test("NS-C-03 Broken Twin line 3 reports MER-TMP-012")
    func brokenTwin3() throws {
        let diagnostic = try requireExpressionDiagnostic(
            "the build step failed since the last deploy step succeeded",
            code: .traceCausalSince
        )
        #expect(diagnostic.message.contains("since the last"), Comment(rawValue: diagnostic.message))
        #expect(diagnostic.message.contains("causality between two events"), Comment(rawValue: diagnostic.message))
    }

    @Test("NS-C-04 Broken Twin line 4 reports MER-TMP-017 for a vague `recently` window")
    func brokenTwin4() throws {
        // Line 4 of the Broken Twin: `a service is flaky if it has failed
        // recently`. The vague window (`recently`, MER-TMP-017) is reported
        // first, short-circuiting before the unkeyed-definition check
        // (MER-TMP-016) can fire — "vague window reported first" per NS §C.4.
        let diagnostic = try requireExpressionDiagnostic(
            "the deploy step has failed recently",
            code: .traceRecently
        )
        #expect(diagnostic.message.contains("`recently` is ambiguous"), Comment(rawValue: diagnostic.message))
        let help = diagnostic.help ?? ""
        #expect(help.contains("within the last 7 days"), Comment(rawValue: help))
    }

    @Test("NS-C-05 Broken Twin line 5 reports MER-TMP-013")
    func brokenTwin5() throws {
        let diagnostic = try requireExpressionDiagnostic(
            "the deploy step will fail",
            code: .traceFuture
        )
        #expect(diagnostic.message.contains("future events"), Comment(rawValue: diagnostic.message))
        let help = diagnostic.help ?? ""
        #expect(help.contains("present or past"), Comment(rawValue: help))
    }

    @Test("NS-C-06 Broken Twin line 6 reports MER-STA-001 for a true-arm-only branch")
    func brokenTwin6() throws {
        // `stale` is an event-backed temporal adjective (`has ever failed`), so
        // the `since the last` holds resolves to an event pattern; the branch is
        // still possibly-indeterminate (any `since` is) and has no unknown/
        // `otherwise` arm, so totality fires.
        let diagnostic = try requireDiagnostic(
            """
            Definition: a service is stale if the deploy step has ever failed.

            To inspect a service:
              if the service is stale since the last deploy step succeeded,
                let the note be "missing fallback".
            """,
            code: .traceMissingUnknownArm
        )
        #expect(diagnostic.message.contains("if it is unknown whether"),
                Comment(rawValue: diagnostic.message))
        #expect(diagnostic.message.contains("otherwise"),
                Comment(rawValue: diagnostic.message))
    }

    @Test("NS-C-07 Broken Twin line 7 reports MER-STA-001 for a blocking assert with no default policy")
    func brokenTwin7() throws {
        let diagnostic = try requireDiagnostic(
            """
            Definition: a service is stale if the deploy step has ever failed.

            To inspect a service:
              assert the service is stale since the last deploy step succeeded.
            """,
            code: .traceMissingUnknownArm
        )
        #expect(diagnostic.message.contains("unknown/default policy"),
                Comment(rawValue: diagnostic.message))
        let help = diagnostic.help ?? ""
        #expect(help.contains("otherwise:"),
                Comment(rawValue: help))
        #expect(help.contains("default policy"),
                Comment(rawValue: help))
    }

    @Test("NS-C-07 near miss branch with otherwise remains accepted")
    func brokenTwin7NearMissOtherwiseAccepted() throws {
        let workflows = try lowered(
            """
            Definition: a service is stale if the deploy step has ever failed.

            To inspect a service:
              if the service is stale since the last deploy step succeeded,
                complete.
              otherwise,
                complete.
            """
        )
        guard let statement = workflows.first?.body.statements.first,
              case .branch(let branch) = statement else {
            Issue.record("expected lowered branch")
            return
        }
        #expect(branch.unknownBlock == nil)
        #expect(branch.elseBlock != nil)
    }

    @Test("NS-C-02 / SEM-4-06 window greater than retention reports MER-TMP-011 naming both durations")
    func brokenTwin2WindowExceedsRetention() throws {
        let cfg = """
        === vocabulary ===
        A service is a kind of thing.
        A service has a text called the name.
        A service is keyed by the name.

        === trace ===
        retention: 30 days
        """
        let diagnostic = try requireDiagnostic(
            """
            To inspect traces:
              if the deploy step has failed within the last 90 days,
                complete.
            """,
            cfg: cfg,
            code: .traceWindowExceedsRetention
        )
        // The message must name BOTH durations (SEM-4-06 / D1).
        #expect(diagnostic.message.contains("90 days"),
                Comment(rawValue: "expected the window `90 days` named, got: \(diagnostic.message)"))
        #expect(diagnostic.message.contains("30 days"),
                Comment(rawValue: "expected the retention `30 days` named, got: \(diagnostic.message)"))
    }

    @Test("MER-TMP-019 a pure state-predicate `since the last` holds is rejected")
    func sinceStatePredicateRejected() throws {
        let diagnostic = try requireDiagnostic(
            """
            Definition: a service is healthy if its status equals "healthy".

            To inspect a service:
              if the service is healthy since the last deploy step succeeded,
                complete.
              otherwise,
                complete.
            """,
            code: .traceStateHistorySince
        )
        #expect(diagnostic.message.contains("not an event pattern"),
                Comment(rawValue: diagnostic.message))
        let help = diagnostic.help ?? ""
        #expect(help.contains("state history: enabled"),
                Comment(rawValue: help))
    }

    @Test("bare `since` without `the last` and without a valid anchor-first comma reports MER-TMP-012")
    func bareCausalSinceWithoutAnchorMarker() throws {
        // No "since the last" anchor marker anywhere in the text (just a
        // bare " since "), so this is diagnosed up front in
        // `earlyDiagnostic`/`isBareCausalSince`, distinct from `brokenTwin3`'s
        // `parseSince`-level causal-since (which requires the "since the
        // last" anchor marker to be present but paired with a non-negated
        // event-pattern LHS).
        let diagnostic = try requireExpressionDiagnostic(
            "the deploy failed since the outage began",
            code: .traceCausalSince
        )
        #expect(diagnostic.message.contains("without `the last`"), Comment(rawValue: diagnostic.message))
    }

    @Test("a negated event-pattern LHS resolves directly through `since the last`, not via the recursive parser")
    func negatedEventPatternLHSResolvesDirectly() {
        // Constructed directly (bypassing the outer `ExpressionParser`,
        // which would otherwise route a leading "no " to the `no`-quantifier
        // determiner before `TraceTemporalGrammar` ever sees it): the LHS
        // resolves to a *negated* event pattern, so `parseSince` must take
        // it directly via `.map(ExpressionAST.eventPattern)` rather than
        // re-parsing it through the general recursive `recurse` closure.
        let ep = ExpressionParser(trace: .silent())
        let grammar = TraceTemporalGrammar(
            lexicon: .default,
            recurse: ep.parse,
            eventPattern: { TraceEventPatternGrammar(lexicon: .default, atom: { .malformed($0) }).parse($0) },
            anchorPattern: { TraceEventPatternGrammar(lexicon: .default, atom: { .malformed($0) }).parseAnchor($0) }
        )
        guard case .traceTemporal(let temporal) = grammar.parse("no critical alert has occurred since the last deploy step succeeded") else {
            Issue.record("expected a traceTemporal result")
            return
        }
        guard case .sinceLast(_, let holds) = temporal.kind else {
            Issue.record("expected sinceLast kind, got \(temporal.kind)")
            return
        }
        guard case .eventPattern(let holdsPattern) = holds else {
            Issue.record("expected an eventPattern holds side, got \(holds)")
            return
        }
        #expect(holdsPattern.negated)
        guard case .named("critical alert") = holdsPattern.subject else {
            Issue.record("expected named(\"critical alert\") subject, got \(holdsPattern.subject)")
            return
        }
    }

    @Test("anchor-first `since the last E, C` recurses through the general parser when the holds side is a state predicate")
    func anchorFirstStatePredicateHoldsRecursesThroughGeneralParser() {
        // At the parser level (before the lowering-time MER-TMP-019 rejection
        // of non-event-pattern holds sides), a state-predicate holds clause
        // must fall through `eventPattern(holdsText).map(...) ?? recurse(...)`
        // to the `recurse` branch, since it has no outcome verb.
        let ep = ExpressionParser(trace: .silent())
        let grammar = TraceTemporalGrammar(
            lexicon: .default,
            recurse: ep.parse,
            eventPattern: { TraceEventPatternGrammar(lexicon: .default, atom: { .malformed($0) }).parse($0) },
            anchorPattern: { TraceEventPatternGrammar(lexicon: .default, atom: { .malformed($0) }).parseAnchor($0) }
        )
        guard case .traceTemporal(let temporal) = grammar.parse("since the last deploy step succeeded, the service is healthy") else {
            Issue.record("expected a traceTemporal result")
            return
        }
        guard case .sinceLast(_, let holds) = temporal.kind else {
            Issue.record("expected sinceLast kind, got \(temporal.kind)")
            return
        }
        if case .eventPattern = holds {
            Issue.record("expected the holds side to recurse through the general parser, not resolve as a bare event pattern")
        }
    }

    @Test("anchor-first `since the last` with no comma separator falls back to the regular (non-anchor-first) since parse")
    func anchorFirstWithoutCommaDoesNotMatch() {
        // The text `hasPrefix`es the anchor-first marker (leading occurrence
        // of "since the last", no space before it), so `parseSinceAnchorFirst`
        // is attempted; with no comma anywhere in its remainder it must
        // return nil (rather than erroring) and let the regular `parseSince`
        // try again — which only succeeds here because a *second*,
        // space-preceded "since the last" occurs later in the text for its
        // marker scan to find.
        let ep = ExpressionParser(trace: .silent())
        let grammar = TraceTemporalGrammar(
            lexicon: .default,
            recurse: ep.parse,
            eventPattern: { TraceEventPatternGrammar(lexicon: .default, atom: { .malformed($0) }).parse($0) },
            anchorPattern: { TraceEventPatternGrammar(lexicon: .default, atom: { .malformed($0) }).parseAnchor($0) }
        )
        let result = grammar.parse(
            "since the last deploy step succeeded and since the last outage ended the service is healthy"
        )
        guard case .traceTemporal(let temporal) = result else {
            Issue.record("expected a traceTemporal result via the regular since-parse fallback, got \(String(describing: result))")
            return
        }
        guard case .sinceLast = temporal.kind else {
            Issue.record("expected sinceLast kind, got \(temporal.kind)")
            return
        }
    }

    @Test("an `at most N times within the last` count comparator lowers")
    func atMostCountInWindowLowers() throws {
        let workflows = try lowered(
            """
            To inspect traces:
              if the deploy step has failed at most 2 times within the last 7 days,
                complete.
              if it is unknown whether:
                complete.
              otherwise,
                complete.
            """
        )
        #expect(!workflows.isEmpty)
    }

    @Test("an `exactly N times within the last` count comparator lowers")
    func exactlyCountInWindowLowers() throws {
        let workflows = try lowered(
            """
            To inspect traces:
              if the deploy step has failed exactly 3 times within the last 7 days,
                complete.
              if it is unknown whether:
                complete.
              otherwise,
                complete.
            """
        )
        #expect(!workflows.isEmpty)
    }

    @Test("a non-numeric count-in-window count falls through every comparator prefix and never matches")
    func nonNumericCountInWindowFallsThrough() {
        let ep = ExpressionParser(trace: .silent())
        let grammar = TraceTemporalGrammar(
            lexicon: .default,
            recurse: ep.parse,
            eventPattern: { TraceEventPatternGrammar(lexicon: .default, atom: { .malformed($0) }).parse($0) },
            anchorPattern: { TraceEventPatternGrammar(lexicon: .default, atom: { .malformed($0) }).parseAnchor($0) }
        )
        #expect(grammar.parse("the deploy step has failed at least three times within the last 7 days") == nil)
    }

    @Test("a non-numeric `times in a row` count never matches the in-a-row shape")
    func nonNumericInARowFallsThrough() {
        let ep = ExpressionParser(trace: .silent())
        let grammar = TraceTemporalGrammar(
            lexicon: .default,
            recurse: ep.parse,
            eventPattern: { TraceEventPatternGrammar(lexicon: .default, atom: { .malformed($0) }).parse($0) },
            anchorPattern: { TraceEventPatternGrammar(lexicon: .default, atom: { .malformed($0) }).parseAnchor($0) }
        )
        #expect(grammar.parse("the deploy step has failed abc times in a row") == nil)
    }

    @Test("a `times in a row` shape with no subject before the count never matches")
    func inARowWithNoSubjectFallsThrough() {
        // `parseInARow` strips the count token off leaving an empty
        // `patternText`; `eventPattern("")` must reject that, so this must
        // return nil rather than crash on the empty-subject edge.
        let ep = ExpressionParser(trace: .silent())
        let grammar = TraceTemporalGrammar(
            lexicon: .default,
            recurse: ep.parse,
            eventPattern: { TraceEventPatternGrammar(lexicon: .default, atom: { .malformed($0) }).parse($0) },
            anchorPattern: { TraceEventPatternGrammar(lexicon: .default, atom: { .malformed($0) }).parseAnchor($0) }
        )
        #expect(grammar.parse("3 times in a row") == nil)
    }

    @Test("a `within the last` window missing its duration unit never matches")
    func withinWindowMissingDurationUnitFallsThrough() {
        let ep = ExpressionParser(trace: .silent())
        let grammar = TraceTemporalGrammar(
            lexicon: .default,
            recurse: ep.parse,
            eventPattern: { TraceEventPatternGrammar(lexicon: .default, atom: { .malformed($0) }).parse($0) },
            anchorPattern: { TraceEventPatternGrammar(lexicon: .default, atom: { .malformed($0) }).parseAnchor($0) }
        )
        #expect(grammar.parse("the deploy step has failed within the last 7") == nil)
    }

    @Test("across-all-runs scoping over an unparseable remainder never matches")
    func acrossAllRunsWithUnparseableRemainderFallsThrough() {
        // No temporal shape matches the remainder ("the weather is nice
        // today" is not a trace-temporal predicate at all), so `parseScoped`
        // itself must reject the recursive `parse(remainder)` result and
        // return nil rather than wrapping a non-temporal expression in a
        // bogus `.acrossAllRuns` scope.
        let ep = ExpressionParser(trace: .silent())
        let grammar = TraceTemporalGrammar(
            lexicon: .default,
            recurse: ep.parse,
            eventPattern: { TraceEventPatternGrammar(lexicon: .default, atom: { .malformed($0) }).parse($0) },
            anchorPattern: { TraceEventPatternGrammar(lexicon: .default, atom: { .malformed($0) }).parseAnchor($0) }
        )
        #expect(grammar.parse("across all runs, the weather is nice today") == nil)
    }

    /// Definition bodies are only lowered by `lowerRegisteredDefinitions()`
    /// (deferred pass), not by the main `.lower(file)` walk that handles
    /// workflow bodies — a bare `if the service is flaky:` reference only
    /// creates a `.definitionPredicate` stub. MER-TMP-014/015 live inside a
    /// temporal adjective's *body*, so they need this deferred pass run too.
    private func requireDefinitionDiagnostic(
        mer: String,
        cfg: String,
        code: DiagnosticCode
    ) throws -> Diagnostic {
        let config = try MerConfigParser(trace: .silent()).parse(cfg, file: "t.merconfig")
        let symbols = SymbolTable.build(from: config, sourceFile: "t.merconfig", trace: .silent())
        let file = try MeridianParser(symbols: symbols, trace: .silent()).parse(mer, file: "t.meridian")
        let lowering = ASTToIR(symbols: symbols, sourceFile: "t.meridian", trace: .silent(), engine: DiagnosticEngine())
        do {
            _ = try lowering.lower(file)
            _ = try lowering.lowerRegisteredDefinitions()
            Issue.record("expected \(code.id)")
            throw CompilerError.codegenError(message: "expected diagnostic \(code.id)")
        } catch let error as CompilerError {
            guard let diagnostic = error.diagnostics.first(where: { $0.code == code }) else {
                Issue.record("expected \(code.id), got \(error.diagnostics.map { $0.code.id })")
                throw CompilerError.codegenError(message: "missing diagnostic \(code.id)")
            }
            return diagnostic
        }
    }

    private func definitionCompiles(mer: String, cfg: String) throws {
        let config = try MerConfigParser(trace: .silent()).parse(cfg, file: "t.merconfig")
        let symbols = SymbolTable.build(from: config, sourceFile: "t.merconfig", trace: .silent())
        let file = try MeridianParser(symbols: symbols, trace: .silent()).parse(mer, file: "t.meridian")
        let lowering = ASTToIR(symbols: symbols, sourceFile: "t.meridian", trace: .silent(), engine: DiagnosticEngine())
        _ = try lowering.lower(file)
        let defs = try lowering.lowerRegisteredDefinitions()
        #expect(!defs.isEmpty)
    }

    @Test("MER-TMP-014 a step name that closely misspells a declared tool prefix is rejected")
    func brokenTwinUnknownStepNearMiss() throws {
        let cfg = """
        === vocabulary ===
        A service is a kind of thing.
        A service has a text called the name.
        A service is keyed by the name.

        === tools ===
        Deploy Rollback
        ================
        ~ deploy.rollback(target: String) : Boolean
        """
        let diagnostic = try requireDefinitionDiagnostic(
            mer: """
            Definition: a service is flaky if the deply step has ever failed.
            """,
            cfg: cfg,
            code: .traceUnknownStep
        )
        let help = diagnostic.help ?? ""
        #expect(help.contains("deploy"), Comment(rawValue: help))
        #expect(help.contains("Declared step names in scope"), Comment(rawValue: help))
    }

    @Test("a novel, self-consistent step noun with no near-miss compiles (MER-TMP-014 never fires on undeclared vocabulary)")
    func unknownStepNoNearMissCompiles() throws {
        try definitionCompiles(
            mer: """
            Definition: a service is flaky if the deploy step has ever failed.
            """,
            cfg: """
            === vocabulary ===
            A service is a kind of thing.
            A service has a text called the name.
            A service is keyed by the name.
            """
        )
    }

    @Test("MER-TMP-015 a `whose` payload field not declared on the subject's tool is rejected")
    func brokenTwinUnknownPayloadField() throws {
        let cfg = """
        === vocabulary ===
        A service is a kind of thing.
        A service has a text called the name.
        A service is keyed by the name.

        === tools ===
        Deploy Rollback
        ================
        ~ deploy.rollback(target: String) : Boolean
        """
        let diagnostic = try requireDefinitionDiagnostic(
            mer: """
            Definition: a service is flaky if the deploy step whose targt is "prod" has ever failed.
            """,
            cfg: cfg,
            code: .traceUnknownPayloadField
        )
        #expect(diagnostic.notes.first?.message.contains("target") == true
                || diagnostic.suggestions.first?.replacement == "target",
                Comment(rawValue: "\(diagnostic.notes) / \(diagnostic.suggestions)"))
    }

    @Test("a declared payload field on the subject's tool compiles cleanly")
    func knownPayloadFieldCompiles() throws {
        let cfg = """
        === vocabulary ===
        A service is a kind of thing.
        A service has a text called the name.
        A service is keyed by the name.

        === tools ===
        Deploy Rollback
        ================
        ~ deploy.rollback(target: String) : Boolean
        """
        try definitionCompiles(
            mer: """
            Definition: a service is flaky if the deploy step whose target is "prod" has ever failed.
            """,
            cfg: cfg
        )
    }

    @Test("MER-TMP-021 a skill-scoped step subject reports cross-skill trace scope not supported (D4)")
    func brokenTwinCrossSkillScope() throws {
        let diagnostic = try requireDiagnostic(
            """
            To inspect a service:
              if the fetch step of the briefing skill has ever failed,
                complete.
              otherwise,
                complete.
            """,
            code: .traceCrossSkillScope
        )
        #expect(diagnostic.message.contains("briefing"), Comment(rawValue: diagnostic.message))
        #expect((diagnostic.help ?? "").contains("cross-skill allow-list"),
                Comment(rawValue: diagnostic.help ?? ""))
    }

    @Test("since-the-last with an event-backed adjective holds lowers to a runtime-evaluable pattern")
    func sinceEventBackedAdjectiveLowers() throws {
        let workflows = try lowered(
            """
            Definition: a service is stale if the deploy step has ever failed.

            To inspect a service:
              if the service is stale since the last deploy step succeeded,
                complete.
              if it is unknown whether:
                complete.
              otherwise,
                complete.
            """
        )
        let holdsPattern = firstSinceHoldsPattern(in: workflows)
        guard let holdsPattern else {
            Issue.record("expected a lowered sinceLast holdsPattern")
            return
        }
        guard case .step("deploy") = holdsPattern.subject else {
            Issue.record("expected holdsPattern subject `deploy` step, got \(holdsPattern.subject)")
            return
        }
        guard case .failed = holdsPattern.outcome else {
            Issue.record("expected holdsPattern outcome `failed`, got \(String(describing: holdsPattern.outcome))")
            return
        }
    }

    private func firstSinceHoldsPattern(in workflows: [IRWorkflow]) -> EventPatternIR? {
        for workflow in workflows {
            if let found = firstSinceHoldsPattern(in: workflow.body) { return found }
        }
        return nil
    }

    private func firstSinceHoldsPattern(in block: IRBlock) -> EventPatternIR? {
        for statement in block.statements {
            if case .branch(let branch) = statement,
               case .predicate(let predicate) = branch.condition,
               case .traceTemporal(let temporal) = predicate,
               case .sinceLast(_, _, let holdsPattern, _) = temporal.kind {
                return holdsPattern
            }
        }
        return nil
    }

    @Test("COOK-20 progressive aspect reports MER-TMP-018")
    func cook20Progressive() throws {
        let diagnostic = try requireExpressionDiagnostic(
            "the deploy step is failing",
            code: .traceProgressive
        )
        #expect(diagnostic.message.contains("not supported"), Comment(rawValue: diagnostic.message))
        let help = diagnostic.help ?? ""
        #expect(help.contains("failed` or `succeeded"), Comment(rawValue: help))
    }

    private func requireDiagnostic(
        _ merBody: String,
        cfg: String = "",
        code: DiagnosticCode
    ) throws -> Diagnostic {
        let diagnostics = try requireDiagnostics(merBody, cfg: cfg)
        guard let diagnostic = diagnostics.first(where: { $0.code == code }) else {
            Issue.record("expected \(code.id), got \(diagnostics.map { $0.code.id })")
            throw CompilerError.codegenError(message: "missing diagnostic \(code.id)")
        }
        return diagnostic
    }

    private func expectDiagnostic(
        _ merBody: String,
        cfg: String = "",
        code: DiagnosticCode
    ) throws {
        _ = try requireDiagnostic(merBody, cfg: cfg, code: code)
    }

    private func expectExpressionDiagnostic(_ expression: String, code: DiagnosticCode) throws {
        _ = try requireExpressionDiagnostic(expression, code: code)
    }

    private func requireExpressionDiagnostic(_ expression: String, code: DiagnosticCode) throws -> (message: String, help: String?) {
        let parsed = ExpressionParser(trace: .silent()).parse(expression)
        guard case .malformed(_, let actualCode, _, _) = parsed else {
            Issue.record("expected malformed expression for \(code.id), got \(parsed)")
            throw CompilerError.codegenError(message: "expected malformed expression \(code.id)")
        }
        #expect(actualCode == code, Comment(rawValue: "expected \(code.id), got \(actualCode.id)"))
        guard case .malformed(let message, _, let help, _) = parsed else {
            throw CompilerError.codegenError(message: "missing malformed message \(code.id)")
        }
        return (message, help)
    }

    private func requireDiagnostics(_ merBody: String, cfg: String = "") throws -> [Diagnostic] {
        do {
            _ = try lowered(merBody, cfg: cfg)
            Issue.record("expected diagnostics")
            throw CompilerError.codegenError(message: "expected diagnostics")
        } catch let error as CompilerError {
            return error.diagnostics
        }
    }

    private func lowered(_ merBody: String, cfg override: String = "") throws -> [IRWorkflow] {
        let defaultCfg = """
        === vocabulary ===
        A service is a kind of thing.
        A service has a text called the name.
        A service has a text called the status.
        A service is keyed by the name.
        """
        let cfg = override.isEmpty ? defaultCfg : override
        let config = try MerConfigParser(trace: .silent()).parse(cfg, file: "t.merconfig")
        let symbols = SymbolTable.build(from: config, sourceFile: "t.merconfig", trace: .silent())
        let file = try MeridianParser(symbols: symbols, trace: .silent()).parse(merBody, file: "t.meridian")
        // The lowerer's batch engine collects; this helper checkpoints so the
        // `requireDiagnostics` contract (errors thrown as `CompilerError`) holds.
        let engine = DiagnosticEngine(trace: .silent())
        let workflows = try ASTToIR(symbols: symbols, sourceFile: "t.meridian", trace: .silent(),
                                    engine: engine).lower(file)
        try engine.throwIfErrors()
        return workflows
    }
}

@Suite("TraceStatistical compiler semantics")
struct TraceStatisticalInform7Tests {
    @Test("SEM_6_02 statistical branch without fallback reports MER-STA-001")
    func sem604MissingUnknownArm() throws {
        try expectDiagnostic(
            mer: """
            To inspect traces:
              if the deploy step succeeds in at least 90% of runs,
                complete.
            """,
            cfg: "",
            code: .traceMissingUnknownArm
        )
    }

    @Test("SEM_2_11 decision-point totality is not enforced on monitored statistical assertions")
    func sem605DefaultCadenceMonitorsAssert() throws {
        let cfg = """
        === trace ===
        default monitor cadence: 5 minutes
        """
        let mer = """
        To inspect traces:
          assert the deploy step succeeds in at least 90% of runs.
        """

        let workflow = try loweredWorkflow(mer: mer, cfg: cfg)
        guard case .assert(let assertion) = workflow.body.statements.first else {
            Issue.record("expected lowered assert")
            return
        }
        #expect(assertion.monitored)
        #expect(assertion.cadence == .seconds(300))
        #expect(assertion.blocking == false)
    }

    @Test("SEM_6_03 contract statistical claims lower to monitored assertions with indeterminate outcomes allowed")
    func sem603ContractStatisticalAssertionsMonitor() throws {
        let cfg = """
        === trace ===
        default monitor cadence: 5 minutes
        """
        let mer = """
        To inspect traces:
          assert the deploy step succeeds in at least 90% of runs.
        """

        let workflow = try loweredWorkflow(mer: mer, cfg: cfg)
        guard case .assert(let assertion) = workflow.body.statements.first else {
            Issue.record("expected lowered assert")
            return
        }
        #expect(assertion.monitored)
        #expect(assertion.cadence == .seconds(300))
        #expect(assertion.blocking == false)
        guard case .traceStatistical = assertion.condition else {
            Issue.record("expected statistical assertion condition, got \(assertion.condition)")
            return
        }
    }

    @Test("8D `most of the time` reports MER-STA-003 vague statistical frequency")
    func mersta003VagueFrequency() throws {
        try expectDiagnostic(
            mer: """
            To inspect traces:
              if the deploy step succeeds most of the time,
                complete.
            """,
            cfg: "",
            code: .statisticalVagueFrequency
        )
    }

    @Test("8D `usually`/`rarely` surface forms lower to the configured default thresholds")
    func usuallyRarelyDefaultThresholds() throws {
        let usuallyWorkflow = try loweredWorkflow(
            mer: """
            To inspect traces:
              if the deploy step usually succeeds,
                complete.
              if it is unknown whether:
                complete.
              otherwise,
                complete.
            """,
            cfg: ""
        )
        guard case .branch(let usuallyBranch) = usuallyWorkflow.body.statements.first,
              case .predicate(.traceStatistical(let usuallyStatistical)) = usuallyBranch.condition else {
            Issue.record("expected a lowered traceStatistical branch condition")
            return
        }
        #expect(usuallyStatistical.outcome == .succeeds)
        #expect(usuallyStatistical.bound == .atLeast(0.9))

        let rarelyWorkflow = try loweredWorkflow(
            mer: """
            To inspect traces:
              if the deploy step rarely fails,
                complete.
              if it is unknown whether:
                complete.
              otherwise,
                complete.
            """,
            cfg: ""
        )
        guard case .branch(let rarelyBranch) = rarelyWorkflow.body.statements.first,
              case .predicate(.traceStatistical(let rarelyStatistical)) = rarelyBranch.condition else {
            Issue.record("expected a lowered traceStatistical branch condition")
            return
        }
        #expect(rarelyStatistical.outcome == .fails)
        #expect(rarelyStatistical.bound == .atMost(0.1))
    }

    @Test("8D `usually`/`rarely` thresholds are configurable via === trace ===")
    func usuallyRarelyConfiguredThresholds() throws {
        let cfg = """
        === trace ===
        usually at least: 95%
        rarely at most: 2%
        """
        let workflow = try loweredWorkflow(
            mer: """
            To inspect traces:
              if the deploy step usually succeeds,
                complete.
              if it is unknown whether:
                complete.
              otherwise,
                complete.
            """,
            cfg: cfg
        )
        guard case .branch(let branch) = workflow.body.statements.first,
              case .predicate(.traceStatistical(let statistical)) = branch.condition else {
            Issue.record("expected a lowered traceStatistical branch condition")
            return
        }
        #expect(statistical.bound == .atLeast(0.95))
    }

    @Test("SEM_5_09 keyed statistical definition threads subject key into lowered IR")
    func sem606KeyedDefinition() throws {
        let cfg = """
        === vocabulary ===
        A service is a kind of thing.
        A service has a text called the name.
        A service is keyed by the name.
        """
        let mer = """
        Definition: a service is reliable if the deploy step succeeds in at least 90% of runs.

        To inspect a service:
          complete.
        """

        let defs = try loweredDefinitions(mer: mer, cfg: cfg)
        guard let only = defs.first else {
            Issue.record("expected one lowered definition")
            return
        }
        guard case .traceStatistical(let statistical) = only.body else {
            Issue.record("expected statistical body, got \(only.body)")
            return
        }
        #expect(statistical.subjectKeyExpr != nil)
    }

    @Test("SEM_6_04 `with 95% confidence` lowers Wilson interval metadata")
    func sem604ConfidenceLowering() throws {
        let workflow = try loweredWorkflow(
            mer: """
            To inspect traces:
              if the deploy step succeeds in at least 90% of runs with 95% confidence,
                complete.
              if it is unknown whether:
                complete.
              otherwise,
                complete.
            """,
            cfg: ""
        )
        guard let statistical = firstTraceStatistical(in: workflow.body) else {
            Issue.record("expected statistical branch")
            return
        }
        #expect(statistical.confidencePercent == 95)
    }

    @Test("SEM_4_10 cross-skill scope allowed when merconfig lists skills")
    func sem410CrossSkillAllowList() throws {
        let cfg = """
        === trace ===
        cross-skill allow-list: briefing, deploy
        """
        let workflow = try loweredWorkflow(
            mer: """
            To inspect traces:
              if across skills briefing, deploy, the fetch step of the briefing skill has ever failed,
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
        #expect(temporal.scope == .acrossSkills(["briefing", "deploy"]))
    }

    private func firstTraceStatistical(in block: IRBlock) -> TraceStatisticalIR? {
        for statement in block.statements {
            if case .branch(let branch) = statement,
               case .predicate(let predicate) = branch.condition,
               case .traceStatistical(let statistical) = predicate {
                return statistical
            }
        }
        return nil
    }

    private func firstTraceTemporal(in block: IRBlock) -> TraceTemporalIR? {
        for statement in block.statements {
            if case .branch(let branch) = statement,
               case .predicate(let predicate) = branch.condition,
               case .traceTemporal(let temporal) = predicate {
                return temporal
            }
        }
        return nil
    }

    @Test("SEM_6_05 syntactic analysis is conservative and transitive only")
    func sem605SyntacticAnalysisMatrix() throws {
        try expectDiagnostic(
            mer: """
            To inspect traces:
              if the deploy step succeeds in at least 90% of runs,
                complete.
            """,
            cfg: "",
            code: .traceMissingUnknownArm
        )
        try expectDiagnostic(
            mer: """
            Definition: a service is stale if the deploy step has ever failed.

            To inspect a service:
              if the service is stale since the last deploy step succeeded,
                complete.
            """,
            cfg: keyedServiceCfg,
            code: .traceMissingUnknownArm
        )
        try expectDiagnostic(
            mer: """
            Definition: a service is reliable if the deploy step succeeds in at least 90% of runs.
            Definition: a service is stable if it is reliable and its name is not empty.

            To inspect a service:
              if the service is stable,
                complete.
            """,
            cfg: """
            === vocabulary ===
            A service is a kind of thing.
            A service has a text called the name.
            A service is keyed by the name.
            """,
            code: .traceMissingUnknownArm
        )
        _ = try loweredWorkflow(
            mer: """
            To inspect a service:
              if the service's name is not empty,
                complete.
            """,
            cfg: keyedServiceCfg
        )
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

    private func loweredWorkflow(mer: String, cfg: String) throws -> IRWorkflow {
        let config = try MerConfigParser(trace: .silent()).parse(cfg, file: "t.merconfig")
        let symbols = SymbolTable.build(from: config, sourceFile: "t.merconfig", trace: .silent())
        let file = try MeridianParser(symbols: symbols, trace: .silent()).parse(mer, file: "t.meridian")
        // The lowerer's batch engine collects; this helper checkpoints so
        // direct-lower tests still observe errors as thrown `CompilerError`s.
        let engine = DiagnosticEngine(trace: .silent())
        let workflows = try ASTToIR(symbols: symbols, sourceFile: "t.meridian", trace: .silent(), engine: engine).lower(file)
        try engine.throwIfErrors()
        guard let workflow = workflows.first else {
            throw CompilerError.codegenError(message: "expected lowered workflow")
        }
        return workflow
    }

    private func loweredDefinitions(mer: String, cfg: String) throws -> [LoweredDefinition] {
        let config = try MerConfigParser(trace: .silent()).parse(cfg, file: "t.merconfig")
        let symbols = SymbolTable.build(from: config, sourceFile: "t.merconfig", trace: .silent())
        let file = try MeridianParser(symbols: symbols, trace: .silent()).parse(mer, file: "t.meridian")
        let lowering = ASTToIR(symbols: symbols, sourceFile: "t.meridian", trace: .silent(), engine: DiagnosticEngine())
        _ = try lowering.lower(file)
        return try lowering.lowerRegisteredDefinitions()
    }

    private var keyedServiceCfg: String {
        """
        === vocabulary ===
        A service is a kind of thing.
        A service has a text called the name.
        A service has a text called the status.
        A service is keyed by the name.
        """
    }
}
