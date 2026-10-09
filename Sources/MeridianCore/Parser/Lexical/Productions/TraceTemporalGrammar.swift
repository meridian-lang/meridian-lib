import Foundation

struct TraceTemporalGrammar {
    let lexicon: EnglishLexicon
    let recurse: (String) -> ExpressionAST
    let eventPattern: (String) -> EventPatternAST?
    /// Anchor-position resolution (`TraceEventPatternGrammar.parseAnchor`):
    /// same event-pattern grammar, but a subject with no explicit outcome
    /// verb defaults to generic completion (kind-flavored anchors like
    /// `the last production deploy`).
    let anchorPattern: (String) -> EventPatternAST?

    func parse(_ raw: String) -> ExpressionAST? {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        if let diagnostic = earlyDiagnostic(for: text) {
            return diagnostic
        }
        if let scoped = parseScoped(text) { return scoped }
        if let future = parseBoundedFutureMonitor(text) {
            return .traceTemporal(TraceTemporalAST(kind: future))
        }
        if let since = parseSince(text) { return since }
        if let count = parseCountInWindow(text) { return count }
        if let inARow = parseInARow(text) { return inARow }
        if let window = parseWithinWindow(text) { return window }
        if let ever = parseEver(text) { return ever }
        if looksLikeBarePerfect(text) {
            return .malformed(
                "Bare perfect temporal event predicates need an explicit operator such as `has ever`, `within the last`, `times in a row`, or `since the last`.",
                code: .traceBarePerfect,
                help: "Rewrite the condition with an explicit temporal operator."
            )
        }
        return nil
    }

    private func parseScoped(_ text: String) -> ExpressionAST? {
        let acrossSkills = lexicon.grammar.traceAcrossSkillsMarker
        if text.lowercased().hasPrefix(acrossSkills) {
            let remainder = String(text.dropFirst(acrossSkills.count)).trimmingCharacters(in: .whitespaces)
            let parts = remainder.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            guard parts.count >= 2 else { return nil }
            for split in stride(from: parts.count - 1, through: 1, by: -1) {
                let skills = Array(parts[0..<split]).filter { !$0.isEmpty }
                let body = parts[split...].joined(separator: ", ").trimmingCharacters(in: .whitespaces)
                guard !skills.isEmpty, !body.isEmpty, let inner = parseUnscopedTemporal(body) else { continue }
                return .traceTemporal(TraceTemporalAST(scope: .acrossSkills(skills), kind: inner))
            }
            return nil
        }
        let marker = lexicon.grammar.traceAcrossAllRunsMarker
        guard text.lowercased().hasPrefix(marker) else { return nil }
        let remainder = String(text.dropFirst(marker.count)).trimmingCharacters(in: .whitespaces)
        guard let inner = parseUnscopedTemporal(remainder) else { return nil }
        return .traceTemporal(TraceTemporalAST(scope: .acrossAllRuns, kind: inner))
    }

    private func parseUnscopedTemporal(_ text: String) -> TraceTemporalKindAST? {
        if let since = parseSince(text) {
            if case .traceTemporal(let temporal) = since { return temporal.kind }
        }
        if let count = parseCountInWindow(text) {
            if case .traceTemporal(let temporal) = count { return temporal.kind }
        }
        if let inARow = parseInARow(text) {
            if case .traceTemporal(let temporal) = inARow { return temporal.kind }
        }
        if let window = parseWithinWindow(text) {
            if case .traceTemporal(let temporal) = window { return temporal.kind }
        }
        if let ever = parseEver(text) {
            if case .traceTemporal(let temporal) = ever { return temporal.kind }
        }
        if let future = parseBoundedFutureMonitor(text) { return future }
        return nil
    }

    private func parseBoundedFutureMonitor(_ text: String) -> TraceTemporalKindAST? {
        let lower = text.lowercased()
        if lower.hasPrefix(lexicon.grammar.traceEventuallyWithinMarker) {
            let remainder = String(text.dropFirst(lexicon.grammar.traceEventuallyWithinMarker.count))
            guard let comma = remainder.firstIndex(of: ",") else { return nil }
            let durationText = String(remainder[..<comma]).trimmingCharacters(in: .whitespaces)
            let conditionText = String(remainder[remainder.index(after: comma)...]).trimmingCharacters(in: .whitespaces)
            guard let duration = parseLeadingDuration(durationText), !conditionText.isEmpty else { return nil }
            return .boundedFutureMonitor(condition: recurse(conditionText), horizon: duration, mode: .eventuallyWithin)
        }
        if lower.hasPrefix(lexicon.grammar.traceAlwaysForMarker) {
            let remainder = String(text.dropFirst(lexicon.grammar.traceAlwaysForMarker.count))
            guard let comma = remainder.firstIndex(of: ",") else { return nil }
            let durationText = String(remainder[..<comma]).trimmingCharacters(in: .whitespaces)
            let conditionText = String(remainder[remainder.index(after: comma)...]).trimmingCharacters(in: .whitespaces)
            guard let duration = parseLeadingDuration(durationText), !conditionText.isEmpty else { return nil }
            return .boundedFutureMonitor(condition: recurse(conditionText), horizon: duration, mode: .alwaysFor)
        }
        return nil
    }

