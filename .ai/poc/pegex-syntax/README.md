# Pegex Syntax POC

This standalone SwiftPM package is a living test bed for Meridian syntax work.
It proves that `PegexBuilder` can express the natural-language parser shapes
needed by Inform-7 Wave 5 before those shapes are moved into `MeridianCore`.

Run it from this directory:

```bash
swift run
```

## What It Proves

The current executable asserts these cases:

- Data-driven, longest-match comparators: `is`, `is not`, `is more than`,
  `is at least`, and friends all come from one table sorted longest-first.
- Quote shielding: `label is "a is b"` does not split on the inner `is`.
- Multi-word operands: `total amount` is consumed until a comparator marker.
- Boolean precedence: `not` binds tighter than `and`, which binds tighter than
  `or`; `either ... or ...` is an explicit grouping form.
- Recursive descriptions: quantified descriptions with adjectives and chained
  `whose` clauses parse deterministically.
- Symbol closures: productions can close over a mock registry of declared kinds,
  adjectives, and verbs, matching the real `(SymbolTable, EnglishLexicon)` shape.
- Sentinel passthrough: private-use `\u{E000}` / `\u{E001}` atoms can be treated
  as first-class parser atoms.
- Construction-cost measurement: the executable prints 10k grammar-construction
  vs 10k parse timings so Wave 5 can choose a cache boundary deliberately.
- Located diagnostics: malformed input maps to a line/column/offset through
  `parseWithLocation`.

## Extending It

When a future syntax question is risky, add the smallest possible parser and a
named assertion here first. Keep the POC focused on parser mechanics that are
hard to validate from existing SQL-style pegex examples:

1. Add a compact AST case if needed.
2. Add the parser helper.
3. Add one assertion in `main.swift`.
4. Run `swift run`.

If the POC exposes a genuine pegex API gap, fix `../pegex` or the upstream
package before adding a Meridian-specific workaround.
