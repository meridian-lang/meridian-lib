import Foundation

// MARK: - InertYieldAnalyzer
//
// Phase 0 measurement spike (see the "Deterministic lowering for gbrain" plan
// and `IMPLEMENTATION_LOG.md`): for every section a `.meri`'s marking pass
// left `(( inert ))`, answer "would this section's content actually lower
// today, if the marking pass had real vocabulary/rulebook knowledge instead
// of shape heuristics?" This is the trial-lowering oracle Phase 1's upgraded
// marking pass needs — built here first, read-only, so the corpus-wide yield
// is measured rather than estimated before any migrator behavior changes.
//
// Two-tier probe, reusing the REAL parser/lowerer end to end (no duplicated
// word lists, no re-derived heuristics):
//   1. Whole-section — tokenize + parse + lower the entire body at once
//      against a real `SymbolTable`/`EnglishLexicon`/`Rulebook`. Success ->
//      `.lowersAsIs`: today's shape heuristics kept this section inert for no
//      structural reason; threading real symbols into the marking pass alone
//      fixes it.
//   2. Per-line — when the whole section fails, probe each non-blank content
//      line independently (same knowledge). A line that fails with an
//      `.unresolvedPhrase` diagnostic is `.needsPhrase` (records the exact
//      unresolved phrase text so Phase 3 can rank a phrase-authoring
//      worklist by frequency); a line that fails but grammatically reads as a
//      checkable-shaped condition is `.fuzzy` (an AI-routing candidate);
//      anything that never looked like a statement is `.doc`.
//
// Line-level isolation is a deliberate approximation: a genuine multi-line
// statement (e.g. a continuation line indented under a header) probed alone
// may fail where it would succeed in its original grouping. That is exactly
// the "lowers-after-split" signal this spike exists to surface — Phase 1's
// auto-split groups contiguous executable runs using the real block parser,
// not this isolated per-line probe.
public struct InertYieldAnalyzer {

    public enum Yield: String, Sendable, Equatable, CaseIterable {
        case lowersAsIs = "lowers-as-is"
        case lowersAfterSplit = "lowers-after-split"
        case needsPhrase = "needs-phrase"
        case fuzzy
        case doc
    }

    public struct LineYield: Sendable, Equatable {
        public let line: Int
        public let text: String
        public let yield: Yield
        /// The exact unresolved-phrase text, present only for `.needsPhrase`.
        public let unresolvedPhrase: String?

        public init(line: Int, text: String, yield: Yield, unresolvedPhrase: String? = nil) {
            self.line = line
            self.text = text
            self.yield = yield
            self.unresolvedPhrase = unresolvedPhrase
        }
    }

    public struct SectionYield: Sendable, Equatable {
        public let heading: String
        public let line: Int
        public let overall: Yield
        /// The `SkillMetrics` inert category (operational-procedure,
        /// template, tools-metadata, convention-reference,
        /// reference-documentation, …). Sections whose category is not
        /// `.isOperational` (templates, tool lists, convention restatements,
        /// reference docs) are legitimately inert; a `.needsPhrase`/`.fuzzy`
        /// yield on one of those is noise, not a real phrase-authoring
        /// worklist entry — callers should filter on this before ranking.
        public let category: SkillMetrics.InertCategory
        /// Per-line diagnosis. Empty when `overall == .lowersAsIs` (the whole
        /// section probed clean, so no line-level breakdown was needed).
        public let lines: [LineYield]

        public init(heading: String, line: Int, overall: Yield,
                    category: SkillMetrics.InertCategory, lines: [LineYield] = []) {
            self.heading = heading
            self.line = line
            self.overall = overall
            self.category = category
            self.lines = lines
        }
    }

    public struct FileYield: Sendable, Equatable {
        public let file: String
        public let sections: [SectionYield]

        public init(file: String, sections: [SectionYield]) {
            self.file = file
            self.sections = sections
        }
    }

    let compiler: Compiler
    let vocabularies: [Compiler.VocabularyInput]
    let rulebookInputs: [RulebookInput]

    public init(compiler: Compiler = Compiler(),
                vocabularies: [Compiler.VocabularyInput],
                rulebooks: [RulebookInput] = []) {
        self.compiler = compiler
        self.vocabularies = vocabularies
        self.rulebookInputs = rulebooks
    }

    /// Analyze every currently-inert section of `meriSource` — using the same
    /// role-resolution rules as the real `SkillSectionBuilder` (via
    /// `SkillMetrics.analyze`) — and classify its trial-lowering yield.
    public func analyze(_ meriSource: String, file: String) throws -> FileYield {
        let knowledge = try compiler.knowledge(
            forSource: meriSource, sourceFile: file,
            vocabularies: vocabularies, rulebooks: rulebookInputs)
        let metrics = SkillMetrics.analyze(meriSource, rulebook: knowledge.rulebook)
        let sections = metrics.inertDetails.map { analyzeSection($0, knowledge: knowledge) }
        return FileYield(file: file, sections: sections)
    }

