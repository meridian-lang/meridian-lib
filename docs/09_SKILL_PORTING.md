# Meridian — Porting `SKILL.md` to `.meri`

The playbook for converting a gbrain-style `SKILL.md` into a strict-compiling
Meridian `.meri`: the edit budget, section-role mechanics, common porting
fixes, the long form of the role-section/narrative pitfalls, and the playbook
for generating a whole new synthetic corpus.

---

This is the playbook for converting a gbrain-style `SKILL.md` into a
strict-compiling Meridian `.meri`. It pairs with the rulebook engine
([03_LANGUAGE.md](03_LANGUAGE.md)) and the `meridian migrate-skill` tool
([05_CLI.md](05_CLI.md)).

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

**Strict determinism — nothing calls an LLM unless explicitly cued.** No prose,
section, idiom, trigger, or guard ever auto-invokes the planner. The only paths
to the LLM are author-written markers: `with discretion` / `with autonomy`
(workflow or section header) and the inline `use judgment to <goal>:` block (all
lower to `IRPrimitive.aiJudgment(AIJudgmentIR)` or `.aiAutonomy(AIAutonomyIR)`,
per dispatch mode), plus the migrator's cue-gated `!!! checklist
(( ai-autonomy ))` / `!!! table (( ai-discretion ))`. Everything else compiles
to deterministic IR or is a hard error. An unmarked, unresolved imperative step
is a coded `MER2001` diagnostic (with a did-you-mean against the declared
phrases) — it never silently degrades to an LLM call.

**P1 — every content unit is one of four things, never a silent fifth.** The
migrator (and the `InertYieldAnalyzer` measurement tooling it shares an oracle
with) classifies every section/block into exactly one bucket:

1. **Lowerable** — it trial-lowers as-is (a statement, a checkable predicate, a
   command/fence, a checklist/table item, or a Phase-8 rule shape — `must not` /
   `may` [+ bounded `up to N`] / `must be … by … before` / `When …, …` — inside
   an `invariants`/`prohibitions` section). No marker needed. Rule-shape
   detection is gated the same way in the migrator as in the compiler
   (`RuleAnalyzer.looksLikeRuleShapedSentence` before `classify`), so ordinary
   narrative that merely contains a rule keyword (e.g. "the file **may** exist
   outside the indexed brain") is never misfiled as a permission rule.
2. **AI-inference, cue-gated** — it does not lower, but carries an
   `EnglishLexicon.inferenceCueWords` cue (a cognitive verb: analyse,
   understand, decide, weigh, synthesize, …). Routed to `use judgment to …:` /
   `!!! checklist (( ai-autonomy ))` / `!!! table (( ai-discretion ))`. This is
   the **only** signal that may reach the planner — a normative cue alone
   (must/never/always) never does.
3. **Documentary (`reference`)** — no operational or inference signal at all:
   rationale, examples, external references, formatting templates, changelog.
   Marked `(( role: reference ))`.
4. **Operational, no cue — a hard error, not a marker.** Content that reads as
   a contract (an `EnglishLexicon.normativeCueWords` cue, or sits under a
   heading that already asserts a checkable/procedure role) but doesn't itself
   lower and carries no inference cue is left for the **real compiler** to
   reject with a precise reword diagnostic. Never silently filed as
   documentation, never silently auto-wrapped in judgment. `--route-fuzzy`
   (`meridian migrate-skill`) is the only opt-in escape hatch, and it still
   marks the result `(( role: reference ))` (and reports it), rather than
   inventing a fifth silent category.

Bucket 4 is the prose-classification instance of a general pattern —
reject an unsupported/unrecognized shape loudly instead of silently
miscategorizing or approximating it — that recurs on the expression-grammar
side too (rule predicates, `When` trigger conditions). See
`docs/03_LANGUAGE.md` §"A restricted sub-language rejects
unsupported forms loudly instead of approximating them" if you're ever
tempted to "fix" one of these hard errors by widening what silently passes.

The migrator **never emits `(( inert ))`** — bucket 3 above always renders as
`(( role: reference ))` (or `(( role: template ))` / `(( role: tools ))` /
`(( role: convention-ref ))` for their specific closed shapes). Hand-authoring
may still use plain `(( inert ))` (the compiler accepts it as a synonym), but a
migrated file containing one is a porting bug, flagged by
`skill-deviation`'s `inertMarkerCount`.

---

## The "minimal edits" budget

Per skill, the required edits are bounded to:

1. **Always:** prepend `vocabulary: brain.merconfig` to frontmatter, plus
   `rulebook: brain.merrules` for the idioms/aliases/conventions. (Section
   semantics activate structurally on the `##`/`###` headings — there is **no**
   `skill: true` flag.)
2. **Prefer, in order:** (a) a heading that already resolves to a recognized
   role; (b) a `=== sections ===` rulebook alias for an organizational heading;
   (c) an explicit marker on the existing heading — `(( role: reference ))` for
   narrative documentation or templates, or `(( role: <R> ))` to force a role
   inline. Never reach for `(( role: invariants/prohibitions ))` as a way to
   quiet non-checkable prose — a checkable-role heading with no checkable
   content and no inference cue is a hard error (P1 category 4), by design.
3. **As needed:** wrap genuine judgment lines (an inference cue is present) in
   `use judgment to …:` / mark a phase `with discretion:`.
4. **Rarely (structural rewrite):** split a MIXED prose+steps section into a
   `(( role: reference ))` heading + a recognized procedure heading; rephrase an
   imperative step that is too freeform for the grammar; rephrase a fuzzy
   applicability condition into a checkable predicate; reword a cue-less
   operational sentence so either it lowers directly or it gains a genuine
   inference cue.

`meridian migrate-skill` injects no frontmatter and applies (1)–(2) wherever it
can; the strict compile surfaces the residue (3)–(4) as located errors (or
`--route-fuzzy` reports them as a nonfatal skip for exploratory batch runs).

