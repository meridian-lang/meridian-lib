import Testing
@testable import MeridianCore

@Suite("AGENTS.md sharp-edge regressions")
struct AGENTSSharpEdgeRegressionTests {
    private func compile(_ mer: String, _ cfg: String = "=== vocabulary ===\n") throws -> String {
        try Compiler(options: .init(
            emitterOptions: .init(includeTimestamp: false, emitSourceLineComments: false),
        )).compile(
            meridianSource: mer,
            meridianFile: "sharp.meri",
            merconfigSource: cfg,
            merconfigFile: "sharp.merconfig"
        )
    }

    @Test("pitfall #1: phrase-pattern article discovery uses the earliest parameter article")
    func earliestArticleWins() {
        let lexicon = EnglishLexicon.default
        let found = lexicon.findEarliestArticle("total amount for an account manager")

        #expect(found?.intro == "total amount for")
        #expect(found?.rest == "account manager")
    }

    @Test("pitfalls #2/#3: bare possessives lower without adding a 'the ' state key")
    func barePossessiveDoesNotInventThePrefix() throws {
        let cfg = """
        === vocabulary ===
        An order is a kind of thing.
        An order has an id, which is String.
        """
        let mer = """
        ---
        vocabulary: sharp.merconfig
        ---
        To inspect an order:
          bind identifier = order's id.
          complete.
        """

        let swift = try compile(mer, cfg)

        #expect(swift.contains("state.get(\"order.id\")"), Comment(rawValue: swift))
        #expect(!swift.contains("state.get(\"the "), Comment(rawValue: swift))
    }

    @Test("pitfall #4: comparison markers inside double-quoted strings stay literal")
    func quotedComparisonMarkerIsLiteral() {
        let parsed = ExpressionParser().parse("\"total is more than 5\"")

        if case .literal(.string(let value)) = parsed {
            #expect(value == "total is more than 5")
        } else {
            Issue.record("expected a string literal, got \(parsed.traceDescription(detail: .verbose))")
        }
    }

    @Test("pitfall #5: phrase substitution prefers longer overlapping parameter names")
    func overlappingPhraseArgumentsSubstituteLongestFirst() throws {
        let cfg = """
        === vocabulary ===
        Money is a kind of Number.
        An order is a kind of thing.
        An order has an amount, which is Money.
        An order has a total amount, which is Money.

        To compare a total amount with an amount:
          bind chosen = the total amount.
          bind fallback = the amount.
        """
        let mer = """
        ---
        vocabulary: sharp.merconfig
        ---
        To inspect an order:
          compare the order's total amount with the order's amount.
          complete.
        """

        let swift = try compile(mer, cfg)

        #expect(swift.contains("state.get(\"order.totalAmount\")"), Comment(rawValue: swift))
        #expect(swift.contains("state.get(\"order.amount\")"), Comment(rawValue: swift))
        #expect(!swift.contains("state.get(\"order.total order.amount\")"), Comment(rawValue: swift))
    }

