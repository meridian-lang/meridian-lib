# AGENTS.md — Meridian AI Contributor Handbook

This file is the always-on, curated handbook for any AI agent working on this
codebase: project orientation, development norms, the phase-gate rule, and the
cross-cutting pitfalls. Keep it lean and accurate.

**Context budget:** this file is injected into *every* conversation. Do not let
it grow into a changelog. Two homes for change history exist instead:

- **`IMPLEMENTATION_LOG.md`** — the append-only decision log (UTC-timestamped).
  Every assumption, decision, fix, or blocker goes here. Never delete entries.
- **`.cursor/rules/*.mdc`** — area-scoped reference (codegen, runtime, compiler
  internals, tracing, testing). These auto-attach only when you edit matching
  files, so deep detail stays out of the always-on budget.

**Self-update rule:** After a substantive session, append to
`IMPLEMENTATION_LOG.md`. Update *this* file only when a **norm or pitfall**
changes; update the relevant `.cursor/rules/*.mdc` when an **area convention**
changes. Do not add per-session changelog entries here.

---

## Table of contents

1. [Project overview](#1-project-overview)
2. [Repository layout](#2-repository-layout)
3. [Development norms](#3-development-norms)
4. [Phase-gate rule](#4-phase-gate-rule)
5. [Area-scoped reference rules](#5-area-scoped-reference-rules)
6. [Known sharp edges and pitfalls](#6-known-sharp-edges-and-pitfalls)
7. [Decision history](#7-decision-history)

---

## 1. Project overview

Meridian is a **controlled natural language compiler**. It converts `.meridian`
workflow files (plus `.merconfig` vocabulary files) into async/await Swift
source that runs against `MeridianRuntime`.

The compiler pipeline is:

```
.merconfig source
    → MerConfigParser → MerConfigFile
    → SymbolTable.build(from:)
.meridian source
    → MeridianParser(symbols:) → MeridianFile
    → ASTToIR(symbols:) → [IRWorkflow]
    → SwiftEmitter → String (Swift source)
    → swift-format → formatted Swift
```

The entire pipeline is exposed as a single call:

```swift
let out = try Compiler(options: opts).compile(
    meridianSource: mer,
    meridianFile: "order_processing.meridian",
    merconfigSource: cfg,
    merconfigFile: "ecommerce.merconfig"
)
```

---

## 2. Repository layout

- `Sources/MeridianRuntime/` — runtime used by generated Swift (`Runtime/`
  actor, `Value/`, `State/`, `Comparison/`, `Protocol/`, `Domain/`).
- `Sources/MeridianCore/` — the compiler: `Compiler.swift` (entry point),
  `AST/`, `IR/IRTypes.swift` (12 IR primitives), `Parser/` (`Lexical/`,
  `Productions/`), `Symbols/`, `Lowering/ASTToIR.swift`, `Codegen/`
  (`SwiftEmitter.swift`, `ManifestEmitter.swift`, `DomainEmitter`),
  `Diagnostics/` (`ParserTrace.swift`, diagnostic engine), `Language/`
  (`EnglishLexicon.swift`, `FixedGrammar.swift`), `Rulebook/`, `Skill/`,
  `Migration/` (`SkillMigrator`, `SkillDeviation`, `Difflib`).
- `Sources/MeridianCLI/` — thin `@main` shell. `Sources/MeridianCLIKit/` —
  testable command library (`Commands/`, one file per subcommand).
- `Sources/MeridianTools/` — built-in tools. `Sources/MeridianTestKit/` — test
  helpers. `Sources/SampleDemoFlows/` — hand-written reference flows.
- `Tests/MeridianCoreTests/`, `Tests/MeridianRuntimeTests/`,
  `sample-gbrain/Tests/` — test targets.
- `examples/` — `.merconfig` / `.meridian` samples + `golden/`.
- `docs/` — numbered docs (`01_OVERVIEW` … `15_DECISIONS`, `coverage/`).
- `meridian-handoff/docs/` — **read-only** original spec (blueprint, language,
  IR, codegen, runtime API, build plan, decisions).
- `IMPLEMENTATION_LOG.md` — append-only decision log.

### CLI commands

`meridian <subcommand>` (see [`docs/07_CLI.md`](docs/07_CLI.md) for full flags):

| Command | Purpose |
|---|---|
| `compile` | `.meridian`/`.meri` → Swift + `.meridian.manifest.json`. Repeatable `--rulebook`; `--namespace auto\|none`; writes the COMPLETE manifest via `compileWithManifest`. |
| `run` | Compile then execute the generated workflow through a temp SwiftPM package. |
| `check` | Parse + lower only; report diagnostics (no codegen). |
| `verify` | Verify generated output / round-trip. |
| `resume` | Resume a run from the latest `FilesystemCheckpointer` snapshot. |
| `test` | Run `.meridian.test` spec fixtures. |
| `format` | `swift-format` the generated Swift. |
| `docs` | Emit documentation. |
| `lint` | Run `MeridianLinter`. |
| `trace render` | Pretty-print runtime JSONL event streams with `TraceTreeRenderer`; compile-time parser tracing uses `--trace` / `MERIDIAN_TRACE`. |
| `preview-skill` | Preview a `SKILL.md` via `SkillMarkdownImporter`. |
| `migrate-skill` | Convert a `SKILL.md` → strict `.meri` (deterministic marking pass + `=== sections ===` alias emission appended to the rulebook, then strict-compile). `--batch` for a directory. See `docs/07_CLI.md` / `docs/13_SKILL_MD_PORTING.md`. |
| `skill-deviation` | Audit a ported `.meri` vs its original `SKILL.md` (frontmatter delta, tier, similarity, categories, `difflib` unified diff). `--batch --index` regenerates `sample-gbrain/migration-deviations/`. |

`migrate-skill` and `skill-deviation` are backed by `SkillMigrator` /
`SkillDeviation` + `DiffMatcher` in `Sources/MeridianCore/Migration/` (single
source of truth; the migration corpus is reproducible with no external scripts).

---

## 3. Development norms

### Files

- **No file headers.** No `//  FileName.swift`, no `// Created by…` comments.
- **No obvious comments.** Comments only explain non-obvious intent, trade-offs,
  or constraints.
- **Append-only log.** Every assumption, decision, or blocker goes in
  `IMPLEMENTATION_LOG.md` with a UTC timestamp. Never delete entries.

### Coding style

- Swift 5.10+. Strict concurrency (`Sendable`, `actor`, `async/await`).
- Prefer `struct` over `class`. Only use `actor` for mutable shared state.
- `public` only on types and members that are part of a module's public API.
- No force-unwrap (`!`) in production code.
- Prefer `guard let` / `guard else` for early exits over nested `if let`.

### No hardcoded English-surface vocabulary (load-bearing rule)

**Never hardcode an English-surface word/keyword/phrase list inside parser,
lowering, or codegen code.** Any set of surface tokens the grammar keys on —
articles, prepositions, copulas, comparison markers, duration units, assertion
introducers (`make sure`/`ensure`/`assert`), quantifier determiners, connector
words, stop-words, etc. — belongs in `EnglishLexicon`
(`Sources/MeridianCore/Language/EnglishLexicon.swift`), which is the single,
domain-overridable source of surface vocabulary. The rulebook / `.merconfig`
`=== language ===` section is the generalisation of this: it lets a domain
*extend* the lexicon without recompiling Meridian.

Concretely, when you reach for a literal like `["make sure ", "ensure "]` or
`if lower.hasPrefix("every ")` in a `Parser/` or `Lowering/` file, **stop** and
instead:

1. Add (or reuse) a field on `EnglishLexicon` (e.g. `assertionMarkers`), with a
   sensible default in `.default`.
2. Thread it through `EnglishLexicon.init` and `merging(...)`.
3. If it should be author-extensible, add a matching `LanguageSynonyms` field,
   parse it in `MerConfigParser.parseLanguageSection` (a new `=== language ===`
   sub-block), concatenate it in `MerConfigFile.merging`, and forward it from
   both `Compiler.compile` overloads into `lexicon.merging(...)`.
4. Read it via the threaded `lexicon` parameter at the call site.

**Where the line is.** Two categories, two rules:

- **Extensible vocabulary** — articles, prepositions, copulas, comparison
  markers, duration units, assertion introducers, stop-words, and any
  domain-synonymisable term. These MUST live in `EnglishLexicon` and SHOULD be
  author-extensible via `=== language ===`. A literal list of these in a
  `Parser/`/`Lowering/`/`Codegen/` file is a bug. Reference examples:
  `assertionMarkers` + `Assertion synonyms:` and
  `EnglishLexicon.stripLeadingArticle` (the canonical article stripper — never
  re-list `["the ", "a ", "an "]` inline; call the helper).
- **Fixed control-flow syntax** — the structural skeleton of the grammar:
  `if`/`while`/`until`/`for each`/`otherwise`/`unless`, the quantifier
  determiners (`every`/`all`/`any`/`some`/`no`) that map 1:1 to
  `QuantifierKindAST`, block headers, and the `let … be …` / `do … and …`
  shapes. These define *what the language is*, not *what a domain calls things*,
  so they may remain literals — but keep each construct's trigger words in ONE
  place (its parse production), commented, never copy-pasted across files. If a
  domain ever needs to rename one, promote it to the lexicon at that point.
  Centralized-but-fixed grammar lives in `FixedGrammar.swift`
  (`EnglishLexicon.grammar`).

Other narrow exceptions (justify in a comment): non-natural-language structural
sentinels (e.g. the `\u{E000}` code-block / shell markers), Swift-keyword output
in the emitter, and section-marker syntax (`(( … ))`). When in doubt, it goes in
the lexicon.

### Dependencies

- `modelhike` (local, `../modelhike`) — `StringTemplate` for codegen.
- `pegex` (local, `../pegex`) — `PegexBuilder` grammar DSL.
- Do not add new remote dependencies without explicit user approval.

### Spec documents

`meridian-handoff/docs/` is read-only. The formal grammar, IR spec, and
codegen spec live there. When the implementation diverges from the spec,
document the divergence in `IMPLEMENTATION_LOG.md`.

---

## 4. Phase-gate rule

**Do not start the next phase until the current one is signed off.**

After completing a phase:

1. Run `swift test` — all tests must pass.
2. Run the CLI forcing function (compile → build → run → diff).
3. Assign a confidence percentage.
4. Record it in `IMPLEMENTATION_LOG.md` under `### Phase N confidence audit`.
5. Ask the user to sign off before proceeding.

After any major implementation session (even outside a formal phase), run the
full local gate unless the user explicitly narrows validation:

```bash
swift test
MERIDIAN_GOLDEN_TYPECHECK=1 MERIDIAN_GBRAIN_TYPECHECK=1 swift test
scripts/coverage.swift --gate
```

If the change affects generated Swift, codegen, domain emission, migration, or
the gbrain corpus, do not skip the typecheck env vars; they are the only gates
that feed generated output to `swiftc`.
Do not skip the coverage gate for substantive production changes; it enforces
the per-file coverage floors documented under `docs/coverage/`.
If a change affects generated artifacts, regenerate and include the matching
outputs in the change set (goldens, `sample-gbrain/compile-outputs/`,
`sample-gbrain/migration-deviations/`, coverage baselines/floors) instead of
leaving stale snapshots.
If any gate cannot be run, say exactly why and record the residual risk in the
final response and `IMPLEMENTATION_LOG.md`.

The user has explicitly stated: *"once impl for a phase is done, don't
automatically start the next phase. First, check if the impl is
comprehensive, give a confidence %. Get to near 100% confidence before
proceeding to the next phase."*

---

## 5. Area-scoped reference rules

Deep per-area conventions live in `.cursor/rules/*.mdc` (kept out of the
always-on budget). Each carries both a `description` and `globs`, so it
**auto-attaches when a matching file is in context** *and* can be pulled in by
relevance from its description.

**Always-on directive (do not skip):** before substantive work in any area below
— including cross-cutting changes, and even if the rule did not auto-attach —
open and read the matching `.cursor/rules/*.mdc` file first. This guarantees the
guidance is applied regardless of how rule-matching resolves. When an area
convention changes, update its rule file, not this handbook.

| Rule file | Covers | Attaches when editing |
|---|---|---|
| `compiler-internals.mdc` | `matchPhrase`/lowering/parsing invariants + the 12 IR primitives & `IRExpression` cases | `Sources/MeridianCore/{Parser,Lowering,Symbols,IR}/**` |
| `codegen.mdc` | `SwiftEmitter` escaping, namespacing, `emitValueExpr`, comparison emission, struct conventions | `Sources/MeridianCore/Codegen/**` |
| `runtime.mdc` | `Value` enum, `State.get` keys, `Runtime.init`, `Observer`/`Event` naming, sync helpers | `Sources/MeridianRuntime/**` |
| `tracing.mdc` | `ParserTrace` categories, `MERIDIAN_TRACE`, thread safety, the `trace` parameter convention | `Sources/MeridianCore/Diagnostics/**` |
| `testing.mdc` | Running tests, the per-file coverage gate, forcing functions, golden/trace test patterns | `Tests/**`, `scripts/coverage.swift` |

All five files are read directly from `.cursor/rules/` whenever you need them —
do not wait for auto-attach.

---

## 6. Known sharp edges and pitfalls

### 1. `findArticle` must pick the earliest article

Phrase-pattern parsing must use `EnglishLexicon.findEarliestArticle(_:)`, which
finds the **earliest** parameter article (`a`/`an`) by position, not by iteration order. An earlier bug
picked the last, causing `state.get("l amount")` from `"total amount"`. Do
not revert this to iteration order.

### 2. Do not prefix identifiers with "the " in `exprToText`

`ASTToIR.exprToText` must not add `"the "` prefix to bare identifier names.
This was tried and reverted. It produces `state.get("the order.id")` which
breaks at runtime.

### 3. Possessive recognition without an article

`ExpressionParser.parseAtom` must detect possessives (`X's Y`) even without
a leading `the/a/an`. After argument substitution removes the article, bare
possessives like `"order's id"` must still be parsed as property access, not
as an identifier.

### 4. Quote-aware splitting

`ExpressionParser.rangeOfMarkerOutsideQuotes` prevents comparison markers
(` is `, ` equals `, etc.) from matching inside double-quoted strings.
`StatementParser.splitArgs` also respects double-quotes. Do not use
single-quote as a string boundary — apostrophes in possessives (`customer's`)
would be misinterpreted.

### 5. Argument substitution order

In `ASTToIR.substituteArgs`, always sort arguments by **descending key
length** before substituting. Shorter keys would otherwise clobber the start
of longer keys (e.g. `"amount"` clobbers `"total amount"`).

### 6. Workflow call argument order

`lowerPhraseInvocation` for workflow stubs orders arguments by iterating
`phrase.pattern.parameters` (the declared order), not the dictionary. The
generated struct's `init` parameters appear in pattern-declaration order.
Passing them in a different order causes Swift compiler argument-label errors.

### 7. `collectMultiLineCounted` vs `collectMultiLine`

Always use `collectMultiLineCounted` when iterating with an explicit `i` index.
The non-counted variant was left for backward compatibility only. Using it in
a new loop will cause continuation lines to be re-processed as top-level
statements (resulting in spurious `_unresolved` binds).

### 8. `statementParser.splitArgs` and single quotes

Single-quote (`'`) must NOT be used as a string delimiter in `splitArgs`.
Possessives like `"customer's email"` contain single quotes; treating them
as string boundaries splits arguments at possessives. Double-quote only.

### 9. `Sendable` Constants struct

`Constants` must be declared `public struct Constants: Sendable`. The
`Sendable` conformance is required because `Constants` is used from async
`run()` methods. Omitting it causes Swift concurrency warnings or errors.

### 10. `StringTemplate.toString(separator:)` and `flatten()`

These two methods were added to `modelhike`'s `StringTemplate` by the user.
They are used in `SwiftEmitter.emitFile`. If `modelhike` is updated or
replaced, ensure these methods exist. Their implementations:

```swift
public func toString(separator: String) -> String {
    flatten().joined(separator: separator)
}

public func flatten() -> [String] {
    items.flatMap { item -> [String] in
        if let nested = item as? StringTemplate { return nested.flatten() }
        return [item.toString()]
    }
}
```

### 11. `StringConvertibleBuilder` must be `public typealias`

`modelhike/Sources/_Common_/Extensions/StringConvertible.swift` must declare
`public typealias StringConvertibleBuilder = ResultBuilder<StringConvertible>`.
Without `public`, the result-builder attribute is unavailable across module
boundaries. This was a manual user fix; do not revert.

### 12. "Compiles" means Meridian emitted Swift *source* — not that it `swiftc`s

`Compiler.compile(...)` and `SkillMigrator.compiledOK` only assert the pipeline
produced Swift text without throwing; the result is **never** fed to a Swift
parser there. So invalid Swift (unescaped strings, hyphenated identifiers,
duplicate decls) can pass every compile/conformance test and only blow up later
in swift-format or `swiftc`. When emitting anything new, assume the output will
be type-checked. The `swiftc -typecheck` gates (`MERIDIAN_GOLDEN_TYPECHECK=1`
for the corpus goldens; `MERIDIAN_GBRAIN_TYPECHECK=1` for `SampleGbrainTests`)
are the only real Swift validators — run them after emitter changes.

### 13. Generated identifiers must be sanitized

Struct names come from natural-language text via `EnglishLexicon.structName`,
which splits on any non-identifier char and `_`-prefixes a leading digit — so a
hyphenated name (`webhook-transforms`) yields `WebhookTransforms`, never
`struct Webhook-transforms` (a syntax error that also mints a phantom
redeclaration of a same-stem domain kind). Distinct trigger phrases that
collapse to one struct name are disambiguated with a numeric suffix via
`IRWorkflow.explicitStructName`. `DomainEmitter` drops an explicit merconfig
`id` property because the `MeridianKind` identity `id` is synthesised
unconditionally (otherwise: duplicate `id`).

### 14. A `role` section's body must be exclusively executable — split, don't comment

A section with an executable role (`(( role: procedure ))`, `(( role: invariants ))`,
…) makes **every** non-blank, non-comment line a live statement that must lower.
So you cannot flip an `(( inert ))` documentation heading to a role and keep its
narrative paragraph — that prose errors as an unresolved phrase. The **correct**
fix is a structural split: keep the narrative in its `(( inert ))` section
(verbatim, uncommented — it stays real documentation) and add a **separate**
sibling/child heading whose body is **only** executable statements. A `###` child
re-resolves its own role under an inert `##` parent; for sections already at
`###`, add a sibling `###`. The gbrain back-linking conversions
(`briefing` `### Enforce back-links`, `maintain` `### Repair missing back-links` /
`### Create missing cross-references`) follow this shape.

**ANTI-PATTERN — do NOT blockquote the prose to silence the error.** Prefixing the
narrative with `>` (so `IndentTokenizer` treats it as a comment) is lossy: a
blockquoted line is *dropped from the IR* — no longer enforced, asserted, or
executed. That hides a real requirement behind a comment and is the one place the
"no silent drops" guarantee (§6 / `SkillSectionBuilder` strictness) can't protect
you, because the drop is author-chosen via `>` rather than compiler-rejected. Full
guidance: `docs/13_SKILL_MD_PORTING.md` §"Common porting fixes" item 7.

### 15. Narrative encodes executable contracts — mine it before marking inert

The most-missed porting step (and the deeper lesson behind §14): SKILL.md prose
rarely *only* describes — it usually states **conditions on execution** the
language can lower. A sentence like "every entity the page mentions must have a
back-link" reads like documentation but is a **post-condition** (`assert …` /
`make sure …`, and/or a guarded loop that establishes it). "before X, Y must
hold" is a **precondition** (`wait until …` / a leading guard). "if X, the rule
applies" is an **applicability guard** (a branch). A qualifier like "fix the
*missing* one" makes an action **conditional**, not unconditional (the
back-linking loop is `if the entity does not link …`, never a bare `add`).

**Before marking any normative sentence `(( inert ))`, classify it: post-
condition, precondition, invariant, or guard? If it's any of those, lower it.**
`(( inert ))` is only for genuinely non-executable material — rationale,
examples, external references, formatting templates. `assert`/`ensure`/`make
sure` are aliases (extensible via `=== language ===` `Assertion synonyms:`); pick
the one closest to the source wording. Full guidance + the contract-shape table:
`docs/13_SKILL_MD_PORTING.md` §"Common porting fixes" item 8.

### 16. `(( role: procedure ))` is redundant on a recognized procedure heading

`procedure` is the **implicit** role for any heading whose text normalizes to a
recognized procedure synonym — `Phases`, `Workflow`, `Pipeline`, `Protocol`,
`Steps`, `Process`, `Procedure`, or a `Phase N:` prefix
(`SkillSectionRole.builtinRole`, `Sources/MeridianCore/Rulebook/Rulebook.swift`).
On such a heading, writing `(( role: procedure ))` is noise — during migration,
**name the executable section with one of those words and add no marker.**

It is **not** a blanket default. A content-bearing heading whose text is *not* a
recognized role (e.g. `### Enforce back-links`) is a **hard `semanticError`** —
"unrecognized section heading … has content but no role" — never a silent
fall-through to procedure (the no-silent-drops guarantee). So: never *add* the
marker to a `Protocol`/`Steps`/`Phase N:` heading; never *strip* it from a custom
heading unless you also rename the heading to a recognized synonym (or add a
`=== sections ===` rulebook alias). The gbrain back-link sections use custom
headings (`### Enforce back-links`, `### Repair missing back-links`), so their
`(( role: procedure ))` markers are load-bearing and must not be removed as-is.
Full guidance: `docs/13_SKILL_MD_PORTING.md` (edit-budget callout after item 4).

---

## 7. Decision history

The full, chronological decision log lives in **`IMPLEMENTATION_LOG.md`**
(append-only, UTC-timestamped). Read it on demand when you need the rationale or
history behind a pattern — do **not** mirror it back into this file.

Useful pointers:

- Architectural decision numbering (`D1`–`D30`):
  `meridian-handoff/docs/11_DECISIONS.md`.
- Generated decision catalog (`D-DX-*`) + diagnostic codes:
  `docs/15_DECISIONS.md`, or `meridian explain <code|decision>`.
- SKILL.md expressiveness tags (`SkillMD-D1`…`SkillMD-D28`):
  `.ai/brainstorm-done/skill_md_expressiveness_d1_d28.md`. Any bare `D<N>`
  outside `meridian-handoff/docs/11_DECISIONS.md` means `SkillMD-D<N>`.

When you record a new decision in `IMPLEMENTATION_LOG.md` and it changes an
ongoing norm or pitfall, reflect *only* that norm/pitfall here (§3/§6) or in the
relevant `.cursor/rules/*.mdc` — keep this file a handbook, not a changelog.
