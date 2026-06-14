# Coverage exclusions

This file is the single, reviewed source of truth for what is allowed to be
uncovered by `scripts/coverage.swift`. The coverage gate (`--gate`) treats every
in-scope `Sources/Meridian*` file as requiring **100% region coverage** unless it
appears below. Every entry MUST carry a justification.

**Policy.** Code that requires a *live external thing* — a spawned subprocess, a
network endpoint, a SwiftPM toolchain build, an LLM provider, terminal I/O the
test can't capture — does not need 100% and keeps a relaxed floor permanently
(bucket A below). **Everything else must aim for 100%**: a floor on reachable,
in-process code (bucket B) is a temporary target, ratcheted up as tests land and
removed once the file hits 100%. The only acceptable permanent sub-100 floor for
reachable code is a genuinely unreachable line (e.g. an `internal:`
`preconditionFailure`), and it must be named in a comment. Full rationale:
[`README.md`](README.md).

`llvm-cov report` measures per *file*, not per line, so exclusions are expressed
at file granularity. Where only a few lines inside an otherwise-covered file are
unreachable, prefer a `file-thresholds` override (with the uncovered range noted)
over a blanket `exclude-files` entry.

Two mechanisms:

- **`exclude-files`** — path substrings removed from the denominator entirely
  (folded into `llvm-cov -ignore-filename-regex`). Use only for code that cannot
  be meaningfully unit-tested in-process.
- **`file-thresholds`** — `path-substring = min-region-percent`. The file stays
  in the denominator but is allowed below 100% at the stated level. The number is
  a **regression floor**: it is the coverage already achieved, so the gate fails
  the moment a change drops a file below where it stands today. Tighten the floor
  (toward 100) as more of the file's reachable branches gain tests.

Always-excluded by the script regardless of this file: `.build/`, `/Tests/`,
`/checkouts/`, and `Sources/SampleDemoFlows/`.

## Rationale: `Sources/SampleDemoFlows/*`

`EcommerceWorkflows`, `GeneratedOrderProcessing`, and `OrderProcessingDemo` are
reference / committed-generated fixtures, not library code. They are exercised
for behavior by `MeridianIntegrationTests` (run + event goldens), not held to a
coverage bar. Excluded from the denominator entirely (hard-coded in the script).

## Excluded files

```exclude-files
# (none — every in-scope file stays in the denominator with a regression floor
#  below, so even the integration-heavy files still catch coverage drops.)
```

## Per-file thresholds

Floors are the region% each file has reached with deterministic in-process tests.
They fall into two buckets:

**(A) Integration boundaries — the uncovered tail genuinely cannot be exercised
in-process.** These files drive real external processes or network I/O whose
success paths require a live toolchain / server / subprocess:

- CLI subcommands (`MeridianCLIKit/*`) — `run()` bodies print to stdout/stderr,
  read/write the real filesystem, and in several cases shell out (`run`,
  `migrate-skill`, `skill-deviation`, `resume`, `test`). Pure-logic helpers are
  covered; the process-spawning and terminal-output tails are not.
- `Testing/RuntimeExecutor`, `Testing/SwiftPMPackageRunner` — scaffold and
  `swift build` / `swift run` a temp SwiftPM package. Early-return and
  pure-string portions are covered; the build/run subprocess tail is not.
- `Tools/ToolRegistry` — HTTP / MCP / subprocess dispatch needs a live endpoint.
  Registration, schema, closure, and error-wrapping paths are covered.
- `Planning/PlanExecutor`, `Planning/ActPlanner`, `Planning/Planner`,
  `MockPlanning` — the LLM planning loop requires a provider; value-type and
  policy paths are covered.

**(B) Reachable residual — defensive guards, `preconditionFailure`s, dead
"future-pass" code, and a few hard-to-trigger error branches** (e.g.
`WholeWordRegex`'s constant-pattern `preconditionFailure` — the codebase's single
sanctioned unreachable arm for that construct — `TraceTreeRenderer`'s
not-yet-wired nested-block `Frame` stack, golden write-failure arms). These floors
should be ratcheted toward 100 as tests land.

