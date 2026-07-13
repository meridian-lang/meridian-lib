# Lexicon vocabulary allowlist (codebase quality cleanup)

Machine-checked by `LexiconVocabularyAuditTests`. Scans
`Sources/MeridianCore/{Parser,Lowering,Codegen,Verbalizer,Migration}` for
banned English-surface hardcoding patterns that belong in `EnglishLexicon`,
`FixedGrammar`, or `=== language ===`.

## Classification

| Classification | Meaning |
|---|---|
| `fixed-grammar` | Structural control-flow / merconfig skeleton living in `FixedGrammar` or a single production |
| `sentinel` | Non-NL structural marker (`\u{E000}`, fence delimiters) |
| `swift-emit` | Emitted Swift keyword/API string (codegen) |
| `test-fixture` | Not scanned (Tests/) |
| `retained-exception` | Justified residual with rationale |

## Entries

| Path | Pattern | Classification | Rationale | Owning test |
|---|---|---|---|---|
| `Sources/MeridianCore/Language/FixedGrammar.swift` | `*` | `fixed-grammar` | Canonical home for structural markers | GrammarTableTests |
| `Sources/MeridianCore/Language/EnglishLexicon.swift` | `*` | `fixed-grammar` | Default seed tables | LexiconCentralizationTests |
| `Sources/MeridianCore/Grammar/**` | `*` | `fixed-grammar` | PegexSurfaceGrammar anchors sourced from lexicon/grammar | GrammarTableTests |
| `Sources/MeridianCore/Parser/Lexical/IndentTokenizer.swift` | `shellFenceLanguages` | `retained-exception` | Module-level default seed for `EnglishLexicon.default.shellFenceLanguages` | ShellFenceLexiconTests |
| `Sources/MeridianCore/Parser/Lexical/IndentTokenizer.swift` | `isShellFence` | `retained-exception` | Free function for lexicon-free paths only; migrator/metrics use `lexicon.isShellFence` | LexiconPhase1RecipeTests |
| `Sources/MeridianCore/Codegen/**` | `"` | `swift-emit` | Swift emitter string templates | SwiftEmitterTests |