> **The migrator adds section titles to the rulebook for you.** When the marking
> pass meets an unrecognized **executable-only** heading (a section whose body is
> made only of deterministic Markdown surfaces such as shell fences, whole-line
> or embedded backticked commands, explicit table/checklist markers, checkable
> task-list items, choice gates, or Markdown list items that can be tried as
> procedure steps after presentation formatting is stripped), it does **not**
> stamp an inline
> `(( role: procedure ))`. Instead it leaves the heading clean and emits a
> `=== sections ===` alias (`section "<heading>" -> procedure`), which the CLI
> **appends to the rulebook** — the first `--rulebook` given, else the first
> autodiscovered `.merrules`, else a new `migrated-sections.merrules` beside the
> output. Persistence is idempotent (a heading already aliased is skipped) and,
> in stdout/preview mode (no `--out`), the aliases are printed as a snippet
> instead of written. So the rulebook accretes the corpus's organizational
> headings over a batch migration, and re-running compiles cleanly with no
> in-file markers. List formatting is not proof of documentation: `**bold**`,
> `__emphasis__`, and `[label](url)` are normalized away before strict compile
> gets a chance to lower the item. Mixed prose paragraphs plus procedure items
> get split automatically (see "Automatic mixed-section split" in
> [05_CLI.md](05_CLI.md#meridian-migrate-skill)): the narrative stays under the
> original heading marked `(( role: reference ))`, and the executable/AI-
> inference run(s) move to generated `— steps` sibling heading(s).

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
| `## Anti-Patterns` | `must not` where checkable; a genuinely non-checkable, cue-less item is a hard error, not free documentation |
| `## Output Format` | result template (fenced literal + `{{ }}`) |
| Philosophy / rationale / examples | `(( role: reference ))` outline / manifest metadata — no edit needed |

Pre-heading narrative (text before the first `##`) is blockquoted (non-
executable) when the file has headings, so SKILL preambles need no edits.

---

## The deterministic surface you get for free

These are lowered deterministically — no markers required. See
[03_LANGUAGE.md](03_LANGUAGE.md) §"gbrain SKILL
surface" for the grammar.

- **Procedure idioms** (rulebook desugars): `If … -> …`, `If … then …`,
  bare `for each <kind>:`, `Report:` / `Output:` → emit, checklists.
- **Command surface:** fenced ` ```bash `/` ```sh `/` ```shell ` blocks,
  whole-line backticked commands, and command-looking embedded backtick spans
  inside labelled/listed procedure prose lower to `invoke shell.run with command
  = "<verbatim>"`. Surrounding prose becomes the source annotation. Multi-line
  blocks lower to one invoke per command line. This is a deterministic `invoke`
  (never an LLM) and avoids pre-declaring ~80 CLI verbs.
- **Non-shell fence → tool (general-abilities, opt-in):** a domain's
  `.merconfig` `=== language ===` section can declare a `Fence tool mapping:`
  block (e.g. `python = interpreter.run`) so a fenced code block in that
  language lowers deterministically to one plain `invoke <tool> with code =
  "<whole fence body>"` instead of falling to inert or an AI-routed judgment
  step. This is the non-gbrain-repo analogue of the bash/sh/shell fence
  handling above — useful for skill repos whose procedures are Python/Node
  scripts rather than shell commands. See `EnglishLexicon.fenceToolMapping`.
- **Procedure heading synonyms (general-abilities):** besides
  `Phases`/`Workflow`/`Pipeline`/`Protocol`/`Steps`/`Process`/`Procedure`/
  `Phase N:`, the builtin `=== sections ===` alias table also recognizes
  `Instructions`, `Usage`, `Quickstart`/`Quick Start`, and `How It Works` as
  the `.procedure` role — common headings in non-gbrain `SKILL.md` repos. See
  `Rulebook.builtinSectionAliases`.
- **Choice-gate:** `ask the user to choose between "A", "B", or "C".` and the
  Markdown option-list form (`ask the user to choose between:` followed by
  indented numbered/bulleted/quoted options) emit `ask.choice` + `wait`
  (`WaitConditionIR.choice`). Follow-up `if yes:`, `if no:`, `if the user
  agrees:`, `if the user declines:`, and `if the user picks/selects/chooses N:`
  lines lower to deterministic branches over the selected value.
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
workflow header) lower to `AIJudgmentIR`/`AIAutonomyIR` with the per-skill
`scopedTools` allow-list. This is the ONLY path prose reaches the planner. Most Tier-B/C
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

`meridian skill-deviation` ([05_CLI.md](05_CLI.md#meridian-skill-deviation))
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
within the budget above. Fixes 7 and 12–14 (mixed-section splitting and fuzzy
AI-routing) are now mechanized by `meridian migrate-skill`'s marking pass by
default — read them as the shape reference / manual fallback rather than a
by-hand checklist; run the migrator first and only intervene where its
deterministic thresholds don't fit a specific section.

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
5. **Pure-narrative file → keep it heading-less, or mark the heading
   `reference`.** A file with no `##`/`###` headings stays a flat-procedure
   document (each line must still lower). To document narrative, put it under
   an explicit `## Overview (( role: reference ))` heading — an unmarked,
   unrecognized heading with content is a hard error, and content before the
   first heading is too (move it under a heading or make it a `#`/`>`
   comment). **`migrate-skill` adds this heading automatically** when the
   source has no `##`/`###` sections and the body reads as markdown narrative
   (bullets, emphasis, topic labels, …) rather than an executable flat
   procedure.
6. **Loose anaphora-prone paragraphs under `## Contract`.** Each item must be a
   structurally checkable comparison, or carry a genuine
   `EnglishLexicon.inferenceCueWords` cue (routed to judgment); a non-checkable,
   cue-less invariant item is a **hard error** (P1 category 4) — reword it into
   a checkable predicate, or add a real inference cue if it genuinely needs
   judgment. It is never silently marked `(( role: invariants ))`-and-inert;
   that role only stays clean when every line is checkable.
7. **Adding executable logic to a documentation section → split, don't comment.**
   **`meridian migrate-skill` does this automatically now** (see 05_CLI.md
   §"Automatic mixed-section split"): a heading whose body mixes narrative and
   executable/AI-inference lines is split into the narrative under the original
   `(( role: reference ))` heading (only when real leftover content remains)
   and a generated `— steps` sibling carrying just the executable/AI-inference
   run, aliased to `procedure`. There is no minimum-content threshold — every
   lowerable or AI-inference segment survives as its own child. What follows is
   the manual fallback — apply it by hand only when you are hand-authoring
   rather than running the migrator, or the automatic split's boundaries don't
   fit a specific section.

   A `role` section makes **every** non-blank, non-comment line a live statement
   that must lower, so you cannot simply flip an `(( role: reference ))` heading
   to `(( role: procedure ))` while keeping its descriptive paragraph — that
   prose now errors as an unresolved phrase. The **correct** fix is a structural
   split (edit-budget item 4): keep the narrative in its `(( role: reference ))`
   section verbatim (it stays real, visible documentation) and add a
   **separate** sibling/child heading whose body is **only** executable
   statements. Example (`briefing.meri` back-linking):

   ```
   ## Back-Linking During Briefing (( role: reference ))

   If the briefing creates or updates any brain pages, the back-linking iron
   law applies: every entity the page mentions must have a back-link from their
   page. See `skills/_brain-filing-rules.md`.

   ### Enforce back-links (( role: procedure ))

   let mentioned be the entities mentioned by the input.
   for each entity in mentioned:
     if the entity does not link to the input, add a back-link from the entity to the input.
   ```

   The procedure section contains zero prose; the documentation stays
   non-executable and uncommented. (A `###` child re-resolves its own role, so
   it can sit under a reference `##` parent; for sections already at `###`, add
   a sibling `###`.)

   The same split applies to **executable template binds** that use `[if]` /
   `{{ }}` holes: keep narrative under `(( role: reference ))`, and put the
   `bind … = ```…``` ` statement in a procedure / `— steps` sibling. Template
   binds left in a reference section never lower (accessmatrix/policyaudit
   lesson).

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
   > executable statements; everything else belongs in an `(( role: reference ))`
   > section.
8. **Narrative encodes executable *contracts* — mine it before marking `reference`.**
   This is the most-missed step. SKILL.md prose rarely just *describes*; it usually
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
   `assert`/`make sure` can *verify* it) captures intent the reference prose
   would have thrown away. **Before you mark any normative sentence
   `(( role: reference ))`, ask: is this a post-condition, precondition,
   invariant, or guard?** If yes, lower it — `reference` is only for genuinely
   non-executable material (rationale, examples, external references,
   formatting templates). If it's normative-shaped (a `must`/`never`/`always`
   cue) but you can't lower it and it has no genuine inference cue, it is a
   **hard error** to reword, not free documentation (P1 category 4) —
   `(( role: reference ))` may never be used to silence it.

   > `assert`, `ensure`, and `make sure` are aliases for the same invariant
   > statement; a domain can add more introducers via a `=== language ===`
   > `Assertion synonyms:` block (see `docs/03`). Use whichever reads closest to
   > the source prose.

