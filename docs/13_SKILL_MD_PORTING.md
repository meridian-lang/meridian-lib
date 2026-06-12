# Meridian — Porting `SKILL.md` to `.meri`

This is the playbook for converting a gbrain-style `SKILL.md` into a
strict-compiling Meridian `.meri`. It pairs with the rulebook engine
([11_RULEBOOKS.md](11_RULEBOOKS.md)) and the `meridian migrate-skill` tool
([07_CLI.md](07_CLI.md)).

The full ported corpus lives under `sample-gbrain/`:

```
sample-gbrain/
├── brain.merconfig    # one shared brain-domain vocabulary
├── brain.merrules     # idioms + section aliases + conventions
├── RESOLVER.meri      # the trigger → skill dispatcher
└── skills/*.meri      # 52 ported skills
```

Every file under `skills/` plus `RESOLVER.meri` compiles under strict mode with
zero `_unresolved` placeholders. The regression gate is
[`Tests/MeridianCoreTests/SampleGbrainConformanceTests.swift`](../Tests/MeridianCoreTests/SampleGbrainConformanceTests.swift)
("every ported gbrain skill compiles deterministically with no _unresolved").

---

## The governing principle

**Strict determinism — nothing calls an LLM unless explicitly marked.** No
prose, section, idiom, trigger, or guard ever auto-invokes the planner. The only
paths to the LLM are author-written markers: `with discretion` / `with autonomy`
(workflow or section header) and the inline `use judgment to <goal>:` block (all
lower to `ProseStepIR`). Everything else compiles to deterministic IR or is a
hard `semanticError`. An unmarked, unresolved imperative step errors — it never
silently degrades to an LLM call.

---

## The "minimal edits" budget

Per skill, the required edits are bounded to:

1. **Always:** prepend `vocabulary: brain.merconfig` to frontmatter, plus
   `rulebook: brain.merrules` for the idioms/aliases/conventions. (Section
   semantics activate structurally on the `##`/`###` headings — there is **no**
   `skill: true` flag.)
2. **Prefer, in order:** (a) a heading that already resolves to a recognized
   role; (b) a `=== sections ===` rulebook alias for an organizational heading;
   (c) an explicit marker on the existing heading — `(( inert ))` for narrative
   documentation, `(( inert, role: invariants ))` / `(( inert, role: prohibitions ))`
   for prose `## Contract` / `## Anti-Patterns`, or `(( role: <R> ))` to force a
   role inline.
3. **As needed:** wrap genuine judgment lines in `use judgment to …:` /
   mark a phase `with discretion:`.
4. **Rarely (structural rewrite):** split a MIXED prose+steps section into an
   `(( inert ))` heading + a recognized procedure heading; rephrase an imperative
   step that is too freeform for the grammar; rephrase a fuzzy applicability
   condition into a checkable predicate.

`meridian migrate-skill` injects no frontmatter and applies (1)–(2) wherever it
can; the strict compile surfaces the residue (3)–(4) as located errors.

---

## How a `SKILL.md` decomposes onto Meridian

A gbrain skill is YAML frontmatter + Markdown sections. The mapping that makes
"rename + minimal edits" work:

| `SKILL.md` element | Meridian target |
|---|---|
| `name` / `description` / `version` / `priority` / `when-to-use` | skill metadata (manifest `meridian_skill`) |
| `parameters:` (usually absent) | implicit entry workflow; defaults to a single generic `input` param |
| `vocabulary:` | **the one edit always required** (declares the brain domain + tools) |
| `tools:` | the scoped tool allow-list for this skill (`scopedTools`) |
| `triggers:` | typed triggers → manifest + synthetic trigger workflows |
| `mutating` / `writes_pages` / `writes_to` | effect metadata in the manifest |
| `## Contract` bullets | invariants → `assert` |
| `## Phases` / `## Protocol` | executable procedure (deterministic statements) |
| `## When To Use` | deterministic applicability (dispatch predicates + checkable preconditions) |
| `## When NOT To Use` / `### Do NOT …` | negative applicability (soft-skip guards + negative dispatch predicates) |
| `## Anti-Patterns` | `must not` where checkable; narrative ones stay inert |
| `## Output Format` | result template (fenced literal + `{{ }}`) |
| Philosophy / rationale / examples | inert outline / manifest metadata — no edit needed |

