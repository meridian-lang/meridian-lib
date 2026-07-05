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

**Tooling note (Inform I7 closeout, 2026-07-04):** `scripts/coverage.swift`'s
per-file row parser was silently broken in this checkout — the report path
that `llvm-cov report` prints embeds this workspace's leading directory name,
which happens to contain a literal space, corrupting whitespace-delimited
column parsing so **every** per-file row was dropped (only `TOTAL` survived)
and `--gate` passed vacuously regardless of real coverage. Fixed by switching
to `llvm-cov export` (JSON) and matching in-scope rows by path *component*
rather than by string prefix. This is the first run with a working gate since
some `SkillMigrator+*.swift` split files and `InertYieldAnalyzer.swift` /
`InertYieldCommand.swift` / `TrialLowering.swift` / `SkillMetrics.swift` were
added, so several of the entries below are newly added floors at their
already-existing (pre-fix, unaffected) measured coverage — not new
regressions. Floors are the **minimum** region% observed across 3 independent
`swift test --enable-code-coverage` runs (parallel `swift-testing` execution
is nondeterministic enough that a handful of files vary run-to-run — see the
per-file jitter notes below), with a small headroom margin subtracted (larger
for the files that showed real spread) so the gate doesn't flap on harmless
scheduling jitter; ratchet down as real tests land and the jitter is
root-caused. Migration/CLI infra floors are unaffected by and out of scope for
the Inform closeout itself (AGENTS.md/plan carve-out) — they're included here
only so the gate reflects reality.