9. **Markdown structures are executable — don't reflexively inert them.**

   | SKILL.md shape | Lower it as | Notes |
   |---|---|---|
   | A **decision table** (conditions → action) | leave as a table (decision is the default) | last column / `action` header is the action; cells become `header is value` predicates |
   | A **data/lookup table** (rows of values) | `!!! table (( data table[: <name>] ))` above it | binds a record list; iterate with `for each row in <name>` |
   | A table that's genuinely reference-only | `!!! table (( inert ))` above it | the only place a table is inert (tables have no heading to carry a `(( role: reference ))` marker instead) |
   | An **acceptance checklist** (`- [ ] …`) | leave as a task list | each item is an invariant `assert`; a non-checkable item with no inference cue is a hard error → rephrase, or route via `!!! checklist (( ai-autonomy ))` if it genuinely needs judgment |
   | An **output-format rule** (`every emitted X …`) | `every emitted <noun> <predicate>` | generalized beyond regex to any checkable predicate |

   A `!!!` marker that is not directly above a table, an unknown block kind, or
   an unknown table mode is a **hard error** — never silently dropped.

10. **Watch for property names that collide with declared verbs.** A `=== language ===`
    /vocabulary verb (e.g. `to link`) makes any possessive property access whose
    *first word* is that verb (`the health's link count`) parse as a verb
    predicate, not a property read. Rename the property to avoid the verb word
    (`edge count`, not `link count`). This is why `brain.merconfig`'s health
    report uses `edge count` / `timeline count`.

