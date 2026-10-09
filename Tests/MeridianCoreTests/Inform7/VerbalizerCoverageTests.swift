import Foundation
import Testing
@testable import MeridianCore
import MeridianRuntime

@Suite("Wave 7 verbalizer branch coverage")
struct VerbalizerCoverageTests {
    @Test("canonical forms cover punctuation escaping and all surface enums")
    func canonicalFormsBranches() {
        #expect(CanonicalForms.indented(["alpha", "", "beta"], depth: 2) == ["    alpha", "", "    beta"])
        #expect(CanonicalForms.sentence("  ") == ".")
        #expect(CanonicalForms.sentence("ready:") == "ready:")
        #expect(CanonicalForms.sentence("ready,") == "ready,")
        #expect(CanonicalForms.sentence("ready") == "ready.")
        #expect(CanonicalForms.quoted("a\\b\"\n\r\t") == "\"a\\\\b\\\"\\n\\r\\t\"")
        // Parser-preserved escapes must not accumulate across verbalize passes.
        #expect(CanonicalForms.quoted("hello\\\"world") == "\"hello\\\"world\"")
        #expect(CanonicalForms.unescaped("hello\\\"world") == "hello\"world")
        #expect(CanonicalForms.unescaped(#"slash\\quote\"line\ncarriage\rtab\tkeep\q"#)
                == "slash\\quote\"line\ncarriage\rtab\tkeep\\q")
        #expect(CanonicalForms.backticked("run `now`") == "`run \\`now\\``")
        #expect(CanonicalForms.words(fromIdentifier: "HTTP_status-code") == "H t t p status code")
        #expect(CanonicalForms.words(fromIdentifier: "totalAmount") == "total amount")
        #expect(CanonicalForms.duration(.seconds(1)) == "1 second")
        #expect(CanonicalForms.duration(.seconds(2)) == "2 seconds")

        let comparisons: [(ComparisonOp, String)] = [
            (.equal, "equals"),
            (.notEqual, "is not"),
            (.lessThan, "is less than"),
            (.lessOrEqual, "is at most"),
            (.greaterThan, "is more than"),
            (.greaterOrEqual, "is at least"),
            (.oneOf, "is one of"),
            (.contains, "contains"),
            (.startsWith, "starts with"),
            (.endsWith, "ends with"),
            (.withinDuration, "is within"),
            (.withinPast, "is within the last"),
            (.withinFuture, "is in the next"),
            (.matchesPattern, "matches pattern"),
            (.isEmpty, "is empty"),
            (.isNotEmpty, "is not empty"),
            (.identifies, "identifies"),
        ]
        for (op, expected) in comparisons {
            #expect(CanonicalForms.comparison(op) == expected)
        }

        let quantifiers: [(QuantifierKind, String)] = [
            (.all, "all pages"),
            (.any, "any pages"),
            (.none, "no pages"),
            (.atLeast(2), "at least 2 pages"),
            (.atMost(3), "at most 3 pages"),
            (.exactly(4), "exactly 4 pages"),
        ]
        for (kind, expected) in quantifiers {
            #expect(CanonicalForms.quantifier(kind, noun: "pages") == expected)
        }

