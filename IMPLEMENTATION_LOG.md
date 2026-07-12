# Implementation Log

This file is maintained by the implementing AI during the build. Every assumption,
question, blocker, and decision goes here, tagged. The supervising human reviews this
log to catch silent drift before it compounds.

**Append only.** Never delete entries. Resolved entries get a `STATUS: RESOLVED` line
and a resolution note appended. The history matters.

**This is the current log.** Older entries live in
[`.ai/implementation-log-archive/`](.ai/implementation-log-archive/)

---

## Tag definitions

| Tag | Meaning | Action |
|---|---|---|
| `ASSUMPTION` | Decided something not specified in the docs. | Log it. Continue. Surface to human if load-bearing. |
| `QUESTION` | Need clarification before proceeding. | Log it. Stop. Wait for human input. |
| `BLOCKER` | Stuck. Cannot make progress. | Log it. Stop. Surface immediately. |
| `DECISION` | Made a decision the docs left open. | Log it. Continue. |

---

## Entry format

```
## YYYY-MM-DD HH:MM — TAG: short headline

CONTEXT: What were you doing when this came up?
DETAIL: The specifics of the assumption / question / blocker / decision.
IMPACT: What downstream work depends on this?
RESOLUTION: (added later when resolved)

STATUS: OPEN | RESOLVED
```

Use UTC timestamps. Keep headlines under 80 characters.

---

## Active log

> **Archive:** Older entries live in [`.ai/implementation-log-archive/`](.ai/implementation-log-archive/README.md).

## 2026-07-11T22:14:18Z — Fixed section-aware stable step path planning

Decision A: `TraceIdentityPlanner.SectionIndex` was indexing only each
`SkillSectionRecord` heading line, so normal body primitives missed every
section and fell back to `/root/procedure/`. Section entries now define ordered
heading-to-next-heading ranges; lines before the first section (and unknown line
zero) retain the root fallback. Focused planner tests pin body-range lookup,
unsorted section input, slug normalization, role propagation, and nested
structural role suffixes.

Phrase expansion also retained merconfig definition line numbers on emitted IR.
Once section ranges became live, those foreign line numbers could select an
unrelated skill section by coincidence (the committed clinical vitals-monitor
output already exhibited the heading-line version of this bug as
`/report-shape/template/` for a workflow invoke). Inlined AST is now retargeted
recursively to the invocation line before lowering, so source maps and stable
section identity both refer to the authored call site. An end-to-end focused
test pins this collision case.

Committed section-bearing Swift outputs and their manifests/source maps need
regeneration: `sample-gbrain/compile-outputs/`, all six Wave 6
`corpora/*/compile-outputs/` sets, and sectioned skill goldens under
`examples/golden/skill/`. They were intentionally not regenerated in this
focused cleanup.

Validation: IDE diagnostics were clean and `swiftc -parse` passed for all three
modified Swift files. `swift test --filter TraceIdentityPlannerD8Tests` was
attempted, but the package build stopped first at the unrelated concurrent
`Sources/MeridianRuntime/Trace/JSONLTraceStore.swift:91` explicit-`self`
compile error; no tests executed.

### 2026-07-11T22:16:31Z validation update

After the concurrent runtime compile error was fixed, the focused test command
was retried. The modified `TraceIdentityPlannerD8Tests.swift` compiled, but
linking the test target then stopped on separate concurrent errors in
`TrialLoweringTests.swift:126` and `SkillMigratorMarkingTests.swift:1677`;
focused tests still could not execute. `swift build --target MeridianCore` and
`swift build --product meridian` both passed. A CLI forcing compile of
`corpora/clinical/skills/vitalsmonitor.meri` produced section-aware paths for
the workflow and guarantees sections, changed the inlined `vitals.read` source
comment from the merconfig definition's line 62 to its skill call-site line 39,
and eliminated both `/root/procedure/` and the accidental
`/report-shape/template/` paths from the primary workflow.

