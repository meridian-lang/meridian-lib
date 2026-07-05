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
| `MER1001` | malformed workflow header | structural | yes |
| `MER1002` | orphaned code block | structural | yes |
| `MER1003` | malformed statement | structural | yes |
| `MER1004` | unparseable rule | structural | yes |
| `MER1005` | malformed condition | structural | yes |
| `MER1006` | misplaced frontmatter | structural | yes |
| `MER1008` | removed import form | structural | yes |
| `MER1009` | sectioned document structural error | structural | yes |
| `MER1010` | uncheckable predicate | structural | yes |
| `MER1011` | invalid table cell | structural | yes |
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
| `MER3005` | invalid relation backing | other | recommended |
| `MER3016` | unlowerable rule predicate | other | recommended |

`MeridianLinter` advisory strings remain outside Wave 5D because lint does not
block compilation; bringing lint advice under `MERxxxx` is a separate decision.
