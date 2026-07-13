# Meridian — Expressiveness Report

Wave 6 closes the Inform-7-tier expressiveness program by validating Meridian
against three corpus families and reporting the result in measurement terms,
not marketing terms.

> **Superseded terminology note (2026-07-05, "Eliminate `(( inert ))`"
> closeout):** the migrator described in this report used `(( inert ))` /
> `(( inert, role: … ))` as its non-executable marker and judgment-routed a
> section's leftover body unconditionally once it fell below a split
> threshold. Both have since changed: the migrator now emits
> `(( role: reference ))` (never `(( inert ))`) for genuinely documentary
> content, routes to AI judgment only when an `EnglishLexicon.inferenceCueWords`
> cue is present, treats cue-less operational/normative content as a hard
> compile error rather than free documentation or an auto-judgment-wrap, and
> has no minimum-content split threshold. The "Sections inert" / "Inert
> ratio" / "Judgment" numbers below are a point-in-time Wave 6 snapshot under
> the *old* policy — see `docs/13_SKILL_MD_PORTING.md` for the current model
> and `IMPLEMENTATION_LOG.md` for the re-migration numbers under the new one
> (all three corpora: zero `(( inert ))`, zero operational/unclassified
> inert).
>
> **Further update (2026-07-06, "sectioned rule firing"):** Phase-8 rule sugar
> (`must not` / `may` [+ bounded] / `must be … before` / `When …, …`) now fires
> identically in flat and sectioned (`##`/`###`-heading) documents — the prior
> `!hasHeadings` gate that made every SKILL.md-style document rule-inert is
> gone (see `docs/15_DECISIONS.md` D-DX-6). This *lowers* the achievable inert
> ratio further: normative sentences that previously had no path but
> `(( role: reference ))`/hard-error now lower deterministically to `AssertIR`/
> `WaitIR`/permission structs instead. Two new synthetic corpora,
> `corpora/governance/` and `corpora/clinical/`, were authored specifically to
> exercise this — each expresses obligations as natural in-section rule sugar
> directly in a skill's body rather than a flat `rules/*.meridian` workaround.
> `corpora/incident/` and `corpora/etl/` extend the two-corpus scope this report
> was originally written against with wait/recover/parallel/judgment and
> data/table/temporal-window surface respectively. All four are outside this
> report's original Wave-6 Tier/similarity measurement scope (below); see
> `corpora/README.md` for their per-corpus metrics and
> `IMPLEMENTATION_LOG.md` for the full expansion writeup.
>
> **Wave 7 addendum (canonical drift):** the Wave 6 similarity/inert metrics
> below remain a historical measurement of the authored-to-ported migration
> surface. Wave 7 adds a second audit axis: `canonical_drift`, computed by
> compiling each port, verbalizing the lowered IR to Canonical English, and
> comparing authored vs canonical lines. Deviation indexes now include
> synonym/structure/desugar/meaning counts when regenerated with
> `skill-deviation --batch --index`; see [18_VERBALIZER.md](18_VERBALIZER.md)
> and [coverage/VERBALIZER_EVIDENCE.md](coverage/VERBALIZER_EVIDENCE.md).
>
> **Wave 8 addendum (trace-backed time/statistics):** this report predates the
> Wave 8 semantics pass. Retained-trace temporal/statistical conditions are now
> implemented (`has ever`, `within the last`, `in a row`, `since the last`,
> percentage frequency, monitored assertions), with coverage and residuals
> tracked in [19_TRACES_AND_TIME.md](19_TRACES_AND_TIME.md) and
> [coverage/WAVE8_COMPLETION_EVIDENCE.md](coverage/WAVE8_COMPLETION_EVIDENCE.md).
> The old Wave 6 statement that historical conditions were out of scope is
> therefore historical context, not current language status.
>
> **Wave 9 addendum (deontic / obligations):** prohibitions (`must not invoke`),
> obligations (`must hold`), and permissions (`may invoke`) lower to attempt-time
> guards and effect-time asserts with trace-witnessed violations (SEM-7). Stable
> `OBL-<hash>` obligation artifacts, `meridian obligations`, and `[OBL-…]`
> explain annotations ship in Wave 9B–9D. Coherence between runtime violations
> and proof obligations is established by **differential testing** (SEM-8-01),
> not a formal machine-checked theorem — see [20_DEONTIC.md](20_DEONTIC.md) and
> [21_OUT_OF_SCOPE.md](21_OUT_OF_SCOPE.md). This is honest regression evidence,
> not a proof of correctness for all traces.

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
| Swift validation | `swift test --filter GeneratedSwiftTypecheckSlowTests` / `CorporaConformanceTests` passes |

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
- This Wave 6 report predates Wave 8. Retained-trace historical conditions are
  now supported, but **pure state-history predicates** remain out of scope
  (`MER-TMP-019` rejects `since the last` holds that require state history
  rather than event history).
