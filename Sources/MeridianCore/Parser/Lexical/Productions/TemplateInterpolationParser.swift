import Foundation

/// `template-conditional` / `template-loop` / `template-formatter`
/// (`GrammarTable`, `.hand-written`): the `{{ … }}` / `[if]…[otherwise]…[end
/// if]` / `[for each]…[end for]` / `as a <formatter>` text-template
/// mini-language (B6/B7).
///
/// Already a correct, well-isolated, independently-recursive state machine
/// with no parallel implementation to strangle — moved here verbatim, not
/// rewritten. A dynamic recursive-descent scan over template markers, not a
/// closed-keyword grammar `pegex` would add clarity to.
struct TemplateInterpolationParser {
    let lexicon: EnglishLexicon
    /// Recurses the full expression grammar for `{{ expr }}` holes, `[if
    /// cond]` conditions, and `[for each x in coll]` collections.
    let recurse: (String) -> ExpressionAST

    /// Parse `body` (a fenced code-block body) into a sequence of literal and
    /// expression segments delimited by `{{ … }}` markers.
    ///
    /// - `\{{` is treated as an escaped `{{` that produces a literal `{{`.
    /// - Unclosed `{{` is treated as a literal fragment to the end of the string.
    func parseSegments(_ body: String) -> [InterpolationSegment] {
        parseTemplateSegments(body).segments
    }

    /// Rewrite a bare `it`/`its` pronoun inside a `{{ … }}` hole, `[if …]`
    /// condition, or nested `[for each … in …]` collection expression to the
    /// enclosing `[for each <var> in …]` loop's own variable — the same
    /// whole-word text substitution `DefinitionParser.rewriteSubjectPronouns`
    /// applies to a `Definition:` body's implicit subject, reused here so
    /// `{{ its name }}` inside a template loop resolves to `<var>'s name`
    /// (a possessive property access on the loop element) instead of
    /// silently parsing as the unrelated bare identifier `its name`. The
    /// nearest (innermost) enclosing `[for each]` wins, matching natural-
    /// language nearest-binding pronoun resolution.
    private func rewritePronoun(_ text: String, subject: String?) -> String {
        guard let subject else { return text }
        var out = WholeWordRegex.replace(text, of: lexicon.grammar.definitionPossessivePronoun, with: subject + "'s")
        out = WholeWordRegex.replace(out, of: lexicon.grammar.definitionSubjectPronoun, with: subject)
        return out
    }