11. **`## Tools Used` is metadata, not reference.** A `## Tools Used` (or
    `Tools`, `Tools Required`, `Required Tools`) section whose bullets each name
    a tool id is the recognized `.tools` role — it mines the ids into the
    workflow's `scopedTools` and the manifest `tools_used`. Do **not** mark it
    `(( role: reference ))`. Two bullet forms are accepted (keep whichever reads
    better, no reformatting): `<description> (<tool_id>)` and the
    leading-backtick `` `<tool_id>` — <description>`` (any separator). A bullet
    matching neither — including a section that is actually a **CLI command
    reference** (``` `gbrain init …` -- create brain ```, whose backticked token
    has spaces and so isn't a bare tool id) — is genuine documentation; keep
    that one `(( role: reference ))`.

12. **Fuzzy tables/checklists are AI steps only when they carry an inference
    cue — otherwise they're a reword error, never reference.** **`meridian
    migrate-skill` routes the cue-gated case automatically**: a checklist/table
    block that doesn't trial-lower AND carries an `inferenceCueWords` cue gets
    the `!!! checklist (( ai-autonomy ))` / `!!! table (( ai-discretion ))`
    marker prepended for you, and a section with no executable content but an
    inference cue becomes a `use judgment to follow the <heading> guidance:`
    wrap. A cue-less non-lowerable checklist/table is instead left for the real
    compiler to reject (P1 category 4) — pass `--route-fuzzy` to downgrade that
    to a reported, nonfatal `(( role: reference ))` skip for exploratory batch
    runs, or reword the block so it either lowers or gains a genuine cue. What
    follows is the manual shape reference — apply it by hand when
    hand-authoring or adjusting an automatically-routed block. A decision table
    whose condition cells are *intent descriptions* (not checkable comparisons)
    and an acceptance checklist whose items are *not structurally checkable*
    are still part of the workflow — if they genuinely need judgment (an
    inference cue is present or the cell text says so), route them to the
    planner via the two AI modes instead of leaving them as an error:

    | Fuzzy shape | Mark it | Lowers to | The planner gets |
    |---|---|---|---|
    | Decision/routing table (intent → action) | `!!! table (( ai-discretion ))` | `IRPrimitive.aiJudgment(AIJudgmentIR)` | "Decide which case applies and carry out its action: when …, …" (every row embedded) |
    | Acceptance checklist (`- [ ] all pages cross-linked`) | `!!! checklist (( ai-autonomy ))` above the list | `IRPrimitive.aiAutonomy(AIAutonomyIR)` | "Ensure every acceptance criterion below holds, taking corrective action until all are satisfied: - …" (every item embedded) |

    This is the **same path** `use judgment to …:` takes (an explicit
    `ProseStepAST` dispatch), so it is valid in any workflow and runs through the
    existing planner / scope / checkpoint machinery — no new IR. The section the
    block sits under must be **executable** (a recognized `procedure`-role
    heading, or aliased in `=== sections ===`), since a `(( role: reference ))`
    section suppresses the whole body. Reserve `(( inert ))`/`(( role: reference
    ))` for a table/checklist *only* when it is genuine reference material the
    workflow never acts on (benchmark evidence, a lookup the procedure never
    consults, a CLI reference). Decide: **does the workflow act on this?** Yes +
    deterministic → decision/data table or invariant checklist; yes + fuzzy +
    genuine inference cue → `ai-discretion` / `ai-autonomy`; yes + fuzzy + no
    cue → reword it (hard error, not a free pass); no → `reference`. Worked
    example: `eiirp`'s `### Confirm` acceptance checklist used to be marked
    inert; it is now `!!! checklist (( ai-autonomy ))`, so the seven criteria
    become an autonomous loop that closes the workflow.

13. **Operational inert must go to zero — and now it structurally can't
    silently recur.** The deviation index reports `Operational inert`,
    `Unclassified inert`, an inert-category breakdown, and `inertMarkerCount`
    (literal `(( inert ))` markers — the migrator never writes one, so a
    nonzero count in a migrated file is itself a bug); per-file reports list
    every non-executable heading with its category and reason. Treat
    `unclassified`, `operational inert`, and any nonzero `inertMarkerCount` as
    porting bugs. Operational inert means a section is procedure-shaped,
    checkable/normative, or contains executable Markdown surfaces but is still
    suppressed — under P1 this should no longer happen, because a cue-less
    operational body is left unmarked/aliased for the real compiler to reject
    rather than marked `(( role: reference ))`. Fix a residual instance by
    adding a section alias, splitting mixed prose, lowering deterministic
    lines, routing genuinely judgment-worthy work with `ai-discretion` /
    `ai-autonomy` (only if an inference cue is present), or authoring the
    `brain.merconfig` phrase the content needs before it will trial-lower. The
    migration report's
    `unmined-contract` line count is the leading indicator: a normative
    (must/never/always-shaped) line that didn't lower and wasn't split out is
    listed there rather than silently disappearing into reference prose.

14. **`Contract` / `Anti-Patterns` are executable, explicitly AI-routed, or a
    reword error — never silently reference.** When every line is checkable,
    leave the section live so invariant/prohibition lowering can produce
    assertions. When the contract is fuzzy or mixed but carries a genuine
    inference cue, make it an executable procedure section and route the
    checklist to the planner. When it's fuzzy or mixed with **no** inference
    cue, it is a hard error (P1 category 4) to reword — never mark it
    `(( role: reference ))` to make the error go away:

    ```meri
    ## Contract (( role: procedure ))

    !!! checklist (( ai-autonomy ))
    - [ ] Every fact has a source citation.
    - [ ] Gaps are called out explicitly.
    ```

    Long operational prose that cannot be deterministically lowered should use
    an explicit judgment block, e.g. `use judgment to follow the <heading>
    guidance:`. That form intentionally collects prose until the next heading.

15. **`normativeCueWords` matching is word-level and context-blind — a
    throwaway "never"/"always" in pure narrative still trips category 4.**
    (See also `corpora/GENERATING_A_CORPUS.md` §"Known gotchas" #1, which
    keeps this same example alongside the other corpus-authoring gotchas —
    `if`/`otherwise` + judgment fragmentation, rule-attachment phrasings that
    silently don't attach, unsupported negative temporal definitions.)
    When authoring rich, `sample-gbrain`-style narrative for a `## Contract` /
    `## Anti-Patterns` / `## When NOT to use this skill` section (a real prose
    intro, cross-references to sibling skills, etc. — see the governing
    principle above; this is the *intended* authoring style, not a
    workaround), every *other* bullet with no cue word joins its siblings and
    splits cleanly to `(( role: reference ))`. But `EnglishLexicon.
    normativeCueWords` (`must`/`never`/`always`/`refuse*`/`require*`/
    `forbidden`/`mandatory`) is a bare substring/word match with no semantic
    check for whether the sentence is actually asserting a rule. A purely
    descriptive `## Contract` bullet —

    ```
    - Side effect: a classified grant is never issued without an approval
      record; a denial gets logged for the next revoke-stale-access sweep.
    ```

    — reads as ordinary background prose to a human, but the migrator's P1
    classifier files it as category 4 ("operational, no cue" — item 8 above)
    purely because it contains "never", and it surfaces alone as an
    `unmined-contract` line in `migrate-skill --route-fuzzy`'s report instead
    of joining its siblings as clean reference prose. The fix is always to
    reword the sentence so the cue word is gone, e.g.:

    ```
    - Side effect: a classified grant carries an approval record from the
      security officer; a denial gets logged for the next revoke-stale-access
      sweep.
    ```

    Never "fix" this by adding `(( role: reference ))` to a heading that
    already resolves that way, and never by wrapping the line in `use
    judgment to …:` — there is no genuine inference cue here, so that would
    misroute a deterministic-documentation line to the planner. The same root
    cause (a sentence that structurally resembles something checkable/
    normative) also explains a related but distinct diagnostic: a quoted
    throwaway aside immediately followed by a dangling pronoun — e.g. `Don't
    do X just because it "always works." The real reason is Y because it's
    the most disruptive option.` — trips the "ambiguous anaphora" check (item
    4) instead, because the pronoun right after the closing quote reads as an
    unresolved referent. Reword to drop the quote or the pronoun (`Don't do X
    out of habit. The real reason is Y.`), not to restructure the section.

    Both failure modes are reworded-prose fixes to the `original-skills/**/
    SKILL.md` source, confirmed by re-running `migrate-skill --batch --report`
    until `unmined-contract line(s)` reads 0 and `skill-deviation --batch
    --index` reports `Operational inert: 0` — the leading indicators that the
    richer narrative migrated as intended rather than silently degrading.

---

## Worked example (`signal-detector`)

Rename → add `vocabulary` + `rulebook`. `## Contract`'s narrative guarantee
bullets are marked `(( role: reference ))`, with its structurally executable
sub-content split into a `— steps` sibling; `## Phases` steps compile
(`gbrain search "name"` → `shell.run` invoke; `If NO page → … If page exists →
trigger enrich` → branch + cross-skill call); the one true-judgment line
("assess notability") gets `use judgment to decide if the entity is
notable:`. Net: ~3 added lines + 1 marker.

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

---

## Wave 4 Porting Fixes

Use `## Domain` for skill-local vocabulary that would otherwise force a separate
`.merconfig` edit: small kind declarations, `called the` properties, and
`can be ... or ...` states with `usually` defaults. Keep domain sentences out of
procedure bodies; there they are conditions or errors, not assembly-time
vocabulary.

Use `## Tables` for deterministic dispatch or lookup tables. Annotate columns
when type matters (`score (Number)`, `deadline (Date)`), and then use lookup
phrases like `the skill corresponding to the trigger phrase "daily briefing" in
the table`. If missing rows are expected, attach `recover from
"table.lookup_miss":`.

Use text substitutions inside explicit string/fenced expression positions, not
by making `## Output Format` executable. `[date]`-style placeholders remain
literal unless they use the closed directives `[if ...]`, `[otherwise]`,
`[end if]`, `[for each ...]`, or `[end for]`.

---

## Pitfalls #14 and #15 — role sections and narrative contracts

*Long form of `AGENTS.md` §6 pitfalls #14–#15; `AGENTS.md` keeps the one-line
versions.*

### 14. A `role` section's body must be exclusively executable — split, don't comment

A section with an executable role (`(( role: procedure ))`, `(( role: invariants ))`,
…) makes **every** non-blank, non-comment line a live statement that must lower.
So you cannot flip an `(( role: reference ))` documentation heading to a role and
keep its narrative paragraph — that prose errors as an unresolved phrase. The
**correct** fix is a structural split: keep the narrative in its
`(( role: reference ))` section (verbatim, uncommented — it stays real
documentation) and add a **separate** sibling/child heading whose body is
**only** executable statements. A `###` child re-resolves its own role under a
`reference` `##` parent; for sections already at `###`, add a sibling `###`.
`meridian migrate-skill` performs this split automatically now (see
`docs/09_SKILL_PORTING.md` §"Common porting fixes" item 7); the gbrain
back-linking conversions (`briefing` `### Enforce back-links`, `maintain`
`### Repair missing back-links` / `### Create missing cross-references`) follow
this shape as the manual-fallback worked example.

**ANTI-PATTERN — do NOT blockquote the prose to silence the error.** Prefixing the
narrative with `>` (so `IndentTokenizer` treats it as a comment) is lossy: a
blockquoted line is *dropped from the IR* — no longer enforced, asserted, or
executed. That hides a real requirement behind a comment and is the one place the
"no silent drops" guarantee (§6 / `SkillSectionBuilder` strictness) can't protect
you, because the drop is author-chosen via `>` rather than compiler-rejected. Full
guidance: `docs/09_SKILL_PORTING.md` §"Common porting fixes" item 7.

### 15. Narrative encodes executable contracts — mine it, route it, or let it hard-error; never auto-wrap or inert it

The most-missed porting step (and the deeper lesson behind §14): SKILL.md prose
rarely *only* describes — it usually states **conditions on execution** the
language can lower. A sentence like "every entity the page mentions must have a
back-link" reads like documentation but is a **post-condition** (`assert …` /
`make sure …`, and/or a guarded loop that establishes it). "before X, Y must
hold" is a **precondition** (`wait until …` / a leading guard). "if X, the rule
applies" is an **applicability guard** (a branch). A qualifier like "fix the
*missing* one" makes an action **conditional**, not unconditional (the
back-linking loop is `if the entity does not link …`, never a bare `add`).

