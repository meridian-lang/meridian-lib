import Foundation

// MARK: - SkillMigrator
//
// Authoring-time tool that converts a gbrain `SKILL.md` into a strict-compiling
// `.meri`. It is the inverse-friendly companion to the rulebook engine:
//
//   1. Deterministic transform — the marking pass. It injects no frontmatter
//      (section semantics activate structurally on any `##`/`###` heading, and
//      the CLI autodiscovers `.merconfig`/`.merrules`), but it blockquotes
//      pre-heading preamble and appends an authoritative `(( … ))` marker to
//      every heading that would not otherwise resolve to an executable role
//      (prose Contract/Anti-Patterns → inert-with-role, executable unknown →
//      a reusable `procedure` section alias, other unknown → `(( inert ))`).
//      Markdown list items are normalized and tried as executable candidates
//      rather than inerted because they contain bullets, bold text, or links.
//      It does NOT strip `skill: true` (a one-time corpus edit). See
//      `deterministicTransform`.
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
        /// Explicitly route fuzzy actionable content — checklists/tables whose
        /// items aren't structurally checkable, and judgment-shaped prose left
        /// over below the split threshold — to the planner via `!!! checklist
        /// (( ai-autonomy ))` / `!!! table (( ai-discretion ))` / `use judgment
        /// to …:` markers (AGENTS.md Phase 1 item 4), instead of leaving them
        /// `(( inert ))`. On by default; `--no-route-fuzzy` on `migrate-skill`
        /// disables it for a byte-for-byte-with-today comparison.
        public var routeFuzzy: Bool

        public init(maxRepair: Int = 0, routeFuzzy: Bool = true) {
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
        public var diagnostics: [String]
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
        var diagnostics: [String] = []
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
                let diag = describe(error)
                diagnostics.append(diag)
                trace.log(.skill, "migrate \"\(file)\": attempt \(attempts) failed — \(diag)")
                if let revised = markEnclosingSectionInert(forDiagnostic: diag, in: candidate) {
                    trace.log(.skill, "migrate \"\(file)\": marking failed section inert and retrying strict compile")
                    candidate = revised
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
                    candidate: candidate, diagnostic: diag, attempt: attempts))
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
    ///   2. **Mark headings** — append an authoritative `(( … ))` marker to each
    ///      heading that would otherwise not resolve to an executable role:
    ///        • Contract/Guarantees/Invariants → `(( inert, role: invariants ))`
    ///          (the gbrain corpus states these as prose, not checkable predicates)
    ///        • Anti-Patterns/Avoid/Pitfalls   → `(( inert, role: prohibitions ))`
    ///        • a recognized procedure/applicability/negative/template heading
    ///          → left unmarked only when its body is structurally lowerable;
    ///          narrative bodies stay inert with the heading's semantic role
    ///          preserved where useful
    ///        • an unrecognized heading whose body is *only* executable
    ///          candidates (shell fences, command spans, choice gates, checkable
    ///          task-list items, or list items normalized from Markdown)
    ///          → a `procedure` section alias
    ///        • every other unrecognized heading → `(( inert ))`
    ///   3. **Heading-less narrative** — when a document has no `##`/`###`
    ///      headings and the body is prose narrative rather than an executable
    ///      flat procedure/list, wrap the body under `## Overview (( inert ))`.
    ///      Plain phrase-only documents and all-list Markdown procedures are
    ///      left for strict compile after inline presentation is normalized.
    ///
    /// Idempotent (an already-marked heading is left untouched) and
    /// frontmatter-preserving. It does NOT strip `skill: true` — that is a
    /// one-time corpus edit, not a reusable transform. Role recognition uses the
    /// built-in alias table (`SkillSectionRole.builtinRole`); idiosyncratic
    /// organizational headings get `(( inert ))` and are the author's residue to
    /// resolve (split into a procedure section, alias in the rulebook, or keep
    /// inert). `addedKeys` is always empty — the pass adds no frontmatter.
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

    private func result(_ source: String, addedKeys: [String], diagnostics: [String],
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

    private func describe(_ error: any Error) -> String {
        if let compilerError = error as? CompilerError {
            switch compilerError {
            case .semanticError(let message, let range):
                return "L\(range.startLine): \(message)"
            default:
                return String(describing: compilerError)
            }
        }
        return String(describing: error)
    }
}
