import Foundation

// MARK: - RewriteEngine
//
// Applies a rulebook's desugar rules to a single statement's text, turning a
// surface English idiom into a canonical Meridian statement that the
// StatementParser already understands.
//
// Semantics (per the plan):
//   • ordered by priority (descending) then source order,
//   • first-match-wins per pass,
//   • bounded fixpoint (reuses the depth-8 inline limit) so a rewrite whose
//     output matches another rule keeps desugaring until it stabilises.
//
// The engine is a pure text→text transform: its output is re-parsed and lowered
// through the identical strict pipeline, so a desugar rule can never introduce
// new semantics, widen tool scope, or reach the LLM.

public struct RewriteEngine {

    private let rules: [DesugarRule]
    private let trace: ParserTrace
    private let maxPasses = 8
    /// The source rulebook, retained so consumers (e.g. section-role lowering)
    /// can reach its section/convention rules without a second parse.
    public let rulebook: Rulebook

    public init(rulebook: Rulebook, trace: ParserTrace = .shared) {
        self.rulebook = rulebook
        // Higher priority first; stable within equal priority by source order.
        self.rules = rulebook.desugars.enumerated()
            .sorted { lhs, rhs in
                if lhs.element.priority != rhs.element.priority {
                    return lhs.element.priority > rhs.element.priority
                }
                return lhs.offset < rhs.offset
            }
            .map(\.element)
        self.trace = trace
    }

    public var isEmpty: Bool { rules.isEmpty }

    /// Desugar `text` to a fixpoint. Returns the rewritten text and whether any
    /// rule fired at all.
    @discardableResult
    public func rewrite(_ text: String) -> (text: String, changed: Bool) {
        guard !rules.isEmpty else { return (text, false) }
        var current = text
        var changed = false
        for _ in 0..<maxPasses {
            guard let (next, rule) = applyOnce(current), next != current else { break }
            trace.log(.rulebook, "rewrite [\(rule.name)]: \"\(current)\" ⇒ \"\(next)\"")
            current = next
            changed = true
        }
        return (current, changed)
    }

    /// Apply the first rule (in priority order) whose `match:` template fits.
    private func applyOnce(_ text: String) -> (String, DesugarRule)? {
        for rule in rules {
            guard let caps = RewriteEngine.match(rule.match, against: text) else { continue }
            return (RewriteEngine.substitute(rule.rewrite, with: caps), rule)
        }
        return nil
    }

    // MARK: - Matcher

    /// Match a literal/hole template against an input string, capturing holes.
    /// The template is anchored at the start of the input; a trailing literal,
    /// if present, must reach the end. Returns nil if the template does not fit.
    static func match(_ tokens: [RuleToken], against input: String) -> [String: String]? {
        guard !tokens.isEmpty else { return nil }
        let s = input
        var cursor = s.startIndex
        var caps: [String: String] = [:]
        var k = 0
        while k < tokens.count {
            switch tokens[k] {
            case .literal(let lit):
                let needle = lit.trimmingCharacters(in: .whitespaces)
                if needle.isEmpty { k += 1; continue }
                guard let r = rangeCI(of: needle, in: s, from: cursor) else { return nil }
                if k == 0 {
                    // Anchor the leading literal at the start (ignoring whitespace).
                    let pre = s[cursor..<r.lowerBound].trimmingCharacters(in: .whitespaces)
                    if !pre.isEmpty { return nil }
                }
                cursor = r.upperBound
                k += 1
            case .hole(let name):
                if k + 1 < tokens.count, case .literal(let nextLit) = tokens[k + 1] {
                    let needle = nextLit.trimmingCharacters(in: .whitespaces)
                    guard !needle.isEmpty, let r = rangeCI(of: needle, in: s, from: cursor) else { return nil }
                    let captured = String(s[cursor..<r.lowerBound]).trimmingCharacters(in: .whitespaces)
                    if captured.isEmpty { return nil }
                    caps[name] = captured
                    cursor = r.upperBound
                    k += 2
                } else {
                    let captured = String(s[cursor...]).trimmingCharacters(in: .whitespaces)
                    if captured.isEmpty { return nil }
                    caps[name] = captured
                    cursor = s.endIndex
                    k += 1
                }
            }
        }
        // A trailing literal must reach the end of the input.
        if case .literal = tokens.last {
            let tail = s[cursor...].trimmingCharacters(in: .whitespaces)
            if !tail.isEmpty { return nil }
        }
        return caps
    }

    /// Substitute `{name}` placeholders in a rewrite template with captures.
    static func substitute(_ template: String, with caps: [String: String]) -> String {
        var out = ""
        var i = template.startIndex
        while i < template.endIndex {
            let c = template[i]
            if c == "{", let close = template[i...].firstIndex(of: "}") {
                let name = String(template[template.index(after: i)..<close])
                    .trimmingCharacters(in: .whitespaces)
                out += caps[name] ?? ""
                i = template.index(after: close)
            } else {
                out.append(c)
                i = template.index(after: i)
            }
        }
        return out.trimmingCharacters(in: .whitespaces)
    }

    /// Case-insensitive search for `needle` in `s` starting at `from`.
    private static func rangeCI(of needle: String, in s: String, from: String.Index) -> Range<String.Index>? {
        s.range(of: needle, options: [.caseInsensitive], range: from..<s.endIndex)
    }
}