    // MARK: - Section probe

    private func analyzeSection(_ detail: SkillMetrics.InertSection,
                                knowledge: Compiler.KnowledgeContext) -> SectionYield {
        let bodyText = detail.body.joined(separator: "\n")
        let tokenized = IndentTokenizer().tokenize(bodyText, file: "<probe>", trace: .silent())

        if case .success = probe(tokenized, knowledge: knowledge), !tokenized.filter(\.isContent).isEmpty {
            return SectionYield(heading: detail.heading, line: detail.line, overall: .lowersAsIs,
                                category: detail.category)
        }

        let lineYields = perLineYields(tokenized, startLine: detail.line, knowledge: knowledge)
        let overall = aggregate(lineYields)
        return SectionYield(heading: detail.heading, line: detail.line, overall: overall,
                            category: detail.category, lines: lineYields)
    }

    private func aggregate(_ lineYields: [LineYield]) -> Yield {
        guard !lineYields.isEmpty else { return .doc }
        let executable = lineYields.filter { $0.yield == .lowersAsIs }
        guard !executable.isEmpty else {
            // No line lowers on its own — dominant failure mode decides.
            if lineYields.contains(where: { $0.yield == .needsPhrase }) { return .needsPhrase }
            if lineYields.contains(where: { $0.yield == .fuzzy }) { return .fuzzy }
            return .doc
        }
        // At least one line lowers and at least one does not (else the
        // whole-section probe above would have already returned `.lowersAsIs`)
        // — a mixed section is exactly the auto-split candidate.
        return .lowersAfterSplit
    }

    // MARK: - Per-line diagnosis

    private func perLineYields(_ tokenized: [SourceLine], startLine: Int,
                               knowledge: Compiler.KnowledgeContext) -> [LineYield] {
        var out: [LineYield] = []
        for line in tokenized where line.isContent && line.headingLevel == nil {
            let absoluteLine = startLine + line.number
            let text = displayText(for: line)
            switch probe([line], knowledge: knowledge) {
            case .success:
                out.append(LineYield(line: absoluteLine, text: text, yield: .lowersAsIs))
            case .failure(let diagnostics):
                if let phrase = unresolvedPhraseTarget(in: diagnostics) {
                    out.append(LineYield(line: absoluteLine, text: text, yield: .needsPhrase, unresolvedPhrase: phrase))
                } else if looksLikeCondition(text, knowledge: knowledge) {
                    out.append(LineYield(line: absoluteLine, text: text, yield: .fuzzy))
                } else {
                    out.append(LineYield(line: absoluteLine, text: text, yield: .doc))
                }
            }
        }
        return out
    }

    private func displayText(for line: SourceLine) -> String {
        if let (lang, body) = decodeCodeBlockSentinel(line.text) {
            let firstLine = body.components(separatedBy: "\n").first ?? ""
            return "```\(lang) \(firstLine)…```"
        }
        return line.raw.trimmingCharacters(in: .whitespaces)
    }

    private func unresolvedPhraseTarget(in diagnostics: [Diagnostic]) -> String? {
        guard let d = diagnostics.first(where: { $0.code == .unresolvedPhrase }) else { return nil }
        // Message shape is always `unknown phrase "<text>"` (Diagnostic.unresolved).
        guard let firstQuote = d.message.firstIndex(of: "\""),
              let lastQuote = d.message.lastIndex(of: "\""), firstQuote != lastQuote else { return nil }
        return String(d.message[d.message.index(after: firstQuote)..<lastQuote])
    }

    private func looksLikeCondition(_ text: String, knowledge: Compiler.KnowledgeContext) -> Bool {
        let classifier = ConditionClassifier(symbols: knowledge.symbols, lexicon: knowledge.lexicon, trace: .silent())
        switch classifier.classify(text) {
        case .fuzzy, .dispatchPhrase:
            return true
        case .checkable:
            // Classified checkable but still failed to lower in isolation —
            // most likely a multi-line/grouping artifact, not genuine fuzz.
            return false
        }
    }

    // MARK: - Trial lowering

    private enum ProbeResult {
        case success
        case failure([Diagnostic])
    }

    /// Delegates the actual parse+lower attempt to the shared `TrialLowering`
    /// primitive (also used by `SkillMigrator`'s marking pass) — no duplicated
    /// probe logic, just a local result shape.
    private func probe(_ lines: [SourceLine], knowledge: Compiler.KnowledgeContext) -> ProbeResult {
        switch TrialLowering(knowledge: knowledge).probe(lines) {
        case .success: return .success
        case .failure(let diagnostics): return .failure(diagnostics)
        }
    }
}
