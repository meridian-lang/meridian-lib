import Foundation

struct TraceStatisticalGrammar {
    let lexicon: EnglishLexicon
    let atom: (String) -> ExpressionAST

    func parse(_ raw: String) -> ExpressionAST? {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        if let diagnostic = earlyDiagnostic(for: text) {
            return diagnostic
        }
        if let scoped = parseScoped(text) {
            return scoped
        }
        return parseUnscoped(text)
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
                guard !skills.isEmpty, !body.isEmpty, case .traceStatistical(let statistical)? = parseUnscoped(body) else { continue }
                return .traceStatistical(TraceStatisticalAST(
                    scope: .acrossSkills(skills),
                    pattern: statistical.pattern,
                    outcome: statistical.outcome,
                    bound: statistical.bound,
                    denominator: statistical.denominator,
                    window: statistical.window,
                    monitorCadence: statistical.monitorCadence,
                    blocking: statistical.blocking,
                    confidencePercent: statistical.confidencePercent
                ))
            }
            return nil
        }
        let marker = lexicon.grammar.traceAcrossAllRunsMarker
        guard text.lowercased().hasPrefix(marker) else { return nil }
        let remainder = String(text.dropFirst(marker.count)).trimmingCharacters(in: .whitespaces)
        guard case .traceStatistical(let statistical)? = parseUnscoped(remainder) else { return nil }
        return .traceStatistical(TraceStatisticalAST(
            scope: .acrossAllRuns,
            pattern: statistical.pattern,
            outcome: statistical.outcome,
            bound: statistical.bound,
            denominator: statistical.denominator,
            window: statistical.window,
            monitorCadence: statistical.monitorCadence,
            blocking: statistical.blocking,
            confidencePercent: statistical.confidencePercent
        ))
    }

    private func parseUnscoped(_ text: String) -> ExpressionAST? {
        var working = text
        var blocking = false
        if working.lowercased().hasSuffix(lexicon.grammar.traceStatisticalBlockingSuffix) {
            working = String(working.dropLast(lexicon.grammar.traceStatisticalBlockingSuffix.count))
                .trimmingCharacters(in: .whitespaces)
            blocking = true
        }

        var confidence: Double?
        if let confidenceValue = parseConfidenceSuffix(&working) {
            confidence = confidenceValue
        }

        var cadence: (Double, TimeUnitAST)?
        if let cadenceRange = QuoteAwareScanner.rangeOfMarker(lexicon.grammar.traceStatisticalCheckedEveryMarker, in: working) {
            let cadenceText = String(working[cadenceRange.upperBound...]).trimmingCharacters(in: .whitespaces)
            guard let parsedCadence = lexicon.parseDuration(cadenceText) else { return nil }
            cadence = parsedCadence
            working = String(working[..<cadenceRange.lowerBound]).trimmingCharacters(in: .whitespaces)
        }

        var window: (Double, TimeUnitAST)?
        if let windowRange = QuoteAwareScanner.rangeOfMarker(lexicon.grammar.traceWithinLastMarker, in: working) {
            let durationText = String(working[windowRange.upperBound...]).trimmingCharacters(in: .whitespaces)
            guard let parsedWindow = lexicon.parseDuration(durationText) else { return nil }
            window = parsedWindow
            working = String(working[..<windowRange.lowerBound]).trimmingCharacters(in: .whitespaces)
        }

        if let parsed = parseUsuallyRarely(working) {
            return .traceStatistical(TraceStatisticalAST(
                pattern: parsed.pattern,
                outcome: parsed.outcome,
                bound: parsed.bound,
                denominator: .runs,
                window: window,
                monitorCadence: cadence,
                blocking: blocking,
                confidencePercent: confidence
            ))
        }

        if let parsed = parseNumeric(working) {
            return .traceStatistical(TraceStatisticalAST(
                pattern: parsed.pattern,
                outcome: parsed.outcome,
                bound: parsed.bound,
                denominator: parsed.denominator,
                window: window,
                monitorCadence: cadence,
                blocking: blocking,
                confidencePercent: confidence
            ))
        }

        return nil
    }

    private func parseUsuallyRarely(_ text: String) -> (pattern: TraceStatisticalPatternAST, outcome: TraceStatisticalOutcomeAST, bound: TraceStatisticalBoundAST)? {
        let variants: [(String, TraceStatisticalBoundAST)] = [
            (lexicon.grammar.traceStatisticalUsuallyMarker, .usually),
            (lexicon.grammar.traceStatisticalRarelyMarker, .rarely),
        ]
        for (marker, bound) in variants {
            guard let range = QuoteAwareScanner.rangeOfMarker(marker, in: text) else { continue }
            let subjectText = String(text[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
            let outcomeText = String(text[range.upperBound...]).trimmingCharacters(in: .whitespaces)
            guard let (pattern, outcome) = parseSubjectAndOutcome(subject: subjectText, outcome: outcomeText) else { continue }
            return (pattern, outcome, bound)
        }
        return nil
    }

    private func parseNumeric(_ text: String) -> (pattern: TraceStatisticalPatternAST, outcome: TraceStatisticalOutcomeAST, bound: TraceStatisticalBoundAST, denominator: TraceStatisticalDenominatorAST)? {
        let variants: [(String, (Double) -> TraceStatisticalBoundAST)] = [
            (lexicon.grammar.traceStatisticalAtLeastMarker, TraceStatisticalBoundAST.atLeast),
            (lexicon.grammar.traceStatisticalAtMostMarker, TraceStatisticalBoundAST.atMost),
        ]
        for (marker, makeBound) in variants {
            guard let range = QuoteAwareScanner.rangeOfMarker(marker, in: text) else { continue }
            let lhs = String(text[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
            let rhs = String(text[range.upperBound...]).trimmingCharacters(in: .whitespaces)
            guard
                let (pattern, outcome) = parseSubjectAndOutcomePrefix(lhs),
                let percentRange = QuoteAwareScanner.rangeOfMarker(lexicon.grammar.traceStatisticalPercentOfMarker, in: rhs)
            else {
                continue
            }

            let percentText = String(rhs[..<percentRange.lowerBound]).trimmingCharacters(in: .whitespaces)
            let denominatorText = String(rhs[percentRange.upperBound...]).trimmingCharacters(in: .whitespaces).lowercased()
            guard let ratio = parseRatio(percentText) else { continue }
            let denominator: TraceStatisticalDenominatorAST
            switch denominatorText {
            case lexicon.grammar.traceStatisticalRunsWord:
                denominator = .runs
            case lexicon.grammar.traceStatisticalOccurrencesWord:
                denominator = .occurrences
            default:
                continue
            }
            return (pattern, outcome, makeBound(ratio), denominator)
        }
        return nil
    }

    private func parseSubjectAndOutcome(
        subject: String,
        outcome: String
    ) -> (TraceStatisticalPatternAST, TraceStatisticalOutcomeAST)? {
        guard !subject.isEmpty else { return nil }
        let lowerOutcome = outcome.lowercased()
        if lowerOutcome == lexicon.grammar.traceStatisticalSuccessKeyword {
            return makeStatisticalPattern(subject).map { ($0, .succeeds) }
        }
        if lowerOutcome == lexicon.grammar.traceStatisticalFailureKeyword {
            return makeStatisticalPattern(subject).map { ($0, .fails) }
        }
        return nil
    }

    private func parseSubjectAndOutcomePrefix(_ text: String) -> (TraceStatisticalPatternAST, TraceStatisticalOutcomeAST)? {
        let lower = text.lowercased()
        let successSuffix = " " + lexicon.grammar.traceStatisticalSuccessKeyword
        if lower.hasSuffix(successSuffix) {
            let subject = String(text.dropLast(successSuffix.count)).trimmingCharacters(in: .whitespaces)
            guard !subject.isEmpty else { return nil }
            return makeStatisticalPattern(subject).map { ($0, .succeeds) }
        }
        let failureSuffix = " " + lexicon.grammar.traceStatisticalFailureKeyword
        if lower.hasSuffix(failureSuffix) {
            let subject = String(text.dropLast(failureSuffix.count)).trimmingCharacters(in: .whitespaces)
            guard !subject.isEmpty else { return nil }
            return makeStatisticalPattern(subject).map { ($0, .fails) }
        }
        return nil
    }

    /// `whose <field> is <value>` on a statistical subject (cookbook 17;
    /// `TraceStatisticalPatternAST.payloadPredicate` was declared but never
    /// populated before this workstream). Shares the split with
    /// `TraceEventPatternGrammar`.
    private func makeStatisticalPattern(_ subjectText: String) -> TraceStatisticalPatternAST? {
        guard let (subjectPart, payloadPredicate) = TraceEventPatternGrammar.splitPayloadPredicate(subjectText, lexicon: lexicon, atom: atom) else {
            return nil
        }
        let subject = TraceEventPatternGrammar.parseSubject(subjectPart, lexicon: lexicon)
        return TraceStatisticalPatternAST(subject: subject, payloadPredicate: payloadPredicate)
    }

    private func parseRatio(_ text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        let stripped = trimmed.hasSuffix("%") ? String(trimmed.dropLast()) : trimmed
        guard let numeric = Double(stripped) else { return nil }
        return numeric > 1 ? numeric / 100.0 : numeric
    }

    private func parseConfidenceSuffix(_ text: inout String) -> Double? {
        let marker = lexicon.grammar.traceStatisticalWithConfidenceMarker
        let suffix = lexicon.grammar.traceStatisticalConfidenceSuffix
        guard let range = QuoteAwareScanner.rangeOfMarker(marker, in: text) else { return nil }
        let tail = String(text[range.upperBound...]).trimmingCharacters(in: .whitespaces)
        guard tail.lowercased().hasSuffix(suffix) else { return nil }
        let percentText = String(tail.dropLast(suffix.count)).trimmingCharacters(in: .whitespaces)
        guard let value = Double(percentText.replacingOccurrences(of: "%", with: "").trimmingCharacters(in: .whitespaces)) else {
            return nil
        }
        text = String(text[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
        return value
    }

    private func earlyDiagnostic(for text: String) -> ExpressionAST? {
        let lower = text.lowercased()
        if lower.contains(lexicon.grammar.traceStatisticalMostOfTimePhrase) {
            return .malformed(
                "`most of the time` is intentionally unsupported in statistical predicates.",
                code: .statisticalVagueFrequency,
                help: "Use an explicit percentage or the fixed `usually` / `rarely` forms."
            )
        }
        return nil
    }
}
