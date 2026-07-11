import Foundation
import MeridianRuntime

// MARK: - SkillMigrator
//
// Authoring-time tool that converts a gbrain `SKILL.md` into a strict-compiling
// `.meri`. It is the inverse-friendly companion to the rulebook engine:
//
//   1. Deterministic transform — the marking pass. It injects no frontmatter
//      (section semantics activate structurally on any `##`/`###` heading, and
//      the CLI autodiscovers `.merconfig`/`.merrules`), but it blockquotes
//      pre-heading preamble and classifies every heading per the P1 four-way
//      precedence (lower / AI-inference-cue judgment / documentary `reference`
//      / cue-less operational error — see AGENTS.md §6 item 15 and
//      `docs/13_SKILL_MD_PORTING.md`): prose Contract/Anti-Patterns → role-
//      typed non-executable or split by cue, executable unknown → a reusable
//      `procedure` section alias, other unknown, non-lowerable, documentary →
//      `(( role: reference ))`. The migrator never emits `(( inert ))`.
//      Markdown list items are normalized and tried as executable candidates
//      rather than marked non-executable because they contain bullets, bold
//      text, or links. It does NOT strip `skill: true` (a one-time corpus
//      edit). See `deterministicTransform`.
//   2. Strict compile — run the candidate through `Compiler` exactly like a
//      hand-authored file.
//   3. Bounded repair — when compilation fails AND a repair closure is
//      supplied, hand the diagnostic + candidate to the closure (which may be
//      LLM-backed) for at most `maxRepair` rounds. The closure may ONLY
//      rephrase a flagged line into a resolvable phrase or wrap a genuine
//      judgment step in an explicit `use judgment to …:` marker — it can never
//      introduce a silent LLM path, because the result is re-compiled strict.
//
// LLM proposes, compiler disposes: a migration is "successful" only when the
// emitted `.meri` passes the same strict compile as a hand-authored file. The
// repair closure is a Core-LOCAL `(RepairRequest) async throws -> String`, so
// `MeridianCore` keeps no dependency on `MeridianRuntime`'s `LLMProvider`; the
// CLI adapts a concrete provider to this closure, and tests pass an inline one.

public struct SkillMigrator {

    public struct Options: Sendable {
        /// Maximum repair rounds (0 = deterministic-only).
        public var maxRepair: Int
        /// Downgrades a P1 category-4 failure (non-lowerable, no inference
        /// cue, operational/normative content) from a hard migration error to
        /// a reported-but-nonfatal skip: the offending section is marked
        /// `(( role: reference ))` (never `(( inert ))`) and the strict
        /// compile retries. Off by default, matching the P1 policy that
        /// cue-less operational content is a hard reword error; `--route-fuzzy`
        /// on `migrate-skill` opts into the escape hatch for exploratory batch
        /// runs where some residual is expected.
        public var routeFuzzy: Bool

        public init(maxRepair: Int = 0, routeFuzzy: Bool = false) {
            self.maxRepair = maxRepair
            self.routeFuzzy = routeFuzzy
        }
    }

    /// A request handed to the repair closure when a candidate fails strict
    /// compilation. The closure returns a revised `.meri` source.
    public struct RepairRequest: Sendable {
        public let candidate: String
        public let diagnostic: String
        public let attempt: Int
    }

    /// A markdown heading the migrator routed to a closed section role via a
    /// rulebook `=== sections ===` alias (instead of an inline `(( … ))` marker).
    /// The CLI persists these to the rulebook so future compiles/re-migrations
    /// recognize the heading with no in-file marker.
    public struct SectionAlias: Sendable, Equatable {
        public let heading: String
        public let role: SkillSectionRole
        public init(heading: String, role: SkillSectionRole) {
            self.heading = heading
            self.role = role
        }
    }

    public struct Report: Sendable {
        public var compiledOK: Bool
        public var repairAttempts: Int
        public var diagnostics: [Diagnostic]
        public var addedFrontmatterKeys: [String]
        public var originalLineCount: Int
        public var resultLineCount: Int
        /// Lines changed vs the original (added frontmatter keys + repair rounds).
        public var editCount: Int
        /// Normative-narrative lines (AGENTS.md §15 cue shapes) found inside a
        /// split section that did not themselves trial-lower and were not split
        /// out. Never silently dropped — a nonzero count is a real signal that a
        /// contract needs a phrase, an assertion rewrite, or explicit AI routing.
        public var unminedContracts: [String]
    }