## 2026-07-11T22:14:21Z — Dead-bridge cleanup validation follow-up

The concurrent `JSONLTraceStore.swift` explicit-`self` compile blocker was
subsequently fixed outside this cleanup. A retry compiled the modified
MeridianCore sources and affected test files, then stopped while compiling two
other concurrently edited tests: `SkillMigratorMarkingTests.swift:1677` omits a
new `lexicon` argument, and `TrialLoweringTests.swift:126` omits the new
`VocabularyInput.name` argument. `swift build --target MeridianCore` completed
successfully, confirming the production cleanup and its exhaustive switches
compile. The focused tests still could not execute because SwiftPM compiles the
whole `MeridianCoreTests` target before applying the test filter.

### 2026-07-11T22:30:00Z — Quality-cleanup documentation refresh

Refreshed active docs for Wave 8 sign-off and quality-cleanup synonym blocks
without editing `meridian-handoff/docs/**`, `inform v7 - wave 7 and 8/**`, or
the Cursor plan file. Changes: Wave 8 status across `README.md`, `docs/README.md`,
and `docs/status.md`; corrected `migrate-skill` / migrator `(( inert ))` wording;
added author-facing Wave 8 + `Guarded-fence`/`Fallback-chain`/`Approval-tool`
synonym docs in `docs/03_LANGUAGE_QUICK_REFERENCE.md`; trace lowering/codegen/
runtime/tracing/DX cross-links in `docs/02`/`04`/`05`/`06`/`08`/`14`; stale
coverage README examples; six-corpus `Tests/README.md`; MCP deferral fix in
`codewalks/walkthrough.md`; trace-expression and trace-codegen conventions in
`.cursor/rules/compiler-internals.mdc` and `codegen.mdc`. Skipped:
`docs/19_TRACES_AND_TIME.md` (already current), `AGENTS.md` (no norm change),
`IMPLEMENTATION_LOG.md` entries before this one.

## 2026-07-11T23:20:17Z — Quality-cleanup validation closeout

Completed the cleanup validation pass after routing remaining coverage gaps to
focused tests and simplifying `TrialLowering.probe`'s duplicate catch arms into
one normalized error path. The focused branch tests now cover `FixedGrammar`
fallback suffix selection, `TrialLowering.failureOutcome`, `TraceStoreHelpers`
ordering/schema rejection, and the question-arrow generic result fallback when
the active lexicon has no definite article. The new always-applied Cursor rule
`.cursor/rules/subagent-model.mdc` records the user's preference to use
Composer 2.5 (non-fast) for subagents unless explicitly overridden.

Validation:

- `swift test --filter 'TraceStoreTests/runLocalOrderingUsesTimestampTieBreak|TraceStoreTests/unsupportedSchemaRejected|FixedGrammarDefaultsTests/affirmativeSuffixFallback|TrialLoweringTests/failureOutcomeCoverage|SkillMigratorMarkingTests/questionArrowCase2FallbackArticle'`
  — green.
- `swift test --filter TrialLoweringTests` — green.
- `swift test` — green.
- `MERIDIAN_GOLDEN_TYPECHECK=1 MERIDIAN_GBRAIN_TYPECHECK=1 MERIDIAN_CORPORA_TYPECHECK=1 swift test`
  — green.
- `scripts/coverage.swift --gate` — green.

Residual note: this workspace copy is not currently backed by a visible `.git`
directory, so changed-file inventory and diff inspection could not use git
status/diff locally.

### 2026-07-11T23:22:33Z — Quality-cleanup confidence audit

