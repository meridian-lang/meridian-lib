import Foundation

/// A cross-reference from a design decision to another catalog entry.
public enum CatalogLink: Sendable, Hashable {
    case diagnostic(DiagnosticCode)
    case decision(DecisionRef)

    public var id: String {
        switch self {
        case .diagnostic(let code): return code.id
        case .decision(let ref): return ref.id
        }
    }
}

extension CatalogLink {
    public static func diag(_ code: DiagnosticCode) -> Self { .diagnostic(code) }
    public static func decision(_ id: String) -> Self { .decision(DecisionRef(id)) }
}

/// A structured design decision behind the diagnostics/developer-experience
/// surface. Decisions are reachable *at the point of error*: a `DiagnosticCode`
/// may carry a `DecisionRef`, and both `meridian explain-diag` and the rendered
/// diagnostic surface the linked rationale. `docs/15_DECISIONS.md` is generated
/// from this catalog (`meridian decisions --render`) so the human-readable log
/// can never drift from the source of truth.
public struct DecisionRecord: Sendable, Hashable {
    public enum Status: String, Sendable, Hashable {
        case accepted
        case superseded
        case proposed
    }

    public let id: String
    public let title: String
    public let status: Status
    public let rationale: String
    public let alternatives: [String]
    public let consequences: [String]
    public let seeAlso: [CatalogLink]

    public init(id: String, title: String, status: Status = .accepted,
                rationale: String, alternatives: [String] = [],
                consequences: [String] = [], seeAlso: [CatalogLink] = []) {
        self.id = id
        self.title = title
        self.status = status
        self.rationale = rationale
        self.alternatives = alternatives
        self.consequences = consequences
        self.seeAlso = seeAlso
    }
}

/// The dependency-free source of truth for design decisions surfaced in
/// diagnostics. See `DecisionRecord`.
public enum DecisionCatalog {

