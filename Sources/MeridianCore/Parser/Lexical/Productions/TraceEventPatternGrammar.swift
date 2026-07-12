import Foundation

struct TraceEventPatternGrammar {
    let lexicon: EnglishLexicon
    let atom: (String) -> ExpressionAST

    /// Strict form: requires an explicit outcome verb (or `occurred`).
    /// Used for `ever`/`within the last`/`times in a row`/`since`-holds and
    /// the causal-since guard.
    func parse(_ raw: String) -> EventPatternAST? {
        parse(raw, allowBareAnchor: false)
    }

    /// Anchor-position resolution (`since the last <anchor>`): same as
    /// `parse`, but a subject with no explicit outcome verb defaults to
    /// generic completion (`.occurred`) — the kind-flavored anchor reading
    /// SEM-5-06 / cookbook 18.5's `since the last production deploy` needs.
    func parseAnchor(_ raw: String) -> EventPatternAST? {
        parse(raw, allowBareAnchor: true)
    }

    private func parse(_ raw: String, allowBareAnchor: Bool) -> EventPatternAST? {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }

        // Event negation `no <event pattern>` (cookbook 2.7/18.5, north-star
        // flagship). Distinct fixed shape from the `no`-quantifier and the
        // `has no <noun>` emptiness marker — this is a leading-position strip
        // on text already routed here as an event-pattern candidate by the
        // caller (since-holds / anchor), so it never competes with those.
        var negated = false
        let negationPrefix = lexicon.grammar.traceEventNegationPrefix
        if text.lowercased().hasPrefix(negationPrefix) {
            negated = true
            text = String(text.dropFirst(negationPrefix.count)).trimmingCharacters(in: .whitespaces)
        }
        guard !text.isEmpty else { return nil }

