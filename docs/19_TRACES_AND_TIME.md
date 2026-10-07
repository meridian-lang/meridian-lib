# Traces And Time

Status: Wave 8 landed and the documentation now reflects **implemented,
named-test-backed behavior**. Cross-reference
`docs/cookbook/MERIDIAN_SEMANTICS.md`.

---

## 1. Purpose

Wave 8 makes traces part of Meridian's semantics, not just its debugging story.
This document is the operational companion to semantics clauses 4 through 6:

- the persisted trace schema
- the store behaviors that temporal/statistical meaning depends on
- ordering, scope, keying, and retention
- temporal/statistical lowering and replay
- monitors, capture policy, privacy, and performance limits

The semantics document is normative. This document describes how the repository
currently realizes that meaning.

---

## 2. Semantic Trace Record

The persisted record is `TraceRecord`
(`Sources/MeridianRuntime/Trace/TraceRecord.swift`). Its JSON keys are:

| Key | Type | Meaning |
| --- | --- | --- |
| `schemaVersion` | Int | Current value is `1`. |
| `id` | String | Monotonic ULID-style identifier; lexicographic order is meaningful. |
| `at` | Date | Runtime timestamp. |
| `ingestOrder` | Int | Monotone fallback order witness. |
| `run` | String | Run identifier. |
| `step` | String | Stable step path for history continuity. |
| `skillName` | String | History identity root. |
| `skillVersionHash` | String | Audit metadata only, not a history partition key. |
| `tag` | `TraceTag` | Closed semantic tag set. |
| `subject` | String? | Named thing/step/event the record is about. |
| `subjectKey` | String? | Per-instance key for keyed temporal/statistical definitions. |
| `payload` | `[String: Value]`? | Structured payload when capture policy keeps it. |
| `payloadHash` | String | Always present; canonical-JSON SHA-256. |
| `outcome` | `TraceOutcome`? | `success`, `failure`, or `indeterminate`. |
| `operationalDetail` | String? | Non-semantic runtime detail retained for audit. |
| `legacyKind` | String? | Source `EventKind.rawValue` for legacy round-trip. |

Tested invariants:

- `schemaVersion` starts at `1`; both stores accept current and N-1 schema
  versions.
- `payloadHash` is stable across JSON key order (`canonical JSON hash is stable
  across key order`).
- legacy `EventKind` values round-trip through semantic projection
  (`all legacy EventKind cases round-trip through semantic trace projection`).
- `skillVersionHash` does not partition `across all runs` history
  (`SEM_4_09 across-all-runs ignores version hash when skill identity is stable`).

The closed `TraceTag` set is:

`invoked`, `completed`, `failed`, `emitted`, `asserted`, `assert-failed`,
`branched`, `iterated`, `judged`, `committed`, `recovered`, `violated`.

Temporal/statistical operators query this semantic tag layer, not raw
`EventKind`.

---

## 3. Legacy Event Migration

`MeridianRuntime` still emits legacy `EventKind` values internally, but Wave 8
defines a stable semantic projection. The important mappings are:

- invoke start/end/error -> `invoked` / `completed` / `failed`
- plan/autonomy start/step/end/error/rejected -> `judged`
- branch/iterate/assert/emit/commit/recover -> `branched` / `iterated` /
  `asserted` or `assert-failed` / `emitted` / `committed` / `recovered`
- workflow lifecycle, bind, and wait lifecycle remain `operationalDetail`
  material unless adapted into a higher-level semantic record

This is pinned by:

- `all legacy EventKind cases round-trip through semantic trace projection`
- `SEM_4_04 judgment boundary maps to a judged record carrying a payload hash, kind, and tool scope`

Judgment boundaries retain a content hash, the legacy/runtime kind, a
tool-scope summary (`tool_count`), and the explicit scoped-tool-id list
(`scoped_tools`) in the payload.

---

## 4. Stores, Persistence, And Integrity

Wave 8 ships two store implementations:

- `InMemoryTraceStore` for tests, replay fixtures, and direct runtime use
- `JSONLTraceStore` for append-only local persistence and audit trails

See `docs/24_TRACE_STORAGE.md` for the JSONL envelope, capture policies, and shell-hole redaction.

The shared `TraceStore` protocol is:

- `append(_:)`
- `query(scope:runID:skillName:window:pattern:)`
- `compact(retention:now:)`
- `capabilities`
- `verifyChain(runID:)`

### 4.1 JSONL format

`JSONLTraceStore` persists one envelope per line:

```json
{ "record": <TraceRecord>, "checksum": "<canonical sha256>" }
```

The checksum covers the decoded `TraceRecord`, not the raw line bytes. On load:

