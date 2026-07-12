# MERIDIAN_SEMANTICS.md
## The Meridian Kernel Semantics, v0.2 draft
### Typed core, trace model, temporal and statistical operators, deontic layer, verbalization law

Status: v0.2 draft with maintainer confirmations folded in on 2026-07-11. Implementation prompts (Waves 7 to 9) treat this document as the oracle: every numbered clause maps to conformance tests named `SEM-<section>-<n>`.

Style note: this document defines MEANING, not surface grammar and not implementation. Surface English forms are quoted only as examples; the grammar lives in the language reference. Notation is lightweight: `⟦X⟧` is "the denotation of X", `Γ` is an environment, `σ` is a snapshot, `τ` is a trace.

v0.2 changelog (Wave 8 oracle amendments): keying for temporal/statistical definitions; physical-time-only durations; K3 three-valued composition and decision-point totality; expanded trace schema and payload policy; trace append failure policy; history continuity by skill name plus stable step path; clarified temporal window boundaries and replay semantics; conservative possibly-indeterminate analysis; compound note form desugaring.

---

## 1. Scope and stance

1.1. This document assigns meaning to the deterministic kernel of Meridian: terms, conditions, descriptions, definitions, relations, quantifiers (the Wave 2 to 4 language), plus three new layers: temporal operators, statistical operators, and deontic operators.

1.2. Judgment blocks (`use judgment`, `with discretion`, `with autonomy`) are OUTSIDE this semantics by design. Their meaning is a typed contract: declared inputs, declared output kind, declared tool scope. The kernel semantics treats a judgment block as an opaque function of that signature whose invocation is recorded in the trace (4.4). Nothing inside the block is assigned meaning here. This boundary is the quarantine principle and it is load-bearing: total language coverage is achieved by giving every sentence a home, not by assigning logic to vague English.

1.3. Two projections are derived from this one semantics:
- `⟦·⟧_exec`: the executable projection (generated Swift against MeridianRuntime).
- `⟦·⟧_proof`: the verification projection (proof obligations).
Clause 8 states the coherence requirement between them. A construct may be marked exec-only or proof-only; everything else must agree.

---

## 2. The typed core

### 2.1 Kinds and values
- Base kinds: `text`, `integer`, `decimal`, `boolean`, `date`, `duration`, plus enumerated kinds declared via `can be X or Y`.
- Declared kinds form a single-inheritance lattice under `is a kind of`, rooted at `value` for data kinds. Subkind values are values of every ancestor kind.
- Constructed kinds: `list of K`, `optional K`. `optional K` has values `some(v)` for `v : K`, and `nothing`.
- Every value has exactly one most-specific kind. The type checker assigns every term a static kind; this semantics assumes well-typed input only. Ill-typed sources have no meaning; they have problem messages.

### 2.1.1 Keying
Kinds may declare `keyed by the <property>`. A kind has at most one key; subkinds inherit the same key unless they inherit from an unkeyed ancestor and declare one of their own. Inside temporal or statistical definitions on kind `K`, every event pattern is implicitly restricted to events whose subject key equals the instance's key. Workflow-level temporal/statistical conditions are keyless. A temporal or statistical definition on an unkeyed kind is ill-formed. [SEM-5-09] [SEM-5-10]

### 2.2 Environments and snapshots
- An environment `Γ` maps names (parameters, let-bound locals, iteration variables, constants) to values.
- A snapshot `σ` is an immutable view of tool-reachable data bound at explicit fetch points. Tools are effectful; conditions and descriptions are not. The bridge rule:

2.2.1 (Single-fetch rule). Every description, quantifier, and statistical evaluation names a fetch point. The collection or data it ranges over is obtained exactly once at that point and bound into `σ`. All evaluation within one fetch point's scope sees the same `σ`. Re-evaluation is a new fetch point. Consequence: within one evaluation, results are stable even under concurrent external mutation. [SEM-2-01]

### 2.3 Terms
- Literals denote themselves. Names denote `Γ(name)`.
- Property access: `⟦the X's p⟧(Γ,σ) = π_p(⟦the X⟧(Γ,σ))` where `π_p` is the property projection declared on the kind (or inherited). Accessing a property through `nothing` is a runtime error routed to recover semantics, never a default value. [SEM-2-02]
- String, numeric, date, and duration operations carry their standard meanings; `date + duration : date`; `date - date : duration`. Decimal arithmetic is exact decimal, not binary floating point. [SEM-2-03]

