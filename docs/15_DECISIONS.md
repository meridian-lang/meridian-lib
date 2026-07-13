# Meridian design decisions (diagnostics & developer experience)

> Generated from `DecisionCatalog` by `meridian decisions --render docs/15_DECISIONS.md`.
> Do not edit by hand — update `Sources/MeridianCore/Diagnostics/DecisionCatalog.swift`
> and re-render. A test fails if this file drifts from the catalog.

Each decision is reachable from the errors it governs: run
`meridian explain-diag <code>` (e.g. `meridian explain-diag MER2002`) or
`meridian explain-diag <decision-id>` (e.g. `meridian explain-diag D-DX-5`).

## D-DX-1 — Unresolved phrases are hard errors by default

**Status:** accepted

An invocation that matches no phrase or workflow is almost always a typo or a missing declaration. Emitting a silent `_unresolved` placeholder hid real bugs until runtime. Strict-by-default surfaces them at compile time; the `allow-fallbacks: unresolved-phrases` escape hatch keeps early-authoring ergonomic.

**Alternatives considered:**

- Always emit an `_unresolved` placeholder (the old behaviour) — hides typos until runtime.
- Warn instead of error — warnings are routinely ignored in CI.

**Consequences:**

- Every phrase must resolve, or the file must opt into the fallback.
- The error funnels through `Diagnostic.unresolved`, so it always carries a did-you-mean or candidate list.

**See also:** MER2001, D-DX-2

## D-DX-2 — No silent compile-time fallbacks; batch-report with coarse recovery

**Status:** accepted

Silent drops (malformed headers, unparseable rules/statements, unknown config keys/sections) erased authoring mistakes. Every former silent site is now a coded diagnostic. The DiagnosticEngine collects rather than aborts, recovering at construct boundaries (workflow / rule / statement) so one compile reports many errors instead of one-at-a-time.

**Alternatives considered:**

- Abort on the first error — slow edit/compile loops; hides co-occurring errors.
- Token-level resync recovery — produces cascade/phantom errors.

**Consequences:**

- Constructs are skipped wholesale on error (cascade-resistant); phrase stubs are pre-registered so dependents still resolve.
- Structural codes carry a mandatory `help` string with the concrete fix.

**See also:** MER1001, MER1002, MER1003, MER1004, MER2011, MER3006, MER3007, MER3016, MER3017, MER1012, MER3018, MER4002, MER6004

## D-DX-3 — swift-format failure is a recoverable warning, not an error

**Status:** accepted

Formatting is cosmetic. If swift-format chokes on otherwise-valid generated Swift, keeping the unformatted output is strictly better than failing the compile. The condition is surfaced as a warning so it is visible but non-fatal.

**Alternatives considered:**

- Fail the compile when formatting fails — loses valid output over a cosmetic step.
- Swallow the failure silently — hides a real formatter/codegen interaction bug.

**Consequences:**

- `compile` always writes Swift; a formatting failure is reported as a warning.

**See also:** MER5001

## D-DX-4 — Always-on did-you-mean for every name-resolution error

**Status:** accepted

A name-resolution failure is, by definition, a mismatch against a finite candidate set, so a remediation can always be named. Every such failure funnels through `Diagnostic.unresolved(code:target:among:range:)`, which attaches a `did you mean "X"?` suggestion when within edit-distance budget, or an enumerated candidate-list note otherwise — never a bare "unknown X".

**Alternatives considered:**

- Per-site ad-hoc messages — drift and inconsistency; easy to forget the hint.
- Only suggest when very close — leaves the user stuck when nothing is close.

**Consequences:**

- A guard test enumerates all `.nameResolution` codes and asserts each yields a suggestion or candidate-list note.
- Suggestions carry `replacement` + `range`, powering `--fix` and editor quick-fixes.

**See also:** MER2003, MER2004, MER2007, MER2008

## D-DX-5 — Unknown tools are errors; Core mirrors the runtime built-in catalog

**Status:** accepted

A misspelled or undeclared tool id silently compiled to an invoke that failed only at runtime. Core cannot import MeridianTools, so `BuiltinToolCatalog` hand-mirrors the runtime's built-in ids (kept in lockstep by a guard test). Every `InvokeIR.toolID` is validated against built-ins ∪ vocabulary `=== tools ===` ∪ frontmatter `tools:` ∪ workflow references, with did-you-mean.

**Alternatives considered:**

- Trust every emitted tool id — runtime-only failures, far from the source.
- Validate only vocabulary tools — false positives on built-ins and frontmatter tools.

**Consequences:**

- Recognition mirrors the invoke path (case-insensitive against methodName; methodized built-ins).
- `allow-fallbacks: unknown-tools` downgrades per-file for host-provided tools.

**See also:** MER2002

## D-DX-6 — Phase-8 rule sugar fires everywhere executable; sectioned-document prose is opt-in via markers/comments only

**Status:** accepted

