# Meridian — Phase Status

Tracks the six-phase build plan from `meridian-handoff/docs/10_BUILD_PLAN.md`.

---

## Summary

| Phase | Name | Status | Confidence |
|---|---|---|---|
| 0 | Scaffolding + Runtime | ✅ Done | 100% |
| 1 | Hand-written reference flows | ✅ Done | 100% |
| 2 | Parser + AST | ✅ Done | 100% |
| 3 | IR + Codegen (compiler pipeline closes) | ✅ Done | ~99% |
| 4 | Typed domain codegen + golden diffs | ✅ Done | 100% |
| 5 | assert / wait / iterate / recover / checkpointing | ✅ Done | 100% |
| 6 | Built-in tools + full CLI + TestKit + DocC | ✅ Done | 100% |
| 6.5 | EnglishLexicon + SKILL-shaped extensions | ✅ Done | 100% |
| 8 | Executable rules (Phase C) | ✅ Done | 100% |
| G | Expressive SKILL.md surface + gbrain corpus | ✅ Done | 100% |

---

## Phase 0 — Scaffolding + Runtime

**Completed.** `MeridianRuntime` actor, `Value` enum, `State`, `MeridianWorkflow`
protocol, `WorkflowResult`, `Event` + `EventKind` (22 cases), `RuntimeApprovalVerdict`,
`MeridianComparison`, `ValueCoercion`, SwiftPM project layout, example files
copied into `examples/`.

Key decision: the runtime enum is called `RuntimeApprovalVerdict` (2 cases: `.approved`, `.denied`).

---

## Phase 1 — Hand-written reference flows

**Completed.** `SampleDemoFlows/OrderProcessingDemo` and
`SampleDemoFlows/EcommerceWorkflows` contain manually-written Swift that
mirrors what the compiler will generate. These served as the design target
for Phases 2–3.

---

## Phase 2 — Parser + AST

**Completed.**

- `IndentTokenizer` tokenises source into `[SourceLine]`.
- `PhrasePatternParser` parses `To {pattern}:` headers into `[PatternSegment]`.
- `MerConfigParser` parses `.merconfig` (vocabulary, constants, instances, tools).
- `MeridianParser` parses `.meridian` (imports, workflows, bodies).
- `StatementParser` parses individual statements (if/branch, bind/rebind,
  emit, wait, complete, phrase invocations).
- `ExpressionParser` parses expression strings (possessives, comparisons, literals).
- `SymbolTable` indexes all declarations; `matchPhrase` + `extractArgs` resolve
  invocations.
- `ParserTrace` added for opt-in diagnostic tracing of all the above.

---

## Phase 3 — IR + Codegen

**Completed (~99% at gate; superseded by Phase 5/6 work that extended the IR to 11 primitives).**

- `ASTToIR` lowers `MeridianFile` to `[IRWorkflow]`.
  - Phrase inlining with substitution (length-descending, whole-word replacement).
  - Recursive workflow calls via phrase stubs.
  - `instanceRef` IR node for named instances.
  - `camelCase` binder names.
  - Multi-line phrase invocation handling.
- `SwiftEmitter` emits compilable Swift from IR.
  - `Constants: Sendable` struct.
  - `Instances: Sendable` struct with `Value.record` properties.
  - `emitValueExpr` for `Value`-wrapped arguments and payloads.
  - `MeridianComparison.*` for `Value?` comparisons.
  - `MeridianComparison.isWithin` for `withinDuration` comparisons.
  - Workflow recursion via `StructName(runtime:…).run()`.
- `ManifestEmitter` emits JSON companion manifests.
- `Phase3ForcingFunction` (8 tests) passes. Generated Swift compiles and runs.

**Deferred to Phase 4:**
- `Domain.swift` codegen (typed Swift structs from vocabulary kinds).
- Golden-diff test against expected output file.
- Round-trip integration test (compile → build → run → match expected JSONL).

### Log references
- `IMPLEMENTATION_LOG.md` §"Phase-3 codegen produces compilable Swift via Value wrapping"
- `IMPLEMENTATION_LOG.md` §"Workflow recursion via phrase-stub registration"
- `IMPLEMENTATION_LOG.md` §"Instance refs codegen via generated Instances struct"
- `IMPLEMENTATION_LOG.md` §"Phase 3 confidence audit — SIGN-OFF (~99%)"

---

## Phase 4 — Typed domain codegen + golden diffs