- a bad checksum on a non-final line is a corruption error
- a torn final line is quarantined to a sibling
  `*.quarantine-<timestamp>` file and ignored on reopen
- the file is rewritten without the torn line after successful recovery

This behavior is pinned by `torn final JSONL line is quarantined and ignored on reopen`.

### 4.2 Durability and locking

`JSONLTraceStore` uses:

- a sidecar advisory lock file (`.lock`) via `lockf`
- durable append + `fsync` on the file and parent directory
- durable rewrite via temp file + replace + `fsync`

Within the retained window, records are append-only. Compaction removes expired
records only (`SEM-4-01 append-only within retention and retention compaction drops expired only`).

### 4.3 Query behavior

Both stores support the same observable query behavior:

- current-run queries sort by `ingestOrder`, then `at`, then `id`
- across-run queries sort by `at`, then `ingestOrder`, then `id`
- filters combine scope, skill, time window, tags, subject, subject key,
  outcome, and exact payload field matches

`JSONLTraceStore` maintains simple in-memory indexes for `run`, `tag`,
`subject`, and cross-run time order. Behavioral parity with the in-memory store
is pinned by `RISK-W8-05 in-memory and JSONL stores stay behaviorally aligned`.

---

## 5. Retention, Closed World, And Time

`TraceConfiguration.retention` is semantic, not housekeeping. Wave 8 behavior:

- temporal/statistical operators are closed-world over retained history
- a query window larger than configured retention is a compile-time
  `MER-TMP-011` (`traceWindowExceedsRetention`)
- the diagnostic names both the requested window and configured retention

Pinned by:

- `trace section and tool capture policies parse`
- `SEM_2_12 trace durations stay physical and deployment zones stay explicit`
- `NS-C-02 / SEM-4-06 window greater than retention reports MER-TMP-011 naming both durations`

Durations are physical time only: `7 days` means exactly `604_800` seconds.
`deployment zone` is explicit trace configuration metadata and is not inferred
from the host.

---

## 6. Ordering, Scope, Keying, And History Identity

Temporal/statistical meaning depends on four separate axes.

### 6.1 Ordering

- current-run queries use run-local emission order
- across-run queries use `at`, then `ingestOrder`, then `id`

Pinned by `SEM-4-02 ordering uses run order locally and at-ingest-id globally`.

### 6.2 Scope

- default scope is the current run
- `across all runs` widens only to runs with the same `skillName`

Cross-skill history is not expressible in v1.

Pinned by `SEM_4_03 across-all-runs uses skill scope and global ordering`.

### 6.3 Keying

Definitions on keyed kinds implicitly restrict matching by `subjectKey`.

- keyed temporal definitions thread a `subjectKeyExpr`
- keyed statistical definitions do the same
- unkeyed definitions are rejected with `MER-TMP-016`

Pinned by:

- `SEM_5_09 keyed temporal definition threads subject key into lowered IR`
- `SEM_5_09 keyed statistical definition threads subject key into lowered IR`
- `SEM_5_10 temporal definition on unkeyed kind reports MER-TMP-016`
- `SEM_5_09 subject key restricts temporal matching`

### 6.4 Stable step paths and skill version hashes

History continuity is keyed by `skillName + stable step path`, not by
`skillVersionHash`.

- unrelated edits must not perturb unaffected step paths
- whitespace-only edits may leave `skillVersionHash` stable
- meaning edits may change `skillVersionHash`
- `skillVersionHash` remains audit metadata even when it changes

Pinned by:

- `stable step paths survive unrelated edits`
- `SEM_4_09 across-all-runs ignores version hash when skill identity is stable`

---

## 7. Temporal Operators

`TraceEvaluator` implements a pure-past fragment over retained history.

| Surface | Runtime query | Pinned behavior |
| --- | --- | --- |
| `E has ever occurred` | `.ever` | `SEM_5_02 ever matches retained scoped history` |
| `E has occurred within the last D` | `.withinWindow` | `SEM_5_03 withinWindow uses inclusive old end` |
| `E has occurred N times within the last D` | `.countInWindow` | `SEM_5_04 countInWindow compares at least at most exactly` |
| `E has occurred N times in a row` | `.inARow` | `SEM_5_05 inARow uses qualifying subsequence and prevented invoke does not qualify` |
| `since the last E, C` | `.sinceLast` | `SEM_5_06 sinceLast is strict after anchor and indeterminate without anchor` |

Other pinned temporal semantics:

- pure-past only: future-looking forms are rejected (`MER-TMP-013`)
- vague `recently` is rejected (`MER-TMP-017`)
- bare perfect without `ever`/window/count is rejected (`MER-TMP-010`)
- causal `since` is rejected (`MER-TMP-012`)
- progressive aspect is rejected (`MER-TMP-018`)

