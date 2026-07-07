# ETL/Data-Pipeline Proxy Corpus

Synthetic validation corpus for data-pipeline/ETL operator runbooks.

This corpus is intentionally authored in a data-engineering voice (sources,
sinks, datasets, schemas, partitions, watermarks, backfills, and data-quality
gates) rather than gbrain's knowledge-management voice or `procedures`'s DBA
transaction/ledger/index/constraint voice. It is a synthetic proxy, not an
independently supplied external corpus. It weights the coverage surface
toward the data-heavy surface (tables, templates, descriptions/aggregates,
cardinality quantifiers, temporal windows, backfill loops) to complement
`incident`'s wait/recover/parallel/judgment weight.

## Layout

- `original-skills/` — source `SKILL.md` files.
- `skills/` — strict migrated `.meri` ports.
- `etl.merconfig` — domain vocabulary, definitions, relations, phrases, tools.
- `etl.merrules` — human-facing syntax (`Stage:`, `Check:`, `Emit:`).
- `RESOLVER.meri` — dispatch-table workflow for trigger phrase routing.
- `compile-outputs/` — generated Swift + manifests from `meridian compile`.
- `migration-deviations/` — reproducible per-skill deviation reports.

## Validation

```bash
swift run meridian migrate-skill corpora/etl/original-skills --batch --out corpora/etl/skills --vocab corpora/etl/etl.merconfig --rulebook corpora/etl/etl.merrules --force
swift run meridian skill-deviation corpora/etl/original-skills corpora/etl --batch --index --out corpora/etl/migration-deviations
MERIDIAN_CORPORA_TYPECHECK=1 swift test --filter CorporaConformanceTests
```