        let outcomes = lexicon.traceOutcomeVerbs.keys.sorted { $0.count > $1.count }
        for marker in outcomes {
            let spaced = " \(marker) "
            if let range = QuoteAwareScanner.rangeOfMarker(spaced, in: text) {
                let subjectText = String(text[text.startIndex..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
                let tail = String(text[range.upperBound...]).trimmingCharacters(in: .whitespaces)
                guard tail.isEmpty, let outcome = lexicon.traceOutcomeVerbs[marker] else { continue }
                if let pattern = makePattern(subjectText, outcome: outcome, negated: negated) { return pattern }
                continue
            }
            let suffix = " \(marker)"
            if text.lowercased().hasSuffix(suffix),
               let outcome = lexicon.traceOutcomeVerbs[marker] {
                let subjectText = String(text.dropLast(suffix.count)).trimmingCharacters(in: .whitespaces)
                guard !subjectText.isEmpty else { continue }
                if let pattern = makePattern(subjectText, outcome: outcome, negated: negated) { return pattern }
                continue
            }
        }
        guard allowBareAnchor else { return nil }
        return makePattern(text, outcome: .occurred, negated: negated)
    }

    /// Split a subject-position clause on the first top-level ` whose ` into
    /// the bare subject and a payload predicate (cookbook 17), reusing
    /// `ComparisonGrammar`/`atom` rather than a new expression scanner (Wave 5
    /// grammar-table norm). Then strips the trailing perfect/passive auxiliary
    /// and resolves the step/skill/named subject shape.
    private func makePattern(_ subjectText: String, outcome: EventPatternAST.OutcomeVerb, negated: Bool) -> EventPatternAST? {
        // A trailing perfect/passive auxiliary (`was`/`has`/…) left over after
        // the outcome verb was stripped sits at the END of the whole clause —
        // *after* a `whose …` payload predicate's value when one is present
        // (`slack.send whose channel is "#incidents" was` → the aux is on
        // `was`, not glued to `slack.send`). It must be stripped from the full
        // text before `splitPayloadPredicate` divides subject from predicate,
        // or it gets swallowed into the predicate's value text instead (e.g.
        // a quoted-string RHS growing a bogus `"#incidents" was` suffix).
        let cleanedText = Self.stripTrailingAuxiliaries(subjectText, lexicon: lexicon)
        guard let (subjectPart, payloadPredicate) = Self.splitPayloadPredicate(cleanedText, lexicon: lexicon, atom: atom) else { return nil }
        let subject = Self.parseSubject(subjectPart, lexicon: lexicon)
        return EventPatternAST(subject: subject, outcome: outcome, payloadPredicate: payloadPredicate, negated: negated)
    }

    /// Split a subject-position clause on the first top-level ` whose ` into
    /// the bare subject and a payload predicate (cookbook 17), reusing
    /// `ComparisonGrammar`/`atom` rather than a new expression scanner (Wave 5
    /// grammar-table norm). Shared with `TraceStatisticalGrammar`, whose
    /// subject clause has the identical `whose` shape.
    static func splitPayloadPredicate(
        _ subjectText: String, lexicon: EnglishLexicon, atom: @escaping (String) -> ExpressionAST
    ) -> (subject: String, payloadPredicate: ExpressionAST?)? {
        var subjectPart = subjectText
        var payloadPredicate: ExpressionAST?
        let whoseMarker = lexicon.grammar.iterationMarkers.whoseMarker
        if let whoseRange = QuoteAwareScanner.rangeOfMarker(whoseMarker, in: subjectPart, caseInsensitive: true) {
            let predicateText = String(subjectPart[whoseRange.upperBound...]).trimmingCharacters(in: .whitespaces)
            subjectPart = String(subjectPart[subjectPart.startIndex..<whoseRange.lowerBound]).trimmingCharacters(in: .whitespaces)
            guard !predicateText.isEmpty else { return nil }
            payloadPredicate = ComparisonGrammar(lexicon: lexicon, atom: atom).parse(predicateText) ?? atom(predicateText)
        }
        guard !subjectPart.isEmpty else { return nil }
        return (subjectPart, payloadPredicate)
    }

    static func parseSubject(_ raw: String, lexicon: EnglishLexicon) -> EventPatternAST.Subject {
        var stripped = lexicon.stripLeadingArticle(raw).trimmingCharacters(in: .whitespaces)
        stripped = stripTrailingAuxiliaries(stripped, lexicon: lexicon)
        let lower = stripped.lowercased()

        // Skill-scoped step: `the fetch step of the briefing skill` (cookbook
        // 17). Parsed (not silently folded into `.named`) so lowering can
        // raise a precise cross-skill-scope diagnostic (D4) instead.
        if lower.hasSuffix(" skill"),
           let ofRange = QuoteAwareScanner.rangeOfMarker(" of the ", in: stripped, caseInsensitive: true) {
            let stepPart = String(stripped[stripped.startIndex..<ofRange.lowerBound]).trimmingCharacters(in: .whitespaces)
            var skillPart = String(stripped[ofRange.upperBound...]).trimmingCharacters(in: .whitespaces)
            if skillPart.lowercased().hasSuffix(" skill") {
                skillPart = String(skillPart.dropLast(" skill".count)).trimmingCharacters(in: .whitespaces)
                let stepLower = stepPart.lowercased()
                let stepName = stepLower.hasSuffix(" step")
                    ? String(stepPart.dropLast(" step".count)).trimmingCharacters(in: .whitespaces)
                    : stepPart
                if !skillPart.isEmpty && !stepName.isEmpty {
                    return .stepOfSkill(step: stepName, skill: skillPart)
                }
            }
        }

        if lower.hasSuffix(" step") {
            let name = String(stripped.dropLast(" step".count)).trimmingCharacters(in: .whitespaces)
            return .step(name.isEmpty ? stripped : name)
        }
        return .named(stripped)
    }

    /// Strip a trailing perfect/passive auxiliary (`has`/`have`/`had`/`was`/
    /// `were`/`been`) left glued to the subject after the outcome verb was
    /// already removed — e.g. `the deploy step has` (from `the deploy step
    /// has failed within the last 7 days`) must resolve to `.step("deploy")`,
    /// not `.named("deploy step has")`. Looped for chained auxiliaries such as
    /// `slack.send whose channel is "#incidents" was` -> `was` alone.
    private static func stripTrailingAuxiliaries(_ text: String, lexicon: EnglishLexicon) -> String {
        var result = text
        let auxiliaries = lexicon.tracePerfectAuxiliaries.sorted { $0.count > $1.count }
        var changed = true
        while changed {
            changed = false
            let lower = result.lowercased()
            for aux in auxiliaries {
                let suffix = " \(aux)"
                guard lower != aux, lower.hasSuffix(suffix) else { continue }
                result = String(result.dropLast(suffix.count)).trimmingCharacters(in: .whitespaces)
                changed = true
                break
            }
        }
        return result
    }
}
