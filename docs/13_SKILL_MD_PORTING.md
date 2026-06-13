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
hard error. An unmarked, unresolved imperative step is a coded `MER2001`
diagnostic (with a did-you-mean against the declared phrases) — it never
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

> **The migrator adds section titles to the rulebook for you.** When the marking
> pass meets an unrecognized **executable** heading (a section whose body is only
> shell fences — see option 2(b)), it does **not** stamp an inline
> `(( role: procedure ))`. Instead it leaves the heading clean and emits a
> `=== sections ===` alias (`section "<heading>" -> procedure`), which the CLI
> **appends to the rulebook** — the first `--rulebook` given, else the first
> autodiscovered `.merrules`, else a new `migrated-sections.merrules` beside the
> output. Persistence is idempotent (a heading already aliased is skipped) and,
> in stdout/preview mode (no `--out`), the aliases are printed as a snippet
> instead of written. So the rulebook accretes the corpus's organizational
> headings over a batch migration, and re-running compiles cleanly with no
> in-file markers. Narrative (non-shell) unknowns still get `(( inert ))`; the
> migrator only auto-aliases headings it can prove are executable.

> **`(( role: procedure ))` is redundant on a recognized procedure heading —
> don't add it.** `procedure` is the *implicit* role for any heading whose text
> normalizes to a recognized procedure synonym: `Phases`, `Workflow`,
> `Pipeline`, `Protocol`, `Steps`, `Process`, `Procedure`, or a `Phase N:`
> prefix (`SkillSectionRole.builtinRole`). For those, an explicit
> `(( role: procedure ))` is noise — prefer option 2(a): just **name the
> executable section** with one of those words and write no marker at all.
>
> The marker is **not** a blanket default, though: a content-bearing heading
> whose text is *not* a recognized role (e.g. `### Enforce back-links`) is a
> **hard error**, not a silent fall-through to procedure (no silent drops). So
> when you do need a custom/descriptive heading on executable lines, you must
> either rename it to a recognized synonym (preferred), add a `=== sections ===`
> rulebook alias, or keep the explicit `(( role: procedure ))`. In short: never
> *add* the marker to a `## Protocol`/`## Steps`/`Phase N:` heading; never
> *strip* it from a custom heading unless you also rename the heading.

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
7. **Adding executable logic to a documentation section → split, don't comment.**
   A `role` section makes **every** non-blank, non-comment line a live statement
   that must lower, so you cannot simply flip an `(( inert ))` heading to
   `(( role: procedure ))` while keeping its descriptive paragraph — that prose
   now errors as an unresolved phrase. The **correct** fix is a structural split
   (edit-budget item 4): keep the narrative in its `(( inert ))` section verbatim
   (it stays real, visible documentation) and add a **separate** sibling/child
   heading whose body is **only** executable statements. Example (`briefing.meri`
   back-linking):

   ```
   ## Back-Linking During Briefing (( inert ))

   If the briefing creates or updates any brain pages, the back-linking iron
   law applies: every entity the page mentions must have a back-link from their
   page. See `skills/_brain-filing-rules.md`.

   ### Enforce back-links (( role: procedure ))

   let mentioned be the entities mentioned by the input.
   for each entity in mentioned:
     if the entity does not link to the input, add a back-link from the entity to the input.
   ```

   The procedure section contains zero prose; the documentation stays inert and
   uncommented. (A `###` child re-resolves its own role, so it can sit under an
   inert `##` parent; for sections already at `###`, add a sibling `###`.)

   Note how the procedure preserves the narrative's **load-bearing qualifier**:
   the prose says "a mention *without* a back-link is a broken brain; fix the
   *missing* one" — so the loop is guarded (`if the entity does not link …`), not
   an unconditional `add`. The qualifier is execution-relevant context, not
   decoration (see fix 8).

   > **ANTI-PATTERN — do NOT blockquote the prose to silence the error.** It is
   > tempting to promote the section to `(( role: procedure ))` and prefix the
   > narrative with `>` so `IndentTokenizer` treats it as a comment. Don't: a
   > blockquoted line is *dropped from the IR* — no longer enforced, asserted, or
   > executed. That hides a real requirement behind a comment and is the one place
   > the "no silent drops" guarantee can't protect you (the drop is author-chosen
   > via `>`, not compiler-rejected). A `role` section's body must be exclusively
   > executable statements; everything else belongs in an `(( inert ))` section.