```file-thresholds
# path-substring                                            = min-region-percent
MeridianCLIKit/CLISupport.swift                              = 87.50
MeridianCLIKit/Commands/CompileCommand.swift                 = 94.00
MeridianCLIKit/Commands/DecisionsCommand.swift               = 97.24
MeridianCLIKit/Commands/DocsCommand.swift                    = 94.39
MeridianCLIKit/Commands/FormatCommand.swift                  = 96.50
# InertYieldCommand: `run()` prints/reads real files end-to-end; no test drives
# it in-process yet. Newly floored — see the tooling note above.
MeridianCLIKit/Commands/InertYieldCommand.swift              = 0.00
MeridianCLIKit/Commands/LintCommand.swift                    = 90.90
MeridianCLIKit/Commands/MigrateSkillCommand.swift            = 95.00
MeridianCLIKit/Commands/ResumeCommand.swift                  = 81.80
MeridianCLIKit/Commands/RunCommand.swift                     = 81.20
# RunCommand: residual is empty-workflow selection, named-workflow match arm,
# and findRepoRoot parent-walk failure when Package.swift cannot be located.
MeridianCLIKit/Commands/SkillDeviationCommand.swift          = 91.60
MeridianCLIKit/Commands/TestCommand.swift                    = 81.34
MeridianCLIKit/Commands/TraceRenderCommand.swift             = 84.95
MeridianCore/AST/ExpressionTraceDescription.swift            = 98.02
MeridianCore/Codegen/DomainEmitter.swift                     = 92.02
# ManifestEmitter: `String(data:encoding:) ?? "{}"` is defensive — JSONSerialization
# always emits valid UTF-8.
MeridianCore/Codegen/ManifestEmitter.swift                   = 97.28
# SwiftEmitter: SwiftEmitterCoverageTests covers temporal/string comparisons,
# value-context bridges, workflow-arg coercion, loop interpolation, and
# definition-helper loop-variable operands. Residual: `compOp`/`compHelper`
# non-relational `default:` arms (~1305/1320) are MER0004 defensive guards.
MeridianCore/Codegen/SwiftEmitter.swift                      = 91.59
# Compiler: CompilerCoverageTests covers scoped-tool resolution, vocabulary/
# rulebook frontmatter validation, and ambiguous enum-default rejection.
MeridianCore/Compiler.swift                                  = 93.24
MeridianCore/Diagnostics/Diagnostic.swift                    = 89.65
MeridianCore/Diagnostics/DiagnosticRenderer.swift            = 96.10
# ParserTrace: ParserTraceCoverageTests covers stderr/stdout/file sinks, custom
# sink round-trip, and timing/profile paths. Residual: `MERIDIAN_TRACE` env init
# (~100–103) depends on process environment at launch; branch-only jitter on
# hierarchy enable paths.
MeridianCore/Diagnostics/ParserTrace.swift                   = 92.55
MeridianCore/Docs/MerconfigDocsRenderer.swift                = 91.08
# EnglishLexicon: grammar is reference-backed after Phase 2/3 to avoid task-stack
# copies; residual branches are defensive synonym/default merge edges.
MeridianCore/Language/EnglishLexicon.swift                   = 97.89
# WholeWordRegex: the single `else { preconditionFailure }` arm is unreachable —
# the pattern always comes from NSRegularExpression.escapedPattern, so it can
# only fail on a Foundation bug (and `!` is banned by house rules). Permanent.
MeridianCore/Language/WholeWordRegex.swift                   = 83.28
# ASTToIR: largest reachable Inform-tier residual (relation/description/
# emptiness/formatter lowering, tool-fetch and quantifier-clause diagnostics).
# Closeout session: ASTToIRDeepCoverageTests (52+ tests) — rule engine/no-engine
# paths, direct substituteArgs/lowerExpr hooks, shell-hole root walks,
# description/verb/scalar-nav error call sites, fenced-template interpolation,
# iteration whose-qualification, nested subInterpolationSegment conditional/
# for-each bodies. Observed 89.83%-89.93% region — floor tightened.
# Documented unreachable residual (do not force tests):
#   - `lowerStatement` `.modal` (line ~693): modals consumed in `lowerBlock`.
#   - `missingPhraseArgument` throw (~1083): `extractArgs` always keys every
#     pattern parameter; defensive only.
#   - `toolReturnsValue` workflow early-return (~1134): workflow invokes return
#     before `autoBindIfNeeded`.
#   - `freeIdentifierRoots` relationTraversal/invocation/tableLookup/
#     interpolatedString arms (~933–951): shell holes lower relational nav to
#     property-access IR, not `IRExpression.relationTraversal`.
#   - `lowerExpr` relational guard `else` internal error (~1475): `lowerRelationalExpr`
#     always handles the four plan kinds.
#   - quantifier collection `.invocation` check (~1721): `lowerQuantifier` always
#     sources via `.identifierRef(noun)`.
#   - `lowerIterationRefinement` `r.adjectives` (~1778): parser never populates
#     `IterationRefinementAST.adjectives` (adjectives stay on the collection noun).
#   - `qualifyToLoopVar` `default` (~1813): whose-predicates never lower to
#     non-qualifiable IR kinds in practice.
#   - `lowerDescriptionPlan` collection `.invocation` check (~2144): same as
#     quantifier — collection is always an identifier ref.
MeridianCore/Lowering/ASTToIR.swift                          = 89.92
MeridianCore/Lowering/ConventionInjector.swift               = 94.73
# RuleLowering: RuleAnalyzerCoverageTests covers compound parameter-guard logical
# arms and possessive multi-word filter values. Removed verified-dead
# `buildSubjectFilter` first-space fallback (greedy always accepts on the last
# single-token split); unreachable path now returns `nil`.
MeridianCore/Lowering/RuleLowering.swift                     = 88.38
# RuleInjector: removed verified-dead `guard case .permission` in
# `applyPermissions` (the `permissions` array is built via `compactMap` keeping
# only `.permission` cases). Floor raised after direct-coverage sweep.
MeridianCore/Lowering/RuleInjector.swift                     = 93.63
# SkillTriggers: SkillTriggersCoverageTests + TriggerRulebookTests cover
# classification, cron/asterisk schedules, synthesizer suffix disambiguation,
# trace logging, and frontmatter compile wiring. Residual: branch-only gaps on
# the `seen == 0` ternary and `isCronLike` guard edges (100% line coverage).
MeridianCore/Lowering/SkillTriggers.swift                    = 92.30
MeridianCore/Migration/Difflib.swift                         = 98.22
# InertYieldAnalyzer / TrialLowering / SkillMetrics / SkillMigrator+*: migration
# infra outside the Inform closeout's scope. Newly floored — see the tooling
# note above; none of these regressed from this closeout's changes.
MeridianCore/Migration/InertYieldAnalyzer.swift              = 87.22
MeridianCore/Migration/SkillDeviation.swift                  = 92.48
MeridianCore/Migration/SkillMetrics.swift                    = 99.27
# SkillMigrator+CommandRewrite: SkillMigratorCommandRewriteCoverageTests covers
# diagnosticLine (L-prefix, file:line:column, colon-scan fallbacks), inertMarker
# roles (prohibitions/applicability/negative-applicability/template/tools),
# list-form parameters, shell-fence rewrite, isWordShaped, and unterminated-backtick spans.
MeridianCore/Migration/SkillMigrator+CommandRewrite.swift    = 96.96
MeridianCore/Migration/SkillMigrator+Markdown.swift          = 94.54
MeridianCore/Migration/SkillMigrator+Marking.swift           = 91.31
MeridianCore/Migration/SkillMigrator+QuestionArrow.swift     = 89.23
MeridianCore/Migration/SkillMigrator+SectionBody.swift       = 88.52
MeridianCore/Migration/SkillMigrator+SplitPlan.swift         = 91.91
# SkillMigrator: SkillMigratorCoverageTests covers repair loop, knowledgeContext,
# line-prefixed diagnostics via unified `CompilerError.diagnostics` projection,
# and max-repair exhaustion; SkillMigratorMarkingTests covers the migrate-loop
# `markEnclosingSectionInert` retry path (failed Markdown procedure items).
# Residual: `while true` closing brace (~174) is structurally unreachable;
# `describe` non-CompilerError tail (~273) needs a non-`CompilerError` throw.
MeridianCore/Migration/SkillMigrator.swift                   = 86.83
MeridianCore/Migration/TrialLowering.swift                   = 89.95
# Per-production expression grammar (Wave 5): these files replaced the
# monolithic expression parser. Most reached 100% this closeout (branch-level
# direct tests); the handful below have a documented unreachable residual —
# see the "table lookup guard branches" / "dynamic verb and scalar-navigation
# guard branches" / "quantifier malformed determiner and body branches" tests
# in ProductionGrammarBranchCoverageTests.swift for what remains defensive
# (e.g. TableLookupGrammar's empty-valueColumn guard can't fire once the
# leading article is always fully trimmed; QuantifierGrammar's
# normalizeQuantBody split guards can't see an empty verb/rest once the
# matched body-verb marker always carries a trailing space).
MeridianCore/Parser/Lexical/Productions/DescriptionGrammar.swift   = 98.74
MeridianCore/Parser/Lexical/Productions/LiteralGrammar.swift       = 93.70
MeridianCore/Parser/Lexical/Productions/QuantifierGrammar.swift    = 97.28
MeridianCore/Parser/Lexical/Productions/ScalarNavigationParser.swift = 94.39
MeridianCore/Parser/Lexical/Productions/SuperlativeGrammar.swift   = 95.40
MeridianCore/Parser/Lexical/Productions/TableLookupGrammar.swift   = 87.45
MeridianCore/Parser/Lexical/Productions/TemplateInterpolationParser.swift = 96.44
# NonterminalScreen: the 2 residual regions are the `?? 0` vocabulary-lookup
# fallbacks in `candidates(for:)` and the private `mask(for:vocabulary:)`
# helper — both are only ever called after `init` has already verified every
# anchor is present, so the nil-coalescing default is permanently unreachable
# via the public API (see AGENTS.md pitfall #17 for the mask-correctness
# invariant this depends on).
MeridianCore/Grammar/NonterminalScreen.swift                 = 95.29
MeridianCore/Parser/Lexical/HeaderFolder.swift               = 94.44
MeridianCore/Parser/Lexical/IndentTokenizer.swift            = 91.15
# MerConfigParser: observed 89.38%-91.70% across runs after declaration-edge,
# phrase-pattern, instance-inline, verb-participle, and language-section tests.
MeridianCore/Parser/Productions/MerConfigParser.swift        = 90.69
MeridianCore/Parser/Productions/MeridianParser.swift         = 95.07
# StatementParser: observed 90.80%-90.89% across runs after spaced-number choice
# labels, wait fall-through/single-quoted signal, comma-and/then chain cleanup,
# and related parser-edge tests. Documented defensive residual (do not remove
# without proof): `parseStatement` desugar re-entry (~271–278); `collectChoiceOptions`
# early `break` (~804); `do … and …` unparseable-chunk error (~657–661) when a
# chunk returns nil from `parseStatement` only (sentinel prefixes); decision-table
# row error (~936–940) when a row yields nil from both parsers.
MeridianCore/Parser/Productions/StatementParser.swift        = 90.51
MeridianCore/Parser/Productions/TableParser.swift            = 87.07
# ConditionClassifier: raw gbrain migration now marks narrative recognized
# sections inert before compile, so corpus tests intentionally exercise fewer
# fuzzy applicability/procedure condition branches.
MeridianCore/Parser/Skill/ConditionClassifier.swift          = 97.82
MeridianCore/Parser/Skill/SectionRoleResolver.swift          = 88.83
# SkillSectionBuilder: section-role strictness and AI-discretion branches are
# covered through corpus tests; residual future/error paths remain reachable but
# sparse.
MeridianCore/Parser/Skill/SkillSectionBuilder.swift          = 84.75
MeridianCore/Rulebook/Rulebook.swift                         = 96.50
MeridianCore/Rulebook/RulebookParser.swift                   = 85.87
# SymbolTable: residual is mostly `trace.log` autoclosure arms on the dynamic
# phrase-matching path (verbose-trace-only branches; see the `ParserTrace`
# convention in .cursor/rules/tracing.mdc). Measured to vary by a fraction of a
# percent run-to-run under parallel test execution; floor carries extra margin.
MeridianCore/Symbols/SymbolTable.swift                       = 94.32
MeridianCore/Testing/Assertions.swift                        = 81.59
# IRWalker.swift now at 100% — floor removed.
MeridianCore/Testing/MeridianTestRunner.swift                = 89.20
# RuntimeExecutor: residual branch regions on assertion ternaries and empty
# tool-stub loops; I/O fault paths are covered via DEBUG SwiftPM hooks.
MeridianCore/Testing/RuntimeExecutor.swift                   = 95.00
# SpecParser: residual is partial branch coverage on tokenize/buildSpec paths
# with no uncovered lines after the extended parser tests.
MeridianCore/Testing/SpecParser.swift                        = 97.60
# SwiftPMPackageRunner: residual is Process.launchFailed (fault injection) and
# the empty-assignment guard in parseAssignments; build/run subprocess paths are
# now covered by the Echo package integration test.
MeridianCore/Testing/SwiftPMPackageRunner.swift              = 89.80
# Checkpointer: FilesystemCheckpointer's fd-open failure arms (fsync/lock when
# open(2) fails) and the cachesDirectory default init are the residual — disk
# fault injection, an integration boundary.
MeridianRuntime/Checkpoints/Checkpointer.swift               = 83.87
MeridianRuntime/Comparison/Comparison.swift                  = 99.19
# Observer: JSONSerialization failure fallback (line ~94) is unreachable for the
# always-serializable dict; the rest needs real file I/O fault paths.
MeridianRuntime/Events/Observer.swift                        = 92.80
MeridianRuntime/Planning/ActPlanner.swift                    = 74.95
MeridianRuntime/Planning/PlanExecutor.swift                  = 42.25
MeridianRuntime/Planning/Planner.swift                       = 79.95
MeridianRuntime/Runtime.swift                                = 83.35
MeridianRuntime/State/State.swift                            = 95.50
# ToolRegistry: observed 74.89%-75.34% across 3 runs (in addition to the
# bucket-A HTTP/MCP/subprocess dispatch tail above); floor carries extra margin.
MeridianRuntime/Tools/ToolRegistry.swift                     = 72.88
MeridianRuntime/Tracing/TraceTreeRenderer.swift              = 81.91
# ValueCoercion: the baseline residual regions are unreachable cast-fail arms —
# after a runtime type-guard (`if T.self == Date.self`) the `as? T` conditional
# cast can never fail, but Swift requires the fail-branch syntactically (T is
# generic). Also observed 96.43%-97.32% across 3 runs (date-coercion branches
# appear timing-sensitive), so the floor carries extra margin on top of that.
MeridianRuntime/Value/ValueCoercion.swift                    = 94.42
# EventAssertions: residual is the unreachable JSONSerialization re-encode
# failure fallback (the dict is always serializable).
MeridianTestKit/EventAssertions.swift                        = 93.49
# MockPlanning: residual is the unused MockPlanner(proposals:) convenience init.
MeridianTestKit/MockPlanning.swift                           = 92.80
# WorkflowTestHarness: firstEvent/durationFromEvents need a full harness run
# (workflow execution) — covered indirectly elsewhere, floored here.
MeridianTestKit/WorkflowTestHarness.swift                    = 88.41
# JSONLReplay / GoldenFile / MockToolRegistry / PlanFuzzer / RecordingTool /
# InformRulebook / MeridianAST / ActiveVerbParser / BooleanGrammar now at 100%
# — floors removed this closeout.
# MeridianTools: residual is the http/shell/mcp dispatch specs (integration
# boundaries) + the unreachable stringify nil-fallback.
MeridianTools/MeridianTools.swift                            = 96.21
```
