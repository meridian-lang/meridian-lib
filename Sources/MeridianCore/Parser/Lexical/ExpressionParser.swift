import Foundation

// MARK: - ExpressionParser
//
// Parses a single-line expression string into ExpressionAST.
// Called from MerConfigParser and MeridianParser when an expression is needed.
//
// Supported forms:
//   Literals:        "USD", 42, 3.14, $5000, 1 hour, true/false, now
//   Property chains: the order's id, the customer's account manager's id
//   Identifiers:     order, risk, retry count (multi-word)
//   Instance refs:   the stripe, the primary mailer  (resolved via symbol table)
//   Constant refs:   the high value threshold         (resolved via symbol table)
//   Comparisons:     X is Y, X is more than Y, X is less than Y,
//                    X is greater than Y, X is not Y, X is within Y
//   Conjunctions:    X and Y, X or Y, not X

public struct ExpressionParser {

    public let symbols: SymbolTable?
    public let trace: ParserTrace
    private let lexicon: EnglishLexicon

    public init(symbols: SymbolTable? = nil, trace: ParserTrace = .shared,
                lexicon: EnglishLexicon = .default) {
        self.symbols = symbols
        self.trace = trace
        self.lexicon = lexicon
    }

    public func parse(_ raw: String) -> ExpressionAST {
        let s = raw.trimmingCharacters(in: .whitespaces)
        let result = parseLogical(s)
        trace.log(.expression, "parse(\"\(s)\") → \(describe(result))")
        return result
    }

    private func describe(_ e: ExpressionAST) -> String {
        switch e {
        case .literal(.string(let s)):     return "\"\(s)\""
        case .literal(.integer(let n)):    return "\(n)"
        case .literal(.double(let d)):     return "\(d)"
        case .literal(.boolean(let b)):    return "\(b)"
        case .literal(.money(let a, let c)): return "$\(a)\(c)"
        case .literal(.duration(let v, let u)): return "\(v) \(u)"
        case .literal:                     return "lit"
        case .identifierRef(let n):        return "id(\(n))"
        case .instanceRef(let n):          return "inst(\(n))"
        case .constantRef(let n):          return "const(\(n))"
        case .propertyAccess(let b, let p):return "\(describe(b)).\(p)"
        case .comparison(let l, let op, let r): return "(\(describe(l)) \(op) \(describe(r)))"
        case .logical(let op, let xs):     return "logical(\(op), [\(xs.map { describe($0) }.joined(separator: ", "))])"
        case .invoke(let tool, _):         return "invoke(\(tool))"
        case .envVar(let n):               return "$\(n)"
        case .now:                         return "now"
        case .decideWhether(let q):        return "decide(\(q))"
        case .interpolatedString(let segs): return "interp(\(segs.count) segs)"
        }
    }

    // MARK: - Logical operators (lowest precedence: or < and < not < comparison)

    private func parseLogical(_ s: String) -> ExpressionAST {
        // Split on top-level " or " first (lower precedence)
        if let orParts = splitTopLevel(s, on: " or ") {
            let operands = orParts.map { parseAnd($0) }
            return operands.count == 1 ? operands[0] : .logical(.or, operands)
        }
        return parseAnd(s)
    }

    private func parseAnd(_ s: String) -> ExpressionAST {
        if let andParts = splitTopLevel(s, on: " and ") {
            let operands = andParts.map { parseNot($0) }
            return operands.count == 1 ? operands[0] : .logical(.and, operands)
        }
        return parseNot(s)
    }

    private func parseNot(_ s: String) -> ExpressionAST {
        let t = s.trimmingCharacters(in: .whitespaces)
        if t.lowercased().hasPrefix("not ") {
            let inner = parseNot(String(t.dropFirst(4)))
            return .logical(.not, [inner])
        }
        return parseComparison(t)
    }