A single `!hasHeadings` gate used to suppress Phase-8 rule extraction (`must not` / `may` [+ bounded `up to N`] / `must be … by … before` / `When …, …`) in any file with `##`/`###` headings, silently downgrading rule-shaped sentences in SKILL.md-style documents to inert prose with no diagnostic. This reversed a real authoring intent: a governance/clinical skill body that reads `A user without clearance must not access classified resources.` is a rule the author expects enforced, not documentation. Rule extraction now runs identically in flat and sectioned documents; each non-comment line in an executable section is classified in a fixed precedence — guidance-step prose, then `RuleAnalyzer.classify`-positive rule shapes (extracted to `MeridianFile.rules`), then ordinary statements — so prose is never inferred from content, only from an explicit `(( role: reference ))`/`(( inert ))` marker or a `#`/`>` comment line.

**Alternatives considered:**

- Keep sectioned documents rule-inert and require authors to move obligations into a flat `rules/*.meridian` file — forces an artificial split between a skill's narrative and its enforced contracts, and is exactly the workaround `corpora/governance`/`corpora/clinical` no longer need.
- Infer prose vs. rule from section role alone (e.g. treat every `invariants` section line as a rule) — too coarse; a section can mix a rule-shaped sentence with an ordinary guard statement, and role-based inference would silently misclassify one or the other.

**Consequences:**

- A rule-shaped sentence with no matching implicit-workflow parameter/action now raises `unattachedRule` at compile time instead of compiling silently as inert narrative — treated as an authoring signal (fix the skill's frontmatter `parameters:` or the rule wording), not a regression.
- `SkillMigrator`'s four-way classifier treats rule-shaped normative lines as lowerable (category 1) rather than routing them to `(( role: reference ))` or a hard error, so migrated `SKILL.md` sources gain real enforcement instead of documentation-only narrative.
- gbrain/erp/procedures ported `.meri` sources with `When …,`/`may`/`must not` narrative that was never meant to be a rule must be explicitly re-marked `(( role: reference ))`/`(( inert ))` or commented (`#`/`>`) — a one-time, mechanical repair pass across the existing corpora, not an ongoing cost.

**See also:** MER3006, MER1010, MER1009, MER3016

## D-DX-7 — Lint and migration-report findings are DiagnosticCode-native, not ad hoc strings

**Status:** accepted

`MeridianLinter` and `SkillMigrator.Report` used to return free-form warning strings, so authors saw a different vocabulary and no `explain-diag` path depending on which tool caught the issue. `MeridianLinter` now returns `[Diagnostic]` (polite-command and uncertainty-wording lints), and `SkillMigrator`'s `--route-fuzzy` downgrade is a `Diagnostic` too, so every finding from every DX tool shares one rendering, one JSON schema, and one `meridian explain-diag <code>` lookup path.

**Alternatives considered:**

- Keep lint/migration findings as tool-specific string types — cheap short-term, but forks the diagnostics UX and blocks a shared `--json`/IDE-integration surface.
- Fold lint findings into the compiler's own diagnostic stream unconditionally — conflates optional style advice with hard compile errors.

**Consequences:**

- Lint findings are warnings, not hard errors, but travel through the exact same `Diagnostic` type as MER1xxx–MER4xxx.
- A batch `migrate-skill --route-fuzzy` run is auditable via the same diagnostic list as a normal compile, instead of a separate log format.

**See also:** MER6001, MER6002, MER6003

## D-DX-8 — Trace-file and lexicon-marker failures degrade visibly, never silently

**Status:** accepted

Two failure modes used to fail quietly: a bad `--trace-file` path would drop trace output with no indication, and an empty required lexicon marker collection would produce blank/malformed canonical output with no diagnostic. Both are now coded: an unwritable trace file falls back to stderr with a visible MER5011 notice instead of losing the trace, and an empty marker collection raises MER5012 instead of emitting degenerate output.

**Alternatives considered:**

- Drop trace output silently on an unwritable path — defeats the purpose of asking for a trace file in the first place.
- Crash outright on an empty lexicon marker collection — loses the batch-report/coarse-recovery behavior the rest of the pipeline relies on (D-DX-2).

**Consequences:**

- `--trace-file` failures are recoverable: the run still completes, with the trace redirected to stderr and a MER5011 notice explaining why.
- A domain that overrides `EnglishLexicon` markers without providing at least one entry per required category gets a compile-time MER5012 instead of a silently broken canonical form.

**See also:** MER5011, MER5012

## D3 — Deontic violation timing and conflict lattice

**Status:** accepted

Prohibitions are attempt-time: the executable projection inserts a guard before the matching invoke, and a blocked attempt emits `violated` with disposition `prevented` without running the tool. State obligations are effect-time: checked at commit points and section exits, with `violated (observed)` routed through recover on failure. Both dispositions are trace events so prevented violations stay auditable. Same-scope prohibition/permission overlap is a compile-time conflict; nested scopes use sticky deny so an inner permission cannot override an outer prohibition.

**Alternatives considered:**

- Let prohibition silently win over permission at runtime — hides authoring mistakes and makes audit replay ambiguous.
- Treat obligations as attempt-time like prohibitions — rejects effect-time invariants that only make sense after state commits.
- Allow inner permissions to override outer prohibitions — breaks the deny-sticky-downward lattice.

**Consequences:**

- MER-DEO-001..006 surface lattice and modal violations at compile time instead of picking a silent winner.
- Prevented prohibition attempts still appear in the trace — the deontic layer is defensive and auditable.

**See also:** MER-DEO-001, MER-DEO-002, MER-DEO-003, MER-DEO-004, MER-DEO-005, MER-DEO-006, MER-DEO-007