### 7.1 `since the last` holds resolution

`since the last <anchor>` keeps authored wording in IR but lowers the runtime
query from a resolved event pattern:

1. direct event-pattern holds: supported
2. event-backed adjective holds: supported and expanded to an event pattern
3. pure state-predicate holds: rejected with `MER-TMP-019`

Pinned by:

- `since-the-last with an event-backed adjective holds lowers to a runtime-evaluable pattern`
- `MER-TMP-019 a pure state-predicate 'since the last' holds is rejected`

Residual limitation: Meridian v1 does **not** retain state history, so a pure
state predicate such as `the service is healthy since the last ...` is still
unsupported.

### 7.2 In-a-row caveat

Semantic ordering is implemented and tested, including prevented invokes and
cross-run/current-run contrast. The advisory lint for author-surprising
simultaneous interleavings is also implemented: `across all runs` scoped
`in a row` queries warn about interleaved ordering, while `current run` `in a
row` and `count in window` queries do not (they have no cross-run interleaving
to warn about). Pinned by `SEM_5_11 across-all-runs in-a-row warns about
interleaved ordering`, `SEM_5_11 current-run in-a-row does not warn`, and
`SEM_5_11 count-in-window does not warn`.

---

## 8. Statistical Operators And Monitors

Wave 8 supports:

- explicit percentage bounds: `at least N%`, `at most N%`
- denominator choice: `of runs` vs `of occurrences`
- lexical sugar: `usually` / `rarely`
- optional windows
- sample-floor indeterminacy
- monitored statistical assertions

Pinned behavior:

- `SEM_6_01 TraceStatistical occurrences compare against explicit threshold`
- `SEM_6_02 TraceStatistical sample floor yields indeterminate`
- `SEM_6_03 TraceStatistical runs use the last qualifying event per run`
- `SEM_6_04 with 95% confidence is reserved and rejected`
- `SEM_6_05 syntactic analysis is conservative and transitive only`

`usually` and `rarely` verbalize numerically; they do not print as fuzzy prose
in Canonical English.

### 8.1 Monitored assertions

A statistical `assert` lowers to a monitored, non-blocking assertion when it is
configured as a monitor:

- cadence comes from `=== trace ===` `default monitor cadence:` unless overridden
- generated Swift registers the monitor with
  `runtime.registerMonitor(query:cadence:message:blocking:step:sourceRange:)`
- monitored statistical asserts allow `indeterminate` outcomes and do not use
  branch-style totality enforcement

Pinned by:

- `SEM_2_11 decision-point totality is not enforced on monitored statistical assertions`
- `etl pipeline reliability watch compiles monitor cadence and denominator contrast`
- `erp payment failure monitor compiles default-cadence monitor and streak hook`

---

## 9. Compound Note Form

`proceed, and note "<text>" in the <binding>` is a real Wave 8 surface, not a
placeholder. It:

- requires an already-declared binding
- requires the binding to be `text`
- desugars to a text-appending `rebind`
- introduces no new IR primitive

Pinned by:

- `COOK-14 compound note desugars to a rebind that appends text (no new IR primitive)`
- `COOK-14 compound note canonical form round trips`
- `COOK-14 compound note into an undeclared binding reports MER-REF-004`
- `COOK-14 compound note into a non-text binding reports MER-TYP-001`

Generated Swift appends with ordinary `state.rebind(...)` string concatenation.

---

## 10. K3 And Decision-Point Totality

Wave 8 uses Kleene strong three-valued logic when a subexpression is
possibly-indeterminate.

Pinned truth-table examples:

- `false and unknown = false`
- `true or unknown = true`
- `true and unknown = unknown`
- `unknown or false = unknown`
- `not unknown = unknown`

These are all covered by `SEM-2-10 K3 truth table`.

Decision-point totality today:

- branch conditions are checked
- monitored statistical asserts are intentionally not branch-totality checked
- ordinary `otherwise` covers `false` plus `indeterminate` when no unknown arm exists
- when an explicit unknown arm exists, `otherwise` covers `false` only

The D7a blocking-assert/obligation-site variant is also implemented: a
blocking `assert` (no `otherwise` fallback) whose lowered condition
structurally contains `since the last` reports `MER-STA-001` at compile time,
since the anchorless case can be indeterminate and a blocking assert site has
no branch to fall through to. A branch with an explicit `otherwise` remains
accepted. Pinned by `NS-C-07 Broken Twin line 7 reports MER-STA-001 for a
blocking assert with no default policy` and `NS-C-07 near miss branch with
otherwise remains accepted`.

