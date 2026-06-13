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

/// Sentinel marking a protected `either … or …` group (base64-encoded body
/// follows). Lives in the private-use area so it can never collide with source.
let eitherSentinelPrefix = "\u{E001}either:"

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
        // 2A: normalise `, and`/`, or` to plain joins, then bracket any
        // `either … or …` group into an opaque sentinel so the boolean splitter
        // sees it as a single operand.
        let prepared = protectEitherGroups(normalizeBooleanCommas(s))
        let result = parseLogical(prepared)
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
        case .recordList(let f, let rows):  return "recordList(\(f.count) fields, \(rows.count) rows)"
        case .quantified(let q):           return "quant(\(q.kind), \(q.description.noun))"
        case .verbPredicate(let s, let v, let o): return "verb(\(describe(s)) \(v) \(describe(o)))"
        case .relationTraversal(let b, let r, _): return "rel(\(describe(b)) ~ \(r))"
        case .description(let d):          return "desc(\(d.noun))"
        case .aggregate(let k, let d):     return "agg(\(k), \(d.noun))"
        case .superlative(let s):          return "super(\(s.ascending ? "min" : "max") \(s.property) of \(s.description.noun))"
        case .malformed(let m):            return "malformed(\(m))"
        }
    }

    // MARK: - Logical operators (lowest precedence: or < and < not < comparison)
    //
    // 2A strict rule: `and` and `or` may NOT be mixed at the same level without
    // explicit grouping. `either A or B` (handled via a sentinel) is the only
    // grouping construct. A bare mix like `A and B or C` is a hard error
    // (`.malformed`) carrying both possible readings.

    private func parseLogical(_ s: String) -> ExpressionAST {
        let t = s.trimmingCharacters(in: .whitespaces)
        // `it is not the case that X` → ¬X (a readable negation of a clause).
        if t.lowercased().hasPrefix("it is not the case that ") {
            let inner = String(t.dropFirst("it is not the case that ".count))
            return .logical(.not, [parseLogical(inner)])
        }
        let hasOr  = rangeOfMarkerOutsideQuotes(" or ", in: t) != nil
        let hasAnd = rangeOfMarkerOutsideQuotes(" and ", in: t) != nil
        if hasOr && hasAnd {
            return .malformed(mixedBooleanMessage(t))
        }
        if hasOr, let parts = splitTopLevel(t, on: " or ") {
            let ops = parts.map { parseAnd($0) }
            return ops.count == 1 ? ops[0] : .logical(.or, ops)
        }
        return parseAnd(t)
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

    /// The diagnostic carried by `.malformed` for an ungrouped `and`/`or` mix.
    private func mixedBooleanMessage(_ s: String) -> String {
        "ambiguous boolean expression \"\(s)\" mixes `and` and `or` without grouping. "
        + "Group the intended sub-clause with `either … or …` — e.g. write "
        + "`A and either B or C` (A ∧ (B ∨ C)) or `either A and B or C` ((A ∧ B) ∨ C)."
    }

    // MARK: - 2A. `either … or …` grouping (sentinel protection)

    /// Replace a leading-or-embedded `either …` clause with an opaque sentinel.
    /// The `either` consumes the remainder of the current expression as its
    /// disjunction body, so `A and either B or C` becomes `A and <sentinel>`
    /// (= A ∧ (B ∨ C)) and `either A or B` becomes a single `<sentinel>`.
    private func protectEitherGroups(_ s: String) -> String {
        guard let r = rangeOfWordOutsideQuotes("either ", in: s) else { return s }
        let prefix = String(s[s.startIndex..<r.lowerBound])
        let body = String(s[r.upperBound...])
        let encoded = Data(body.utf8).base64EncodedString()
        return prefix + eitherSentinelPrefix + encoded
    }

    /// Parse a previously-protected `either` body (`A or B or C`) into `.or`.
    private func parseEitherBody(_ body: String) -> ExpressionAST {
        guard let parts = splitTopLevel(body, on: " or ") else {
            return parse(body)
        }
        let ops = parts.map { parse($0) }
        return ops.count == 1 ? ops[0] : .logical(.or, ops)
    }

    /// Normalise Oxford-style `, and`/`, or` joins to plain ` and `/` or `.
    private func normalizeBooleanCommas(_ s: String) -> String {
        var out = replaceOutsideQuotes(s, find: ", and ", with: " and ")
        out = replaceOutsideQuotes(out, find: ", or ", with: " or ")
        return out
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
        let t = s.trimmingCharacters(in: .whitespaces)
        // Leaf-level precedence: quantifier → emptiness → temporal → active-verb
        // predicate → comparison markers → atom (aggregate/superlative/
        // description/scalar-nav are resolved inside parseAtom as value operands).
        if let q = parseQuantifierIfPresent(t) { return q }
        if let e = parseEmptinessIfPresent(t) { return e }
        if let tw = parseTemporalIfPresent(t) { return tw }
        if let v = parseActiveVerbIfPresent(t) { return v }
        for (marker, op) in lexicon.comparisonMarkers {
            if let (lhs, rhs) = split(t, around: [marker]) {
                return .comparison(parseAtom(lhs), op, parseAtom(rhs))
            }
        }
        return parseAtom(t)
    }

    // MARK: - Shared condition grammar (emptiness + temporal)

    /// Property-backed emptiness: `<subj> is empty` / `is not empty`,
    /// `<subj> has no <prop>` / `has a <prop>` / `has some <prop>`. The RHS of
    /// the produced comparison is an ignored `true` placeholder.
    private func parseEmptinessIfPresent(_ s: String) -> ExpressionAST? {
        let placeholder = ExpressionAST.literal(.boolean(true))
        let lower = s.lowercased()
        if lower.hasSuffix(" is not empty") {
            let subj = String(s.dropLast(" is not empty".count))
            return .comparison(parseAtom(subj), .isNotEmpty, placeholder)
        }
        if lower.hasSuffix(" is empty") {
            let subj = String(s.dropLast(" is empty".count))
            return .comparison(parseAtom(subj), .isEmpty, placeholder)
        }
        // has no / has a / has some  (also the plural `have …`)
        let emptyMarkers  = [" has no ", " have no "]
        let filledMarkers = [" has a ", " has an ", " has some ", " have a ", " have an ", " have some "]
        for m in emptyMarkers {
            if let r = rangeOfMarkerOutsideQuotes(m, in: lower) {
                let subj = String(s[s.startIndex..<r.lowerBound])
                let prop = String(s[r.upperBound...]).trimmingCharacters(in: .whitespaces)
                return .comparison(.propertyAccess(parseAtom(subj), prop), .isEmpty, placeholder)
            }
        }
        for m in filledMarkers {
            if let r = rangeOfMarkerOutsideQuotes(m, in: lower) {
                let subj = String(s[s.startIndex..<r.lowerBound])
                let prop = String(s[r.upperBound...]).trimmingCharacters(in: .whitespaces)
                return .comparison(.propertyAccess(parseAtom(subj), prop), .isNotEmpty, placeholder)
            }
        }
        return nil
    }

    /// One-sided temporal windows: `<subj> within the last N <unit>` and
    /// `<subj> in the next N <unit>`. A bare participle subject (`updated`,
    /// `modified`, `changed`) — or an empty subject — resolves to the lexicon's
    /// `timestampProperty`.
    private func parseTemporalIfPresent(_ s: String) -> ExpressionAST? {
        let lower = s.lowercased()
        let cases: [(String, ComparisonOpAST)] = [
            (" within the last ", .withinPast),
            (" in the next ", .withinFuture),
        ]
        for (marker, op) in cases {
            if let r = rangeOfMarkerOutsideQuotes(marker, in: lower) {
                let before = String(s[s.startIndex..<r.lowerBound]).trimmingCharacters(in: .whitespaces)
                let after  = String(s[r.upperBound...]).trimmingCharacters(in: .whitespaces)
                guard let dur = parseLeadingDuration(after) else { return nil }
                let lt = before.lowercased()
                let lhs: ExpressionAST
                if before.isEmpty || lt == "updated" || lt == "modified" || lt == "changed" {
                    lhs = .identifierRef(lexicon.timestampProperty)
                } else {
                    lhs = parseAtom(before)
                }
                return .comparison(lhs, op, .literal(.duration(dur.0, dur.1)))
            }
        }
        return nil
    }

    /// Parse a leading `N <unit>` duration, ignoring any trailing words.
    private func parseLeadingDuration(_ s: String) -> (Double, TimeUnitAST)? {
        let parts = s.split(separator: " ").map(String.init)
        guard parts.count >= 2 else { return nil }
        return parseDuration("\(parts[0]) \(parts[1])")
    }

    // MARK: - Atom

    func parseAtom(_ s: String) -> ExpressionAST {
        let t = s.trimmingCharacters(in: .whitespaces)
        if t.isEmpty { return .literal(.string("")) }

        // 2A: `either … or …` sentinel — decode the base64 body and parse it as
        // an explicit disjunction.
        if t.hasPrefix(eitherSentinelPrefix) {
            let b64 = String(t.dropFirst(eitherSentinelPrefix.count))
            if let data = Data(base64Encoded: b64),
               let body = String(data: data, encoding: .utf8) {
                return parseEitherBody(body)
            }
            return .literal(.string(""))
        }

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

        // 3C: relational value atoms (need the symbol table to resolve kinds /
        // verbs). Precedence: aggregate (`the number/list of …`) → superlative
        // (`the oldest …`) → scalar navigation (`the task assigned to X`) →
        // description (`the stale pages that mention X`). A bare plural kind with
        // no restriction is NOT a description and falls through to an identifier.
        if symbols != nil {
            if let agg = parseAggregateIfPresent(t) { return agg }
            if let sup = parseSuperlativeIfPresent(t) { return sup }
            if let nav = parseScalarNavIfPresent(t) { return nav }
            if let desc = parseDescription(t) { return .description(desc) }
            if let bad = undeclaredPassiveVerbError(t) { return bad }
        }

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

    /// Like `rangeOfMarkerOutsideQuotes` but the match must begin at a word
    /// boundary (string start or a preceding space). Used so `either ` matches
    /// the keyword but not the tail of `neither `.
    private func rangeOfWordOutsideQuotes(_ word: String, in s: String) -> Range<String.Index>? {
        var search = s.startIndex
        while let r = rangeOfMarkerOutsideQuotes(word, in: String(s[search...])) {
            // Translate the sub-range back to absolute indices.
            let lowerOffset = s[search...].distance(from: s[search...].startIndex, to: r.lowerBound)
            let absLower = s.index(search, offsetBy: lowerOffset)
            let atBoundary = absLower == s.startIndex || s[s.index(before: absLower)] == " "
            if atBoundary {
                let absUpper = s.index(absLower, offsetBy: word.count)
                return absLower..<absUpper
            }
            search = s.index(after: absLower)
            if search >= s.endIndex { break }
        }
        return nil
    }

    /// Replace every out-of-quotes occurrence of `find` with `replace`.
    private func replaceOutsideQuotes(_ s: String, find: String, with replace: String) -> String {
        var result = ""
        var remaining = Substring(s)
        while let r = rangeOfMarkerOutsideQuotes(find, in: String(remaining)) {
            let head = remaining[remaining.startIndex..<r.lowerBound]
            result += head + replace
            let consumed = String(remaining).distance(from: String(remaining).startIndex, to: r.upperBound)
            remaining = remaining[remaining.index(remaining.startIndex, offsetBy: consumed)...]
        }
        result += remaining
        return result
    }

    // MARK: - 2C. Quantifier parsing

    /// Detect a leading quantifier determiner and parse the whole leaf as a
    /// quantified description. Returns nil when there is no determiner.
    private func parseQuantifierIfPresent(_ s: String) -> ExpressionAST? {
        guard let (kind, rest0) = matchDeterminer(s) else { return nil }
        var rest = rest0.trimmingCharacters(in: .whitespaces)
        for p in ["of the ", "of "] where rest.lowercased().hasPrefix(p) {
            rest = String(rest.dropFirst(p.count)); break
        }
        rest = lexicon.stripLeadingArticle(rest)
        guard !rest.isEmpty else {
            return .malformed("quantifier \"\(s)\" is missing a description (e.g. `all pages`).")
        }

        let (descText, whereText, bodyText) = splitDescriptionAndBody(rest)
        let (adjectives, noun) = splitAdjectivesAndNoun(descText)
        guard !noun.isEmpty else {
            return .malformed("quantifier \"\(s)\" has no collection noun.")
        }
        let wherePred = whereText.map { parse($0) }
        var body: ExpressionAST? = nil
        if let b = bodyText {
            let elementVar = lexicon.singularize(noun.lowercased())
            body = parse(elementVar + " " + normalizeQuantBody(b))
        }
        let desc = DescriptionAST(noun: noun, adjectives: adjectives, wherePredicate: wherePred)
        return .quantified(QuantifierAST(kind: kind, description: desc, body: body))
    }

    /// Match a leading quantifier determiner; return the kind and the remainder.
    private func matchDeterminer(_ s: String) -> (QuantifierKindAST, String)? {
        let lower = s.lowercased()
        func after(_ prefix: String) -> String { String(s.dropFirst(prefix.count)) }
        if lower.hasPrefix("all ")     { return (.all, after("all ")) }
        if lower.hasPrefix("every ")   { return (.all, after("every ")) }
        if lower.hasPrefix("any ")     { return (.any, after("any ")) }
        if lower.hasPrefix("some ")    { return (.any, after("some ")) }
        if lower.hasPrefix("none of ") { return (.none, after("none of ")) }
        if lower.hasPrefix("none ")    { return (.none, after("none ")) }
        if lower.hasPrefix("no ")      { return (.none, after("no ")) }
        for (kw, make): (String, (Int) -> QuantifierKindAST) in
            [("at least ", { .atLeast($0) }), ("at most ", { .atMost($0) }), ("exactly ", { .exactly($0) })] {
            if lower.hasPrefix(kw) {
                let tail = after(kw).trimmingCharacters(in: .whitespaces)
                let parts = tail.split(separator: " ", maxSplits: 1).map(String.init)
                if let first = parts.first, let n = Int(first) {
                    return (make(n), parts.count > 1 ? parts[1] : "")
                }
            }
        }
        return nil
    }

    /// Split a quantifier remainder into (descriptionText, whereText, bodyText).
    /// `whose …` introduces a where-predicate; a copular/possessive verb
    /// (`have`/`has`/`are`/`is`/`contain`/`include`) introduces a per-element
    /// body (kept verbatim from the verb onward).
    private func splitDescriptionAndBody(_ s: String) -> (desc: String, whereText: String?, body: String?) {
        if let wr = rangeOfMarkerOutsideQuotes(" whose ", in: s.lowercased()) {
            let desc = String(s[s.startIndex..<wr.lowerBound]).trimmingCharacters(in: .whitespaces)
            let cond = String(s[wr.upperBound...]).trimmingCharacters(in: .whitespaces)
            return (desc, cond, nil)
        }
        let bodyVerbs = [" have ", " has ", " are ", " is ", " contain ", " contains ",
                         " include ", " includes ", " do ", " does "]
        var earliest: Range<String.Index>? = nil
        let lower = s.lowercased()
        for v in bodyVerbs {
            if let r = rangeOfMarkerOutsideQuotes(v, in: lower) {
                if earliest == nil || r.lowerBound < earliest!.lowerBound { earliest = r }
            }
        }
        if let r = earliest {
            let desc = String(s[s.startIndex..<r.lowerBound]).trimmingCharacters(in: .whitespaces)
            let body = String(s[r.lowerBound...]).trimmingCharacters(in: .whitespaces)
            return (desc, nil, body)
        }
        return (s.trimmingCharacters(in: .whitespaces), nil, nil)
    }

    /// Split `[adjectives] <kind plural>` into the raw adjective list and the
    /// head noun. Prefers the longest trailing run that resolves to a declared
    /// kind (singular form); falls back to the last word as the noun.
    private func splitAdjectivesAndNoun(_ s: String) -> (adjectives: [String], noun: String) {
        let words = s.split(separator: " ").map(String.init)
        guard !words.isEmpty else { return ([], "") }
        if let sym = symbols {
            for i in 0..<words.count {
                let candidate = words[i...].joined(separator: " ")
                if sym.kinds[lexicon.singularize(candidate)] != nil
                    || sym.kinds[candidate.lowercased()] != nil {
                    return (Array(words[0..<i]).map { $0.lowercased() }, candidate)
                }
            }
        }
        // Fallback: the last word is the head noun.
        return (Array(words.dropLast()).map { $0.lowercased() }, words.last!)
    }

    /// Normalise a plural quantifier body verb to its singular element form so a
    /// synthesised `<element> <body>` re-parses cleanly.
    private func normalizeQuantBody(_ b: String) -> String {
        let parts = b.split(separator: " ", maxSplits: 1).map(String.init)
        guard let verb = parts.first else { return b }
        let rest = parts.count > 1 ? " " + parts[1] : ""
        switch verb.lowercased() {
        case "have":    return "has" + rest
        case "are":     return "is" + rest
        case "do":      return "does" + rest
        case "contain": return "contains" + rest
        case "include": return "includes" + rest
        default:        return b
        }
    }

    // MARK: - 3B/3C. Relational surface forms

    private func stripLeadingArticle(_ s: String) -> String {
        lexicon.stripLeadingArticle(s)
    }

    /// 3B: active verb predicate `<subject> <verbs> <object>` (`the user owns the
    /// page`). Splits on the earliest non-initial word that is an active (third
    /// person / base) form of a declared verb. Past participles are skipped (they
    /// are passive description clauses, not active predicates).
    private func parseActiveVerbIfPresent(_ s: String) -> ExpressionAST? {
        guard let sym = symbols, !sym.verbs.isEmpty else { return nil }
        guard rangeOfMarkerOutsideQuotes("\"", in: s) == nil else { return nil }
        let words = s.split(separator: " ").map(String.init)
        guard words.count >= 3 else { return nil }
        let relativizers: Set<String> = ["that", "which", "who", "whose", "whom"]
        // Do-support auxiliaries that carry the negation in front of a base verb
        // (`the entity does not link …`); contractions fuse the negator (`doesn't`).
        let auxiliaries: Set<String> = ["does", "do", "did"]
        let negContractions: Set<String> = ["doesn't", "don't", "didn't"]
        for idx in 1..<(words.count - 1) {
            let w = words[idx].lowercased()
            guard let resolved = sym.resolveVerbForm(w), resolved.role != .pastParticiple else { continue }
            // A verb immediately preceded by a relativizer is a relative-clause
            // predicate inside a description (`pages that mention …`), not a
            // top-level active-verb condition. Let parseAtom/description own it.
            if relativizers.contains(words[idx - 1].lowercased()) { continue }
            // Detect a negated predicate (`<subject> does not <verb> <object>` or
            // `<subject> doesn't <verb> <object>`) so the verb's subject excludes
            // the auxiliary + negator. The result is wrapped in `not`.
            var subjectEnd = idx
            var negated = false
            let prev = words[idx - 1].lowercased()
            if prev == "not", idx >= 2, auxiliaries.contains(words[idx - 2].lowercased()) {
                subjectEnd = idx - 2
                negated = true
            } else if negContractions.contains(prev) {
                subjectEnd = idx - 1
                negated = true
            }
            let subject = words[0..<subjectEnd].joined(separator: " ")
            let object = stripLeadingPreposition(words[(idx + 1)...].joined(separator: " "))
            guard !subject.isEmpty, !object.isEmpty else { continue }
            let predicate: ExpressionAST = .verbPredicate(subject: parseAtom(subject), verb: w, object: parseAtom(object))
            return negated ? .logical(.not, [predicate]) : predicate
        }
        return nil
    }

    /// Strip a single leading preposition token (`link to the input` → `the
    /// input`). Verbs that govern a preposition (`link to`, `report to`) carry it
    /// between verb and object; objects of bare-transitive verbs are unaffected.
    private func stripLeadingPreposition(_ s: String) -> String {
        let t = s.trimmingCharacters(in: .whitespaces)
        guard let first = t.split(separator: " ").first.map({ String($0).lowercased() }),
              lexicon.prepositions.contains(first) else { return t }
        return String(t.dropFirst(first.count)).trimmingCharacters(in: .whitespaces)
    }

    /// 3C: `the number of <desc>` / `the count of <desc>` / `the list of <desc>`.
    private func parseAggregateIfPresent(_ raw: String) -> ExpressionAST? {
        let s = stripLeadingArticle(raw)
        let forms: [(String, AggregateKindAST)] =
            [("number of ", .count), ("count of ", .count), ("list of ", .list)]
        for (kw, kind) in forms where s.lowercased().hasPrefix(kw) {
            let inner = String(s.dropFirst(kw.count)).trimmingCharacters(in: .whitespaces)
            guard let desc = parseDescriptionOrBare(inner) else { return nil }
            return .aggregate(kind, desc)
        }
        return nil
    }

    /// 3C: a superlative `the <gradable> <desc> [by <property>]`. Timestamp
    /// gradables (`oldest`/`newest`/`most recent`) default to the lexicon's
    /// timestamp property; magnitude gradables require `by <property>`.
    private func parseSuperlativeIfPresent(_ raw: String) -> ExpressionAST? {
        guard symbols != nil else { return nil }
        let s = stripLeadingArticle(raw)
        let words = s.split(separator: " ").map(String.init)
        guard let first = words.first?.lowercased() else { return nil }
        var gradable = first
        var rest = words.dropFirst().joined(separator: " ")
        if first == "most", words.count >= 2, words[1].lowercased() == "recent" {
            gradable = "most recent"
            rest = words.dropFirst(2).joined(separator: " ")
        }
        guard let dir = superlativeDirection(gradable) else { return nil }
        var property: String?
        if let r = rangeOfMarkerOutsideQuotes(" by ", in: rest.lowercased()) {
            property = String(rest[r.upperBound...]).trimmingCharacters(in: .whitespaces).lowercased()
            rest = String(rest[rest.startIndex..<r.lowerBound]).trimmingCharacters(in: .whitespaces)
        }
        guard let desc = parseDescriptionOrBare(rest) else { return nil }
        let prop: String
        if dir.needsBy {
            guard let p = property else {
                return .malformed("superlative `\(gradable)` needs a `by <property>` (e.g. `the \(gradable) \(desc.noun) by amount`).")
            }
            prop = p
        } else {
            prop = property ?? lexicon.timestampProperty
        }
        return .superlative(SuperlativeAST(description: desc, property: prop, ascending: dir.ascending))
    }

    private func superlativeDirection(_ g: String) -> (ascending: Bool, needsBy: Bool)? {
        switch g {
        case "oldest", "earliest":                  return (true, false)
        case "newest", "latest", "most recent":     return (false, false)
        case "smallest", "lowest", "least", "fewest": return (true, true)
        case "largest", "highest", "most", "greatest", "biggest": return (false, true)
        default:                                    return nil
        }
    }

    /// 3C: scalar relation navigation `the <kind> <participle> {to|by} <operand>`
    /// (`the task assigned to the user`). The head must be a singular declared
    /// kind; a plural head is a passive description clause, handled elsewhere.
    private func parseScalarNavIfPresent(_ raw: String) -> ExpressionAST? {
        guard let sym = symbols else { return nil }
        let s = stripLeadingArticle(raw)
        let words = s.split(separator: " ").map(String.init)
        guard words.count >= 4 else { return nil }
        for idx in 1..<(words.count - 1) {
            let w = words[idx].lowercased()
            guard let resolved = sym.resolveVerbForm(w), resolved.role == .pastParticiple else { continue }
            let conn = words[idx + 1].lowercased()
            guard conn == "to" || conn == "by" else { continue }
            let head = words[0..<idx].joined(separator: " ").lowercased()
            guard sym.kinds[head] != nil else { return nil }
            let operand = words[(idx + 2)...].joined(separator: " ")
            guard !operand.isEmpty else { return nil }
            return .relationTraversal(parseAtom(operand), relation: w, navKind: head)
        }
        return nil
    }

    /// 3C: parse a description `[first N] [adjectives] <plural kind> [whose … |
    /// that <verb clause> | <participle> by <operand>] [sorted by <property>
    /// [ascending|descending]]`. Returns nil unless the head is a plural declared
    /// kind carrying at least one restriction/adjective/sort/take.
    private func parseDescription(_ raw: String) -> DescriptionAST? {
        guard let sym = symbols else { return nil }
        var s = stripLeadingArticle(raw)

        var take: Int?
        let leading = s.split(separator: " ").map(String.init)
        if leading.count >= 2, leading[0].lowercased() == "first", let n = Int(leading[1]) {
            take = n
            s = leading[2...].joined(separator: " ")
        }

        var sort: (property: String, ascending: Bool)?
        if let r = rangeOfMarkerOutsideQuotes(" sorted by ", in: s.lowercased()) {
            var tail = String(s[r.upperBound...]).trimmingCharacters(in: .whitespaces)
            var asc = true
            if tail.lowercased().hasSuffix(" descending") {
                asc = false; tail = String(tail.dropLast(" descending".count))
            } else if tail.lowercased().hasSuffix(" ascending") {
                tail = String(tail.dropLast(" ascending".count))
            }
            sort = (property: tail.trimmingCharacters(in: .whitespaces).lowercased(), ascending: asc)
            s = String(s[s.startIndex..<r.lowerBound]).trimmingCharacters(in: .whitespaces)
        }

        var wherePred: ExpressionAST?
        var verbClauses: [VerbClauseAST] = []
        var descPart = s

        if let wr = rangeOfMarkerOutsideQuotes(" whose ", in: s.lowercased()) {
            descPart = String(s[s.startIndex..<wr.lowerBound]).trimmingCharacters(in: .whitespaces)
            wherePred = parse(String(s[wr.upperBound...]))
        } else if let tr = rangeOfMarkerOutsideQuotes(" that ", in: s.lowercased()) {
            descPart = String(s[s.startIndex..<tr.lowerBound]).trimmingCharacters(in: .whitespaces)
            guard let vc = parseThatClause(String(s[tr.upperBound...])) else { return nil }
            verbClauses.append(vc)
        } else if let vc = parsePassiveClauseSuffix(&descPart) {
            verbClauses.append(vc)
        }

        let (adjectives, noun) = splitAdjectivesAndNoun(descPart)
        guard !noun.isEmpty else { return nil }
        let singular = lexicon.singularize(noun.lowercased())
        guard sym.kinds[singular] != nil, noun.lowercased() != singular else { return nil }
        if wherePred == nil && verbClauses.isEmpty && adjectives.isEmpty && sort == nil && take == nil {
            return nil
        }
        return DescriptionAST(noun: noun, adjectives: adjectives, wherePredicate: wherePred,
                              verbClauses: verbClauses, sort: sort, take: take)
    }

    /// A description, or (failing that) a bare plural declared kind with no
    /// restriction (used as an aggregate/superlative source).
    private func parseDescriptionOrBare(_ inner: String) -> DescriptionAST? {
        if let d = parseDescription(inner) { return d }
        guard let sym = symbols else { return nil }
        let s = stripLeadingArticle(inner)
        let (adjectives, noun) = splitAdjectivesAndNoun(s)
        guard !noun.isEmpty else { return nil }
        let singular = lexicon.singularize(noun.lowercased())
        guard sym.kinds[singular] != nil else { return nil }
        return DescriptionAST(noun: noun, adjectives: adjectives)
    }

    /// Parse a `that …` relative clause into a verb clause. Subject-gap
    /// (`that mention the entity`) has the verb first; object-gap (`that the user
    /// owns`) has the verb last.
    private func parseThatClause(_ raw: String) -> VerbClauseAST? {
        guard let sym = symbols else { return nil }
        let words = raw.trimmingCharacters(in: .whitespaces).split(separator: " ").map(String.init)
        guard !words.isEmpty else { return nil }
        if let r = sym.resolveVerbForm(words[0].lowercased()), r.role != .pastParticiple {
            let operand = words[1...].joined(separator: " ")
            guard !operand.isEmpty else { return nil }
            return VerbClauseAST(verbForm: words[0].lowercased(),
                                 operand: parseAtom(operand), elementIsSubject: true)
        }
        if words.count >= 2, let r = sym.resolveVerbForm(words.last!.lowercased()), r.role != .pastParticiple {
            let operand = words[0..<(words.count - 1)].joined(separator: " ")
            guard !operand.isEmpty else { return nil }
            return VerbClauseAST(verbForm: words.last!.lowercased(),
                                 operand: parseAtom(operand), elementIsSubject: false)
        }
        return nil
    }

    /// Detect a trailing passive clause `<participle> by <operand>` on `descPart`,
    /// removing it from `descPart` and returning the verb clause (element = object).
    private func parsePassiveClauseSuffix(_ descPart: inout String) -> VerbClauseAST? {
        guard let sym = symbols else { return nil }
        guard let byR = rangeOfMarkerOutsideQuotes(" by ", in: descPart.lowercased()) else { return nil }
        let head = String(descPart[descPart.startIndex..<byR.lowerBound]).trimmingCharacters(in: .whitespaces)
        let operand = String(descPart[byR.upperBound...]).trimmingCharacters(in: .whitespaces)
        let hw = head.split(separator: " ").map(String.init)
        guard let last = hw.last,
              let r = sym.resolveVerbForm(last.lowercased()), r.role == .pastParticiple,
              !operand.isEmpty else { return nil }
        descPart = hw[0..<(hw.count - 1)].joined(separator: " ")
        return VerbClauseAST(verbForm: last.lowercased(),
                             operand: parseAtom(operand), elementIsSubject: false)
    }

    /// 3B: a high-confidence "you meant a relation verb here" error. Fires ONLY
    /// when the text is unambiguously shaped like a passive relation clause —
    /// `<plural declared kind> <participle-looking word> by <operand>` — but the
    /// participle word names no declared verb. Ordinary prose ending in `… by …`
    /// falls through untouched (the head must be a plural declared kind and the
    /// pre-`by` word must look like a participle). This is the only place an
    /// unknown relation verb surfaces, since every other relational production
    /// requires `resolveVerbForm` to already succeed.
    private func undeclaredPassiveVerbError(_ raw: String) -> ExpressionAST? {
        guard let sym = symbols else { return nil }
        let s = stripLeadingArticle(raw)
        guard let byR = rangeOfMarkerOutsideQuotes(" by ", in: s.lowercased()) else { return nil }
        let head = String(s[s.startIndex..<byR.lowerBound]).trimmingCharacters(in: .whitespaces)
        let operand = String(s[byR.upperBound...]).trimmingCharacters(in: .whitespaces)
        let hw = head.split(separator: " ").map(String.init)
        guard hw.count >= 2, !operand.isEmpty, let cand = hw.last?.lowercased() else { return nil }
        let looksParticiple = cand.hasSuffix("ed") || cand.hasSuffix("en")
        guard looksParticiple, sym.resolveVerbForm(cand) == nil else { return nil }
        let noun = hw[hw.count - 2].lowercased()
        let singular = lexicon.singularize(noun)
        guard sym.kinds[singular] != nil, noun != singular else { return nil }
        let hint = sym.nearestVerbForm(to: cand).map { " (did you mean \"\($0)\"?)" } ?? ""
        return .malformed("unknown relation verb \"\(cand)\"\(hint). Declare it with `The verb to <base> (it <3rd>, it is \(cand)) means the <relation> relation.`")
    }
}
