# SKILL.md Expressiveness Plan — SkillMD-D1 through SkillMD-D28

**Status:** Implemented and shipped. Last validation run: `swift test` — 483 tests
in 81 suites passing as of 2026-05-01.

This document is the canonical reference for the **SKILL.md-shaped expressiveness
plan**, executed in two passes during 2026-04-30 → 2026-05-01. Tests, code
comments, log entries, and `AGENTS.md` use stable identifiers like
`SkillMD-D11`, `SkillMD-D11a`, `SkillMD-D17`, `SkillMD-D23`, etc. that originate
**from this plan**, not from the original architectural decision log. The
`SkillMD-` prefix exists specifically to distinguish them from the bare `D1`–`D30`
architectural decisions in
[`meridian-handoff/docs/11_DECISIONS.md`](../../meridian-handoff/docs/11_DECISIONS.md).
This file preserves their meaning even after the planning chat is discarded.

> **Backward-compatibility note.** A small number of older log/comment entries
> (and possibly external mirrors) still use the bare form (`D17`, `D22`, …).
> Outside `meridian-handoff/docs/11_DECISIONS.md`, treat any bare `D<N>` as
> shorthand for `SkillMD-D<N>`. New code, tests, and log entries must use the
> prefixed form.

---

## Table of contents

1. [Why this exists (numbering ambiguity)](#1-why-this-exists-numbering-ambiguity)
2. [Three-tier expressiveness model](#2-three-tier-expressiveness-model)
3. [Strict execution contract](#3-strict-execution-contract)
4. [Tier 1 — deterministic surface (SkillMD-D1 to SkillMD-D11)](#4-tier-1--deterministic-surface-skillmd-d1-to-skillmd-d11)
5. [Tier 2 + Tier 3 — prose plan and autonomy (SkillMD-D11a to SkillMD-D20)](#5-tier-2--tier-3--prose-plan-and-autonomy-skillmd-d11a-to-skillmd-d20)
6. [Test infrastructure (SkillMD-D21 to SkillMD-D22)](#6-test-infrastructure-skillmd-d21-to-skillmd-d22)
7. [Idiom desugaring + Inform-style rulebooks (SkillMD-D23 to SkillMD-D23a)](#7-idiom-desugaring--inform-style-rulebooks-skillmd-d23-to-skillmd-d23a)
8. [Diagnostics / linter / SKILL.md import (SkillMD-D24 to SkillMD-D26)](#8-diagnostics--linter--skillmd-import-skillmd-d24-to-skillmd-d26)
9. [Resource limits, host policy, replay checkpoints (SkillMD-D27 to SkillMD-D28)](#9-resource-limits-host-policy-replay-checkpoints-skillmd-d27-to-skillmd-d28)
10. [Hardening pass (post-SkillMD-D28 audit close)](#10-hardening-pass-post-skillmd-d28-audit-close)
11. [Where to find each piece](#11-where-to-find-each-piece)
12. [Tag legend (B-series, D-series)](#12-tag-legend-b-series-d-series)

---

## 1. Why this exists (numbering ambiguity)

Two **independent** D-numbering schemes exist in this repository:

| Scheme | Defined in | Shape |
|---|---|---|
| **Architectural decisions D1–D30** *(bare `D<N>`)* | `meridian-handoff/docs/11_DECISIONS.md` (read-only) | "D17 = tool declarations use ModelHike syntax", "D22 = `simultaneously` is a primitive", etc. |
| **SKILL.md expressiveness `SkillMD-D1`–`SkillMD-D28`** *(this document)* | This file | "SkillMD-D17 = autonomy header parsing", "SkillMD-D22 = `MeridianTestKit` planning mocks", etc. |

When you see `SkillMD-D17`, `SkillMD-D22`, `SkillMD-D23`, `SkillMD-D27`,
`SkillMD-D28` (or — for backward compatibility — bare `D17`, `D22`, …) in:

- `IMPLEMENTATION_LOG.md` entries dated 2026-04-30 onward
- `AGENTS.md` "Recent decisions" sections dated 2026-04-30 onward
- `Tests/MeridianCoreTests/SkillExampleCorpusTests.swift`
  (`@Test("all SkillMD-D22 skill examples ...")`)
- `Sources/MeridianCore/Lowering/ASTToIR.swift`
  (`// SkillMD-D11a: Delegate to the runtime's Discretion protocol`)
- `Sources/MeridianCore/Parser/Productions/MeridianParser.swift`
  (`// B3 / SkillMD-D17: Detect prose-mode annotations before the colon.`)

…they refer to **this plan**, not to `meridian-handoff/docs/11_DECISIONS.md`.

The architectural decision log uses a separate numbering inherited from the
spec; do not cross-reference. New code, tests, and log entries must use the
`SkillMD-D<N>` form. A small number of older entries still use the bare form
(`D17`, etc.); treat any bare `D<N>` outside
`meridian-handoff/docs/11_DECISIONS.md` as shorthand for `SkillMD-D<N>`.

---

## 2. Three-tier expressiveness model

The plan introduces **three tiers** of authoring style. A single `.meridian`
file may freely mix all three:

| Tier | Audience cue | Lowers to | Runtime path |
|---|---|---|---|
| **Tier 1 — Surface only** | Markdown headings, lists, frontmatter, English connectives, idioms. | Deterministic IR (`bind`, `invoke`, `branch`, `iterate`, `wait`, `emit`, `recover`, `complete`, `assert`, `commit`, `simultaneously`). | `runtime.invoke(...)` only. |
| **Tier 2 — Plan-then-execute prose** | Workflow header `, with discretion:`. Body is free English plus optional fenced code blocks. | `ProseStepIR(dispatchMode: .planThenExecute)`. | `runtime.executeProsePlan(...)` calls `Planner` → validates each `ProposedAction` → `runtime.invoke(...)`. |
| **Tier 3 — Autonomy loop** | Workflow header `, with autonomy [until X] [unless Y] [re-plan after N failures] [max M]:`. | `ProseStepIR(dispatchMode: .autonomousLoop, autonomy: AutonomyConfigIR)`. | `runtime.executeAutonomousLoop(...)` calls `ActPlanner` per turn → validates each turn → `runtime.invoke(...)` → checkpoint → repeat. |

Within Tier 2/3 the planner can also fall back to discretion via the runtime's
typed `Discretion` slot for `decide whether ...` predicates.

---

## 3. Strict execution contract

The contract — paraphrased from the user's directive
*"LLM proposes, Meridian disposes"* — is:

1. **Strict by default.** Tier 1 surface raises `CompilerError.semanticError`
   for any unresolved phrase, unparseable rule, unattached rule, or trigger
   action that doesn't lower. Per-file opt-in is the frontmatter
   `allow-fallbacks:` key (`unresolved-phrases`, `unparseable-rules`,
   `unattached-rules`, `unresolved-trigger-actions`, or `all`). Process-wide
   opt-in is `Compiler.Options.fallbackPolicy = .lenient`.
2. **No silent fallback.** Every previously silent path is now a hard error
   unless the host explicitly opted in.
3. **Planner proposals never execute directly.** The runtime validates each
   `ProposedAction` against scoped tools, registered tools, `ToolSchema`
   (required/unexpected/typed args), `PlanningResourceLimits`, and the host
   `PlanPolicy` before calling `runtime.invoke`.
4. **Failures escalate.** Planning rejections raise
   `MeridianRuntimeError.toolError(.implementation(code: <PlanningFailureCode>))`
   so `recover from "planning.host_policy_denied":` (etc.) handlers match
   them via `meridianMatches(_:named:)`.
5. **`Discretion`, `Planner`, `ActPlanner`, `LLMProvider`, `PlanPolicy`, and
   `PlanningResourceLimits`** are typed slots on `Runtime`; hosts swap them via
   `Runtime.Builder`.

---

## 4. Tier 1 — deterministic surface (SkillMD-D1 to SkillMD-D11)

Implemented 2026-04-30 (first pass, SkillMD-D1 to SkillMD-D7) and 2026-05-01
(second pass, SkillMD-D8 to SkillMD-D11).

| ID  | Item | Surface form | Lowering |
|-----|------|--------------|----------|
| SkillMD-D1  | Markdown list/heading sugar | `- step`, `* step`, `1. step`, `## Section`, `### Sub-section` | `IndentTokenizer` strips list markers, records `HeadingEntry(level, text, line, kind: "heading")` in `MeridianFile.outline`. Manifest emits these under `meridian_skill.outline`. |
| SkillMD-D2  | Implicit entry workflow | Top-level statements outside any `To … :` form an implicit workflow named after frontmatter `name:` (fallback `entry`), parameters from frontmatter `parameters:`. | `MeridianParser.buildImplicitWorkflow`. Throws `semanticError` if it would shadow an explicit workflow. |
| SkillMD-D3  | Natural English connectives | `<stmt> only when <pred>.`, `<stmt> unless <pred>.`, `otherwise <stmt>.` | Suffix `only when` / `unless` desugar into single-statement conditionals; leading `otherwise` desugars to `recover from any` attached to the predecessor. |
| SkillMD-D4  | `every X` / `each X` iteration | `review every comment.` | `IterationStatementAST(.forEach(variable: "comment", collection: "comments"))` with body `review the comment`. Backed by public `EnglishLexicon.singularize(_:)`. |
| SkillMD-D5  | Implicit result binding | `invoke get customer with id = ...` (no leading `bind`) | If a naked invoke lowers to a single return-valued **registered** tool call without an explicit binding, `ASTToIR.lowerPhraseInvocation` synthesises a binding from the action object words. Unknown tools and workflow stubs are NOT auto-bound. |
| SkillMD-D6  | Discretion predicate sugar | `if you decide that X,`, `unless you decide that X,` | Lowers to a comparison whose value is the runtime's `Discretion.decide(DiscretionContext(question: X, ...))` rather than the legacy `llm.decide` tool. |
| SkillMD-D7  | Frontmatter SKILL metadata | `---\nname: …\ndescription: …\ngoal: …\nparameters: pull request, repo\n---` | Parsed by `MeridianParser`. `parameters:` kinds must resolve in `SymbolTable`; otherwise `semanticError`. |
| SkillMD-D8  | Topic labels | `Comments: bind comments = invoke …` | `StatementAST.labelled` carrying `(label, statement)`; manifest records labels as `HeadingEntry(kind: "topic")`. |
| SkillMD-D9  | Inline statement chains | `do A, B, and C.`, `do A, then B.` | `StatementParser.parseInlineChain` splits on `, and `, ` and `, ` then `; plain commas inside an invoke `with …` argument list do **not** split (`inInvokeArgs` flag in `splitStatementChain`). |
| SkillMD-D10 | Strict single-parameter phrase fill | A workflow with exactly one parameter receives an implicit `the <param>` when invoking a phrase whose pattern requires that parameter. | `SymbolTable.matchPhrase(_:defaultParam:)`. Multi-parameter workflows still require explicit arguments. |
| SkillMD-D11 | Frontmatter `goal:` reflection | `goal: keep release work deterministic` | Manifest emits `meridian_skill.goal`. Available to planners as snapshot context. |

**Surface invariant (Tier 1):** *Strict mode never produces `_unresolved`
placeholders.* Unresolved phrase invocations escalate to
`CompilerError.semanticError` unless the file opts into `allow-fallbacks:
unresolved-phrases`.

---

## 5. Tier 2 + Tier 3 — prose plan and autonomy (SkillMD-D11a to SkillMD-D20)

| ID   | Item | Surface form | Runtime contract |
|------|------|--------------|-----------------|
| SkillMD-D11a | Typed `Discretion` slot | `if you decide that …` | `runtime.discretion.decide(DiscretionContext(question, snapshot, history))` returning `DiscretionVerdict`. The legacy `llm.decide` tool still exists for direct invocation but is no longer the path for `you decide that`. |
| SkillMD-D12  | Typed `Planner` protocol | n/a (runtime API) | `protocol Planner { func plan(_ ctx: PlanContext) async throws -> PlanProposal }`. Returns a `PlanProposal { rationale, actions: [ProposedAction] }`. |
| SkillMD-D13  | Typed `ActPlanner` protocol | n/a | One step of an autonomy loop: `protocol ActPlanner { func nextAction(_ ctx: ActContext) async throws -> ProposedAction? }`. Nil signals the planner believes the goal is met. |
| SkillMD-D14  | Typed `LLMProvider` protocol | n/a | Wraps prompt/completion APIs. The default `LLMBackedPlanner` / `LLMBackedActPlanner` / `LLMBackedDiscretion` are constructed from any `LLMProvider`. |
| SkillMD-D15  | `Runtime.Builder` slot exposure | n/a | `Runtime.Builder` exposes `withPlanner`, `withActPlanner`, `withDiscretion`, `withLLMProvider`, `withPlanPolicy`, `withPlanningResourceLimits`. |
| SkillMD-D16  | `with discretion` workflow header | `To plan repair for a pull request, with discretion:` | Body is parsed as one or more `phraseInvocation`s; any phrase that fails to match in `SymbolTable.matchPhrase` is lowered to `ProseStepIR(.planThenExecute)`. Resolved phrases still lower deterministically. |
| SkillMD-D17  | `with autonomy` workflow header | `To autonomously stabilize ci for a pull request, with autonomy until <pred> unless <pred> re-plan after N failures max M:` | `MeridianParser.parseAutonomyOptions` extracts `until`, `unless`, `re-plan after N`, `max M` (defaults 3 / 32). Lowers prose body to `ProseStepIR(.autonomousLoop, autonomy: AutonomyConfigIR(...))`. |
| SkillMD-D18  | Runtime prose execution | n/a | `Runtime.executeProsePlan(text:, scopedTools:, snapshot:)` calls `Planner.plan(...)`, validates each `ProposedAction` (scope, registration, schema, limits, host policy), then calls `runtime.invoke(...)`. Emits `plan.start`, `plan.proposed`, `plan.rejected`, `plan.error`, `plan.complete`. |
| SkillMD-D19  | Runtime autonomy execution | n/a | `Runtime.executeAutonomousLoop(text:, scopedTools:, snapshot:, until:, unless:, replanAfterFailures:, maxSteps:)`. Per turn: check `unless` (abort), check `until` (success stop), call `ActPlanner.nextAction(...)`, validate, invoke, merge result binding into loop snapshot, checkpoint. Emits `autonomy.start`, `autonomy.step`, `autonomy.end`. |
| SkillMD-D20  | Codegen for prose / autonomy | `SwiftEmitter.emitProseStep` | Generates `try await runtime.executeProsePlan(...)` or `try await runtime.executeAutonomousLoop(...)` calls. For autonomy, emits `until:` / `unless:` predicate closures that restore a local `State` from the loop `StateSnapshot` before evaluating the lowered `IRExpression`. |

`ProseStepIR` carries `text`, `scopedTools` (defaulted to all registered
tools), `snapshotKeys` (defaulted to all current state keys), `dispatchMode`,
optional `autonomy`, and `sourceRange`.

---

## 6. Test infrastructure (SkillMD-D21 to SkillMD-D22)

| ID  | Item | Implementation |
|-----|------|----------------|
| SkillMD-D21 | Planning mocks | `MockPlanner`, `ScriptedPlanner`, `MockActPlanner`, `MockDiscretion`, `RecordingTool`, `MockToolRegistry`, `MockRuntime` in `MeridianTestKit`. |
| SkillMD-D21 | Replay / fuzz / clock harnesses | `JSONLReplay`, `PlanFuzzer`, `ClockHarness` in `MeridianTestKit`. |
| SkillMD-D22 | `examples/skill/*` fixture corpus | `ci_fixer.meridian`, `code_review.meridian`, `incident_response.meridian`, `customer_support.meridian`, `release_orchestrator.meridian`, `multi_host_demo.meridian`. Tested by `Tests/MeridianCoreTests/SkillExampleCorpusTests.swift` (`@Test("all SkillMD-D22 skill examples parse and lower")` — this is the source of the `SkillMD-D22` reference in tests). |
| SkillMD-D22 | Adversarial planner tests | Tests where `MockPlanner` proposes unregistered tools, out-of-scope tools, oversized payloads, ill-typed args. Asserts the runtime rejects without invoking and emits the right `PlanningFailureCode`. |
| SkillMD-D22 | Replay determinism | Tests that re-running a workflow against a captured `JSONLReplay` produces byte-identical event sequences. |
| SkillMD-D22 | Multi-host planner tests | Same workflow source, three different `Planner`/`ActPlanner`/`Discretion` slot configurations, asserting host-specific outcomes. |

---

## 7. Idiom desugaring + Inform-style rulebooks (SkillMD-D23 to SkillMD-D23a)

| ID   | Item | Surface form | Lowering |
|------|------|--------------|----------|
| SkillMD-D23  | English idioms | `make sure X.`, `ensure X.`, `after X, Y.`, `X except when Y.`, `try X; if it fails Y.`, passive voice (`X is done.`) | `StatementParser.parseEnglishIdiom`. `make sure / ensure → assertStmt`; `after X, Y → conditional(Y)`; `X except when Y → X unless Y`; `try X; if it fails Y → recover from any: Y attached to X`. |
| SkillMD-D23a | Inform 7-style rulebooks | `before <event>:`, `instead of <event>:`, `check <event>:`, `carry out <event>:`, `after <event>:`, `report <event>:` | `InformRulebookParser` is clean-room and parser-only for now. It recognises the six phases, sorts rules in Inform-style phase order, and preserves source order within each phase. Not yet wired to the lowering pipeline. |

---

## 8. Diagnostics / linter / SKILL.md import (SkillMD-D24 to SkillMD-D26)

| ID  | Item | Implementation |
|-----|------|----------------|
| SkillMD-D24 | Strict scoped references / anaphora | `AnaphoraResolver` runs over each block. Pronouns (`it`, `they`, `them`) and bare possessives (`its`, `their`) must resolve to a single recent referent (last 4 binds / iteration variables) or compilation fails with an explicit "ambiguous anaphora in `…`; spell out the referenced value" error. |
| SkillMD-D25 | Linter | `MeridianLinter` is invoked by `meridian lint`. Reports paraphrase suggestions (e.g. "did you mean `if you decide that X`?"), missing recover handlers around long invoke chains, and Tier-2/3 prose that does not list scoped tools. |
| SkillMD-D26 | SKILL.md import preview | `SkillMarkdownImporter` reads a `.skill.md` (Anthropic-style) and emits a stub `.meridian` preview by extracting frontmatter, headings, and code blocks. Driven by `meridian preview-skill <file>`. Read-only — does not implicitly compile or run. |

---

## 9. Resource limits, host policy, replay checkpoints (SkillMD-D27 to SkillMD-D28)

| ID  | Item | Implementation |
|-----|------|----------------|
| SkillMD-D27 | `PlanningResourceLimits` | Public struct on `Runtime`. Fields: `maxProseBytes`, `maxToolArgsBytes`, `maxActions`, `maxReplanActions`, `maxSnapshotBytes`, `maxHistoryBytes`, `maxProposalBytes`, `maxLoopSteps`. Each over-limit raises a `PlanningFailureCode`. |
| SkillMD-D27 | `PlanPolicy` | `protocol PlanPolicy { func evaluate(_ action: ProposedAction, context: PolicyContext) async throws -> PolicyDecision }`. Defaults to `.allow`. Hosts implement to deny, downgrade, or annotate. Reference impl: `DenyListPlanPolicy` in `MeridianTestKit`. |
| SkillMD-D27 | `PlanningFailureCode` | Stable raw-value enum (`planning.prose_payload_too_large`, `planning.tool_arguments_payload_too_large`, `planning.too_many_actions`, `planning.replan_too_many_actions`, `planning.max_steps_exceeded`, `planning.host_policy_denied`, `planning.tool_out_of_scope`, `planning.tool_not_registered`, `planning.missing_tool_argument`, `planning.unexpected_tool_argument`, `planning.invalid_tool_argument_type`, `planning.snapshot_payload_too_large`, `planning.history_payload_too_large`, `planning.proposal_payload_too_large`). All are matchable via `recover from "planning.<code>":`. |
| SkillMD-D28 | Replay checkpoints | After each accepted prose action and each accepted autonomy turn, `Runtime` writes a checkpoint via the registered `Checkpointer`. Autonomy checkpoints persist the post-action loop snapshot **including planner-produced result bindings**. `Runtime.prepareResume(runID:)` restores those bindings into local state. |
| SkillMD-D28 | Chaos recovery | Filesystem checkpointer writes use `temp file → fsync → atomic rename → fsync directory` and a per-run advisory lock (`lockf(3)`) to survive crashes mid-write. |

---

## 10. Hardening pass (post-SkillMD-D28 audit close)

Performed 2026-05-01 to bring the implementation to ~100% confidence. None of
these are new SkillMD-D IDs; they fix gaps in existing IDs:

- **Autonomy predicates are executable.** `SwiftEmitter.emitProseStep` emits
  `until:` / `unless:` closures; `Runtime.executeAutonomousLoop` evaluates them
  before each act-planner turn. (Tightens SkillMD-D17 / SkillMD-D19 / SkillMD-D20.)
- **Schema-validated tool args.** `ToolRegistry.register` accepts an optional
  `schema:`. `PlanExecutor` rejects missing/unexpected/ill-typed args with the
  three new `PlanningFailureCode`s above. (Tightens SkillMD-D27.)
- **Expanded resource limits.** Added `maxSnapshotBytes`,
  `maxHistoryBytes`, `maxProposalBytes` plus their failure codes.
  (Tightens SkillMD-D27.)
- **Recursive redaction.** `RedactionPolicy.redactKeys` redacts matching keys
  recursively inside `Value.record`/`Value.list` payloads of `invoke.start`
  events.
- **Autonomy checkpoint completeness.** Autonomy loop snapshot includes
  planner-produced result bindings before each checkpoint write.
  (Tightens SkillMD-D28.)

Recover-attachment + error-matching stabilization (also part of this pass):

- `StatementParser.appendStatement` recognises both an empty placeholder and
  the `"__recover_placeholder__"` sentinel as the recover placeholder eligible
  for attachment. Without this fix, `recover from ...:` lines parsed before any
  predecessor was emitted attached to nothing.
- Planning failures use `MeridianRuntimeError.toolError(.implementation(code:
  ...))` rather than introducing new `MeridianRuntimeError` enum cases. This
  preserves the ABI of `meridianMatches(_:named:)` and avoids regressions in
  `recover from approval.denied:` matching.
- `MerConfigParser.sectionName` rejects all-`=` lines so tool-title underlines
  (`========================`) are not mistaken for section headers; this was a
  silent bug that caused `=== tools ===` sections to drop every tool after the
  first underline.

---

## 11. Where to find each piece

| Concern | Path |
|---------|------|
| Runtime planner / autonomy plumbing | `Sources/MeridianRuntime/Runtime.swift`, `Sources/MeridianRuntime/Planning/*` |
| Failure codes | `Sources/MeridianRuntime/Planning/PlanningFailureCode.swift` |
| Resource caps | `Sources/MeridianRuntime/Planning/PlanningResourceLimits.swift` |
| Tool schema validation | `Sources/MeridianRuntime/Planning/PlanExecutor.swift`, `Sources/MeridianRuntime/Tools/ToolRegistry.swift` |
| Tier-1 surface lowering | `Sources/MeridianCore/Parser/Lexical/IndentTokenizer.swift`, `Sources/MeridianCore/Parser/Productions/StatementParser.swift`, `Sources/MeridianCore/Parser/Productions/MeridianParser.swift` |
| Prose / autonomy lowering + codegen | `Sources/MeridianCore/Lowering/ASTToIR.swift`, `Sources/MeridianCore/Codegen/SwiftEmitter.swift` |
| Idiom + anaphora | `Sources/MeridianCore/Parser/Productions/StatementParser.swift` (`parseEnglishIdiom`, `AnaphoraResolver`) |
| Inform rulebooks | `Sources/MeridianCore/Parser/Productions/InformRulebookParser.swift` |
| Linter | `Sources/MeridianCore/Diagnostics/MeridianLinter.swift` |
| SKILL.md importer | `Sources/MeridianCore/Diagnostics/SkillMarkdownImporter.swift` |
| Test mocks | `Sources/MeridianTestKit/*` |
| Examples | `examples/skill/*.meridian`, `examples/skill/*.meri`, `examples/skill/comprehensive_workflows.merconfig` |
| Tests | `Tests/MeridianCoreTests/SkillSurfaceTests.swift`, `Tests/MeridianCoreTests/SkillExampleCorpusTests.swift`, `Tests/MeridianCoreTests/ProseModeTests.swift`, `Tests/MeridianCoreTests/AutonomyModeTests.swift`, `Tests/MeridianRuntimeTests/AutonomyRuntimeTests.swift`, `Tests/MeridianRuntimeTests/PlanningFailureCodeTests.swift`, `Tests/MeridianRuntimeTests/PlanningValidationTests.swift`, `Tests/MeridianRuntimeTests/ProseRecoveryPolicyTests.swift` |
| Documentation | `docs/12_PROSE_AND_AUTONOMY.md`, `docs/03_LANGUAGE_QUICK_REFERENCE.md`, `README.md` |

---

## 12. Tag legend (B-series, SkillMD-D series)

In addition to the `SkillMD-D…` tags from this plan, you may see a small
number of `B…` tags referring to a separate Phase B work-stream (de-hardcoding
English and SKILL-shaped extensions) that ran immediately before this plan:

| Tag | Origin | Meaning |
|-----|--------|---------|
| **B3** | Phase B | `decide whether <question>` and discretion predicate sugar (later subsumed by SkillMD-D6 / SkillMD-D11a). |
| **B6** | Phase B | Triple-backtick fenced code blocks, including the `\u{E000}codeblock:<lang>:<base64>` sentinel produced by `IndentTokenizer`. |
| **B7** | Phase B | `{{ … }}` interpolation inside fenced code blocks. |
| **SkillMD-D11a** | This plan | Refinement of SkillMD-D11 — the `Discretion` slot is a typed protocol, not a tool. |
| **SkillMD-D23a** | This plan | Refinement of SkillMD-D23 — the Inform-style rulebook parser. |

If you find a reference to a `SkillMD-D` or `B` tag not listed here, add it
during the next implementation session and document it in
`IMPLEMENTATION_LOG.md`. Bare `D<N>` references that predate this rename
should be treated as `SkillMD-D<N>` unless they appear in
`meridian-handoff/docs/11_DECISIONS.md`.

---

*This document is intentionally append-only. If a future plan revises an item,
add a new section at the bottom explaining the revision rather than editing the
historical entry above.*