    private func parseTemplateSegments(
        _ body: String, terminators: Set<String> = [], pronounSubject: String? = nil
    ) -> (segments: [InterpolationSegment], terminator: String?, rest: String) {
        var segments: [InterpolationSegment] = []
        var remaining = body

        while !remaining.isEmpty {
            let remainingLower = remaining.lowercased()
            if let term = terminators.first(where: { remainingLower.hasPrefix($0) }) {
                return (segments, term, String(remaining.dropFirst(term.count)))
            }

            let template = lexicon.grammar.templateDirectives
            let markers = [
                "{{",
                template.ifPrefix,
                template.otherwiseTerminator,
                template.endIfTerminator,
                template.forEachPrefix,
                template.endForTerminator,
            ]
            let next = markers.compactMap { marker -> (String, Range<String.Index>)? in
                remaining.range(of: marker, options: marker == "{{" ? [] : [.caseInsensitive]).map { (marker, $0) }
            }.min { $0.1.lowerBound < $1.1.lowerBound }

            guard let (marker, range) = next else {
                segments.append(.literal(remaining))
                return (segments, nil, "")
            }

            let prefix = String(remaining[remaining.startIndex..<range.lowerBound])
            if terminators.contains(marker) {
                if !prefix.isEmpty { segments.append(.literal(prefix)) }
                return (segments, marker, String(remaining[range.upperBound...]))
            }
            if marker == "{{", prefix.hasSuffix("\\") {
                segments.append(.literal(String(prefix.dropLast()) + "{{"))
                remaining = String(remaining[range.upperBound...])
                continue
            }
            if !prefix.isEmpty { segments.append(.literal(prefix)) }
            remaining = String(remaining[range.lowerBound...])
            let lower = remaining.lowercased()

            if lower.hasPrefix("{{") {
                guard let close = remaining.range(of: "}}") else {
                    segments.append(.literal(remaining)); return (segments, nil, "")
                }
                let exprText = rewritePronoun(
                    String(remaining[remaining.index(remaining.startIndex, offsetBy: 2)..<close.lowerBound])
                        .trimmingCharacters(in: .whitespacesAndNewlines),
                    subject: pronounSubject
                )
                if !exprText.isEmpty {
                    if let formatted = parseFormattedInterpolation(exprText) {
                        segments.append(.formatted(formatted.expr, formatter: formatted.formatter))
                    } else {
                        segments.append(.expression(recurse(exprText)))
                    }
                }
                remaining = String(remaining[close.upperBound...])
                continue
            }

            if lower.hasPrefix(template.ifPrefix) {
                guard let close = remaining.firstIndex(of: "]") else {
                    segments.append(.literal(remaining)); return (segments, nil, "")
                }
                let condText = rewritePronoun(
                    String(remaining[remaining.index(remaining.startIndex, offsetBy: template.ifPrefix.count)..<close])
                        .trimmingCharacters(in: .whitespacesAndNewlines),
                    subject: pronounSubject
                )
                let tail = String(remaining[remaining.index(after: close)...])
                let thenParsed = parseTemplateSegments(
                    tail, terminators: [template.otherwiseTerminator, template.endIfTerminator], pronounSubject: pronounSubject
                )
                let elseParsed: (segments: [InterpolationSegment], terminator: String?, rest: String)
                if thenParsed.terminator == template.otherwiseTerminator {
                    elseParsed = parseTemplateSegments(thenParsed.rest, terminators: [template.endIfTerminator], pronounSubject: pronounSubject)
                } else {
                    elseParsed = ([], nil, thenParsed.rest)
                }
                segments.append(.conditional(condition: recurse(condText), then: thenParsed.segments, otherwise: elseParsed.segments))
                remaining = elseParsed.rest
                continue
            }

            if lower.hasPrefix(template.forEachPrefix) {
                guard let close = remaining.firstIndex(of: "]") else {
                    segments.append(.literal(remaining)); return (segments, nil, "")
                }
                let header = String(remaining[remaining.index(remaining.startIndex, offsetBy: template.forEachPrefix.count)..<close])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                let parts = splitForEachHeader(header)
                let collectionText = rewritePronoun(parts.collection, subject: pronounSubject)
                let tail = String(remaining[remaining.index(after: close)...])
                let bodyParsed = parseTemplateSegments(tail, terminators: [template.endForTerminator], pronounSubject: parts.variable)
                segments.append(.forEach(variable: parts.variable, collection: recurse(collectionText), body: bodyParsed.segments))
                remaining = bodyParsed.rest
                continue
            }

            segments.append(.literal(marker))
            remaining = String(remaining.dropFirst(marker.count))
        }

        return (segments, nil, "")
    }

    private func parseFormattedInterpolation(_ text: String) -> (expr: ExpressionAST, formatter: String)? {
        let marker = lexicon.grammar.templateDirectives.formatAsMarker
        guard let range = text.range(of: marker, options: [.caseInsensitive]) else { return nil }
        let expr = String(text[text.startIndex..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
        let formatter = String(text[range.upperBound...]).trimmingCharacters(in: .whitespaces)
        guard !expr.isEmpty, !formatter.isEmpty else { return nil }
        return (recurse(expr), formatter)
    }

    private func splitForEachHeader(_ header: String) -> (variable: String, collection: String) {
        if let range = header.range(of: lexicon.grammar.templateDirectives.loopInMarker, options: [.caseInsensitive]) {
            let variable = String(header[header.startIndex..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
            let collection = String(header[range.upperBound...]).trimmingCharacters(in: .whitespaces)
            return (variable.isEmpty ? "item" : variable, collection)
        }
        return ("item", header)
    }
}