2.3.1. Durations are PHYSICAL TIME only: `7 days` means exactly 168 hours. Meridian v1 does not define calendar arithmetic, DST-aware arithmetic, or timezone-relative duration semantics. Dates compare on the timeline. Formatting forms such as `as a short date` render in one configured deployment zone, default UTC. [SEM-2-12]

### 2.4 Conditions (the FOL core)
Conditions denote `boolean` when every subexpression is two-valued, and denote a promoted `TruthValue ∈ {true, false, unknown}` when any subexpression is possibly-indeterminate:
- Comparators `is, is not, is more than, is less than, is at least, is at most, contains, is one of` carry their standard meanings per kind; comparing values of incomparable kinds is ill-typed.
- `not`, `and`, `or` are classical for purely boolean/FOL conditions. When a subexpression is promoted to `TruthValue`, composition follows 2.4.1 instead. Precedence: not > and > or. Mixed and/or at one level without `either ... or` grouping is ill-formed (a grammar rule, restated here because it protects determinism of meaning). [SEM-2-04]
- Adjectives: an adjective `a` defined on kind `K` denotes a predicate `⟦a⟧_K : K -> boolean | TruthValue` given by its definition body (2.5). `x is a` means `⟦a⟧_K(x)`; `x is not a` is its negation.

### 2.4.1 Three-valued composition (K3)
When a subexpression is possibly-indeterminate, Meridian promotes the containing expression to `TruthValue` and uses Kleene strong three-valued logic:
- `false and X = false`
- `true or X = true`
- `true and unknown = unknown`
- `unknown or false = unknown`
- `not unknown = unknown`

Totality is enforced at DECISION POINTS only: branch conditions, blocking asserts and obligations, and quantifier results feeding either. Inside expressions, `unknown` flows freely. Quantifier lifting when the predicate is possibly-indeterminate is defined as follows: `all` folds with K3-and; `any`/`some` folds with K3-or; `no` is `not any`; numeric forms use definite-true and possible-true bounds (`at least n` checks the lower bound, `at most n` checks the upper bound, `exactly n` requires both). When the predicate is two-valued, the classical empty-domain behavior of 2.8 applies unchanged. Ordinary `otherwise` is an explicit default covering BOTH false and indeterminate when no unknown arm exists. If an unknown arm exists, it receives indeterminate and `otherwise` receives false only. SEM-2-10 and SEM-2-11 are reserved for the nine-cell truth-table suite and decision-point enforcement suite.

### 2.5 Definitions
`Definition: a K is a if C.` defines `⟦a⟧_K(x) = ⟦C⟧(Γ[it := x], σ)`.
- Well-foundedness: the dependency graph of definitions must be acyclic. Recursive and mutually recursive definitions are ill-formed. [SEM-2-05]
- Inheritance: `a` is available on every subkind of `K`; the most specific definition wins when shadowed. Shadowing that changes the predicate's truth value on shared instances is permitted but flagged by lint, since it is the lattice's only semantic foot-gun. [SEM-2-06]

### 2.6 Relations
A declared relation `R` with arity in {1:1, 1:n, n:1, n:n} between kinds `A` and `B` denotes a set of pairs `⟦R⟧(σ) ⊆ A × B`, computed from its mandatory backing (property path or tool) at the governing fetch point. Verb forms are notational: `x V y`, `ys V-ed by x`, and `ys that x V-s` all denote membership tests or comprehensions over `⟦R⟧(σ)`. An unbacked relation has no denotation and is ill-formed. [SEM-2-07]

### 2.7 Descriptions
A description `D` (kind head + adjectives + whose-clauses + verb clauses + ordering + take) denotes a finite LIST (ordered), not a set:
`⟦D⟧(Γ,σ) = take_n( sort_k( filter_φ( source(σ) )))`
- `source` is the fetch-point collection for the head kind.
- `filter_φ` is the conjunction of all restriction clauses.
- `sort_k` is the declared ordering; when no ordering is declared, the source order is preserved as delivered at the fetch point, and that order is part of the meaning (it is witnessed in the trace). [DECISION D0, CONFIRMED by maintainer 2026-07-11: source order is meaningful and preserved; the alternative, unordered set semantics, breaks `the first N` and replayability.] [SEM-2-08]
- `the number of D` denotes `length(⟦D⟧)`; `the list of D` denotes `⟦D⟧` itself.

