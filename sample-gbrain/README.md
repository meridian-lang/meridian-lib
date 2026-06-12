# sample-gbrain

A complete, self-contained port of the [`garrytan/gbrain`](https://github.com/garrytan/gbrain)
skill corpus to Meridian's controlled natural language. Every original
`SKILL.md` is rewritten as a strict-compiling `.meri` file that lowers to a
deterministic IR — no implicit LLM calls, no fuzzy fallbacks — against one
shared vocabulary and one shared rulebook.

This folder is the canonical demonstration that an entire real-world skill
library can be expressed in Meridian with near-verbatim edits (average source
similarity **87%**), while gaining a compiler that rejects ambiguity instead of
guessing.

`brain.merconfig` also ships **checkable adjective definitions** (Wave 2) — e.g.
*"a page is unwritten if it has no body"*, *"a job is broken if its state is
failed"* — that skill bodies use in subject position (`if the page is
unwritten`), in quantified descriptions (`if any unwritten pages`), and in
boolean compositions (`if any urgent pages or any unwritten pages`). Five skills
(`maintain`, `briefing`, `publish`, `reports`, `query`) carry executable guards
built from these surfaces, each lowering to deterministic Swift with no LLM call.

---

## Layout

```
sample-gbrain/
├── brain.merconfig          ← shared vocabulary (kinds, enums, constants, tools, phrases)
├── brain.merrules           ← shared rulebook (desugar idioms, section roles, conventions)
├── RESOLVER.meri            ← the trigger → skill dispatcher
├── skills/                  ← 52 ported skills (*.meri)
├── original-skills/         ← verbatim copy of the upstream gbrain skills tree
├── migration-deviations/    ← per-skill diff vs. the original SKILL.md (+ index)
├── compile-outputs/         ← generated Swift for every skill (53 *.swift)
└── Tests/                   ← the SampleGbrainTests SPM target (lives with the corpus)
```

| Folder | Count | What it is |
|---|---|---|
| `skills/` | 52 | Ported skills, one `.meri` each. |
| `compile-outputs/` | 53 | Generated Swift (52 skills + `RESOLVER`). |
| `original-skills/` | 54 dirs | The upstream tree, unmodified, for side-by-side reference. |
| `migration-deviations/` | 53 reports | Audit of every change made during porting. |

> The two extra `original-skills/` directories — `conventions/` and
> `migrations/` — are **not** skills (they have no `SKILL.md`; they're reference
> docs and version changelogs), so they have no `.meri` or deviation report.
> The `conventions/` guidance informed `brain.merrules`.

---

## The two shared artifacts

A gbrain `SKILL.md` becomes a compiling `.meri` by adding frontmatter that
points at these two files — nothing else is required per-skill.

### `brain.merconfig` — vocabulary

The single always-required dependency. It declares:

- **Domain** — the brain knowledge-graph kinds (`page`, `entity`, `concept`,
  `idea`, …) and operational kinds (`job`, `brain`, …), plus enumerations
  (`JobState`, `PagePriority`, `QueryMode`, …). Each kind maps to a generated
  Swift type under the skill's namespace.
- **Constants** — recurring literals shared across skills.
- **Tools** — 18 tool declarations, grouped into families (page/knowledge-graph,
  link, timeline, jobs, …), that the natural-language phrases resolve against.
- **Phrase library** — 12 `To …:` definitions that wrap those tools so skill
  bodies read as plain English (e.g. *"capture the thought"*) while lowering to
  deterministic `runtime.invoke(...)` calls.

Literal shell commands inside skills (fenced ` ```bash ` blocks and inline
backticked `` `gbrain …` `` commands) need **no** declaration — they lower to
the built-in `shell.run` subprocess tool.

### `brain.merrules` — rulebook

Pure data that extends the surface without touching compiler code. Three
sections:

- `=== desugar ===` — text→text idioms applied before parsing (e.g. arrow
  conditionals).
- `=== sections ===` — maps markdown heading aliases to semantic
  `SkillSectionRole`s (e.g. `Contract` → invariants/asserts, `When To Use` →
  applicability precondition, `Phases`/`Protocol` → procedure).
- `=== conventions ===` — Inform-style rules injected into matching workflows.

