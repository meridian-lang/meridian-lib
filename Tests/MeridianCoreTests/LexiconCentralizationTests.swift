import Testing
import Foundation
@testable import MeridianCore

// Regression coverage for the lexicon-centralization / dedup work: the
// FixedGrammar skeleton, the author-extensible `=== triggers ===` and the
// data-backed `=== sections ===` builtin alias seed. These lock the default
// surface so a future "centralization" refactor can't silently shift behavior.

@Suite("FixedGrammar — defaults & threading")
struct FixedGrammarDefaultsTests {

    @Test("default lexicon carries the fixed grammar skeleton")
    func defaults() {
        let g = EnglishLexicon.default.grammar
        #expect(g.relativizers.contains("that"))
        #expect(g.relativizers.contains("which"))
        #expect(g.discretionMarker == "with discretion")
        #expect(g.autonomyMarker == "with autonomy")
        #expect(g.decideWhetherIntroducer == "decide whether ")
        #expect(g.passiveByMarker == " by ")
        #expect(g.pastParticipleSuffixes == ["ed", "en"])
        #expect(g.relativeClauseMarkers == [" that "])
        #expect(g.emptyPredicateSuffix == " is empty")
        #expect(g.notEmptyPredicateSuffix == " is not empty")
        #expect(g.suffixConditionalNegated == " unless ")
        #expect(g.scalarNavConnectors == ["to", "by"])
        #expect(g.afterIdiomIntroducer == "after ")
        #expect(g.tryIdiomFailureSeparator == "; if it fails ")
        #expect(g.iterationMarkers.embeddedEachMarkers == [" every ", " each "])
        #expect(g.autonomyMarkers.replanAfter == ["re-plan after", "replan after"])
        #expect(g.autonomyMarkers.maxSteps == ["max", "up to"])
        #expect(g.autonomyMarkers.boundaryMarkers.contains(" until "))
        #expect(g.judgmentFollowCollectPrefix == "use judgment to follow the ")
        #expect(g.judgmentFollowCollectSuffix == " guidance:")
        #expect(g.judgmentFollowCollectLine(heading: "Phases") == "use judgment to follow the Phases guidance:")
        #expect(g.decidingTheIntroducer == "deciding the ")
        #expect(g.questionArrowJudgmentGoal == "use judgment to weigh each question below:")
        #expect(g.merconfig.isKeyedByMarker == " is keyed by ")
        #expect(g.merconfig.voidReturnTypeNames.contains("void"))
        #expect(EnglishLexicon.default.approvalToolIDSubstrings.contains("approve"))
        #expect(g.lintMarkers.politenessPrefixes == ["please "])
        #expect(g.lintMarkers.uncertaintyMarkers == [" maybe ", "maybe "])
        #expect(g.statement.branchOnPrefix == "branch on ")
        #expect(g.statement.matchBranchWildcardLabels == ["anything", "_"])
        #expect(g.statement.matchBranchCanonicalWildcard == "anything")
        #expect(g.statement.matchOtherwiseLabel == "otherwise:")
        #expect(g.statement.possessionPrefixes == ["has ", "have "])
        #expect(g.templateDirectives.ifPrefix == "[if ")
        #expect(g.templateDirectives.otherwiseTerminator == "[otherwise]")
        #expect(g.verbalizer.assertPrefix == "assert ")
        #expect(g.verbalizer.workflowHeaderPrefix == "To ")
        #expect(g.verbalizer.aggregateCountPrefix == "the number of ")
        #expect(g.verbalizer.templateHoleOpen == "{{ ")
        #expect(g.statement.forEachPrefix == "for each ")
        #expect(EnglishLexicon.default.emptyMarkers.contains(" have no "))
        #expect(EnglishLexicon.default.filledMarkers.contains(" have a "))
    }