**`SkillMigrator` resolves every non-lowerable content unit through a fixed
four-way precedence — never a fuzzy auto-wrap, never a blanket `inert`:**

1. **Lowerable** → lower it (unmarked, or split into a `— steps` child).
2. **Not lowerable, but carries an `EnglishLexicon.inferenceCueWords` cognitive-verb
   cue** (`analyse`/`decide`/`assess`/`evaluate`/…) → the **only** case that may
   emit an AI marker: `use judgment to …:` / `ai-discretion` / `ai-autonomy`.
3. **Not lowerable, no inference cue, genuinely documentary** (rationale,
   examples, external references, formatting templates) → `(( role: reference ))`
   — never `(( inert ))`; the migrator does not emit that keyword.
4. **Not lowerable, no inference cue, but normative/operational** (an
   `EnglishLexicon.normativeCueWords` cue — `must`/`never`/`always`/`require*`/
   `refuse*`/…, or a role heading that already asserts a checkable contract) →
   **left unmarked** so the real compiler raises its own precise
   `uncheckablePredicate`/`unresolvedPhrase` error naming the reword needed.
   This is an **intentional hard error** (P3), not a bug: re-migration can now
   fail by design, and the fix is to reword the line or add a genuine
   inference-cue verb if AI judgment really is intended — never to silently
   file it as `reference` or wrap it in judgment.