**Status:** Done (~99% confidence). 145/145 tests green; signed off in
`IMPLEMENTATION_LOG.md` §"Phase 4 confidence audit".

### Delivered

1. **`Domain` codegen** ✅ — `SwiftEmitter.DomainDecl` + `DomainEmitter` emit
   typed Swift structs/typealiases for every `kind`, plus top-level enums for
   each `which is one of (…)` clause. Inheritance is flattened in
   `Compiler.buildDomainDecl` so generated structs list ancestor properties
   first, in declaration order. **Updated 2026-05-01:** non-scalar kinds now
   emit a `<KindName>Kind` protocol pair on top of the struct, composing one
   of ten `Meridian<Base>` runtime markers (`Thing | Event | Action | Tool |
   Process | Message | Signal | Fact | Role | Verdict`). See
   [`05_CODEGEN.md`](05_CODEGEN.md) §"Domain types" and
   [`06_RUNTIME.md`](06_RUNTIME.md) §"Kind protocols".
2. **Typed workflow init** ✅ — `ProcessOrder(runtime:order:customer:)` uses
   the generated `Order` and `Customer` structs (not `Value`). State binds
   them as `.opaque(AnyHashableSendable(value))`; the new
   `init<T: …Encodable>` overload preserves the conformance for dotted
   `state.get` traversal.
3. **Golden diff test** ✅ — `Tests/MeridianCoreTests/Phase4GoldenDiff.swift`
   plus `examples/golden/order_processing_expected.swift`. Re-baselining
   honours the `MERIDIAN_REGEN_GOLDENS=1` env var.
4. **Round-trip integration test** ✅ —
   `Tests/MeridianIntegrationTests/Phase4RoundTrip.swift` runs the *generated*
   `ProcessOrder` against mock tools and asserts on the captured event
   stream / `WorkflowResult.reason` for happy-path, validation-fail,
   insufficient-credit, and approval-denied scenarios.
5. **Multi-vocabulary** ✅ — `Compiler.compile(…, vocabularies:)` accepts
   any number of `.merconfig` inputs, validates `import X.` references against
   the supplied set, and rejects duplicate kind/phrase/tool/constant/instance
   names with a sourced error. `Tests/MeridianCoreTests/Phase4MultiVocab.swift`
   pins the merge + import-validation invariants. CLI `--merconfig` is now a
   repeatable flag, and bare `import name.` (per
   `docs/03_LANGUAGE_QUICK_REFERENCE.md`) is parsed alongside the original
   `import vocabulary from "path".` form.
6. **Phrase-only canonical example** ✅ — `examples/order_processing.meridian`
   workflow bodies now contain only phrase invocations (no `bind`/`invoke`/`if`/
   `wait`/`emit`/`complete` at workflow level). Fraud screening, high-value
   approval, payment/retry, and lenient analytics live as phrase definitions in
   [examples/ecommerce.merconfig](examples/ecommerce.merconfig). Goldens and
   `GeneratedOrderProcessing` were re-baselined to match.

### Decisions resolved

- **camelCase everywhere** — generated property paths
  (`state.get("order.totalAmount")`), instance record keys, and phrase
  parameter names all use `camelCase`. `State.opaque` traversal lines up by
  default with `Codable`'s key-encoding strategy.
- **Domain in main file** — generated domain types live in the same file as
  the workflow for now; if multi-file output becomes useful in Phase 6 we can
  split them out.
- **Money/Duration through `AnyCodable`** — `MeridianComparison.numeric`
  recognises the flattened record shape (`{amount, currency}` /
  `{seconds, …}`) so generated comparisons stay numeric across the boundary.

---

## Phase 5 — Hard IR primitives + checkpointing

**Status:** Done (100% confidence). Final gate: 319 tests / 43 suites green.
Signed off in
`IMPLEMENTATION_LOG.md` §"Phase 5 Completion: non-duration waits, source-level recover, and FilesystemCheckpointer durability".

### Delivered

