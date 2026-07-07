# ETL Resolver

Routes a data-pipeline operator request to the synthetic ETL skill that owns it.

## Dispatch table

| trigger phrase | skill |
| --- | --- |
| run extract load | extractload |
| run incremental sync | incrementalsync |
| check schema evolution | schemaevolution |
| backfill dataset partitions | backfillpartitions |
| dedupe datasets | dedupeupsert |
| run quality gate | qualitygate |
| orchestrate pipeline dag | dagorchestrate |
| triage failed pipelines | pipelinetriage |

## Workflow

Look up the skill corresponding to the trigger phrase and emit the selected
skill id.