    public struct Result: Sendable {
        public var meriSource: String
        public var report: Report
        public var compiledOK: Bool
        /// Section-role aliases the migrator emitted for the rulebook (each an
        /// unrecognized executable heading routed to a closed role). Empty when
        /// every heading resolved via a built-in role or an inline marker.
        public var sectionAliases: [SectionAlias]
    }

    let compiler: Compiler
    let vocabularies: [Compiler.VocabularyInput]
    let rulebookInputs: [RulebookInput]
    let options: Options
    let repair: (@Sendable (RepairRequest) async throws -> String)?
    /// Opt-in debug trace for the migration pass, under `.skill`. Defaults to
    /// the compiler's own trace so `--trace skill` on the CLI covers migration
    /// without a second flag; pass an explicit trace to decouple them.
    let trace: ParserTrace

    public init(compiler: Compiler,
                vocabularies: [Compiler.VocabularyInput],
                rulebooks: [RulebookInput] = [],
                options: Options = Options(),
                repair: (@Sendable (RepairRequest) async throws -> String)? = nil,
                trace: ParserTrace? = nil) {
        self.compiler = compiler
        self.vocabularies = vocabularies
        self.rulebookInputs = rulebooks
        self.options = options
        self.repair = repair
        self.trace = trace ?? compiler.options.trace
    }

    public func migrate(_ markdown: String, file: String = "skill.meri") async throws -> Result {
        trace.log(.skill, "migrate \"\(file)\": \(markdown.components(separatedBy: "\n").count) source line(s)")
        let (transformed, addedKeys, aliases, unminedContracts) = try deterministicTransform(markdown)
        let originalLineCount = markdown.components(separatedBy: "\n").count

        trace.log(.skill, "migrate \"\(file)\": marking pass added \(addedKeys.count) frontmatter key(s), \(aliases.count) section alias(es), \(unminedContracts.count) unmined-contract line(s)")

        // The aliases the marking pass chose (e.g. a pure-shell heading routed to
        // `procedure`) are left UNMARKED in the .meri, so they must be supplied to
        // the strict compile as a synthetic rulebook — otherwise an unrecognized
        // heading with content is a hard error. The CLI persists the same aliases
        // to the on-disk rulebook so the written .meri compiles standalone.
        let effectiveRulebooks = rulebookInputs + Self.aliasRulebook(aliases)

        var candidate = transformed
        var diagnostics: [Diagnostic] = []
        var attempts = 0

        while true {
            trace.log(.skill, "migrate \"\(file)\": strict compile attempt \(attempts)")
            do {
                _ = try compiler.compile(
                    meridianSource: candidate, meridianFile: file,
                    vocabularies: vocabularies, rulebooks: effectiveRulebooks
                )
                trace.log(.skill, "migrate \"\(file)\": compiled OK after \(attempts) repair attempt(s)")
                return result(candidate, addedKeys: addedKeys, diagnostics: diagnostics,
                              attempts: attempts, originalLineCount: originalLineCount,
                              compiledOK: true, aliases: aliases, unminedContracts: unminedContracts)
            } catch {
                let diag = describe(error, file: file)
                diagnostics.append(diag)
                trace.log(.skill, "migrate \"\(file)\": attempt \(attempts) failed — \(diagnosticSummary(diag))")
                if Self.isFuzzyRoutableCode(diagnosticCode(error)),
                   let routed = markEnclosingSectionReference(forDiagnostic: diag, in: candidate) {
                    diagnostics.append(routed.warning)
                    trace.log(.skill, "migrate \"\(file)\": \(diagnosticSummary(routed.warning))")
                    candidate = routed.source
                    continue
                }
                guard let repair, attempts < options.maxRepair else {
                    trace.log(.skill, "migrate \"\(file)\": giving up after \(attempts) attempt(s) (no repair closure or maxRepair reached)")
                    return result(candidate, addedKeys: addedKeys, diagnostics: diagnostics,
                                  attempts: attempts, originalLineCount: originalLineCount,
                                  compiledOK: false, aliases: aliases, unminedContracts: unminedContracts)
                }
                attempts += 1
                candidate = try await repair(RepairRequest(
                    candidate: candidate, diagnostic: diagnosticSummary(diag), attempt: attempts))
            }
        }
    }

