# Wave 8 Requirements Matrix

This table is the rollout checklist for Wave 8 traces, time, statistics, and
their documentation/test artifacts.

Status legend:

- `done` — implemented and covered by a named, passing test/artifact (linked in
  the "Expected test/artifact" column). Some `done` rows carry a residual note
  where a *sub-clause* of the requirement is intentionally scoped out; the
  load-bearing behavior is tested.
- `deferred` — the load-bearing half is tested (linked), but a named sub-clause
  is deliberately out of Wave 8 because it is blocked on an open decision or is
  post-Wave-8 surface. Each deferral names its residual and the wave/decision it
  waits on. See `WAVE8_COMPLETION_EVIDENCE.md` for the consolidated residual list.

Final counts (this matrix): **55 done, 0 pending, 0 deferred**.

| ID | Source | Requirement | Owner phase | Expected test/artifact | Status |
| --- | --- | --- | --- | --- | --- |
| SEM-2-08 | `docs/cookbook/MERIDIAN_SEMANTICS.md` 2.7 | Description order is meaningful source order unless an explicit sort is present. | W8C | `SEM_2_08 the first N preserves source order when no explicit sort is present` | done |
| SEM-2-09 | `docs/cookbook/MERIDIAN_SEMANTICS.md` 2.8 | Quantifier empty-domain behavior is stable and documented. | W8C | `all <description> is vacuously TRUE over an empty domain` + sibling empty-domain quantifier cases | done |
| SEM-2-10 | `docs/cookbook/MERIDIAN_SEMANTICS.md` 2.4.1 | K3 nine-cell truth table is implemented exactly. | W8C | `SEM-2-10 K3 truth table` | done |
| SEM-2-11 | `docs/cookbook/MERIDIAN_SEMANTICS.md` 2.4.1 | Decision-point totality is enforced only at the specified sites. | W8C | `SEM_2_11 decision-point totality is not enforced on monitored statistical assertions` + `SEM_6_02 statistical branch without fallback reports MER-STA-001` | done |
| SEM-2-12 | `docs/cookbook/MERIDIAN_SEMANTICS.md` 2.3.1 | Durations are physical time only; date formatting uses one deployment zone. | W8C | `SEM_2_12 trace durations stay physical and deployment zones stay explicit` | done |
| SEM-4-01 | `docs/cookbook/MERIDIAN_SEMANTICS.md` 4.1 | Trace records are append-only within retention. | W8A | `SEM-4-01 append-only within retention and retention compaction drops expired only` | done |
| SEM-4-02 | `docs/cookbook/MERIDIAN_SEMANTICS.md` 4.2 | Event ordering is deterministic within-run and across runs. | W8A | `SEM-4-02 ordering uses run order locally and at-ingest-id globally` | done |
| SEM-4-03 | `docs/cookbook/MERIDIAN_SEMANTICS.md` 4.3 | `Across all runs` scopes by skill name + stable step path continuity only. | W8C | `SEM_4_03 across-all-runs uses skill scope and global ordering` (+ `SEM_4_09 across-all-runs ignores version hash when skill identity is stable`) | done |
| SEM-4-04 | `docs/cookbook/MERIDIAN_SEMANTICS.md` 4.4 | Judgment boundaries emit `judged` with hashes, kind, and tool scope. | W8B | `SEM_4_04 judgment boundary maps to a judged record carrying a payload hash, kind, and tool scope` (+ `all legacy EventKind cases round-trip through semantic trace projection`) | done |
| SEM-4-05 | `docs/cookbook/MERIDIAN_SEMANTICS.md` 4.5 | Runtime time source is monotone within a run; ingest order is fallback ordering witness. | W8A | `SEM-4-05 ingest fallback assigns monotone ingest order` | done |
| SEM-4-06 | `docs/cookbook/MERIDIAN_SEMANTICS.md` 4.6 | Window greater than retention is a compile-time error naming both durations. | W8C | `NS-C-02 / SEM-4-06 window greater than retention reports MER-TMP-011 naming both durations` | done |
| SEM-4-07 | `docs/cookbook/MERIDIAN_SEMANTICS.md` 4.7 | Trace append failure honors D8 fail-closed / fail-open behavior. | W8A | `SEM-4-07 fail-open emits a degraded-witnessing marker after recovery` + `SEM-4-07 fail-closed rethrows append failures on strict emits` | done |
| SEM-4-08 | `docs/cookbook/MERIDIAN_SEMANTICS.md` 4.8 | Per-tool capture policy supports `full`, `hash-only`, and `redacted(fields)` with mandatory content hash. | W8A | `trace section and tool capture policies parse` + `production trace capture succeeds when every tool is explicit` + `governance access review freshness compiles production trace capture policy` + `clinical handoff reliability monitor compiles privacy-safe tool scope` | done |
| SEM-4-09 | `docs/cookbook/MERIDIAN_SEMANTICS.md` 4.9 | History continuity is keyed by skill name + stable step path, not version hash. | W8B | `SEM_4_09 across-all-runs ignores version hash when skill identity is stable` + `stable step paths survive unrelated edits` | done |
| SEM-5-01 | `docs/cookbook/MERIDIAN_SEMANTICS.md` 5 preamble | v1 temporal support is pure-past only; future-looking forms remain deferred. | W8C | `SEM_5_01 pure-past evaluation ignores future events` | done |
| SEM-5-02 | `docs/cookbook/MERIDIAN_SEMANTICS.md` 5.1 | `has ever occurred` queries retained history only. | W8C | `SEM_5_02 ever matches retained scoped history` | done |
| SEM-5-03 | `docs/cookbook/MERIDIAN_SEMANTICS.md` 5.2 | Metric window uses closed bounds `t-D <= at <= t`. | W8C | `SEM_5_03 withinWindow uses inclusive old end` | done |
| SEM-5-04 | `docs/cookbook/MERIDIAN_SEMANTICS.md` 5.3 | Count-in-window supports at least / at most / exactly semantics. | W8C | `SEM_5_04 countInWindow compares at least at most exactly` | done |
| SEM-5-05 | `docs/cookbook/MERIDIAN_SEMANTICS.md` 5.4 | In-a-row uses the qualifying subsequence rule and ignores prevented invokes. | W8C | `SEM_5_05 inARow uses qualifying subsequence and prevented invoke does not qualify` + `RISK-W8-01 north-star contrast covers both orderings plus prevented invoke` | done |
| SEM-5-06 | `docs/cookbook/MERIDIAN_SEMANTICS.md` 5.5 | `since the last` is indeterminate without an anchor and checks strictly after the anchor. | W8C | `SEM_5_06 sinceLast is strict after anchor and indeterminate without anchor` | done |
| SEM-5-07 | `docs/cookbook/MERIDIAN_SEMANTICS.md` 5.6 | Temporal operators compose inside definitions and yield temporal adjectives. | W8C | `SEM_5_07 temporal operators compose inside definitions and yield temporal adjectives` + `SEM_5_09 keyed temporal definition threads subject key into lowered IR` + `since-the-last with an event-backed adjective holds lowers to a runtime-evaluable pattern` | done |
| SEM-5-08 | `docs/cookbook/MERIDIAN_SEMANTICS.md` 5.7 | Replay over fixed `(Gamma, sigma, tau, t)` is deterministic. | W8E | `SEM_5_08 fixed context yields deterministic result` + `SEM_5_08 replay semantics depend only on explicit evaluation instant` + `SEM_5_08 in-memory and JSONL replay results agree across operator families` + `SEM_5_08 replay result encoding is byte-identical` | done |
| SEM-5-09 | `docs/cookbook/MERIDIAN_SEMANTICS.md` 2.1.1 | Temporal/statistical definitions on keyed kinds implicitly restrict by instance key. | W8C | `SEM_5_09 keyed temporal definition threads subject key into lowered IR` + `SEM_5_09 keyed statistical definition threads subject key into lowered IR` | done |
| SEM-5-10 | `docs/cookbook/MERIDIAN_SEMANTICS.md` 2.1.1 | Temporal/statistical definitions on unkeyed kinds are ill-formed. | W8C | `SEM_5_10 temporal definition on unkeyed kind reports MER-TMP-016` | done |
| SEM-5-11 | `docs/cookbook/MERIDIAN_SEMANTICS.md` 5 preamble | Simultaneous interleavings are semantically ordered and linted for in-a-row surprise. | W8B | `SEM-4-02 ordering uses run order locally and at-ingest-id globally` + `RISK-W8-01 north-star contrast covers both orderings plus prevented invoke` + `SEM_5_11 across-all-runs in-a-row warns about interleaved ordering` + near-miss siblings `SEM_5_11 current-run in-a-row does not warn` / `SEM_5_11 count-in-window does not warn` | done |
| SEM-6-01 | `docs/cookbook/MERIDIAN_SEMANTICS.md` 6.2 | `usually` / `rarely` map to configured numeric thresholds and verbalize numerically. | W8D | `SEM_6_01 usually and rarely verbalize numerically` | done |
| SEM-6-02 | `docs/cookbook/MERIDIAN_SEMANTICS.md` 6.3 | Sample-floor indeterminacy and decision-point totality work together. | W8D | `SEM_6_02 TraceStatistical sample floor yields indeterminate` + `SEM_6_02 statistical branch without fallback reports MER-STA-001` | done |
| SEM-6-03 | `docs/cookbook/MERIDIAN_SEMANTICS.md` 6.4 | Contract statistical claims lower to monitored assertions with indeterminate outcomes allowed. | W8D | `SEM_6_03 contract statistical claims lower to monitored assertions with indeterminate outcomes allowed` + `etl pipeline reliability watch compiles monitor cadence and denominator contrast` + `erp payment failure monitor compiles default-cadence monitor and streak hook` | done |
| SEM-6-04 | `docs/cookbook/MERIDIAN_SEMANTICS.md` 6.5 | `with 95% confidence` is reserved and rejected. | W8D | `SEM_6_04 with 95% confidence is reserved and rejected` | done |
| SEM-6-05 | `docs/cookbook/MERIDIAN_SEMANTICS.md` 6.6 | Possibly-indeterminate analysis is syntactic and conservative only. | W8D | `SEM_6_05 syntactic analysis is conservative and transitive only` | done |
| COOK-04 | `docs/cookbook/MERIDIAN_SYNTAX_COOKBOOK.md` 4 | K3 boolean composition examples stay canonical and testable. | W8C | `COOK-04 boolean canonical form round trips` | done |
| COOK-13 | `docs/cookbook/MERIDIAN_SYNTAX_COOKBOOK.md` 13 | Branching forms include explicit unknown-arm behavior. | W8C | `COOK-13 branch canonical form round trips` + `COOK-13 unknown-arm canonical form round trips` | done |
| COOK-14 | `docs/cookbook/MERIDIAN_SYNTAX_COOKBOOK.md` 14 | Compound note form is canonical only for declared text bindings. | W8B | `COOK-14 compound note canonical form round trips` + `COOK-14 compound note desugars to a rebind that appends text (no new IR primitive)` + `COOK-14 compound note into an undeclared binding reports MER-REF-004` + `COOK-14 compound note into a non-text binding reports MER-TYP-001` | done |
| COOK-18 | `docs/cookbook/MERIDIAN_SYNTAX_COOKBOOK.md` 18 | Temporal operator surface and edge cases are pinned. | W8C | `COOK-18 ever canonical form round trips` + `COOK-18 within-window canonical form round trips` + `COOK-18 count-in-window canonical form round trips` + `COOK-18 in-a-row canonical form round trips` + `COOK-18 since-the-last canonical form round trips` | done |
| COOK-19 | `docs/cookbook/MERIDIAN_SYNTAX_COOKBOOK.md` 19 | Temporal adjectives require keying and restrict by subject key. | W8C | `COOK-19 keyed temporal adjective canonical form round trips` | done |
| COOK-20 | `docs/cookbook/MERIDIAN_SYNTAX_COOKBOOK.md` 20 | Ill-formed temporal sentences map to the published `MER-TMP-*` codes. | W8C | `COOK-20 progressive aspect reports MER-TMP-018` + BrokenTwin diagnostics suite (`NS-C-01`/`03`/`04`/`05` = MER-TMP-010/012/017/013 with message substrings, `SEM_5_10` = MER-TMP-016, `MER-TMP-019 …`) | done |
| COOK-STAT | `docs/cookbook/MERIDIAN_SYNTAX_COOKBOOK.md` Part V | Statistical surface, cadence, and reserved confidence wording are pinned. | W8D | `COOK-STAT statistical canonical form round trips` + `SEM_6_01 usually and rarely verbalize numerically` | done |
| NS-A6 | `docs/cookbook/MERIDIAN_NORTHSTAR_EXAMPLE.md` A.6 | North-star trace walkthrough remains executable as a semantic contrast harness. | W8E | `RISK-W8-01 north-star contrast covers both orderings plus prevented invoke` + `incident release health sentinel compiles temporal contrast hooks` + `Tests/MeridianCoreTests/Fixtures/Trace/release-sentinel-wave8.meri` | done |
| NS-A6-ROW | `docs/cookbook/MERIDIAN_NORTHSTAR_EXAMPLE.md` A.6 | In-a-row contrast uses both orderings and distinguishes count-in-window from streaks. | W8C | `SEM_5_05 inARow uses qualifying subsequence and prevented invoke does not qualify` + `RISK-W8-01 north-star contrast covers both orderings plus prevented invoke` | done |
| NS-B-COMPOUND | `docs/cookbook/MERIDIAN_NORTHSTAR_EXAMPLE.md` B.1/B.3 | `proceed, and note ...` has a real surface/lowering path, not hand-waving. | W8B | `COOK-14 compound note desugars to a rebind that appends text (no new IR primitive)` + `COOK-14 compound note canonical form round trips` + `procedures ledger parity watch compiles statistical parity receipt flow` | done |
| NS-C-01 | `docs/cookbook/MERIDIAN_NORTHSTAR_EXAMPLE.md` C.1 | Bare perfect triggers `MER-TMP-010`. | W8C | `NS-C-01 Broken Twin line 1 reports MER-TMP-010` | done |
| NS-C-02 | `docs/cookbook/MERIDIAN_NORTHSTAR_EXAMPLE.md` C.2 | Window greater than retention triggers `MER-TMP-011`. | W8C | `NS-C-02 / SEM-4-06 window greater than retention reports MER-TMP-011 naming both durations` | done |
| NS-C-03 | `docs/cookbook/MERIDIAN_NORTHSTAR_EXAMPLE.md` C.3 | Causal `since` triggers `MER-TMP-012`. | W8C | `NS-C-03 Broken Twin line 3 reports MER-TMP-012` | done |
| NS-C-04 | `docs/cookbook/MERIDIAN_NORTHSTAR_EXAMPLE.md` C.4 | Vague `recently` plus unkeyed temporal definition ordering is pinned. | W8C | `NS-C-04 Broken Twin line 4 reports MER-TMP-017 for a vague recently window` | done |
| NS-C-05 | `docs/cookbook/MERIDIAN_NORTHSTAR_EXAMPLE.md` C.5 | Future tense triggers `MER-TMP-013`. | W8C | `NS-C-05 Broken Twin line 5 reports MER-TMP-013` | done |
| GAP-TMP-14-15 | Wave 8 gap closure | `MER-TMP-014`/`MER-TMP-015` (unknown trace step / unknown trace payload field) have real, sound emitters — a near-miss check against the subject's declared tool vocabulary, not an instrumentation registry. | W8C | `MER-TMP-014 a step name that closely misspells a declared tool prefix is rejected` + `a novel, self-consistent step noun with no near-miss compiles (MER-TMP-014 never fires on undeclared vocabulary)` + `MER-TMP-015 a whose payload field not declared on the subject's tool is rejected` + `a declared payload field on the subject's tool compiles cleanly` | done |
| NS-C-06 | `docs/cookbook/MERIDIAN_NORTHSTAR_EXAMPLE.md` C.6 | True-arm-only possibly-indeterminate branch triggers `MER-STA-001`. | W8D | `NS-C-06 Broken Twin line 6 reports MER-STA-001 for a true-arm-only branch` | done |
| NS-C-07 | `docs/cookbook/MERIDIAN_NORTHSTAR_EXAMPLE.md` C.7 | Blocking anchorless `since` without unknown/default policy triggers the D7a `MER-STA-001` variant. | W8D | `NS-C-07 Broken Twin line 7 reports MER-STA-001 for a blocking assert with no default policy` + `NS-C-07 near miss branch with otherwise remains accepted` | done |
| RISK-W8-01 | `docs/cookbook/MERIDIAN_DESIGN_RISKS_AND_REVIEW.md` 7 | `SEM-5-05` contrast tests cover both orderings, interleavings, and prevented invokes. | W8C | `RISK-W8-01 north-star contrast covers both orderings plus prevented invoke` | done |
| RISK-W8-02 | `docs/cookbook/MERIDIAN_DESIGN_RISKS_AND_REVIEW.md` 7 | `MER-TMP-010` through `MER-TMP-018` have message-snapshot coverage. | W8C | BrokenTwin diagnostics suite (010/011/012/013/016/017/019 with message substrings) + `COOK-20 progressive aspect reports MER-TMP-018` (message substring) | done |
| RISK-W8-03 | `docs/cookbook/MERIDIAN_DESIGN_RISKS_AND_REVIEW.md` 7 | Window-vs-retention, keying, and K3 tests pass at language and codegen levels. | W8C | `NS-C-02 / SEM-4-06 …` (window/retention) + `SEM_5_09 keyed temporal definition …` (keying) + `SEM-2-10 K3 truth table` (language) + `incident release health sentinel compiles temporal contrast hooks` (codegen) | done |
| RISK-W8-04 | `docs/cookbook/MERIDIAN_DESIGN_RISKS_AND_REVIEW.md` 7 | Broken Twin line 6 and line 7 enforce totality exactly as the oracle says. | W8D | `NS-C-06 Broken Twin line 6 reports MER-STA-001 for a true-arm-only branch` + `NS-C-07 Broken Twin line 7 reports MER-STA-001 for a blocking assert with no default policy` + `NS-C-07 near miss branch with otherwise remains accepted` | done |
| RISK-W8-05 | `docs/cookbook/MERIDIAN_DESIGN_RISKS_AND_REVIEW.md` 7 | Step-path stability, crash consistency, and store differential tests are green. | W8A/W8B | `RISK-W8-05 in-memory and JSONL stores stay behaviorally aligned` + `stable step paths survive unrelated edits` | done |
| RISK-W8-06 | `docs/cookbook/MERIDIAN_DESIGN_RISKS_AND_REVIEW.md` 7 | Bench-trace and replay-determinism evidence is logged. | W8E | Bench output + implementation log entry | done |
| RISK-W8-07 | `docs/cookbook/MERIDIAN_DESIGN_RISKS_AND_REVIEW.md` 7 | Capture policy is implemented and production requires explicit per-tool policy. | W8A | `RISK-W8-07 production trace capture requires every tool to declare capture` + `production trace capture succeeds when every tool is explicit` + `development trace capture still allows omitted tool capture` + `merged production trace capture checks tools declared in another merconfig` | done |

