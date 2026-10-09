import Foundation

// MARK: - PhrasePatternParser

public struct PhrasePatternParser {

    public let lexicon: EnglishLexicon

    public init(lexicon: EnglishLexicon = .default) {
        self.lexicon = lexicon
    }

    /// Parse "validate an order" or "put an order on hold with a reason"
    /// into a PhrasePattern with literal and parameter segments.
    public func parse(_ text: String) -> PhrasePattern {
        let trace = ParserTrace.current
        let token = trace.push(.phraseParse, "PhrasePattern.parse: \"\(text)\"")
        defer { trace.pop(token) }

        var segments: [PatternSegment] = []
        var current = text.trimmingCharacters(in: .whitespaces)

        while !current.isEmpty {
            trace.log(.phraseParse, "loop  current=\"\(current)\"")
            // Look for parameter intro: "a {kind}", "an {kind}"
            if let (intro, rest, param) = tryParseParam(current) {
                if !intro.isEmpty {
                    trace.log(.phraseParse, "  → literal[\(intro.trimmingCharacters(in: .whitespaces))]")
                    segments.append(.literal(intro.trimmingCharacters(in: .whitespaces)))
                }
                trace.log(.phraseParse, "  → param(name=\(param.name), kind=\(param.kind))")
                segments.append(.parameter(param))
                current = rest.trimmingCharacters(in: .whitespaces)
            } else {
                trace.log(.phraseParse, "  → literal[\(current.trimmingCharacters(in: .whitespaces))] (tail)")
                segments.append(.literal(current.trimmingCharacters(in: .whitespaces)))
                current = ""
            }
        }
        let result = PhrasePattern(segments: segments.filter {
            if case .literal(let s) = $0 { return !s.isEmpty }
            return true
        })
        trace.log(.phraseParse, "= \(result.segments.map(describe).joined(separator: " · "))")
        return result
    }

    private func describe(_ s: PatternSegment) -> String {
        switch s {
        case .literal(let l):   return "L[\(l)]"
        case .parameter(let p): return "P(\(p.name):\(p.kind))"
        }
    }

    private func tryParseParam(_ s: String) -> (String, String, PhraseParameterAST)? {
        let trace = ParserTrace.current
        // Find the EARLIEST occurrence of an article-delimited parameter slot.
        // Picking the earliest is critical: in "of a customer for an amount" the
        // first parameter slot starts at "a customer", not "an amount".
        guard let (intro, afterArticle) = lexicon.findEarliestArticle(s) else {
            trace.log(.phraseParse, "tryParseParam(\"\(s)\") → no article")
            return nil
        }
        trace.log(.phraseParse, "tryParseParam: intro=\"\(intro)\" afterArticle=\"\(afterArticle)\"")

        // Extract kind name: chain consecutive nouns; stop at verbs/participles
        // or preposition connectors. No word-count cap — "email address",
        // "mailer server", "subject line", "account manager" are all valid kinds.
        //
        // Stop signals:
        //   • prepositions / conjunctions ("with", "to", "for", "by", "via" …)
        //   • participles — verbs in past or gerund form ("placed", "sent",
        //     "given", "that", "whose", "which", "using", "containing" …)
        //   • copula forms ("is", "are", "has", "have", "was", "were")
        //   • another bare article ("a", "an") that starts the next parameter
        let connectors = lexicon.prepositions.union(lexicon.copulas)
            .union(lexicon.grammar.phraseParamConnectors)
        let participles = lexicon.participles

        let words = afterArticle.components(separatedBy: " ").filter { !$0.isEmpty }
        var kindWords: [String] = []
        var remaining: [String] = []
        var paramName: String? = nil

        // Punctuation (commas, semicolons) ends a kind name — even mid-string.
        // Headers like "via a mailer server, to an email address, ..." otherwise
        // produce kindName="mailer server," which leaks the comma into the
        // parameter name.
        let kindStops = CharacterSet(charactersIn: ",;:.")

        for (idx, word) in words.enumerated() {
            let w = word.lowercased().trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
            if w == lexicon.grammar.calledIntroducer {
                paramName = words.dropFirst(idx + 1).first?
                    .trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
                remaining = Array(words.dropFirst(idx + 2))
                break
            }
            // Stop at prepositions, conjunctions, copula, participles, or
            // a new bare article (start of the next parameter slot)
            let isVerb = participles.contains(w)
                || lexicon.participleSuffixes.contains(where: { w.hasSuffix($0) && idx > 0 && w.count > 3 })
            if connectors.contains(w) || isVerb || lexicon.articles.contains(w) {
                remaining = Array(words.dropFirst(idx))
                break
            }
            // Strip trailing punctuation; if the word ENDS in punctuation,
            // that's also a kind-name terminator.
            let stripped = word.trimmingCharacters(in: kindStops)
            kindWords.append(stripped)
            // Empty words are filtered above, so `.last` is always present;
            // compare to `true` instead of `?? false` so the nil arm is not a
            // phantom coverage gap.
            let endsInPunct = word.unicodeScalars.last.map { kindStops.contains($0) } == true
            if endsInPunct {
                remaining = Array(words.dropFirst(idx + 1))
                break
            }
            if idx == words.count - 1 { remaining = [] }
        }

        let kindName = kindWords.joined(separator: " ")
        guard !kindName.isEmpty else {
            trace.log(.phraseParse, "  no kind words → reject")
            return nil
        }
        // Param name fallback: derive from the kind in camelCase
        // (`mailer server` → `mailerServer`) to keep the codegen-side
        // identifier convention consistent end-to-end.
        let name = paramName ?? IdentifierNaming.lowerCamel(kindName)
        let rest = remaining.joined(separator: " ")
        trace.log(.phraseParse, "  → kindName=\"\(kindName)\" name=\"\(name)\" rest=\"\(rest)\"")
        return (intro, rest, PhraseParameterAST(name: name, kind: kindName))
    }
}