    /// Render section aliases as a synthetic `=== sections ===` rulebook input
    /// (empty array → no input), so the marking pass's unmarked executable
    /// headings resolve during the strict compile.
    static func aliasRulebook(_ aliases: [SectionAlias]) -> [RulebookInput] {
        guard !aliases.isEmpty else { return [] }
        var lines = ["=== sections ==="]
        for a in aliases {
            lines.append("section \"\(a.heading)\" -> \(a.role.rawValue)")
        }
        return [RulebookInput(name: "__migrator-section-aliases__",
                              file: "__migrator-section-aliases__.merrules",
                              source: lines.joined(separator: "\n") + "\n")]
    }

    // MARK: - Deterministic transform

    /// The reusable, deterministic marking pass. It injects **no frontmatter**
    /// (section semantics activate structurally on `##`/`###` headings, and the
    /// CLI autodiscovers `.merconfig`/`.merrules`) — instead it does the two
    /// edits the universal-sections model needs to make a `SKILL.md`-shaped
    /// document compile with minimal change:
    ///
    ///   1. **Blockquote preamble** — any non-comment content before the first
    ///      heading is prefixed with `> ` (a markdown blockquote, treated as a
    ///      comment by the tokenizer), so it doesn't trip the "content before
    ///      the first heading" hard error.
    ///   2. **Classify headings per P1** — apply the fixed four-way precedence
    ///      (lower → AI-inference-cue judgment → documentary `reference` →
    ///      cue-less operational error) to each heading that would otherwise
    ///      not resolve to an executable role:
    ///        • Contract/Guarantees/Invariants → checkable lines lower/split;
    ///          non-checkable lines with an inference cue → judgment; with no
    ///          cue → left to `SkillSectionBuilder`'s own `uncheckablePredicate`
    ///          error (never auto-marked non-executable)
    ///        • Anti-Patterns/Avoid/Pitfalls → same treatment under `role:
    ///          prohibitions`
    ///        • a recognized procedure/applicability/negative/template heading
    ///          → left unmarked when its body is structurally lowerable or
    ///          judgment-wrapped; a purely documentary body is marked
    ///          `(( role: reference ))`
    ///        • an unrecognized heading whose body is *only* executable
    ///          candidates (shell fences, command spans, choice gates, checkable
    ///          task-list items, or list items normalized from Markdown)
    ///          → a `procedure` section alias
    ///        • every other unrecognized, non-lowerable, non-cued heading with
    ///          real operational content → a `procedure` alias, left for the
    ///          real compiler to raise its own reword diagnostic; genuinely
    ///          documentary content → `(( role: reference ))`
    ///   3. **Heading-less narrative** — when a document has no `##`/`###`
    ///      headings and the body is prose narrative rather than an executable
    ///      flat procedure/list, wrap the body under
    ///      `## Overview (( role: reference ))`. Plain phrase-only documents
    ///      and all-list Markdown procedures are left for strict compile after
    ///      inline presentation is normalized.
    ///
    /// Idempotent (an already-marked heading is left untouched) and
    /// frontmatter-preserving. It does NOT strip `skill: true` — that is a
    /// one-time corpus edit, not a reusable transform. Role recognition uses the
    /// built-in alias table (`SkillSectionRole.builtinRole`); idiosyncratic
    /// organizational headings with no lowerable/cued/documentary content are
    /// the author's residue to resolve via reword, not a silently emitted
    /// marker. `addedKeys` is always empty — the pass adds no frontmatter.
    func deterministicTransform(_ markdown: String) throws
        -> (source: String, addedKeys: [String], aliases: [SectionAlias], unminedContracts: [String]) {
        let (marked, aliases, unminedContracts) = try markSections(markdown)
        return (rewriteCommandPlaceholders(marked), [], aliases, unminedContracts)
    }

