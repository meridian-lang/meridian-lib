import Testing
import Foundation
@testable import MeridianCore
import MeridianRuntime

// Phase: ASTToIR closeout coverage. Targets the specific reachable branches
// left uncovered after `ReachableCoverageASTToIRTests` — rule-fallback
// strict-throw/no-engine paths, phrase-inlining substitution over every
// expression/statement shape, relation/verb error call sites that differ by
// position (scalar nav vs. active verb vs. description clause), and a few
// grammar corners (adjective-fallthrough, duplicate cross-kind adjectives,
// nested template interpolation). Genuinely unreachable branches (dead IR
// cases, defensive re-validation already guaranteed by
// `validateRelationsAndVerbs`) are intentionally left alone and documented in
// `docs/coverage/coverage-exclusions.md` rather than forced here.

@Suite("ASTToIR deep coverage — closeout")
struct ASTToIRDeepCoverageTests {

    private func compile(_ mer: String, _ cfg: String, trace: ParserTrace = .silent()) throws -> String {
        try Compiler(options: .init(
            emitterOptions: .init(includeTimestamp: false, emitSourceLineComments: false),
            trace: trace
        )).compile(
            meridianSource: mer, meridianFile: "t.meridian",
            merconfigSource: cfg, merconfigFile: "t.merconfig"
        )
    }

    private func expectThrows(_ mer: String, _ cfg: String, _ label: String) {
        do {
            _ = try compile(mer, cfg)
            Issue.record("\(label): expected the compile to throw")
        } catch {
            // expected
        }
    }

    /// Parse straight to a `MeridianFile` and lower with a `nil` engine (the
    /// historical first-error-throws path), bypassing `Compiler` — which
    /// always constructs a batch `DiagnosticEngine`. This is the only way to
    /// reach the no-engine `else` branches in `ASTToIR.lower`'s rule handling.
    private func lowerNoEngine(_ mer: String, symbols: SymbolTable = SymbolTable(),
                               fallbackPolicy: FallbackPolicy = .strict) throws -> [IRWorkflow] {
        let ast = try MeridianParser(symbols: symbols, trace: .silent()).parse(mer, file: "t.meridian")
        return try ASTToIR(symbols: symbols, sourceFile: "t.meridian", trace: .silent(),
                          fallbackPolicy: fallbackPolicy).lower(ast)
    }

    // MARK: - Rule fallback: strict-throw / no-engine branches

    @Test("an unparseable rule with no batch engine throws (strict policy)")
    func unparseableRuleNoEngineThrows() {
        let mer = """
        ---
        vocabulary: t.merconfig
        ---
        The gizmo requires frobnication.

        To run:
          complete.
        """
        #expect(throws: (any Error).self) { try lowerNoEngine(mer) }
    }

    @Test("an unattached rule with no batch engine throws (strict policy)")
    func unattachedRuleNoEngineThrows() {
        let mer = """
        ---
        vocabulary: t.merconfig
        ---
        A widget must not be tampered.

        To run:
          complete.
        """
        #expect(throws: (any Error).self) { try lowerNoEngine(mer) }
    }

    @Test("a rule that attaches cleanly with no batch engine lowers (no-engine success path)")
    func attachedRuleNoEngineSucceeds() throws {
        let mer = """
        ---
        vocabulary: t.merconfig
        ---
        A customer with status suspended must not place orders.

        To process an order placed by a customer:
          complete with reason "ok".
        """
        let workflows = try lowerNoEngine(mer)
        #expect(!workflows.isEmpty)
    }

