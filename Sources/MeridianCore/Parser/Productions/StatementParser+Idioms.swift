import Foundation
import MeridianRuntime

// MARK: - English idioms & iteration helpers
//
// Surface idioms (background spawn, try/except, suffix conditionals,
// every/each, compound note) plus iteration-refinement / chain helpers
// extracted from StatementParser for Phase 3 readability.

extension StatementParser {

    func parseEnglishIdiom(_ line: SourceLine, sourceFile: String) throws -> StatementAST? {
        let t = line.statement
        let lower = t.lowercased()

        // Background spawn: `in the background, <stmt>.` → detached simultaneously.
        for prefix in lexicon.grammar.backgroundSpawnIntroducers {
            guard lower.hasPrefix(prefix) else { continue }
            let actionText = String(t.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
            guard !actionText.isEmpty else { return nil }
            let actionLine = SourceLine(indent: line.indent, text: actionText, raw: line.raw, number: line.number)
            guard let stmt = try parseStatement([actionLine], at: 0, sourceFile: sourceFile).0 else { return nil }
            return .simultaneously(SimultaneouslyStatementAST(
                branches: [ASTBlock(statements: [stmt], sourceLine: line.number)],
                detached: true,
                sourceLine: line.number
            ))
        }

        if let marker = lexicon.assertionMarkers.first(where: { lower.hasPrefix($0 + " ") }) {
            let condition = String(t.dropFirst(marker.count + 1)).trimmingCharacters(in: .whitespaces)
            guard !condition.isEmpty else { return nil }
            return .assertStmt(AssertStatementAST(
                condition: exprParser.parse(condition),
                message: "Expected \(condition)",
                sourceLine: line.number
            ))
        }

        if lower.hasPrefix(lexicon.grammar.afterIdiomIntroducer),
           let comma = rangeOfMarkerOutsideQuotes(", ", in: t) {
            let conditionText = String(t[t.index(t.startIndex, offsetBy: lexicon.grammar.afterIdiomIntroducer.count)..<comma.lowerBound])
                .trimmingCharacters(in: .whitespaces)
            let actionText = String(t[comma.upperBound...]).trimmingCharacters(in: .whitespaces)
            guard !conditionText.isEmpty, !actionText.isEmpty else { return nil }
            let actionLine = SourceLine(indent: line.indent + 2, text: actionText, raw: line.raw, number: line.number)
            let (stmt, _) = try parseStatement([actionLine], at: 0, sourceFile: sourceFile)
            guard let stmt else { return nil }
            return .conditional(ConditionalStatementAST(
                condition: exprParser.parse(conditionText),
                thenBlock: ASTBlock(statements: [stmt], sourceLine: line.number),
                sourceLine: line.number
            ))
        }

        if let range = rangeOfMarkerOutsideQuotes(lexicon.grammar.exceptWhenMarker, in: t) {
            let actionText = String(t[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
            let predicateText = String(t[range.upperBound...]).trimmingCharacters(in: .whitespaces)
            guard !actionText.isEmpty, !predicateText.isEmpty else { return nil }
            let rewritten = "\(actionText)\(lexicon.grammar.suffixConditionalNegated)\(predicateText)"
            let rewrittenLine = SourceLine(indent: line.indent, text: rewritten, raw: line.raw, number: line.number)
            return try parseStatement([rewrittenLine], at: 0, sourceFile: sourceFile).0
        }

        if lower.hasPrefix(lexicon.grammar.tryIdiomIntroducer),
           let range = rangeOfMarkerOutsideQuotes(lexicon.grammar.tryIdiomFailureSeparator, in: t) {
            let actionText = String(t[t.index(t.startIndex, offsetBy: lexicon.grammar.tryIdiomIntroducer.count)..<range.lowerBound])
                .trimmingCharacters(in: .whitespaces)
            let handlerText = String(t[range.upperBound...]).trimmingCharacters(in: .whitespaces)
            guard !actionText.isEmpty, !handlerText.isEmpty else { return nil }
            let actionLine = SourceLine(indent: line.indent, text: actionText, raw: line.raw, number: line.number)
            let handlerLine = SourceLine(indent: line.indent + 2, text: handlerText, raw: line.raw, number: line.number)
            guard let action = try parseStatement([actionLine], at: 0, sourceFile: sourceFile).0,
                  let handler = try parseStatement([handlerLine], at: 0, sourceFile: sourceFile).0 else { return nil }
            return .recover(RecoverStatementAST(
                pattern: .any,
                handler: ASTBlock(statements: [handler], sourceLine: line.number),
                attached: action,
                sourceLine: line.number
            ))
        }

        if let passive = passiveVoiceRewrite(t) {
            let rewrittenLine = SourceLine(indent: line.indent, text: passive, raw: line.raw, number: line.number)
            return try parseStatement([rewrittenLine], at: 0, sourceFile: sourceFile).0
        }

        return nil
    }

    func passiveVoiceRewrite(_ text: String) -> String? {
        let markers = lexicon.grammar.passiveModalityMarkers
        for marker in markers {
            guard let range = text.range(of: marker, options: [.caseInsensitive]) else { continue }
            let subject = String(text[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
            var verb = String(text[range.upperBound...]).trimmingCharacters(in: .whitespaces)
            guard !subject.isEmpty, verb.hasSuffix("ed") else { continue }
            verb.removeLast(2)
            if verb.hasSuffix("v") { verb += "e" }
            return "\(verb) \(subject)"
        }
        return nil
    }

    func parseSuffixConditional(_ line: SourceLine, sourceFile: String) throws -> ConditionalStatementAST? {
        let t = line.statement
        let markers = lexicon.grammar.suffixConditionalMarkers
        for marker in markers {
            guard let range = rangeOfMarkerOutsideQuotes(marker, in: t) else { continue }
            let actionText = String(t[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
            let predicateText = String(t[range.upperBound...]).trimmingCharacters(in: .whitespaces)
            guard !actionText.isEmpty, !predicateText.isEmpty else { return nil }

            let actionLine = SourceLine(indent: line.indent + 2, text: actionText, raw: line.raw, number: line.number)
            let (stmt, _) = try parseStatement([actionLine], at: 0, sourceFile: sourceFile)
            guard let stmt else { return nil }

            let parsedPredicate = parseDecisionPredicate(predicateText)
            let condition: ExpressionAST = marker == lexicon.grammar.suffixConditionalNegated
                ? .logical(.not, [parsedPredicate])
                : parsedPredicate
            return ConditionalStatementAST(
                condition: condition,
                thenBlock: ASTBlock(statements: [stmt], sourceLine: line.number),
                authoredForm: marker == lexicon.grammar.suffixConditionalNegated ? .unlessSuffix : .ifPositive,
                sourceLine: line.number
            )
        }
        return nil
    }

    func parseUnlessDecisionConditional(
        _ lines: [SourceLine],
        at i: Int,
        sourceFile: String
    ) throws -> (ConditionalStatementAST, Int) {
        let line = lines[i]
        var question = String(line.statement.dropFirst(lexicon.grammar.unlessYouDecideIntroducer.count))
        if question.hasSuffix(",") { question = String(question.dropLast()) }
        let parentIndent = line.indent
        var bodyLines: [SourceLine] = []
        var j = i + 1
        while j < lines.count {
            let l = lines[j]
            if l.isEmpty || l.isComment { j += 1; continue }
            if l.indent > parentIndent { bodyLines.append(l); j += 1 }
            else { break }
        }
        let body = try parseBlock(bodyLines, sourceFile: sourceFile)
        return (ConditionalStatementAST(
            condition: .logical(.not, [.decideWhether(question: question.trimmingCharacters(in: .whitespaces))]),
            thenBlock: body,
            sourceLine: line.number
        ), j - i)
    }

    func parseDecisionPredicate(_ text: String) -> ExpressionAST {
        let t = text.trimmingCharacters(in: .whitespaces)
        let lower = t.lowercased()
        if lower.hasPrefix(lexicon.grammar.youDecideIntroducer) {
            let question = String(t.dropFirst(lexicon.grammar.youDecideIntroducer.count)).trimmingCharacters(in: .whitespaces)
            return .decideWhether(question: question)
        }
        return exprParser.parse(t)
    }

    func parseEveryEach(_ line: SourceLine, sourceFile: String) throws -> IterationStatementAST? {
        let t = line.statement
        for marker in lexicon.grammar.iterationMarkers.embeddedEachMarkers {
            guard let range = rangeOfMarkerOutsideQuotes(marker, in: t) else { continue }
            let action = String(t[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
            let rawNounPhrase = String(t[range.upperBound...]).trimmingCharacters(in: .whitespaces)
            guard !action.isEmpty, !rawNounPhrase.isEmpty else { return nil }

            let (rawNoun, refinement) = try extractIterationRefinement(rawNounPhrase, sourceFile: sourceFile, line: line.number)
            guard !rawNoun.isEmpty else { return nil }

            let singular = lexicon.singularize(rawNoun)
            let variable = camelize(singular)
            let collection = ExpressionAST.identifierRef(camelize(lexicon.pluralize(singular)))
            let bodyText = "\(action) the \(singular)"
            let body = ASTBlock(
                statements: [.phraseInvocation(PhraseInvocationAST(words: bodyText, sourceLine: line.number))],
                sourceLine: line.number
            )
            return IterationStatementAST(
                mode: .forEach(variable: variable, collection: collection),
                body: body,
                sourceLine: line.number,
                refinement: refinement
            )
        }
        return nil
    }

    /// Strip a single-clause iteration refinement (1C) off a noun phrase,
    /// returning the bare kind noun plus the parsed refinement (or nil). Grammar,
    /// in order: `[the first N] <kind plural> [whose <pred> | within the last N
    /// <unit> | in the next N <unit>] [sorted by <prop>[, <dir>]]`. Sorting is
    /// recognized as a trailing clause; the filter clause is single (the first
    /// of `whose`/temporal that appears); `the first N` is a leading prefix.
    func extractIterationRefinement(
        _ phrase: String,
        sourceFile: String,
        line: Int
    ) throws -> (noun: String, refinement: IterationRefinementAST?) {
        var work = phrase.trimmingCharacters(in: .whitespaces)
        var ref = IterationRefinementAST()

        // 1. Trailing `sorted by <prop>[, <dir>]`.
        if let r = lexicon.sortByMarkers.lazy.compactMap({ rangeOfMarkerOutsideQuotes($0, in: work) }).first {
            let head = String(work[..<r.lowerBound])
            var tail = String(work[r.upperBound...]).trimmingCharacters(in: .whitespaces)
            var ascending = true
            if let comma = tail.range(of: ",") {
                let dir = String(tail[comma.upperBound...]).trimmingCharacters(in: .whitespaces).lowercased()
                tail = String(tail[..<comma.lowerBound]).trimmingCharacters(in: .whitespaces)
                if lexicon.descendingMarkers.contains(where: { dir.contains($0) }) { ascending = false }
                else if lexicon.ascendingMarkers.contains(where: { dir.contains($0) }) { ascending = true }
            }
            if !tail.isEmpty { ref.sort = (camelize(tail), ascending) }
            work = head.trimmingCharacters(in: .whitespaces)
        }

        // 2. Single filter clause: whose / within the last / in the next.
        if let r = rangeOfMarkerOutsideQuotes(lexicon.grammar.iterationMarkers.whoseMarker, in: work) {
            let head = String(work[..<r.lowerBound])
            let clause = String(work[r.upperBound...]).trimmingCharacters(in: .whitespaces)
            if let hedge = conditionVagueHedge(in: clause) {
                try raiseStructural(
                    .conditionUnknownComparator,
                    message: "vague hedge `\(hedge)` is not a checkable comparator",
                    range: SourceRange(file: sourceFile, line: line, column: 1),
                    help: "Use a closed comparator (`is`, `equals`, `is more than`, …) or move vague wording into a `use judgment to …:` block.")
            }
            if !clause.isEmpty { ref.predicate = exprParser.parse(clause) }
            work = head.trimmingCharacters(in: .whitespaces)
        } else if let hit = lexicon.temporalWindowMarkers.lazy.compactMap({ (marker, op) -> (Range<String.Index>, ComparisonOpAST)? in
            rangeOfMarkerOutsideQuotes(marker, in: work).map { ($0, op) }
        }).first {
            let head = String(work[..<hit.0.lowerBound])
            let clause = String(work[hit.0.upperBound...]).trimmingCharacters(in: .whitespaces)
            if let secs = durationSeconds(clause) {
                ref.temporal = (lexicon.timestampProperty, hit.1 == .withinPast ? .past : .future, secs)
            }
            work = head.trimmingCharacters(in: .whitespaces)
        }

        // 3. Leading `[the ]first N` or `[the ]last N` (take suffix disambiguated
        // from temporal windows by requiring a kind noun after the count).
        let firstScan = lexicon.stripLeadingArticle(work)
        let lowerFirst = firstScan.lowercased()
        if let definite = lexicon.definiteArticle,
           lowerFirst.hasPrefix(definite + " ") {
            let afterThe = String(firstScan.dropFirst(definite.count + 1))
            if afterThe.lowercased().hasPrefix(lexicon.grammar.iterationMarkers.lastTakePrefix) {
                let afterLast = String(afterThe.dropFirst(lexicon.grammar.iterationMarkers.lastTakePrefix.count))
                    .trimmingCharacters(in: .whitespaces)
                let comps = afterLast.split(separator: " ", maxSplits: 1).map(String.init)
                if let n = Int(comps.first ?? ""), comps.count > 1 {
                    ref.takeFromEnd = n
                    work = comps[1].trimmingCharacters(in: .whitespaces)
                }
            } else if afterThe.lowercased().hasPrefix(lexicon.grammar.iterationMarkers.firstPrefix) {
                let afterFirst = String(afterThe.dropFirst(lexicon.grammar.iterationMarkers.firstPrefix.count))
                    .trimmingCharacters(in: .whitespaces)
                let comps = afterFirst.split(separator: " ", maxSplits: 1).map(String.init)
                if let n = Int(comps.first ?? ""), comps.count > 1 {
                    ref.take = n
                    work = comps[1].trimmingCharacters(in: .whitespaces)
                }
            }
        }
        if ref.take == nil, ref.takeFromEnd == nil,
           firstScan.lowercased().hasPrefix(lexicon.grammar.iterationMarkers.firstPrefix) {
            let after = String(firstScan.dropFirst(lexicon.grammar.iterationMarkers.firstPrefix.count)).trimmingCharacters(in: .whitespaces)
            let comps = after.split(separator: " ", maxSplits: 1).map(String.init)
            if let n = Int(comps.first ?? "") {
                ref.take = n
                work = comps.count > 1 ? comps[1].trimmingCharacters(in: .whitespaces) : ""
            }
        }

        // Any comma still in `work` at this point is not the sorted-by
        // direction comma (already consumed in step 1) — it is an
        // unrecognized trailing clause, e.g. a participial aside ("each
        // one, checking for inline citations"). Bound the noun to the text
        // before it rather than folding punctuation into the generated
        // identifier, which would produce an invalid Swift variable name
        // downstream (a bare comma is parsed as a tuple-pattern separator).
        if let comma = work.range(of: ",") {
            work = String(work[..<comma.lowerBound]).trimmingCharacters(in: .whitespaces)
        }

        return (work.trimmingCharacters(in: .whitespaces), ref.isEmpty ? nil : ref)
    }

    func containsWholePhrase(_ phrase: String, in text: String) -> Bool {
        let padded = " \(text.lowercased()) "
        return padded.contains(" \(phrase.lowercased()) ")
    }

    func conditionVagueHedge(in text: String) -> String? {
        let padded = " \(text.lowercased()) "
        return lexicon.conditionVagueHedges.first { padded.contains(" \($0) ") }
    }

    /// Parse "N <unit>" into total seconds using the lexicon's duration table.
    func durationSeconds(_ s: String) -> Double? {
        guard let (amount, unit) = lexicon.parseDuration(s) else { return nil }
        return amount * Double(unit.inSeconds)
    }

    func splitStatementChain(_ text: String) -> [String] {
        var parts: [String] = []
        var current = ""
        var depth = 0
        var inString = false
        // True once a chain element has entered an invoke argument list via
        // ` with `. While true, plain commas separate invoke arguments rather
        // than chain elements; only `, and `, ` and `, or ` then ` terminate
        // the element.
        var inInvokeArgs = false
        var i = text.startIndex
        while i < text.endIndex {
            let c = text[i]
            if c == "\"" {
                inString.toggle()
                current.append(c)
                i = text.index(after: i)
                continue
            }
            if !inString {
                if c == "(" { depth += 1 }
                else if c == ")" { depth = max(0, depth - 1) }

                // Enter "invoke args" mode when we see ` with ` at depth 0.
                if depth == 0, !inInvokeArgs,
                   text[i...].lowercased().hasPrefix(lexicon.grammar.merconfig.withMarker) {
                    inInvokeArgs = true
                }

                // `, and ` is a chain terminator even when we're inside an
                // invoke argument list — `and` introduces the next element.
                if depth == 0,
                   text[i...].lowercased().hasPrefix(lexicon.grammar.iterationMarkers.chainCommaAndMarker) {
                    parts.append(cleanChainPart(current))
                    current = ""
                    inInvokeArgs = false
                    i = text.index(i, offsetBy: lexicon.grammar.iterationMarkers.chainCommaAndMarker.count)
                    continue
                }
                if depth == 0,
                   text[i...].lowercased().hasPrefix(lexicon.grammar.iterationMarkers.chainAndMarker) {
                    parts.append(cleanChainPart(current))
                    current = ""
                    inInvokeArgs = false
                    i = text.index(i, offsetBy: lexicon.grammar.iterationMarkers.chainAndMarker.count)
                    continue
                }
                if depth == 0,
                   text[i...].lowercased().hasPrefix(lexicon.grammar.iterationMarkers.chainThenMarker) {
                    parts.append(cleanChainPart(current))
                    current = ""
                    inInvokeArgs = false
                    i = text.index(i, offsetBy: lexicon.grammar.iterationMarkers.chainThenMarker.count)
                    continue
                }
                // Plain comma only splits when not collecting invoke arguments.
                if depth == 0, !inInvokeArgs, c == "," {
                    parts.append(cleanChainPart(current))
                    current = ""
                    i = text.index(after: i)
                    continue
                }
            }
            current.append(c)
            i = text.index(after: i)
        }
        parts.append(cleanChainPart(current))
        return parts.filter { !$0.isEmpty }
    }

    func cleanChainPart(_ part: String) -> String {
        var s = part.trimmingCharacters(in: .whitespaces)
        if s.lowercased().hasPrefix(lexicon.grammar.iterationMarkers.cleanupAndPrefix) {
            s = String(s.dropFirst(lexicon.grammar.iterationMarkers.cleanupAndPrefix.count)).trimmingCharacters(in: .whitespaces)
        }
        if s.lowercased().hasPrefix(lexicon.grammar.iterationMarkers.cleanupThenPrefix) {
            s = String(s.dropFirst(lexicon.grammar.iterationMarkers.cleanupThenPrefix.count)).trimmingCharacters(in: .whitespaces)
        }
        return s
    }

    /// Hyphen-aware camelCase for phrase parameters (`pull-request` → `pullRequest`).
    /// Do not replace with `IdentifierNaming.lowerCamel` — that helper does not split on hyphens.
    func camelize(_ raw: String) -> String {
        IdentifierNaming.lowerCamelSplittingHyphen(raw)
    }

    func rangeOfMarkerOutsideQuotes(_ marker: String, in text: String) -> Range<String.Index>? {
        QuoteAwareScanner.rangeOfMarker(marker, in: text, caseInsensitive: true)
    }

    /// INFORM7 §2.9 compound note: `proceed, and note "<text>" in the <binding>`.
    /// Returns nil when the fixed shape (a quoted note followed by the ` in `
    /// marker and a binding) is absent, so the caller can raise a precise
    /// malformed-statement diagnostic.
    func parseCompoundNote(_ t: String, line: SourceLine) -> NoteStatementAST? {
        let introducer = lexicon.grammar.compoundNoteIntroducer
        guard t.count >= introducer.count else { return nil }
        var rest = String(t.dropFirst(introducer.count)).trimmingCharacters(in: .whitespaces)
        if rest.hasSuffix(".") { rest = String(rest.dropLast()) }
        guard let firstQuote = rest.firstIndex(of: "\"") else { return nil }
        let afterFirst = rest.index(after: firstQuote)
        guard let secondQuote = rest[afterFirst...].firstIndex(of: "\"") else { return nil }
        let text = String(rest[afterFirst..<secondQuote])
        let tail = String(rest[rest.index(after: secondQuote)...])
        guard let inRange = tail.range(of: lexicon.grammar.compoundNoteInMarker) else { return nil }
        let bindingPart = String(tail[inRange.upperBound...]).trimmingCharacters(in: .whitespaces)
        let binding = lexicon.stripLeadingArticle(bindingPart).trimmingCharacters(in: .whitespaces)
        guard !binding.isEmpty, !text.isEmpty else { return nil }
        return NoteStatementAST(binding: binding, text: text, sourceLine: line.number)
    }

}
