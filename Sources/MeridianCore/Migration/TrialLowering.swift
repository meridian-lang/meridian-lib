import Foundation

// MARK: - TrialLowering
//
// Shared real-parser probe: attempts to tokenize + parse + lower text against
// a real `SymbolTable`/`EnglishLexicon`/`Rulebook`, reusing the exact
// `StatementParser`/`ASTToIR` path a real compile takes. Single source of
// truth for "would this text actually lower today?" — replaces the marking
// pass's former shape heuristics (AGENTS.md Phase 1: "Trial lowering as the
// oracle"). Used by:
//   - `SkillMigrator`'s marking pass (a real, load-bearing decision), and
//   - `InertYieldAnalyzer` (a read-only measurement, Phase 0).
struct TrialLowering {
    let knowledge: Compiler.KnowledgeContext

    /// Per-line classification (AGENTS.md Phase 1 item 2): the marking pass's
    /// deterministic split precedence, in order of precedence.
    enum LineClass: Equatable {
        /// A shell fence / whole-line backticked command — always executable,
        /// never trial-lowered (fences are handled at the statement-parser
        /// level; a whole-line command is unconditionally a valid invoke).
        case executable
        /// Trial-lowers as a statement (bind/invoke/if/assert/…) via the real
        /// parser+lowerer.
        case checkable
        /// Narrative ending in `:` immediately preceding a command/fence — the
        /// command's source annotation, not independently executable.
        case annotationLabel
        /// Contract-shaped prose (AGENTS.md §15 cue words: must/never/always,
        /// or a quantified "every X must …") that did not itself lower.
        case normativeNarrative
        /// Everything else — genuinely inert documentation.
        case documentation
    }

    enum Outcome: Equatable {
        case success
        case failure([Diagnostic])
    }

    /// True when raw text trial-lowers as a standalone statement (bind,
    /// invoke, if, assert, …) via the real parser + lowerer.
    func lowersAsStatement(_ text: String) -> Bool {
        guard !text.isEmpty else { return false }
        let tokenized = IndentTokenizer().tokenize(text, file: "<probe>", trace: .silent())
        return probe(tokenized) == .success
    }

    /// True when raw text trial-lowers as a checkable condition (an
    /// assert-shaped predicate), independent of whether it also lowers as a
    /// full statement.
    ///
    /// `ConditionClassifier.classify` only checks grammatical shape (does
    /// this read as `<subject> is/is not <adjective>`, a comparison, …?) —
    /// it does not validate that a referenced adjective/tool/kind is actually
    /// declared in the active vocabulary, because that resolution normally
    /// happens later, when the real compiler lowers the condition. A
    /// checkable-shaped line is exactly what the migrator's per-line
    /// classification (`splitPlan`, `sectionIsCheckableRoleBody`) promotes
    /// straight to an executable segment — so an undeclared adjective (e.g.
    /// prose like "Any fork where the wrong default wastes work" trial-
    /// lowering the bare word "fork" as a subject-adjective comparison) was
    /// silently accepted at migration time and only failed at the real
    /// strict compile. Confirm resolvability the same way a real checkable
    /// role-body line eventually lowers (`StatementParser.checklistInvariant`
    /// → `.assertStmt` via `exprParser.parse`) by probing the equivalent
    /// `make sure <condition>.` statement through the full parse+lower
    /// pipeline.
    func isCheckableCondition(_ text: String) -> Bool {
        guard !text.isEmpty else { return false }
        guard case .checkable = ConditionClassifier(symbols: knowledge.symbols, lexicon: knowledge.lexicon, trace: .silent()).classify(text) else {
            return false
        }
        return lowersAsStatement("make sure \(text).")
    }

    /// Whole-word (case-insensitive) match against `EnglishLexicon.normativeCueWords`.
    func isNormativeNarrative(_ text: String) -> Bool {
        let words = text.lowercased().split(whereSeparator: { !$0.isLetter && !$0.isNumber })
        return words.contains { knowledge.lexicon.normativeCueWords.contains(String($0)) }
    }

    /// Whole-word (case-insensitive) match against `EnglishLexicon.inferenceCueWords`
    /// — the ONLY signal that permits routing non-lowerable content to an AI
    /// marker (judgment/autonomy/`ai-discretion`/`ai-autonomy`). See P1 in the
    /// "Eliminate `(( inert ))`" plan / `docs/13_SKILL_MD_PORTING.md`.
    func hasInferenceCue(_ text: String) -> Bool {
        let words = text.lowercased().split(whereSeparator: { !$0.isLetter && !$0.isNumber })
        return words.contains { knowledge.lexicon.inferenceCueWords.contains(String($0)) }
    }

    /// Classify one already-presentation-normalized line, given whether it is
    /// a whole-line command/fence (callers already know this from the
    /// surrounding markdown scan) and whether the immediately-following line
    /// in the section is itself `.executable`/`.checkable` (for the
    /// annotation-label look-ahead).
    func classifyLine(_ text: String, isCommandOrFence: Bool, precedesExecutable: Bool) -> LineClass {
        if isCommandOrFence { return .executable }
        if isCheckableCondition(text) { return .checkable }
        if lowersAsStatement(text) { return .executable }
        if text.hasSuffix(":") && precedesExecutable { return .annotationLabel }
        if isNormativeNarrative(text) { return .normativeNarrative }
        return .documentation
    }

    // MARK: - Probe primitive

    func probe(_ lines: [SourceLine]) -> Outcome {
        guard lines.contains(where: \.isContent) else { return .failure([]) }
        let sp = StatementParser(symbols: knowledge.symbols, trace: .silent(), lexicon: knowledge.lexicon,
                                 rewriteEngine: knowledge.rewriteEngine, diagnostics: nil)
        do {
            let block = try sp.parseBlock(lines, file: "<probe>")
            guard !block.statements.isEmpty else { return .failure([]) }
            let lowerer = ASTToIR(symbols: knowledge.symbols, sourceFile: "<probe>", trace: .silent(),
                                  lexicon: knowledge.lexicon, fallbackPolicy: .strict, rulebook: knowledge.rulebook)
            // `lowerBlock` alone never runs the top-level `lower(_ file:)` setup
            // that materializes merconfig-declared adjectives
            // (`symbols.pendingDefinitions`) into `symbols.definitions` — so a
            // condition using a real vocabulary adjective (e.g. "any short
            // products" against `Definition: a product is short if …`) would
            // spuriously fail to lower here with "unknown adjective", even
            // though a real compile (which always goes through `lower(_
            // file:)` first) resolves it fine. Idempotent across repeated probe
            // calls: `registerDefinitions` treats a same-function-name
            // re-register as benign.
            try lowerer.registerDefinitions([])
            _ = try lowerer.lowerBlock(block, mode: .strict, depth: 0)
            return .success
        } catch let error as CompilerError {
            return .failure(error.diagnostics)
        } catch {
            return .failure([])
        }
    }
}
