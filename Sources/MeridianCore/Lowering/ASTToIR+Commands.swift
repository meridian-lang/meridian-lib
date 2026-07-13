import Foundation
import MeridianRuntime

// Shell command hole lowering — extracted from ASTToIR for Phase 3 readability.

extension ASTToIR {

    // MARK: - Command holes (1B)

    /// Lower a decoded shell command into a string literal (no holes) or an
    /// interpolated string with `{…}` holes resolved. A `{…}` span is a typed
    /// hole: its content is parsed as an expression and its identifier roots are
    /// validated against `scope`. `{{`/`}}` are literal braces. A hole inside a
    /// double-quoted span is shell-escaped at runtime (`meridianShellQuote`); a
    /// hole outside quotes interpolates verbatim. An unresolved hole is a hard
    /// sourced error (it cannot silently become a literal).
    func lowerShellCommand(_ command: String, scope: Set<String>, sourceLine: Int) throws -> IRExpression {
        var segments: [IRInterpolationSegment] = []
        var literal = ""
        var inQuote = false
        let chars = Array(command)
        var i = 0
        while i < chars.count {
            let c = chars[i]
            if c == "{", i + 1 < chars.count, chars[i + 1] == "{" {
                literal.append("{"); i += 2; continue
            }
            if c == "}", i + 1 < chars.count, chars[i + 1] == "}" {
                literal.append("}"); i += 2; continue
            }
            if c == "{" {
                // `${…}` is shell parameter expansion, never a hole.
                let precededByDollar = i > 0 && chars[i - 1] == "$"
                var j = i + 1
                var holeText = ""
                var closed = false
                while j < chars.count {
                    if chars[j] == "}" { closed = true; break }
                    holeText.append(chars[j]); j += 1
                }
                guard closed else { literal.append(c); i += 1; continue }
                let exprText = holeText.trimmingCharacters(in: .whitespaces)
                // A `{…}` is a typed hole only when its content is reference-
                // shaped English (words/possessives) and it is not `${…}`. Code-
                // shaped braces (XML namespaces, awk `{print …}`, brace
                // expansion `{a,b}`, JSON) carry non-word characters and stay
                // literal — shell commands routinely contain them. A literal
                // brace whose content *is* word-shaped is written `{{…}}`.
                if !precededByDollar, isReferenceLikeHole(exprText) {
                    if !literal.isEmpty { segments.append(.literal(literal)); literal = "" }
                    let parsed = ExpressionParser(
                        symbols: symbols,
                        trace: trace,
                        lexicon: lexicon
                    ).parse(exprText)
                    let lowered = try lowerExpr(parsed)
                    let unresolved = freeIdentifierRoots(lowered).filter { !scope.contains(scopeKey($0)) }
                    if let bad = unresolved.first {
                        throw CompilerError.diagnostics([
                            Diagnostic.unresolved(
                                .commandHoleOutOfScope,
                                target: bad,
                                among: Array(scope),
                                range: sourceRange(sourceLine),
                                noun: "reference",
                                help: "Command hole \"{\(exprText)}\" is not in scope. Reference a workflow parameter, earlier bind, loop variable, or escape with `{{`/`}}`.")
                        ])
                    }
                    segments.append(inQuote ? .shellEscapedExpression(lowered) : .expression(lowered))
                } else {
                    literal.append("{")
                    literal.append(contentsOf: holeText)
                    literal.append("}")
                }
                i = j + 1
                continue
            }
            if c == "\"" { inQuote.toggle() }
            literal.append(c)
            i += 1
        }
        if !literal.isEmpty { segments.append(.literal(literal)) }
        let hasExpr = segments.contains { if case .literal = $0 { return false } else { return true } }
        guard hasExpr else { return .literal(.string(command)) }
        return .interpolatedString(segments)
    }

    /// A `{…}` span is a typed hole only when its content is "reference-shaped":
    /// English words, possessives, articles — letters/digits/spaces plus
    /// apostrophes, hyphens, and underscores, with at least one letter. Any
    /// other character (`/ : . , $ ( ) ; | …`) marks it as code-shaped shell
    /// syntax that stays literal. This is what lets holes and ordinary shell
    /// braces (XML namespaces, awk, brace expansion, JSON) coexist.
    private func isReferenceLikeHole(_ s: String) -> Bool {
        guard !s.isEmpty else { return false }
        var sawLetter = false
        for ch in s {
            if ch.isLetter { sawLetter = true; continue }
            if ch.isNumber || ch == " " || ch == "'" || ch == "\u{2019}" || ch == "-" || ch == "_" { continue }
            return false
        }
        return sawLetter
    }

    /// Free identifier roots referenced by a lowered expression (the base name
    /// of each property-access chain / bare reference). Constants, instances,
    /// literals, env vars, and `now` contribute nothing — they are always
    /// resolvable. Used to validate command holes against the scope set.
    func freeIdentifierRoots(_ e: IRExpression) -> [String] {
        switch e {
        case .identifierRef(let n):
            return [n]
        case .propertyAccess(let base, _):
            return freeIdentifierRoots(base)
        case .comparison(let a, _, let b):
            return freeIdentifierRoots(a) + freeIdentifierRoots(b)
        case .logical(_, let xs):
            return xs.flatMap(freeIdentifierRoots)
        case .relationTraversal(let base, _, let target):
            return freeIdentifierRoots(base) + (target.map(freeIdentifierRoots) ?? [])
        case .invocation(let ir):
            return ir.arguments.flatMap { freeIdentifierRoots($0.value) }
        case .tableLookup(_, _, let key, _):
            return freeIdentifierRoots(key)
        case .interpolatedString(let segs):
            return segs.flatMap { seg -> [String] in
                switch seg {
                case .literal:                       return []
                case .expression(let x):             return freeIdentifierRoots(x)
                case .conditional(let c, let t, let o):
                    return freeIdentifierRoots(c) + t.flatMap { _ in [] } + o.flatMap { _ in [] }
                case .forEach(_, let c, _):          return freeIdentifierRoots(c)
                case .formatted(let x, _):           return freeIdentifierRoots(x)
                case .shellEscapedExpression(let x):  return freeIdentifierRoots(x)
                }
            }
        default:
            return []
        }
    }

}