1. **`wait`** ✅ — All four `WaitConditionIR` cases fully implemented end-to-end:
   - `.duration`: `Clock.sleep`-backed, honours `timeout:` parameter.
   - `.signal`: actor-isolated `CheckedContinuation` queue; `deliverSignal(_:)` API.
   - `.approval`: keyed by `(subject: Value, role: String)`; `.approved` resumes
     normally, `.denied` throws `MeridianRuntimeError.approvalDenied`;
     `deliverApproval(of:by:verdict:)` API.
   - `.event`: predicate-filtered queue; woken by `deliverEvent(_:)` or by any
     matching `emit(event:…)` call. `WaitCondition.event` matching predicate is
     now `Optional` (`nil` = accept any event with matching id).
   - Source forms `wait for signal`, `wait for approval from`, `wait for event …
     matching` all parse and lower to the correct `WaitConditionIR`.
   - Codegen: approval emits `RoleRef(identifier:)`, event with matching emits
     a `{ _event in … }` closure.
2. **`iterate`** ✅ — unchanged from prior delivery.
3. **`assert`** ✅ — unchanged from prior delivery.
4. **`recover`** ✅ — Now **fully end-to-end**: source → AST → IR → codegen → runtime.
   - Source forms: `recover from any:`, `recover from payment.declined:`,
     `recover from TimeoutError:` (typed), `recover where {predicate}:`.
   - `StatementParser.parseBlock` attaches each `recover` to the immediately
     preceding statement; chained recovers nest outward naturally.
   - Codegen emits `meridianMatches(_recoveredError, named: "…")` for named
     patterns (using the new `public func meridianMatches` free function); no more
     non-existent `.isNamed(…)` call.
5. **`FilesystemCheckpointer`** ✅ — Now production-grade durable:
   - Explicit `fsync` after temp-file write and after atomic `rename`.
   - Per-run POSIX advisory lock via `lockf(3)` (F_LOCK / F_ULOCK) on
     `<runDir>/.lock` — safe for multi-process concurrent writers.
6. **Replay-safe resume** ✅ — Generated workflows consume prepared resume
   context once, restore state, and guard checkpointed side-effect primitives
   with stable progress labels. Implicit checkpoints are emitted after invokes,
   emits, waits, assertions, and loop iteration boundaries so resumed runs skip
   pre-checkpoint side effects.

### Decisions resolved

- **`recover` source form** — Implemented. Single-line header ending with `:`;
  `parseRecover` does NOT call `collectMultiLineCounted` (which would greedily
  consume body lines as continuation lines).
- **`WaitCondition.event` predicate** — Made Optional; `nil` means "any event
  matching the id". Previously forced a non-optional `@Sendable (Event) -> Bool`.
- **Timeout on signal/approval/event** — V2 per spec. `timeout:` is ignored for
  those conditions in v1; `wait(.duration)` honours timeout.
- **Advisory lock mechanism** — Uses `lockf(3)` not `flock(2)` to avoid the
  Darwin `flock` struct/function name collision in Swift.

---

## Phase 6 — Built-in tools + full CLI + TestKit + DocC

**Done.** Final gate: 319 tests / 43 suites green. Full validation is recorded
in `IMPLEMENTATION_LOG.md` for the Phase 5/6 100% completion pass.

### Shipped

1. **`MeridianTools` Blueprint built-ins** — opt-in canonical families:
   `http.get/post/put/delete`, `file.read/write/append`,
   `json.parse/stringify/transform`, `regex.match/replace`, `shell.run`,
   `mcp.call`, `llm.chat`, `validate.json_schema`, `time.now/format`,
   and `uuid.generate`. Ecommerce demo stubs were removed from
   `registerBuiltins()`; examples/tests register domain tools explicitly.
2. **`meridian check` / `verify`** — parse + lower without emitting. Re-uses the
   compile pipeline so `check` and `compile` agree on validity. Exits 1
   on the first sourced diagnostic.
3. **`meridian format`** — conservative whitespace-only formatter.
   Idempotent (`format(format(s)) == format(s)`). `--check` flag turns
   it into a CI gate. Pinned by 7 tests in `MeridianFormatterTests`.
4. **`meridian docs`** — renders one or more `.merconfig` files to a
   self-contained HTML reference (inline CSS, no JS). Six sections:
   kinds, properties, phrases, constants, instances, tools. Multi-vocab
   render groups each file into its own labelled `<article>`. Pinned
   by 4 tests in `MerconfigDocsRendererTests`.
5. **`meridian test`** — discovers `.meridian.test` spec files and runs
   each as a compile-pass + golden-Swift diff. `examples/order_processing.meridian.test`
   is the canonical example.
6. **`meridian compile` manifest output** — writes both generated Swift and
   `{stem}.meridian.manifest.json` with source-map entries derived from
   generated source-line comments.
