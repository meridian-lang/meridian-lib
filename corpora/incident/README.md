# Incident/SRE Proxy Corpus

Synthetic validation corpus for SRE/on-call operator runbooks.

This corpus is intentionally authored in an SRE voice (alerts, services,
incidents, deploys, runbooks, on-call escalation, SLOs, and postmortems)
rather than gbrain's knowledge-management voice or erp/procedures'
transactional voice. It is a synthetic proxy, not an independently supplied
external corpus. It weights the coverage surface toward `wait`/`recover`/
`simultaneously`/judgment/tables that the `erp` and `procedures` corpora
exercise more lightly.

## Layout

- `original-skills/` — source `SKILL.md` files.
- `skills/` — strict migrated `.meri` ports.
- `incident.merconfig` — domain vocabulary, definitions, relations, phrases, tools.
- `incident.merrules` — human-facing syntax (`Runbook:`, `Check:`, `Post:`).
- `RESOLVER.meri` — dispatch-table workflow for trigger phrase routing.
- `compile-outputs/` — generated Swift + manifests from `meridian compile`.
- `migration-deviations/` — reproducible per-skill deviation reports.

## Validation

```bash
swift run meridian migrate-skill corpora/incident/original-skills --batch --out corpora/incident/skills --vocab corpora/incident/incident.merconfig --rulebook corpora/incident/incident.merrules --force
swift run meridian skill-deviation corpora/incident/original-skills corpora/incident --batch --index --out corpora/incident/migration-deviations
MERIDIAN_CORPORA_TYPECHECK=1 swift test --filter CorporaConformanceTests
```
