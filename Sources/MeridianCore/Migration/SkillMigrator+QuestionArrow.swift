import Foundation

extension SkillMigrator {
    // MARK: - Question-arrow decision protocol (Phase 2 idiom)

    /// `->`/`→` decision-arrow markers. Arrow syntax is punctuation, not
    /// English vocabulary — it stays a fixed local constant rather than an
    /// `EnglishLexicon` field, matching AGENTS.md §6's "structural sentinel"
    /// exception (the same rationale as the `\u{E000}` markers).
    static let decisionArrowMarkers = ["->", "\u{2192}"]

    struct QuestionArrowItem {
        let question: String
        let rhs: String
    }

    /// Parses a `<question>? -> <rhs>` (or `→`) list item. Returns nil for
    /// any line that isn't shaped this way, which both excludes it from a
    /// question-arrow block during the atomic-block scan and guards the
    /// classifier against misreading incidental `?`/arrow punctuation.
    func parseQuestionArrowLine(_ raw: String) -> QuestionArrowItem? {
        let stripped = stripMarkdownListMarker(raw.trimmingCharacters(in: .whitespaces))
        guard let qMark = stripped.firstIndex(of: "?") else { return nil }
        let question = String(stripped[...qMark]).trimmingCharacters(in: .whitespaces)
        let afterQuestion = stripped[stripped.index(after: qMark)...].trimmingCharacters(in: .whitespaces)
        guard let arrow = Self.decisionArrowMarkers.first(where: { afterQuestion.hasPrefix($0) }) else { return nil }
        let rhs = String(afterQuestion.dropFirst(arrow.count)).trimmingCharacters(in: .whitespaces)
        guard !question.isEmpty, !rhs.isEmpty else { return nil }
        return QuestionArrowItem(question: question, rhs: rhs)
    }

    /// Result-name lead-in for question-arrow case 2 (`deciding the <name>:`
    /// on the line immediately before the list). Falls back to a generic
    /// name when absent — the section's exact subject isn't threaded
    /// into `splitPlan` today, so this is the honest default rather than a
    /// guessed noun phrase.
    func questionArrowResultName(precedingBlock: SplitBlock?, lexicon: EnglishLexicon) -> String {
        let grammar = lexicon.grammar
        let leadIn = grammar.decidingTheIntroducer
        guard let text = precedingBlock?.normalizedText.lowercased(), text.hasSuffix(":"),
              text.hasPrefix(leadIn) else { return grammar.questionArrowFallbackResultName }
        return String(text.dropFirst(leadIn.count).dropLast())
            .trimmingCharacters(in: .whitespaces)
    }

    /// The three-way question-arrow lowering (Phase 2 idiom, design closed):
    /// classifies a contiguous `<question>? -> <rhs>` list as a whole (mixed
    /// checkable/fuzzy questions inside one list would produce an
    /// inconsistent shape, so the decision is uniform over the block).
    ///   1. Every question is checkable AND every rhs trial-lowers as its own
    ///      statement → each item is independently actionable: desugar to the
    ///      existing suffix-conditional idiom, `<rhs> only when <question>.`
    ///   2. Every question is checkable but rhs is a bare classification
    ///      value → reuse decision-table lowering: `let the <name> be
    ///      "<rhs>" only when <question>.` (first match wins, same as a
    ///      `decision table` block).
    ///   3. Any question is not checkable (needs entity/semantic judgment,
    ///      e.g. brain_taxonomist's "Is the primary subject a NAMED PERSON?")
    ///      and the block carries an AI-inference cue (P1 category 2) → the
    ///      whole list is wrapped in `use judgment to …:` rather than faked
    ///      determinism. With no inference cue, the list is a category-4
    ///      reword error (`.errorOperational`) — never a silent AI wrap.
    /// Returns nil when the block doesn't parse as a question-arrow list at
    /// all (defensive; the caller only invokes this once `isQuestionArrowList`
    /// already confirmed every line parses).
    func classifyQuestionArrowList(
        _ block: SplitBlock, precedingBlock: SplitBlock?, trial: TrialLowering
    ) -> (kind: SplitKind, renderOverride: [String]?) {
        let items = block.rawLines.compactMap { parseQuestionArrowLine($0) }
        guard items.count == block.rawLines.count, !items.isEmpty else { return (.documentation, nil) }

        let lexicon = trial.knowledge.lexicon
        let grammar = lexicon.grammar
        let statement = grammar.statement
        let onlyWhen = grammar.affirmativeSuffixConditionalMarker
        let article = (lexicon.definiteArticle ?? "the") + " "

        func predicateText(_ question: String) -> String {
            String(question.dropLast()).trimmingCharacters(in: .whitespaces)
        }
        let allCheckable = items.allSatisfy { trial.isCheckableCondition(predicateText($0.question)) }
        guard allCheckable else {
            guard trial.hasInferenceCue(block.rawLines.joined(separator: "\n")) else {
                return (.errorOperational, nil)
            }
            // Not a Markdown table, so `!!! table (( ai-discretion ))` (which
            // requires a real `|`-delimited table) doesn't apply — wrap in the
            // generic `use judgment to …:` block instead, indenting the raw
            // items two spaces so `StatementParser`'s indentation-bounded body
            // collection (not the heading-following variant) scopes to just
            // this block, leaving any sibling exec content in the same run
            // alone.
            let goal = grammar.questionArrowJudgmentGoal
            let indented = block.rawLines.map { "  " + $0.trimmingCharacters(in: .whitespaces) }
            return (.aiInference, [goal] + indented)
        }

        let allRhsAreStatements = items.allSatisfy { trial.lowersAsStatement($0.rhs) }
        if allRhsAreStatements {
            let lines = items.map { "\($0.rhs)\(onlyWhen)\(predicateText($0.question))." }
            return (.exec, lines)
        }

        let name = questionArrowResultName(precedingBlock: precedingBlock, lexicon: lexicon)
        let lines = items.map {
            "\(statement.letPrefix)\(article)\(name)\(statement.letBeMarker)\"\($0.rhs)\"\(onlyWhen)\(predicateText($0.question))."
        }
        return (.exec, lines)
    }
}
