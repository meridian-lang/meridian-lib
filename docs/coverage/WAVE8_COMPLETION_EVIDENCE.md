# Wave 8 Completion Evidence

This document is the row-by-row closeout companion to
`docs/coverage/WAVE8_REQUIREMENTS.md`. Every Wave 8 oracle item is mapped to a
named test, committed artifact, CLI command, or an explicit residual/deferred
note.

Counts match the requirements matrix:

- `55` done
- `0` pending
- `0` deferred

Oracle sources:

- `docs/cookbook/MERIDIAN_SEMANTICS.md`
- `docs/cookbook/MERIDIAN_SYNTAX_COOKBOOK.md`
- `docs/cookbook/MERIDIAN_NORTHSTAR_EXAMPLE.md`
- `docs/cookbook/MERIDIAN_DESIGN_RISKS_AND_REVIEW.md`

## 1. Shared evidence surfaces

| Surface | What it discharges |
| --- | --- |
| `Tests/MeridianRuntimeTests/Trace/TraceStoreTests.swift` | trace schema/store, retention, ordering, D8 fail-open/fail-closed, chain integrity |
| `Tests/MeridianRuntimeTests/Trace/TraceEvaluatorTests.swift` | temporal/statistical runtime semantics, K3-adjacent truth behavior, keying, scope |
| `Tests/MeridianRuntimeTests/Trace/TraceReplayTests.swift` | replay determinism and store-differential replay |
| `Tests/MeridianCoreTests/Inform7/TraceTemporalInform7Tests.swift` | parser/lowering diagnostics, keyed/unkeyed definitions, `since the last`, totality |
| `Tests/MeridianCoreTests/Inform7/CompoundNoteTests.swift` | compound-note lowering and diagnostics |
| `Tests/MeridianCoreTests/Inform7/VerbalizerCookbookTests.swift` | canonical surface round-trip for COOK forms |
| `Tests/MeridianCoreTests/MerConfigParserTests.swift` | trace-section parsing, capture policy parsing, physical duration/deployment zone |
| `Tests/MeridianCoreTests/TraceEnabledCompileTests.swift` | stable step paths and skill fingerprint stability |
| `Tests/CorporaTests/Wave8CorpusTraceE2ETests.swift` | emitted Swift for corpora carrying Wave 8 surfaces |
| `Tests/MeridianCLITests/TraceReplayCommandTests.swift` | `trace eval`, `trace-eval`, and `bench-trace` CLI stability |
| `docs/coverage/bench-trace-wave8.json` | committed benchmark evidence |
| `docs/19_TRACES_AND_TIME.md` | tested-behavior operational write-up |
| `docs/coverage/WAVE8_CORPUS_MATRIX.md` | corpus-to-surface mapping |
| `IMPLEMENTATION_LOG.md` 2026-07-11 Wave 8 entries | implementation/benchmark closeout and residual logging |

## 2. Full mapping