## Deferrals and residuals

No rows are still `deferred`, and no Wave 8 requirement remains open.

**SEM-4-04** now records both the tool-scope summary (`tool_count`) and
explicit scoped-tool-id list (`scoped_tools`) in judged payloads.

**Gap closure (2026-07-11):** `MER-TMP-014`/`MER-TMP-015` were previously
tracked as reserved, non-v1 diagnostic identifiers with "no surface that can
soundly emit them." That framing is now stale — both have real emitters: a
temporal adjective's event-pattern subject/payload resolution (inside
`lowerRegisteredDefinitions()`) runs a near-miss check against the subject's
declared tool vocabulary (step names) and that tool's declared parameter
names (payload fields), and reports `MER-TMP-014`/`MER-TMP-015` with a
"declared step names in scope" / field-name suggestion when a step or `whose`
field doesn't match but is *close* to a declared name. A step/field with no
near-miss at all still compiles (open-world instrumentation, not a closed
registry) — see `GAP-TMP-14-15` above. This gap closure also closed several
other cross-cutting holes discovered during a Wave 8 audit: a
perfect-auxiliary event-pattern subject mis-parse, event negation
(`no <event pattern>`), skill/kind-scoped step and payload-predicate subjects,
branched/iterated/recovered runtime instrumentation events, `.auto` store
failure-policy resolution at compile time, the Composition Gallery
cross-cutting acceptance suite (parse + verbalize round-trip + runtime eval
for gallery lines 1/2/3/7/8 and the north-star flagship), `TraceStoreCapabilities.payloadRetention`,
`meridian trace drift` CLI documentation, and the `MER-STA-003` vague-frequency
diagnostic plus `usually`/`rarely` default/configurable-threshold surface
tests. None of these introduced new requirement IDs beyond `GAP-TMP-14-15`
above — they are test/implementation depth added under existing SEM/COOK/NS/
RISK rows, logged in `IMPLEMENTATION_LOG.md`.