### 2.8 Quantifiers
Over a description `D` and condition `C` with bound variable `it`:
- `all D C` is true iff `C` holds for every element (vacuously true on empty `⟦D⟧`).
- `any/some D C` is true iff it holds for at least one (false on empty).
- `no D C` ≡ `not (any D C)`.
- `at least n / at most n / exactly n D C` compare `|{x ∈ ⟦D⟧ : C(x)}|` with `n`.
Empty-domain behavior is part of the meaning and must be documented at the surface. When `C` is possibly-indeterminate, 2.4.1's lifted K3 quantifier rules apply instead of direct cardinality over a two-valued predicate. [SEM-2-09]

### 2.9 Compound note form
The compound workflow sentence `proceed, and note "<text>" in the <binding>` is legal only when the named binding already exists and has kind `text`. It appends deterministically to that binding, is a compile error when the binding is undeclared or non-text, and desugars entirely to existing bind/rebind behavior; it introduces no new IR primitive.

---

## 3. Workflow meaning (informative summary)

The 13 IR primitives have operational meaning in MeridianRuntime and are not redefined here. `bind` and `rebind` share `BindIR`; AI inference is split into `aiJudgment` and `aiAutonomy`. This document touches the IR at exactly three seams: (a) every primitive execution emits trace events per clause 4; (b) `assert` conditions and `branch`/`iterate` predicates take their meaning from clause 2; (c) deontic lowering inserts guards and asserts per clause 7. The semantics of `commit`/`recover` (transactional grouping and compensation) is assumed as implemented and witnessed; formalizing it is future work flagged in 9.3.

---

## 4. The trace model

The trace is the semantic model for temporal and statistical operators, and the witness substrate shared with WDD.

### 4.1 Events
A trace `τ` is a finite sequence of events. An event `e` is a record:
- `schema_version`: the trace schema version understood by readers and artifacts.
- `id`: globally unique, lexicographically time-sortable (ULID class).
- `at`: timestamp (runtime clock; see 4.5).
- `ingest_order`: store-assigned monotone tie-breaker when clock order alone is insufficient.
- `run`: workflow-run identifier.
- `step`: stable step path within the compiled workflow.
- `skill`: `{ name, versionHash }`, where `versionHash` is audit metadata only and does not partition history (4.9).
- `tag` ∈ { invoked, completed, failed, emitted, asserted, assert-failed, branched, iterated, judged, committed, recovered, violated }.
- `subject`: the tool id, relation, kind, or store subject the event concerns, when applicable.
- `payload`: the structured argument/result data, stored as canonical JSON with a content hash. The content hash is mandatory even when the body is redacted or omitted.
- `witness` (optional): one deterministic witness instance for quantified or description-based failures, subject to the capture policy.
- `prev_hash` (optional): predecessor hash within a run when chaining is enabled.
- `record_hash` (optional): hash of the canonical event record for tamper evidence or external anchoring.
- `operational_detail` (optional): non-semantic runtime detail that should be preserved for audit but not lifted into the closed semantic tag set.
- `outcome`: success | failure | indeterminate, where applicable.

4.1.1. Append-only: events are never mutated or deleted within the retention window. [SEM-4-01]
4.1.2. Optional hash chaining (each event carries the hash of its predecessor within a run) provides tamper evidence; chaining is a store capability, not a semantic requirement. (This is the receipts tie-in.)

### 4.2 Ordering
Events within one `run` are totally ordered by emission. Across runs, ordering is by `at`, then `ingest_order` when present, then `id` as final tiebreaker. Temporal operators over a single run use run order; operators marked `across all runs` use the global order. [SEM-4-02]

### 4.3 Scope
Every temporal/statistical evaluation has a scope:
- default scope: the current run.
- `across all runs` (explicit surface marker): all runs sharing the same skill NAME and the same stable step path continuity within the window; `versionHash` does not partition that history.
- [DECISION D4, CONFIRMED by maintainer 2026-07-11: cross-skill scopes are not expressible in v1; they invite accidental global coupling.] [SEM-4-03]

### 4.4 Judgment events
Every judgment-block invocation emits `judged` with the input payload hash, output payload hash, declared output kind, and tool scope used. The kernel thereby witnesses the boundary of every non-deterministic region. [SEM-4-04]

### 4.5 Time
`at` comes from the runtime clock built-in, assumed monotone non-decreasing within a run. Clock skew across machines is out of scope in v1; `ingest_order` exists as a store-assigned fallback ordering witness when timestamps tie or skew. [SEM-4-05]

### 4.6 Retention and the closed window
Each deployment configures a retention duration `ρ` (and optionally a count bound). The semantic consequence:

