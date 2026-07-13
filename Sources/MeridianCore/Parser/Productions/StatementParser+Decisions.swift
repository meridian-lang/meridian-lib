import Foundation
import MeridianRuntime

// MARK: - Judgment & choice decisions
//
// `use judgment to …` / `with discretion:` / `with autonomy …:` prose
// dispatch, choice-gate waits, and choice-branch conditionals —
// extracted from StatementParser for Phase 3 readability.

extension StatementParser {

    /// Parse an explicit judgment marker into a `.proseStep` carrying its own
    /// dispatch mode (so it is valid in any workflow, deterministic-by-default):
    ///
    ///   • `use judgment to <goal>:`  + indented instructions → discretion
    ///   • `use judgment to <goal>.`  (single line)            → discretion
    ///   • `with discretion:`         + indented instructions  → discretion
    ///   • `with autonomy <opts>:`    + indented instructions  → autonomy
    ///
    /// Returns `nil` when the line is not a judgment marker.
    func parseJudgmentMarker(_ lines: [SourceLine], at i: Int, sourceFile: String) throws -> (StatementAST, Int)? {
        let line = lines[i]
        let t = line.statement
        let lower = t.lowercased()
        let collectUntilNextHeading = lower.hasPrefix(lexicon.grammar.judgmentFollowCollectPrefix)

        func collectBody() -> (text: [String], consumed: Int) {
            var bodyLines: [String] = []
            var j = i + 1
            while j < lines.count {
                let l = lines[j]
                if collectUntilNextHeading {
                    if l.headingLevel != nil { break }
                    if l.isEmpty || l.isComment { j += 1; continue }
                    bodyLines.append(l.statement)
                    j += 1
                    continue
                }
                if l.isEmpty || l.isComment { j += 1; continue }
                if l.indent > line.indent { bodyLines.append(l.statement); j += 1 } else { break }
            }
            return (bodyLines, j - i)
        }

        // `use judgment to <goal>` — block (ends with ":") or single line.
        for prefix in lexicon.grammar.judgmentIntroducers {
            guard lower.hasPrefix(prefix) else { continue }
            var goal = String(t.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
            let isBlock = goal.hasSuffix(":")
            if isBlock { goal = String(goal.dropLast()).trimmingCharacters(in: .whitespaces) }
            var consumed = 1
            var proseText = goal
            var guidance: String?
            let parsedContract = parseJudgmentContract(&proseText)
            if isBlock {
                let body = collectBody()
                consumed += body.consumed - 1
                if !body.text.isEmpty {
                    // `…follow the <heading> guidance:` collects a whole
                    // leftover inert-narrative body verbatim (Phase 1 §3/§4).
                    // Keep the dispatch goal short in `text` and carry that
                    // narrative separately as planner context, rather than
                    // folding it into one prose blob.
                    if collectUntilNextHeading {
                        guidance = body.text.joined(separator: "\n")
                    } else {
                        proseText = ([goal] + body.text).filter { !$0.isEmpty }.joined(separator: "\n")
                    }
                }
            }
            if !collectUntilNextHeading,
               parsedContract.outputs.isEmpty,
               let cue = lexicon.effectfulJudgmentCuePhrases.first(where: { containsWholePhrase($0, in: proseText) }) {
                try raiseStructural(
                    .judgmentWithoutProducedValue,
                    message: "judgment goal \"\(proseText)\" names an effectful action (`\(cue)`) without `producing a <kind> called <name>`",
                    range: SourceRange(file: sourceFile, line: line.number, column: 1),
                    help: "Add `, producing a <kind> called <name>` to the judgment header, or move the effect into a kernel step that consumes a produced value.")
            }
            return (.proseStep(ProseStepAST(
                text: proseText, sourceLine: line.number, dispatch: .discretion, guidance: guidance,
                outputBindings: parsedContract.outputs, usingTools: parsedContract.tools)), consumed)
        }

        // `with discretion:` block.
        if lower == lexicon.grammar.discretionMarker + ":" || lower == lexicon.grammar.discretionMarker {
            let body = collectBody()
            let proseText = body.text.joined(separator: "\n")
            return (.proseStep(ProseStepAST(text: proseText, sourceLine: line.number, dispatch: .discretion)), body.consumed)
        }

        // `with autonomy <options>:` block.
        if lower.hasPrefix(lexicon.grammar.autonomyMarker) {
            let afterMarker = String(t.dropFirst(lexicon.grammar.autonomyMarker.count))
            let opts = afterMarker.hasSuffix(":")
                ? String(afterMarker.dropLast()).trimmingCharacters(in: .whitespaces)
                : afterMarker.trimmingCharacters(in: .whitespaces)
            let body = collectBody()
            let proseText = body.text.joined(separator: "\n")
            return (.proseStep(ProseStepAST(
                text: proseText,
                sourceLine: line.number,
                dispatch: .autonomy,
                autonomy: AutonomyConfigAST.parse(opts, parseExpression: exprParser.parse)
            )), body.consumed)
        }

        return nil
    }

    struct JudgmentContractParse {
        var outputs: [(kind: String, name: String)] = []
        var tools: [String] = []
    }

    /// Strip `, producing a <kind> called <name>` and `, using <tools>` tails from
    /// a judgment goal phrase before it becomes planner `text`.
    func parseJudgmentContract(_ goal: inout String) -> JudgmentContractParse {
        var result = JudgmentContractParse()
        if let usingRange = goal.range(of: ", using ", options: [.caseInsensitive, .backwards]) {
            let tail = String(goal[usingRange.upperBound...]).trimmingCharacters(in: .whitespaces)
            goal = String(goal[..<usingRange.lowerBound]).trimmingCharacters(in: .whitespaces)
            result.tools = tail.split(separator: " and ").map {
                $0.trimmingCharacters(in: .whitespaces)
                    .trimmingCharacters(in: CharacterSet(charactersIn: ":"))
            }.filter { !$0.isEmpty }
        }
        while let producingRange = goal.range(of: ", producing a ", options: [.caseInsensitive, .backwards]) {
            let tail = String(goal[producingRange.upperBound...]).trimmingCharacters(in: .whitespaces)
            goal = String(goal[..<producingRange.lowerBound]).trimmingCharacters(in: .whitespaces)
            if let calledRange = tail.range(of: " called ", options: .caseInsensitive) {
                let kind = String(tail[..<calledRange.lowerBound]).trimmingCharacters(in: .whitespaces)
                let name = String(tail[calledRange.upperBound...]).trimmingCharacters(in: .whitespaces)
                if !kind.isEmpty, !name.isEmpty {
                    result.outputs.append((kind: kind, name: name))
                }
            }
        }
        return result
    }

    /// Parse a choice-gate statement:
    /// `ask the user to choose between "A", "B", or "C":` (trailing `:` optional),
    /// or the Markdown option-list form:
    ///
    ///   ask the user to choose between:
    ///       1. Supabase
    ///       2. BYO Postgres
    ///
    /// Numbered options use the number as the runtime selection value so
    /// follow-up branches like `if the user picks 1:` can route deterministically.
    func parseChoiceGate(_ lines: [SourceLine], at i: Int) -> (statement: WaitStatementAST, consumed: Int)? {
        let line = lines[i]
        let t = line.statement
        let lower = t.lowercased()
        let markers = lexicon.grammar.choiceGateIntroducers
        let marker = markers.first(where: { lower.hasPrefix($0) })
            ?? markers.map { $0.trimmingCharacters(in: .whitespaces) }
                .first(where: { lower == $0 || lower == $0 + ":" })
        guard let marker else { return nil }
        let rest = String(t.dropFirst(marker.count))
        var options = doubleQuotedSpans(in: rest)
        var consumed = 1
        if options.isEmpty {
            let collected = collectChoiceOptions(lines, after: i)
            options = collected.options
            consumed += collected.consumed
        }
        guard !options.isEmpty else { return nil }
        return (WaitStatementAST(
            condition: .choice(prompt: t, options: options),
            sourceLine: line.number
        ), consumed)
    }

    func collectChoiceOptions(_ lines: [SourceLine], after i: Int) -> (options: [String], consumed: Int) {
        let parentIndent = lines[i].indent
        var options: [String] = []
        var consumed = 0
        var j = i + 1
        while j < lines.count {
            let line = lines[j]
            if line.isEmpty || line.isComment { j += 1; consumed += 1; continue }
            guard line.indent > parentIndent else { break }
            if let option = choiceOptionValue(line.raw) ?? choiceOptionValue(line.statement) {
                options.append(option)
                j += 1
                consumed += 1
                continue
            }
            break
        }
        return (options, consumed)
    }

    func choiceOptionValue(_ text: String) -> String? {
        let raw = text.trimmingCharacters(in: .whitespaces)
        if let quoted = doubleQuotedSpans(in: raw).first { return quoted }
        if let numeric = leadingChoiceNumber(in: raw) { return numeric }
        let stripped = stripMarkdownListMarker(raw)
        return stripped.isEmpty ? nil : stripped
    }

    func leadingChoiceNumber(in s: String) -> String? {
        var digits = ""
        var idx = s.startIndex
        while idx < s.endIndex, s[idx].isNumber {
            digits.append(s[idx])
            idx = s.index(after: idx)
        }
        guard !digits.isEmpty, idx < s.endIndex, s[idx] == "." || s[idx] == ")" else { return nil }
        return digits
    }

    func parseChoiceBranch(_ lines: [SourceLine], at i: Int, sourceFile: String) throws
        -> (statement: ConditionalStatementAST, consumed: Int)? {
        let line = lines[i]
        let t = line.statement.trimmingCharacters(in: .whitespaces)
        let statement = lexicon.grammar.statement
        guard t.lowercased().hasPrefix(statement.ifPrefix), t.hasSuffix(":") else { return nil }
        let label = String(t.dropFirst(statement.ifPrefix.count).dropLast()).trimmingCharacters(in: .whitespaces)
        guard let selected = choiceBranchSelection(label) else { return nil }

        let parentIndent = line.indent
        var bodyLines: [SourceLine] = []
        var j = i + 1
        while j < lines.count {
            let l = lines[j]
            if l.isEmpty || l.isComment { j += 1; continue }
            if l.indent > parentIndent {
                bodyLines.append(l)
                j += 1
            } else {
                break
            }
        }
        let body = try parseBlock(bodyLines, sourceFile: sourceFile)
        let condition = exprParser.parse("\(lexicon.grammar.choiceBranchLabels.choiceConditionPrefix)\"\(selected)\"")
        return (ConditionalStatementAST(condition: condition, thenBlock: body, elseBlock: nil,
                                        sourceLine: line.number), j - i)
    }

    func choiceBranchSelection(_ label: String) -> String? {
        let lower = label.lowercased()
        let labels = lexicon.grammar.choiceBranchLabels
        if labels.yesLabels.contains(lower) { return "yes" }
        if labels.noLabels.contains(lower) { return "no" }
        for prefix in labels.pickPrefixes where lower.hasPrefix(prefix) {
            let value = String(label.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
            return value.isEmpty ? nil : value
        }
        return nil
    }

    /// Extract the contents of each double-quoted span in `s`, in order.
    func doubleQuotedSpans(in s: String) -> [String] {
        var spans: [String] = []
        var current = ""
        var inQuote = false
        for c in s {
            if c == "\"" {
                if inQuote { spans.append(current); current = "" }
                inQuote.toggle()
                continue
            }
            if inQuote { current.append(c) }
        }
        return spans
    }

}