Closed the remaining confidence gap without relying on git metadata by
verifying the workspace is a non-git copy, auditing the active source/test/doc
tree directly, and removing root-level validation leftovers
(`g*.meridian.manifest.json`, `gns_*.meridian.manifest.json`) that were generated
outside the committed `compile-outputs/` artifact locations. Active source/tests
no longer reference the retired bridge APIs (`CompilerError.notImplemented`,
`MeridianLinter.lintLegacy`, `LintDiagnostic`) except for immutable historical
log text, and the new language-synonym plumbing is present through AST,
merconfig parsing, compiler lexicon merging, lowering, docs, and tests.

Additional validation:

- IDE diagnostics: clean.
- `scripts/coverage.swift --no-test --gate` — green against the latest profile
  (`TrialLowering.swift` now measures 93.75% region coverage, above its 93.10%
  floor).
- Root-level `*.meridian.manifest.json` verification: no matches remain.


### 2026-07-11T23:55:00Z — DECISION: ParserTrace structured correlated spans

Upgraded `ParserTrace` with correlated span IDs (`correlationID`, monotonic
`sequence`, `SpanID`, `SpanOutcome`, `openSpan`/`closeSpan`) while preserving
text output prefixes (`[category]`, `▶`/`◀`, existing indent rules). Per-thread
span stacks and indent levels replace the process-global `indentLevel` so
concurrent compiles on one trace instance stay balanced. Added `.validation`
category wired through `IRValidator.validate(..., trace:)`, `SwiftEmitter`,
`Verbalizer`, and `Compiler.emit(trace:)`. Optional `outputFormat = .jsonl`
emits one JSON object per record (`seq`, `corr`, `span`, `parent`, `cat`, `op`,
`kind`, `outcome?`, `msg`, `range?`). Redaction regexes are precompiled at
static init (no silent `try?` skip). Tests: `ParserTraceSpanConcurrencyTests`.

Validation: `swift test --filter 'ParserTrace|TraceEnabledCompile|IRValidator|SwiftEmitterCoverage'`.

### 2026-07-12T00:02:00Z — Phase runtime-fail-closed observability

**DECISION:** Resolve `.auto` store-failure policy to `.failClosed` unconditionally at
compile time (`TraceIdentityPlanner`) and set `TraceConfiguration.default.storeFailurePolicy`
to `.failClosed` for hosts that bypass the planner. Runtime treats `.auto` as fail-closed
via `isFailClosedPolicy`.

**DECISION:** `Observer.record` is now `async throws`. `JSONLObserver` propagates file
open/write and JSON serialization failures (`ObserverError`); `CompositeObserver` fails
fast on the first throw. `Runtime.emit` records `RuntimeOperationalDiagnostic` entries
(stderr + `operationalDiagnostics()`) and aborts strict paths through
`MeridianRuntimeError.observerFailure` / `.traceStoreFailure`.

**DECISION:** Added `Runtime.workflowFailed` (skips `CancellationError`) and wrapped
generated `run()` in `SwiftEmitter` do/catch so terminal `workflow.failed` events are
emitted before rethrow. Blocking monitor violations append a `.violated` trace record
(`operationalDetail: "prevented"`) with `subject_key` when available.

**DECISION:** `DriverSourceBuilder.runtimeBootstrap` wires `TraceStore` from
`workflow.runtimeTraceConfiguration` in CLI/test drivers (`SwiftPMPackageRunner`,
`RuntimeExecutor`). `MeridianWorkflow` exposes optional `runtimeTraceConfiguration`.

Validation: `swift test --filter 'ObserverTests|TraceIdentityPlanner|TraceStoreTests|MonitorLifecycle|EventGolden'` — 46/46 green.

### 2026-07-12T00:30:00Z — Observability DX Hardening Phase 1

**DECISION:** Expanded `SilentFallbackAuditTests` into a machine-enforced completeness
contract. Production `Sources/` scans now cover `.silent()` (incl. `?? .silent()`),
`try? FileHandle` / `try? *.write(` / `try? *.close(`, `serialization_failed` literals,
high-risk catch swallows (`catch {}`, `catch { return nil/[] }`, `catch { continue }`),
legacy diagnostic projection, `_unresolved` allow-fallback binds, and inline-invoke
placeholders. `Tests/` scans only `traceCapture?.trace ?? .silent()` (excluding the
audit source itself). Allowlist rows require path, pattern, classification, rationale,
user-visible signal, owning test, and explicit-opt-in; `fix-target` entries fail the audit.