    private func parseEver(_ text: String) -> ExpressionAST? {
        for marker in [lexicon.grammar.traceHasEverMarker] + lexicon.grammar.traceHasEverAliasMarkers {
            guard let range = QuoteAwareScanner.rangeOfMarker(marker, in: text) else { continue }
            let subject = String(text[text.startIndex..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
            let outcome = String(text[range.upperBound...]).trimmingCharacters(in: .whitespaces)
            guard let pattern = eventPattern("\(subject) \(outcome)") else { continue }
            return .traceTemporal(TraceTemporalAST(kind: .ever(pattern)))
        }
        // Trailing alias: `has failed before` (outcome verb precedes `before`,
        // rather than an aux+adverb marker preceding the outcome verb).
        let beforeSuffix = lexicon.grammar.traceEverBeforeSuffix
        if text.lowercased().hasSuffix(beforeSuffix) {
            let stem = String(text.dropLast(beforeSuffix.count)).trimmingCharacters(in: .whitespaces)
            if let pattern = eventPattern(stem) {
                return .traceTemporal(TraceTemporalAST(kind: .ever(pattern)))
            }
        }
        return nil
    }

    private func parseWithinWindow(_ text: String) -> ExpressionAST? {
        guard let range = QuoteAwareScanner.rangeOfMarker(lexicon.grammar.traceWithinLastMarker, in: text) else { return nil }
        let before = String(text[text.startIndex..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
        let after = String(text[range.upperBound...]).trimmingCharacters(in: .whitespaces)
        guard let duration = parseLeadingDuration(after), let pattern = eventPattern(before) else { return nil }
        return .traceTemporal(TraceTemporalAST(kind: .withinWindow(pattern, duration: duration)))
    }

    private func parseCountInWindow(_ text: String) -> ExpressionAST? {
        guard let range = QuoteAwareScanner.rangeOfMarker(lexicon.grammar.traceWithinLastMarker, in: text) else { return nil }
        let before = String(text[text.startIndex..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
        let after = String(text[range.upperBound...]).trimmingCharacters(in: .whitespaces)
        guard let duration = parseLeadingDuration(after) else { return nil }

        let prefixes: [(String, (Int) -> TraceCountComparatorAST)] = [
            (lexicon.grammar.quantifierDeterminers.atLeastPrefix, TraceCountComparatorAST.atLeast),
            (lexicon.grammar.quantifierDeterminers.atMostPrefix, TraceCountComparatorAST.atMost),
            (lexicon.grammar.quantifierDeterminers.exactlyPrefix, TraceCountComparatorAST.exactly),
        ]
        for (prefix, makeComparator) in prefixes {
            let spaced = " \(prefix)"
            guard let comparatorRange = QuoteAwareScanner.rangeOfMarker(spaced, in: before) else { continue }
            let subjectPart = String(before[before.startIndex..<comparatorRange.lowerBound]).trimmingCharacters(in: .whitespaces)
            let countPart = String(before[comparatorRange.upperBound...]).trimmingCharacters(in: .whitespaces)
            guard let count = parseCountSuffix(countPart), let pattern = eventPattern(subjectPart) else { continue }
            return .traceTemporal(TraceTemporalAST(kind: .countInWindow(pattern, comparator: makeComparator(count), duration: duration)))
        }
        return nil
    }

    private func parseInARow(_ text: String) -> ExpressionAST? {
        let suffix = lexicon.grammar.traceInARowSuffix
        guard text.lowercased().hasSuffix(suffix) else { return nil }
        let stem = String(text.dropLast(suffix.count)).trimmingCharacters(in: .whitespaces)
        let tokens = stem.split(separator: " ").map(String.init)
        guard let countToken = tokens.last, let count = Int(countToken) else { return nil }
        let patternText = tokens.dropLast().joined(separator: " ")
        guard let pattern = eventPattern(patternText) else { return nil }
        return .traceTemporal(TraceTemporalAST(kind: .inARow(pattern, count: count)))
    }

    private func parseSince(_ text: String) -> ExpressionAST? {
        if let anchorFirst = parseSinceAnchorFirst(text) { return anchorFirst }
        guard let range = QuoteAwareScanner.rangeOfMarker(lexicon.grammar.traceSinceLastMarker, in: text) else { return nil }
        let lhs = String(text[text.startIndex..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
        let rhs = String(text[range.upperBound...]).trimmingCharacters(in: .whitespaces)
        let lhsPattern = eventPattern(lhs)
        if let lhsPattern, !lhsPattern.negated {
            return .malformed(
                "Use `since the last` only for a predicate that holds after an anchor event, not to express causality between two events.",
                code: .traceCausalSince,
                help: "Rewrite the left side as the state or predicate that should hold after the anchor event."
            )
        }
        guard let anchor = anchorPattern(rhs) else { return nil }
        // A holds side that is itself a (necessarily negated, per the guard
        // above) event pattern resolves directly — `no <event pattern>` —
        // rather than through the general recursive parser, which would
        // otherwise re-hit the `no`-quantifier ambiguity (cookbook 2.7).
        let holds: ExpressionAST = lhsPattern.map(ExpressionAST.eventPattern) ?? recurse(lhs)
        return .traceTemporal(TraceTemporalAST(kind: .sinceLast(anchor: anchor, holds: holds)))
    }

    /// Anchor-first `since the last E, C` (SEM-5-06, north-star flagship):
    /// `Since the last production deploy, no critical alert has occurred`.
    private func parseSinceAnchorFirst(_ text: String) -> ExpressionAST? {
        let prefix = lexicon.grammar.traceSinceLastAnchorFirstMarker
        guard text.lowercased().hasPrefix(prefix) else { return nil }
        let remainder = String(text.dropFirst(prefix.count))
        guard let commaRange = QuoteAwareScanner.rangeOfMarker(",", in: remainder) else { return nil }
        let anchorText = String(remainder[remainder.startIndex..<commaRange.lowerBound]).trimmingCharacters(in: .whitespaces)
        let holdsText = String(remainder[commaRange.upperBound...]).trimmingCharacters(in: .whitespaces)
        guard let anchor = anchorPattern(anchorText), !holdsText.isEmpty else { return nil }
        let holds: ExpressionAST = eventPattern(holdsText).map(ExpressionAST.eventPattern) ?? recurse(holdsText)
        return .traceTemporal(TraceTemporalAST(kind: .sinceLast(anchor: anchor, holds: holds)))
    }

    private func earlyDiagnostic(for text: String) -> ExpressionAST? {
        let lower = text.lowercased()
        if lower.contains("recently") {
            return .malformed(
                "`recently` is ambiguous in trace-temporal predicates.",
                code: .traceRecently,
                help: "Use an explicit duration such as `within the last 7 days`."
            )
        }
        if lower.contains(" will ") {
            return .malformed(
                "Trace-temporal predicates cannot refer to future events.",
                code: .traceFuture,
                help: "Rewrite the condition in present or past terms."
            )
        }
        if lower.contains(" is failing") || lower.contains(" is succeeding") || isProgressiveHasBeen(lower) {
            return .malformed(
                "Progressive trace event predicates are not supported.",
                code: .traceProgressive,
                help: "Use a completed event such as `failed` or `succeeded`."
            )
        }
        if isBareCausalSince(lower, rawText: text) {
            return .malformed(
                "`since` without `the last` relates two events causally, which `since the last` does not support.",
                code: .traceCausalSince,
                help: "Rewrite using `since the last <anchor event>, <condition>`, or use an ordinary `if`/`otherwise` branch."
            )
        }
        return nil
    }

    /// `has been failing`: perfect progressive, not a recorded
    /// completed event.
    private func isProgressiveHasBeen(_ lower: String) -> Bool {
        lower.contains(" has been ") && lower.hasSuffix("ing")
    }

    /// Bare causal `since`: a trace-flavored sentence (mentions
    /// a known outcome verb) using `since` without the `the last` anchor
    /// marker, e.g. `the deploy failed since the service degraded`. Scoped to
    /// outcome-verb-bearing text so ordinary non-trace prose containing
    /// "since" is never misdiagnosed.
    private func isBareCausalSince(_ lower: String, rawText: String) -> Bool {
        guard lower.contains(" since "), !lower.contains(lexicon.grammar.traceSinceLastMarker) else { return false }
        guard !lower.hasPrefix(lexicon.grammar.traceSinceLastAnchorFirstMarker) else { return false }
        return lexicon.traceOutcomeVerbs.keys.contains { lower.contains($0) }
    }

    private func looksLikeBarePerfect(_ text: String) -> Bool {
        let lower = text.lowercased()
        return lower.contains(" has ")
            && lexicon.traceOutcomeVerbs.keys.contains { lower.hasSuffix(" \($0)") }
    }

    private func parseLeadingDuration(_ text: String) -> (Double, TimeUnitAST)? {
        let pieces = text.split(separator: " ").map(String.init)
        guard pieces.count >= 2 else { return nil }
        return lexicon.parseDuration("\(pieces[0]) \(pieces[1])")
    }

    private func parseCountSuffix(_ text: String) -> Int? {
        let tokens = text.split(separator: " ").map(String.init)
        guard tokens.count >= 2, let count = Int(tokens[0]), tokens[1] == "times" else { return nil }
        return count
    }
}