    public static let all: [DecisionRecord] = [

        DecisionRecord(
            id: "D-DX-1",
            title: "Unresolved phrases are hard errors by default",
            rationale: "An invocation that matches no phrase or workflow is almost always a typo or a missing declaration. Emitting a silent `_unresolved` placeholder hid real bugs until runtime. Strict-by-default surfaces them at compile time; the `allow-fallbacks: unresolved-phrases` escape hatch keeps early-authoring ergonomic.",
            alternatives: [
                "Always emit an `_unresolved` placeholder (the old behaviour) — hides typos until runtime.",
                "Warn instead of error — warnings are routinely ignored in CI.",
            ],
            consequences: [
                "Every phrase must resolve, or the file must opt into the fallback.",
                "The error funnels through `Diagnostic.unresolved`, so it always carries a did-you-mean or candidate list.",
            ],
            seeAlso: [.diag(.unresolvedPhrase), .decision("D-DX-2")]),

        DecisionRecord(
            id: "D-DX-2",
            title: "No silent compile-time fallbacks; batch-report with coarse recovery",
            rationale: "Silent drops (malformed headers, unparseable rules/statements, unknown config keys/sections) erased authoring mistakes. Every former silent site is now a coded diagnostic. The DiagnosticEngine collects rather than aborts, recovering at construct boundaries (workflow / rule / statement) so one compile reports many errors instead of one-at-a-time.",
            alternatives: [
                "Abort on the first error — slow edit/compile loops; hides co-occurring errors.",
                "Token-level resync recovery — produces cascade/phantom errors.",
            ],
            consequences: [
                "Constructs are skipped wholesale on error (cascade-resistant); phrase stubs are pre-registered so dependents still resolve.",
                "Structural codes carry a mandatory `help` string with the concrete fix.",
            ],
            seeAlso: [
                .diag(.malformedWorkflowHeader), .diag(.orphanedCodeBlock),
                .diag(.unparseableStatement), .diag(.unparseableRule),
                .diag(.missingPhraseArgument), .diag(.unattachedRule),
                .diag(.unresolvedTriggerAction), .diag(.unlowerableRulePredicate),
                .diag(.unsupportedTriggerCondition), .diag(.matchBranchSyntax),
                .diag(.matchBranchSemantic), .diag(.invalidIR),
                .diag(.diagnosticRecoverySummary),
            ]),

        DecisionRecord(
            id: "D-DX-3",
            title: "swift-format failure is a recoverable warning, not an error",
            rationale: "Formatting is cosmetic. If swift-format chokes on otherwise-valid generated Swift, keeping the unformatted output is strictly better than failing the compile. The condition is surfaced as a warning so it is visible but non-fatal.",
            alternatives: [
                "Fail the compile when formatting fails — loses valid output over a cosmetic step.",
                "Swallow the failure silently — hides a real formatter/codegen interaction bug.",
            ],
            consequences: [
                "`compile` always writes Swift; a formatting failure is reported as a warning.",
            ],
            seeAlso: [.diag(.swiftFormatFailed)]),

        DecisionRecord(
            id: "D-DX-4",
            title: "Always-on did-you-mean for every name-resolution error",
            rationale: "A name-resolution failure is, by definition, a mismatch against a finite candidate set, so a remediation can always be named. Every such failure funnels through `Diagnostic.unresolved(code:target:among:range:)`, which attaches a `did you mean \"X\"?` suggestion when within edit-distance budget, or an enumerated candidate-list note otherwise — never a bare \"unknown X\".",
            alternatives: [
                "Per-site ad-hoc messages — drift and inconsistency; easy to forget the hint.",
                "Only suggest when very close — leaves the user stuck when nothing is close.",
            ],
            consequences: [
                "A guard test enumerates all `.nameResolution` codes and asserts each yields a suggestion or candidate-list note.",
                "Suggestions carry `replacement` + `range`, powering `--fix` and editor quick-fixes.",
            ],
            seeAlso: [
                .diag(.unknownKind), .diag(.unknownProperty),
                .diag(.unknownAdjective), .diag(.unknownVerb),
            ]),

        DecisionRecord(
            id: "D-DX-5",
            title: "Unknown tools are errors; Core mirrors the runtime built-in catalog",
            rationale: "A misspelled or undeclared tool id silently compiled to an invoke that failed only at runtime. Core cannot import MeridianTools, so `BuiltinToolCatalog` hand-mirrors the runtime's built-in ids (kept in lockstep by a guard test). Every `InvokeIR.toolID` is validated against built-ins ∪ vocabulary `=== tools ===` ∪ frontmatter `tools:` ∪ workflow references, with did-you-mean.",
            alternatives: [
                "Trust every emitted tool id — runtime-only failures, far from the source.",
                "Validate only vocabulary tools — false positives on built-ins and frontmatter tools.",
            ],
            consequences: [
                "Recognition mirrors the invoke path (case-insensitive against methodName; methodized built-ins).",
                "`allow-fallbacks: unknown-tools` downgrades per-file for host-provided tools.",
            ],
            seeAlso: [.diag(.unknownTool)]),

        DecisionRecord(
            id: "D-DX-6",
            title: "Phase-8 rule sugar fires everywhere executable; sectioned-document prose is opt-in via markers/comments only",
            rationale: "A single `!hasHeadings` gate used to suppress Phase-8 rule extraction (`must not` / `may` [+ bounded `up to N`] / `must be … by … before` / `When …, …`) in any file with `##`/`###` headings, silently downgrading rule-shaped sentences in SKILL.md-style documents to inert prose with no diagnostic. This reversed a real authoring intent: a governance/clinical skill body that reads `A user without clearance must not access classified resources.` is a rule the author expects enforced, not documentation. Rule extraction now runs identically in flat and sectioned documents; each non-comment line in an executable section is classified in a fixed precedence — guidance-step prose, then `RuleAnalyzer.classify`-positive rule shapes (extracted to `MeridianFile.rules`), then ordinary statements — so prose is never inferred from content, only from an explicit `(( role: reference ))`/`(( inert ))` marker or a `#`/`>` comment line.",
            alternatives: [
                "Keep sectioned documents rule-inert and require authors to move obligations into a flat `rules/*.meridian` file — forces an artificial split between a skill's narrative and its enforced contracts, and is exactly the workaround `corpora/governance`/`corpora/clinical` no longer need.",
                "Infer prose vs. rule from section role alone (e.g. treat every `invariants` section line as a rule) — too coarse; a section can mix a rule-shaped sentence with an ordinary guard statement, and role-based inference would silently misclassify one or the other.",
            ],
            consequences: [
                "A rule-shaped sentence with no matching implicit-workflow parameter/action now raises `unattachedRule` at compile time instead of compiling silently as inert narrative — treated as an authoring signal (fix the skill's frontmatter `parameters:` or the rule wording), not a regression.",
                "`SkillMigrator`'s four-way classifier treats rule-shaped normative lines as lowerable (category 1) rather than routing them to `(( role: reference ))` or a hard error, so migrated `SKILL.md` sources gain real enforcement instead of documentation-only narrative.",
                "gbrain/erp/procedures ported `.meri` sources with `When …,`/`may`/`must not` narrative that was never meant to be a rule must be explicitly re-marked `(( role: reference ))`/`(( inert ))` or commented (`#`/`>`) — a one-time, mechanical repair pass across the existing corpora, not an ongoing cost.",
            ],
            seeAlso: [
                .diag(.unattachedRule), .diag(.uncheckablePredicate),
                .diag(.sectionStructuralError), .diag(.unlowerableRulePredicate),
            ]),

        DecisionRecord(
            id: "D-DX-7",
            title: "Lint and migration-report findings are DiagnosticCode-native, not ad hoc strings",
            rationale: "`MeridianLinter` and `SkillMigrator.Report` used to return free-form warning strings, so authors saw a different vocabulary and no `explain-diag` path depending on which tool caught the issue. `MeridianLinter` now returns `[Diagnostic]` (polite-command and uncertainty-wording lints), and `SkillMigrator`'s `--route-fuzzy` downgrade is a `Diagnostic` too, so every finding from every DX tool shares one rendering, one JSON schema, and one `meridian explain-diag <code>` lookup path.",
            alternatives: [
                "Keep lint/migration findings as tool-specific string types — cheap short-term, but forks the diagnostics UX and blocks a shared `--json`/IDE-integration surface.",
                "Fold lint findings into the compiler's own diagnostic stream unconditionally — conflates optional style advice with hard compile errors.",
            ],
            consequences: [
                "Lint findings are warnings, not hard errors, but travel through the exact same `Diagnostic` type as MER1xxx–MER4xxx.",
                "A batch `migrate-skill --route-fuzzy` run is auditable via the same diagnostic list as a normal compile, instead of a separate log format.",
            ],
            seeAlso: [
                .diag(.lintPoliteCommand), .diag(.lintUncertainty),
                .diag(.migrationRouteFuzzyDowngrade),
            ]),

        DecisionRecord(
            id: "D-DX-8",
            title: "Trace-file and lexicon-marker failures degrade visibly, never silently",
            rationale: "Two failure modes used to fail quietly: a bad `--trace-file` path would drop trace output with no indication, and an empty required lexicon marker collection would produce blank/malformed canonical output with no diagnostic. Both are now coded: an unwritable trace file falls back to stderr with a visible MER5011 notice instead of losing the trace, and an empty marker collection raises MER5012 instead of emitting degenerate output.",
            alternatives: [
                "Drop trace output silently on an unwritable path — defeats the purpose of asking for a trace file in the first place.",
                "Crash outright on an empty lexicon marker collection — loses the batch-report/coarse-recovery behavior the rest of the pipeline relies on (D-DX-2).",
            ],
            consequences: [
                "`--trace-file` failures are recoverable: the run still completes, with the trace redirected to stderr and a MER5011 notice explaining why.",
                "A domain that overrides `EnglishLexicon` markers without providing at least one entry per required category gets a compile-time MER5012 instead of a silently broken canonical form.",
            ],
            seeAlso: [.diag(.unwritableTraceFile), .diag(.emptyLexiconMarkers)]),
    ]