4.6.1 [DECISION D1, CONFIRMED by maintainer 2026-07-11]. Temporal and statistical operators are evaluated CLOSED-WORLD over the retained window: "has ever" means "has occurred within retention". A surface form whose stated window exceeds configured retention is a COMPILE-TIME error, not a silently narrower query. Rationale: silent narrowing is a lie in English clothing; the compile error forces either a bigger `ρ` or honest phrasing. [SEM-4-06]

### 4.7 Trace append failure
[DECISION D8, CONFIRMED by maintainer 2026-07-11]. If a skill contains any blocking `AssertIR` or blocking monitor, trace-append failure is FAIL-CLOSED: execution halts through the governing recover path because witnessing is part of the meaning of enforcement. Otherwise, the runtime is FAIL-OPEN: work may continue, but recovery from the trace-store outage must emit a degraded-witnessing marker using semantic tag `failed` with subject `trace-store`, so the missing witness interval is itself witnessed. [SEM-4-07]

### 4.8 Payload capture policy
[DECISION D9, CONFIRMED by maintainer 2026-07-11]. Every tool and judgment boundary has a declared capture mode: `full`, `hash-only`, or `redacted(fields)`. The content hash is always mandatory. Production profiles require an explicit policy per tool; omitting one is a compile-time error. Development profiles may default to `full`. [SEM-4-08]

### 4.9 History continuity
[DECISION D10, CONFIRMED by maintainer 2026-07-11]. Temporal history binds to skill NAME plus stable STEP PATH. The `versionHash` is audit metadata only: it records which compiled artifact emitted an event, but it does not partition the history seen by temporal or statistical operators. A step-path change is therefore a semantic history break and must be surfaced as such by tooling. [SEM-4-09]

---

## 5. Temporal operators (pure-past, metric, counting)

v1 deliberately restricts to the pure-past fragment evaluated over the finite trace prefix at an evaluation instant `t`. Future-looking operators (`eventually`, `always henceforth`) have no executable meaning at an instant and are proof-mode-only; they are deferred entirely from v1. [SEM-5-01]

Let `E` be an event pattern: a predicate over events built from `tag`, `subject`, `outcome`, and payload property comparisons (kernel conditions lifted to payloads). Let `D` be a duration literal. All operators respect scope (4.3) and the closed window (4.6). Run order includes interleavings produced by `simultaneously`; that order is semantically real, even when author-surprising. Implementations should lint, but not reject, an in-a-row claim whose qualifying subject can be touched inside a `simultaneously` block. [SEM-5-11]

5.1 `E has ever occurred` : true iff some event in scope matches `E`. [SEM-5-02]

5.2 `E has occurred within the last D` : true iff some matching event lies in the closed metric window `t - D ≤ at ≤ t`. [SEM-5-03]

5.3 `E has occurred n times within the last D` : count of matching events in the metric window compared with `n`; variants `at least / at most / exactly n times`. [SEM-5-04]