---

## 11. Capture Policy, Privacy, And Store Failures

### 11.1 Capture policy

Per-tool capture policy supports:

- `full`
- `hash-only`
- `redacted(fields)`

The content hash is mandatory under all three. This is pinned by:

- `trace section and tool capture policies parse`
- `governance access review freshness compiles production trace capture policy`
- `clinical handoff reliability monitor compiles privacy-safe tool scope`

Practical privacy guidance from the current implementation:

- treat the trace store as a shadow data system
- use `hash-only` when historical existence/comparison is enough
- use `redacted(fields)` when the payload shape is needed but particular fields
  must not be stored in clear
- remember that judgment/tool boundaries can carry sensitive inputs or outputs;
  capture policy applies there too

Related compile-time trace logging (`ParserTrace`) redacts obvious secret-bearing
fields before emission, but that is separate from semantic trace-store capture.

Residual: D9's production-profile guard is still missing. A production profile
without explicit per-tool capture policies still compiles today.

### 11.2 Store failure policy

Wave 8 supports:

- **fail-closed** — append/observer failures propagate on strict emits
- **fail-open** — after recovery, a degraded-witnessing marker is appended

**`.auto` always resolves to `.failClosed` at compile time.** `TraceIdentityPlanner`
replaces unresolved `.auto` (including when the `=== trace ===` section omits an
explicit policy) with `.failClosed` before codegen, so `Runtime` never sees `.auto`
(which would otherwise behave as fail-open). Explicit `.failOpen` / `.failClosed`
declarations are preserved. `TraceConfiguration.default.storeFailurePolicy` is
`.failClosed` for hosts that construct a runtime without the planner.

Pinned by `TraceIdentityPlannerD8Tests` and:

- `SEM-4-07 fail-closed rethrows append failures on strict emits`
- `SEM-4-07 fail-open emits a degraded-witnessing marker after recovery`

The fail-open marker uses semantic tag `failed`, subject `trace-store`, and
`operationalDetail == "degraded-witnessing-marker"`.

### 11.3 Terminal failures and monitor violations

- **`workflow.failed`** — generated `run()` wraps failures in `do/catch` and
  calls `Runtime.workflowFailed(…)` before rethrowing, emitting a terminal
  `EventKind.workflowFailed` (`"workflow.failed"`) with workflow name, error,
  optional `step`, and `source` range. Cancellation is not recorded.
