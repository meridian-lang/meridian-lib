# Meridian — Rulebooks (`.merrules`)

A **rulebook** extends Meridian's deterministic English surface with
externally-authored, declarative rules. The compiler ships the *engine* plus a
small closed set of roles/rule-kinds; every domain-specific idiom, section
alias, and cross-cutting behaviour is **data** in a `.merrules` file. Adding a
construct for a new domain is an authoring task, not a recompile.

Rulebooks are the generalisation of the existing `=== language ===` synonym
section. They are parsed by `RulebookParser`
(`Sources/MeridianCore/Rulebook/RulebookParser.swift`) — a hand-written
recursive-descent parser in the same style as `MerConfigParser` — and applied
by `RewriteEngine` (desugars) and `ConventionInjector` (behavioural rules).

---

## The invariant that keeps the core clean

Whatever a rule produces is validated by the **same** core checks as normal
lowering: strict-mode phrase resolution, the scoped-tool allow-list, the
no-unmarked-prose rule, and the no-new-primitives rule. A rule is a
**compile-time equivalence**, never a runtime decision. It therefore can never:

- widen the tool scope,
- bypass strict mode, or
- introduce an LLM call.

Determinism holds by construction. A malformed rule fails loudly with source
attribution rather than silently degrading.

---

## Wiring a rulebook into a compile

Reference a rulebook from frontmatter with the `rulebook:` key (comma-separated,
alongside `vocabulary:`):

```
---
name: capture
vocabulary: brain.merconfig
rulebook: brain.merrules
---
```

(There is no `skill: true` flag — the section-role model activates structurally
whenever the body contains a `##`/`###` heading.)

Programmatically, rulebooks are passed as `[RulebookInput]`, analogous to
`[VocabularyInput]`:

```swift
let out = try Compiler(options: .init()).compile(
    meridianSource: meri, meridianFile: "capture.meri",
    vocabularies: [brainVocab],
    rulebooks: [RulebookInput(name: "brain", file: "brain.merrules", source: rulesSrc)]
)
```

The core's default rulebook is **empty**, so existing `.meridian`/`.meri` files
that don't list a `rulebook:` are byte-for-byte unaffected.

---

## File structure

A `.merrules` file has three section families, each introduced by a
`=== name ===` header (the same delimiter style as `.merconfig`). `#` comment
lines are ignored.

```
=== desugar ===
=== sections ===
=== conventions ===
```

---

## Family 1 — Desugar rules (`=== desugar ===`)

A desugar rule rewrites an English surface form into a canonical Meridian
statement. Each rule has a `match:` pattern with typed holes (`{name}`) and
either a `rewrite:` template (re-parsed through the normal path) or a
`lowers to:` template (the validated escape hatch).

```
rule "arrow-conditional":
  match: If {condition} -> {action}
  rewrite: {action} only when {condition}.

rule "report-emit":
  match: Report: {message}
  lowers to: emit skill.report with message = {message}.
```

- **`rewrite:` (preferred, surface-only).** The output re-parses + lowers
  through the strict pipeline, so a bad rewrite fails loudly. Use this for
  anything expressible as an existing canonical statement.
- **`lowers to:` (escape hatch).** Targets one of the 11 existing primitives
  directly via the canonical statement surface (e.g. `emit …`). This is "use an
  existing primitive directly," **not** hand-authored IR and **not** new
  semantics. Reserve it for constructs with no clean canonical equivalent.

Holes are matched by a hand-written matcher over `[SourceLine]`; captured holes
are parsed by the existing Expression/Statement parsers. The engine applies
rules ordered by priority then source order, as a bounded fixpoint (reusing the
depth-8 inline limit); conflicts are first-match-wins. Every rewrite step is
logged under the `rulebook` trace category.

Idioms the shipped `brain.merrules` covers: `If … -> …` / `If … then …` arrow
conditionals, `Report:` / `Output:` → `emit skill.report`, Markdown checklists
(`- [ ] item`, `[x] item`, `□ item`) → `make sure …` asserts, and the
command-with-annotation idiom below.

### Worked example — a desugar rule that reaches the command surface

