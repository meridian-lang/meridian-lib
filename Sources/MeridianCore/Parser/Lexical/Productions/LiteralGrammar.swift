import Foundation
import Parsing
import PegexBuilder

/// `literal-atom` (`GrammarTable`, `.pegex`): `now`, `$ENV_VAR`, `true`/`false`,
/// single/double-quoted strings, durations (`1 hour`), floats, and integers.
///
/// Fixed keywords (`now`/`true`/`false`) are matched with `pegex`'s `Keyword`,
/// which is word-boundary-aware and requires the whole trimmed atom to be
/// consumed (no trailing content) — the same "this token, and nothing else"
/// requirement the pre-rewrite `t == "now"` equality enforced.
///
/// `$`-prefixed tokens always resolve to an env-var reference. A money literal
/// branch (`$5000` → `.literal(.money(...))`) is deliberately **not**
/// implemented here: the pre-rewrite env-var check ran unconditionally before
/// the money check, so every `$`-prefixed atom already took the env-var branch
/// and the money branch was unreachable dead code (see
/// `ExpressionParserGoldenTests`'s `lit-dollar-shadows-money` case, which pins
/// `$5000` → `$5000` as an env-var, not a money literal).
struct LiteralGrammar {
    let lexicon: EnglishLexicon

    func parse(_ s: String) -> ExpressionAST? {
        let t = s.trimmingCharacters(in: .whitespaces)
        if t.isEmpty { return nil }

        if matchesWholeKeyword("now", in: t) { return .now }
        if t.hasPrefix("$") {
            // `$5000` / `$5000.00 AUD` — a money literal, the same form the
            // `.merconfig` constant parser accepts (docs/03 "value forms").
            // `$NAME` stays an environment-variable reference; a name that can
            // be neither (`$1000x`) is rejected rather than silently read as an
            // env var that evaluates to "".
            let body = String(t.dropFirst())
            if let money = Self.parseMoneyLiteral(body) { return .literal(.money(money.0, currency: money.1)) }
            guard let first = body.first, first.isLetter || first == "_" else {
                return .malformed("\(t)` is not an environment variable name or a money amount")
            }
            return .envVar(body)
        }
        if matchesWholeKeyword("true", in: t) { return .literal(.boolean(true)) }
        if matchesWholeKeyword("false", in: t) { return .literal(.boolean(false)) }

        if (t.hasPrefix("\"") && t.hasSuffix("\"")) ||
            (t.hasPrefix("'") && t.hasSuffix("'")) {
            return .literal(.string(String(t.dropFirst().dropLast())))
        }

        if let cal = lexicon.parseCalendarAmount(t) { return .literal(.calendarAmount(cal.0, cal.1)) }
        if let dur = lexicon.parseDuration(t) { return .literal(.duration(dur.0, dur.1)) }
        if let d = Double(t), t.contains(".") { return .literal(.double(d)) }
        if let n = Int(t) { return .literal(.integer(n)) }

        return nil
    }

    /// `5000` or `5000.00 AUD` → (amount, currency); `nil` when the text is not
    /// a money amount. Default currency is USD, matching the .merconfig parser.
    static func parseMoneyLiteral(_ body: String) -> (Double, String)? {
        let parts = body.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
        guard let amount = Double(parts.first ?? ""), parts.count <= 2 else { return nil }
        let currency = parts.count == 2 ? parts[1].uppercased() : "USD"
        guard currency.allSatisfy({ $0.isLetter }), !currency.isEmpty else { return nil }
        return (amount, currency)
    }

    /// True when `text`, trimmed and with no remainder, is exactly the keyword
    /// `word` — validated with `pegex`'s `Keyword` rather than `==` so the
    /// match is the same word-boundary-aware primitive used across the other
    /// pegex productions.
    private func matchesWholeKeyword(_ word: String, in text: String) -> Bool {
        var input = text[...]
        guard (try? Keyword<Substring>(words: [word]).parse(&input)) != nil else { return false }
        return input.isEmpty
    }
}