- **`violated`** — blocking monitor assertions append a `TraceRecord` with
  tag `.violated`, `outcome: .failure`, and payload fields `message`, `step`,
  `subject_key` (from the monitor's keyed definition). This is semantic trace
  material, distinct from legacy `assert.failed` events.

### 11.4 Driver `TraceStore` wiring

When a workflow carries `runtimeTraceConfiguration` (from `=== trace ===`),
generated drivers and `DriverSourceBuilder` wire a store before `Runtime` init:

```
runtimeTraceConfiguration (compiled from merconfig + TraceIdentityPlanner)
  → switch store { .memory → InMemoryTraceStore, .file → JSONLTraceStore }
  → Runtime(traceStore:, traceConfiguration:, traceSkillIdentity:)
```

`meridian run` / `RuntimeExecutor` use this bootstrap when trace configuration
is present; in-memory stores are used for tests and ephemeral runs, file-backed
`JSONLTraceStore` for persisted audit trails (temp path keyed by `runID` in the
generated driver). Semantic records are appended from `Runtime.emit` alongside
legacy `Observer` events — the two sinks are independent but share `runID`,
step paths, and source ranges from the manifest map.

---

## 12. Replay, Verification, And Benchmarks

### 12.1 Replay semantics

Replay is pure over `(store, TraceEvaluationContext)`:

- `evaluationInstant` is explicit input
- the evaluator does not read wall clock during replay
- fixed context yields deterministic truth values and witness ids

Pinned by:

- `SEM_5_07 fixed context yields deterministic result`
- `SEM_5_08 replay semantics depend only on explicit evaluation instant`
- `SEM_5_08 in-memory and JSONL replay results agree across operator families`
- `SEM_5_08 replay result encoding is byte-identical`

### 12.2 CLI surfaces

Wave 8 adds these audit/replay commands:

- `meridian trace eval <trace.jsonl> "<expression>" --at <iso8601>`
- `meridian trace-eval ...` as a top-level alias
- `meridian trace verify <trace.jsonl> --run <id> [--json]`
- `meridian bench-trace [--format json|text]`

Pinned CLI behavior:

- `trace eval JSON schema is stable`
- `trace-eval alias is byte-identical across repeated replays`
- `trace eval rejects ambiguous current-run replay`
- `bench-trace JSON schema covers all measurement combinations`

Current `trace eval` limitations:

- it only replays expressions that lower to temporal/statistical queries
- it supports simple `whose <field> is <value>` equality payload predicates
  (event and statistical patterns); a predicate that doesn't reduce to that
  shape is a `ValidationError`, not a silent drop
- current-run replay requires exactly one run in the store
- replay currently infers exactly one `skillName` from the store contents

Pinned by `trace eval replays a whose-qualified event payload predicate`
(matching vs. non-matching payload values through the CLI end-to-end) and
`8D trace eval replays a statistical expression across all runs` in
`Tests/MeridianCLITests/TraceReplayCommandTests.swift`.

### 12.3 Bench artifact and interpretation

The runner measures:

- dataset sizes `10_000` and `100_000`
- both store kinds (`in_memory`, `jsonl`)
- both `cold` and `warm` labels
- operator families `ever`, `window`, `count`, `streak`, `since`,
  `statistical_frequency`

Interpret the numbers carefully:

- the benchmark uses one store instance per dataset
- `warm` means "after an extra warm-up evaluation for that family"
- `cold` does **not** recreate the store from scratch for every family
- on JSONL, the very first evaluation on a fresh store also pays lazy file-load cost

The artifact is therefore best treated as comparative implementation evidence,
not a portable SLA.

---

## 13. Performance And Limits

What Wave 8 proves today:

- the semantic evaluator is deterministic
- the in-memory and JSONL stores are behaviorally aligned
- benchmark output is committed and reproducible through `meridian bench-trace`

What it does **not** promise:

- distributed trace backends
- OpenTelemetry export
- remote trust anchors or signatures
- a universally applicable latency target across machines
- state-history-backed `since the last` for pure state predicates

If a stronger backend is ever needed, the justification point is measured
benchmark pain, not speculation.

---

## 14. Diagnostics And Reservations

### 14.1 Diagnostic families

| Code | Meaning | Coverage |
| --- | --- | --- |
| `MER-TMP-010` | bare perfect trace predicate | `NS-C-01` |
| `MER-TMP-011` | window exceeds retention | `NS-C-02 / SEM-4-06` |
| `MER-TMP-012` | causal `since` form | `NS-C-03` |
| `MER-TMP-013` | future trace predicate | `NS-C-05` |
| `MER-TMP-014` | unknown trace step | near-miss check against the subject's declared tool-name vocabulary — `GAP-TMP-14-15` |
| `MER-TMP-015` | unknown trace payload field | near-miss check against the subject's declared tool parameter names — `GAP-TMP-14-15` |
| `MER-TMP-016` | unkeyed temporal/statistical definition | `SEM_5_10` |
| `MER-TMP-017` | vague `recently` | `NS-C-04` |
| `MER-TMP-018` | progressive trace predicate | `COOK-20` |
| `MER-TMP-019` | pure state-predicate `since the last` holds | `MER-TMP-019 ...` |
| `MER-STA-001` | missing unknown/default handling at a decision point | `NS-C-06`, `SEM_6_02`, `NS-C-07` (D7a blocking-assert variant) |
| `MER-STA-002` | reserved confidence wording | `SEM_6_04` |
| `MER-STA-003` | vague statistical frequency wording | `mersta003VagueFrequency` ("most of the time") |
| `MER-REF-004` | compound-note binding undeclared | `COOK-14` |
| `MER-TYP-001` | compound-note binding not text | `COOK-14` |

### 14.2 `MER-TMP-014` / `MER-TMP-015` scope note

No Wave 8 requirement remains open. `MER-TMP-014`/`MER-TMP-015` are **not**
a closed instrumentation/payload-shape registry — Meridian has no such
registry, and a step or `whose` field the compiler has never seen still
compiles (open-world instrumentation is intentional: workflows can invoke
tools and reference their outputs freely). What they *do* check is a
near-miss: a temporal adjective's event-pattern subject/payload is compared
against the subject kind's declared tool vocabulary (step names) and that
tool's declared parameter names (payload fields) inside
`lowerRegisteredDefinitions()`; a name that's *close* to — but not exactly —
a declared name (e.g. a typo like `deply` for a declared `deploy.rollback`
tool, or `targt` for a declared `target` parameter) is rejected with a
"declared step names in scope" / field-name suggestion, while a novel,
self-consistent name with no near-miss compiles cleanly. Pinned by
`GAP-TMP-14-15` and directly by
`Tests/MeridianCoreTests/Inform7/TraceTemporalInform7Tests.swift`.
