# Silent-path allowlist (Phase 0 inventory)

Machine-checked by `SilentFallbackAuditTests`. Every production hit of a
banned pattern must appear here with a classification, or the audit fails.

## Classifications

| Tag | Meaning |
|---|---|
| `probe` | Intentional silent probe during migration/marking (not user-facing) |
| `benchmark` | Benchmark harness noise control |
| `explicit-fallback` | Behind `allow-fallbacks:` only |
| `parser-non-match` | Production dispatch “try next parser”, not an error |
| `internal-invariant` | Compatibility/projection shim or unreachable compiler invariant with an explicit hard failure |
| `fix-target` | Known gap this DX closeout must eliminate; live hits with this tag fail the audit |

`Tests/` may use `.silent()` freely. The audit scans production `Sources/`
only, because tests often need deterministic silence regardless of
`MERIDIAN_TRACE`.

## `ParserTrace.silent()` / `trace: .silent()` in Sources/

| Path | Classification | Notes |
|---|---|---|
| `Sources/MeridianCore/Migration/TrialLowering.swift` | `probe` | Marking-pass probe parses |
| `Sources/MeridianCore/Migration/InertYieldAnalyzer.swift` | `probe` | Yield analysis probes |
| `Sources/MeridianCore/Grammar/ParserBenchmark.swift` | `benchmark` | Benchmark harness |

## Soft defaults / placeholders

| Path | Pattern | Classification |
|---|---|---|
| `Sources/MeridianCore/Lowering/ASTToIR.swift` | `_unresolved` BindIR | `explicit-fallback` |
| `Sources/MeridianCore/Compiler.swift` | `.legacySemantic/.legacySyntax projection` | `internal-invariant` |

The legacy syntax/semantic projection is deprecated and exists only to render
older `CompilerError` cases uniformly. Production sources must emit specific
diagnostic codes through `CompilerError.diagnostics`.

## Intentional non-matches (not silent errors)

Parser `return nil` / `break` that means “this production did not match” are
`parser-non-match` and are **not** listed individually. Match-branch case lines
without `:` are hard errors (`MER1012` from `StatementParser.parseMatchBranch`).
