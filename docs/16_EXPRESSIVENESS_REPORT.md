# Meridian — Expressiveness Report

Wave 6 closes the Inform-7-tier expressiveness program by validating Meridian
against three corpus families and reporting the result in measurement terms,
not marketing terms.

## Corpus Status

| Corpus | Status | Scope |
|---|---|---|
| gbrain | online | 52 upstream skills + `RESOLVER` in `sample-gbrain/` |
| ERP/OFBiz proxy | online (synthetic) | 8 operator runbooks + `RESOLVER` in `corpora/erp/` |
| stored-procedure proxy | online (synthetic) | 8 DBA runbooks + `RESOLVER` in `corpora/procedures/` |

The ERP and stored-procedure corpora are synthetic proxies authored for Wave 6.
They are intentionally written in non-gbrain voices, but they are not independent
maintainer-supplied corpora. That limits the strength of the final claim and is
tracked as a known caveat below.

## Metrics

Wave 0 baseline for gbrain (`IMPLEMENTATION_LOG.md`, "Wave 0 baseline"):

| Corpus | Pairs | Avg similarity | Sections inert | Avg inert ratio | Judgment |
|---|---:|---:|---:|---:|---:|
| gbrain (Wave 0) | 53 | 87% | 692/755 | 90% | 17 blocks / 73 lines |

Wave 6 final measurements:

| Corpus | Pairs | Tier 1 | Tier 2 | Tier 3 | Avg similarity | Sections inert | Inert deviations | Avg inert ratio | Judgment |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| gbrain | 53 | 51 | 1 | 1 | 90% | 730/754 | 730 | 97% | 1 block / 4 lines |
| ERP/OFBiz proxy | 9 | 8 | 1 | 0 | 93% | 16/30 | 6 | 49% | 0 blocks / 0 lines |
| stored-procedure proxy | 9 | 8 | 1 | 0 | 95% | 6/29 | 0 | 18% | 0 blocks / 0 lines |

The gbrain inert ratio is higher than the Wave 0 baseline because later
migration hardening intentionally preserved narrative SKILL.md material as
explicit inert documentation instead of silently treating it as executable. The
more important deterministic-routing signal improved sharply: judgment fell
from 17 blocks / 73 lines to 1 block / 4 lines.

## Mechanism Coverage

The two Wave 6 proxy corpora exercise these Inform-tier mechanisms in committed,
typechecked generated Swift:

| Mechanism | Coverage |
|---|---|
| Definitions | ERP: 7 checkable adjectives; procedures: 7 checkable adjectives |
| Relations + verbs | ERP: 4 backed relations + verbs; procedures: 3 backed relations + verbs |
| Quantifiers | `all`, `any`, and `no` appear across procedure assertions and runbooks |
| Temporal windows | Natural `is within the last ...` definition bodies compile |
| Tables | Resolver dispatch tables plus ERP invoice and procedure aging tables |
| Templates | `[for each row in table] ... [end for]` rendering in report skills |
| Rulebook syntax | `Step:`, `SQL:`, `Check:`, `Publish:`, `Emit:` desugar as data |
| Swift validation | `MERIDIAN_CORPORA_TYPECHECK=1 swift test --filter CorporaConformanceTests` passes |

## Worked Before/After

### gbrain: `install`

The raw `install` skill is a deprecation stub, not an executable runbook. The
migrator now wraps heading-less narrative in `## Overview (( inert ))` so strict
compile records the documentation instead of silently dropping it. Fresh
regeneration caught and refreshed the stale `install.swift`/manifest pair.

### ERP/OFBiz proxy: `place_order`

Original source keeps operator phrasing:

```text
Step: `ofbiz order-check --queue open --json` to snapshot the open order queue.
fetch open orders.
Check: all orders have a number.
Check: no orders whose status is "blocked".
for each order:
  reserve inventory for the order.
  create an invoice for the order.
  collect payment for the invoice.
  ship the order.
```

`erp.merrules` maps `Step:` to a shell command with annotation, `Check:` to a
deterministic assertion, and `Publish:` to an emit. The phrase library maps the
plain-English operations to declared ERP tool ids.

### Stored-procedure proxy: `reconcile_ledger`

Original source keeps DBA phrasing:

```text
SQL: `psql -c "select id,status from ledger_batch where status='ready'" --csv` to snapshot ready batches.
fetch ready batches.
Check: all batches have a name.
for each batch:
  settle the batch.
Emit: "ledger batches reconciled".
```

`procedures.merrules` makes `SQL:` and `Emit:` deterministic rulebook syntax.
No planner or fuzzy parsing is involved.

## Known Gaps And Caveats

- Corpora 2 and 3 are synthetic proxies. They use different domain idioms from
  gbrain, but they are still authored inside this repository. Independent
  maintainer-supplied corpora remain the stronger validation path.
- No runtime natural-language understanding is added. Dispatch remains compiled
  trigger/table logic plus explicit `RESOLVER` workflows.
- Past-tense/historical conditions remain out of scope; they require runtime
  state history and replay design.
- General morphology remains out of scope. Verb forms still come from declared
  relation verbs and regular defaults.
- The proxy corpora intentionally prefer closed rulebook syntax over fuzzy prose.
  When an idiom is not deterministic, it is either documented as inert or
  rewritten to a supported form in the deviation report.

## Reproduction

```bash
swift run meridian migrate-skill corpora/erp/original-skills --batch --out corpora/erp/skills --vocab corpora/erp/erp.merconfig --rulebook corpora/erp/erp.merrules --force
swift run meridian migrate-skill corpora/procedures/original-skills --batch --out corpora/procedures/skills --vocab corpora/procedures/procedures.merconfig --rulebook corpora/procedures/procedures.merrules --force

swift run meridian skill-deviation corpora/erp/original-skills corpora/erp --batch --index --out corpora/erp/migration-deviations
swift run meridian skill-deviation corpora/procedures/original-skills corpora/procedures --batch --index --out corpora/procedures/migration-deviations

MERIDIAN_CORPORA_TYPECHECK=1 swift test --filter CorporaConformanceTests
```
