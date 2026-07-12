import Foundation

struct PegexSurfaceGrammar {
    let lexicon: EnglishLexicon

    init(lexicon: EnglishLexicon = .default) {
        self.lexicon = lexicon
    }

    var table: GrammarTable {
        GrammarTable(productions: [
            literals,
            possessiveChain,
            comparison,
            boolean,
            traceEventPattern,
            traceStatisticalFrequency,
            traceTemporalEver,
            traceTemporalWindow,
            traceTemporalCount,
            traceTemporalInARow,
            traceTemporalSince,
            traceScopeMarker,
            temporalWindow,
            emptiness,
            quantifier,
            aggregate,
            superlative,
            description,
            activeVerb,
            scalarNavigation,
            tableLookup,
            textTemplateConditional,
            textTemplateLoop,
            textTemplateFormatter,
            afterIdiom,
            exceptWhenIdiom,
            tryRecoverIdiom,
            suffixConditionalIdiom,
            compoundNote,
        ])
    }

    /// `"approved"` / `42` / `$5000` — literal and atomic expression forms.
    private var literals: GrammarProduction {
        GrammarProduction(
            name: "literal-atom",
            category: .expression,
            implementation: .pegex,
            canonicalExample: "`\"approved\"`, `42`, `$5000`, `now`",
            summary: "Atomic values and bare references.",
            anchors: ["\"", "$", "now"]
        )
    }

    /// `"the order's id"` — a possessive property-access chain.
    private var possessiveChain: GrammarProduction {
        GrammarProduction(
            name: "possessive-chain",
            category: .expression,
            implementation: .handWritten,
            canonicalExample: "`the order's id`",
            summary: "Property access through possessive English.",
            anchors: ["'s"] + Array(lexicon.articles)
        )
    }

    /// `"total amount is more than 500"` — a comparison marker from the lexicon.
    private var comparison: GrammarProduction {
        GrammarProduction(
            name: "comparison",
            category: .expression,
            implementation: .pegex,
            canonicalExample: "`total amount is more than 500`",
            summary: "Comparison between two expressions.",
            anchors: lexicon.comparisonMarkers.map(\.0)
        )
    }

    /// `"not A and either B or C"` — boolean composition of conditions.
    private var boolean: GrammarProduction {
        let connectors = lexicon.grammar.booleanConnectors
        return GrammarProduction(
            name: "boolean",
            category: .expression,
            implementation: .pegex,
            canonicalExample: "`not A and either B or C`",
            summary: "`not` > `and` > `or`, with `either ... or ...` grouping.",
            anchors: [
                connectors.notPrefix,
                connectors.andMarker,
                connectors.orMarker,
                connectors.eitherPrefix,
            ]
        )
    }

    private var traceEventPattern: GrammarProduction {
        GrammarProduction(
            name: "trace-event-pattern",
            category: .expression,
            implementation: .handWritten,
            canonicalExample: "`the deploy step failed`",
            summary: "Trace event subject plus outcome verb.",
            anchors: Array(lexicon.traceOutcomeVerbs.keys)
        )
    }

    private var traceStatisticalFrequency: GrammarProduction {
        GrammarProduction(
            name: "trace-statistical-frequency",
            category: .expression,
            implementation: .handWritten,
            canonicalExample: "`the fetch step succeeds in at least 95% of runs, checked every 1 days`",
            summary: "Statistical frequency over runs or occurrences.",
            anchors: [
                lexicon.grammar.traceStatisticalAtLeastMarker,
                lexicon.grammar.traceStatisticalAtMostMarker,
                lexicon.grammar.traceStatisticalUsuallyMarker,
                lexicon.grammar.traceStatisticalRarelyMarker,
                lexicon.grammar.traceStatisticalCheckedEveryMarker,
            ]
        )
    }

    private var traceTemporalEver: GrammarProduction {
        GrammarProduction(
            name: "trace-temporal-ever",
            category: .expression,
            implementation: .handWritten,
            canonicalExample: "`the deploy step has ever failed`",
            summary: "Whether an event has ever occurred.",
            anchors: [lexicon.grammar.traceHasEverMarker]
        )
    }

    private var traceTemporalWindow: GrammarProduction {
        GrammarProduction(
            name: "trace-temporal-window",
            category: .expression,
            implementation: .handWritten,
            canonicalExample: "`the deploy step failed within the last 7 days`",
            summary: "Whether an event occurred within a trailing window.",
            anchors: [lexicon.grammar.traceWithinLastMarker]
        )
    }

    private var traceTemporalCount: GrammarProduction {
        GrammarProduction(
            name: "trace-temporal-count",
            category: .expression,
            implementation: .handWritten,
            canonicalExample: "`the deploy step failed at least 3 times within the last 7 days`",
            summary: "Windowed counts of matching trace events.",
            anchors: [
                lexicon.grammar.traceWithinLastMarker,
                lexicon.grammar.traceInARowSuffix,
                lexicon.grammar.quantifierDeterminers.atLeastPrefix,
                lexicon.grammar.quantifierDeterminers.atMostPrefix,
                lexicon.grammar.quantifierDeterminers.exactlyPrefix,
            ]
        )
    }