5.4 `E has occurred n times in a row` : among the subsequence of QUALIFYING events (those matching `E`'s pattern with outcome ignored), the most recent `n` all satisfy `E`'s full pattern including outcome. Example: "the deploy has failed twice in a row" ranges over deploy attempts and requires the last two to be failures. The qualifying-subsequence rule is the entire meaning; implementations must not count over the whole trace. Prevented invokes never qualify for in-a-row because no completion event occurred. [SEM-5-05]

5.5 `since the last E, C` : let `e*` be the most recent event matching `E`.
- If `e*` exists: true iff condition/pattern `C` has held at every evaluation point STRICTLY AFTER `e*` (for event-pattern `C`: no violating event strictly after `e*`). If the anchor is at `t`, the post-anchor window is empty, so the result is vacuous per the embedded quantifier.
- If no `e*` exists in scope: the form is INDETERMINATE, and the decision-point totality rule applies (the surface must handle it explicitly, guard with 5.1, or provide a default branch where allowed). [DECISION D7, CONFIRMED by maintainer 2026-07-11: `since the last E` with no anchor is indeterminate, not vacuously true.] [SEM-5-06]
- If this possibly-indeterminate form feeds a blocking obligation or blocking assert, the source must provide an explicit unknown/default policy arm at compile time; omission is ill-formed. [DECISION D7a, CONFIRMED by maintainer 2026-07-11.]

5.6 Composition: temporal operators are conditions; they compose with boolean structure and may appear inside definitions. A definition whose body contains a temporal operator is a TEMPORAL ADJECTIVE (e.g. "flaky"); it is evaluated against `(Γ, σ, τ, t)` and is exec-legal everywhere conditions are. [SEM-5-07]

5.7 Determinism statement: for fixed `(Γ, σ, τ, t)`, every temporal operator denotes a unique value in {true, false, indeterminate}. Replaying the same trace prefix reproduces the same answers. This is the property that makes temporal English auditable. [SEM-5-08]

5.8 Replay note (informative): replay is byte-for-byte over the chosen trace prefix and evaluation instant. `now` is always an explicit parameter to temporal/statistical evaluation and never an implicit wall-clock lookup during replay.

---

## 6. Statistical operators

6.1 Frequency form: `E succeeds in at least p% of runs` (and `at most`, and over events rather than runs) denotes: let `q` = matching qualifying occurrences in scope and window, `s` = those with the stated outcome. The claim compares `s/q` with `p/100`.

6.2 Lexical defaults: `usually` = at least `P_u` (default 90, merconfig-configurable); `rarely` = at most `P_r` (default 10). The numeric reading is always available and always what the verbalizer prints. [SEM-6-01]

6.3 Sample floor and three-valued totality [DECISION D2, CONFIRMED by maintainer 2026-07-11]:
- A minimum sample size `n₀` (default 20, configurable) applies. If `q < n₀`, the operator denotes INDETERMINATE.
- TOTALITY RULE: any DECISION POINT whose behavior depends on a possibly-indeterminate value must handle indeterminacy explicitly (an `if it is unknown whether ...` arm, or an explicit default branch where allowed). Absence of handling is a compile-time error. Indeterminate never silently coerces to false, because "we lack evidence" and "it is rare" are different facts and conflating them is how statistical assertions become lies. [SEM-6-02]

6.4 Statistical claims in Contract sections become MONITORED assertions: evaluated at the declared cadence, emitting `asserted`/`assert-failed` events, with indeterminate emitting `asserted` with outcome indeterminate. They never block execution unless marked blocking. [SEM-6-03]

6.5 Confidence-interval semantics (Wilson bounds instead of raw ratio) is acknowledged and deferred; the spec reserves the surface `with 95% confidence` as ill-formed-for-now rather than meaning raw ratio. [SEM-6-04]

6.6 Possibly-indeterminate analysis
An expression is possibly-indeterminate iff it syntactically contains (a) a statistical operator, (b) a `since the last` form, or (c) an adjective whose definition body is possibly-indeterminate, computed transitively over the acyclic definition graph. v1 performs no flow analysis, no constant propagation, and no window-size reasoning. Conservatism here is part of the semantics, not an implementation shortcut. [SEM-6-05]

---

## 7. Deontic operators

Deontic sentences relate a SCOPE (workflow, section, or kind), a NORM, and a SUBJECT (an action pattern or a state condition).

7.1 Forms:
- Prohibition: `<subject> must not <action pattern>` (action: an invoke pattern over tool id + argument conditions).
- Obligation: `<state condition> must hold` / `<subject> must <action/state>`.
- Permission: `<subject> may <action pattern>`.

7.2 Trace meaning (the single source of truth): a trace `τ` COMPLIES with a prohibition iff no `invoked` event in scope matches the prohibited pattern; with a state obligation iff the condition holds at every designated evaluation point in scope; with permission iff (in a default-deny scope) every matching `invoked` event is covered by some permission. Compliance is a property of traces; everything else is projection. [SEM-7-01]

7.3 Violation timing [DECISION D3, CONFIRMED by maintainer 2026-07-11]:
- Prohibitions are ATTEMPT-TIME: the executable projection inserts a guard before the matching invoke; a blocked attempt emits `violated` with disposition `prevented`, and the invoke does not occur.
- State obligations are EFFECT-TIME: checked at commit points and section exits within scope; a failure emits `violated` with disposition `observed` and routes to the governing recover handler.
- Both dispositions are trace events: even PREVENTED violations are witnessed, which is what makes the deontic layer auditable rather than merely defensive. [SEM-7-02]

7.4 Permission and tools: `may` over tool-invoke patterns GENERALIZES the existing scopedTools allow-list: a bare tool allow-list is the degenerate case `may invoke <tool>` with no argument conditions. v1 ships argument-conditioned permissions (e.g. "the briefing skill may send email only to the user's own address") lowering to argument guards. [SEM-7-03]

7.5 Conflicts: a prohibition and a permission matching the same action in the same scope are a COMPILE-TIME conflict error naming both sources; prohibition does not silently win. Nested scopes: the more specific scope wins, and a specific permission cannot override an outer prohibition (deny is sticky downward). [SEM-7-04]

7.6 Proof projection: each norm emits a proof obligation: prohibition -> unreachability of the guarded invoke under the guard; obligation -> invariant at designated points; permission -> coverage completeness in default-deny scopes. v1 emits obligations as structured artifacts (8.2) without committing to a prover.

---

## 8. The two projections and coherence

8.1 Coherence requirement: for every kernel construct with both projections, and every trace `τ` produced by `⟦·⟧_exec`, the proof obligations of `⟦·⟧_proof` evaluated over `τ` must hold, and every runtime `violated`/`assert-failed` event must correspond to a falsified obligation. Exec and proof are two views of clause-level meaning, not two meanings. v1 establishes this by DIFFERENTIAL TESTING (replay traces through the obligation evaluator); a proved theorem is future work. [SEM-8-01]

8.2 Obligation artifact: a deterministic, versioned JSON document per skill: obligation id, source span, scope, kind (unreachability | invariant | coverage | statistical-monitor), the kernel condition in canonical IR form, and its canonical English (8.3). Stable across builds when the source is unchanged. [SEM-8-02]

8.3 Verbalization law: there exists a total function `V : IR -> canonical English` over the deterministic kernel such that `parse(V(ir)) = ir` (round trip at IR equality, not string equality). Canonical English is defined by a one-form-per-construct table: synonyms parse, exactly one form prints. Judgment blocks verbalize as their verbatim prose plus their typed contract. `V` undefined on any kernel construct is a build failure, which makes totality of `V` a permanent regression gate. [SEM-8-03]

8.4 Audit consequence (informative): given 8.3 and clause 4, every claim the system makes about itself is checkable by a human in English and by a machine against traces. This conjunction, executable + formally projectable + trace-grounded + round-trip verbalizable, is the precise content of the claim of exceeding Inform 7 (no formal projection, no published semantics) and ACE (no execution, no trace model).

---

## 9. Conformance, versioning, open items

9.1 Conformance: every clause tagged `[SEM-x-y]` requires at least one automated test asserting exactly that clause, named with the tag. The conformance suite is the executable form of this document; divergence between suite and document is a bug in one of them and blocks release.

9.2 Versioning: this document is versioned with the language. A semantic change (any change to a `[SEM-...]` clause's meaning) is a major version event and requires a migration note in the changelog, even when no surface syntax changes.

9.3 Acknowledged open items (deferred, logged, not blocking v1): formal commit/recover semantics; future-looking temporal operators in proof mode; confidence intervals (6.5); cross-skill trace scopes (4.3); clock skew model (4.5); a machine-checked coherence theorem (8.1).

## 10. Decision register

- D0 (2.7): description order is source order, meaningful and preserved. CONFIRMED (maintainer 2026-07-11)
- D1 (4.6): closed-world over retention; window > retention is a compile error. CONFIRMED (maintainer 2026-07-11)
- D2 (6.3): statistical indeterminacy is first-class and totality-checked. CONFIRMED (maintainer 2026-07-11)
- D3 (7.3): prohibitions attempt-time, obligations effect-time, prevented violations witnessed. CONFIRMED (maintainer 2026-07-11)
- D4 (4.3): no cross-skill scopes in v1. CONFIRMED (maintainer 2026-07-11)
- D7 (5.5): `since the last E` with no anchor is indeterminate, not vacuously true. CONFIRMED (maintainer 2026-07-11)
- D7a (5.5): a blocking obligation or blocking assert over possibly-indeterminate `since` requires an explicit unknown/default policy arm at compile time. CONFIRMED (maintainer 2026-07-11)
- D8 (4.7): fail-closed when the skill has a blocking `AssertIR` or blocking monitor; otherwise fail-open with degraded-witnessing recovery marker (`failed` tag, subject `trace-store`). CONFIRMED (maintainer 2026-07-11)
- D9 (4.8): per-tool capture policy is `full | hash-only | redacted(fields)`; production requires an explicit policy per tool; content hash is always mandatory. CONFIRMED (maintainer 2026-07-11)
- D10 (4.9): temporal history binds to skill NAME plus stable STEP PATH; `versionHash` is audit metadata only. CONFIRMED (maintainer 2026-07-11)
- D11: `unless` canonical-print policy. DEFERRED to later waves.
- D12: witness payload contents under hash-only capture. DEFERRED to later waves.

Note: `[OBL-*]` annotations are ON by default for Wave 9 `meridian explain` output.