7. **`meridian run` / `resume`** — `run` now creates a temporary SwiftPM
   package, builds it, registers Blueprint built-ins/tool stubs, decodes JSON
   parameters, and executes the generated workflow. `resume` loads the latest
   checkpoint and prints the restored runtime context.
8. **`TraceTreeRenderer`** — pure JSONL → indented-tree renderer with
   Unicode/ASCII glyphs, optional timing column, source-range suffix.
   Skips malformed input lines instead of failing. Pinned by 9 tests
   in `TraceTreeRendererTests`. Wrapped by `meridian trace render`.
9. **`MeridianTestKit` helpers** — `WorkflowTestHarness`, `MockRuntime`,
   `MockToolRegistry`, `RecordingTool`, `GoldenFile`, `EventAssertions`,
   and `FixedClock` cover runtime integration tests.
10. **Event goldens** — all four files in `examples/expected_events`
   (`happy_path`, `approval_denied`, `fraud_review`, `retry_success`) are
   pinned by normalized JSONL tests.
11. **DocC bundles** — `MeridianRuntime.docc/` and `MeridianCore.docc/`
   with curated landing pages and Topics sections. Both build clean
   under `swift package generate-documentation`.

### Decisions resolved

- **Tool naming** — `registerBuiltins()` now means Blueprint built-ins only.
  Ecommerce workflow tests and demos explicitly register `validateOrder`,
  `chargePayment`, and other domain tools in their fixtures.
- **`meridian run` runtime mode** — v1 run command executes generated Swift via
  a temporary SwiftPM package managed by `SwiftPMPackageRunner`; it does not use
  dynamic Swift loading.
- **`mcp.call` / `llm.chat`** — `mcp.call` uses a replaceable `MCPClient`
  adapter with HTTP JSON-RPC and subprocess stdio transports. `llm.chat`
  intentionally throws `llm.not_implemented` until a provider is selected.
- **`MeridianCLITests` target removed** — was empty, so SwiftPM was
  printing an unhandled-files warning every build. CLI behaviour is
  exercised via integration tests and `meridian test examples/`.

---

## Known deferred items (cross-phase)

| Item | Phase | Note |
|---|---|---|
| Live LLM provider | 6 | `llm.chat` deliberately throws `llm.not_implemented`; this is the user-approved v1 scope note. |

---

## Phase 6.5 — EnglishLexicon + SKILL-shaped extensions

**Done.** All 391+ tests pass.

### Delivered

1. **`EnglishLexicon`** — Centralises articles, prepositions, copulas, participles,
   comparison markers, duration units, and tool stop-words. Threaded through all
   compiler components via `Compiler.Options.lexicon`. Vocabulary synonyms via
   `=== language ===` section (A2). Lexicon-driven `IRWorkflow.structName` (A3).
   Token-overlap tool resolution (A4). `and`/`or`/`not` in expressions (A5).
   `_unresolved` phrases now throw `Diagnostic.error` by default (A6).
   Unified `parseDuration` (A7).

2. **Frontmatter / discovery metadata** — `---`-delimited metadata block in
   `.meridian` files emitted under `meridian_skill` in the manifest and as
   `static let skillMetadata` on the first generated workflow struct.

3. **Goal-driven loops** — `until` / `while` loops in workflow bodies. Both forms
   bridge through `IterationModeAST` → `IterateIR` → SwiftEmitter.

4. **`decide whether`** — LLM discretion opt-in per workflow (`with discretion`
   header). `decide whether <text>` lowers to `InvokeIR("llm.decide", ...)`.

5. **`llm.decide` / `llm.judge`** — built-ins registered in `MeridianTools`.
   Deterministic default returns `.boolean(false)` when no LLM host is wired.

6. **Fenced code-block string literals** — Triple-backtick fences in workflow
   bodies become multi-line string literals. `decide using:` continuation form.

7. **`{{ expression }}` interpolation** — Inside fenced blocks, `{{ expr }}`
   expands at runtime via `meridianStringify`. New AST/IR cases
   `.interpolatedString([…])`.

8. **`babysit.meridian` + `github.merconfig`** — SKILL.md port demonstrating
   all B features. Phase 7 forcing function (6 tests).

---

## Phase 8 — Executable rules (Phase C)

**Done.** All 391+ tests pass.

### Delivered