    private var traceTemporalInARow: GrammarProduction {
        GrammarProduction(
            name: "trace-temporal-in-a-row",
            category: .expression,
            implementation: .handWritten,
            canonicalExample: "`the deploy step failed 3 times in a row`",
            summary: "Consecutive matching trace events.",
            anchors: [lexicon.grammar.traceInARowSuffix]
        )
    }

    private var traceTemporalSince: GrammarProduction {
        GrammarProduction(
            name: "trace-temporal-since",
            category: .expression,
            implementation: .handWritten,
            canonicalExample: "`the service is healthy since the last deploy step succeeded`",
            summary: "Predicate holding strictly after the last anchor event.",
            anchors: [lexicon.grammar.traceSinceLastMarker]
        )
    }

    private var traceScopeMarker: GrammarProduction {
        GrammarProduction(
            name: "trace-scope-marker",
            category: .expression,
            implementation: .handWritten,
            canonicalExample: "`across all runs, the deploy step has ever failed`",
            summary: "Trace-temporal scope extension across runs.",
            anchors: [lexicon.grammar.traceAcrossAllRunsMarker]
        )
    }

    /// `"updated within the last 7 days"` — one-sided temporal windows.
    private var temporalWindow: GrammarProduction {
        GrammarProduction(
            name: "temporal-window",
            category: .expression,
            implementation: .pegex,
            canonicalExample: "`updated within the last 7 days`",
            summary: "Past/future date windows over a timestamp property.",
            anchors: lexicon.temporalWindowMarkers.map(\.0)
        )
    }

    /// `"page has no summary"` — property-backed emptiness.
    private var emptiness: GrammarProduction {
        GrammarProduction(
            name: "emptiness",
            category: .expression,
            implementation: .pegex,
            canonicalExample: "`page has no summary`",
            summary: "Empty/non-empty checks over properties and collections.",
            // "empty" covers the bare `is empty`/`is not empty` suffix forms
            // (`FixedGrammar.emptyPredicateSuffix`/`notEmptyPredicateSuffix`),
            // in addition to the `has no`/`has a` property-backed markers.
            anchors: lexicon.emptyMarkers + lexicon.filledMarkers + ["empty"]
        )
    }

    /// `"no stale pages whose status is draft"` — quantified descriptions.
    private var quantifier: GrammarProduction {
        let determiners = lexicon.grammar.quantifierDeterminers
        return GrammarProduction(
            name: "quantifier",
            category: .description,
            implementation: .pegex,
            canonicalExample: "`no stale pages whose status is draft`",
            summary: "All/any/no/count quantifiers over descriptions.",
            anchors: determiners.all + determiners.any + determiners.none + [
                determiners.atLeastPrefix,
                determiners.atMostPrefix,
                determiners.exactlyPrefix,
            ]
        )
    }

    /// `"the number of stale pages"` — aggregate over a description.
    private var aggregate: GrammarProduction {
        GrammarProduction(
            name: "aggregate",
            category: .description,
            implementation: .pegex,
            canonicalExample: "`the number of stale pages`",
            summary: "Count/list aggregations over descriptions.",
            anchors: lexicon.aggregateIntroducers.map(\.0)
        )
    }

    /// `"the oldest stale page"` — superlative over a description.
    private var superlative: GrammarProduction {
        GrammarProduction(
            name: "superlative",
            category: .description,
            implementation: .pegex,
            canonicalExample: "`the oldest stale page`",
            summary: "Sorted single-element selection from a description.",
            anchors: Array(lexicon.superlativeGradables.keys)
        )
    }

    /// `"the stale pages that mention the entity"` — first-class description.
    private var description: GrammarProduction {
        let markers = lexicon.grammar.iterationMarkers
        return GrammarProduction(
            name: "description",
            category: .description,
            implementation: .pegex,
            canonicalExample: "`the stale pages that mention the entity`",
            summary: "Description query plans with filters, relation clauses, sort, and take.",
            anchors: [
                markers.whoseMarker,
                markers.firstPrefix,
                markers.collectionInMarker,
            ] + Array(lexicon.grammar.relativizers) + lexicon.sortByMarkers
        )
    }

    /// `"the user owns the page"` — active relation verb condition.
    private var activeVerb: GrammarProduction {
        GrammarProduction(
            name: "active-verb",
            category: .expression,
            implementation: .handWritten,
            canonicalExample: "`the user owns the page`",
            summary: "Declared verb forms bound to backed relations.",
            anchors: Array(lexicon.grammar.relativizers)
        )
    }

    /// `"the task assigned to the user"` — scalar relation navigation.
    private var scalarNavigation: GrammarProduction {
        GrammarProduction(
            name: "scalar-navigation",
            category: .expression,
            implementation: .handWritten,
            canonicalExample: "`the task assigned to the user`",
            summary: "One-to-one relation traversal used as a value.",
            anchors: Array(lexicon.grammar.scalarNavConnectors).sorted()
        )
    }

