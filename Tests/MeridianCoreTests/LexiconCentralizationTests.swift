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
