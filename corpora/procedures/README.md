# Stored-Procedure Proxy Corpus

Synthetic validation corpus for DBA and stored-procedure-style runbooks.

This corpus uses database-administration idioms: SQL snapshots, ledger batches,
stale records, constraints, audit rows, index rebuilds, bounded purges, and
recoverable cleanup. It is a synthetic proxy, not an independently supplied
external corpus.

## Layout

- `original-skills/` — source `SKILL.md` files.
- `skills/` — strict migrated `.meri` ports.
- `procedures.merconfig` — domain vocabulary, definitions, relations, phrases, tools.
- `procedures.merrules` — human-facing syntax (`SQL:`, `Check:`, `Emit:`).
- `RESOLVER.meri` — dispatch-table workflow for trigger phrase routing.
- `compile-outputs/` — generated Swift + manifests from `meridian compile`.
- `migration-deviations/` — reproducible per-skill deviation reports.

## Validation

```bash
swift run meridian migrate-skill corpora/procedures/original-skills --batch --out corpora/procedures/skills --vocab corpora/procedures/procedures.merconfig --rulebook corpora/procedures/procedures.merrules --force
swift run meridian skill-deviation corpora/procedures/original-skills corpora/procedures --batch --index --out corpora/procedures/migration-deviations
MERIDIAN_CORPORA_TYPECHECK=1 swift test --filter CorporaConformanceTests
```