Pre-heading narrative (text before the first `##`) is **inert** when the file
has headings, so SKILL preambles need no edits.

---

## The deterministic surface you get for free

These are lowered deterministically — no markers required. See
[03_LANGUAGE_QUICK_REFERENCE.md](03_LANGUAGE_QUICK_REFERENCE.md) §"gbrain SKILL
surface" for the grammar.

- **Procedure idioms** (rulebook desugars): `If … -> …`, `If … then …`,
  bare `for each <kind>:`, `Report:` / `Output:` → emit, checklists.
- **Command surface:** fenced ` ```bash `/` ```sh `/` ```shell ` blocks AND
  inline backticked `gbrain …` commands inside a `procedure`-role section lower
  to `invoke shell.run with command = "<verbatim>"`. Multi-line blocks lower to
  one invoke per command line. This is a deterministic `invoke` (never an LLM)
  and avoids pre-declaring ~80 CLI verbs.
- **Choice-gate:** `ask the user to choose between "A", "B", or "C".` → emit
  `ask.choice` + `wait` (`WaitConditionIR.choice`) + branch on the response.
- **Background spawn:** `in the background, <stmt>.` → detached `Task {}` (no
  join).
- **Conventions:** Iron-Law back-linking, notability gate, and brain-first are
  injected from `brain.merrules` into matching workflows — no per-skill
  restatement.

---

## The explicit judgment escape hatch

When a step is genuinely synthesis/interview/routing, wrap it:

```
use judgment to decide if the entity is notable:
  Weigh prominence, recency, and reliability of sources.
```

`use judgment to <goal>:` (and `with discretion` / `with autonomy` on the
workflow header) lower to `ProseStepIR` with the per-skill `scopedTools`
allow-list. This is the ONLY path prose reaches the planner. Most Tier-B/C
`## Phases` sections that mix prose with `gbrain` commands are ported by
splitting the deterministic `gbrain` calls into bash fences and collapsing the
judgment-heavy steps into one `use judgment to …:` block.

---

## The three-tier edit budget

The corpus is structurally regular (`frontmatter + Contract + Phases +
When-To(/NOT)-Use + Output Format + Anti-Patterns`), so the section-role
rulebook carries the bulk uniformly. Skills sort into three tiers:

- **Tier A — clean deterministic.** Procedure maps directly to
  invoke/branch/iterate/emit. Edits = rename + `vocabulary:` + `rulebook:`
  (+ at most 1–2 idiom rephrasings).
- **Tier B — deterministic CLI orchestration.** The work is a sequence of
  `gbrain …` CLI calls, ported as bash fences (rename + frontmatter, no per-phase
  rewrites).
- **Tier C — genuinely judgment-heavy.** The core IS synthesis/interview/routing.
  The deterministic scaffold stays; a handful of `use judgment to …:` /
  `with discretion` markers sit on the synthesis steps. This is the intended
  design, not a shortfall.

### Coverage matrix (52 skills + RESOLVER)

| Tier | Skills |
|---|---|
| **A — clean deterministic** | `ask_user`, `brain_ops`, `brain_taxonomist`, `briefing`, `capture`, `citation_fixer`, `cron_scheduler`, `daily_task_manager`, `daily_task_prep`, `frontmatter_guard`, `functional_area_resolver`, `gbrain_upgrade`, `install`, `maintain`, `publish`, `repo_architecture`, `reports`, `signal_detector`, `skill_creator`, `skillpack_check`, `smoke_test`, `testing` |
| **B — CLI orchestration** | `archive_crawler`, `brain_pdf`, `cold_start`, `data_research`, `eiirp`, `idea_ingest`, `ingest`, `media_ingest`, `meeting_ingestion`, `migrate`, `minion_orchestrator`, `perplexity_research`, `schema_author`, `schema_unify`, `setup`, `skill_optimizer`, `skillify`, `skillpack_harvest`, `webhook_transforms` |
| **C — judgment-heavy** | `academic_verify`, `article_enrichment`, `book_mirror`, `concept_synthesis`, `cross_modal_review`, `enrich`, `idea_lineage`, `query`, `soul_audit`, `strategic_reading`, `voice_note_ingest` |
| **dispatcher** | `RESOLVER.meri` |

