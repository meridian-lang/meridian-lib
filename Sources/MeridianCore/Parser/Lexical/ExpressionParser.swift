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
        trace.log(.expression, "parse.start(\"\(s)\")")
        // 2A: normalise `, and`/`, or` to plain joins, then bracket any
        // `either … or …` group into an opaque sentinel so the boolean splitter
        // sees it as a single operand.
        let prepared = protectEitherGroups(normalizeBooleanCommas(s))
        trace.log(.expression, "parse.prepared(\"\(prepared)\")")
        let result = parseLogical(prepared)
        trace.log(.expression, "parse(\"\(s)\") → \(result.traceDescription(detail: .verbose))")
        return result
    }

    // MARK: - Logical operators (lowest precedence: or < and < not < comparison)
    //
    // 2A strict rule: `and` and `or` may NOT be mixed at the same level without
    // explicit grouping. `either A or B` (handled via a sentinel) is the only
    // grouping construct. A bare mix like `A and B or C` is a hard error
    // (`.malformed`) carrying both possible readings.

    private func parseLogical(_ s: String) -> ExpressionAST {
        let t = s.trimmingCharacters(in: .whitespaces)
        trace.log(.expression, "parseLogical(\"\(t)\")")
        // `it is not the case that X` → ¬X (a readable negation of a clause).
        if t.lowercased().hasPrefix(lexicon.grammar.clauseNegationIntroducer) {
            let inner = String(t.dropFirst(lexicon.grammar.clauseNegationIntroducer.count))
            return .logical(.not, [parseLogical(inner)])
        }
        // ── Why we mask here ─────────────────────────────────────────────
        // This layer is the BOOLEAN disjunction splitter: it cuts the clause on
        // every top-level ` or ` and treats each piece as a separate operand of
        // `.logical(.or, …)`. It runs BEFORE the comparison layer (`or` is the
        // lowest-precedence operator), so it sees the raw clause text.
        //
        // Problem: some comparison MARKERS themselves contain the word "or" —
        // the `… than or equal to` family (`is more than or equal to`,
        // `greater than or equal to`, `less than or equal to`), i.e. the very
        // common ≥ / ≤ spellings. Left alone, the splitter would chop
        //   "total is more than or equal to 5"
        // at its internal ` or ` into the nonsense pair
        //   ["total is more than", "equal to 5"]
        // and emit a bogus `.logical(.or, …)` — the comparison would never form.
        //
        // Fix: temporarily replace ONLY the marker-internal ` or ` with an
        // opaque sentinel (`maskComparisonOr`). After masking, the only ` or `s
        // left in the string are *genuine* disjunctions, so `hasOr` / the split
        // are computed on the masked text. Each resulting operand is then
        // un-masked (`unmaskComparisonOr`) before it descends to `parseAnd` →
        // `parseComparison`, which matches the marker against its ORIGINAL
        // (restored) ` or ` text. Net effect: a marker-internal ` or ` is
        // invisible to the splitter but intact for the comparison layer, while
        // a real "A or B" — even one whose operands contain ≥/≤ comparisons —
        // still splits correctly (see `disjunctionStillSplits` test).
        let masked = maskComparisonOr(t)
        let hasOr  = rangeOfMarkerOutsideQuotes(lexicon.grammar.booleanConnectors.orMarker, in: masked) != nil
        let hasAnd = rangeOfMarkerOutsideQuotes(lexicon.grammar.booleanConnectors.andMarker, in: masked) != nil
        if hasOr && hasAnd {
            return .malformed(mixedBooleanMessage(t))
        }
        if hasOr, let parts = splitTopLevel(masked, on: lexicon.grammar.booleanConnectors.orMarker) {
            let ops = parts.map { parseAnd(unmaskComparisonOr($0)) }
            return ops.count == 1 ? ops[0] : .logical(.or, ops)
        }
        return parseAnd(t)
    }

    // MARK: - Comparison-marker `or` shielding
    //
    // Helpers for the masking described in `parseLogical`. They exist solely so
    // the ≥/≤ word spellings (`… than or equal to`) survive the boolean
    // disjunction split. The token is a private-use-area character so it can
    // never appear in real source and never re-matches as an operator.

    /// Stand-in for a comparison-marker-internal ` or ` while the disjunction
    /// splitter runs. PUA (`\u{E002}`) on both sides + uppercase `OR` so it
    /// cannot collide with source text and cannot be re-matched as ` or `.
    private static let orMaskToken = "\u{E002}OR\u{E002}"

    /// The comparison markers that embed a literal ` or ` (the `… or equal to`
    /// family). Pulled from the lexicon — NOT a hardcoded phrase list — so a
    /// domain that adds an or-bearing comparison synonym via `=== language ===`
    /// is shielded automatically. Sorted longest-first so a marker that is a
    /// substring of another (`more than or equal to` ⊂ `is more than or equal
    /// to`) is masked only after its longer container, avoiding double work.
    private var orBearingComparisonMarkers: [String] {
        lexicon.comparisonMarkers
            .map { $0.0.lowercased() }
            .filter { $0.contains(lexicon.grammar.booleanConnectors.orMarker) }
            .sorted { $0.count > $1.count }
    }

    /// Replace every marker-internal ` or ` in `t` with `orMaskToken`, leaving
    /// genuine disjunction ` or `s untouched. Case-insensitive so `Greater Than
    /// Or Equal To` is shielded too (the comparison layer lower-cases anyway).
    /// Masking a marker that happens to sit inside a quoted string is harmless:
    /// the splitter already ignores quoted ` or `, and the operand is un-masked
    /// before it is parsed. The leading `guard` is a fast path for the common
    /// case of a clause with no ` or ` at all.
    private func maskComparisonOr(_ t: String) -> String {
        guard t.lowercased().contains(lexicon.grammar.booleanConnectors.orMarker) else { return t }
        var result = t
        for marker in orBearingComparisonMarkers {
            let masked = marker.replacingOccurrences(
                of: lexicon.grammar.booleanConnectors.orMarker,
                with: " \(Self.orMaskToken) ")
            result = result.replacingOccurrences(of: marker, with: masked, options: .caseInsensitive)
        }
        return result
    }

    /// Inverse of `maskComparisonOr`: restore the sentinel back to ` or ` so the
    /// comparison layer sees the marker in its original form. Applied to each
    /// disjunction operand right before it descends past the boolean layers.
    private func unmaskComparisonOr(_ s: String) -> String {
        s.replacingOccurrences(of: " \(Self.orMaskToken) ", with: lexicon.grammar.booleanConnectors.orMarker)
    }

    private func parseAnd(_ s: String) -> ExpressionAST {
        trace.log(.expression, "parseAnd(\"\(s)\")")
        if let andParts = splitTopLevel(s, on: lexicon.grammar.booleanConnectors.andMarker) {
            let operands = andParts.map { parseNot($0) }
            return operands.count == 1 ? operands[0] : .logical(.and, operands)
        }
        return parseNot(s)
    }

    private func parseNot(_ s: String) -> ExpressionAST {
        let t = s.trimmingCharacters(in: .whitespaces)
        trace.log(.expression, "parseNot(\"\(t)\")")
        if t.lowercased().hasPrefix(lexicon.grammar.booleanConnectors.notPrefix) {
            let inner = parseNot(String(t.dropFirst(lexicon.grammar.booleanConnectors.notPrefix.count)))
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
        guard let r = rangeOfWordOutsideQuotes(lexicon.grammar.booleanConnectors.eitherPrefix, in: s) else { return s }
        let prefix = String(s[s.startIndex..<r.lowerBound])
        let body = String(s[r.upperBound...])
        let encoded = Data(body.utf8).base64EncodedString()
        return prefix + eitherSentinelPrefix + encoded
    }

    /// Parse a previously-protected `either` body (`A or B or C`) into `.or`.
    private func parseEitherBody(_ body: String) -> ExpressionAST {
        guard let parts = splitTopLevel(body, on: lexicon.grammar.booleanConnectors.orMarker) else {
            return parse(body)
        }
        let ops = parts.map { parse($0) }
        return ops.count == 1 ? ops[0] : .logical(.or, ops)
    }

    /// Normalise Oxford-style `, and`/`, or` joins to plain ` and `/` or `.
    private func normalizeBooleanCommas(_ s: String) -> String {
        var out = replaceOutsideQuotes(
            s,
            find: lexicon.grammar.booleanConnectors.oxfordAndMarker,
            with: lexicon.grammar.booleanConnectors.andMarker)
        out = replaceOutsideQuotes(
            out,
            find: lexicon.grammar.booleanConnectors.oxfordOrMarker,
            with: lexicon.grammar.booleanConnectors.orMarker)
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
        trace.log(.expression, "parseComparison(\"\(t)\")")
        // Leaf-level precedence: quantifier → emptiness → temporal → active-verb
        // predicate → comparison markers → atom (aggregate/superlative/
        // description/scalar-nav are resolved inside parseAtom as value operands).
        trace.log(.expression, "parseComparison.quantifier")
        if let q = parseQuantifierIfPresent(t) { return q }
        trace.log(.expression, "parseComparison.emptiness")
        if let e = parseEmptinessIfPresent(t) { return e }
        trace.log(.expression, "parseComparison.temporal")
        if let tw = parseTemporalIfPresent(t) { return tw }
        trace.log(.expression, "parseComparison.activeVerb")
        if let v = parseActiveVerbIfPresent(t) { return v }
        trace.log(.expression, "parseComparison.markers")
        for (marker, op) in lexicon.comparisonMarkers {
            if let (lhs, rhs) = split(t, around: [marker]) {
                return .comparison(parseAtom(lhs), op, parseAtom(rhs))
            }
        }
        trace.log(.expression, "parseComparison.atom")
        return parseAtom(t)
    }

    // MARK: - Shared condition grammar (emptiness + temporal)

    /// Property-backed emptiness: `<subj> is empty` / `is not empty`,
    /// `<subj> has no <prop>` / `has a <prop>` / `has some <prop>`. The RHS of
    /// the produced comparison is an ignored `true` placeholder.
    private func parseEmptinessIfPresent(_ s: String) -> ExpressionAST? {
        let placeholder = ExpressionAST.literal(.boolean(true))
        let lower = s.lowercased()
        if lower.hasSuffix(lexicon.grammar.notEmptyPredicateSuffix) {
            let subj = String(s.dropLast(lexicon.grammar.notEmptyPredicateSuffix.count))
            return .comparison(parseAtom(subj), .isNotEmpty, placeholder)
        }
        if lower.hasSuffix(lexicon.grammar.emptyPredicateSuffix) {
            let subj = String(s.dropLast(lexicon.grammar.emptyPredicateSuffix.count))
            return .comparison(parseAtom(subj), .isEmpty, placeholder)
        }
        // has no / has a / has some  (also the plural `have …`)
        let emptyMarkers  = lexicon.emptyMarkers
        let filledMarkers = lexicon.filledMarkers
        for m in emptyMarkers {
            if let r = rangeOfMarkerOutsideQuotes(m, in: s) {
                let subj = String(s[s.startIndex..<r.lowerBound])
                let prop = String(s[r.upperBound...]).trimmingCharacters(in: .whitespaces)
                return .comparison(.propertyAccess(parseAtom(subj), prop), .isEmpty, placeholder)
            }
        }
        for m in filledMarkers {
            if let r = rangeOfMarkerOutsideQuotes(m, in: s) {
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
        for (marker, op) in lexicon.temporalWindowMarkers {
            if let r = rangeOfMarkerOutsideQuotes(marker, in: s) {
                let before = String(s[s.startIndex..<r.lowerBound]).trimmingCharacters(in: .whitespaces)
                let after  = String(s[r.upperBound...]).trimmingCharacters(in: .whitespaces)
                guard let dur = parseLeadingDuration(after) else { return nil }
                let lt = before.lowercased()
                let lhs: ExpressionAST
                if before.isEmpty || lexicon.timestampAliases.contains(lt) {
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
        return lexicon.parseDuration("\(parts[0]) \(parts[1])")
    }

    // MARK: - Atom

    func parseAtom(_ s: String) -> ExpressionAST {
        let t = s.trimmingCharacters(in: .whitespaces)
        if t.isEmpty { return .literal(.string("")) }

        // 2A: `either … or …` sentinel — decode the base64 body and parse it as
        // an explicit disjunction.
        if t.hasPrefix(eitherSentinelPrefix) {
            if let body = decodeBase64Body(String(t.dropFirst(eitherSentinelPrefix.count))) {
                return parseEitherBody(body)
            }
            return .literal(.string(""))
        }

        // B6/B7: Fenced code-block sentinel — decode base64 body, then parse
        // for `{{ expr }}` interpolation markers (B7).
        if t.hasPrefix(codeBlockSentinelPrefix) {
            if let (_, body) = decodeCodeBlockSentinel(t) {
                let lowerBody = body.lowercased()
                if body.contains("{{")
                    || lowerBody.contains(lexicon.grammar.templateDirectives.ifPrefix)
                    || lowerBody.contains(lexicon.grammar.templateDirectives.forEachPrefix) {
                    let segs = parseInterpolationSegments(body)
                    // Collapse a single literal-only segment to a plain string literal.
                    if segs.count == 1, case .literal(let plain) = segs[0] {
                        return .literal(.string(plain))
                    }
                    return .interpolatedString(segs)
                }
                return .literal(.string(body))
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
        if let dur = lexicon.parseDuration(t) { return .literal(.duration(dur.0, dur.1)) }

        // float
        if let d = Double(t), t.contains(".") { return .literal(.double(d)) }

        // integer
        if let n = Int(t) { return .literal(.integer(n)) }

        if let lookup = parseTableLookupIfPresent(t) { return lookup }

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

    private func parseTableLookupIfPresent(_ s: String) -> ExpressionAST? {
        guard lexicon.hasLeadingArticle(s) else { return nil }
        let body = lexicon.stripLeadingArticle(s)
        let corrMarker = lexicon.grammar.tableLookup.correspondingToMarker
        let inMarker = lexicon.grammar.tableLookup.inTableMarker
        guard let corr = body.range(of: corrMarker, options: [.caseInsensitive]),
              let inRange = body.range(of: inMarker, options: [.caseInsensitive, .backwards]),
              corr.upperBound < inRange.lowerBound else { return nil }

        let valueColumn = String(body[body.startIndex..<corr.lowerBound])
            .trimmingCharacters(in: .whitespaces)
        let keyPhrase = String(body[corr.upperBound..<inRange.lowerBound]).trimmingCharacters(in: .whitespaces)
        let tableName = String(body[inRange.upperBound...]).trimmingCharacters(in: .whitespaces)
        guard !valueColumn.isEmpty, !keyPhrase.isEmpty, !tableName.isEmpty else { return nil }

        let (keyColumn, keyText) = splitTableLookupKeyPhrase(keyPhrase)
        guard !keyColumn.isEmpty, !keyText.isEmpty else { return nil }
        return .tableLookup(
            table: tableName,
            keyColumn: keyColumn,
            key: parse(keyText),
            valueColumn: valueColumn
        )
    }

    private func splitTableLookupKeyPhrase(_ keyPhrase: String) -> (column: String, key: String) {
        if let quote = keyPhrase.firstIndex(of: "\"") {
            let column = String(keyPhrase[keyPhrase.startIndex..<quote]).trimmingCharacters(in: .whitespaces)
            let key = String(keyPhrase[quote...]).trimmingCharacters(in: .whitespaces)
            return (column, key)
        }
        let parts = keyPhrase.split(separator: " ").map(String.init)
        guard parts.count > 1 else { return ("", keyPhrase) }
        return (parts.dropLast().joined(separator: " "), parts.last ?? "")
    }

    // MARK: - Possessive chain

    func parsePossessiveChain(_ s: String) -> ExpressionAST {
        // Strip article then split on "'s"
        let stripped = lexicon.stripLeadingArticle(s)

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
        parseTemplateSegments(body).segments
    }

    private func parseTemplateSegments(_ body: String, terminators: Set<String> = []) -> (segments: [InterpolationSegment], terminator: String?, rest: String) {
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
                let exprText = String(remaining[remaining.index(remaining.startIndex, offsetBy: 2)..<close.lowerBound])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !exprText.isEmpty {
                    if let formatted = parseFormattedInterpolation(exprText) {
                        segments.append(.formatted(formatted.expr, formatter: formatted.formatter))
                    } else {
                        segments.append(.expression(parse(exprText)))
                    }
                }
                remaining = String(remaining[close.upperBound...])
                continue
            }

            if lower.hasPrefix(template.ifPrefix) {
                guard let close = remaining.firstIndex(of: "]") else {
                    segments.append(.literal(remaining)); return (segments, nil, "")
                }
                let condText = String(remaining[remaining.index(remaining.startIndex, offsetBy: template.ifPrefix.count)..<close])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                let tail = String(remaining[remaining.index(after: close)...])
                let thenParsed = parseTemplateSegments(tail, terminators: [template.otherwiseTerminator, template.endIfTerminator])
                let elseParsed: (segments: [InterpolationSegment], terminator: String?, rest: String)
                if thenParsed.terminator == template.otherwiseTerminator {
                    elseParsed = parseTemplateSegments(thenParsed.rest, terminators: [template.endIfTerminator])
                } else {
                    elseParsed = ([], nil, thenParsed.rest)
                }
                segments.append(.conditional(condition: parse(condText), then: thenParsed.segments, otherwise: elseParsed.segments))
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
                let tail = String(remaining[remaining.index(after: close)...])
                let bodyParsed = parseTemplateSegments(tail, terminators: [template.endForTerminator])
                segments.append(.forEach(variable: parts.variable, collection: parse(parts.collection), body: bodyParsed.segments))
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
        return (parse(expr), formatter)
    }

    private func splitForEachHeader(_ header: String) -> (variable: String, collection: String) {
        if let range = header.range(of: lexicon.grammar.templateDirectives.loopInMarker, options: [.caseInsensitive]) {
            let variable = String(header[header.startIndex..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
            let collection = String(header[range.upperBound...]).trimmingCharacters(in: .whitespaces)
            return (variable.isEmpty ? "item" : variable, collection)
        }
        return ("item", header)
    }

    // MARK: - Helpers

    private func split(_ s: String, around markers: [String]) -> (String, String)? {
        // Find the marker only in *unquoted* regions of `s`. Splitting inside a
        // string literal — e.g. `"Your order is on hold"` — would otherwise
        // chop the literal at " is ".
        for marker in markers {
            let needle = " \(marker) "
            if let r = rangeOfMarkerOutsideQuotesCaseInsensitive(needle, in: s) {
                let lhs = String(s[s.startIndex ..< r.lowerBound]).trimmingCharacters(in: .whitespaces)
                let rhs = String(s[r.upperBound...]).trimmingCharacters(in: .whitespaces)
                return (lhs, rhs)
            }
        }
        return nil
    }

    private func rangeOfMarkerOutsideQuotes(_ marker: String, in s: String) -> Range<String.Index>? {
        QuoteAwareScanner.rangeOfMarker(marker, in: s)
    }

    private func rangeOfMarkerOutsideQuotesCaseInsensitive(_ marker: String, in s: String) -> Range<String.Index>? {
        QuoteAwareScanner.rangeOfMarker(marker, in: s, caseInsensitive: true)
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
        trace.log(.expression, "parseQuantifierIfPresent(\"\(s)\")")
        guard let (kind, rest0) = matchDeterminer(s) else { return nil }
        var rest = rest0.trimmingCharacters(in: .whitespaces)
        for p in lexicon.grammar.quantifierPartitiveMarkers where rest.lowercased().hasPrefix(p) {
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
        trace.log(.expression, "matchDeterminer(\"\(s)\")")
        func after(_ prefix: String) -> String { String(s.dropFirst(prefix.count)) }
        for marker in lexicon.grammar.quantifierDeterminers.all where lower.hasPrefix(marker) {
            trace.log(.expression, "matchDeterminer.all \(marker)")
            return (.all, after(marker))
        }
        for marker in lexicon.grammar.quantifierDeterminers.any where lower.hasPrefix(marker) {
            trace.log(.expression, "matchDeterminer.any \(marker)")
            return (.any, after(marker))
        }
        for marker in lexicon.grammar.quantifierDeterminers.none where lower.hasPrefix(marker) {
            trace.log(.expression, "matchDeterminer.none \(marker)")
            return (.none, after(marker))
        }
        for (kw, make): (String, (Int) -> QuantifierKindAST) in
            [
                (lexicon.grammar.quantifierDeterminers.atLeastPrefix, { .atLeast($0) }),
                (lexicon.grammar.quantifierDeterminers.atMostPrefix, { .atMost($0) }),
                (lexicon.grammar.quantifierDeterminers.exactlyPrefix, { .exactly($0) }),
            ] {
            if lower.hasPrefix(kw) {
                trace.log(.expression, "matchDeterminer.count \(kw)")
                let tail = after(kw).trimmingCharacters(in: .whitespaces)
                let parts = tail.split(separator: " ", maxSplits: 1).map(String.init)
                if let first = parts.first, let n = Int(first) {
                    return (make(n), parts.count > 1 ? parts[1] : "")
                }
            }
        }
        trace.log(.expression, "matchDeterminer.none")
        return nil
    }

    /// Split a quantifier remainder into (descriptionText, whereText, bodyText).
    /// `whose …` introduces a where-predicate; a copular/possessive verb
    /// (`have`/`has`/`are`/`is`/`contain`/`include`) introduces a per-element
    /// body (kept verbatim from the verb onward).
    private func splitDescriptionAndBody(_ s: String) -> (desc: String, whereText: String?, body: String?) {
        if let wr = rangeOfMarkerOutsideQuotesCaseInsensitive(lexicon.grammar.iterationMarkers.whoseMarker, in: s) {
            let desc = String(s[s.startIndex..<wr.lowerBound]).trimmingCharacters(in: .whitespaces)
            let cond = String(s[wr.upperBound...]).trimmingCharacters(in: .whitespaces)
            return (desc, cond, nil)
        }
        var earliest: Range<String.Index>? = nil
        for v in lexicon.grammar.quantifierBodyVerbs {
            if let r = rangeOfMarkerOutsideQuotesCaseInsensitive(v, in: s) {
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
        if let singular = lexicon.grammar.quantifierBodyNormalization[verb.lowercased()] {
            return singular + rest
        }
        return b
    }

    // MARK: - 3B/3C. Relational surface forms

    /// 3B: active verb predicate `<subject> <verbs> <object>` (`the user owns the
    /// page`). Splits on the earliest non-initial word that is an active (third
    /// person / base) form of a declared verb. Past participles are skipped (they
    /// are passive description clauses, not active predicates).
    private func parseActiveVerbIfPresent(_ s: String) -> ExpressionAST? {
        guard let sym = symbols, !sym.verbs.isEmpty else { return nil }
        guard rangeOfMarkerOutsideQuotes("\"", in: s) == nil else { return nil }
        let words = s.split(separator: " ").map(String.init)
        guard words.count >= 3 else { return nil }
        let relativizers = lexicon.grammar.relativizers
        // Do-support auxiliaries that carry the negation in front of a base verb
        // (`the entity does not link …`); contractions fuse the negator (`doesn't`).
        let auxiliaries = lexicon.grammar.negationAuxiliaries
        let negContractions = lexicon.grammar.negationContractions
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
            let notKeyword = lexicon.grammar.booleanConnectors.notPrefix.trimmingCharacters(in: .whitespaces)
            if prev == notKeyword, idx >= 2, auxiliaries.contains(words[idx - 2].lowercased()) {
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
        let s = lexicon.stripLeadingArticle(raw)
        for (kw, kind) in lexicon.aggregateIntroducers where s.lowercased().hasPrefix(kw) {
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
        let s = lexicon.stripLeadingArticle(raw)
        let lower = s.lowercased()
        let gradables = lexicon.superlativeGradables.keys.sorted {
            $0.count == $1.count ? $0 < $1 : $0.count > $1.count
        }
        guard let gradable = gradables.first(where: { lower == $0 || lower.hasPrefix($0 + " ") }) else {
            return nil
        }
        let restStart = s.index(s.startIndex, offsetBy: gradable.count)
        var rest = String(s[restStart...]).trimmingCharacters(in: .whitespaces)
        guard let dir = superlativeDirection(gradable) else { return nil }
        var property: String?
        if let r = rangeOfMarkerOutsideQuotesCaseInsensitive(lexicon.grammar.passiveByMarker, in: rest) {
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
        guard let dir = lexicon.superlativeGradables[g.lowercased()] else { return nil }
        return (dir.ascending, dir.needsBy)
    }

    /// 3C: scalar relation navigation `the <kind> <participle> {to|by} <operand>`
    /// (`the task assigned to the user`). The head must be a singular declared
    /// kind; a plural head is a passive description clause, handled elsewhere.
    private func parseScalarNavIfPresent(_ raw: String) -> ExpressionAST? {
        guard let sym = symbols else { return nil }
        let s = lexicon.stripLeadingArticle(raw)
        let words = s.split(separator: " ").map(String.init)
        guard words.count >= 4 else { return nil }
        for idx in 1..<(words.count - 1) {
            let w = words[idx].lowercased()
            guard let resolved = sym.resolveVerbForm(w), resolved.role == .pastParticiple else { continue }
            let conn = words[idx + 1].lowercased()
            guard lexicon.grammar.scalarNavConnectors.contains(conn) else { continue }
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
        var s = lexicon.stripLeadingArticle(raw)

        var take: Int?
        let leading = s.split(separator: " ").map(String.init)
        let first = lexicon.grammar.iterationMarkers.firstPrefix.trimmingCharacters(in: .whitespaces)
        if leading.count >= 2, leading[0].lowercased() == first, let n = Int(leading[1]) {
            take = n
            s = leading[2...].joined(separator: " ")
        }

        var sort: (property: String, ascending: Bool)?
        if let r = lexicon.sortByMarkers.lazy.compactMap({ rangeOfMarkerOutsideQuotesCaseInsensitive($0, in: s) }).first {
            var tail = String(s[r.upperBound...]).trimmingCharacters(in: .whitespaces)
            var asc = true
            if let m = lexicon.descendingMarkers.first(where: { tail.lowercased().hasSuffix(" " + $0) }) {
                asc = false; tail = String(tail.dropLast((" " + m).count))
            } else if let m = lexicon.ascendingMarkers.first(where: { tail.lowercased().hasSuffix(" " + $0) }) {
                tail = String(tail.dropLast((" " + m).count))
            }
            sort = (property: tail.trimmingCharacters(in: .whitespaces).lowercased(), ascending: asc)
            s = String(s[s.startIndex..<r.lowerBound]).trimmingCharacters(in: .whitespaces)
        }

        var wherePred: ExpressionAST?
        var verbClauses: [VerbClauseAST] = []
        var descPart = s

        if let wr = rangeOfMarkerOutsideQuotesCaseInsensitive(lexicon.grammar.iterationMarkers.whoseMarker, in: s) {
            descPart = String(s[s.startIndex..<wr.lowerBound]).trimmingCharacters(in: .whitespaces)
            wherePred = parse(String(s[wr.upperBound...]))
        } else if let tr = lexicon.grammar.relativeClauseMarkers.lazy
            .compactMap({ rangeOfMarkerOutsideQuotesCaseInsensitive($0, in: s) }).first {
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
        let s = lexicon.stripLeadingArticle(inner)
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
    /// Split a passive-clause fragment on the first top-level ` by ` marker
    /// (quote-aware). Returns the space-tokenized head words (before ` by `) and
    /// the trimmed operand (after it), or nil if there is no top-level ` by `.
    /// Shared prelude of `parsePassiveClauseSuffix` and `undeclaredPassiveVerbError`,
    /// which otherwise stay intentionally divergent (one requires the head's last
    /// word to resolve as a participle; the other requires it to NOT resolve).
    private func splitByClause(_ text: String) -> (head: [String], operand: String)? {
        guard let byR = rangeOfMarkerOutsideQuotesCaseInsensitive(lexicon.grammar.passiveByMarker, in: text) else { return nil }
        let head = String(text[text.startIndex..<byR.lowerBound]).trimmingCharacters(in: .whitespaces)
        let operand = String(text[byR.upperBound...]).trimmingCharacters(in: .whitespaces)
        return (head.split(separator: " ").map(String.init), operand)
    }

    private func parsePassiveClauseSuffix(_ descPart: inout String) -> VerbClauseAST? {
        guard let sym = symbols else { return nil }
        guard let (hw, operand) = splitByClause(descPart) else { return nil }
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
        let s = lexicon.stripLeadingArticle(raw)
        guard let (hw, operand) = splitByClause(s) else { return nil }
        guard hw.count >= 2, !operand.isEmpty, let cand = hw.last?.lowercased() else { return nil }
        let looksParticiple = lexicon.grammar.pastParticipleSuffixes.contains { cand.hasSuffix($0) }
        guard looksParticiple, sym.resolveVerbForm(cand) == nil else { return nil }
        let noun = hw[hw.count - 2].lowercased()
        let singular = lexicon.singularize(noun)
        guard sym.kinds[singular] != nil, noun != singular else { return nil }
        let hint = sym.verbFormSuggestion(for: cand)
        return .malformed("unknown relation verb \"\(cand)\"\(hint). Declare it with `The verb to <base> (it <3rd>, it is \(cand)) means the <relation> relation.`")
    }
}