    public static func lookup(_ id: String) -> DecisionRecord? {
        let needle = id.uppercased()
        return all.first { $0.id.uppercased() == needle }
    }

    /// Render the catalog as the canonical `docs/15_DECISIONS.md`. The
    /// `decisions --render` CLI mode writes this; a staleness test re-renders
    /// and diffs against the committed file so the doc never drifts.
    public static func renderMarkdown() -> String {
        var out = """
        # Meridian design decisions (diagnostics & developer experience)

        > Generated from `DecisionCatalog` by `meridian decisions --render docs/15_DECISIONS.md`.
        > Do not edit by hand — update `Sources/MeridianCore/Diagnostics/DecisionCatalog.swift`
        > and re-render. A test fails if this file drifts from the catalog.

        Each decision is reachable from the errors it governs: run
        `meridian explain-diag <code>` (e.g. `meridian explain-diag MER2002`) or
        `meridian explain-diag <decision-id>` (e.g. `meridian explain-diag D-DX-5`).

        """
        for d in all {
            out += "\n## \(d.id) — \(d.title)\n\n"
            out += "**Status:** \(d.status.rawValue)\n\n"
            out += "\(d.rationale)\n"
            if !d.alternatives.isEmpty {
                out += "\n**Alternatives considered:**\n\n"
                for a in d.alternatives { out += "- \(a)\n" }
            }
            if !d.consequences.isEmpty {
                out += "\n**Consequences:**\n\n"
                for c in d.consequences { out += "- \(c)\n" }
            }
            if !d.seeAlso.isEmpty {
                let links = d.seeAlso.map(\.id).joined(separator: ", ")
                out += "\n**See also:** \(links)\n"
            }
        }
        return out
    }
}