**DECISION:** `SILENT_FALLBACK_ALLOWLIST.md` upgraded to the 7-column schema. Removed
`try?` fail-open paths from `JSONLObserver`, `JSONLTraceStore.appendDurably`, and
`ParserTrace.writeLine` (file sink now uses `do/catch` + MER5011 stderr fallback).

**DECISION:** Added `TraceAcceptanceMatrixTests` (successful compile must emit
`[symbols]`, `[merconfig]`, `[parse]`/`[statement]`, `[lowering]`, `[codegen]` evidence;
failed compile must emit `[diagnostics]`). Added `DiagnosticQualityAuditTests` stub over
active catalog explanation/emitter completeness.

Validation: `swift test --filter 'SilentFallbackAuditTests|TraceAcceptanceMatrixTests|ObserverTests|DiagnosticTests|DiagnosticQualityAuditTests'` — 38/38 green.

### 2026-07-12T00:00:00Z — Diagnostic remediation hardening

**DECISION:** Extended `Diagnostic` with optional `phase` and `relatedRanges`
(Hashable/Sendable). `Diagnostic.error` now auto-fills `help` from
`code.explanation` when callers omit remediation and there are no
suggestions/notes — making `MER4002` actionable without rewriting every call site.

**DECISION:** `Suggester.closestAmbiguous` detects tied/near-tied candidates
(within one edit of the leader). `Diagnostic.unresolved` surfaces a candidate-list
note instead of a single auto-suggestion when ambiguous.

**DECISION:** `DiagnosticRenderer.renderJSON` now throws on serialization failure
(backward-compatible schema adds optional `phase` / `related`). Human renderer
shows phase and related spans when present.

**DECISION:** `IRValidator.invalidIR` / `matchSemantic` emit explicit actionable
`help` plus `phase: "validation"`. Removed duplicate pre-report in `ASTToIR`
lowering throw paths inside `DiagnosticEngine.recovering` (`throwLoweringError`
only throws; `recovering` collects once).

Validation: `swift test --filter 'Diagnostic|Suggester|IRValidator|SilentFallbackAudit'` — 86/86 green (`MeridianCoreTests` target; full package build blocked by pre-existing `MeridianCLIKit` `CLITraceOptions` errors unrelated to this change).

---

### 2026-07-12 — CLI trace-format + fallback hardening (Observability DX)

**DECISION:** Added `--trace-format text|jsonl` (default `text`) via shared
`CLITraceOptions` / `makeCLITrace(spec:file:format:)`. Wired through all
trace-capable commands (`compile`, `check`, `verify`, `run`, `migrate-skill`,
`preview-skill`, `explain`, `drift`, `inert-yield`, `skill-deviation`,
`trace-eval`). Active `--trace` prints one stderr correlation-id line; JSONL
records include matching `corr`.

**DECISION:** CLI discovery/read failures now fail closed with coded diagnostics:
`MER5013` (`inputFileNotFound`) for missing explicit/input paths,
`MER5014` (`directoryReadFailed`) for `contentsOfDirectory` / enumerator
failures. Replaced `try? … ?? []` in `DependencyDiscovery`, `MigrateSkillCommand`,
`InertYieldCommand`, and `SkillDeviationCommand` batch discovery.

**DECISION:** Removed BooleanGrammar `either`-prefix best-effort and-join (line
80–82); undocumented `A either B or C` shapes now `.malformed` with an explicit
connector message. `ProductionGrammarBranchCoverageTests` updated.