The deterministic command surface (a fenced ` ```bash ` block or an inline
backticked command on its own line → one `shell.run` invoke) is detected by
`parseInlineChain` / `inlineBacktickedCommand` **before** the per-statement
desugar hook runs. So that a desugar rule's *output* can also become a command,
the engine applies the desugar **at the top of `parseBlock`'s loop** (before the
command/chain detectors), replacing the source line with its rewrite. A rule can
therefore normalize a surface variant into the canonical
backticked-command-with-annotation form and have it routed to the shell path:

```
rule "annotated-command":
  match: Run `{command}` to {purpose}
  rewrite: `{command}` -- {purpose}.
```

`` Run `gbrain doctor --json` to check index health. `` rewrites to
`` `gbrain doctor --json` -- check index health ``, which lowers to a single
`shell.run` invoke whose `command` is `gbrain doctor --json` and whose
`-- check index health` note is emitted as a `//` source comment above the call.

The annotation (a trailing ` -- <note>` recognized **outside** backticks — so a
`--flag` or an in-backtick ` -- ` is never split) is a parser feature of the
command surface itself; the rule above merely produces the canonical form. The
rewrite is fixpoint-stable, so the downstream per-statement desugar hook is a
no-op second pass, and the whole path is inert without a `rulebook:`.

---

## Family 2 — Section-role rules (`=== sections ===`)

A section rule maps one or more Markdown heading aliases to one of the **closed**
`SkillSectionRole` values. The roles and their lowering strategies are core; the
alias → role mapping is data.

```
section "Contract", "Guarantees", "Invariants" -> invariants
section "Phases", "Workflow", "Protocol", "Steps" -> procedure
section "When To Use", "Primary Triggers" -> applicability
section "When NOT To Use", "Do NOT Use" -> negative-applicability
section "Anti-Patterns", "Pitfalls" -> prohibitions
section "Output Format", "Result Format" -> template
```

The closed role set (exhaustive `switch`, no `default:`):

| Role | Lowers to |
|---|---|
| `invariants` | `assert` (the skill's guarantees become runtime-checked). |
| `procedure` | Executable statements (deterministic phrase invocations / idioms). |
| `applicability` | Deterministic preconditions: checkable conditions → `if <cond>, complete.` guards; literal phrases → dispatch predicates. |
| `negative-applicability` | Negative guards: checkable conditions → soft-skip `if <cond>, complete.`; literal phrases → negative dispatch predicates. |
| `prohibitions` | `must not` asserts where structurally checkable. |
| `template` | Declared result template (fenced literal + `{{ }}` interpolation). |
| `inert` | Outline / manifest metadata only — no executable lowering. |

An **unmarked** heading with no rulebook alias resolves to its built-in default
(`SkillSectionRole.builtinRole(forHeading:)`, which also recognizes the
`Phase N: …` prefix and common applicability/output variants). A heading that
resolves to nothing **and has content** is a hard `semanticError` — there is no
silent `inert` fallback. The author then adds a `=== sections ===` alias here,
forces a role inline with `(( role: <R> ))`, or marks it `(( inert ))`. Section
semantics activate **structurally** on the presence of a `##`/`###` heading;
there is no `skill: true` flag. `=== sections ===` aliases are the sanctioned,
data-only path for organizational/applicability headings — see
`sample-gbrain/brain.merrules` and `examples/skill/skill.merrules`.

### Fuzzy conditions are a hard error

An applicability / negative-applicability condition that is **neither** a literal
dispatch phrase **nor** structurally checkable (e.g. "the request is ambiguous",
"the entity is notable") raises a compile-time `semanticError`. The author must:

1. rephrase it to a checkable predicate,
2. move it to `triggers:` as a literal dispatch phrase, or
3. wrap it in an explicit `use judgment to …:` marker.

It is never silently turned into an LLM check or silently dropped.

---

## Family 3 — Conventions (`=== conventions ===`)

Conventions are Inform-style, cross-cutting behaviours declared **once** and
injected into every matching workflow by `ConventionInjector`. They use the
`before` / `after` phase verbs with an action clause and an indented body.

```
=== conventions ===

# Iron-Law back-linking: any page that mentions an entity gets a reciprocal link.
after writing a page that mentions an entity:
  create a back-link from the entity to the page.

# Notability gate before creating entity pages.
before writing a page about an entity:
  make sure the entity is notable.

# Brain-first: consult the local knowledge graph before any external call.
before calling an external service:
  check the brain first.
```

`ConventionInjector` matches a convention's action against each workflow by
token overlap (stemmed, stopword-stripped), then prepends (`before`) or appends
(`after`) the lowered body. This makes gbrain's Iron-Law / notability /
brain-first guarantees a single shared rulebook entry instead of per-skill
restatement — fewer edits, DRY, and matching gbrain's own `conventions/` design.

The convention body is parsed and lowered through the same strict pipeline as
any workflow statement, so an unresolved phrase inside a convention is a hard
error.

---

## Extending a rulebook is pure data

Adding a new idiom or section alias requires **no dispatcher edit** — only a new
rule entry:

```
=== desugar ===
rule "memo-emit":
  match: Memo: {message}
  lowers to: emit skill.report with message = {message}.

=== sections ===
section "Recipe" -> procedure
```

This is exercised directly in
[`Tests/MeridianCoreTests/SampleGbrainConformanceTests.swift`](../Tests/MeridianCoreTests/SampleGbrainConformanceTests.swift)
("a new desugar idiom + a new section alias can be added as pure rulebook
data"), which adds both as inline data and compiles a skill that uses them with
zero changes to compiler code.

---

## Tracing

Set the `rulebook` trace category to see every desugar rewrite and convention
injection with source attribution:

```bash
MERIDIAN_TRACE=rulebook meridian compile sample-gbrain/skills/ingest.meri \
    --merconfig sample-gbrain/brain.merconfig
```

See also [08_TRACING.md](08_TRACING.md).