    @Test("Verbalizer match-branch and possession markers track FixedGrammar defaults")
    func verbalizerReadsFixedGrammarMarkers() {
        let g = EnglishLexicon.default.grammar
        let done = IRBlock(statements: [.complete(CompleteIR())])
        let match = BranchIR(
            condition: .match(.identifierRef(name: "choice"), [
                BranchCase(pattern: .wildcard, block: done),
            ]),
            thenBlock: done
        )
        let model = VerbalizerModel(
            workflows: [
                IRWorkflow(name: "audit choice", parameters: [], body: IRBlock(statements: [.branch(match)]))
            ],
            loweredDefinitions: [],
            inlineDefinitions: [],
            symbols: SymbolTable(trace: .silent()),
            lexicon: .default,
            sourceFileName: "guard.meri",
            authoredSource: ""
        )
        let verbalizer = Verbalizer(model: model)
        let surface = verbalizer.verbalize(.branch(match))
        #expect(surface.hasPrefix(g.statement.branchOnPrefix), Comment(rawValue: surface))
        #expect(surface.contains(g.statement.matchBranchCanonicalWildcard + ":"), Comment(rawValue: surface))
        #expect(surface.contains(g.statement.matchOtherwiseLabel), Comment(rawValue: surface))
        #expect(g.statement.possessionPrefixes.allSatisfy { $0.hasSuffix(" ") })

        let assertSurface = verbalizer.verbalize(.assert(AssertIR(
            condition: .literal(.boolean(true)),
            otherwiseAction: done
        )))
        #expect(assertSurface.contains("assert "), Comment(rawValue: assertSurface))
        #expect(assertSurface.contains(g.statement.matchOtherwiseLabel), Comment(rawValue: assertSurface))

        let emptyBody = verbalizer.verbalize(.quantified(QuantifierIR(
            kind: .all,
            description: DescriptionIR(
                collection: .identifierRef(name: "pages"),
                elementVar: "page"
            ),
            body: .comparison(
                .propertyAccess(.identifierRef(name: "page"), propertyName: "tags"),
                .isEmpty,
                .literal(.boolean(true))
            )
        )))
        #expect(emptyBody.contains("have no"), Comment(rawValue: emptyBody))
    }

    @Test("merging preserves the grammar passthrough unchanged")
    func mergingPreservesGrammar() {
        let merged = EnglishLexicon.default.merging(
            comparisonSynonyms: [],
            durationSynonyms: ["fortnight": .week]
        )
        #expect(merged.grammar.discretionMarker == "with discretion")
        #expect(merged.grammar.relativeClauseMarkers == [" that "])
    }

    @Test("condition cue words + comparison-op spellings are centralized data")
    func conditionAndComparisonData() {
        let g = EnglishLexicon.default.grammar
        #expect(g.conditionCueWords == ["equals", "not"])
        // The synonym-target spelling table maps plain English to the AST op.
        #expect(g.comparisonOpSpellings["greater than"] == .greaterThan)
        #expect(g.comparisonOpSpellings["less or equal to"] == .lessOrEqual)
        #expect(g.comparisonOpSpellings["equals"] == .equal)
        #expect(g.comparisonOpSpellings["not equals"] == .notEqual)
        #expect(g.comparisonOpSpellings["within"] == .within)
        #expect(g.comparisonOpSpellings["nonsense"] == nil)
    }

    @Test("affirmative suffix conditional falls back when only negated marker is configured")
    func affirmativeSuffixFallback() {
        let grammar = FixedGrammar(
            suffixConditionalMarkers: [" unless "],
            suffixConditionalNegated: " unless "
        )
        #expect(grammar.affirmativeSuffixConditionalMarker == " only when ")
    }
}