    /// Split `s` on `separator` but only outside quoted regions.
    /// Returns nil if no outside-quotes separator found (single-element).
    private func splitTopLevel(_ s: String, on sep: String) -> [String]? {
        var parts: [String] = []
        var remaining = s
        var found = false
        while let r = rangeOfMarkerOutsideQuotes(sep, in: remaining) {
            parts.append(String(remaining[remaining.startIndex..<r.lowerBound])
                .trimmingCharacters(in: .whitespaces))
            remaining = String(remaining[r.upperBound...])
                .trimmingCharacters(in: .whitespaces)
            found = true
        }
        guard found else { return nil }
        parts.append(remaining.trimmingCharacters(in: .whitespaces))
        return parts
    }

    // MARK: - Comparison

    private func parseComparison(_ s: String) -> ExpressionAST {
        for (marker, op) in lexicon.comparisonMarkers {
            if let (lhs, rhs) = split(s, around: [marker]) {
                return .comparison(parseAtom(lhs), op, parseAtom(rhs))
            }
        }
        return parseAtom(s)
    }

    // MARK: - Atom

    func parseAtom(_ s: String) -> ExpressionAST {
        let t = s.trimmingCharacters(in: .whitespaces)
        if t.isEmpty { return .literal(.string("")) }

        // B6/B7: Fenced code-block sentinel — decode base64 body, then parse
        // for `{{ expr }}` interpolation markers (B7).
        if t.hasPrefix(codeBlockSentinelPrefix) {
            let rest = String(t.dropFirst(codeBlockSentinelPrefix.count))
            // Format after prefix: "<lang>:<base64-body>"
            if let colonIdx = rest.firstIndex(of: ":") {
                let b64 = String(rest[rest.index(after: colonIdx)...])
                if let data = Data(base64Encoded: b64),
                   let body = String(data: data, encoding: .utf8) {
                    if body.contains("{{") {
                        let segs = parseInterpolationSegments(body)
                        // Collapse a single literal-only segment to a plain string literal.
                        if segs.count == 1, case .literal(let plain) = segs[0] {
                            return .literal(.string(plain))
                        }
                        return .interpolatedString(segs)
                    }
                    return .literal(.string(body))
                }
            }
            return .literal(.string(""))
        }

        // now
        if t == "now" { return .now }

        // env var
        if t.hasPrefix("$") { return .envVar(String(t.dropFirst())) }

        // boolean
        if t == "true"  { return .literal(.boolean(true)) }
        if t == "false" { return .literal(.boolean(false)) }

        // quoted string
        if (t.hasPrefix("\"") && t.hasSuffix("\"")) ||
           (t.hasPrefix("'")  && t.hasSuffix("'")) {
            let inner = String(t.dropFirst().dropLast())
            return .literal(.string(inner))
        }

        // money  "$5000", "$99.95"
        if t.hasPrefix("$"), let amount = Double(t.dropFirst()) {
            return .literal(.money(amount, currency: "USD"))
        }

        // duration  "1 hour", "30 days", "3600 seconds"
        if let dur = parseDuration(t) { return .literal(.duration(dur.0, dur.1)) }

        // float
        if let d = Double(t), t.contains(".") { return .literal(.double(d)) }

        // integer
        if let n = Int(t) { return .literal(.integer(n)) }

        // possessive chain: "the customer's account manager's email" — also
        // handles bare possessives like "order's id" (after text substitution
        // strips the leading article).
        let hasArticlePrefix = lexicon.articles.sorted(by: { $0.count > $1.count })
            .contains { t.lowercased().hasPrefix($0 + " ") }
        if hasArticlePrefix
            || t.contains("'s ")
            || t.hasSuffix("'s")
        {
            return parsePossessiveChain(t)
        }

        // bare identifier / enum value (e.g. "invalid", "denied", "succeeded")
        return .identifierRef(t)
    }

    // MARK: - Possessive chain