```file-thresholds
# path-substring                                          = min-region-percent
MeridianCLIKit/CLISupport.swift                            = 47
MeridianCLIKit/Commands/CompileCommand.swift               = 83
MeridianCLIKit/Commands/DecisionsCommand.swift             = 97
MeridianCLIKit/Commands/DocsCommand.swift                  = 94
MeridianCLIKit/Commands/ExplainCommand.swift               = 76
MeridianCLIKit/Commands/FormatCommand.swift                = 94
MeridianCLIKit/Commands/LintCommand.swift                  = 54
MeridianCLIKit/Commands/MigrateSkillCommand.swift          = 31
MeridianCLIKit/Commands/ResumeCommand.swift                = 45
MeridianCLIKit/Commands/RunCommand.swift                   = 23
MeridianCLIKit/Commands/SkillDeviationCommand.swift        = 21
MeridianCLIKit/Commands/TestCommand.swift                  = 72
MeridianCLIKit/Commands/TraceRenderCommand.swift           = 85
MeridianCore/AST/MeridianAST.swift                         = 97
MeridianCore/Codegen/DomainEmitter.swift                   = 91
MeridianCore/Codegen/ManifestEmitter.swift                 = 98
MeridianCore/Codegen/SwiftEmitter.swift                    = 92
MeridianCore/Compiler.swift                                = 86
MeridianCore/Diagnostics/Diagnostic.swift                  = 89
MeridianCore/Diagnostics/DiagnosticRenderer.swift          = 96
MeridianCore/Diagnostics/ParserTrace.swift                 = 87
MeridianCore/Docs/MerconfigDocsRenderer.swift              = 93
MeridianCore/Language/EnglishLexicon.swift                 = 97.5
# WholeWordRegex: the single `else { preconditionFailure }` arm is unreachable —
# the pattern always comes from NSRegularExpression.escapedPattern, so it can
# only fail on a Foundation bug (and `!` is banned by house rules). Permanent.
MeridianCore/Language/WholeWordRegex.swift                 = 83
MeridianCore/Lowering/ASTToIR.swift                        = 80.7
MeridianCore/Lowering/ConventionInjector.swift             = 73
MeridianCore/Lowering/RuleInjector.swift                   = 75
MeridianCore/Lowering/RuleLowering.swift                   = 83
MeridianCore/Lowering/SkillTriggers.swift                  = 88
MeridianCore/Migration/Difflib.swift                       = 98
MeridianCore/Migration/SkillDeviation.swift                = 90
MeridianCore/Migration/SkillMigrator.swift                 = 90
MeridianCore/Parser/Lexical/ExpressionParser.swift         = 88.9
MeridianCore/Parser/Lexical/HeaderFolder.swift             = 94.4
MeridianCore/Parser/Lexical/IndentTokenizer.swift          = 90
MeridianCore/Parser/Productions/MerConfigParser.swift      = 88
MeridianCore/Parser/Productions/MeridianParser.swift       = 94
MeridianCore/Parser/Productions/StatementParser.swift      = 89
MeridianCore/Parser/Productions/TableParser.swift          = 84
MeridianCore/Parser/Skill/SectionRoleResolver.swift        = 88
MeridianCore/Parser/Skill/SkillSectionBuilder.swift        = 87
MeridianCore/Rulebook/Rulebook.swift                       = 96
MeridianCore/Rulebook/RulebookParser.swift                 = 85
MeridianCore/Symbols/SymbolTable.swift                     = 94
MeridianCore/Testing/Assertions.swift                      = 81
# IRWalker.swift now at 100% — floor removed.
MeridianCore/Testing/MeridianTestRunner.swift              = 80
MeridianCore/Testing/RuntimeExecutor.swift                 = 38
MeridianCore/Testing/SpecParser.swift                      = 88
MeridianCore/Testing/SwiftPMPackageRunner.swift            = 46
# Checkpointer: FilesystemCheckpointer's fd-open failure arms (fsync/lock when
# open(2) fails) and the cachesDirectory default init are the residual — disk
# fault injection, an integration boundary.
MeridianRuntime/Checkpoints/Checkpointer.swift             = 83
MeridianRuntime/Comparison/Comparison.swift                = 99
# Observer: JSONSerialization failure fallback (line ~94) is unreachable for the
# always-serializable dict; the rest needs real file I/O fault paths.
MeridianRuntime/Events/Observer.swift                      = 92
MeridianRuntime/Planning/ActPlanner.swift                  = 75
MeridianRuntime/Planning/PlanExecutor.swift                = 42
MeridianRuntime/Planning/Planner.swift                     = 80
MeridianRuntime/Runtime.swift                              = 83
MeridianRuntime/State/State.swift                          = 95
MeridianRuntime/Tools/ToolRegistry.swift                   = 74
MeridianRuntime/Tracing/TraceTreeRenderer.swift            = 81
# ValueCoercion: the 3 residual regions are unreachable cast-fail arms — after a
# runtime type-guard (`if T.self == Date.self`) the `as? T` conditional cast can
# never fail, but Swift requires the fail-branch syntactically (T is generic).
MeridianRuntime/Value/ValueCoercion.swift                  = 96
# EventAssertions: residual is the unreachable JSONSerialization re-encode
# failure fallback (the dict is always serializable).
MeridianTestKit/EventAssertions.swift                      = 93
# MockPlanning: residual is the unused MockPlanner(proposals:) convenience init.
MeridianTestKit/MockPlanning.swift                         = 92
# WorkflowTestHarness: firstEvent/durationFromEvents need a full harness run
# (workflow execution) — covered indirectly elsewhere, floored here.
MeridianTestKit/WorkflowTestHarness.swift                  = 88
# JSONLReplay / GoldenFile / MockToolRegistry / PlanFuzzer / RecordingTool now
# at 100% — no floors needed.
# MeridianTools: residual is the http/shell/mcp dispatch specs (integration
# boundaries) + the unreachable stringify nil-fallback.
MeridianTools/MeridianTools.swift                          = 96
```