@Suite("EnglishLexicon — morphology branch coverage")
struct EnglishLexiconMorphologyBranchTests {
    @Test("pluralize and verb morphology cover empty and suffix branches")
    func morphologyBranches() {
        let lex = EnglishLexicon.default
        #expect(lex.singularize("boxes") == "box")
        #expect(lex.singularize("buzzes") == "buzz")
        #expect(lex.singularize("churches") == "church")
        #expect(lex.singularize("brushes") == "brush")
        #expect(lex.singularize("ties") == "ty")
        #expect(lex.singularize("series") == "sery")
        #expect(lex.pluralize("") == "")
        #expect(lex.pluralize("box") == "boxes")
        #expect(lex.pluralize("church") == "churches")
        #expect(lex.pluralize("brush") == "brushes")
        #expect(lex.pluralize("buzz") == "buzzes")
        #expect(lex.pluralize("status") == "status")
        #expect(lex.pluralize("toy") == "toys")
        #expect(lex.pluralize("city") == "cities")
        #expect(lex.thirdPersonSingular("") == "")
        #expect(lex.thirdPersonSingular("go") == "goes")
        #expect(lex.thirdPersonSingular("fix") == "fixes")
        #expect(lex.thirdPersonSingular("buzz") == "buzzes")
        #expect(lex.thirdPersonSingular("watch") == "watches")
        #expect(lex.thirdPersonSingular("try") == "tries")
        #expect(lex.regularPastParticiple("") == "")
        #expect(lex.regularPastParticiple("move") == "moved")
        #expect(lex.regularPastParticiple("play") == "played")
        #expect(lex.regularPastParticiple("try") == "tried")
        #expect(lex.regularPastParticiple("walk") == "walked")

        let merged = lex.merging(
            comparisonSynonyms: [],
            durationSynonyms: ["fortnight": .week],
            timestampProperty: "createdAt",
            emptySynonyms: ["lacks"],
            filledSynonyms: ["includes"],
            pastWindowSynonyms: ["during the past"],
            futureWindowSynonyms: ["during the next"],
            timestampAliasSynonyms: ["touched"],
            superlativeSynonyms: ["freshest": .newest],
            sortBySynonyms: ["ordered by"],
            ascendingSynonyms: ["up"],
            descendingSynonyms: ["down"],
            possessiveSynonyms: ["our"],
            anaphoraSynonyms: ["that value"],
            conditionHeaderSynonyms: ["given"],
            actionHeaderSynonyms: ["outcome"],
            wildcardSynonyms: ["whatever"],
            shellFenceSynonyms: ["fish"]
        )
        #expect(merged.parseDuration("2 fortnights")?.1 == .week)
        #expect(merged.parseDuration("2 widgets") == nil)
        #expect(merged.timestampProperty == "createdAt")
        #expect(merged.emptyMarkers.contains(" lacks "))
        #expect(merged.filledMarkers.contains(" includes "))
        #expect(merged.temporalWindowMarkers.contains { $0.0 == " during the past " && $0.1 == .withinPast })
        #expect(merged.temporalWindowMarkers.contains { $0.0 == " during the next " && $0.1 == .withinFuture })
        #expect(merged.timestampAliases.contains("touched"))
        #expect(merged.superlativeGradables["freshest"] == .newest)
        #expect(merged.sortByMarkers.contains(" ordered by "))
        #expect(merged.ascendingMarkers.contains("up"))
        #expect(merged.descendingMarkers.contains("down"))
        #expect(merged.possessivePronouns.contains("our "))
        #expect(merged.anaphoraMarkers.contains("that value"))
        #expect(merged.tableConditionHeaders.contains("given"))
        #expect(merged.tableActionHeaders.contains("outcome"))
        #expect(merged.tableWildcardTokens.contains("whatever"))
        #expect(merged.isShellFence("fish"))
        #expect(lex.structName(from: "123 import") == "_123Import")
        #expect(lex.structName(from: "the an a") == "Workflow")
    }
}

@Suite("Comparison-alias folding — copula-less canonical spellings are live")
struct ComparisonFoldingTests {

    private func op(_ s: String) -> ComparisonOpAST? {
        if case .comparison(_, let op, _) = ExpressionParser(symbols: nil, trace: .silent()).parse(s) {
            return op
        }
        return nil
    }

    @Test("bare spellings parse as comparisons without a copula")
    func bareForms() {
        #expect(op("the total greater than 5") == .greaterThan)
        #expect(op("the total more than 5") == .greaterThan)
        #expect(op("the total less than 5") == .lessThan)
        #expect(op("the total fewer than 5") == .lessThan)
        #expect(op("the total at least 5") == .greaterOrEqual)
        #expect(op("the total at most 5") == .lessOrEqual)
        // The `… than or equal to` (≥/≤) family works too: the marker-internal
        // `or` is shielded from the boolean disjunction splitter.
        #expect(op("the total greater than or equal to 5") == .greaterOrEqual)
        #expect(op("the total more than or equal to 5") == .greaterOrEqual)
        #expect(op("the total less than or equal to 5") == .lessOrEqual)
        #expect(op("the total is more than or equal to 5") == .greaterOrEqual)
        #expect(op("the status equals \"open\"") == .equal)
        #expect(op("the status equal to \"open\"") == .equal)
    }

