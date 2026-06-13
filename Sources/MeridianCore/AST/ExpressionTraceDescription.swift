extension ExpressionAST {

    /// Detail level for `traceDescription`. `.verbose` renders full comparison /
    /// logical trees (used by `ExpressionParser`'s parse trace); `.compact`
    /// collapses them to `cmp(...)` / `logical(...)` and elides operands (used by
    /// `SymbolTable`'s phrase-match trace, where the surrounding line already
    /// carries the detail).
    enum TraceDetail { case verbose, compact }

    /// Human-readable one-line rendering of this expression for `ParserTrace`
    /// diagnostics. Single source for what were two divergent `describe`
    /// switches; the only differences are folded into `detail`.
    func traceDescription(detail: TraceDetail) -> String {
        func sub(_ e: ExpressionAST) -> String { e.traceDescription(detail: detail) }
        switch self {
        case .literal(.string(let s)):          return "\"\(s)\""
        case .literal(.integer(let n)):         return "\(n)"
        case .literal(.double(let d)):          return "\(d)"
        case .literal(.boolean(let b)):
            return detail == .verbose ? "\(b)" : "lit"
        case .literal(.money(let a, let c)):
            return detail == .verbose ? "$\(a)\(c)" : "lit"
        case .literal(.duration(let v, let u)):
            return detail == .verbose ? "\(v) \(u)" : "lit"
        case .identifierRef(let n):             return "id(\(n))"
        case .instanceRef(let n):               return "inst(\(n))"
        case .constantRef(let n):               return "const(\(n))"
        case .propertyAccess(let b, let p):     return "\(sub(b)).\(p)"
        case .comparison(let l, let op, let r):
            return detail == .verbose ? "(\(sub(l)) \(op) \(sub(r)))" : "cmp(...)"
        case .logical(let op, let xs):
            return detail == .verbose
                ? "logical(\(op), [\(xs.map { sub($0) }.joined(separator: ", "))])"
                : "logical(...)"
        case .invoke(let tool, _):              return "invoke(\(tool))"
        case .envVar(let n):                    return "$\(n)"
        case .now:                              return "now"
        case .decideWhether(let q):             return "decide(\(q))"
        case .interpolatedString(let segs):     return "interp(\(segs.count) segs)"
        case .recordList(let f, let rows):      return "recordList(\(f.count) fields, \(rows.count) rows)"
        case .quantified(let q):
            return detail == .verbose ? "quant(\(q.kind), \(q.description.noun))" : "quant(\(q.kind))"
        case .verbPredicate(let s, let v, let o):
            return detail == .verbose ? "verb(\(sub(s)) \(v) \(sub(o)))" : "verb(\(v))"
        case .relationTraversal(let b, let r, _):
            return detail == .verbose ? "rel(\(sub(b)) ~ \(r))" : "rel(\(r))"
        case .description(let d):               return "desc(\(d.noun))"
        case .aggregate(let k, let d):          return "agg(\(k), \(d.noun))"
        case .superlative(let s):
            return detail == .verbose
                ? "super(\(s.ascending ? "min" : "max") \(s.property) of \(s.description.noun))"
                : "super(\(s.property))"
        case .malformed(let m):                 return "malformed(\(m))"
        }
    }
}