`meridian migrate-skill skills/ --batch --report <path>` regenerates this matrix
with exact line deltas and added-key counts per file.

### Auditing deviations

`meridian skill-deviation` ([07_CLI.md](07_CLI.md#meridian-skill-deviation))
diffs each original `SKILL.md` against its checked-in `.meri` and emits a
per-skill report plus an index, so the corpus port stays auditable as either
side evolves. It assigns the same effort tiers from a deterministic similarity
ratio (`>=0.85` -> 1, `0.5..<0.85` -> 2, `<0.5` -> 3). The committed corpus
reports live under `sample-gbrain/migration-deviations/` and are regenerated
with:

```bash
meridian skill-deviation \
    sample-gbrain/original-skills sample-gbrain \
    --batch --index --out sample-gbrain/migration-deviations
```

The original `SKILL.md` snapshots live under `sample-gbrain/original-skills/`
and the compiled Swift for each `.meri` under `sample-gbrain/compile-outputs/`
(generated by `meridian compile … --no-format`).

---

## Common porting fixes (from the corpus)

These are the recurring edits applied while porting the corpus. They are all
within the budget above.

1. **Prose `## Phases` → `use judgment to …:`.** A numbered-prose procedure that
   describes judgment ("Decompose the question…", "Synthesize an answer…") is
   collapsed into a single `use judgment to <goal>:` block with the steps as the
   indented body.
2. **Mixed prose + CLI → bash fences + judgment.** Pull the deterministic
   `gbrain …` commands into ` ```bash ` fences and collapse the rest into one
   judgment block.
3. **Fuzzy applicability → checkable predicate.** "Entity makes news or has a
   major event" → "the entity appears in major news". Avoid copulas (`is`) and
   comparison markers in conditions you intend as dispatch phrases.
4. **Ambiguous anaphora → spell out the referent.** "connect it to the brain" →
   "connect the content to the brain". The anaphora resolver runs on judgment
   headers and procedure text; an unresolvable pronoun is a hard error.
5. **Pure-narrative file → keep it heading-less, or mark the heading inert.** A
   file with no `##`/`###` headings stays a flat-procedure document (each line
   must still lower). To document narrative, put it under an explicit
   `## Overview (( inert ))` heading — an unmarked, unrecognized heading with
   content is a hard error, and content before the first heading is too (move it
   under a heading or make it a `#`/`>` comment).
6. **Loose anaphora-prone paragraphs under `## Contract`.** Each item must be a
   structurally checkable comparison, or mark the section
   `(( inert, role: invariants ))`; a non-checkable invariant item is a hard error.

---

## Worked example (`signal-detector`)

Rename → add `vocabulary` + `rulebook`. `## Contract` prose bullets are marked
`(( inert, role: invariants ))`; `## Phases` steps compile (`gbrain search "name"` → `shell.run` invoke;
`If NO page → … If page exists → trigger enrich` → branch + cross-skill call);
the one true-judgment line ("assess notability") gets
`use judgment to decide if the entity is notable:`. Net: ~3 added lines + 1
marker.

---

## Acceptance

- All ported `SKILL.md` files compile under strict mode within the per-tier
  budget; zero `_unresolved`.
- No prose reaches the planner unless explicitly marked
  (`use judgment to …:` / `with discretion` / `with autonomy`).
- Zero new IR primitives — only the `detached` flag on `SimultaneouslyIR` and the
  `.choice` case on `WaitConditionIR`.
- `meridian migrate-skill` converts a `SKILL.md` to a strict-compiling `.meri`;
  deterministic-only mode works offline; bounded LLM-assisted repair (mock
  provider in tests) auto-repairs residual diagnostics; every accepted migration
  compiles strict.