    @Test("a genuine disjunction still splits even alongside a ≥ comparison")
    func disjunctionStillSplits() {
        let e = ExpressionParser(symbols: nil, trace: .silent())
            .parse("the total is more than or equal to 5 or the status equals \"open\"")
        guard case .logical(.or, let ops) = e else {
            Issue.record("expected a top-level disjunction, got: \(e)")
            return
        }
        #expect(ops.count == 2)
        if case .comparison(_, let op0, _) = ops[0] { #expect(op0 == .greaterOrEqual) }
        else { Issue.record("lhs not a comparison: \(ops[0])") }
        if case .comparison(_, let op1, _) = ops[1] { #expect(op1 == .equal) }
        else { Issue.record("rhs not a comparison: \(ops[1])") }
    }

    @Test("copula forms still bind to the `is X` marker (priority preserved)")
    func copulaForms() {
        #expect(op("the total is greater than 5") == .greaterThan)
        #expect(op("the total is at least 5") == .greaterOrEqual)
        #expect(op("the status is pending") == .equal)
        #expect(op("the status is not pending") == .notEqual)
    }
}

@Suite("Shell-fence dialects — default + author-extensible")
struct ShellFenceLexiconTests {

    @Test("default lexicon carries the canonical shell dialects")
    func defaults() {
        let l = EnglishLexicon.default
        for d in ["bash", "sh", "shell", "console", "zsh"] {
            #expect(l.isShellFence(d))
            #expect(l.isShellFence(d.uppercased())) // case-insensitive
        }
        #expect(!l.isShellFence("fish"))
    }

    @Test("=== language === Shell fence synonyms extends the dialect set")
    func authorExtends() {
        let merged = EnglishLexicon.default.merging(
            comparisonSynonyms: [],
            durationSynonyms: [:],
            shellFenceSynonyms: ["fish", "PWSH", "nu"]
        )
        #expect(merged.isShellFence("fish"))
        #expect(merged.isShellFence("pwsh")) // synonyms lower-cased on merge
        #expect(merged.isShellFence("nu"))
        #expect(merged.isShellFence("bash")) // defaults retained (union)
    }
}

@Suite("Fence tool mapping — general-abilities extension")
struct FenceToolMappingLexiconTests {

    @Test("default lexicon has no fence tool mapping")
    func defaultsAreEmpty() {
        #expect(EnglishLexicon.default.fenceTool(for: "python") == nil)
    }

    @Test("=== language === Fence tool mapping populates a non-shell fence lookup")
    func authorExtends() {
        let merged = EnglishLexicon.default.merging(
            comparisonSynonyms: [],
            durationSynonyms: [:],
            fenceToolSynonyms: ["Python": "interpreter.run", "node": "interpreter.runJS"]
        )
        #expect(merged.fenceTool(for: "python") == "interpreter.run") // key lower-cased on merge
        #expect(merged.fenceTool(for: "PYTHON") == "interpreter.run") // lookup is case-insensitive too
        #expect(merged.fenceTool(for: "node") == "interpreter.runJS") // tool ID keeps its original case
        #expect(merged.fenceTool(for: "ruby") == nil)
        // A shell dialect stays shell-classified even if a domain (oddly)
        // also maps it — isShellFence takes precedence at call sites.
        #expect(merged.isShellFence("bash"))
    }

    @Test("author-supplied mapping overrides a same-key default on merge")
    func authorOverrides() {
        let base = EnglishLexicon.default.merging(
            comparisonSynonyms: [],
            durationSynonyms: [:],
            fenceToolSynonyms: ["python": "interpreter.run"]
        )
        let overridden = base.merging(
            comparisonSynonyms: [],
            durationSynonyms: [:],
            fenceToolSynonyms: ["python": "custom.pythonRunner"]
        )
        #expect(overridden.fenceTool(for: "python") == "custom.pythonRunner")
    }

    @Test("a ```python fence with a configured mapping lowers to one plain invoke, end to end")
    func toolFenceLowersToPlainInvoke() throws {
        let lexicon = EnglishLexicon.default.merging(
            comparisonSynonyms: [],
            durationSynonyms: [:],
            fenceToolSynonyms: ["python": "interpreter.run"]
        )
        let symbols = SymbolTable()
        let ast = try MeridianParser(symbols: symbols, trace: .silent(), lexicon: lexicon).parse("""
        To score, with discretion:
          ```python
          print("hi")
          x = 1 + 1
          ```
        """, file: "test.meridian")
        let workflows = try ASTToIR(symbols: symbols, sourceFile: "test.meridian", trace: .silent(), lexicon: lexicon).lower(ast)
        guard case .invoke(let invoke) = workflows[0].body.statements.first else {
            Issue.record("expected a single invoke, got \(workflows[0].body.statements.first as Any)")
            return
        }
        #expect(invoke.toolID == "interpreter.run")
        guard case .literal(.string(let code)) = invoke.arguments.first?.value else {
            Issue.record("expected a literal code argument"); return
        }
        #expect(code == "print(\"hi\")\nx = 1 + 1")
        #expect(invoke.arguments.first?.key == "code")

        // Emitted Swift wraps the whole multi-line body as one escaped
        // string argument to the configured tool — a plain invoke, no
        // per-line splitting and no shell-style {…} hole interpolation.
        let out = try SwiftEmitter(options: .init(emitSourceLineComments: false)).emitFile(workflows: workflows)
        #expect(out.contains("tool: \"interpreter.run\""))
        #expect(out.contains("\"code\": .string(\"print(\\\"hi\\\")\\nx = 1 + 1\")"))
    }

    @Test("a fenced language with no configured mapping is rejected, not silently misrouted")
    func unmappedNonShellFenceIsRejected() throws {
        let lexicon = EnglishLexicon.default.merging(
            comparisonSynonyms: [],
            durationSynonyms: [:],
            fenceToolSynonyms: ["python": "interpreter.run"]
        )
        let symbols = SymbolTable()
        // ```ruby has no mapping entry, so it is not a code-block sentinel
        // this production recognizes. Pre-existing "orphaned fenced code
        // block" diagnostic behavior — it must not be misrouted to
        // interpreter.run just because *some* mapping exists.
        #expect(throws: (any Error).self) {
            _ = try MeridianParser(symbols: symbols, trace: .silent(), lexicon: lexicon).parse("""
            To score, with discretion:
              ```ruby
              puts "hi"
              ```
            """, file: "test.meridian")
        }
    }
}

@Suite("Rulebook — === triggers === family")
struct TriggerRulebookTests {