**DECISION:** `TrialLowering.ProbeTally` records silent probe outcomes;
`SkillMigrator` logs a `.skill` summary line when `--trace skill` is enabled.
`TrialLowering` / `InertYieldAnalyzer` remain on the silent-probe allowlist.

Validation: `swift test --filter 'CLISupport|SilentFallback|NoSilentFallback|MigrateSkill|TraceEnabled|SkillMigrator'`.


### 2026-07-12T00:05:00Z — Observability DX Phase 0 residual-risk retirement

**DECISION:** Schema blast-radius inventory (gates TraceRecord/event field bumps):

| Artifact set | Paths | Regen / owning script |
|---|---|---|
| Runtime Event goldens | `examples/expected_events/*.expected.jsonl` (happy_path, approval_denied, fraud_review, retry_success) | `MERIDIAN_REGEN_EVENTS=1 swift test --filter EventGoldenTests` |
| Bench/trace wave8 | `docs/coverage/bench-trace-wave8.json` | `meridian bench-trace` / Wave 8 bench flow |
| TraceTreeRenderer fixtures | Inline JSONL in `Tests/MeridianRuntimeTests/TraceTreeRendererTests.swift` | Manual edit (no regen env) |
| ParserTrace goldens | None committed (substring + structured operation-ID tests) | N/A — `ParserTraceSpanConcurrencyTests`, `TraceAcceptanceMatrixTests` |
| Semantic TraceRecord schema | `TraceRecord.currentSchemaVersion = 1` in `Sources/MeridianRuntime/Trace/TraceRecord.swift` | Round-trip tests in `TraceStoreTests`; bump only with deterministic migration |
| Corpus compile-outputs | `sample-gbrain/compile-outputs/`, `corpora/*/compile-outputs/` | `scripts/generate-compile-outputs.swift --corpus <name>` |
| Routing-eval JSONL | `sample-gbrain/original-skills/**/routing-eval.jsonl` | Immutable skill corpus (not Meridian observability) |

**DECISION:** Concurrent span stress test landed red-first then greened with structured spans (`ParserTraceSpanConcurrencyTests`). Coverage floors for new observability files will be measured from `scripts/coverage.swift --full` in the validation phase.

---

### 2026-07-12T00:12:00Z — Observability DX validation prep (docs + fault-injection tests)

**DECISION:** Updated `docs/08_TRACING.md` (structured spans, JSONL keys, `--trace-format`,
correlation id, zero-cost-when-disabled, per-thread nesting, end-to-end chain),
`docs/14_DEVELOPER_EXPERIENCE.md` (ambiguous did-you-mean, `phase`/`relatedRanges`,
fail-closed defaults, correlation id, unified recipe), and
`docs/19_TRACES_AND_TIME.md` (`.auto` → `.failClosed`, `violated`/`workflow.failed`,
driver `TraceStore` wiring). Synced `.cursor/rules/tracing.mdc` and `runtime.mdc`.

**DECISION:** Added `Tests/MeridianCoreTests/ObservabilityFaultInjectionTests.swift`
for ambiguity alternates, duplicate-diagnostic guard, allow-fallbacks warning+trace,
`renderJSON` throwing contract, and MER4002 help/phase. Skipped duplicates already
covered by `ParserTraceSpanConcurrencyTests`, `ObserverTests`, and
`DiagnosticTests.recoveringDoesNotDuplicateLoweringDiagnostics`.

Validation: `swift test --filter 'ObservabilityFaultInjection|DiagnosticRenderer|Suggester|NoSilentFallback|ParserTraceSpan'`.

## 2026-07-12T02:20:30Z — Observability coverage gate closeout

**DECISION:** Closed the `--full --gate` observability regression by adding focused
tests (not floor reductions) for the twelve originally failing files and the
residual Suggester overlap tie-break region. Minimal production fixes:
`Runtime.swift` monitor violation ordering (blocking path was dead after
assertion recording), `CompileCommand.format()` test hook
`MERIDIAN_TEST_SWIFT_FORMAT_FAIL=1`, and `MigrateSkillCommand` batch-directory
validation before dependency loading.