8. **Narrative encodes executable *contracts* — mine it before inerting.** This
   is the most-missed step. SKILL.md prose rarely just *describes*; it usually
   states **conditions on execution** that the language can lower:

   | Narrative shape | Lower it as | Example |
   |---|---|---|
   | "every X must Y" / "X is always Z after" (an **invariant / post-condition**) | `assert …` / `make sure …` (and/or a guarded repair loop that establishes it) | "every entity the page mentions must have a back-link" |
   | "before doing X, Y must hold" (a **precondition**) | `wait until …` / a leading `assert` guard | "wait for approval before merging" |
   | "if X, then the rule applies" (an **applicability guard**) | `if X, …` (single- or multi-line branch) | "if the briefing updates a page, the iron law applies" |
   | "a mention WITHOUT a back-link is broken; fix the MISSING one" (a **qualified** action) | guarded action, not unconditional | the `if the entity does not link …` guard above |

   The back-linking iron law is the canonical case: "every entity the page
   mentions must have a back-link" reads like documentation but is a
   **post-condition**. Lowering it (the guarded loop *establishes* it; an
   `assert`/`make sure` can *verify* it) captures intent the inert prose would
   have thrown away. **Before you mark any normative sentence `(( inert ))`, ask:
   is this a post-condition, precondition, invariant, or guard?** If yes, lower
   it — inert is only for genuinely non-executable material (rationale, examples,
   external references, formatting templates).

   > `assert`, `ensure`, and `make sure` are aliases for the same invariant
   > statement; a domain can add more introducers via a `=== language ===`
   > `Assertion synonyms:` block (see `docs/03`). Use whichever reads closest to
   > the source prose.

9. **Markdown structures are executable — don't reflexively inert them.**

   | SKILL.md shape | Lower it as | Notes |
   |---|---|---|
   | A **decision table** (conditions → action) | leave as a table (decision is the default) | last column / `action` header is the action; cells become `header is value` predicates |
   | A **data/lookup table** (rows of values) | `!!! table (( data table[: <name>] ))` above it | binds a record list; iterate with `for each row in <name>` |
   | A table that's genuinely reference-only | `!!! table (( inert ))` above it | the only place a table is inert (tables have no heading to mark) |
   | An **acceptance checklist** (`- [ ] …`) | leave as a task list | each item is an invariant `assert`; a non-checkable item is a hard error → rephrase or inert |
   | An **output-format rule** (`every emitted X …`) | `every emitted <noun> <predicate>` | generalized beyond regex to any checkable predicate |

   A `!!!` marker that is not directly above a table, an unknown block kind, or
   an unknown table mode is a **hard error** — never silently dropped.

10. **Watch for property names that collide with declared verbs.** A `=== language ===`
    /vocabulary verb (e.g. `to link`) makes any possessive property access whose
    *first word* is that verb (`the health's link count`) parse as a verb
    predicate, not a property read. Rename the property to avoid the verb word
    (`edge count`, not `link count`). This is why `brain.merconfig`'s health
    report uses `edge count` / `timeline count`.

11. **`## Tools Used` is metadata, not inert.** A `## Tools Used` (or `Tools`,
    `Tools Required`, `Required Tools`) section whose bullets each name a tool id
    is the recognized `.tools` role — it mines the ids into the workflow's
    `scopedTools` and the manifest `tools_used`. Do **not** mark it `(( inert ))`.
    Two bullet forms are accepted (keep whichever reads better, no reformatting):
    `<description> (<tool_id>)` and the leading-backtick `` `<tool_id>` — <description>``
    (any separator). A bullet matching neither — including a section that is
    actually a **CLI command reference** (``` `gbrain init …` -- create brain ```,
    whose backticked token has spaces and so isn't a bare tool id) — is genuine
    documentation; keep that one `(( inert ))`.

12. **Fuzzy tables/checklists are AI steps, not inert.** A decision table whose
    condition cells are *intent descriptions* (not checkable comparisons) and an
    acceptance checklist whose items are *not structurally checkable* are still
    part of the workflow — they just need judgment. Route them to the planner via
    the two AI modes instead of dropping them with `(( inert ))`:

    | Fuzzy shape | Mark it | Lowers to | The planner gets |
    |---|---|---|---|
    | Decision/routing table (intent → action) | `!!! table (( ai-discretion ))` | `ProseStepIR(.planThenExecute)` | "Decide which case applies and carry out its action: when …, …" (every row embedded) |
    | Acceptance checklist (`- [ ] all pages cross-linked`) | `!!! checklist (( ai-autonomy ))` above the list | `ProseStepIR(.autonomousLoop)` | "Ensure every acceptance criterion below holds, taking corrective action until all are satisfied: - …" (every item embedded) |

    This is the **same path** `use judgment to …:` takes (an explicit
    `ProseStepAST` dispatch), so it is valid in any workflow and runs through the
    existing planner / scope / checkpoint machinery — no new IR. The section the
    block sits under must be **executable** (a recognized `procedure`-role
    heading, or aliased in `=== sections ===`), since an `(( inert ))` section
    suppresses the whole body. Prefer `(( inert ))` for a table/checklist *only*
    when it is genuine reference material the workflow never acts on (benchmark
    evidence, a lookup the procedure never consults, a CLI reference). Decide:
    **does the workflow act on this?** Yes + deterministic → decision/data table
    or invariant checklist; yes + fuzzy → `ai-discretion` / `ai-autonomy`; no →
    `inert`. Worked example: `eiirp`'s `### Confirm` acceptance checklist was
    `(( inert ))`; it is now `!!! checklist (( ai-autonomy ))`, so the seven
    criteria become an autonomous loop that closes the workflow.

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