    @Test("builtin defaults classify the canonical kinds")
    func builtinClassification() {
        let c = TriggerClassifier(lexicon: .default)
        #expect(c.classify("nightly", sourceLine: 1).kind == .schedule)
        #expect(c.classify("every morning", sourceLine: 1).kind == .schedule) // schedule beats ambient
        #expect(c.classify("always on", sourceLine: 1).kind == .ambient)
        #expect(c.classify("webhook received", sourceLine: 1).kind == .event)
        #expect(c.classify("user asks for a summary", sourceLine: 1).kind == .keyword)
        #expect(c.classify("0 9 * * 1", sourceLine: 1).kind == .schedule) // cron-like
    }

    @Test("classify logs the classification decision under .lowering")
    func classifyTraced() {
        let cap = ParserTrace.capturing(categories: [.lowering])
        let c = TriggerClassifier(lexicon: .default, trace: cap.trace)
        #expect(c.classify("nightly", sourceLine: 3).kind == .schedule)
        let lines = cap.lines()
        #expect(lines.contains { $0.contains("trigger classify") && $0.contains("L3") && $0.contains("nightly") && $0.contains("schedule") })
    }

    @Test("an author === triggers === block extends classification")
    func authorExtends() throws {
        let rb = try RulebookParser(trace: .silent()).parse("""
        === triggers ===
        schedule: fortnightly, quarterly
        event: ingested
        """, file: "x.merrules")
        #expect(rb.triggerWords.contains(TriggerWordRule(kind: .schedule, word: "fortnightly", sourceLine: 2)))
        let c = TriggerClassifier(lexicon: .default, rulebook: rb)
        // New words classify; built-in defaults still apply (union, not replace).
        #expect(c.classify("fortnightly", sourceLine: 1).kind == .schedule)
        #expect(c.classify("data ingested", sourceLine: 1).kind == .event)
        #expect(c.classify("nightly", sourceLine: 1).kind == .schedule)
    }