1. **`RuleAnalyzer`** — Parses `RuleAST.text` into typed `ParsedRule` enum:
   `invariant`, `parameterGuard`, `precondition`, `trigger`, `permission`.

2. **`RuleInjector`** — Matches parsed rules to workflows via token-overlap
   action matching. Prepends `AssertIR` (invariant/parameterGuard) or
   `WaitIR(.approval)` (precondition). Softens assert conditions with permission
   predicates (`may` rules).

3. **Bounded permission gates (C3c)** — Bounded `may` rules inject an additional
   `AssertIR` gate at the start of matching workflows.

4. **Trigger workflow synthesis (C4)** — `when …` rules produce new synthetic
   `IRWorkflow` with `WaitIR(.event)` leader.

5. **`Permission` + `PermissionRegistry`** — Runtime types in `MeridianRuntime`.
   `Runtime.permissionRegistry` slot for host-injected actor-aware resolvers.

6. **Rule manifest entries (C5)** — All rules emitted in manifest under
   `meridian_rules`. Unparseable rules appear with `executes: false`.

7. **`RuleLoweringTests`** — 10 tests covering all rule shapes, permission
   softening, bounded gates, trigger synthesis, and unrecognised-rule fallback.

---

## Phase G — Expressive SKILL.md surface + gbrain corpus

**Done.** 530 tests / 85 suites green. Zero new IR primitives — only a
`detached` flag on `SimultaneouslyIR` and a `.choice` case on `WaitConditionIR`.

### Delivered

1. **Rulebook engine** — `RulebookParser` + `RewriteEngine` + `ConventionInjector`
   under `Sources/MeridianCore/Rulebook/` and `…/Lowering/`. Three external rule
   families in `.merrules`: desugars, section-role aliases, Inform-style
   conventions. New `rulebook` trace category. Referenced via the `rulebook:`
   frontmatter key. See [11_RULEBOOKS.md](11_RULEBOOKS.md).
2. **Universal section semantics (structural, no `skill: true`)** —
   `SkillSectionBuilder` activates on any `##`/`###` heading and maps headings to
   a closed `SkillSectionRole` set: Contract→`assert`, Phases→procedure,
   When-To-Use→applicability, When-NOT→negative applicability,
   Anti-Patterns→prohibitions, Output→template. A trailing `(( inert ))` /
   `(( inert, role: R ))` / `(( role: R ))` marker is authoritative. No silent
   drops: every section is recorded into `meridian_skill.sections`, and
   pre-heading content, unrecognized-heading-with-content, non-checkable
   invariants, and fuzzy applicability conditions are hard `semanticError`s.
3. **Frontmatter compatibility** — YAML sequences + block scalars; `tools:`→
   `scopedTools`; default `input` param; gbrain keys projected to the manifest.
4. **Command surface** — fenced ` ```bash ` blocks + inline backticked commands
   → `invoke shell.run` (sentinel-carried verbatim).
5. **Explicit judgment** — `use judgment to <goal>:` + `with discretion` /
   `with autonomy` → `ProseStepIR`; unmarked prose errors.
6. **Triggers + dispatch** — typed `TriggerKind` (keyword/ambient/event/schedule),
   `TriggerClassifier` + `TriggerSynthesizer`, `RESOLVER.meri`.
7. **Choice-gate** — `ask the user to choose between …` → emit + `WaitConditionIR.choice`
   + branch; runtime `deliverChoice`/`consumeChoiceSelection`.
8. **Background spawn** — `in the background, <stmt>.` → `SimultaneouslyIR(detached:true)`
   → detached `Task {}`.
9. **Skillpack compilation** — `Compiler.compileSkillpack(…)` pre-registers every
   file's workflows for cross-file resolution.
10. **`SkillMigrator` + `meridian migrate-skill`** — deterministic transform →
   strict compile → bounded LLM-assisted repair → `.meri` + report.
11. **gbrain corpus** — `sample-gbrain/` ships `brain.merconfig`, `brain.merrules`,
   52 ported skills + `RESOLVER.meri`, all compiling strict with zero `_unresolved`.

### Tests
- `SampleGbrainSmokeTests` — per-feature lowering assertions.
- `SampleGbrainConformanceTests` — full-corpus compile gate, rulebook
  data-only extensibility, and `SkillMigrator` (deterministic + mock-LLM repair).

See [13_SKILL_MD_PORTING.md](13_SKILL_MD_PORTING.md) for the porting playbook.