    /// Real `SymbolTable` + merged `EnglishLexicon` + rulebook `RewriteEngine`,
    /// built once per marking pass from the migrator's own `vocabularies` /
    /// `rulebookInputs` (the exact inputs the strict compile will use). Threaded
    /// through the section classifiers below so a domain phrase like "validate
    /// the order" is recognized as executable instead of falling to shape
    /// heuristics with `symbols: nil` (AGENTS.md Phase 1 item 1). No `.meri`
    /// source exists yet at marking time, so inline domain-vocabulary harvesting
    /// sees an empty document — harmless, since gbrain-style corpora declare
    /// their domain vocabulary in `.merconfig`/`.merrules`, not inline.
    func knowledgeContext() throws -> Compiler.KnowledgeContext {
        try compiler.knowledge(forSource: "", sourceFile: "<skill-migrator>",
                               vocabularies: vocabularies, rulebooks: rulebookInputs)
    }
    // MARK: - Helpers

    private func result(_ source: String, addedKeys: [String], diagnostics: [Diagnostic],
                        attempts: Int, originalLineCount: Int, compiledOK: Bool,
                        aliases: [SectionAlias], unminedContracts: [String]) -> Result {
        let resultLineCount = source.components(separatedBy: "\n").count
        let report = Report(
            compiledOK: compiledOK,
            repairAttempts: attempts,
            diagnostics: diagnostics,
            addedFrontmatterKeys: addedKeys,
            originalLineCount: originalLineCount,
            resultLineCount: resultLineCount,
            editCount: addedKeys.count + attempts,
            unminedContracts: unminedContracts
        )
        return Result(meriSource: source, report: report, compiledOK: compiledOK,
                      sectionAliases: aliases)
    }

    private func describe(_ error: any Error, file: String) -> Diagnostic {
        if let compilerError = error as? CompilerError,
           let first = compilerError.diagnostics.first {
            return first
        }
        return Diagnostic.error(
            .internalError,
            message: "migration failed: \(String(describing: error))",
            range: SourceRange(file: file, line: 1, column: 1),
            help: "Inspect the underlying error and retry the migration after resolving it."
        )
    }

    private func diagnosticSummary(_ diagnostic: Diagnostic) -> String {
        "\(diagnostic.code.id) \(diagnostic.primaryRange): \(diagnostic.message)"
    }

    private func diagnosticCode(_ error: any Error) -> DiagnosticCode? {
        guard let compilerError = error as? CompilerError else { return nil }
        return compilerError.diagnostics.first?.code
    }

    /// The `--route-fuzzy` rescue (`markEnclosingSectionReference`) exists for
    /// the P1 category-4 case: a line's *shape* is genuinely ambiguous between
    /// prose and code (`uncheckablePredicate`/`sectionStructuralError`'s
    /// multi-line-item sibling, `unresolvedPhrase` when nothing recognized the
    /// line at all, `ambiguousAnaphora`, …) — those diagnostics are safe to
    /// downgrade to "keep this as documentation" because the compiler never
    /// recognized the line as a specific executable construct in the first
    /// place.
    ///
    /// It must NEVER fire for a diagnostic raised *after* a line was already
    /// recognized as a specific, well-formed construct (a quantifier, a tool
    /// invocation, a rule) whose only problem is an undeclared name — an
    /// unknown adjective/tool/kind/property/verb, an out-of-scope template
    /// hole, a rule that can't attach, or a duplicate declaration. There the
    /// shape is unambiguous and the fix is a `.merconfig`/rulebook edit, not
    /// documentation; blanket-demoting the enclosing section (often the whole
    /// `Workflow`) to `(( role: reference ))` would silently drop the rest of
    /// its already-recognized executable content with no signal beyond a
    /// report line — exactly the "unknown adjective" bug that dropped
    /// `review_requests`' entire fetch/check/loop/emit body while still
    /// reporting `compiles: true` (see IMPLEMENTATION_LOG.md). Nil (a
    /// non-`CompilerError` failure) is never fuzzy-routable either.
    private static let neverFuzzyRoutableCodes: Set<DiagnosticCode> = [
        .unknownTool, .unknownProperty, .unknownAdjective, .unknownVerb, .unknownKind,
        .unknownVocabulary, .unknownRulebook, .unknownFallbackKind,
        .commandHoleOutOfScope, .missingPhraseArgument, .unknownTemplateFormatter,
        .unattachedRule, .unresolvedTriggerAction, .unlowerableRulePredicate,
        .duplicateDeclaration, .duplicateName,
    ]

    private static func isFuzzyRoutableCode(_ code: DiagnosticCode?) -> Bool {
        guard let code else { return false }
        return !neverFuzzyRoutableCodes.contains(code)
    }
}