    @Test("unknown trigger kind is a hard error")
    func unknownKind() {
        #expect(throws: CompilerError.self) {
            _ = try RulebookParser(trace: .silent()).parse("""
            === triggers ===
            sometime: occasionally
            """, file: "x.merrules")
        }
    }

    @Test("defaultTriggers seed matches the historical word sets")
    func seedStability() {
        let sets = Rulebook.defaultTriggers.triggerWordSets()
        #expect(sets[.schedule] == [
            "nightly", "daily", "hourly", "weekly", "monthly", "cron", "schedule",
            "scheduled", "morning", "evening", "midnight", "noon",
        ])
        #expect(sets[.ambient] == [
            "always", "ambient", "continuous", "continuously", "inbound", "every",
            "stream", "streaming", "watch", "watching", "ongoing",
        ])
        #expect(sets[.event] == [
            "received", "arrives", "arrived", "created", "updated", "deleted",
            "webhook", "fires", "fired", "pushed", "merged", "opened", "closed", "on",
        ])
    }
}

@Suite("Rulebook — === sections === builtin alias data")
struct SectionAliasDataTests {

    @Test("defaultSections data agrees with builtinRole for every alias")
    func defaultsAgree() {
        for rule in Rulebook.defaultSections.sectionRoles {
            #expect(SkillSectionRole.builtinRole(forHeading: rule.alias) == rule.role,
                    Comment(rawValue: "alias \(rule.alias) disagreed"))
        }
    }

    @Test("representative builtin aliases still resolve")
    func representativeAliases() {
        #expect(SkillSectionRole.builtinRole(forHeading: "Contract") == .invariants)
        #expect(SkillSectionRole.builtinRole(forHeading: "Workflow") == .procedure)
        #expect(SkillSectionRole.builtinRole(forHeading: "When To Use") == .applicability)
        #expect(SkillSectionRole.builtinRole(forHeading: "Prerequisites") == .applicability)
        #expect(SkillSectionRole.builtinRole(forHeading: "When NOT To Use") == .negativeApplicability)
        #expect(SkillSectionRole.builtinRole(forHeading: "Anti-Patterns") == .prohibitions)
        #expect(SkillSectionRole.builtinRole(forHeading: "Quality Rules") == .invariants)
        #expect(SkillSectionRole.builtinRole(forHeading: "Verification Checklist") == .invariants)
        #expect(SkillSectionRole.builtinRole(forHeading: "Output Format") == .template)
        #expect(SkillSectionRole.builtinRole(forHeading: "Tools Used") == .tools)
    }

    @Test("general-abilities: non-gbrain procedure heading synonyms resolve to procedure")
    func generalAbilitiesProcedureSynonyms() {
        #expect(SkillSectionRole.builtinRole(forHeading: "Instructions") == .procedure)
        #expect(SkillSectionRole.builtinRole(forHeading: "Usage") == .procedure)
        #expect(SkillSectionRole.builtinRole(forHeading: "Quickstart") == .procedure)
        #expect(SkillSectionRole.builtinRole(forHeading: "Quick Start") == .procedure)
        #expect(SkillSectionRole.builtinRole(forHeading: "How It Works") == .procedure)
    }

    @Test("open-ended numbered-phase heading is still procedure")
    func phasePrefix() {
        #expect(SkillSectionRole.builtinRole(forHeading: "Phase 1: Inventory") == .procedure)
        #expect(SkillSectionRole.builtinRole(forHeading: "Phase A.5: Settle") == .procedure)
    }

    @Test("an unrecognised heading remains unresolved")
    func unresolved() {
        #expect(SkillSectionRole.builtinRole(forHeading: "Philosophy") == nil)
    }
}

@Suite("Lexicon merge recipe — Phase 1 cleanup categories")
struct LexiconPhase1RecipeTests {
    private func mergedLexicon(from cfg: String) throws -> EnglishLexicon {
        let config = try MerConfigParser(trace: .silent()).parse(cfg, file: "t.merconfig")
        return EnglishLexicon.default.merging(from: config.languageSynonyms)
    }

    @Test("vague-hedge and effectful-judgment synonyms merge into the lexicon")
    func vagueHedgeAndEffectfulJudgment() throws {
        let lex = try mergedLexicon(from: """
        === language ===
        Vague-hedge synonyms:
          kinda
        Effectful-judgment synonyms:
          scrub the
        """)
        #expect(lex.conditionVagueHedges.contains("kinda"))
        #expect(lex.effectfulJudgmentCuePhrases.contains("scrub the"))
    }

