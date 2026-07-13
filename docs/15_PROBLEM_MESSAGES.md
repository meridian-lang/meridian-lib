# Meridian Problem Messages

Generated from `DiagnosticCode.catalog`.

Wave 5 introduces an Inform-style message template for new diagnostics:

```text
I read '<source span>' as <reading>, but <problem>. I expected <closed list>.
= help: Rewrite as: <concrete rewrite>
```

The canonical builder is `Diagnostic.problem(...)` in
`Sources/MeridianCore/Diagnostics/ProblemMessage.swift`. Name-resolution
diagnostics still use `Diagnostic.unresolved(...)` so they keep the
always-on did-you-mean guarantee; structural diagnostics can use the problem
template directly.

| Code | Title | Kind | Help Required |
|---|---|---|---|
| `MER0004` | internal compiler error | other | recommended |
| `MER1001` | malformed workflow header | structural | yes |
| `MER1002` | orphaned code block | structural | yes |
| `MER1003` | malformed statement | structural | yes |
| `MER1004` | unparseable rule | structural | yes |
| `MER1005` | malformed condition | structural | yes |
| `MER1006` | misplaced frontmatter | structural | yes |
| `MER1007` | unknown test-spec key | nameResolution | guided |
| `MER1008` | removed import form | structural | yes |
| `MER1009` | sectioned document structural error | structural | yes |
| `MER1010` | uncheckable predicate | structural | yes |
| `MER1011` | invalid table cell | structural | yes |
| `MER1012` | match branch missing colon | structural | yes |
| `MER2001` | unresolved phrase | nameResolution | guided |
| `MER2002` | unknown tool | nameResolution | guided |
| `MER2003` | unknown kind | nameResolution | guided |
| `MER2004` | unknown property | nameResolution | guided |
| `MER2005` | unknown vocabulary | nameResolution | guided |
| `MER2006` | unknown rulebook | nameResolution | guided |
| `MER2007` | unknown adjective | nameResolution | guided |
| `MER2008` | unknown verb | nameResolution | guided |
| `MER2009` | unknown allow-fallbacks kind | nameResolution | guided |
| `MER2010` | unknown trace category | nameResolution | guided |
| `MER2011` | missing phrase argument | nameResolution | guided |
| `MER2012` | unknown template formatter | nameResolution | guided |
| `MER3001` | phrase inlining too deep | other | recommended |
| `MER3002` | recursive definition | other | recommended |
| `MER3003` | duplicate declaration | other | recommended |
| `MER3004` | duplicate name | other | recommended |
| `MER3005` | invalid relation backing | other | recommended |
| `MER3006` | unattached rule | other | recommended |
| `MER3007` | unresolved trigger action | other | recommended |
| `MER3008` | tool-backed expression must be a statement | other | recommended |
| `MER3010` | ambiguous entry workflow | other | recommended |
| `MER3011` | prose not allowed | other | recommended |
| `MER3012` | operand out of scope | nameResolution | guided |
| `MER3013` | quantifier semantic error | other | recommended |
| `MER3014` | ambiguous anaphora | other | recommended |
| `MER3015` | invalid enum default | other | recommended |
| `MER3016` | unlowerable rule predicate | other | recommended |
| `MER3017` | unsupported trigger condition | other | recommended |
| `MER3018` | match branch semantic error | other | recommended |
| `MER-TMP-010` | bare perfect trace predicate | structural | yes |
| `MER-TMP-011` | trace window exceeds retention | other | recommended |
| `MER-TMP-012` | causal since form | structural | yes |
| `MER-TMP-013` | future trace predicate | structural | yes |
| `MER-TMP-014` | unknown trace step | nameResolution | guided |
| `MER-TMP-015` | unknown trace payload field | nameResolution | guided |
| `MER-TMP-016` | unkeyed temporal definition | other | recommended |
| `MER-TMP-017` | ambiguous recently | structural | yes |
| `MER-TMP-018` | progressive trace predicate | structural | yes |
| `MER-TMP-019` | unsupported since-the-last state predicate | structural | yes |
| `MER-TMP-020` | missing production trace capture policy | structural | yes |
| `MER-TMP-021` | cross-skill trace scope not supported | structural | yes |
| `MER-STA-001` | missing unknown arm | other | recommended |
| `MER-STA-003` | vague statistical frequency | structural | yes |
| `MER-REF-004` | note target binding undeclared | structural | yes |
| `MER-TYP-001` | note target binding is not text | structural | yes |
| `MER4001` | codegen error | other | recommended |
| `MER4002` | invalid IR | other | recommended |
| `MER5001` | swift-format failed | other | recommended |
| `MER5002` | unrecognized vocabulary declaration | structural | yes |
| `MER5003` | unknown rulebook section | nameResolution | guided |
| `MER5010` | unknown merconfig section | structural | yes |
| `MER5004` | malformed rulebook entry | structural | yes |
| `MER5005` | unrecognized block property | structural | yes |
| `MER5011` | unwritable trace file | other | recommended |
| `MER5012` | empty lexicon marker collection | other | recommended |
| `MER5013` | input file not found | other | recommended |
| `MER5014` | directory read failed | other | recommended |
| `MER6001` | polite command lint | other | recommended |
| `MER6002` | uncertainty lint | other | recommended |
| `MER6003` | migration fuzzy-route downgrade | other | recommended |
| `MER6004` | diagnostic recovery summary | other | recommended |
| `MER6005` | cross-run in-a-row lint | other | recommended |
| `MER6006` | superlative event-anchor lint | other | recommended |
| `MER-DEO-001` | deontic same-scope conflict | structural | yes |
| `MER-DEO-002` | deontic sticky deny | structural | yes |
| `MER-DEO-003` | deontic non-norm modal | structural | yes |
| `MER-DEO-004` | deontic tool outside permissions | structural | yes |
| `MER-DEO-005` | deontic outcome as action | structural | yes |
| `MER-DEO-006` | obligation id collision | structural | yes |
| `MER-DEO-007` | deontic unlowerable condition | structural | yes |
| `MER-MOD-001` | module not found | nameResolution | guided |
| `MER-MOD-002` | module import cycle | structural | yes |
| `MER-MOD-003` | module export collision | structural | yes |
| `MER-MOD-004` | sealed module export overridden | structural | yes |
| `MER-MOD-005` | duplicate module import | structural | yes |
| `MER-JDG-001` | effectful judgment without produced value | structural | yes |
| `MER-JDG-002` | judgment tool outside permissions | structural | yes |
| `MER-CND-001` | unknown comparator | structural | yes |
| `MER-DOM-002` | contradictory domain default | structural | yes |
| `MER-DSC-001` | superlative needs measurable backing | structural | yes |