New suites:

- `Tests/MeridianCoreTests/ObservabilityCoverageCloseoutTests.swift` — IRWalker
  `hasBlockingAssert`, IRValidator empty pattern subjects + validation trace
  spans, Diagnostic phase/related/help edges, ParserTrace env/jsonl/trace-file
  paths, EmptinessTemporalGrammar negated window, Verbalizer data-table quoted
  cells + fractional statistical percentages, TrialLowering ProbeTally summary.
- `Tests/MeridianRuntimeTests/ObservabilityRuntimeCoverageTests.swift` —
  MeridianWorkflow default `runtimeTraceConfiguration`, invoke capture policies,
  `workflowFailed` error_code, `evaluateTrace`, blocking monitor violations,
  trace-store query failures, monitor sleep cancellation.

Extended:

- `Tests/MeridianCLITests/CLICommandsTests.swift` — Compile swift-format failure
  (human + json), PreviewSkill missing input, Lint json diagnostics,
  MigrateSkill explicit missing deps / missing rulebook / batch directory guards.
- `Tests/MeridianCLITests/InertYieldCommandTests.swift` — stdout report,
  explicit missing deps, renderReport line detail.
- `Tests/MeridianCoreTests/SuggesterTests.swift` — overlap tie-break when edit
  distance ties (`closestAmbiguousOverlapTiebreak`, `rankedOverlapBeforeDistance`).

Validation:

- `scripts/coverage.swift --full --gate` — **green** (`All in-scope files meet
  their required region coverage`; TOTAL 92.95% region / 96.57% line).

### 2026-07-12T02:38:53Z — Observability DX Hardening final confidence audit

Completed all Observability DX Hardening phases:

1. Phase 0 residual-risk retirement (schema fixture inventory, concurrent span stress, measured floors)
2. Machine-enforced silent-path / trace-acceptance / diagnostic-quality contracts
3. ParserTrace structured correlated spans + `.validation` + `Compiler.emit` trace threading
4. Diagnostic remediation (`phase`/`relatedRanges`, ambiguous did-you-mean, throwing `renderJSON`, IRValidator help, no duplicate recovering reports)
5. Compile/CLI fallback hardening (`--trace-format`, MER5013/5014, no `try? ?? []` discovery, BooleanGrammar and-join hard-error, probe tallies)
6. Runtime fail-closed (`.auto`→`.failClosed`, throwing `Observer`, operational diagnostics, TraceStore driver wiring, `workflow.failed`/`violated`, optional `runtimeTraceConfiguration` protocol witness fix)
7. Validation docs + fault-injection + regen goldens/compile-outputs + coverage closeout

Validation:

- `MERIDIAN_GOLDEN_TYPECHECK=1 MERIDIAN_GBRAIN_TYPECHECK=1 MERIDIAN_CORPORA_TYPECHECK=1 swift test` — **2396/2396 green**
- `scripts/coverage.swift --full --gate` — **green** (TOTAL 92.99% region / 96.61% line)

Confidence: **98%** for the Observability DX Hardening scope in this workspace.
Residual risk: corpus compile-outputs regenerated for failClosed/optional witness; Event JSONL goldens unchanged (schema v1). Explicit fail-open / lenient paths remain supported but are now visibly auditable.

### 2026-07-12T02:47:41Z — Runtime.Builder TraceStore auto-wire (100% closeout)

**DECISION:** `Runtime.Builder.setRuntimeTraceConfiguration` now arms auto-wiring so
`build()` instantiates `InMemoryTraceStore` (`.memory`) or a temp-dir
`JSONLTraceStore` (`.file`) when no explicit `setTraceStore` was given. Explicit
`setTraceStore` wins and disables auto-wire. `build()` is throwing so `.file`
store creation failures surface instead of silently leaving a nil store.