**Before marking any normative sentence `(( role: reference ))`, classify it:
post-condition, precondition, invariant, or guard? If it's any of those, lower
it (or, failing that, let category 4 catch it — don't paper over it).**
`assert`/`ensure`/`make sure` are aliases (extensible via `=== language ===`
`Assertion synonyms:`); pick the one closest to the source wording.
`(( inert ))` remains valid, compiler-accepted hand-authored syntax (a synonym
of `(( role: reference ))`) — but a bare `(( inert ))` surviving in a
*migrator-generated* file is a deviation-report violation
(`SkillMetrics.inertMarkerCount`), since the migrator itself never emits it.
Full guidance + the contract-shape table + the four-way precedence:
`docs/09_SKILL_PORTING.md` §"Common porting fixes" items 7–8; the
`=== language ===` recipe for the three classification categories:
`docs/03_LANGUAGE.md` §"SkillMigrator classification synonyms".

---

## Generating a new synthetic corpus

*Was `corpora/GENERATING_A_CORPUS.md`; that file is now a pointer here.*

This is the playbook for adding a new corpus under `corpora/<name>/` (e.g.
`erp`, `procedures`, `incident`, `etl`, `governance`) — a from-scratch domain
vocabulary plus a set of natural-sounding `SKILL.md` files, ported through the
same `migrate-skill` → `compile` → `skill-deviation` loop as `sample-gbrain`.
See `corpora/README.md` for why these corpora exist (the Inform-tier
expressiveness program's "survive contact with a foreign domain" claim) and
the metrics every wave reports.

This doc is the **how**; `docs/09_SKILL_PORTING.md` is the authoritative
reference for the underlying `SkillMigrator`/section-role mechanics (read it
first if anything below is surprising). `AGENTS.md` §6 keeps only a one-line
pointer to the gotchas here — this file is where the full detail lives.

---

### 1. Directory layout

```
corpora/<name>/
├── <name>.merconfig        # domain vocabulary: kinds, properties, relations,
│                            # verbs, tools, constants, instances, language synonyms
├── <name>.merrules         # desugar rules + === sections === role aliases
├── original-skills/
│   ├── RESOLVER.md         # trigger → skill dispatch table (prose, not SKILL.md-named)
│   └── <skill>/SKILL.md    # one directory per skill, natural-language source
├── skills/*.meri           # migrated output (generated — see step 4)
├── RESOLVER.meri           # migrated resolver (generated)
├── compile-outputs/        # generated Swift + manifests (generated — see step 5)
└── migration-deviations/   # skill-deviation reports (generated — see step 6)
```

Only `<name>.merconfig`, `<name>.merrules`, and `original-skills/**` are
hand-authored. Everything else is regenerated by the scripts in step 4–6 and
should never be hand-edited (the `IMPLEMENTATION_LOG.md`/`AGENTS.md`
"original `SKILL.md` is read-only" norm applies symmetrically to the *ported*
side too: fix the source or the compiler/migrator, never hand-patch a
`.meri`).

### 2. Design the vocabulary and rulebook first

1. Pick a domain with a genuinely different voice from what's already
   covered (operator runbooks, DBA procedures, SRE on-call, ETL pipelines,
   access governance, …) — the point of a new corpus is exercising the
   grammar against unfamiliar phrasing, not restating an existing one.
2. Write `<name>.merconfig`: the kinds and their properties (mark enums,
   `Money`/`Date`/`Number` types explicitly), relations, declared verbs, tool
   phrases (`To <verb> a <noun>[, with a <param>]:`), constants, instances,
   and any `=== language ===` synonyms the domain needs.
3. Write `<name>.merrules`: at minimum, `Check:`/`Note:`/`Log:`/`Emit:`-style
   desugar rules matching the corpus's chosen prose idiom (see the existing
   corpora for the pattern), and an initial `=== sections ===` block for any
   heading you already know will be custom (e.g. a skill-specific procedure
   heading like "Replay Routing"). `migrate-skill` appends more aliases here
   automatically as you go (see step 4) — don't pre-guess all of them.
4. Sanity-compile one trivial hand-written `.meri` skill against the vocab/
   rulebook before authoring any real `SKILL.md`, to catch vocabulary typos
   early.

### 3. Author `original-skills/**/SKILL.md` in the `sample-gbrain` voice

**Write natural, detailed prose — not pre-split pseudo-`.meri`.** This is the
single most important habit this playbook exists to instill. A corpus skill
should read like a real runbook a real operator would write, with the same
shape `sample-gbrain/original-skills/capture/SKILL.md` uses:

```
---
name: <skill name>
description: <2 sentences — what it does AND why/when, not just what>
triggers:
  - "<phrase>"
parameters: <comma-separated kind names, if the skill isn't a bare entrypoint>
---

# <Title>

<3-6 sentence narrative paragraph: what problem this solves, why it exists,
how it relates to sibling skills. This is pure scene-setting prose.>

## Contract
- Input: …
- Output: …
- Side effect: …

## When to invoke
- "<trigger phrase>"
- "<trigger phrase>"

## Rules            (Phase-8 in-section rules, if any: must not / may / must be approved by / When …,)
## Workflow          (the executable core: if/otherwise, for each, wait, recover, tables, judgment, …)
## Anti-Patterns
- Don't do X because Y.
- Don't do Z because W.

## When NOT to use this skill
<narrative pointing at sibling skills that are the better fit for adjacent cases.>

## Guarantees / Report shape
<narrative + any genuine checkable invariant.>
```

`Contract`, `Anti-Patterns`, `When NOT to use this skill`, and `Output
Format`/`Report shape` are **built-in recognized headings**
(`Rulebook.builtinSectionAliases`) — you don't need a `=== sections ===` alias
for any of them. `migrate-skill` automatically splits a heading that mixes
narrative and checkable/executable content into the original heading marked
`(( role: reference ))` (the narrative) plus a generated `— steps` sibling
(the checkable/executable remainder) — confirmed against `sample-gbrain/
skills/capture.meri`'s own `## Contract`/`## Anti-Patterns` sections, which
already show this exact shape. Writing rich narrative and letting the
migrator split it is the *intended* workflow, not something to work around.

Keep the executable core (`## Rules`/`## Workflow`/tables) exactly as
carefully as you'd write a hand-authored `.meri` — the narrative wrapper
doesn't relax any of the language surface rules, and a fragile `if/otherwise`
+ judgment construct (see gotcha 3 below) is just as fragile inside a richer
`SKILL.md`.

**Number multi-statement sequences inside `## Workflow`/`## Rules`, at every
nesting level, the same way `sample-gbrain`'s `## Phases` numbers its steps.**
A block of 2+ sibling statements — whether the section's top level or the
body of a `for each`/`until`/`recover where` — reads as a plain run-on list
without numbering and as a natural sequence of steps with it. A block with
only one statement doesn't need a number (there's nothing to enumerate).
Before:

```
## Workflow
fetch unpaid invoices.
Check: any unpaid invoices.
for each invoice:
  until it is not the case that the invoice is unpaid,
    collect payment for the invoice.
    recover where the error code equals "payment.declined":
      escalate the invoice.
Publish: "payment retry pass complete".
```

After:

```
## Workflow
1. fetch unpaid invoices.
2. Check: any unpaid invoices.
3. for each invoice:
  until it is not the case that the invoice is unpaid,
    1. collect payment for the invoice.
    2. recover where the error code equals "payment.declined":
      escalate the invoice.
4. Publish: "payment retry pass complete".
```

Numbering restarts inside each nested block (`1.`/`2.` under `until` is
independent of the outer `1.`–`4.`), exactly like a nested outline — not a
single running count across the whole section. `for each invoice:` and
`recover where …:` each have only one child statement here, so they stay
unnumbered.

This is purely cosmetic and safe to apply anywhere, including inside a `for
each`/`if`/`until`/`recover where` body: `IndentTokenizer.stripMarkdownSurface`
strips a leading `N. ` (or `- `/`* `) marker from **any** line before
statement parsing ever sees it — this is base-tokenizer behavior shared by
every `.meri`/`SKILL.md` source, not something `SkillMigrator`-specific. Block
nesting is computed from the line's raw leading whitespace *before* the
marker is stripped, so adding a number never changes which statements are
siblings vs. children. Confirmed by diffing the generated Swift for
`payment_retry` before/after this rewrite: byte-identical apart from the
source-line-number trace comments. Prefer this over unnumbered runs of
statements in every new corpus skill; retrofit existing ones opportunistically
rather than as a dedicated pass.

### 4. Migrate

```bash
swift run meridian migrate-skill corpora/<name>/original-skills \
  --out corpora/<name>/skills --batch --force \
  --vocab corpora/<name>/<name>.merconfig --rulebook corpora/<name>/<name>.merrules \
  --report corpora/<name>/migration-report.md --route-fuzzy

swift run meridian migrate-skill corpora/<name>/original-skills/RESOLVER.md \
  --out corpora/<name>/RESOLVER.meri --force \
  --vocab corpora/<name>/<name>.merconfig --rulebook corpora/<name>/<name>.merrules --route-fuzzy
```