| ID | Requirement | Evidence | Kind | Status | Residual / note |
| --- | --- | --- | --- | --- | --- |
| `SEM-2-08` | Description order is meaningful source order unless explicitly sorted. | `SEM_2_08 the first N preserves source order when no explicit sort is present` | test | done | — |
| `SEM-2-09` | Quantifier empty-domain behavior is stable and documented. | `all <description> is vacuously TRUE over an empty domain` + sibling empty-domain quantifier cases | test | done | — |
| `SEM-2-10` | K3 nine-cell truth table is implemented exactly. | `SEM-2-10 K3 truth table` | test | done | — |
| `SEM-2-11` | Decision-point totality is enforced only at the specified sites. | `SEM_2_11 decision-point totality is not enforced on monitored statistical assertions` + `SEM_6_02 statistical branch without fallback reports MER-STA-001` + `NS-C-07 Broken Twin line 7 reports MER-STA-001 for a blocking assert with no default policy` | test | done | Non-blocking monitored statistical assertions still compile; blocking assert sites now require an explicit default policy when `since the last` may be indeterminate. |
| `SEM-2-12` | Durations are physical time only; deployment zone stays explicit. | `SEM_2_12 trace durations stay physical and deployment zones stay explicit` | test | done | — |
| `SEM-4-01` | Trace records are append-only within retention. | `SEM-4-01 append-only within retention and retention compaction drops expired only` | test | done | — |
| `SEM-4-02` | Event ordering is deterministic within-run and across runs. | `SEM-4-02 ordering uses run order locally and at-ingest-id globally` | test | done | — |
| `SEM-4-03` | `Across all runs` scopes by skill name + stable step path continuity only. | `SEM_4_03 across-all-runs uses skill scope and global ordering` + `SEM_4_09 across-all-runs ignores version hash when skill identity is stable` | test | done | Step-path continuity is pinned separately by `stable step paths survive unrelated edits`. |
| `SEM-4-04` | Judgment boundaries emit `judged` with hashes, kind, and tool scope. | `SEM_4_04 judgment boundary maps to a judged record carrying a payload hash, kind, and tool scope` + `executeProsePlan routes proposed actions through registered tools` + `all legacy EventKind cases round-trip through semantic trace projection` | test | done | Judged payloads now carry both `tool_count` and the explicit `scoped_tools` ids. |
| `SEM-4-05` | Runtime time source is monotone within a run; ingest order is the fallback ordering witness. | `SEM-4-05 ingest fallback assigns monotone ingest order` | test | done | — |
| `SEM-4-06` | Window greater than retention is a compile-time error naming both durations. | `NS-C-02 / SEM-4-06 window greater than retention reports MER-TMP-011 naming both durations` | test | done | — |
| `SEM-4-07` | Trace append failure honors D8 fail-closed / fail-open behavior. | `SEM-4-07 fail-open emits a degraded-witnessing marker after recovery` + `SEM-4-07 fail-closed rethrows append failures on strict emits` | test | done | — |
| `SEM-4-08` | Per-tool capture policy supports `full`, `hash-only`, and `redacted(fields)` with mandatory content hash. | `trace section and tool capture policies parse` + `production trace capture succeeds when every tool is explicit` + `governance access review freshness compiles production trace capture policy` + `clinical handoff reliability monitor compiles privacy-safe tool scope` | test/codegen | done | Production-explicit enforcement is now covered separately by `RISK-W8-07`. |
| `SEM-4-09` | History continuity is keyed by skill name + stable step path, not version hash. | `SEM_4_09 across-all-runs ignores version hash when skill identity is stable` + `stable step paths survive unrelated edits` | test | done | — |
| `SEM-5-01` | v1 temporal support is pure-past only. | `SEM_5_01 pure-past evaluation ignores future events` | test | done | Future-looking surface remains rejected via `MER-TMP-013`. |
| `SEM-5-02` | `has ever occurred` queries retained history only. | `SEM_5_02 ever matches retained scoped history` | test | done | — |
| `SEM-5-03` | Metric window uses closed bounds `t-D <= at <= t`. | `SEM_5_03 withinWindow uses inclusive old end` | test | done | — |
| `SEM-5-04` | Count-in-window supports at least / at most / exactly semantics. | `SEM_5_04 countInWindow compares at least at most exactly` | test | done | — |
| `SEM-5-05` | In-a-row uses qualifying subsequence and ignores prevented invokes. | `SEM_5_05 inARow uses qualifying subsequence and prevented invoke does not qualify` + `RISK-W8-01 north-star contrast covers both orderings plus prevented invoke` | test | done | — |
| `SEM-5-06` | `since the last` is indeterminate without an anchor and checks strictly after the anchor. | `SEM_5_06 sinceLast is strict after anchor and indeterminate without anchor` | test | done | Pure state-predicate holds remain unsupported and are rejected with `MER-TMP-019`. |
| `SEM-5-07` | Temporal operators compose inside definitions and yield temporal adjectives. | `SEM_5_09 keyed temporal definition threads subject key into lowered IR` + `since-the-last with an event-backed adjective holds lowers to a runtime-evaluable pattern` + `SEM_5_07 fixed context yields deterministic result` | test | done | — |
| `SEM-5-08` | Replay over fixed `(Gamma, sigma, tau, t)` is deterministic. | `SEM_5_08 replay semantics depend only on explicit evaluation instant` + `SEM_5_08 in-memory and JSONL replay results agree across operator families` + `SEM_5_08 replay result encoding is byte-identical` | test | done | CLI replay surface is pinned separately by `trace eval` tests. |
| `SEM-5-09` | Temporal/statistical definitions on keyed kinds implicitly restrict by instance key. | `SEM_5_09 keyed temporal definition threads subject key into lowered IR` + `SEM_5_09 keyed statistical definition threads subject key into lowered IR` | test | done | Runtime key restriction itself is pinned by `SEM_5_09 subject key restricts temporal matching`. |
| `SEM-5-10` | Temporal/statistical definitions on unkeyed kinds are ill-formed. | `SEM_5_10 temporal definition on unkeyed kind reports MER-TMP-016` | test | done | — |
| `SEM-5-11` | Simultaneous interleavings are semantically ordered and linted for in-a-row surprise. | `SEM-4-02 ordering uses run order locally and at-ingest-id globally` + `RISK-W8-01 north-star contrast covers both orderings plus prevented invoke` + `SEM_5_11 across-all-runs in-a-row warns about interleaved ordering` + near-miss siblings `SEM_5_11 current-run in-a-row does not warn` / `SEM_5_11 count-in-window does not warn` | test | done | Advisory lint now covers the cross-run `in a row` surprise case without changing runtime ordering semantics. |
| `SEM-6-01` | `usually` / `rarely` map to configured numeric thresholds and verbalize numerically. | `SEM_6_01 usually and rarely verbalize numerically` | test | done | — |
| `SEM-6-02` | Sample-floor indeterminacy and decision-point totality work together. | `SEM_6_02 TraceStatistical sample floor yields indeterminate` + `SEM_6_02 statistical branch without fallback reports MER-STA-001` | test | done | Non-blocking monitored statistical assertions remain allowed to carry indeterminate outcomes. |
| `SEM-6-03` | Contract statistical claims lower to monitored assertions with indeterminate outcomes allowed. | `etl pipeline reliability watch compiles monitor cadence and denominator contrast` + `erp payment failure monitor compiles default-cadence monitor and streak hook` | codegen test | done | — |
| `SEM-6-04` | `with 95% confidence` is reserved and rejected. | `SEM_6_04 with 95% confidence is reserved and rejected` | test | done | — |
| `SEM-6-05` | Possibly-indeterminate analysis is syntactic and conservative only. | `SEM_6_05 syntactic analysis is conservative and transitive only` | test | done | — |
| `COOK-04` | K3 boolean composition examples stay canonical and testable. | `COOK-04 boolean canonical form round trips` | test | done | — |
| `COOK-13` | Branching forms include explicit unknown-arm behavior. | `COOK-13 branch canonical form round trips` + `COOK-13 unknown-arm canonical form round trips` | test | done | — |
| `COOK-14` | Compound note form is canonical only for declared text bindings. | `COOK-14 compound note canonical form round trips` + `COOK-14 compound note desugars to a rebind that appends text (no new IR primitive)` + `COOK-14 compound note into an undeclared binding reports MER-REF-004` + `COOK-14 compound note into a non-text binding reports MER-TYP-001` | test | done | — |
| `COOK-18` | Temporal operator surface and edge cases are pinned. | `COOK-18 ever canonical form round trips` + `COOK-18 within-window canonical form round trips` + `COOK-18 count-in-window canonical form round trips` + `COOK-18 in-a-row canonical form round trips` + `COOK-18 since-the-last canonical form round trips` | test | done | — |
| `COOK-19` | Temporal adjectives require keying and restrict by subject key. | `COOK-19 keyed temporal adjective canonical form round trips` | test | done | — |
| `COOK-20` | Ill-formed temporal sentences map to the published `MER-TMP-*` codes. | `COOK-20 progressive aspect reports MER-TMP-018` + BrokenTwin diagnostics suite (`NS-C-01` / `03` / `04` / `05`) + `SEM_5_10` + `MER-TMP-019 ...` | test | done | — |
| `GAP-TMP-14-15` | `MER-TMP-014`/`015` (unknown trace step / payload field) have real near-miss emitters against the subject's declared tool vocabulary. | `MER-TMP-014 a step name that closely misspells a declared tool prefix is rejected` + `a novel, self-consistent step noun with no near-miss compiles (MER-TMP-014 never fires on undeclared vocabulary)` + `MER-TMP-015 a whose payload field not declared on the subject's tool is rejected` + `a declared payload field on the subject's tool compiles cleanly` | test | done | Open-world: an unrecognized step/field with no near-miss to a declared name still compiles — this is a fuzzy-match diagnostic, not a closed instrumentation registry. |
| `COOK-STAT` | Statistical surface, cadence, and reserved confidence wording are pinned. | `COOK-STAT statistical canonical form round trips` + `SEM_6_01 usually and rarely verbalize numerically` | test | done | — |
| `NS-A6` | North-star trace walkthrough remains executable as a semantic contrast harness. | `RISK-W8-01 north-star contrast covers both orderings plus prevented invoke` + `incident release health sentinel compiles temporal contrast hooks` + `Tests/MeridianCoreTests/Fixtures/Trace/release-sentinel-wave8.meri` | test/artifact | done | — |
| `NS-A6-ROW` | In-a-row contrast distinguishes count-in-window from streaks. | `SEM_5_05 inARow uses qualifying subsequence and prevented invoke does not qualify` + `RISK-W8-01 north-star contrast covers both orderings plus prevented invoke` | test | done | — |
| `NS-B-COMPOUND` | `proceed, and note ...` has a real surface/lowering path. | `COOK-14 compound note desugars to a rebind that appends text (no new IR primitive)` + `COOK-14 compound note canonical form round trips` + `procedures ledger parity watch compiles statistical parity receipt flow` | test/codegen | done | — |
| `NS-C-01` | Bare perfect triggers `MER-TMP-010`. | `NS-C-01 Broken Twin line 1 reports MER-TMP-010` | test | done | — |
| `NS-C-02` | Window greater than retention triggers `MER-TMP-011`. | `NS-C-02 / SEM-4-06 window greater than retention reports MER-TMP-011 naming both durations` | test | done | — |
| `NS-C-03` | Causal `since` triggers `MER-TMP-012`. | `NS-C-03 Broken Twin line 3 reports MER-TMP-012` | test | done | — |
| `NS-C-04` | Vague `recently` plus unkeyed-definition ordering is pinned. | `NS-C-04 Broken Twin line 4 reports MER-TMP-017 for a vague recently window` | test | done | — |
| `NS-C-05` | Future tense triggers `MER-TMP-013`. | `NS-C-05 Broken Twin line 5 reports MER-TMP-013` | test | done | — |
| `NS-C-06` | True-arm-only possibly-indeterminate branch triggers `MER-STA-001`. | `NS-C-06 Broken Twin line 6 reports MER-STA-001 for a true-arm-only branch` | test | done | — |
| `NS-C-07` | Blocking anchorless `since` without unknown/default policy triggers the D7a `MER-STA-001` variant. | `NS-C-07 Broken Twin line 7 reports MER-STA-001 for a blocking assert with no default policy` + `NS-C-07 near miss branch with otherwise remains accepted` | test | done | The assert-site guard is limited to blocking/no-default asserts whose lowered condition structurally contains `since the last`; accepted branch behavior is unchanged. |
| `RISK-W8-01` | Contrast tests cover both orderings, interleavings, and prevented invokes. | `RISK-W8-01 north-star contrast covers both orderings plus prevented invoke` | test | done | — |
| `RISK-W8-02` | `MER-TMP-010` through `MER-TMP-018` have message-snapshot coverage. | BrokenTwin diagnostics suite + `COOK-20 progressive aspect reports MER-TMP-018` | test | done | `MER-TMP-014`/`015` now also have direct message-snapshot coverage via `GAP-TMP-14-15`'s tests. |
| `RISK-W8-03` | Window-vs-retention, keying, and K3 tests pass at language and codegen levels. | `NS-C-02 / SEM-4-06 ...` + `SEM_5_09 keyed temporal definition ...` + `SEM-2-10 K3 truth table` + `incident release health sentinel compiles temporal contrast hooks` | test/codegen | done | — |
| `RISK-W8-04` | Broken Twin lines 6 and 7 enforce totality exactly as the oracle says. | `NS-C-06 Broken Twin line 6 reports MER-STA-001 for a true-arm-only branch` + `NS-C-07 Broken Twin line 7 reports MER-STA-001 for a blocking assert with no default policy` + `NS-C-07 near miss branch with otherwise remains accepted` | test | done | Both Broken Twin totality cases are now covered explicitly. |
| `RISK-W8-05` | Step-path stability, crash consistency, and store differential tests are green. | `RISK-W8-05 in-memory and JSONL stores stay behaviorally aligned` + `stable step paths survive unrelated edits` + `torn final JSONL line is quarantined and ignored on reopen` | test | done | — |
| `RISK-W8-06` | Bench-trace and replay-determinism evidence is logged. | `bench-trace JSON schema covers all measurement combinations` + `trace eval JSON schema is stable` + `trace-eval alias is byte-identical across repeated replays` + `docs/coverage/bench-trace-wave8.json` + 2026-07-11 `IMPLEMENTATION_LOG.md` Wave 8E entry | test/artifact/log | done | — |
| `RISK-W8-07` | Capture policy is implemented and production requires explicit per-tool policy. | `RISK-W8-07 production trace capture requires every tool to declare capture` + `production trace capture succeeds when every tool is explicit` + `development trace capture still allows omitted tool capture` + `merged production trace capture checks tools declared in another merconfig` | test | done | — |