    @Test("article, preposition, copula, participle, and tool-stopword synonyms merge")
    func surfaceVocabularySynonyms() throws {
        let lex = try mergedLexicon(from: """
        === language ===
        Article synonyms:
          da
        Parameter-article synonyms:
          ein
        Preposition synonyms:
          durch
        Copula synonyms:
          sein
        Participle synonyms:
          gekauft
        Tool-stopword synonyms:
          ausführen
        """)
        #expect(lex.articles.contains("da"))
        #expect(lex.parameterArticles.contains("ein"))
        #expect(lex.prepositions.contains("durch"))
        #expect(lex.copulas.contains("sein"))
        #expect(lex.participles.contains("gekauft"))
        #expect(lex.toolStopwords.contains("ausführen"))
    }

    @Test("irregular-plural mapping and contract-reference synonyms merge")
    func pluralAndContractReference() throws {
        let lex = try mergedLexicon(from: """
        === language ===
        Irregular-plural mapping:
          maus = mäuse
        Contract-reference synonyms:
          bereits erzwungen
        """)
        #expect(lex.pluralize("maus") == "mäuse")
        #expect(lex.contractReferencePhrases.contains("bereits erzwungen"))
    }

    @Test("merging(from:) matches Compiler bootstrap lexicon merge")
    func mergingFromMatchesBootstrap() throws {
        let cfg = """
        === language ===
        Normative-cue synonyms:
          shall
        Shell fence synonyms:
          fish
        Vague-hedge synonyms:
          kinda
        """
        let config = try MerConfigParser(trace: .silent()).parse(cfg, file: "t.merconfig")
        let fromHelper = EnglishLexicon.default.merging(from: config.languageSynonyms)
        let fromBootstrap = try Compiler().knowledge(
            forSource: "",
            sourceFile: "probe.meri",
            vocabularies: [Compiler.VocabularyInput(name: "t", file: "t.merconfig", source: cfg)]
        ).lexicon
        #expect(fromHelper.normativeCueWords == fromBootstrap.normativeCueWords)
        #expect(fromHelper.shellFenceLanguages == fromBootstrap.shellFenceLanguages)
        #expect(fromHelper.conditionVagueHedges == fromBootstrap.conditionVagueHedges)
    }

    @Test("custom shell fence is honored on migrator metrics path")
    func customShellFenceOnMetricsPath() throws {
        let cfg = """
        === language ===
        Shell fence synonyms:
          fish
        """
        let lex = try mergedLexicon(from: cfg)
        let body = """
        To run:
          ```fish
          echo hi
          ```
        """
        let metrics = SkillMetrics.analyze(body, lexicon: lex)
        #expect(metrics.inertSections == 0)
    }

    @Test("definite-article take prefix still works after article synonym merge")
    func articleTakePrefix() throws {
        let lex = EnglishLexicon.default.merging(
            comparisonSynonyms: [],
            durationSynonyms: [:],
            articleSynonyms: ["das"]
        )
        let out = try Compiler(options: .init(lexicon: lex, fallbackPolicy: .lenient)).compile(
            meridianSource: """
            To process:
              for each the first 5 orders:
                complete.
            """,
            meridianFile: "test.meridian",
            merconfigSource: "",
            merconfigFile: "test.merconfig"
        )
        #expect(out.contains(".prefix(5)"))
    }

    @Test("CanonicalForms.comparison round-trips equal and notEqual")
    func comparisonRoundTripEqualNotEqual() throws {
        let lex = EnglishLexicon.default
        let cases: [(ComparisonOp, ComparisonOpAST, String)] = [
            (.equal, .equal, "equals"),
            (.notEqual, .notEqual, "is not"),
        ]
        for (irOp, astOp, surface) in cases {
            #expect(CanonicalForms.comparison(irOp, lexicon: lex) == surface)
            let parsed = ExpressionParser(symbols: nil, trace: .silent(), lexicon: lex)
                .parse("the status \(surface) \"open\"")
            if case .comparison(_, let parsedOp, _) = parsed {
                #expect(parsedOp == astOp)
            } else {
                Issue.record("expected comparison for \(surface), got \(parsed)")
            }
        }
    }
}