    @Test("pitfall #6: workflow-call init labels follow declared phrase parameter order")
    func workflowCallArgumentsUseDeclaredOrder() throws {
        let cfg = """
        === vocabulary ===
        An order is a kind of thing.
        A customer is a kind of thing.
        """
        let mer = """
        ---
        vocabulary: sharp.merconfig
        ---
        To notify a customer about an order:
          complete.

        To process an order for a customer:
          notify the customer about the order.
          complete.
        """

        let swift = try compile(mer, cfg)

        #expect(swift.contains("NotifyCustomer(runtime: runtime, customer: customer, order: order).run()"),
                Comment(rawValue: swift))
    }

    @Test("pitfall #7: counted multiline collection skips continuation lines")
    func multilineContinuationIsNotReprocessedAsTopLevel() throws {
        let mer = """
        To choose:
          ask the user to choose between:
            - "approve"
            - "deny"
          complete.
        """

        let block = try StatementParser(symbols: SymbolTable())
            .parseBlock(IndentTokenizer().tokenize(mer).filter { $0.headingLevel == nil }.dropFirst().map { $0 })

        #expect(block.statements.count == 2)
        #expect(!block.statements.contains {
            if case .phraseInvocation(let phrase) = $0 {
                return phrase.words.contains("approve") || phrase.words.contains("deny")
            }
            return false
        })
    }

    @Test("pitfall #8: apostrophes in possessive invoke arguments do not split args")
    func apostrophePossessiveDoesNotSplitInvokeArgs() throws {
        let cfg = """
        === vocabulary ===
        A customer is a kind of thing.
        A customer has an email, which is String.

        === tools ===
        Send Email
        ==========
        ~ sendEmail(email: String) : String
        """
        let mer = """
        ---
        vocabulary: sharp.merconfig
        ---
        To message a customer:
          invoke sendEmail with email = the customer's email.
          complete.
        """

        let swift = try compile(mer, cfg)

        #expect(swift.contains("\"email\": state.get(\"customer.email\") ?? .null"), Comment(rawValue: swift))
        #expect(!swift.contains("_unresolved"), Comment(rawValue: swift))
    }

    @Test("pitfall #9: generated Constants stays Sendable")
    func constantsStaySendable() throws {
        let cfg = """
        === constants ===
        The greeting is "hello".
        """
        let swift = try compile("To run:\n  complete.\n", cfg)

        #expect(swift.contains("public struct Constants: Sendable"), Comment(rawValue: swift))
    }

    @Test("pitfalls #10/#11: vendored StringTemplate flattens nested templates and builder is public")
    func vendoredStringTemplateBuilderAndFlattening() {
        let nested = StringTemplate {
            "a"
            StringTemplate {
                "b"
                "c"
            }
        }

        #expect(nested.toString(separator: "|") == "a|b|c")
        let _: StringConvertibleBuilder.Type = StringConvertibleBuilder.self
    }

    @Test("pitfall #13: domain emission sanitizes names and does not duplicate explicit id properties")
    func domainEmitterSanitizesAndDeduplicatesID() throws {
        let cfg = """
        === vocabulary ===
        A webhook-transform is a kind of thing.
        A webhook-transform has an id, which is String.
        A webhook-transform has a payload, which is String.
        """
        let mer = """
        ---
        vocabulary: sharp.merconfig
        ---
        To process a webhook-transform:
          complete.
        """

        let swift = try compile(mer, cfg)

        #expect(swift.contains("public struct WebhookTransform:"), Comment(rawValue: swift))
        #expect(!swift.contains("Webhook-transform"), Comment(rawValue: swift))
        #expect(swift.components(separatedBy: "public var id: String").count == 2,
                Comment(rawValue: swift))
    }

    @Test("pitfall #14: blockquoted normative prose in executable sections is non-executable")
    func blockquotedExecutableProseIsDroppedAsComment() throws {
        let ast = try MeridianParser(symbols: SymbolTable()).parse("""
        ## Steps
        > every entity must have a back-link.
        complete.
        """, file: "sharp.meri")

        #expect(ast.workflows.first?.body.statements.count == 1)
    }

    @Test("pitfall #15: custom assertion synonyms lower end-to-end and migrator output avoids inert markers")
    func assertionSynonymAndMigratorNoInertMarker() async throws {
        let cfg = """
        === vocabulary ===

        === language ===
        Assertion synonyms:
          verify
        """
        let mer = """
        ---
        vocabulary: sharp.merconfig
        ---
        To check a score:
          verify the score is more than 100.
        """

        let swift = try compile(mer, cfg)

        #expect(swift.contains("try await runtime.assert"), Comment(rawValue: swift))
        #expect(!swift.contains("_unresolved"), Comment(rawValue: swift))

        let migrated = try await SkillMigrator(
            compiler: Compiler(options: .init()),
            vocabularies: [],
            options: .init(routeFuzzy: true)
        ).migrate("""
        # Demo

        ## Notes
        This is reference documentation.
        """, file: "SKILL.md")
        #expect(!migrated.meriSource.contains("(( inert"), Comment(rawValue: migrated.meriSource))
    }

    @Test("pitfall #16: custom procedure headings need a load-bearing role marker")
    func customProcedureHeadingMarkerIsLoadBearing() throws {
        let source = """
        ## Repair missing back-links (( role: procedure ))
        complete.
        """

        let ast = try MeridianParser(symbols: SymbolTable()).parse(source, file: "sharp.meri")

        #expect(ast.skillSections.first?.role == "procedure")
        #expect(ast.skillSections.first?.executes == true)
        #expect(ast.workflows.first?.body.statements.count == 1)
    }

    @Test("pitfall #17: overflowed production anchors leave the whole production unscreened")
    func overflowedProductionIsUnscreenedRatherThanPartiallyMasked() {
        let fillers = (0..<127).map { i in
            GrammarProduction(
                name: "filler-\(i)",
                category: .expression,
                implementation: .pegex,
                canonicalExample: "`anchor\(i)`",
                summary: "Filler.",
                anchors: ["anchor\(i)"]
            )
        }
        let quantifierLike = GrammarProduction(
            name: "quantifier-like",
            category: .expression,
            implementation: .pegex,
            canonicalExample: "`every order is valid`",
            summary: "Synthetic quantifier overflow regression.",
            anchors: ["every", "any"]
        )
        let screen = NonterminalScreen(table: GrammarTable(productions: fillers + [quantifierLike]))

        #expect(screen.anchorCount == 128)
        #expect(screen.anchorIndices(for: quantifierLike).isEmpty)
        #expect(screen.candidates(for: "no determinant here").contains { $0.name == "quantifier-like" })
    }
}
