# ERP/OFBiz Proxy Corpus

Synthetic validation corpus for ERP/OFBiz-style operator runbooks.

This corpus is intentionally authored in an ERP voice (orders, invoices,
shipments, purchase orders, dunning, and period close) rather than gbrain's
knowledge-management voice. It is a synthetic proxy, not an independently
supplied external corpus.

## Layout

- `original-skills/` — source `SKILL.md` files.
- `skills/` — strict migrated `.meri` ports.
- `erp.merconfig` — domain vocabulary, definitions, relations, phrases, tools.
- `erp.merrules` — human-facing syntax (`Step:`, `Check:`, `Publish:`).
- `RESOLVER.meri` — dispatch-table workflow for trigger phrase routing.
- `compile-outputs/` — generated Swift + manifests from `meridian compile`.
- `migration-deviations/` — reproducible per-skill deviation reports.

## Validation

```bash
swift run meridian migrate-skill corpora/erp/original-skills --batch --out corpora/erp/skills --vocab corpora/erp/erp.merconfig --rulebook corpora/erp/erp.merrules --force
swift run meridian skill-deviation corpora/erp/original-skills corpora/erp --batch --index --out corpora/erp/migration-deviations
MERIDIAN_CORPORA_TYPECHECK=1 swift test --filter CorporaConformanceTests
```