- General morphology remains out of scope. Verb forms still come from declared
  relation verbs and regular defaults.
- The proxy corpora intentionally prefer closed rulebook syntax over fuzzy prose.
  When an idiom is not deterministic, it is either documented as inert or
  rewritten to a supported form in the deviation report.
- **Checkable adjectives are global, not kind-scoped (documented deviation).**
  `Definition: a <kind> is <adjective> if …` registers the adjective under a
  single global, uniqueness-checked namespace (`ASTToIR.registerDefinitions` /
  `SymbolTable.definition(forAdjective:)`); resolution does not check the
  subject's declared kind or walk the domain lattice. A page-defined adjective
  therefore applies to any subkind (e.g. `deal`) automatically, by globality —
  the practical inheritance behavior the corpora need — but this is **not**
  literal kind-scoped most-specific resolution: two unrelated kinds can never
  define the same adjective name, even if a real per-kind model would allow
  shadowing. This is an intentional, confirmed simplification (kept because
  none of the three corpora need per-kind adjective shadowing, and reworking
  resolution would conflict with the global-uniqueness invariant for a
  low-value edge case). Property inheritance is unaffected — properties are
  already flattened per-kind in `DomainEmitter.buildDomainDecl`.
- **Relation-backed emptiness has no bare-noun surface (by design, not a
  gap).** `X has no <property>` lowers straight to `MeridianComparison.isEmpty`
  because a property name is unambiguous. A *relation* has no bare-noun
  surface of its own — only a conjugated verb — so `X has no <relation-noun>`
  cannot resolve which relation is meant without a verb. The closed-grammar
  route for a relation-backed emptiness condition is a `none`-kind quantifier
  restricted by a `that <verb> …` / `<participle> by …` relative clause (e.g.
  `no pages owned by the user`), which reuses the same verb-clause resolution
  as descriptions/aggregates/superlatives (see `Inform7Wave3Tests
  .relationBackedEmptinessLowers`). Tool-backed relation clauses inside a
  quantifier are rejected with a sourced "bind it first" diagnostic, matching
  every other inline tool-backed relation use.

## Reproduction

```bash
swift run meridian migrate-skill corpora/erp/original-skills --batch --out corpora/erp/skills --vocab corpora/erp/erp.merconfig --rulebook corpora/erp/erp.merrules --force
swift run meridian migrate-skill corpora/procedures/original-skills --batch --out corpora/procedures/skills --vocab corpora/procedures/procedures.merconfig --rulebook corpora/procedures/procedures.merrules --force

swift run meridian skill-deviation corpora/erp/original-skills corpora/erp --batch --index --out corpora/erp/migration-deviations
swift run meridian skill-deviation corpora/procedures/original-skills corpora/procedures --batch --index --out corpora/procedures/migration-deviations

swift test --filter GeneratedSwiftTypecheckSlowTests
swift test --filter CorporaConformanceTests
```
