# Prose And Autonomy

Meridian supports two opt-in prose modes for SKILL.md-shaped workflows.

`with discretion` is plan-then-execute mode. Unmatched English lines in that
workflow are lowered to `ProseStepIR`; generated Swift calls
`runtime.executeProsePlan(...)`. The runtime asks a typed `Planner` for a
`PlanProposal`, validates each proposed tool against the scoped tool list, and
executes the action itself.

`with autonomy` is loop mode. Unmatched English lines are lowered to autonomous
`ProseStepIR`; generated Swift calls `runtime.executeAutonomousLoop(...)`.
The runtime asks an `ActPlanner` for one action per turn, records observations,
routes every action through the same sealed executor, and can call a `Planner`
again after repeated failures.

Autonomy `until` and `unless` header clauses are enforced by generated
predicates over the runtime's current `StateSnapshot`. The runtime checks
`unless` as an abort guard and `until` as a success stop before planning; after
each accepted action, result bindings are merged into the loop snapshot so the
next predicate check can stop on newly produced state.

Examples:

```meridian
To plan risky cleanup for a pull request, with discretion:
  Read the current diff and propose the smallest safe cleanup actions.

To stabilize a pull request, with autonomy until the ci status is passed re-plan after 2 failures:
  Keep inspecting CI and apply the next smallest safe repair.
```

The LLM boundary is typed:

- `LLMProvider` can only produce completions.
- `Discretion` can only answer a boolean question.
- `Planner` can only propose a bounded plan.
- `ActPlanner` can only propose the next action or declare done.
- `PlanExecutor` is runtime-owned and validates tool IDs before invocation.
- Planner actions are validated against registered `ToolSchema` argument specs
  when a schema is present: missing required arguments, unexpected arguments,
  and common type mismatches are rejected before invocation.

Strict workflows still reject unresolved lines. Prose fallback only applies
inside headers that explicitly opt in with `with discretion` or `with autonomy`.

## Failure Identity

Planning/prose failures use stable `PlanningFailureCode` raw values carried by
`MeridianRuntimeError.toolError(.implementation(code: ...))`. Generated
`recover from ...:` blocks can match these names through `meridianMatches`.

Current codes:

- `planning.prose_payload_too_large`
- `planning.tool_arguments_payload_too_large`
- `planning.too_many_actions`
- `planning.replan_too_many_actions`
- `planning.max_steps_exceeded`
- `planning.host_policy_denied`
- `planning.tool_out_of_scope`
- `planning.tool_not_registered`
- `planning.missing_tool_argument`
- `planning.unexpected_tool_argument`
- `planning.invalid_tool_argument_type`
- `planning.snapshot_payload_too_large`
- `planning.history_payload_too_large`
- `planning.proposal_payload_too_large`

Telemetry uses the same values: `plan.error` includes `error_code` when one is
available, and `plan.rejected` includes `code`.

Resource limits cover prose bytes, state snapshot bytes, observation-history
bytes, planner-proposal bytes, action count, and tool-argument bytes. Accepted
prose/autonomy actions checkpoint the post-action loop snapshot so resume
contexts include planner-produced bindings.

## Strict contract: discretion / autonomy bodies are always prose

A workflow declared `with discretion` or `with autonomy` runs every body line
through the planner — there is no deterministic fallthrough. Even if a body
sentence happens to share words with a deterministic vocabulary phrase
(e.g. "Inspect the failing job…" overlapping with `to inspect the ci status of
a pull request`), the lowering emits a `ProseStepIR` and the `Planner` /
`ActPlanner` decides what runtime actions are taken. This is enforced in
`ASTToIR.lowerPhraseInvocation` and is verified by the
[`SkillExampleCorpusTests`](../Tests/MeridianCoreTests/SkillExampleCorpusTests.swift)
suite.

## Worked examples

End-to-end prose / autonomy samples live under `examples/skill/`. They share
the standalone `comprehensive_workflows.merconfig` vocabulary so each file can
focus on a single feature:

- `flaky_ci_stabilizer.meri` — autonomy with `until` / `unless` / replan / max steps.
- `large_release_train.meridian` — deterministic gate → discretion → autonomy.
- `policy_guarded_autonomy.meridian` — recover from `planning.host_policy_denied`
  and `planning.tool_out_of_scope`.
- `planner_schema_validation_demo.meri` — recover from every schema-validation
  `PlanningFailureCode` and from `planning.max_steps_exceeded`.
- `hotfix_commander.meridian` — autonomy abort guard via `unless` predicate
  combined with `wait for approval` and `wait for signal`.
- `incident_pr_response.meri` — discretion plan + autonomy mitigation with
  recover-on-failure cleanup.

Structural lowering assertions for each sample (autonomy config presence,
discretion vs autonomous-loop dispatch mode, recover code names, and so on)
live in [`SkillExampleCorpusTests`](../Tests/MeridianCoreTests/SkillExampleCorpusTests.swift).