    func parsePossessiveChain(_ s: String) -> ExpressionAST {
        // Strip article then split on "'s"
        var stripped = s
        for article in lexicon.articles.sorted(by: { $0.count > $1.count }) {
            if stripped.lowercased().hasPrefix(article + " ") {
                stripped = String(stripped.dropFirst(article.count + 1))
                break
            }
        }

        let parts = stripped.components(separatedBy: "'s")
        guard !parts.isEmpty else { return .identifierRef(stripped) }

        let base = parts[0].trimmingCharacters(in: .whitespaces)

        // Resolve base: instance, constant, or identifier
        var expr: ExpressionAST = resolveBase(base)

        // Traverse property accesses
        for part in parts.dropFirst() {
            let prop = part.trimmingCharacters(in: .whitespaces)
            if !prop.isEmpty {
                expr = .propertyAccess(expr, prop)
            }
        }
        return expr
    }

    private func resolveBase(_ name: String) -> ExpressionAST {
        if let sym = symbols {
            if sym.instances[name] != nil    { return .instanceRef(name) }
            if sym.constants[name] != nil    { return .constantRef(name) }
        }
        return .identifierRef(name)
    }

    // MARK: - B7 interpolation segment parsing

    /// Parse `body` (a fenced code-block body) into a sequence of literal and
    /// expression segments delimited by `{{ … }}` markers.
    ///
    /// - `\{{` is treated as an escaped `{{` that produces a literal `{{`.
    /// - Unclosed `{{` is treated as a literal fragment to the end of the string.
    func parseInterpolationSegments(_ body: String) -> [InterpolationSegment] {
        var segments: [InterpolationSegment] = []
        var remaining = body
        while let openRange = remaining.range(of: "{{") {
            let prefix = String(remaining[remaining.startIndex..<openRange.lowerBound])
            // \{{ — escaped open marker
            if prefix.hasSuffix("\\") {
                segments.append(.literal(String(prefix.dropLast()) + "{{"))
                remaining = String(remaining[openRange.upperBound...])
                continue
            }
            if !prefix.isEmpty { segments.append(.literal(prefix)) }
            remaining = String(remaining[openRange.upperBound...])
            guard let closeRange = remaining.range(of: "}}") else {
                // No matching close — treat the rest as a literal.
                segments.append(.literal("{{" + remaining))
                remaining = ""
                break
            }
            let exprText = String(remaining[remaining.startIndex..<closeRange.lowerBound])
                .trimmingCharacters(in: .whitespaces)
            segments.append(.expression(parse(exprText)))
            remaining = String(remaining[closeRange.upperBound...])
        }
        if !remaining.isEmpty { segments.append(.literal(remaining)) }
        return segments
    }

    // MARK: - Duration parsing

    private func parseDuration(_ s: String) -> (Double, TimeUnitAST)? {
        lexicon.parseDuration(s)
    }

    // MARK: - Helpers

    private func split(_ s: String, around markers: [String]) -> (String, String)? {
        // Find the marker only in *unquoted* regions of `s`. Splitting inside a
        // string literal — e.g. `"Your order is on hold"` — would otherwise
        // chop the literal at " is ".
        let lower = s.lowercased()
        for marker in markers {
            let needle = " \(marker) "
            if let r = rangeOfMarkerOutsideQuotes(needle, in: lower) {
                let lhs = String(s[s.startIndex ..< r.lowerBound]).trimmingCharacters(in: .whitespaces)
                let rhs = String(s[r.upperBound...]).trimmingCharacters(in: .whitespaces)
                return (lhs, rhs)
            }
        }
        return nil
    }

    private func rangeOfMarkerOutsideQuotes(_ marker: String, in s: String) -> Range<String.Index>? {
        var i = s.startIndex
        var inString = false
        while i < s.endIndex {
            let c = s[i]
            if c == "\"" { inString.toggle(); i = s.index(after: i); continue }
            if !inString {
                let end = s.index(i, offsetBy: marker.count, limitedBy: s.endIndex) ?? s.endIndex
                if end > s.endIndex { break }
                if s[i..<end] == Substring(marker) {
                    return i..<end
                }
            }
            i = s.index(after: i)
        }
        return nil
    }
}
