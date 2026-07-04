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
        if t.hasPrefix("$") { return .envVar(String(t.dropFirst())) }
        if matchesWholeKeyword("true", in: t) { return .literal(.boolean(true)) }
        if matchesWholeKeyword("false", in: t) { return .literal(.boolean(false)) }

        if (t.hasPrefix("\"") && t.hasSuffix("\"")) ||
            (t.hasPrefix("'") && t.hasSuffix("'")) {
            return .literal(.string(String(t.dropFirst().dropLast())))
        }

        if let dur = lexicon.parseDuration(t) { return .literal(.duration(dur.0, dur.1)) }
        if let d = Double(t), t.contains(".") { return .literal(.double(d)) }
        if let n = Int(t) { return .literal(.integer(n)) }

        return nil
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