Target **0 unmined-contract line(s)** for every skill (`RESOLVER.md` is
allowed a small residual — it's a prose dispatch table, not a skill). Read
`migration-report.md`'s diagnostics for the exact line and reason on any
failure, and see §"Known gotchas" below before assuming a fix requires a
structural rewrite — most unmined lines are a one-word reword.

### 5. Regenerate compile-outputs and typecheck

```bash
swift scripts/strict-compile-report.swift --root corpora/<name> \
  --vocab corpora/<name>/<name>.merconfig --rulebook corpora/<name>/<name>.merrules
```

Target `FAILURES=0`. This is the only gate that feeds generated Swift to
`swiftc -typecheck` — "migrates cleanly" and "compiles" are not the same
claim (AGENTS.md pitfall #12).

### 6. Wire into the shared scripts and regenerate committed artifacts

Add a `Corpus(...)` entry for `<name>` to all three of:

- `scripts/generate-migration.swift`
- `scripts/generate-compile-outputs.swift`
- `scripts/generate-deviations.swift`

Then run all three for `<name>` and commit the regenerated `skills/*.meri`,
`RESOLVER.meri`, `compile-outputs/`, and `migration-deviations/`:

```bash
swift scripts/generate-migration.swift --corpus <name>
swift scripts/generate-compile-outputs.swift --corpus <name>
swift scripts/generate-deviations.swift --corpus <name>
```

Check the deviations summary: target `Operational inert: 0` and
`Unclassified inert: 0`. A healthy corpus with genuinely rich narrative
should show a substantial (40%+) reference/documentation share — a
near-zero inert ratio usually means the `SKILL.md` files are still too
terse, not that the corpus is unusually "clean."

### 7. Extend the test gate and run the full suite

Add `<name>` to `Tests/CorporaTests/CorporaConformanceTests.swift`'s corpus
list (and `expectedFileCount` if it doesn't have exactly 8 skills +
`RESOLVER.meri`), then run the full gate per `AGENTS.md` §4:

```bash
swift test
MERIDIAN_GOLDEN_TYPECHECK=1 MERIDIAN_GBRAIN_TYPECHECK=1 MERIDIAN_CORPORA_TYPECHECK=1 swift test
scripts/coverage.swift --gate
```

---

### Known gotchas

These are the recurring, non-obvious failure modes hit while authoring the
`erp`/`procedures`/`incident`/`etl`/`governance` corpora. Read this section
before spending time re-diagnosing one of them from scratch. Several of these
are worked examples of general architectural patterns cataloged in
`docs/03_LANGUAGE.md` — check there before assuming a "gotcha"
marked intentional/permanent-by-design below is actually a gap to fix.

#### 0. Executable template binds belong in procedure / `— steps`, not reference

Fenced templates with `[if]` / `{{ }}` that are bound into workflow state must
live under an executable role (procedure or a migrator-generated `— steps`
sibling). Leaving them under `(( role: reference ))` drops them from IR — the
governance accessmatrix/policyaudit ports are the worked example.

#### 1. `EnglishLexicon.normativeCueWords` matching is word-level and context-blind (investigated — working as intended, do not loosen)

When writing rich, natural-sounding narrative (`## Contract`, `##
Anti-Patterns`, `## When NOT to use this skill`, cross-references to sibling
skills — see step 3 above), `EnglishLexicon.normativeCueWords`
(`must`/`never`/`always`/`refuse*`/`require*`/`forbidden`/`mandatory`) matches
**any** occurrence of those words in a line, including ordinary
conversational usage that was never meant as a real invariant.

**This was investigated for a compiler-side fix and deliberately left
unchanged.** `TrialLowering.isNormativeNarrative` (P1 category 4 in
`SkillMigrator+SplitPlan.swift`) is a context-blind whole-word match *by
design*: the moment such a line reaches strict compile, it produces
`MER1004: unparseable rule` (or, inside a checkable section,
`uncheckablePredicate`/`unresolvedPhrase`) with an explicit, actionable `help`
— e.g. "Use one of the supported rule shapes (must / must not / must be … by
… before / when / may), or set frontmatter `allow-fallbacks:
unparseable-rules` to drop it." Confirmed empirically: compiling `A classified
grant is never issued without an approval record.` produces exactly that
diagnostic, never a silent drop. Two considered alternatives were both
rejected as unsafe:

- **Loosen the cue-word match with a "does this look imperative" heuristic**
  (e.g. only flag second-person/imperative phrasing, not third-person
  declaratives). Rejected: third-person declarative *is* the normal way to
  state a real domain invariant ("a user's session must expire after 30
  minutes"), so this would silently reclassify real invariants as
  documentation — the exact failure mode `docs/09_SKILL_PORTING.md`'s P1
  four-way precedence exists to prevent.
- **Auto-lower the declarative shape** (treat `X is never Y` as sugar for `X
  must not Y`). Rejected: `is never issued without an approval record` isn't
  semantically equivalent to a simple `must not` — "without an approval
  record" here qualifies the *action*, not the subject, and the real
  intended meaning is closer to a precondition ("issuing requires an approval
  record") than an invariant. Guessing the wrong mapping and silently
  lowering it would compile a rule that asserts the wrong thing — strictly
  worse than today's loud reword error.

A narrative `## Contract` bullet like —

```
- Side effect: a classified grant is never issued without an approval
  record; a denial gets logged for the next revoke-stale-access sweep.
```

— is pure background prose to a human reader, but `SkillMigrator`'s P1
four-way classifier (`docs/09_SKILL_PORTING.md` §"The governing
principle") files any line containing a cue word as category 4
("operational, no cue"), not category 3 ("documentary"). Every *other*
bullet in the same list (no cue word) splits cleanly to `(( role: reference
))`; this one line alone surfaces as an `unmined-contract` line in the
`--route-fuzzy` report instead of joining its siblings as reference prose.

**Fix: reword the sentence to drop the cue word.** For example:

```
- Side effect: a classified grant carries an approval record from the
  security officer; a denial gets logged for the next revoke-stale-access
  sweep.
```

Never "fix" this by adding `(( role: reference ))` to a heading that already
resolves that way, and never by wrapping the line in `use judgment to …:` —
there is no genuine inference cue here, so that would misroute a
deterministic-documentation line to the planner.

A related but distinct diagnostic has the same root cause (a sentence that
structurally resembles something checkable/normative): a quoted throwaway
aside immediately followed by a dangling pronoun —

```
- Don't skip the gate for a dataset because it "always passes." The
  thresholds table exists so a genuinely broken run gets caught the one
  time it doesn't.
```

— trips the "ambiguous anaphora" check (`docs/09_SKILL_PORTING.md` item 4)
instead, because the pronoun right after the closing quote reads as an
unresolved referent. Reword to drop the quote or the pronoun:

```
- Don't skip the gate for a habitually passing dataset. The thresholds
  table exists to catch the one run that finally breaks the streak.
```

Both are reworded-prose fixes to the `original-skills/**/SKILL.md` source,
confirmed by re-running `migrate-skill --batch --report` until
`unmined-contract line(s)` reads 0. Full detail:
`docs/09_SKILL_PORTING.md` §"Common porting fixes" item 15. See
`docs/03_LANGUAGE.md` §"A blunt, context-blind classifier is
intentional when the alternative is guessing" for why loosening this match
is out of bounds in general, not just for this specific corpus.

#### 5. A Phase-8 rule only attaches if its subject kind is in the skill's `parameters:`

`RuleInjector.hasParameter` matches a rule's subject noun (`A user …`, `A
reviewer …`) against the *stemmed* kind names of the skill workflow's own
parameters — which come from frontmatter `parameters:`, nothing else. A rule
whose subject kind has no corresponding entry in `parameters:` never
attaches (`MER3006: rule did not attach`), even if the kind exists in
`<name>.merconfig` and the rule text itself parses cleanly. If you add an
in-section `## Rules` block to a skill, first check that every rule's subject
noun is one of the kinds already listed in that skill's `parameters:` line —
add it there (not just to the `.merconfig`) if it's missing.

#### 6. `When …, …` trigger rules are event-driven stubs — a self-evaluating condition is now a loud compile error, not a silent dead stub (fixed)

`When an access request has been pending for more than 7 days, escalate the
access request.` reads like a live, self-checking rule, but a `When …, …`
trigger only ever compiles to an **external-event hook**:
`RuleInjector.buildTriggerWorkflow` turns the condition into a synthesized
event name (`trigger.<camelCasedCondition>.fired`) and generates a workflow
that **waits to be told** the condition became true — it never polls,
schedules, or evaluates the condition against any data itself. This is the
right shape for a genuinely external signal (`"a refund is requested"`,
`"payment clears"`) — the host system raises the event — but it's the wrong
shape (and previously a silent trap) for a condition Meridian could in
principle check itself: a duration/age check, a magnitude comparison, a
quantifier, a relation traversal, etc. Such a condition would compile
cleanly into an event nobody ever raises, and the rule would simply never
fire — no error, no warning.

**Fixed: `RuleAnalyzer.isSelfEvaluatingTriggerCondition` now recognizes this
shape at classify-time and routes it to `MER3017` instead of a silent
`.trigger`.** Two conservative signals are checked, deliberately biased
toward false negatives (which just keep today's opaque-stub behavior) over
false positives (which would wrongly block a legitimate external-event
trigger): (1) a duration mention anywhere in the condition (`"7 days"`, `"3
hours"` — the hallmark of an elapsed-time/age check), and (2) the full
symbol-aware `ExpressionParser` recognizing the condition as a
magnitude/pattern/set comparison, quantifier, relation traversal,
description, aggregate, superlative, or table lookup. Bare equality/
inequality (`"a refund is requested"`, `"the order is not shipped"`) is
deliberately excluded — it's indistinguishable from idiomatic passive-voice
event phrasing and must keep working as an external-event hook. `When an
order has been on hold for more than 7 days, …` now raises `MER3017:
unsupported trigger condition` with a help message pointing at `wait
until …`/`assert …` (self-evaluable — express it in the skill's own
`## Workflow` instead) or a reworded opaque event phrase
(`"When an order is flagged as stale, …"`) as the two ways forward. If a
skill genuinely needs to poll/recompute a duration itself, do that in its own
`## Workflow`/`## Rules` `until`/`while` loop (e.g. `cooldown watch`'s `make
sure no alerts whose fired at is within the last 15 minutes …` guarantee,
which *is* evaluated against live data at compile-time-checkable
granularity, unlike a `When …, …` trigger). `MeridianRuntime` still has no
cron/poll-scheduler primitive — this fix makes the limitation loud and
actionable, it does not add a scheduler. See `docs/03_LANGUAGE.md`
§"A restricted sub-language rejects unsupported forms loudly instead of
approximating them" for the general architectural pattern this is one of
the two worked examples of.

`buildTriggerWorkflow` also (1) resolves `actionText` against the same
workflow/phrase lookup a real invoke uses and raises a loud
`unresolvedTriggerAction` error if it doesn't match anything (opt-out via
`allow-fallbacks: unresolved-trigger-actions`), (2) emits a real, inspectable
`wait for trigger.<event>.fired` construct — not a bare placeholder — and (3)
carries both `condition` and `action` through to the manifest for host
discoverability. A malformed rule with an empty condition or action (`When ,
escalate the request.` / `When the request is stale,.`) also has no
non-emptiness gap: `RuleLowering.classifyTrigger` returns `nil` for a blank
condition or action, routing it through the same `MER1004: unparseable rule`
path every other malformed rule shape hits (regression test:
`RuleAnalyzerCoverageTests.triggerWithBlankConditionOrActionIsNil`).

#### 7. A Phase-8 rule's filter/condition/predicate is a deliberately restricted expression grammar — no quantifiers, no data tables (permanent by design)

`RuleInjector.lowerExprSimple` (used for an `.invariant` filter, a bounded
`.permission`'s conditions, and a `.precondition`'s gate — i.e. the clause
after `whose`/`if`/the bound in `up to N …`) only accepts literals,
identifiers, property access, comparisons, `and`/`or`/`not`, env vars, `now`,
constant/instance refs, tool invocations, string interpolation, and `decide
whether`. It explicitly rejects cardinality quantifiers (`any`/`all`/`at
least N …`), relation traversals, descriptions, aggregates, superlatives, and
data-table lookups with `MER3016: rule predicate uses an expression form a
rule body cannot express` — this is a hard, permanent restriction (a rule
condition must never silently coerce to `false`, so unsupported forms raise
loudly instead). **This restriction is intentional; do not try to "fix" it.**
See `docs/03_LANGUAGE.md` §"A restricted sub-language rejects
unsupported forms loudly instead of approximating them" for the full
architectural reasoning (this is one of the two worked examples there).

This matters most for domains — clinical, ops-heavy governance — where the
natural phrasing of a guard reaches for exactly these forms: `A patient whose
active prescriptions include a contraindicated drug must not receive the new
order.` (relation traversal) or `A reviewer may approve any request whose
priority is at least 3.` (quantifier — the `any` is fine as a bare subject
determiner, but a bound like "at least 3 **of** the patient's prior doses"
is not). Keep a rule's filter to a single comparison/property-access/boolean
combination, and push anything that genuinely needs a quantifier, aggregate,
or table lookup into the skill's own `## Workflow` `if`/`assert`/`for each`
body instead — ordinary workflow statements (as opposed to in-section rule
filters) go through the full `ASTToIR` expression lowerer and support all of
these forms without restriction.

A related bug (now fixed) meant a relation-traversal clause like the patient
example above didn't even get the courtesy of the `MER3016` above: the rule
parser (`RuleAnalyzer`) used to build its `ExpressionParser` with
`symbols: nil`, so it couldn't recognize the clause as a relation
traversal/quantifier/aggregate/verb-predicate at all, and
`buildSubjectFilter`'s shorthand-comparison fallback silently guessed a
meaningless `patient.active_prescriptions_include_a_contraindicated ==
drug`-shaped predicate instead — a rule that "compiled" and looked like it
enforced something while actually checking nothing. `RuleAnalyzer` now
requires a real `SymbolTable` (every pipeline call site already had one in
scope), so the clause is recognized precisely and rejected with the correct,
named `MER3016` instead. Regression test:
`RuleAnalyzerCoverageTests.subjectFilterWithSymbolsRecognizesRelationTraversal`.