    @Test("non-literal match branch pattern is a semantic lowering error")
    func nonLiteralMatchBranchPatternSemanticError() {
        let ast = MeridianFile(workflows: [
            WorkflowAST(
                pattern: PhrasePattern(segments: [.literal("route")]),
                body: ASTBlock(statements: [
                    .matchBranch(MatchBranchStatementAST(
                        subject: .identifierRef("choice"),
                        cases: [
                            MatchBranchCaseAST(
                                pattern: .literal(.identifierRef("choice")),
                                block: ASTBlock(statements: [.complete(CompleteStatementAST())])
                            )
                        ],
                        sourceLine: 3
                    ))
                ])
            )
        ])

        do {
            _ = try ASTToIR(symbols: SymbolTable(), sourceFile: "t.meridian", trace: .silent()).lower(ast)
            Issue.record("expected matchBranchSemantic")
        } catch let error as CompilerError {
            #expect(error.diagnostics.contains { diagnostic in
                diagnostic.code == .matchBranchSemantic
                    && diagnostic.message.contains("match-branch case pattern must be a literal")
            })
        } catch {
            Issue.record("unexpected error: \(error)")
        }
    }

    @Test("match branch lowering trace renders every pattern kind")
    func matchBranchTracePatternNames() throws {
        let cap = ParserTrace.capturing(categories: [.lowering])
        let ast = MeridianFile(workflows: [
            WorkflowAST(
                pattern: PhrasePattern(segments: [.literal("route")]),
                body: ASTBlock(statements: [
                    .matchBranch(MatchBranchStatementAST(
                        subject: .identifierRef("choice"),
                        cases: [
                            MatchBranchCaseAST(
                                pattern: .literal(.literal(.string("ready"))),
                                block: ASTBlock(statements: [.complete(CompleteStatementAST())])
                            ),
                            MatchBranchCaseAST(
                                pattern: .enumValue("approved"),
                                block: ASTBlock(statements: [.complete(CompleteStatementAST())])
                            ),
                            MatchBranchCaseAST(
                                pattern: .wildcard,
                                block: ASTBlock(statements: [.complete(CompleteStatementAST())])
                            ),
                        ],
                        otherwiseBlock: ASTBlock(statements: [.complete(CompleteStatementAST())]),
                        sourceLine: 3
                    ))
                ])
            )
        ])

        let workflows = try ASTToIR(symbols: SymbolTable(), sourceFile: "t.meridian", trace: cap.trace).lower(ast)
        #expect(workflows.first?.body.statements.count == 1)
        let trace = cap.lines().joined(separator: "\n")
        #expect(trace.contains("literal("), Comment(rawValue: trace))
        #expect(trace.contains("enum(approved)"), Comment(rawValue: trace))
        #expect(trace.contains("wildcard"), Comment(rawValue: trace))
    }

    @Test("direct modal statement lowering returns no primitives")
    func directModalStatementLowering() throws {
        let lowered = try ASTToIR(symbols: SymbolTable(), sourceFile: "t.meridian", trace: .silent())
            .lowerStatement(.modal(.lenient), mode: .strict, depth: 0)
        #expect(lowered.isEmpty)
    }

    // MARK: - `.modal` block marker + rebind-to-invoke

    @Test("`in lenient mode.` as a direct statement lowers to no primitive")
    func modalStatementLowersToNothing() throws {
        let symbols = SymbolTable()
        let ast = try MeridianParser(symbols: symbols, trace: .silent())
            .parse("To sync:\n  in lenient mode.\n  complete.\n", file: "t.meridian")
        let workflows = try ASTToIR(symbols: symbols, sourceFile: "t.meridian", trace: .silent()).lower(ast)
        #expect(workflows.first?.mode == .lenient)
        // The modal marker itself contributes no IR primitive — only `complete`.
        #expect(workflows.first?.body.statements.count == 1)
    }

    @Test("rebind to an invoke result lowers to an invoke, not a bind-of-invocation")
    func rebindToInvokeLowers() throws {
        let cfg = """
        === vocabulary ===
        An order is a kind of thing.
        === tools ===
        Charge Payment
        ==============
        ~ chargePayment(order: Order) : Order
        """
        let mer = """
        ---
        vocabulary: t.merconfig
        ---
        To process an order:
          bind result = invoke chargePayment with order = the order.
          rebind result = invoke chargePayment with order = the order.
          complete.
        """
        let swift = try compile(mer, cfg)
        #expect(swift.contains("chargePayment"))
    }

    // MARK: - Phrase inlining depth + missing argument

    @Test("a self-referential phrase hits the inline depth limit")
    func phraseInlineDepthExceeded() {
        let cfg = """
        === vocabulary ===
        An order is a kind of thing.

        To loop forever with an order:
          loop forever with the order.
        """
        let mer = """
        ---
        vocabulary: t.merconfig
        ---
        To run for an order:
          loop forever with the order.
        """
        expectThrows(mer, cfg, "phrase-inline-depth-exceeded")
    }

    // MARK: - Phrase-arg substitution over every expression/statement shape

    @Test("inlining a phrase substitutes through rebind/simultaneously/labelled statements")
    func substituteArgsStatementShapes() throws {
        let cfg = """
        === vocabulary ===
        An order is a kind of thing.
        An order has a total, which is Money.

        To settle an order:
          rebind total = 0.
          simultaneously:
            complete with reason "a".
            complete with reason "b".
        """
        let mer = """
        ---
        vocabulary: t.merconfig
        ---
        To run for an order:
          settle the order.
        """
        let swift = try compile(mer, cfg)
        #expect(swift.contains("struct"))
    }

    @Test("inlining a phrase substitutes through a labelled statement")
    func substituteArgsLabelledStatement() throws {
        let cfg = """
        === vocabulary ===
        An order is a kind of thing.

        To settle an order:
          My step: complete with reason "done".
        """
        let mer = """
        ---
        vocabulary: t.merconfig
        ---
        To run for an order:
          settle the order.
        """
        let swift = try compile(mer, cfg)
        #expect(swift.contains("struct"))
    }

    // MARK: - Direct substituteArgs (shapes merconfig phrase parsing can't build)

    // Merconfig `=== vocabulary ===` phrase bodies are parsed with
    // `StatementParser(symbols: nil, …)`, so relational atoms inside a phrase
    // body collapse to bare `identifierRef` strings. `substituteArgs`/`subExpr`
    // still must handle every `ExpressionAST` case for workflow-phrase inlining
    // and other callers — exercise them directly here.
    @Test("substituteArgs recurses through every ExpressionAST case when invoked directly")
    func substituteArgsDirectExpressionShapes() {
        let lowering = ASTToIR(symbols: SymbolTable(), sourceFile: "t.meridian", trace: .silent())
        let userExpr = ExpressionAST.identifierRef("the substituted user")
        let args = ["the user": userExpr]

        let desc = DescriptionAST(
            noun: "pages",
            wherePredicate: .identifierRef("the user"),
            verbClauses: [
                VerbClauseAST(verbForm: "owned", operand: .identifierRef("the user"), elementIsSubject: false),
            ]
        )
        let value: ExpressionAST = .logical(.and, [
            .verbPredicate(subject: .identifierRef("the user"), verb: "owns", object: .identifierRef("the page")),
            .relationTraversal(.identifierRef("the user"), relation: "owned", navKind: "page"),
            .description(desc),
            .aggregate(.count, desc),
            .superlative(SuperlativeAST(description: desc, property: "view count", ascending: false)),
            .interpolatedString([
                .expression(.identifierRef("the user")),
                .conditional(
                    condition: .identifierRef("the user"),
                    then: [
                        .forEach(
                            variable: "row",
                            collection: .identifierRef("the user"),
                            body: [
                                .conditional(
                                    condition: .identifierRef("the user"),
                                    then: [.literal("x")],
                                    otherwise: []
                                ),
                            ]
                        ),
                    ],
                    otherwise: []
                ),
                .forEach(
                    variable: "row",
                    collection: .identifierRef("the user"),
                    body: [.literal("x")]
                ),
                .formatted(.identifierRef("the user"), formatter: "integer"),
            ]),
            .recordList(fields: ["name"], rows: [[.identifierRef("the user")]]),
            .tableLookup(table: "prices", keyColumn: "sku", key: .identifierRef("the user"), valueColumn: "price"),
        ])
        let block = ASTBlock(statements: [
            .bind(BindStatementAST(name: "x", value: value, sourceLine: 1)),
            .matchBranch(MatchBranchStatementAST(
                subject: .identifierRef("the user"),
                cases: [
                    MatchBranchCaseAST(
                        pattern: .literal(.identifierRef("the user")),
                        block: ASTBlock(statements: [
                            .bind(BindStatementAST(name: "caseValue", value: .identifierRef("the user")))
                        ])
                    ),
                    MatchBranchCaseAST(pattern: .enumValue("approved"), block: ASTBlock(statements: [])),
                    MatchBranchCaseAST(pattern: .wildcard, block: ASTBlock(statements: [])),
                ],
                otherwiseBlock: ASTBlock(statements: [
                    .bind(BindStatementAST(name: "otherwiseValue", value: .identifierRef("the user")))
                ]),
                sourceLine: 3
            )),
            .proseStep(ProseStepAST(text: "the user", sourceLine: 2)),
        ], sourceLine: 1)

        let out = lowering.substituteArgs(block, args: args)
        guard case .bind(let bind) = out.statements[0],
              case .logical(_, let exprs) = bind.value else {
            Issue.record("expected substituted bind with logical expression")
            return
        }
        #expect(exprs.count == 8)
        if case .verbPredicate(let sub, _, let obj) = exprs[0] {
            if case .identifierRef(let subName) = sub {
                #expect(subName == "the substituted user")
            } else {
                Issue.record("expected identifierRef subject after substitution")
            }
            if case .identifierRef(let objName) = obj {
                #expect(objName == "the page")
            } else {
                Issue.record("expected identifierRef object")
            }
        } else {
            Issue.record("expected verbPredicate after substitution")
        }
        guard case .matchBranch(let match) = out.statements[1] else {
            Issue.record("expected substituted matchBranch")
            return
        }
        if case .identifierRef(let subjectName) = match.subject {
            #expect(subjectName == "the substituted user")
        } else {
            Issue.record("expected substituted match subject")
        }
        if case .literal(.identifierRef(let patternName)) = match.cases[0].pattern {
            #expect(patternName == "the substituted user")
        } else {
            Issue.record("expected substituted literal match pattern")
        }
        guard case .bind(let caseBind) = match.cases[0].block.statements.first else {
            Issue.record("expected substituted match case bind")
            return
        }
        if case .identifierRef(let caseValueName) = caseBind.value {
            #expect(caseValueName == "the substituted user")
        } else {
            Issue.record("expected substituted match case bind value")
        }
        guard case .enumValue("approved") = match.cases[1].pattern else {
            Issue.record("expected enum match pattern to survive")
            return
        }
        guard case .wildcard = match.cases[2].pattern else {
            Issue.record("expected wildcard match pattern to survive")
            return
        }
        guard case .bind(let otherwiseBind) = match.otherwiseBlock?.statements.first else {
            Issue.record("expected substituted otherwise bind")
            return
        }
        if case .identifierRef(let otherwiseName) = otherwiseBind.value {
            #expect(otherwiseName == "the substituted user")
        } else {
            Issue.record("expected substituted otherwise bind value")
        }
        guard case .proseStep(let prose) = out.statements[2] else {
            Issue.record("expected proseStep passthrough")
            return
        }
        #expect(prose.text == "the user")
    }

    // Compile-time phrase inlining can't build the relational cases (merconfig
    // phrase bodies parse with `symbols: nil`); `.quantified`, `.logical`,
    // `.comparison`, `.propertyAccess` ARE constructible that way.
    @Test("inlining a phrase substitutes through logical/quantified/comparison/property-access expressions")
    func substituteArgsExpressionShapes() throws {
        let cfg = """
        === vocabulary ===
        A page is a kind of thing.
        A page has an owner, which is a String.

        To audit a page:
          if the page's owner is "none" and any page is "stale",
            let owned be the page's owner.
        """
        let mer = """
        ---
        vocabulary: t.merconfig
        ---
        To run for a page:
          audit the page.
        """
        let swift = try compile(mer, cfg)
        #expect(swift.contains("struct"))
    }

    // `AggregateGrammar`/`SuperlativeGrammar` also require a non-nil symbol
    // table (see the note above `substituteArgsExpressionShapes`), so they're
    // unreachable from a merconfig phrase body too. `recordList` (built by
    // `StatementParser.dataTableBinding`, a `!!! table (( data table ))`
    // marker) and `tableLookup` (`TableLookupGrammar`, tried before the
    // `symbols != nil` gate in `ExpressionParser.parseAtom`) need no symbol
    // table, so both ARE reachable here.
    @Test("inlining a phrase substitutes through recordList/tableLookup expressions")
    func substituteArgsRecordListTableLookupExpressions() throws {
        let cfg = """
        === vocabulary ===
        A page is a kind of thing.

        To summarize a page:
          !!! table (( data table: prices ))
          | sku | price |
          | --- | --- |
          | SKU1 | 10 |
          let looked be the price corresponding to the sku "SKU1" in the prices table.
        """
        let mer = """
        ---
        vocabulary: t.merconfig
        ---
        To run for a page:
          summarize the page.
        """
        let swift = try compile(mer, cfg)
        #expect(swift.contains("struct"))
    }

    // `.interpolatedString` (an `ExpressionAST` case) is only produced from a
    // fenced code block whose body contains `{{ … }}`/`[if …]`/`[for each …]`
    // template directives (`ExpressionParser.parseAtom`'s code-block-sentinel
    // branch) — a bare quoted string with `{if}`/`{end if}` markers is just a
    // string literal. Use a real fenced template so `subExpr`'s
    // `.interpolatedString` case (and its nested `.conditional`/`.forEach`
    // segment substitution) actually runs.
    @Test("inlining a phrase substitutes through an interpolated string with a conditional segment")
    func substituteArgsInterpolatedStringSegments() throws {
        let cfg = """
        === vocabulary ===
        A user is a kind of thing.
        A user has a name, which is a String.

        To greet a user:
          bind report =
            ```
            [if the user's name is "x"]yes[otherwise]no[end if]
            ```
          emit greeting.sent with body = report.
        """
        let mer = """
        ---
        vocabulary: t.merconfig
        ---
        To run for a user:
          greet the user.
        """
        let swift = try compile(mer, cfg)
        #expect(swift.contains("struct"))
    }

    // MARK: - Nested template interpolation (conditional/forEach inside for-each body)

    // Template interpolation is only recognized inside a fenced code block
    // whose body contains `{{ … }}`/`[if …]`/`[for each …]` directives
    // (`ExpressionParser.parseAtom`) — a plain quoted string with `{for
    // each}`/`{if}` markers is just a literal. This exercises
    // `ASTToIR.lowerInterpolationSegments`'s `.forEach` case with a nested
    // `.conditional` segment in its body (both otherwise-uncovered branches
    // in one fixture).
    @Test("a for-each template segment whose body contains a nested conditional lowers both levels")
    func nestedInterpolationConditionalInsideForEach() throws {
        let cfg = """
        === vocabulary ===
        An order is a kind of thing.
        """
        let mer = """
        ---
        vocabulary: t.merconfig
        ---
        To run:
          bind report =
            ```
            [for each item in items][if item is "a"]A[otherwise]B[end if][end for]
            ```
          emit report.sent with body = report.
        """
        let swift = try compile(mer, cfg)
        #expect(swift.contains("struct"))
    }

    // MARK: - Adjective / definition edge cases

    @Test("`X is <adjective>` falls through to a normal comparison when X is not in subject position")
    func adjectiveNotSubjectPositionFallsThrough() throws {
        let cfg = """
        === vocabulary ===
        A page is a kind of thing.
        A page has an owner, which is a String.
        Definition: a page is stale if its owner is "none".
        """
        let mer = """
        ---
        vocabulary: t.merconfig
        ---
        To run for a page:
          if the page's owner is stale,
            complete with reason "matched".
        """
        let swift = try compile(mer, cfg)
        #expect(swift.contains("struct"))
    }

    @Test("the same adjective word defined for two different kinds is a hard error")
    func duplicateAdjectiveAcrossKinds() {
        let cfg = """
        === vocabulary ===
        A page is a kind of thing.
        A page has an owner, which is a String.
        A task is a kind of thing.
        A task has an owner, which is a String.
        Definition: a page is stale if its owner is "none".
        Definition: a task is stale if its owner is "none".
        """
        expectThrows("""
        ---
        vocabulary: t.merconfig
        ---
        To run:
          complete.
        """, cfg, "duplicate-adjective-across-kinds")
    }

    @Test("a definition body combining two property accesses with `and` walks both operands")
    func definitionBodyLogicalWalksProperties() throws {
        let cfg = """
        === vocabulary ===
        A page is a kind of thing.
        A page has a view count, which is a Number.
        A page has an owner, which is a String.
        Definition: a page is stale if its view count is less than 100 and its owner is "none".
        """
        let mer = """
        ---
        vocabulary: t.merconfig
        ---
        To run for a page:
          if the page is stale,
            complete with reason "matched".
        """
        let swift = try compile(mer, cfg)
        #expect(swift.contains("struct"))
    }

    @Test("a definition body referencing two other adjectives via `and` recurses through both")
    func definitionBodyReferencedAdjectivesLogical() throws {
        let cfg = """
        === vocabulary ===
        A page is a kind of thing.
        A page has an owner, which is a String.
        A page has a status, which is a String.
        Definition: a page is stale if its owner is "none".
        Definition: a page is hidden if its status is "off".
        Definition: a page is dormant if it is stale and it is hidden.
        """
        let mer = """
        ---
        vocabulary: t.merconfig
        ---
        To run for a page:
          if the page is dormant,
            complete with reason "matched".
        """
        let swift = try compile(mer, cfg)
        #expect(swift.contains("struct"))
    }

    // MARK: - `wait for event ... matching ...`

    @Test("wait for event with a matching predicate lowers the predicate")
    func waitEventMatchingLowers() throws {
        let cfg = """
        === vocabulary ===
        An order is a kind of thing.
        An order has an id, which is a String.
        """
        let mer = """
        ---
        vocabulary: t.merconfig
        ---
        To run for an order:
          wait for event payment.confirmed matching the order's id is "o-1".
          complete.
        """
        let swift = try compile(mer, cfg)
        #expect(swift.contains(".event("))
    }

    // MARK: - Verb-form ambiguity + active-verb-condition backing sides

    @Test("two different verbs whose conjugated forms collide is a hard error")
    func ambiguousVerbFormAcrossRelations() {
        // Different bases ("own" / "possess") but the SAME third-person form
        // ("owns") — `symbols.verbs` is keyed by base, so this is the only way
        // to get two live verb registrations whose forms actually collide.
        let cfg = """
        === vocabulary ===
        A user is a kind of thing.
        A page is a kind of thing.
        A page has an owner, which is a String.
        A task is a kind of thing.
        A task has an assignee, which is a String.
        Ownership relates one user to various pages.
        Ownership is read from the page's owner.
        The verb to own (it owns, it is owned) means the ownership relation.
        Assignment relates one user to various tasks.
        Assignment is read from the task's assignee.
        The verb to possess (it owns, it is possessed) means the assignment relation.
        """
        expectThrows("""
        ---
        vocabulary: t.merconfig
        ---
        To run:
          complete.
        """, cfg, "ambiguous-verb-form")
    }

    @Test("an active verb condition backed on the relation's left kind takes the left-side branch")
    func activeVerbConditionLeftKindBacking() throws {
        let cfg = """
        === vocabulary ===
        A user is a kind of thing.
        A user has a task, which is a String.
        A task is a kind of thing.
        Assignment relates one user to one task.
        Assignment is read from the user's task.
        The verb to assign (it assigns, it is assigned) means the assignment relation.
        """
        let mer = """
        ---
        vocabulary: t.merconfig
        ---
        To run for a user and a task:
          if the user assigns the task,
            complete with reason "matched".
        """
        let swift = try compile(mer, cfg)
        #expect(swift.contains(".identifies"))
    }

    // MARK: - Description clause / element-kind errors

    @Test("a property-backed relation clause whose backing kind doesn't match the description's element is a hard error")
    func propertyBackedRelationWrongElement() {
        let cfg = """
        === vocabulary ===
        A user is a kind of thing.
        A page is a kind of thing.
        A page has an owner, which is a String.
        A deal is a kind of thing.
        Ownership relates one user to various pages.
        Ownership is read from the page's owner.
        The verb to own (it owns, it is owned) means the ownership relation.
        """
        expectThrows("""
        ---
        vocabulary: t.merconfig
        ---
        To run for a user:
          let owned be the deals owned by the user.
        """, cfg, "property-backed-relation-wrong-element")
    }

    // MARK: - Fallback policy with batch engine (allow-fallbacks log paths)

    @Test("an unparseable rule with a batch engine reports instead of throwing (strict policy)")
    func unparseableRuleWithEngineReports() throws {
        let engine = DiagnosticEngine(trace: .silent())
        let file = MeridianFile(
            rules: [RuleAST(text: "The gizmo requires frobnication.", sourceLine: 3)],
            workflows: [
                WorkflowAST(
                    pattern: PhrasePattern(segments: [.literal("run")]),
                    body: ASTBlock(statements: [
                        .complete(CompleteStatementAST(reason: nil, sourceLine: 5)),
                    ], sourceLine: 5),
                    sourceLine: 5,
                ),
            ]
        )
        _ = try ASTToIR(
            symbols: SymbolTable(),
            sourceFile: "t.meridian",
            trace: .silent(),
            fallbackPolicy: .strict,
            engine: engine
        ).lower(file)
        #expect(engine.errors.contains { $0.code == .unparseableRule })
    }

    @Test("an unattached rule with a batch engine reports instead of throwing (strict policy)")
    func unattachedRuleWithEngineReports() throws {
        let engine = DiagnosticEngine(trace: .silent())
        let file = MeridianFile(
            rules: [RuleAST(text: "A widget must not be tampered.", sourceLine: 3)],
            workflows: [
                WorkflowAST(
                    pattern: PhrasePattern(segments: [.literal("run")]),
                    body: ASTBlock(statements: [
                        .complete(CompleteStatementAST(reason: nil, sourceLine: 5)),
                    ], sourceLine: 5),
                    sourceLine: 5,
                ),
            ]
        )
        _ = try ASTToIR(
            symbols: SymbolTable(),
            sourceFile: "t.meridian",
            trace: .silent(),
            fallbackPolicy: .strict,
            engine: engine
        ).lower(file)
        #expect(engine.errors.contains { $0.code == .unattachedRule })
    }

    @Test("allow-fallbacks: unparseable-rules logs and drops instead of throwing")
    func allowFallbacksUnparseableRuleLogs() throws {
        let cap = ParserTrace.capturing()
        let file = MeridianFile(
            rules: [RuleAST(text: "The gizmo requires frobnication.", sourceLine: 3)],
            workflows: [
                WorkflowAST(
                    pattern: PhrasePattern(segments: [.literal("run")]),
                    body: ASTBlock(statements: [
                        .complete(CompleteStatementAST(reason: nil, sourceLine: 5)),
                    ], sourceLine: 5),
                    sourceLine: 5,
                ),
            ]
        )
        _ = try ASTToIR(
            symbols: SymbolTable(),
            sourceFile: "t.meridian",
            trace: cap.trace,
            fallbackPolicy: FallbackPolicy(allowed: [.unparseableRules])
        ).lower(file)
        #expect(cap.lines().contains { $0.contains("unparseable") || $0.contains("allow-fallbacks") })
    }

    // MARK: - Workflow phrase stub: missing required argument

    @Test("invoking a workflow phrase without a required parameter is a hard error")
    func missingWorkflowPhraseArgument() throws {
        let symbols = SymbolTable()
        let pattern = PhrasePattern(segments: [
            .literal("bill a "),
            .parameter(PhraseParameterAST(name: "customer", kind: "customer")),
            .literal(" for an "),
            .parameter(PhraseParameterAST(name: "order", kind: "order")),
        ])
        symbols.registerWorkflowPhrase(
            pattern: pattern, structName: "BillACustomerForAnOrder", sourceLine: 1, sourceFile: "t.merconfig")
        let lowering = ASTToIR(symbols: symbols, sourceFile: "t.meridian", trace: .silent())
        #expect(throws: (any Error).self) {
            try lowering.lowerPhraseInvocation(
                PhraseInvocationAST(words: "bill a customer", sourceLine: 2),
                mode: .strict,
                depth: 0
            )
        }
    }

    // MARK: - Instance ref + env-var expression lowering

    @Test("a declared instance and an env-var reference lower in expressions")
    func instanceRefAndEnvVarLower() throws {
        let cfg = """
        === vocabulary ===
        A mailer server is a kind of thing.
        === instances ===
        There is a mailer server called primary with host = "smtp.example.com".
        """
        let mer = """
        ---
        vocabulary: t.merconfig
        ---
        To run:
          let host be the primary's host.
          let home be $HOME.
          complete.
        """
        let swift = try compile(mer, cfg)
        #expect(swift.contains("instances.primaryMailer") || swift.contains("primary"))
        #expect(swift.contains("ProcessInfo") || swift.contains("environment"))
    }

    // MARK: - Prose disallowed (hand-built AST — parser always sets dispatch)

    @Test("a prose step with no dispatch in a strict workflow is a hard error")
    func proseDisallowedInStrictWorkflow() {
        let pattern = PhrasePattern(segments: [.literal("run")])
        let body = ASTBlock(statements: [
            .proseStep(ProseStepAST(text: "fuzzy planner step", sourceLine: 2, dispatch: nil)),
        ], sourceLine: 1)
        let file = MeridianFile(workflows: [
            WorkflowAST(pattern: pattern, body: body, sourceLine: 1),
        ])
        #expect(throws: (any Error).self) {
            try ASTToIR(symbols: SymbolTable(), sourceFile: "t.meridian", trace: .silent()).lower(file)
        }
    }

    // MARK: - Direct lowerExpr quantifier / description semantic errors

    private func lowering(forConfig cfg: String, engine: DiagnosticEngine? = nil) throws -> ASTToIR {
        let config = try MerConfigParser(trace: .silent()).parse(cfg, file: "t.merconfig")
        let symbols = SymbolTable.build(from: config, sourceFile: "t.merconfig")
        return ASTToIR(symbols: symbols, sourceFile: "t.meridian", trace: .silent(), engine: engine)
    }

    private let wave3RelCfg = """
    === vocabulary ===
    A user is a kind of thing.
    A user has a name, which is a String.
    A user has a task, which is a String.
    A task is a kind of thing.
    A page is a kind of thing.
    A page has an owner, which is a String.
    An entity is a kind of thing.
    Ownership relates one user to various pages.
    Ownership is read from the page's owner.
    The verb to own (it owns, it is owned) means the ownership relation.
    Assignment relates one user to one task.
    Assignment is read from the user's task.
    The verb to assign (it assigns, it is assigned) means the assignment relation.
    Mentioning relates various pages to various entities.
    Mentioning is read via the link tool.
    The verb to mention (it mentions, it is mentioned) means the mentioning relation.
    Escalation relates one task to one user.
    Escalation is read via the escalate tool.
    The verb to escalate (it escalates, it is escalated) means the escalation relation.
    === tools ===
    List Pages
    ==============
    ~ listPages(owner: String) : List
    Link
    ====
    ~ link(entity: String) : List

    Escalate
    ========
    ~ escalate(task: String) : Record
    """

    @Test("a quantifier with an empty collection noun is a semantic error")
    func quantifierEmptyNounErrors() throws {
        let lowering = try lowering(forConfig: """
        === vocabulary ===
        A page is a kind of thing.
        """)
        let q = QuantifierAST(
            kind: .any,
            description: DescriptionAST(noun: ""),
            body: .comparison(.identifierRef("page"), .equal, .identifierRef("stale")))
        #expect(throws: (any Error).self) {
            try lowering.lowerExpr(ExpressionAST.quantified(q))
        }
    }

    @Test("`all <description>` without a body or restriction is a semantic error")
    func quantifierAllWithoutBodyErrors() throws {
        let lowering = try lowering(forConfig: """
        === vocabulary ===
        A page is a kind of thing.
        """)
        let q = QuantifierAST(kind: .all, description: DescriptionAST(noun: "pages"), body: nil)
        #expect(throws: (any Error).self) {
            try lowering.lowerExpr(ExpressionAST.quantified(q))
        }
    }

    @Test("a description with an empty noun is a semantic error")
    func descriptionEmptyNounErrors() throws {
        let lowering = try lowering(forConfig: """
        === vocabulary ===
        A page is a kind of thing.
        """)
        #expect(throws: (any Error).self) {
            try lowering.lowerExpr(ExpressionAST.description(DescriptionAST(noun: "")))
        }
    }

    // MARK: - Iteration refinement with adjective + unknown verb / backing errors

    @Test("for each over an adjective-filtered collection lowers definition predicates on the loop var")
    func iterationAdjectiveRefinementLowers() throws {
        let cfg = """
        === vocabulary ===
        A page is a kind of thing.
        A page has an owner, which is a String.
        Definition: a page is stale if its owner is "none".
        """
        let mer = """
        ---
        vocabulary: t.merconfig
        ---
        To run:
          let pages be "a,b".
          for each stale page in pages,
            complete with reason "ok".
        """
        let swift = try compile(mer, cfg)
        #expect(swift.contains("struct"))
    }

    @Test("an unknown verb form in scalar navigation is a hard error")
    func unknownVerbInScalarNavigation() throws {
        let lowering = try lowering(forConfig: """
        === vocabulary ===
        A user is a kind of thing.
        A task is a kind of thing.
        A task has an assignee, which is a String.
        Assignment relates one user to one task.
        Assignment is read from the task's assignee.
        The verb to assign (it assigns, it is assigned) means the assignment relation.
        """)
        #expect(throws: (any Error).self) {
            try lowering.lowerExpr(ExpressionAST.relationTraversal(
                .identifierRef("the user"),
                relation: "frobnicated",
                navKind: "task"))
        }
    }

    @Test("active verb backing on a kind that is not a relation side is a hard error")
    func verbBackingKindNotRelationSide() {
        let cfg = """
        === vocabulary ===
        A user is a kind of thing.
        A task is a kind of thing.
        A page is a kind of thing.
        A page has an owner, which is a String.
        Assignment relates one user to one task.
        Assignment is read from the page's owner.
        The verb to assign (it assigns, it is assigned) means the assignment relation.
        """
        expectThrows("""
        ---
        vocabulary: t.merconfig
        ---
        To run for a user and a task:
          if the user assigns the task,
            complete.
        """, cfg, "verb-backing-not-relation-side")
    }

    // MARK: - Template interpolation: for-each segment lowering

    @Test("a fenced template with a for-each segment lowers the collection and body")
    func templateForEachSegmentLowers() throws {
        let cfg = """
        === vocabulary ===
        An order is a kind of thing.
        """
        let mer = """
        ---
        vocabulary: t.merconfig
        ---
        To run:
          let items be "a, b".
          bind report =
            ```
            [for each item in items]{{ item }}[end for]
            ```
          emit report.sent with body = report.
        """
        let swift = try compile(mer, cfg)
        #expect(swift.contains("struct"))
    }

    // MARK: - Shell command hole walks comparison-shaped lowered IR

    @Test("a command hole containing a comparison expression validates identifier roots")
    func shellHoleComparisonRoots() throws {
        let cfg = """
        === vocabulary ===
        A user is a kind of thing.
        A user has a role, which is a String.
        A user has a name, which is a String.
        """
        let mer = """
        ---
        vocabulary: t.merconfig
        ---
        To run for a user:
          `echo {the user's role is the user's name}`.
        """
        let swift = try compile(mer, cfg)
        #expect(swift.contains("shell.run") || swift.contains("struct"))
    }

    @Test("a command hole containing a logical expression walks both operand roots")
    func shellHoleLogicalRoots() throws {
        let mer = """
        ---
        vocabulary: t.merconfig
        ---
        To run for a user:
          `echo {the user's role is the user's name and the user's task is the user's name}`.
        """
        let swift = try compile(mer, wave3RelCfg)
        #expect(swift.contains("shell.run") || swift.contains("struct"))
    }

    @Test("a command hole containing scalar relation navigation walks traversal-shaped IR roots")
    func shellHoleRelationTraversalRoots() throws {
        let mer = """
        ---
        vocabulary: t.merconfig
        ---
        To run for a user:
          `echo {the task assigned to the user}`.
        """
        let swift = try compile(mer, wave3RelCfg)
        #expect(swift.contains("shell.run") || swift.contains("struct"))
    }

    // MARK: - Direct lowerExpr / lowerInterpolationSegments hooks

    @Test("a malformed expression with a batch engine reports before throwing")
    func malformedExprWithEngineReports() throws {
        let engine = DiagnosticEngine(trace: .silent())
        let lowering = try lowering(forConfig: """
        === vocabulary ===
        A page is a kind of thing.
        """, engine: engine)
        var thrown: [Diagnostic] = []
        do {
            _ = try lowering.lowerExpr(.malformed("mixed and/or"))
        } catch let CompilerError.diagnostics(diags) {
            thrown = diags
        } catch {
            Issue.record("expected CompilerError.diagnostics, got \(error)")
        }
        #expect(thrown.contains { $0.code == .malformedCondition || $0.message.contains("mixed and/or") })
        // Direct lowerExpr throws without pre-reporting into the engine; batch
        // recovery (`DiagnosticEngine.recovering`) is what collects into engine.errors.
        #expect(engine.errors.isEmpty)
    }

    @Test("lowerExpr lowers a bare invoke expression to IR invocation")
    func lowerExprInvokeDirect() throws {
        let lowering = try lowering(forConfig: """
        === vocabulary ===
        A user is a kind of thing.
        === tools ===
        List Pages
        ==============
        ~ listPages(owner: String) : List
        """)
        let ir = try lowering.lowerExpr(.invoke("listPages", [("owner", .literal(.string("u1")))]))
        guard case .invocation(let invoke) = ir else {
            Issue.record("expected invocation IR")
            return
        }
        #expect(invoke.toolID == "listPages")
    }

    @Test("lowerInterpolationSegments lowers for-each nested inside a conditional branch")
    func lowerInterpolationForEachNestedInConditional() throws {
        let lowering = ASTToIR(symbols: SymbolTable(), sourceFile: "t.meridian", trace: .silent())
        let ir = try lowering.lowerExpr(.interpolatedString([
            .conditional(
                condition: .literal(.string("t")),
                then: [.forEach(
                    variable: "item",
                    collection: .identifierRef("items"),
                    body: [.literal("x")]
                )],
                otherwise: []),
        ]))
        guard case .interpolatedString(let segs) = ir else {
            Issue.record("expected interpolatedString IR")
            return
        }
        #expect(segs.count == 1)
    }

    // MARK: - Description / iteration / scalar-nav reachable branches

    @Test("a description whose clause lowers a where-predicate qualifies it to the element var")
    func descriptionWherePredicateQualifies() throws {
        let mer = """
        ---
        vocabulary: t.merconfig
        ---
        To run for a user:
          let owned be the pages whose owner is "none".
          complete with reason "ok".
        """
        let swift = try compile(mer, wave3RelCfg)
        #expect(swift.contains("struct"))
    }

    @Test("for each with a bare boolean whose clause qualifies the loop variable")
    func iterationWhoseBareBooleanQualifies() throws {
        let cfg = """
        === vocabulary ===
        A page is a kind of thing.
        A page has an archived, which is a Boolean.
        """
        let mer = """
        ---
        vocabulary: t.merconfig
        ---
        To run:
          let pages be "a,b".
          for each page in pages whose archived,
            complete with reason "ok".
        """
        let swift = try compile(mer, cfg)
        #expect(swift.contains("struct"))
    }

    @Test("scalar navigation to a various-cardinality side is a hard error")
    func scalarNavVariousCardinalityErrors() {
        expectThrows("""
        ---
        vocabulary: t.merconfig
        ---
        To run for a user:
          let p be the page owned by the user.
        """, wave3RelCfg, "scalar-nav-various")
    }

    @Test("tool-backed scalar navigation in a value expression is a hard error")
    func toolBackedScalarNavInlineErrors() throws {
        let lowering = try lowering(forConfig: wave3RelCfg)
        #expect(throws: (any Error).self) {
            try lowering.lowerExpr(ExpressionAST.relationTraversal(
                .identifierRef("the task"),
                relation: "escalated",
                navKind: "user"))
        }
    }

    @Test("an unknown verb in an active verb predicate is a hard error")
    func unknownVerbInVerbPredicate() throws {
        let lowering = try lowering(forConfig: wave3RelCfg)
        #expect(throws: (any Error).self) {
            try lowering.lowerExpr(ExpressionAST.verbPredicate(
                subject: .identifierRef("the user"),
                verb: "frobnicates",
                object: .identifierRef("the page")))
        }
    }

    @Test("an active verb whose relation has no backing is a hard error")
    func verbPredicateUnbackedRelationErrors() throws {
        let lowering = try lowering(forConfig: """
        === vocabulary ===
        A user is a kind of thing.
        A task is a kind of thing.
        Assignment relates one user to one task.
        The verb to assign (it assigns, it is assigned) means the assignment relation.
        """)
        #expect(throws: (any Error).self) {
            try lowering.lowerExpr(ExpressionAST.verbPredicate(
                subject: .identifierRef("the user"),
                verb: "assigns",
                object: .identifierRef("the task")))
        }
    }

    @Test("active verb backing on a kind that is not a relation side is a hard error (direct lowerExpr)")
    func verbPredicateWrongBackingSideErrors() throws {
        let lowering = try lowering(forConfig: """
        === vocabulary ===
        A user is a kind of thing.
        A task is a kind of thing.
        A page is a kind of thing.
        A page has an owner, which is a String.
        Assignment relates one user to one task.
        Assignment is read from the page's owner.
        The verb to assign (it assigns, it is assigned) means the assignment relation.
        """)
        #expect(throws: (any Error).self) {
            try lowering.lowerExpr(ExpressionAST.verbPredicate(
                subject: .identifierRef("the user"),
                verb: "assigns",
                object: .identifierRef("the task")))
        }
    }

    @Test("scalar navigation through an unbacked relation is a hard error")
    func scalarNavUnbackedRelationErrors() throws {
        let lowering = try lowering(forConfig: """
        === vocabulary ===
        A user is a kind of thing.
        A task is a kind of thing.
        Assignment relates one user to one task.
        The verb to assign (it assigns, it is assigned) means the assignment relation.
        """)
        #expect(throws: (any Error).self) {
            try lowering.lowerExpr(ExpressionAST.relationTraversal(
                .identifierRef("the user"),
                relation: "assigned",
                navKind: "task"))
        }
    }

    @Test("an unknown verb in a description clause is a hard error")
    func descriptionClauseUnknownVerbErrors() throws {
        let lowering = try lowering(forConfig: wave3RelCfg)
        let d = DescriptionAST(
            noun: "pages",
            verbClauses: [
                VerbClauseAST(
                    verbForm: "frobnicates",
                    operand: .identifierRef("the user"),
                    elementIsSubject: false),
            ])
        #expect(throws: (any Error).self) {
            try lowering.lowerExpr(.description(d))
        }
    }

    @Test("a description clause naming an unbacked relation is a hard error")
    func descriptionClauseUnbackedRelationErrors() throws {
        let lowering = try lowering(forConfig: """
        === vocabulary ===
        A user is a kind of thing.
        A page is a kind of thing.
        Ownership relates one user to various pages.
        The verb to own (it owns, it is owned) means the ownership relation.
        """)
        let d = DescriptionAST(
            noun: "pages",
            verbClauses: [
                VerbClauseAST(
                    verbForm: "owned",
                    operand: .identifierRef("the user"),
                    elementIsSubject: false),
            ])
        #expect(throws: (any Error).self) {
            try lowering.lowerExpr(.description(d))
        }
    }

    @Test("a description with two tool-backed relation clauses is a hard error")
    func descriptionTwoToolClausesErrors() throws {
        let lowering = try lowering(forConfig: wave3RelCfg)
        let d = DescriptionAST(
            noun: "pages",
            verbClauses: [
                VerbClauseAST(
                    verbForm: "mention",
                    operand: .identifierRef("entity"),
                    elementIsSubject: false),
                VerbClauseAST(
                    verbForm: "mention",
                    operand: .identifierRef("otherEntity"),
                    elementIsSubject: false),
            ])
        let file = MeridianFile(workflows: [
            WorkflowAST(
                pattern: PhrasePattern(segments: [
                    .literal("run for an "),
                    .parameter(PhraseParameterAST(name: "entity", kind: "entity")),
                    .literal(" and another "),
                    .parameter(PhraseParameterAST(name: "otherEntity", kind: "entity")),
                ]),
                body: ASTBlock(statements: [
                    .bind(BindStatementAST(name: "bad", value: .description(d), sourceLine: 2)),
                    .complete(CompleteStatementAST(reason: nil, sourceLine: 3)),
                ], sourceLine: 2),
                sourceLine: 2,
            ),
        ])
        let caught = #expect(throws: CompilerError.self) {
            try lowering.lower(file)
        }
        let err = try #require(caught)
        let diag = try #require(err.diagnostics.first)
        #expect(diag.message.contains("at most one tool-backed"))
    }

    @Test("a description over entities keys a tool fetch from the opposite relation side")
    func descriptionOverEntitiesUsesOtherSide() throws {
        let mer = """
        ---
        vocabulary: t.merconfig
        ---
        To run for a page:
          let refs be the entities that mention the page.
          complete with reason "ok".
        """
        let swift = try compile(mer, wave3RelCfg)
        #expect(swift.contains("runtime.invoke(") || swift.contains("struct"))
    }

    @Test("phrase inlining substitutes through a for-each template segment in the phrase body")
    func phraseInlineSubstitutesForEachTemplateSegment() throws {
        let cfg = """
        === vocabulary ===
        A user is a kind of thing.
        A user has tags, which is a String.

        To greet a user:
          bind report =
            ```
            [for each tag in {tags}]{tag}[end for]
            ```
          emit greeting.sent with body = report.
        """
        let mer = """
        ---
        vocabulary: t.merconfig
        ---
        To run for a user:
          greet the user with tags = the user's tags.
        """
        let swift = try compile(mer, cfg)
        #expect(swift.contains("greeting") || swift.contains("struct"))
    }
}