## 3. Consolidated residuals

No rows remain deferred, and no Wave 8 requirement remains open.

### Gap-closure pass (2026-07-11)

A post-signoff audit found several cross-cutting holes that no single
SEM/COOK/NS/RISK oracle row named explicitly. All are now closed, with
evidence logged in `IMPLEMENTATION_LOG.md`:

| Gap | Evidence |
| --- | --- |
| `MER-TMP-014`/`015` real emitters (see `GAP-TMP-14-15` above) | `Tests/MeridianCoreTests/Inform7/TraceTemporalInform7Tests.swift` |
| Perfect-auxiliary event-pattern subject mis-parse | `TraceEventPatternGrammar.parseSubject` fix + regression test |
| Temporal surface: `occurred` outcome verb, `ever` aliases, anchor-first `since`, has-been-failing/bare-causal-since rejection | `Tests/MeridianCoreTests/Inform7/TraceTemporalInform7Tests.swift` |
| Event negation (`no <event pattern>`) | `TraceEventPatternGrammar` + tests |
| `whose <field> is <value>` payload predicates (event + statistical) | `TraceEventPatternGrammar` / `TraceStatisticalGrammar` + tests |
| Skill-scoped step and kind-flavored noun subjects | `TraceEventPatternGrammar.parseSubject` + `D4` diagnostic + tests |
| Branched/iterated/recovered runtime instrumentation events | `Runtime`/codegen emission + tests |
| Input/output payload hash + output kind on judged events | `SEM-4-04` judged-event payload additions |
| `.auto` store failure-policy resolved to `failClosed`/`failOpen` at compile time | `D8` auto-policy resolution + tests |
| Composition Gallery acceptance suite (parse + verbalize round-trip for all gallery lines; runtime eval for lines 1/2/3/7/8 + the north-star flagship) | `Tests/MeridianCoreTests/Inform7/CompositionGalleryTests.swift` + `Tests/MeridianSlowIntegrationTests/CompositionGalleryEvalTests.swift` |
| `TraceStoreCapabilities.payloadRetention` flag | `InMemoryTraceStore`/`JSONLTraceStore` + `Tests/MeridianRuntimeTests/Trace/TraceStoreTests.swift` `capabilityFlags()` |
| `meridian trace drift` CLI documentation | `docs/07_CLI.md` |
| `MER-STA-003` vague-frequency diagnostic + `usually`/`rarely` default/configurable-threshold surface | `Tests/MeridianCoreTests/Inform7/TraceTemporalInform7Tests.swift` (`mersta003VagueFrequency`, `usuallyRarelyDefaultThresholds`, `usuallyRarelyConfiguredThresholds`) |
| `proxy-sentences.json` fixture (harvested real-world sentences) validated as a parser negative-control corpus | `Tests/MeridianCoreTests/Fixtures/Trace/proxy-sentences.json` + `Tests/MeridianCoreTests/Inform7/ProxySentencesFixtureTests.swift` |
| Same-trace `runs`-vs-`occurrences` denominator divergence | `Tests/MeridianRuntimeTests/Trace/TraceEvaluatorTests.swift` (`sameTraceRunsVsOccurrencesDivergence`) |
| Runtime monitor indeterminate emission below `sampleFloor` | `Tests/MeridianRuntimeTests/MonitorLifecycleTests.swift` (`emitsIndeterminateBelowSampleFloor`) |
| `meridian trace eval` end-to-end statistical CLI coverage | `Tests/MeridianCLITests/TraceReplayCommandTests.swift` (`statisticalExpressionReplay`) |

None of these introduced a new oracle requirement; they are implementation
depth added under existing SEM/COOK/NS/RISK rows (or, for `MER-TMP-014`/`015`,
the new `GAP-TMP-14-15` tracking row). Full test-run/typecheck/coverage/
strict-compile gate results for this pass are logged in
`IMPLEMENTATION_LOG.md`.
