# Silent-path allowlist (Observability DX Phase 1)

Machine-checked by `SilentFallbackAuditTests`. Every production hit of a
banned pattern must appear here with full metadata, or the audit fails.

## Classifications

| Tag | Meaning |
|---|---|
| `probe` | Intentional silent probe during migration/marking (not user-facing) |
| `benchmark` | Benchmark harness noise control |
| `explicit-fallback` | Deliberate degrade path with a user-visible signal or opt-in gate |
| `parser-non-match` | Production dispatch “try next parser”, not an error |
| `internal-invariant` | Compatibility shim, test harness default, or bounded runtime invariant |
| `fix-target` | **Forbidden in allowlist** — known gap that must be fixed, not approved |

`Tests/` may use `.silent()` freely for deterministic harness behavior. The
audit scans `Tests/` only for `traceCapture?.trace ?? .silent()` defaults.

## Table columns

| Path | Pattern | Classification | Rationale | User-visible signal | Owning test | Explicit opt-in |
|---|---|---|---|---|---|---|

## `ParserTrace.silent()` / `trace: .silent()` in Sources/

| Path | Pattern | Classification | Rationale | User-visible signal | Owning test | Explicit opt-in |
|---|---|---|---|---|---|---|
| `Sources/MeridianCore/Migration/TrialLowering.swift` | `.silent()` | `probe` | Marking-pass probe parses must not inherit caller trace noise | none — intentional | `SkillMigratorMarkingTests` | no |
| `Sources/MeridianCore/Migration/InertYieldAnalyzer.swift` | `.silent()` | `probe` | Yield analysis probes parse/check without polluting migration trace | none — intentional | `InertYieldCommandTests` | no |
| `Sources/MeridianCore/Migration/SkillMigrator+SplitPlan.swift` | `catch return` | `probe` | Rule-shape probe treats `classify` throw as non-match for permission heuristics | none — intentional | `SkillMigratorMarkingTests` | no |
| `Sources/MeridianCore/Grammar/ParserBenchmark.swift` | `.silent()` | `benchmark` | Benchmark harness compares screened vs unscreened dispatch | none — intentional | `BenchParseCommandTests` | no |

## Test harness trace defaults

| Path | Pattern | Classification | Rationale | User-visible signal | Owning test | Explicit opt-in |
|---|---|---|---|---|---|---|
| `Sources/MeridianCore/Testing/MeridianTestRunner.swift` | `traceCapture` | `internal-invariant` | `.meridian.test` runner defaults to silent trace unless a spec captures it | none — harness default | `MeridianTestRunnerTests` | no |

## Soft defaults / placeholders

| Path | Pattern | Classification | Rationale | User-visible signal | Owning test | Explicit opt-in |
|---|---|---|---|---|---|---|
| `Sources/MeridianCore/Lowering/ASTToIR+PhraseInvocation.swift` | `_unresolved` | `explicit-fallback` | Emits placeholder bind only behind `allow-fallbacks: unresolved-phrases` | compiler warning diagnostic | `Phase3ForcingFunction` | yes |

## Trace file sink degrade path

ParserTrace file-sink failures now use `do/catch` with MER5011 stderr fallback
(no `try?` on write/close). Covered by `ParserTraceTests`.

## Catch swallow patterns (high-risk only)

| Path | Pattern | Classification | Rationale | User-visible signal | Owning test | Explicit opt-in |
|---|---|---|---|---|---|---|
| `Sources/MeridianCore/Testing/Assertions.swift` | `catch return` | `internal-invariant` | Golden-file helper returns descriptive failure string instead of throwing | returned assertion message | `MeridianTestRunnerTests` | no |
| `Sources/MeridianCore/Testing/MeridianTestRunner.swift` | `catch return` | `internal-invariant` | Batch compile maps per-file failure into `(url, .failure)` result | aggregated spec failure report | `MeridianTestRunnerTests` | no |
| `Sources/MeridianCore/Testing/DriverSourceBuilder.swift` | `catch swallow` | `internal-invariant` | Shared driver emitter closes the `.meridian.test` driver's `Task` with an empty catch in the emitted Swift template | subprocess compile stderr | `RuntimeExecutorSlowTests` | no |
| `Sources/MeridianRuntime/Runtime+Assert.swift` | `catch return` | `internal-invariant` | Monitor background task exits cleanly when `clock.sleep` is cancelled | none — task lifecycle | `MonitorLifecycleTests` | no |

## Intentional non-matches (not silent errors)

Parser `return nil` / `break` that mean “this production did not match” are
`parser-non-match` and are **not** listed individually. Match-branch case lines
without `:` are hard errors (`MER1012` from `StatementParser.parseMatchBranch`).

## `try?` in Lowering / Parser (scoped audit)

| Path | Pattern | Classification | Rationale | User-visible signal | Owning test | Explicit opt-in |
|---|---|---|---|---|---|---|
| `Sources/MeridianCore/Parser/Lexical/Productions/LiteralGrammar.swift` | `try?` | `parser-non-match` | pegex `Keyword` probe — `false` means the word did not match as a whole keyword | none — production did not match | `Inform7Wave3/4Tests` | no |

`RuleLowering.swift` deontic condition lowering now hard-errors with `MER-DEO-007`
(plan step 3; DX-RULE-003 closed).