See [`docs/11_RULEBOOKS.md`](../docs/11_RULEBOOKS.md) for the authoring guide.

---

## How a skill is structured

Each `.meri` is a `SKILL.md` with a Meridian frontmatter block prepended:

```
---
vocabulary: brain.merconfig
rulebook: brain.merrules
name: <skill name>
description: <one-paragraph summary>
triggers:
  - "natural language trigger phrase"
---

# Title

## Contract (( inert, role: invariants ))   ← prose guarantees, recorded inert
## When To Use         ← applicability → precondition guard / dispatch phrases
## Phases / Protocol   ← procedure → deterministic steps
## Anti-Patterns (( inert, role: prohibitions ))   ← prose, recorded inert
## How to use          ← pure-shell → shell.run invokes
...
```

There is **no `skill: true` flag** — the section-role model activates
structurally on the `##`/`###` headings. Descriptive sections become
deterministic guards; any genuinely fuzzy condition is a **hard compile error**,
not a silent LLM call. A heading carries a trailing `(( … ))` marker when it is
documentation: `(( inert ))` (narrative), `(( inert, role: invariants ))` /
`(( inert, role: prohibitions ))` (prose Contract/Anti-Patterns, label kept), or
`(( role: <R> ))` (force a role). Markers are authoritative and override even
shell-block routing. Every section — executable or not — is recorded into the
manifest's `meridian_skill.sections`, so nothing is silently dropped. Steps that
legitimately need judgment must be marked explicitly (`use judgment to …:`),
which lowers to a `ProseStepIR`.

`RESOLVER.meri` is the dispatcher: it routes an inbound request to the skill
that owns it (skills are the implementation; the resolver only selects).

---

## Building & compiling

Compile any skill from the repo root (vocabulary and rulebook are
auto-discovered beside the source):

```bash
swift run meridian compile sample-gbrain/skills/academic_verify.meri --output /tmp/out
```

By default the CLI wraps each file's generated declarations in
`public enum <SkillName> { … }` (PascalCase of the file stem). This namespacing
lets every skill's Swift coexist in one module without the per-file domain
types (`Job`, `Brain`, `Constants`, …) colliding. Disable with
`--namespace none`, or set an explicit name with `--namespace Foo`.

The pre-generated, swift-format-formatted output for all 53 files lives in
[`compile-outputs/`](compile-outputs/).

---

## Tests

The corpus is tested by the **`SampleGbrainTests`** SPM target, which lives
here (under `Tests/`) so the skillpack is fully self-contained. Run:

```bash
swift test --filter SampleGbrain
```

Suites:

- **smoke** — the shared vocabulary and rulebook parse; a minimal skill body
  compiles.
- **conformance** — every ported skill compiles deterministically with no
  `_unresolved` placeholders; rulebook extensibility is pure data; the
  `SkillMigrator` round-trips.
- **codegen validity** —
  - *(always on)* an in-process string-literal lexer asserts no single-line
    Swift `"…"` literal contains a raw newline (catches the bug class where a
    multi-line metadata value would otherwise emit invalid Swift);
  - *(opt-in, `MERIDIAN_GBRAIN_TYPECHECK=1`)* every emitted file is run through
    `swiftc -typecheck` against `MeridianRuntime`, validating the namespaced
    shipped form:

    ```bash
    MERIDIAN_GBRAIN_TYPECHECK=1 swift test --filter SampleGbrainCodegenTests
    ```

All 53 emitted skills type-check against `MeridianRuntime`.

---

## Auditing the migration

[`migration-deviations/README.md`](migration-deviations/README.md) is the
index: per-skill tier, source similarity, line delta, frontmatter keys added,
and a unified diff against the original `SKILL.md`. Regenerate with:

```bash
# ported dir is the corpus root so RESOLVER.meri (top-level) is paired too
swift run meridian skill-deviation original-skills/ . \
  --batch --out migration-deviations/ --index
```

Current corpus: tier 1 (near-verbatim) **42**, tier 2 (light edits) **10**,
tier 3 (structural rewrite) **1** (`RESOLVER`, a dispatcher doc rewritten as a
workflow). The dominant change across the corpus is `section-marker-added` —
i.e. porting mostly appends `(( … ))` markers to non-executable headings and
leaves the body intact; only `RESOLVER` adds frontmatter.
