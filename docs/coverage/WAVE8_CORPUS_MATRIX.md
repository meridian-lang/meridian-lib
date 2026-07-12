# Wave 8 Corpus Matrix

This matrix maps the Wave 8 authoring surfaces exercised by the synthetic
corpora to the hand-authored skills that carry them, and then maps the
supporting infrastructure to the named tests that pin those surfaces.

## Authoring Surfaces

| Surface | Corpus skill(s) |
| --- | --- |
| Temporal `ever` / `within the last` / count-in-window / in-a-row contrast | `corpora/incident/original-skills/release_health_sentinel/SKILL.md` |
| `since the last` with explicit unknown/default handling | `corpora/incident/original-skills/release_health_sentinel/SKILL.md` |
| Run-denominator statistical monitoring | `corpora/etl/original-skills/pipeline_reliability_watch/SKILL.md`, `corpora/erp/original-skills/payment_failure_monitor/SKILL.md`, `corpora/clinical/original-skills/handoff_reliability_monitor/SKILL.md` |
| Occurrence-denominator statistical monitoring | `corpora/etl/original-skills/pipeline_reliability_watch/SKILL.md`, `corpora/procedures/original-skills/ledger_parity_watch/SKILL.md` |
| `usually` / `rarely` statistical sugar in executable Contract items | `corpora/etl/original-skills/pipeline_reliability_watch/SKILL.md` |
| Keyed temporal/statistical definitions on corpus kinds | `corpora/incident/incident.merconfig`, `corpora/procedures/procedures.merconfig`, `corpora/erp/erp.merconfig`, `corpora/governance/governance.merconfig`, `corpora/clinical/clinical.merconfig` |
| Transitive possibly-indeterminate adjective use with explicit unknown arm | `corpora/erp/original-skills/payment_failure_monitor/SKILL.md` |
| K3 default via `otherwise` on a possibly-indeterminate derived predicate | `corpora/procedures/original-skills/ledger_parity_watch/SKILL.md` |
| Blocking assert with explicit fallback policy | `corpora/incident/original-skills/release_health_sentinel/SKILL.md`, `corpora/procedures/original-skills/ledger_parity_watch/SKILL.md` |
| Production trace profile plus explicit per-tool capture policy | `corpora/governance/governance.merconfig`, `corpora/clinical/clinical.merconfig` |
| Hash-only / redacted sensitive trace payload policy | `corpora/governance/governance.merconfig`, `corpora/clinical/clinical.merconfig` |
| Judgment boundary with explicit, narrow tool scope | `corpora/clinical/original-skills/handoff_reliability_monitor/SKILL.md` |

## Closeout Snapshot

Regenerated on `2026-07-11` with the shared `generate-migration`,
`generate-compile-outputs`, and `generate-deviations` scripts for all six Wave 8
corpora. The six new Wave 8 skills all regenerated with `edits=0`, `repairs=0`,
and `unmined=0`.

| Corpus | New Wave 8 skill | Resolver dispatch verified | Expected files | Verified trace / keying / capture evidence | generated_loc total | Residuals to keep honest |
| --- | --- | --- | --- | --- | --- | --- |
| `incident` | `release_health_sentinel` | `check release health -> releasehealthsentinel` | 9 skills + `RESOLVER.meri` (10 total) | `incident.merconfig` has `=== trace ===`; `service` is keyed; skill compiles `ever`, `within the last`, count-in-window, in-a-row, and `since the last` + explicit unknown/default handling | 361 | Resolver migration still reports 1 unmined-contract line; corpus skill migrations and deviation index are otherwise clean |
| `etl` | `pipeline_reliability_watch` | `check pipeline reliability -> pipelinereliabilitywatch` | 9 skills + `RESOLVER.meri` (10 total) | `etl.merconfig` has `=== trace ===` with `usually` / `rarely` thresholds and cadence; `dataset` is keyed; skill compiles run-denominator and occurrence-denominator monitoring | 356 | Resolver migration still reports 1 unmined-contract line; corpus skill migrations and deviation index are otherwise clean |
| `procedures` | `ledger_parity_watch` | `check ledger parity -> ledgerparitywatch` | 13 skills + `RESOLVER.meri` (14 total) | `procedures.merconfig` has `=== trace ===`; `ledger` is keyed; skill compiles occurrence-denominator monitoring, K3 `otherwise`, blocking assert fallback, and compound `note` receipt flow | 284 | Skill migrations/deviations are clean; resolver migration still reports 1 unmined-contract line |
| `erp` | `payment_failure_monitor` | `monitor payment failures -> paymentfailuremonitor` | 13 skills + `RESOLVER.meri` (14 total) | `erp.merconfig` has `=== trace ===`; `invoice` and `payment` are keyed; skill compiles run-denominator monitoring, streak detection, and explicit unknown handling | 285 | Deviation index is clean for operational/unclassified inert; resolver migration still reports 1 unmined-contract line |
| `governance` | `access_review_freshness` | `check access review freshness -> accessreviewfreshness` | 9 skills + `RESOLVER.meri` (10 total) | `governance.merconfig` has `profile: production`, hash-only capture policies, and keyed `resource`; skill compiles retained-boundary freshness checks | 374 | `generated_loc` total rose from 373 to 374 on regeneration; resolver migration still reports 1 unmined-contract line |
| `clinical` | `handoff_reliability_monitor` | `check handoff reliability -> handoffreliabilitymonitor` | 9 skills + `RESOLVER.meri` (10 total) | `clinical.merconfig` has `profile: production`, hash-only / redacted capture policies, and keyed `patient`; skill compiles run-denominator monitoring plus a narrow `patient.list` / `vitals.read` judgment scope | 417 | Resolver migration still reports 1 unmined-contract line; corpus skill migrations and deviation index are otherwise clean |

## Infrastructure Coverage

| Concern | Named test(s) / artifact |
| --- | --- |
| Temporal parser/lowering semantics | `Tests/MeridianCoreTests/Inform7/TraceTemporalInform7Tests.swift` |
| Statistical parser/lowering semantics | `Tests/MeridianCoreTests/Inform7/TraceTemporalInform7Tests.swift` |
| Canonical verbalization of trace surfaces | `Tests/MeridianCoreTests/Inform7/VerbalizerCookbookTests.swift` |
| Runtime evaluation of temporal/statistical traces | `Tests/MeridianRuntimeTests/Trace/TraceEvaluatorTests.swift` |
| Monitor registration / lifecycle | `Tests/MeridianRuntimeTests/MonitorLifecycleTests.swift` |
| Corpus completeness + compile/typecheck gate | `Tests/CorporaTests/CorporaConformanceTests.swift` |
| Wave 8 corpus trace compile hooks | `Tests/CorporaTests/Wave8CorpusTraceE2ETests.swift` |
| Migration deviation index, inert worklist, and generated LOC reporting | `Sources/MeridianCore/Migration/SkillMetrics.swift`, `Sources/MeridianCLIKit/Commands/SkillDeviationCommand.swift`, `scripts/generate-deviations.swift` |
