# Corpora

This directory tracks the corpora the Inform-7-tier expressiveness program is
validated against.  The defensible claim — "Meridian
covers Inform-tier mechanisms for the workflow/skill domain" — requires the
grammar to survive contact with foreign corpora it was not designed around.

## Target: at least three corpora by end of program

| # | Corpus | Status | Source |
|---|--------|--------|--------|
| 1 | gbrain | online | `../sample-gbrain/` (52 skills + `RESOLVER`) |
| 2 | ERP/OFBiz proxy | online (synthetic) | `erp/` (8 skills + `RESOLVER`) |
| 3 | stored-procedure proxy | online (synthetic) | `procedures/` (8 skills + `RESOLVER`) |

Wave 6 brings corpora 2 and 3 online as **synthetic proxies**, not maintainer-
supplied external corpora. They deliberately use foreign domain voices (ERP
operator runbooks and DBA/stored-procedure runbooks) and are validated with the
same migrate/compile/typecheck/deviation loop as gbrain. The claim is therefore
honest but scoped: Meridian has now been tested against three corpus families,
two of which are synthetic rather than independently sourced.

## Wave 6 metrics

| Corpus | Pairs | Tier 1 | Tier 2 | Tier 3 | Avg similarity | Sections inert | Inert deviations | Avg inert ratio | Judgment |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| gbrain | 53 | 51 | 1 | 1 | 90% | 730/754 | 730 | 97% | 1 block / 4 lines |
| ERP/OFBiz proxy | 9 | 8 | 1 | 0 | 93% | 16/30 | 6 | 49% | 0 blocks / 0 lines |
| stored-procedure proxy | 9 | 8 | 1 | 0 | 95% | 6/29 | 0 | 18% | 0 blocks / 0 lines |

The two proxy corpora also exercise deterministic mechanism coverage directly:
checkable definitions, property-to-property definition predicates, relations and
declared verbs, quantifiers, data tables, template loops, rulebook desugars, and
generated Swift typechecking under `MERIDIAN_CORPORA_TYPECHECK=1`.

## The per-wave metric-delta rule

Every wave's acceptance includes the metric deltas, measured on **all corpora
present at that time**, regenerated reproducibly:

```bash
meridian skill-deviation <originals-dir> <ported-dir> \
    --batch --index --out <deviations-dir>
```

The counters that must be reported each wave (per corpus, plus index
totals/averages) are emitted by `meridian skill-deviation` and defined in
`Sources/MeridianCore/Migration/SkillMetrics.swift`:

- `total_sections`, `inert_sections`, `inert_ratio` — how much of each skill is
  non-executable documentation vs lowered, deterministic procedure.
- `judgment_blocks`, `judgment_lines` — how much of each skill still routes
  through the LLM (`use judgment to …:`, `with discretion`, `with autonomy`)
  rather than deterministic IR.

The program's thesis is that each wave's new deterministic surface should make
`inert_ratio` and `judgment_lines` fall (more of each skill expressible
deterministically) without the similarity or tier mix regressing. The Wave 0
baseline these are measured against is recorded in `../IMPLEMENTATION_LOG.md`
under "Wave 0 baseline".

Reports are byte-for-byte reproducible: the deviation diff is a faithful
`difflib` port and all collections are sorted, so a regenerated corpus diffs
cleanly against the committed one.