Tests: `RuntimeBuilderTraceStoreTests` (memory/file auto-wire, nil without
config, explicit store wins). Docs: `docs/06_RUNTIME.md`, `.cursor/rules/runtime.mdc`.

Confidence: **100%** for Observability DX Hardening plan scope — the last residual
Builder TraceStore gap is closed.

### 2026-07-12T08:30:00Z — Relocate oracle docs and wave agent prompts

**DECISION:** Moved the Wave 7–8 normative oracle from `inform v7 - wave 7 and 8/`
into `docs/cookbook/` (`MERIDIAN_SEMANTICS.md`, `MERIDIAN_SYNTAX_COOKBOOK.md`,
`MERIDIAN_NORTHSTAR_EXAMPLE.md`, `MERIDIAN_DESIGN_RISKS_AND_REVIEW.md`) and
`INFORM7_DESIGN_NOTES.md` from `inform v7/` into the same folder. Moved agent
implementation prompts to `.ai/` (`meridian-wave7-verbalizer-prompt.md`,
`meridian-wave8-9-trace-deontic-prompt.md`, `meridian-cursor-master-prompt.md`,
`meridian-inform7-cursor-prompt.md`). Added `docs/cookbook/README.md` and
`.ai/README.md`. Updated references across `AGENTS.md`, `README.md`, `docs/README.md`,
`docs/status.md`, `docs/19_TRACES_AND_TIME.md`, `docs/18_VERBALIZER.md`,
`docs/03_LANGUAGE_QUICK_REFERENCE.md`, Wave 8 coverage docs, and brainstorm
archives. Stale `meridian-handoff/docs/` pointers in active docs now target
`docs/15_DECISIONS.md` and `docs/cookbook/`. The empty `inform v7*/` folders
remain for the maintainer to delete.

**STATUS:** RESOLVED — user may remove `inform v7/` and `inform v7 - wave 7 and 8/` when ready.

### 2026-07-12T09:15:00Z — Move slow external-process tests to MeridianSlowIntegrationTests

**DECISION:** Consolidated all wall-clock-heavy external-process suites into
`Tests/MeridianSlowIntegrationTests/` so `swift test --skip MeridianSlowIntegrationTests`
gives a ~100s inner loop (2336 tests) while plain `swift test` still runs the full
gate (~8–9 min including typecheck + SwiftPM run + CLI E2E).

Moved:
- `swiftc -typecheck` gates (goldens, corpora, gbrain) →
  `GeneratedSwiftTypecheckSlowTests.swift` (no more `MERIDIAN_*_TYPECHECK=1` env vars)
- CLI process E2E: DX fixtures, verbalizer pipelines, trace eval/verify
- Shared helpers: `MeridianTestKit/SwiftTypecheckSupport.swift`,
  `MeridianTestKit/MeridianCLIProcessSupport.swift`

Updated `AGENTS.md`, `Tests/README.md`, `.cursor/rules/testing.mdc`, `Package.swift`
target comment.

**GATE:** `swift test --skip MeridianSlowIntegrationTests` → 2336/2336 pass (~101s);
`swift test --filter MeridianSlowIntegrationTests` → 64/64 pass (~385s).

**STATUS:** RESOLVED

### 2026-07-12T09:30:00Z — Document three test workflows consistently

**DECISION:** Added a canonical three-workflow table to `AGENTS.md` §4 (fast
inner loop / full test gate / coverage gate) with a pointer to
`Tests/README.md`. Restructured `Tests/README.md` as the detailed hub (table,
focused slow-run filters, fixed stale typecheck/phase-checklist text). Aligned
`.cursor/rules/testing.mdc`, `docs/coverage/README.md` § pipeline/flow 2, and
`.ai/meridian-*-prompt.md` gate wording (dropped obsolete
`MERIDIAN_*_TYPECHECK=1` references).

**STATUS:** RESOLVED