    /// `"the skill corresponding to the trigger phrase ... in the table"` — lookup.
    private var tableLookup: GrammarProduction {
        let lookup = lexicon.grammar.tableLookup
        return GrammarProduction(
            name: "table-lookup",
            category: .expression,
            implementation: .pegex,
            canonicalExample: "`the skill corresponding to the trigger phrase \"daily\" in the table`",
            summary: "Deterministic lookup in a bound data table.",
            anchors: [lookup.correspondingToMarker, lookup.inTableMarker]
        )
    }

    /// `"[if page is stale]STALE[otherwise]fresh[end if]"` — conditional text.
    private var textTemplateConditional: GrammarProduction {
        let template = lexicon.grammar.templateDirectives
        return GrammarProduction(
            name: "template-conditional",
            category: .template,
            implementation: .handWritten,
            canonicalExample: "`[if page is stale]STALE[otherwise]fresh[end if]`",
            summary: "Conditional branch inside a text template.",
            anchors: [template.ifPrefix, template.otherwiseTerminator, template.endIfTerminator]
        )
    }

    /// `"[for each row in rows]{{ row.name }}[end for]"` — loop text.
    private var textTemplateLoop: GrammarProduction {
        let template = lexicon.grammar.templateDirectives
        return GrammarProduction(
            name: "template-loop",
            category: .template,
            implementation: .handWritten,
            canonicalExample: "`[for each row in rows]{{ row.name }}[end for]`",
            summary: "Iteration inside a text template.",
            anchors: [template.forEachPrefix, template.loopInMarker, template.endForTerminator]
        )
    }

    /// `"{{ deadline as a short date }}"` — formatter hint.
    private var textTemplateFormatter: GrammarProduction {
        let template = lexicon.grammar.templateDirectives
        return GrammarProduction(
            name: "template-formatter",
            category: .template,
            implementation: .handWritten,
            canonicalExample: "`{{ deadline as a short date }}`",
            summary: "Closed formatter registry for template expression holes.",
            anchors: [template.formatAsMarker]
        )
    }

    // The four statement idioms below are metadata-only: fixed-keyword shapes
    // registered for documentation/screening ahead of a future statement-level
    // implementation. `implementation: .pegex` records their intended form
    // (all four are closed-keyword shapes with no dynamic symbol-table scan),
    // not a claim that a parser exists yet.

    /// `"after build is green, publish"` — temporal-precondition idiom.
    private var afterIdiom: GrammarProduction {
        GrammarProduction(
            name: "after-idiom",
            category: .statementIdiom,
            implementation: .pegex,
            canonicalExample: "`after build is green, publish the page`",
            summary: "Statement idiom rewritten to a guarded action.",
            anchors: [lexicon.grammar.afterIdiomIntroducer]
        )
    }

    /// `"publish except when build is red"` — suffix negated guard idiom.
    private var exceptWhenIdiom: GrammarProduction {
        GrammarProduction(
            name: "except-when-idiom",
            category: .statementIdiom,
            implementation: .pegex,
            canonicalExample: "`publish the page except when build is red`",
            summary: "`except when` rewritten to `unless`.",
            anchors: [lexicon.grammar.exceptWhenMarker]
        )
    }

    /// `"try publish; if it fails repair"` — recover idiom.
    private var tryRecoverIdiom: GrammarProduction {
        GrammarProduction(
            name: "try-recover-idiom",
            category: .statementIdiom,
            implementation: .pegex,
            canonicalExample: "`try publish the page; if it fails repair it`",
            summary: "Recover-block idiom over a single protected action.",
            anchors: [
                lexicon.grammar.tryIdiomIntroducer,
                lexicon.grammar.tryIdiomFailureSeparator,
            ]
        )
    }

    /// `"publish only when build is green"` — suffix conditional idiom.
    private var suffixConditionalIdiom: GrammarProduction {
        GrammarProduction(
            name: "suffix-conditional",
            category: .statementIdiom,
            implementation: .pegex,
            canonicalExample: "`publish only when build is green`",
            summary: "Single-statement suffix guard.",
            anchors: lexicon.grammar.suffixConditionalMarkers
        )
    }

    /// `proceed, and note "thin history" in the receipt trailer` — the compound
    /// note idiom (INFORM7 §2.9). Unlike the four idioms above, this one is
    /// fully wired: hand-written statement parsing produces a `NoteStatementAST`
    /// that lowers to a `rebind` appending the note text to an already-declared
    /// text binding (MER-REF-004 / MER-TYP-001 guard the target), and the
    /// Verbalizer reprints this canonical surface.
    private var compoundNote: GrammarProduction {
        GrammarProduction(
            name: "compound-note",
            category: .statementIdiom,
            implementation: .handWritten,
            canonicalExample: "`proceed, and note \"thin history\" in the receipt trailer`",
            summary: "Append a note to a declared text binding; desugars to rebind.",
            anchors: [lexicon.grammar.compoundNoteIntroducer]
        )
    }
}