        let date = Date(timeIntervalSince1970: 42)
        #expect(CanonicalForms.literal(.string("x")) == "\"x\"")
        #expect(CanonicalForms.literal(.number(Decimal(3))) == "3")
        #expect(CanonicalForms.literal(.boolean(true)) == "true")
        #expect(CanonicalForms.literal(.boolean(false)) == "false")
        #expect(CanonicalForms.literal(.money(Decimal(12), currency: "USD")) == "$12 USD")
        #expect(CanonicalForms.literal(.duration(.seconds(5))) == "5 seconds")
        #expect(CanonicalForms.literal(.date(date)) == "@42")
        #expect(CanonicalForms.literal(.dateTime(date)) == "@42")
        #expect(CanonicalForms.literal(.enumValue("approved", kind: "Status")) == "approved")
    }

    @Test("invoke inversion covers workflow patterns discretion and tool fallbacks")
    func invokeInverterBranches() {
        let pattern = PhrasePattern(segments: [
            .literal("review"),
            .parameter(PhraseParameterAST(name: "page", kind: "page")),
            .literal("carefully"),
        ])
        let symbols = SymbolTable(trace: .silent())
        symbols.registerWorkflowPhrase(
            pattern: pattern,
            structName: "ReviewPage",
            sourceLine: 1,
            sourceFile: "test.meri"
        )
        let inverter = InvokeInverter(symbols: symbols)
        let workflow = IRWorkflow(
            name: "review a page carefully",
            parameters: [IRParameter(name: "page", kind: KindRef("Page"))],
            body: IRBlock(statements: []),
            explicitStructName: "ReviewPage"
        )

        #expect(inverter.phrase(for: workflow)?.displayText == "review a page carefully")
        #expect(inverter.surface(
            for: InvokeIR(
                toolID: "workflow:ReviewPage",
                arguments: [InvokeArg("page", .identifierRef(name: "home page"))]
            ),
            renderExpression: renderExpression
        ) == "review home page carefully")
        #expect(inverter.surface(
            for: InvokeIR(toolID: "workflow:ReviewPage", arguments: []),
            renderExpression: renderExpression
        ) == "invoke workflow:ReviewPage")
        #expect(inverter.surface(
            for: InvokeIR(toolID: "workflow:MissingWorkflow", arguments: [InvokeArg("value", .literal(.string("x")))]),
            renderExpression: renderExpression
        ) == "invoke workflow:MissingWorkflow with value = \"x\"")
        #expect(inverter.surface(
            for: InvokeIR(
                toolID: "runtime.discretion.decide",
                arguments: [InvokeArg("question", .literal(.string("to continue")))]
            ),
            renderExpression: renderExpression
        ) == "decide whether to continue")
        #expect(inverter.surface(
            for: InvokeIR(
                toolID: "runtime.discretion.decide",
                arguments: [InvokeArg("question", .identifierRef(name: "next step"))]
            ),
            renderExpression: renderExpression
        ) == "decide whether next step")
        #expect(inverter.surface(
            for: InvokeIR(toolID: "demo.tool", arguments: []),
            renderExpression: renderExpression
        ) == "invoke demo.tool")

        let toolSymbols = SymbolTable.build(from: MerConfigFile(tools: [
            ToolDeclaration(
                displayName: "Demo Tool",
                methodName: "demo.tool",
                parameters: [ToolParameterAST(name: "value", type: "String")],
                returnType: "String"
            )
        ]), trace: .silent())
        let toolInverter = InvokeInverter(symbols: toolSymbols)
        #expect(toolInverter.surface(
            for: InvokeIR(toolID: "demo.tool", arguments: [InvokeArg("value", .literal(.string("x")))]),
            renderExpression: renderExpression
        ) == "invoke demo.tool with value = \"x\"")
    }

    @Test("drift engine classifies public diff categories")
    func driftEngineBranches() {
        #expect(DriftEngine.diff(authored: "same", canonical: "same").hunks.isEmpty)
        let cap = ParserTrace.capturing(categories: [.drift])
        _ = DriftEngine.diff(authored: "left", canonical: "right", trace: cap.trace)
        #expect(cap.lines().contains { $0.contains("classified 1 drift hunk") })

        let trim = DriftEngine.diff(authored: "  same  ", canonical: "same")
        #expect(trim.hunks.map(\.category) == [.structureNormalized])
        #expect((trim.counts[.structureNormalized] ?? 0) >= 1)

        let spacing = DriftEngine.diff(authored: "score    >   1", canonical: "score > 1")
        #expect(spacing.hunks.map(\.category) == [.structureNormalized])
        #expect((spacing.counts[.structureNormalized] ?? 0) >= 1)

        let synonym = DriftEngine.diff(authored: "score > 1", canonical: "score is more than 1")
        #expect(synonym.hunks.map(\.category) == [.synonymCanonicalized])

        let desugar = DriftEngine.diff(
            authored: "do escalate the order and notify the customer.",
            canonical: "escalate the order."
        )
        #expect(desugar.hunks.map(\.category) == [.desugarExpanded])

        let uneven = DriftEngine.diff(authored: "one\ntwo", canonical: "one")
        #expect(uneven.hunks.count == 1)
        #expect(uneven.hunks[0].authored == "two")
        #expect(uneven.hunks[0].canonical == "")

        let meaning = DriftEngine.diff(authored: "complete.", canonical: "commit.")
        #expect(meaning.counts[.meaningBearing] == 1)
    }

    @Test("match-branch IR verbalizes and reparses (compile-from-source match remains IR-only until corpora emit it)")
    func matchBranchIRRoundTrip() throws {
        let done = IRBlock(statements: [.complete(CompleteIR())])
        let match = BranchIR(
            condition: .match(.identifierRef(name: "choice"), [
                BranchCase(pattern: .literal(.string("yes")), block: done),
                BranchCase(pattern: .enumValue("approved", kind: ""), block: done),
            ]),
            thenBlock: done
        )
        let workflow = IRWorkflow(
            name: "audit choice",
            parameters: [],
            body: IRBlock(statements: [.branch(match)])
        )
        let model = emptyModel(workflows: [workflow])
        let surface = Verbalizer(model: model).verbalize(.branch(match))
        #expect(surface.contains("branch on choice:"), Comment(rawValue: surface))
        #expect(surface.contains("\"yes\":"), Comment(rawValue: surface))
        #expect(surface.contains("approved:"), Comment(rawValue: surface))
        #expect(surface.contains("otherwise:"), Comment(rawValue: surface))

        let fileText = try Verbalizer(model: model).verbalize()
        let reparsed = try VerbalizerTestSupport.compiler().compileToModel(
            meridianSource: fileText,
            meridianFile: "match-branch.meri",
            vocabularies: [VerbalizerTestSupport.baseVocabInput()]
        )
        #expect(IREquality.structurallyEqual(model.workflows, reparsed.workflows),
                Comment(rawValue: VerbalizerTestSupport.firstInequalityHint(model.workflows, reparsed.workflows)
                    + "\n---\n" + fileText))
    }

    @Test("verbalizer covers direct IR rendering branches")
    func directVerbalizerBranches() throws {
        let symbols = definitionSymbols()
        let workflows = [
            IRWorkflow(
                name: "",
                parameters: [],
                body: IRBlock(statements: [.complete(CompleteIR())]),
                explicitStructName: "EmptyWorkflow"
            ),
            IRWorkflow(
                name: "",
                parameters: [IRParameter(name: "order", kind: KindRef("Order"))],
                body: IRBlock(statements: [.complete(CompleteIR())]),
                explicitStructName: "AuditOrder"
            ),
            IRWorkflow(
                name: "when webhook fires",
                parameters: [],
                body: IRBlock(statements: [
                    .wait(WaitIR(condition: .event("webhook", matching: nil))),
                    .emit(EmitIR(
                        eventID: "trigger.webhook.fired",
                        payload: [EmitField("spec", .identifierRef(name: "dynamic spec"))]
                    )),
                ])
            ),
            IRWorkflow(
                name: "ask once",
                parameters: [],
                body: IRBlock(statements: [
                    .emit(EmitIR(
                        eventID: "ask.choice",
                        payload: [EmitField("options", .literal(.string("Approve, Reject")))]
                    )),
                ])
            ),
            IRWorkflow(
                name: "ask malformed",
                parameters: [],
                body: IRBlock(statements: [
                    .emit(EmitIR(
                        eventID: "ask.choice",
                        payload: [EmitField("options", .identifierRef(name: "dynamic options"))]
                    )),
                    .emit(EmitIR(
                        eventID: "ask.choice",
                        payload: [EmitField("options", .literal(.string(" , ")))]
                    )),
                ])
            ),
        ]
        let model = emptyModel(
            symbols: symbols,
            workflows: workflows,
            metadata: FileMetadataAST(entries: [("name", "coverage"), ("triggers", "webhook")]),
            toolsUsed: ["demoTool"]
        )
        let verbalizer = Verbalizer(model: model)
        let fileText = try verbalizer.verbalize()

        #expect(fileText.contains("tools:\n  - \"demoTool\""), Comment(rawValue: fileText))
        #expect(fileText.contains("To EmptyWorkflow:"), Comment(rawValue: fileText))
        #expect(fileText.contains("To Audit order with a Order:"), Comment(rawValue: fileText))
        #expect(fileText.contains("To when webhook fires:"), Comment(rawValue: fileText))
        #expect(fileText.contains("ask the user to choose between \"Approve\", \"Reject\"."), Comment(rawValue: fileText))

        #expect(verbalizer.verbalize(.relationTraversal(.identifierRef(name: "page"), relationName: "mentions", target: nil)) == "page mentions")
        #expect(verbalizer.verbalize(.aggregate(.list, description())) == "the list of the first 2 pages whose score is more than 1 sorted by score descending")
        #expect(verbalizer.verbalize(.propertyAccess(.literal(.string("page")), propertyName: "status")) == "\"page\"'s status")
        #expect(verbalizer.verbalize(.recordList(fields: ["displayName"], rows: [[.identifierRef(name: "page title")]])) == "display name; page title")

        let dataTable = verbalizer.verbalize(.bind(BindIR(
            name: "people",
            expression: .recordList(fields: ["name"], rows: [[.identifierRef(name: "page title")]])
        )))
        #expect(dataTable.contains("| \"page title\" |"), Comment(rawValue: dataTable))

        #expect(verbalizer.verbalize(.invoke(InvokeIR(
            toolID: "shell.run",
            arguments: [InvokeArg("command", .literal(.string("echo hi")))],
            resultBinding: "shellResult"
        ))) == "bind shellResult = `echo hi`.")
        #expect(verbalizer.verbalize(.invoke(InvokeIR(
            toolID: "shell.run",
            arguments: [InvokeArg("command", .identifierRef(name: "command text"))]
        ))) == "`{command text}`.")
        let shellTemplate = IRExpression.interpolatedString([
            .conditional(condition: .identifierRef(name: "ready"), then: [.literal("yes")], otherwise: [.literal("no")]),
            .forEach(variable: "item", collection: .identifierRef(name: "items"), body: [.literal(" {item}")]),
            .formatted(.identifierRef(name: "score"), formatter: "integer"),
        ])
        #expect(verbalizer.verbalize(.invoke(InvokeIR(
            toolID: "shell.run",
            arguments: [InvokeArg("command", shellTemplate)]
        ))).contains("{score as a integer}"))

        let refinedLoop = verbalizer.verbalize(.iterate(IterateIR(
            mode: .overCollection(parameter: "order", kind: KindRef("Order"), collection: .identifierRef(name: "incoming orders")),
            body: block(),
            source: IRIterationRefinement(
                filters: [.comparison(.identifierRef(name: "status"), .equal, .literal(.string("open")))],
                sort: IRSortSpec(path: "score", ascending: true),
                take: 3
            )
        )))
        #expect(refinedLoop.contains("whose status equals \"open\" sorted by score, ascending first 3"), Comment(rawValue: refinedLoop))
        #expect(verbalizer.verbalize(.iterate(IterateIR(
            mode: .overCollection(parameter: "order", kind: KindRef("Order"), collection: .identifierRef(name: "incoming orders")),
            body: block(),
            source: IRIterationRefinement(sort: IRSortSpec(path: "score", ascending: false))
        ))).contains("sorted by score, descending"))
        #expect(verbalizer.verbalize(.iterate(IterateIR(
            mode: .overCollection(parameter: "order", kind: KindRef("Order"), collection: .identifierRef(name: "incoming orders")),
            body: block(),
            source: IRIterationRefinement()
        ))).contains("for each order in incoming orders,"))

        let fallbackMarkerVerbalizer = Verbalizer(model: emptyModel(lexicon: lexicon(
            emptyMarkers: [],
            filledMarkers: [],
            sortByMarkers: []
        )))
        let fallbackSort = fallbackMarkerVerbalizer.verbalize(.description(DescriptionIR(
            collection: .identifierRef(name: "pages"),
            elementVar: "page",
            sort: IRSortSpec(path: "score", ascending: true)
        )))
        #expect(fallbackSort.contains("sorted by score"), Comment(rawValue: fallbackSort))
        #expect(fallbackMarkerVerbalizer.verbalize(.quantified(QuantifierIR(
            kind: .all,
            description: DescriptionIR(collection: .identifierRef(name: "pages"), elementVar: "page"),
            body: .comparison(.propertyAccess(.identifierRef(name: "page"), propertyName: "tags"), .isEmpty, .literal(.boolean(true)))
        ))) == "all pages have no tags")
        #expect(fallbackMarkerVerbalizer.verbalize(.quantified(QuantifierIR(
            kind: .all,
            description: DescriptionIR(collection: .identifierRef(name: "pages"), elementVar: "page"),
            body: .comparison(.propertyAccess(.identifierRef(name: "page"), propertyName: "tags"), .isNotEmpty, .literal(.boolean(true)))
        ))) == "all pages have a tags")

        #expect(verbalizer.verbalize(.assert(AssertIR(
            condition: .propertyAccess(.identifierRef(name: "order"), propertyName: "ready"),
            message: "Expected the order is ready"
        ))) == "assert the order is ready.")
        // Empty / bare / glued Expected messages are not encoded predicates —
        // verbalize the lowered condition and never emit non-round-trippable
        // `# assertion message:` comments.
        #expect(verbalizer.verbalize(.assert(AssertIR(
            condition: .identifierRef(name: "ready"),
            message: "Expected "
        ))) == "assert ready.")
        #expect(verbalizer.verbalize(.assert(AssertIR(
            condition: .identifierRef(name: "ready"),
            message: "Expected"
        ))) == "assert ready.")
        #expect(verbalizer.verbalize(.assert(AssertIR(
            condition: .identifierRef(name: "ready"),
            message: "ExpectedFoo"
        ))) == "assert ready.")
        #expect(verbalizer.verbalize(.assert(AssertIR(
            condition: .definitionPredicate(functionName: "meridianDef_Page_ready", subject: .identifierRef(name: "page")),
            message: "Expected the page is ready"
        ))) == "assert page is ready.")
        // Bare `has` property hits stripLeadingHasWords' no-prefix arm; `hasSummary`
        // hits the strip-success arm.
        #expect(verbalizer.verbalize(.quantified(QuantifierIR(
            kind: .all,
            description: DescriptionIR(
                collection: .identifierRef(name: "pages"),
                elementVar: "page",
                filters: []
            ),
            body: .propertyAccess(.identifierRef(name: "page"), propertyName: "has")
        ))).contains("have has"))
        #expect(verbalizer.verbalize(.quantified(QuantifierIR(
            kind: .all,
            description: DescriptionIR(
                collection: .identifierRef(name: "pages"),
                elementVar: "page",
                filters: []
            ),
            body: .propertyAccess(.identifierRef(name: "page"), propertyName: "hasSummary")
        ))).contains("have summary"))
        #expect(verbalizer.verbalize(.aiAutonomy(AIAutonomyIR(text: ""))).contains("with autonomy"))
        #expect(verbalizer.verbalize(.assert(AssertIR(
            condition: .literal(.boolean(true)),
            message: "custom note"
        ))) == "assert true.")
        #expect(verbalizer.verbalize(.assert(AssertIR(
            condition: .quantified(QuantifierIR(kind: .all, description: description(), body: .literal(.boolean(true)))),
            message: "Expected all pages are ready"
        ))).contains("assert all"))

        #expect(verbalizer.verbalize(.emit(EmitIR(eventID: "audit.started"))) == "emit audit.started.")
        #expect(verbalizer.verbalize(.recover(RecoverIR(pattern: .typed(KindRef("OrderError")), handler: block(), attachedTo: block())))
            .contains("recover from OrderError:"))
        #expect(verbalizer.verbalize(.recover(RecoverIR(
            pattern: .predicate(.identifierRef(name: "can retry")),
            handler: block(),
            attachedTo: block()
        ))).contains("recover where can retry:"))
        #expect(verbalizer.verbalize(.simultaneously(SimultaneouslyIR(
            branches: [IRBlock(statements: [.complete(CompleteIR()), .commit(CommitIR())])],
            detached: true
        ))).contains("in the background, simultaneously:"))
        #expect(verbalizer.verbalize(.simultaneously(SimultaneouslyIR(
            branches: [IRBlock(statements: [.complete(CompleteIR())])],
            detached: true
        ))) == "in the background, complete.")
        #expect(verbalizer.verbalize(.simultaneously(SimultaneouslyIR(
            branches: [block(), block()],
            detached: false
        ))).contains("simultaneously:"))
        #expect(verbalizer.verbalize(.aiJudgment(AIJudgmentIR(text: ""))).contains("use judgment to"))
        // Bullet-prefixed judgment guidance is stripped for fixpoint stability.
        let judgmentBullets = verbalizer.verbalize(.aiJudgment(AIJudgmentIR(
            text: "Decide which case applies:",
            guidance: "- when ready, continue\n- otherwise, wait"
        )))
        #expect(judgmentBullets.contains("when ready, continue"), Comment(rawValue: judgmentBullets))
        #expect(!judgmentBullets.contains("- when"), Comment(rawValue: judgmentBullets))

        // Opaque property assert prefers Expected surface; softened or() does not.
        // Compile-path permission softening (rulebook `may` → or()) is not present
        // in corpora today — this IR lock is the Wave 7 ceiling for that surface.
        let opaqueAssert = verbalizer.verbalize(.assert(AssertIR(
            condition: .propertyAccess(.identifierRef(name: "order"), propertyName: "ready"),
            message: "Expected the order is ready"
        )))
        #expect(opaqueAssert == "assert the order is ready.")
        let softened = verbalizer.verbalize(.assert(AssertIR(
            condition: .logical(.or, [
                .propertyAccess(.identifierRef(name: "order"), propertyName: "ready"),
                .identifierRef(name: "permission granted"),
            ]),
            message: "Expected the order is ready"
        )))
        #expect(softened.contains("either"), Comment(rawValue: softened))
        #expect(!softened.contains("assert the order is ready."), Comment(rawValue: softened))

        #expect(verbalizer.verbalize(.wait(WaitIR(
            condition: .approval(of: .identifierRef(name: "order"), by: "an account manager")
        ))) == "wait for approval of order from an account manager.")
        #expect(verbalizer.verbalize(.wait(WaitIR(
            condition: .event("alert.fired", matching: .identifierRef(name: "critical"))
        ))) == "wait for event alert.fired matching critical.")

        let autonomy = verbalizer.verbalize(.aiAutonomy(AIAutonomyIR(
            text: "repair failures:\ncheck logs",
            autonomy: AutonomyConfigIR(
                until: .identifierRef(name: "done"),
                unless: .identifierRef(name: "blocked"),
                replanAfterFailures: 2,
                maxSteps: 5
            ),
            guidance: "prefer safe steps"
        )))
        #expect(autonomy.contains("unless blocked"), Comment(rawValue: autonomy))
        #expect(autonomy.contains("check logs"), Comment(rawValue: autonomy))
        #expect(autonomy.contains("prefer safe steps"), Comment(rawValue: autonomy))
        #expect(verbalizer.verbalize(.aiAutonomy(AIAutonomyIR(text: ""))).contains("with autonomy"))

        #expect(verbalizer.verbalize(.logical(.or, [])) == "false")
        #expect(verbalizer.verbalize(.logical(.or, [.identifierRef(name: "ready")])) == "ready")
        #expect(verbalizer.verbalize(.logical(.not, [])) == "not true")

        #expect(verbalizer.verbalize(.quantified(QuantifierIR(
            kind: .all,
            description: DescriptionIR(collection: .identifierRef(name: "orders"), elementVar: "order"),
            body: .propertyAccess(.identifierRef(name: "order"), propertyName: "hasInventoryReserved")
        ))) == "all orders have inventory reserved")
        #expect(verbalizer.verbalize(.quantified(QuantifierIR(
            kind: .all,
            description: DescriptionIR(collection: .identifierRef(name: "orders"), elementVar: "order"),
            body: .propertyAccess(.identifierRef(name: "order"), propertyName: "has")
        ))) == "all orders have has")
        #expect(verbalizer.verbalize(.quantified(QuantifierIR(
            kind: .all,
            description: DescriptionIR(collection: .identifierRef(name: "pages"), elementVar: "page"),
            body: .comparison(.propertyAccess(.identifierRef(name: "page"), propertyName: "tags"), .isEmpty, .literal(.boolean(true)))
        ))) == "all pages have no tags")
        #expect(verbalizer.verbalize(.quantified(QuantifierIR(
            kind: .all,
            description: DescriptionIR(collection: .identifierRef(name: "pages"), elementVar: "page"),
            body: .comparison(.propertyAccess(.identifierRef(name: "page"), propertyName: "status"), .equal, .literal(.string("open")))
        ))).contains("have the page's status equals \"open\""))
        #expect(verbalizer.verbalize(.quantified(QuantifierIR(
            kind: .all,
            description: DescriptionIR(collection: .identifierRef(name: "pages"), elementVar: "page"),
            body: .definitionPredicate(
                functionName: "meridianDef_Page_ready",
                subject: .propertyAccess(.identifierRef(name: "page"), propertyName: "page")
            )
        ))) == "all pages is ready")
        #expect(verbalizer.verbalize(.quantified(QuantifierIR(
            kind: .all,
            description: DescriptionIR(collection: .identifierRef(name: "pages"), elementVar: "page"),
            body: .definitionPredicate(functionName: "meridianDef_Page_ready", subject: .literal(.boolean(true)))
        ))).contains("true is ready"))

        let complexDescription = DescriptionIR(
            collection: .invocation(InvokeIR(toolID: "fetch.pages")),
            elementVar: "page",
            filters: [
                .logical(.and, [
                    .comparison(.identifierRef(name: "page"), .equal, .literal(.string("home"))),
                    .literal(.boolean(true)),
                ]),
                .logical(.or, [
                    .comparison(.propertyAccess(.identifierRef(name: "page"), propertyName: "score"), .greaterThan, .literal(.number(1))),
                    .comparison(.propertyAccess(.identifierRef(name: "page"), propertyName: "score"), .lessThan, .literal(.number(10))),
                ]),
                .logical(.not, [.definitionPredicate(functionName: "meridianDef_Page_ready", subject: .identifierRef(name: "page"))]),
                .logical(.not, []),
                .comparison(
                    .comparison(.identifierRef(name: "page"), .equal, .literal(.string("home"))),
                    .equal,
                    .literal(.boolean(true))
                ),
                .definitionPredicate(functionName: "meridianDef_Page_ready", subject: .identifierRef(name: "other page")),
            ]
        )
        let descriptionText = verbalizer.verbalize(.description(complexDescription))
        #expect(descriptionText.contains("page in invoke fetch.pages whose"), Comment(rawValue: descriptionText))
        #expect(descriptionText.contains("page equals \"home\" and true"), Comment(rawValue: descriptionText))
        #expect(descriptionText.contains("either score is more than 1 or score is less than 10"), Comment(rawValue: descriptionText))
        #expect(descriptionText.contains("not ready"), Comment(rawValue: descriptionText))
        #expect(descriptionText.contains("not true"), Comment(rawValue: descriptionText))
        #expect(descriptionText.contains("page equals \"home\" equals true"), Comment(rawValue: descriptionText))
        #expect(descriptionText.contains("other page is ready"), Comment(rawValue: descriptionText))
    }

    @Test("IR equality covers positive arms and intentional normalizations")
    func irEqualityPositiveBranchesAndNormalizations() {
        #expect(IREquality.structurallyEqual(
            IRPrimitive.assert(AssertIR(condition: .literal(.boolean(true)), message: "Expected true")),
            IRPrimitive.assert(AssertIR(condition: .literal(.boolean(true)), message: "Different authored message"))
        ))
        #expect(IREquality.structurallyEqual(
            IRExpression.relationTraversal(.identifierRef(name: "page"), relationName: "mentions", target: nil),
            IRExpression.relationTraversal(.identifierRef(name: "the page"), relationName: "mentions", target: nil)
        ))
        #expect(IREquality.structurallyEqual(IRExpression.envVar(name: "HOME"), IRExpression.envVar(name: "HOME")))
        #expect(IREquality.structurallyEqual(IRExpression.nowExpression, IRExpression.nowExpression))

        let branchCase = BranchCase(pattern: .enumValue("approved", kind: "Status"), block: block())
        #expect(IREquality.structurallyEqual(
            BranchCondition.match(.identifierRef(name: "status"), [branchCase]),
            BranchCondition.match(.identifierRef(name: "status"), [branchCase])
        ))
        #expect(IREquality.structurallyEqual(IRPattern.literal(.string("x")), IRPattern.literal(.string("x"))))
        #expect(IREquality.structurallyEqual(IRPattern.enumValue("approved", kind: "Status"), IRPattern.enumValue("approved", kind: "status")))
        #expect(IREquality.structurallyEqual(IRPattern.wildcard, IRPattern.wildcard))
        #expect(IREquality.structurallyEqual(ErrorPattern.typed(KindRef("OrderError")), ErrorPattern.typed(KindRef("order error"))))

        #expect(IREquality.structurallyEqual(
            IRInterpolationSegment.expression(.identifierRef(name: "score")),
            IRInterpolationSegment.expression(.identifierRef(name: "score"))
        ))
        #expect(IREquality.structurallyEqual(
            IRInterpolationSegment.forEach(variable: "the item", collection: .identifierRef(name: "items"), body: [.literal("x")]),
            IRInterpolationSegment.forEach(variable: "item", collection: .identifierRef(name: "items"), body: [.literal("x")])
        ))
        #expect(IREquality.structurallyEqual(
            IRInterpolationSegment.shellEscapedExpression(.identifierRef(name: "path")),
            IRInterpolationSegment.shellEscapedExpression(.identifierRef(name: "path"))
        ))

        #expect(!IREquality.structurallyEqual(QuantifierKind.all, QuantifierKind.any))
        #expect(IREquality.structurallyEqual(IRLiteral.money(Decimal(1), currency: "USD"), IRLiteral.money(Decimal(1), currency: "USD")))
        let date = Date(timeIntervalSince1970: 7)
        #expect(IREquality.structurallyEqual(IRLiteral.date(date), IRLiteral.date(date)))
        #expect(IREquality.structurallyEqual(IRLiteral.dateTime(date), IRLiteral.dateTime(date)))
        #expect(IREquality.structurallyEqual(IRLiteral.enumValue("approved", kind: "Status"), IRLiteral.enumValue("approved", kind: "Status")))
        #expect(!IREquality.structurallyEqual(IRLiteral.money(Decimal(1), currency: "USD"), IRLiteral.string("1 USD")))

        for op in [ComparisonOp.oneOf, .startsWith, .endsWith, .withinDuration, .withinFuture, .matchesPattern, .identifies] {
            #expect(IREquality.structurallyEqual(op, op), Comment(rawValue: "\(op)"))
        }
        let comparisonMismatches: [(ComparisonOp, ComparisonOp)] = [
            (.equal, .notEqual), (.notEqual, .equal), (.lessThan, .equal), (.lessOrEqual, .equal),
            (.greaterThan, .equal), (.greaterOrEqual, .equal), (.oneOf, .equal), (.contains, .equal),
            (.startsWith, .equal), (.endsWith, .equal), (.withinDuration, .equal), (.withinPast, .equal),
            (.withinFuture, .equal), (.matchesPattern, .equal), (.isEmpty, .equal), (.isNotEmpty, .equal),
            (.identifies, .equal),
        ]
        for (lhs, rhs) in comparisonMismatches {
            #expect(!IREquality.structurallyEqual(lhs, rhs), Comment(rawValue: "\(lhs) vs \(rhs)"))
        }
        #expect(!IREquality.structurallyEqual(
            DescriptionIR(collection: .identifierRef(name: "pages"), elementVar: "page", sort: nil),
            DescriptionIR(collection: .identifierRef(name: "pages"), elementVar: "page", sort: IRSortSpec(path: "score", ascending: true))
        ))
        #expect(!IREquality.structurallyEqual(
            InvokeIR(toolID: "demo.tool", resultBinding: nil),
            InvokeIR(toolID: "demo.tool", resultBinding: "result")
        ))
        #expect(!IREquality.structurallyEqual(
            IRPrimitive.aiJudgment(AIJudgmentIR(text: "decide", guidance: nil)),
            IRPrimitive.aiJudgment(AIJudgmentIR(text: "decide", guidance: "guide"))
        ))
        #expect(!IREquality.structurallyEqual(
            IRExpression.superlative(SuperlativeIR(description: description(), sortPath: "score", ascending: true)),
            IRExpression.literal(.boolean(true))
        ))
        let primitiveMismatchCases: [IRPrimitive] = [
            .invoke(InvokeIR(toolID: "demo.tool")),
            .bind(BindIR(name: "value", expression: .literal(.number(1)))),
            .branch(BranchIR(condition: .predicate(.literal(.boolean(true))), thenBlock: block())),
            .iterate(IterateIR(mode: .whileCondition(.literal(.boolean(true))), body: block())),
            .assert(AssertIR(condition: .literal(.boolean(true)))),
            .emit(EmitIR(eventID: "demo.event")),
            .wait(WaitIR(condition: .duration(.seconds(1)))),
            .commit(CommitIR()),
            .recover(RecoverIR(pattern: .anyError, handler: block(), attachedTo: block())),
            .simultaneously(SimultaneouslyIR(branches: [block()])),
            .aiJudgment(AIJudgmentIR(text: "decide")),
            .aiAutonomy(AIAutonomyIR(text: "repair")),
            .complete(CompleteIR()),
        ]
        for index in 0..<(primitiveMismatchCases.count - 1) {
            #expect(!IREquality.structurallyEqual(primitiveMismatchCases[index], primitiveMismatchCases[index + 1]))
        }
        #expect(!IREquality.structurallyEqual(
            IRPrimitive.complete(CompleteIR()),
            IRPrimitive.bind(BindIR(name: "value", expression: .literal(.number(1))))
        ))
    }

    @Test("IR equality covers false arms and normalization helpers")
    func irEqualityBranches() {
        #expect(IREquality.identifiersEqual("the Order-ID", "order id"))
        #expect(IREquality.structurallyEqual(
            IRParameter(name: "the order", kind: KindRef("Order")),
            IRParameter(name: "order", kind: KindRef("order"))
        ))
        #expect(IREquality.structurallyEqual(
            LoweredDefinition(functionName: "meridianDef_Page_stale", subjectVar: "page", body: .literal(.boolean(true))),
            LoweredDefinition(functionName: "meridian def page stale", subjectVar: "the page", body: .literal(.boolean(true)))
        ))
        #expect(IREquality.structurallyEqual(
            IRLiteral.string("line\\nquote\\\""),
            IRLiteral.string("line\nquote\"")
        ))

        let exprCases: [IRExpression] = [
            .literal(.string("x")),
            .constantRef(name: "default threshold"),
            .identifierRef(name: "score"),
            .instanceRef(name: "primary mailer"),
            .propertyAccess(.identifierRef(name: "order"), propertyName: "score"),
            .relationTraversal(.identifierRef(name: "page"), relationName: "mentions", target: nil),
            .comparison(.identifierRef(name: "score"), .equal, .literal(.number(1))),
            .logical(.and, [.literal(.boolean(true))]),
            .envVar(name: "HOME"),
            .nowExpression,
            .invocation(InvokeIR(toolID: "demo.tool")),
            .interpolatedString([.literal("hello")]),
            .recordList(fields: ["name"], rows: [[.literal(.string("Ada"))]]),
            .tableLookup(table: "routes", keyColumn: "from", key: .literal(.string("home")), valueColumn: "to"),
            .definitionPredicate(functionName: "meridianDef_Page_stale", subject: .identifierRef(name: "page")),
            .quantified(QuantifierIR(kind: .any, description: description())),
            .description(description()),
            .aggregate(.list, description()),
            .superlative(SuperlativeIR(description: description(), sortPath: "score", ascending: true)),
        ]
        for index in 0..<(exprCases.count - 1) {
            #expect(!IREquality.structurallyEqual(exprCases[index], exprCases[index + 1]))
        }

        #expect(!IREquality.structurallyEqual(
            IRPrimitive.bind(BindIR(name: "value", expression: .literal(.number(1)), isRebind: false)),
            IRPrimitive.bind(BindIR(name: "value", expression: .literal(.number(1)), isRebind: true))
        ))
        #expect(!IREquality.structurallyEqual(
            IRPrimitive.emit(EmitIR(eventID: "one", strict: true)),
            IRPrimitive.emit(EmitIR(eventID: "one", strict: false))
        ))
        #expect(!IREquality.structurallyEqual(
            IRPrimitive.simultaneously(SimultaneouslyIR(branches: [block()], detached: true)),
            IRPrimitive.simultaneously(SimultaneouslyIR(branches: [block()], detached: false))
        ))
        #expect(!IREquality.structurallyEqual(
            IRPrimitive.aiJudgment(AIJudgmentIR(text: "- decide:", scopedTools: ["a"], snapshotKeys: ["s"], guidance: "guide")),
            IRPrimitive.aiJudgment(AIJudgmentIR(text: "decide", scopedTools: ["a"], snapshotKeys: ["s"], guidance: "different"))
        ))
        #expect(!IREquality.structurallyEqual(
            IRPrimitive.aiAutonomy(AIAutonomyIR(text: "repair", autonomy: AutonomyConfigIR(maxSteps: 2))),
            IRPrimitive.aiAutonomy(AIAutonomyIR(text: "repair", autonomy: AutonomyConfigIR(maxSteps: 3)))
        ))

        #expect(!IREquality.structurallyEqual(
            BranchCondition.predicate(.literal(.boolean(true))),
            BranchCondition.match(.identifierRef(name: "choice"), [])
        ))
        #expect(!IREquality.structurallyEqual(
            IRPattern.literal(.string("x")),
            IRPattern.wildcard
        ))
        #expect(!IREquality.structurallyEqual(
            IterateMode.whileCondition(.literal(.boolean(true))),
            IterateMode.untilCondition(.literal(.boolean(true)))
        ))
        #expect(!IREquality.structurallyEqual(
            IRIterationRefinement(filters: [], sort: nil, take: nil),
            nil
        ))
        #expect(!IREquality.structurallyEqual(
            WaitConditionIR.signal("ready"),
            WaitConditionIR.duration(.seconds(1))
        ))
        #expect(!IREquality.structurallyEqual(
            ErrorPattern.typed(KindRef("Order")),
            ErrorPattern.named("OrderError")
        ))
        #expect(!IREquality.structurallyEqual(
            AutonomyConfigIR(until: .literal(.boolean(true)), unless: nil, replanAfterFailures: 1, maxSteps: 2),
            AutonomyConfigIR(until: nil, unless: .literal(.boolean(true)), replanAfterFailures: 1, maxSteps: 2)
        ))
        #expect(!IREquality.structurallyEqual(
            IRInterpolationSegment.formatted(.identifierRef(name: "score"), formatter: "integer"),
            IRInterpolationSegment.shellEscapedExpression(.identifierRef(name: "score"))
        ))
        #expect(!IREquality.structurallyEqual(QuantifierKind.atLeast(2), QuantifierKind.atLeast(3)))
        #expect(!IREquality.structurallyEqual(LogicalOp.and, LogicalOp.or))
        #expect(!IREquality.structurallyEqual(IRExpression?.none, IRExpression?.some(.literal(.boolean(true)))))
        #expect(!IREquality.structurallyEqual(IRBlock?.none, IRBlock?.some(block())))
    }

    @Test("compileToModel returns verbalizer fields without emitting Swift")
    func compileToModelFields() throws {
        let source = """
        ---
        tools:
          - Demo Tool
        ---
        Definition: a page is stale if the page's status is "old".
        To audit a page:
          invoke demoTool with value = default threshold.
          complete.

        ## Tools Used
        - Demo Tool (demoTool)
        """
        let model = try VerbalizerTestSupport.compiler().compileToModel(
            meridianSource: source,
            meridianFile: "audit.meri",
            vocabularies: [VerbalizerTestSupport.baseVocabInput()]
        )

        #expect(model.sourceFileName == "audit.meri")
        #expect(model.authoredSource == source)
        #expect(model.metadata?["tools"]?.contains("Demo Tool") == true)
        #expect(model.workflows.contains { $0.name == "audit a page" })
        #expect(model.loweredDefinitions.count == 1)
        #expect(model.inlineDefinitions.count == 1)
        #expect(model.toolsUsed.contains("demoTool"))
        #expect(try Verbalizer(model: model).verbalize().contains("Definition: a page is stale"))
    }

    @Test("verbalize validates lexicon and IR before emitting, and logs trace")
    func verbalizeValidationAndTrace() throws {
        let emptyMarkerModel = emptyModel(lexicon: lexicon(
            emptyMarkers: [],
            filledMarkers: [],
            sortByMarkers: []
        ))
        do {
            _ = try Verbalizer(model: emptyMarkerModel).verbalize()
            Issue.record("expected empty lexicon marker diagnostic")
        } catch let error as CompilerError {
            #expect(error.diagnostics.contains { diagnostic in
                diagnostic.code == .emptyLexiconMarkers
                    && diagnostic.message.contains("empty markers")
                    && diagnostic.message.contains("filled markers")
                    && diagnostic.message.contains("sort-by markers")
            })
        }

        let singleMissingMarkerModel = emptyModel(lexicon: lexicon(emptyMarkers: []))
        do {
            _ = try Verbalizer(model: singleMissingMarkerModel).verbalize()
            Issue.record("expected singular empty lexicon marker diagnostic")
        } catch let error as CompilerError {
            #expect(error.diagnostics.contains { diagnostic in
                diagnostic.code == .emptyLexiconMarkers
                    && diagnostic.message.contains("collection empty")
            })
        }

        let invalidWorkflow = IRWorkflow(
            name: "invalid",
            parameters: [],
            body: IRBlock(statements: [
                .bind(BindIR(name: "bad", expression: .logical(.and, [])))
            ])
        )
        do {
            _ = try Verbalizer(model: emptyModel(workflows: [invalidWorkflow])).verbalize()
            Issue.record("expected IR validation failure")
        } catch IRValidationError.diagnostics(let diagnostics) {
            #expect(diagnostics.contains { $0.code == .invalidIR })
        }

        let cap = ParserTrace.capturing(categories: [.verbalizer])
        let traceWorkflow = IRWorkflow(
            name: "trace",
            parameters: [],
            body: IRBlock(statements: [.complete(CompleteIR())])
        )
        let text = try Verbalizer(model: emptyModel(workflows: [traceWorkflow]), trace: cap.trace).verbalize()
        #expect(text.contains("To trace:"), Comment(rawValue: text))
        #expect(cap.lines().contains { $0.contains("verbalizing 1 workflow") })
    }

    @Test("trace-temporal countInWindow verbalizes all three comparator kinds, not just atLeast")
    func traceTemporalCountInWindowComparators() {
        let v = Verbalizer(model: emptyModel())
        let pattern = EventPatternIR(subject: .step("deploy"), outcome: .failed)
        let atMost = v.verbalize(.traceTemporal(TraceTemporalIR(
            scope: .currentRun,
            kind: .countInWindow(pattern, comparator: .atMost(3), duration: .seconds(60))
        )))
        #expect(atMost.contains("at most 3 times"), Comment(rawValue: atMost))
        let exactly = v.verbalize(.traceTemporal(TraceTemporalIR(
            scope: .currentRun,
            kind: .countInWindow(pattern, comparator: .exactly(2), duration: .seconds(60))
        )))
        #expect(exactly.contains("exactly 2 times"), Comment(rawValue: exactly))
    }

    @Test("trace-statistical verbalizes a .named subject, a payload predicate, and non-integer percentages")
    func traceStatisticalNamedSubjectAndFractionalPercent() {
        let v = Verbalizer(model: emptyModel())
        let named = v.verbalize(.traceStatistical(TraceStatisticalIR(
            pattern: TraceStatisticalPatternIR(
                subject: .named("checkout"),
                payloadPredicate: .comparison(.identifierRef(name: "amount"), .greaterThan, .literal(.number(10)))
            ),
            outcome: .fails,
            bound: .atMost(0.3335),
            denominator: .occurrences
        )))
        #expect(named.contains("checkout"), Comment(rawValue: named))
        #expect(named.contains("33.35"), Comment(rawValue: named))
    }

    @Test("trace-temporal .ever payload whose-clause and statistical acrossSkills scope")
    func traceEverPayloadAndAcrossSkillsStatistical() {
        let v = Verbalizer(model: emptyModel())
        let ever = v.verbalize(.traceTemporal(TraceTemporalIR(
            scope: .currentRun,
            kind: .ever(EventPatternIR(
                subject: .step("deploy"),
                outcome: .failed,
                payloadPredicate: .comparison(
                    .identifierRef(name: "amount"),
                    .greaterThan,
                    .literal(.number(10))
                )
            ))
        )))
        #expect(ever.contains("whose"), Comment(rawValue: ever))
        #expect(ever.contains("has ever"), Comment(rawValue: ever))

        let across = v.verbalize(.traceStatistical(TraceStatisticalIR(
            scope: .acrossSkills(["alpha", "beta"]),
            pattern: TraceStatisticalPatternIR(subject: .step("deploy")),
            outcome: .succeeds,
            bound: .atLeast(0.5),
            denominator: .runs
        )))
        #expect(across.contains("alpha"), Comment(rawValue: across))
        #expect(across.contains("beta"), Comment(rawValue: across))
    }

    @Test("verbClauseFilterText falls back to nil when no relation backing matches the filtered property")
    func verbClauseFilterTextNoMatchingRelation() {
        // Every relation is tool-backed, so `first(where:)` exhausts the whole
        // dictionary via the `.property` pattern-match failure arm (`return
        // false`) before the outer guard falls through to `nil` — the
        // generic `whose` filter text is used instead.
        let config = MerConfigFile(vocabulary: [
            .relationBacking(RelationBackingDeclaration(relation: "curation", backing: .tool(toolID: "assign.tool"))),
            .relationBacking(RelationBackingDeclaration(relation: "mentioning", backing: .tool(toolID: "link.tool"))),
        ])
        let symbols = SymbolTable.build(from: config, trace: .silent())
        let v = Verbalizer(model: emptyModel(symbols: symbols))
        let text = v.verbalize(.quantified(QuantifierIR(
            kind: .all,
            description: DescriptionIR(
                collection: .identifierRef(name: "pages"),
                elementVar: "page",
                filters: [.comparison(
                    .propertyAccess(.identifierRef(name: "page"), propertyName: "owner"),
                    .identifies,
                    .identifierRef(name: "user")
                )]
            ),
            body: .literal(.boolean(true))
        )))
        #expect(text.contains("whose"), Comment(rawValue: text))
    }

    @Test("verbClauseFilterText falls back to nil when a matching relation has no declared verb")
    func verbClauseFilterTextNoVerbForRelation() {
        let config = MerConfigFile(vocabulary: [
            .relationBacking(RelationBackingDeclaration(relation: "ownership", backing: .property(kind: "page", path: "owner"))),
        ])
        let symbols = SymbolTable.build(from: config, trace: .silent())
        let v = Verbalizer(model: emptyModel(symbols: symbols))
        let text = v.verbalize(.quantified(QuantifierIR(
            kind: .all,
            description: DescriptionIR(
                collection: .identifierRef(name: "pages"),
                elementVar: "page",
                filters: [.comparison(
                    .propertyAccess(.identifierRef(name: "page"), propertyName: "owner"),
                    .identifies,
                    .identifierRef(name: "user")
                )]
            ),
            body: .literal(.boolean(true))
        )))
        #expect(text.contains("whose"), Comment(rawValue: text))
    }

    private func renderExpression(_ expression: IRExpression) -> String {
        Verbalizer(model: emptyModel()).verbalize(expression)
    }

    private func emptyModel(
        symbols: SymbolTable = SymbolTable(trace: .silent()),
        workflows: [IRWorkflow] = [],
        lexicon: EnglishLexicon = .default,
        metadata: FileMetadataAST? = nil,
        toolsUsed: [String] = []
    ) -> VerbalizerModel {
        VerbalizerModel(
            workflows: workflows,
            loweredDefinitions: [],
            inlineDefinitions: [],
            symbols: symbols,
            lexicon: lexicon,
            sourceFileName: "test.meri",
            authoredSource: "",
            metadata: metadata,
            toolsUsed: toolsUsed
        )
    }

    private func lexicon(
        emptyMarkers: [String]? = nil,
        filledMarkers: [String]? = nil,
        sortByMarkers: [String]? = nil
    ) -> EnglishLexicon {
        let base = EnglishLexicon.default
        return EnglishLexicon(
            articles: base.articles,
            parameterArticles: base.parameterArticles,
            prepositions: base.prepositions,
            copulas: base.copulas,
            participles: base.participles,
            participleSuffixes: base.participleSuffixes,
            comparisonMarkers: base.comparisonMarkers,
            durationUnits: base.durationUnits,
            toolStopwords: base.toolStopwords,
            assertionMarkers: base.assertionMarkers,
            normativeCueWords: base.normativeCueWords,
            inferenceCueWords: base.inferenceCueWords,
            referenceHeadingWords: base.referenceHeadingWords,
            guardedFenceIntroducers: base.guardedFenceIntroducers,
            fallbackChainIntroducers: base.fallbackChainIntroducers,
            timestampProperty: base.timestampProperty,
            grammar: base.grammar,
            emptyMarkers: emptyMarkers ?? base.emptyMarkers,
            filledMarkers: filledMarkers ?? base.filledMarkers,
            temporalWindowMarkers: base.temporalWindowMarkers,
            timestampAliases: base.timestampAliases,
            aggregateIntroducers: base.aggregateIntroducers,
            superlativeGradables: base.superlativeGradables,
            sortByMarkers: sortByMarkers ?? base.sortByMarkers,
            ascendingMarkers: base.ascendingMarkers,
            descendingMarkers: base.descendingMarkers,
            possessivePronouns: base.possessivePronouns,
            anaphoraMarkers: base.anaphoraMarkers,
            tableConditionHeaders: base.tableConditionHeaders,
            tableActionHeaders: base.tableActionHeaders,
            tableWildcardTokens: base.tableWildcardTokens,
            shellFenceLanguages: base.shellFenceLanguages,
            fenceToolMapping: base.fenceToolMapping
        )
    }

    private func block() -> IRBlock {
        IRBlock(statements: [.complete(CompleteIR())])
    }

    private func description() -> DescriptionIR {
        DescriptionIR(
            collection: .identifierRef(name: "pages"),
            elementVar: "page",
            filters: [.comparison(.propertyAccess(.identifierRef(name: "page"), propertyName: "score"), .greaterThan, .literal(.number(1)))],
            sort: IRSortSpec(path: "score", ascending: false),
            take: 2
        )
    }

    private func definitionSymbols() -> SymbolTable {
        let symbols = SymbolTable(trace: .silent())
        symbols.registerDefinition(.init(
            adjective: "ready",
            kind: "page",
            subjectVar: "page",
            body: .literal(.boolean(true)),
            functionName: "meridianDef_Page_ready",
            sourceLine: 1
        ))
        return symbols
    }
}
