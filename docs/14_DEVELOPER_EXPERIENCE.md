# Meridian — Developer Experience: Diagnostics, Tracing & Decisions

This is the centerpiece reference for debugging Meridian. It explains how the
compiler is designed to be **fully observable** and **unforgiving**: structured,
coded errors with source carets, always-on "did you mean", batch multi-error
reporting, machine-readable JSON, queryable design decisions, and end-to-end
tracing that connects compile time to run time.

If you only read one section, read [§2 The diagnostic anatomy](#2-the-diagnostic-anatomy)
and [§9 CLI reference for debugging](#9-cli-reference-for-debugging).

---

## Table of contents

1. [Overview & philosophy](#1-overview--philosophy)
2. [The diagnostic anatomy](#2-the-diagnostic-anatomy)
3. [Diagnostic code catalog](#3-diagnostic-code-catalog)
4. [The always-on "did you mean" guarantee](#4-the-always-on-did-you-mean-guarantee)
5. [Batch reporting](#5-batch-reporting)
6. [No-silent-fallback guarantee](#6-no-silent-fallback-guarantee)
7. [Tracing](#7-tracing)
8. [Unified compile + runtime debugging](#8-unified-compile--runtime-debugging)
9. [CLI reference for debugging](#9-cli-reference-for-debugging)
10. [Per-phase debugging recipes](#10-per-phase-debugging-recipes)
11. [Extending diagnostics](#11-extending-diagnostics)

---

## 1. Overview & philosophy

Three principles drive the whole surface:

- **Strict by default.** Anything the compiler cannot resolve is an error, not a
  silent placeholder. The historical `_unresolved` placeholder, dropped rules,
  ignored config keys, and swallowed parse failures are all gone (see
  [§6](#6-no-silent-fallback-guarantee)). Escape hatches exist but are explicit
  and per-file (`allow-fallbacks:`).
- **No silent fallbacks.** Every place the compiler previously recovered quietly
  now emits a coded diagnostic (error or, where cosmetic, a warning). Internal
  invariants that "cannot fail" are `precondition`s, not `try?` shrugs.
- **Every fixable error is guided.** A name-resolution failure always carries a
  `did you mean "X"?` suggestion or an enumerated candidate list — never a bare
  "unknown X". Structural errors always carry a concrete `help` string. And the
  *rationale* for a rule is one command away (`meridian explain`).

The implementation lives in `Sources/MeridianCore/Diagnostics/`:

| File | Responsibility |
|---|---|
| `Diagnostic.swift` | `Diagnostic`, `Suggestion`, `DiagnosticNote`, and the mandatory `Diagnostic.unresolved` / `.structural` constructors |
| `DiagnosticCode.swift` | The stable `MERxxxx` code catalog + `DecisionRef` |
| `DiagnosticEngine.swift` | Per-file collector that recovers and reports many errors per run |
| `DiagnosticRenderer.swift` | Human (snippet + caret + color) and JSON renderers |
| `Suggester.swift` | The reusable "did you mean" engine (Levenshtein + token overlap) |
| `DecisionCatalog.swift` | Structured design decisions surfaced *in* errors |
| `ParserTrace.swift` | The category-scoped tracer + timing profile |

---

## 2. The diagnostic anatomy

A single diagnostic rendered for a human looks like this:

```
error[MER2002]: unknown tool "chargepaymnt"
  --> order.meridian:6:10
     |
  6  |   invoke chargePaymnt with order = the order.
     |          ^^^^^^^^^^^^ did you mean "chargePayment"?
  = suggestion: did you mean "chargePayment"?
  = help: Declare it in a `=== tools ===` block or frontmatter `tools:`, or set frontmatter `allow-fallbacks: unknown-tools` if it is a host-provided tool registered at runtime.
  = why: A misspelled or undeclared tool id silently compiled to an invoke that failed only at runtime. (D-DX-5)
  = see: meridian explain MER2002 · meridian explain D-DX-5
```

Each piece maps to a field on the `Diagnostic` value type:

| Output | Field | Meaning |
|---|---|---|
| `error` / `warning` / `note` | `severity` | `error` fails the compile; `warning`/`note` are advisory |
| `[MER2002]` | `code.id` | The stable code (never changes once shipped) |
| `unknown tool "…"` | `message` | The human message (may evolve; the *code* is the contract) |
| `--> file:line:col` | `primaryRange` | Where it happened (`SourceRange`) |
| source line + `^^^` caret | rendered from `primaryRange` + the suggestion span | The caret narrows to the offending token when known |
| `suggestion:` | `suggestions[]` | A mechanically-applicable fix (`replacement` + `range` + `rationale`); powers `--fix` |
| `note:` | `notes[]` | Secondary related info (e.g. an enumerated candidate list) |
| `help:` | `help` | The concrete remediation (mandatory on structural codes) |
| `why:` | `decision` (via `code.decision`) | One-line rationale from the linked design decision |
| `see:` | derived | Pointers to `meridian explain <code>` / `<decision>` |

ANSI color is emitted only when stderr is an interactive terminal and `NO_COLOR`
is unset; piping to a file or CI is automatically plain text.

---

## 3. Diagnostic code catalog

Codes are stable and grouped by phase. `meridian explain <code>` prints the
long-form entry (and the linked decision). This table mirrors
`DiagnosticCode.all`; a guard test asserts they stay in sync.

### MER0xxx — legacy / generic (migration shims)

| Code | Title | Kind |
|---|---|---|
| MER0001 | semantic error | other |
| MER0002 | syntax error | other |
| MER0003 | not implemented | other |
| MER0004 | internal compiler error | other |

### MER1xxx — lex / parse (structural)

| Code | Title | Kind |
|---|---|---|
| MER1001 | malformed workflow header | structural |
| MER1002 | orphaned code block | structural |
| MER1003 | malformed statement | structural |
| MER1004 | unparseable rule | structural |
| MER1005 | malformed condition | structural |
| MER1006 | misplaced frontmatter | structural |
| MER1007 | unknown test-spec key | nameResolution |
| MER1008 | removed import form | structural |
| MER1009 | sectioned document structural error | structural |
| MER1010 | uncheckable predicate | structural |
| MER1011 | invalid table cell | structural |

### MER2xxx — name resolution (always suggest)

| Code | Title | Decision |
|---|---|---|
| MER2001 | unresolved phrase | D-DX-1 |
| MER2002 | unknown tool | D-DX-5 |
| MER2003 | unknown kind | D-DX-4 |
| MER2004 | unknown property | D-DX-4 |
| MER2005 | unknown vocabulary | — |
| MER2006 | unknown rulebook | — |
| MER2007 | unknown adjective | D-DX-4 |
| MER2008 | unknown verb | D-DX-4 |
| MER2009 | unknown allow-fallbacks kind | — |
| MER2010 | unknown trace category | — |

### MER3xxx — semantics

| Code | Title | Decision |
|---|---|---|
| MER3001 | phrase inlining too deep | D-DX-2 |
| MER3002 | recursive definition | — |
| MER3003 | duplicate declaration | — |
| MER3004 | duplicate name | — |
| MER3005 | invalid relation backing | — |
| MER3006 | unattached rule | D-DX-2 |
| MER3007 | unresolved trigger action | D-DX-2 |
| MER3008 | tool-backed expression must be a statement | — |
| MER3010 | ambiguous entry workflow | — |
| MER3011 | prose not allowed | — |
| MER3012 | command hole out of scope | — |
| MER3013 | quantifier semantic error | — |
| MER3014 | ambiguous anaphora | — |
| MER3015 | invalid enum default | — |

### MER4xxx — codegen

| Code | Title |
|---|---|
| MER4001 | codegen error |

### MER5xxx — configuration / vocabulary

| Code | Title | Decision |
|---|---|---|
| MER5001 | swift-format failed (warning) | D-DX-3 |
| MER5002 | unrecognized vocabulary declaration | — |
| MER5003 | unknown rulebook section | — |
| MER5004 | malformed rulebook entry | — |
| MER5005 | unrecognized block property | — |
| MER5010 | unknown merconfig section | — |

---

## 4. The always-on "did you mean" guarantee

A diagnostic is *fixable* when a remediation can be named. Meridian enforces this
mechanically rather than relying on per-site discipline.

**Name-resolution errors** funnel through a single constructor — the *only* way
to build a `.nameResolution` diagnostic:

```swift
Diagnostic.unresolved(_ code: DiagnosticCode,
                      target: String,
                      among candidates: [String],
                      range: SourceRange,
                      noun: String? = nil,
                      help: String? = nil)
```

It runs the `Suggester` over `candidates`:

- **within edit-distance budget** (`max(2, target.count / 3)`) → attaches a
  `did you mean "<closest>"?` `Suggestion` carrying `replacement` + `range` (so
  `--fix` and editors can apply it).
- **nothing within budget** → never a bare "unknown X"; instead a `note`
  enumerating the available set: the full list when small (≤12), else the top-8
  by closeness plus a total count.

The constructor `precondition`s that `code.kind == .nameResolution`, so a
miswired call fails loudly in tests.

**Structural errors** are not name lookups, so they carry a mandatory non-empty
`help` string (`Diagnostic.structural` `precondition`s this).

**Enforcement.** A guard test enumerates every `.nameResolution` code and asserts
each produces a suggestion or a candidate-list note, and every `.structural`
code asserts non-empty `help`. This is what makes "always" load-bearing.

Sites funneled through the guarantee today: unresolved phrase (MER2001), unknown
tool (MER2002), unknown kind/property (MER2003/4), unknown vocabulary/rulebook
(MER2005/6), unknown adjective/verb (MER2007/8), unknown `allow-fallbacks` token
(MER2009), unknown rulebook section (MER5003), and unknown test-spec key
(MER1007).

---

## 5. Batch reporting

The `DiagnosticEngine` **collects** diagnostics and continues past the first
error, so one compile reports *many* problems (rustc/Elm-style) instead of the
old one-at-a-time loop.

- **Recovery is coarse-grained**: skip a whole construct (workflow, rule,
  statement), never resync at the token level. Token-level resync produces
  cascade/phantom errors; construct-skipping is cascade-resistant.
- **Cascade avoidance is structural**: workflow phrase-stubs are registered
  *before* any body lowers, so a workflow whose body fails to lower still
  resolves as a callee — dependents don't spuriously report "unresolved phrase".
- **Compatibility**: `engine.throwIfErrors()` preserves the "throw on first
  error" contract for callers that want it. The thrown type stays
  `CompilerError`, now carrying `.diagnostics([Diagnostic])`.
- **Concurrency**: the engine is per-file and single-threaded within one file's
  pipeline; `Diagnostic` values are `Sendable`. Parallel file compiles each get
  their own engine.

Every emitted diagnostic is also mirrored into the `.diagnostics` trace stream
and counted in the end-of-compile timing profile (see [§7](#7-tracing)).

---

## 6. No-silent-fallback guarantee

Former silent recoveries are now coded diagnostics. The audited table:

| Former silent site | Now |
|---|---|
| Malformed workflow header (missing `:`) | MER1001 (error) |
| Orphaned fenced code block | MER1002 (error) |
| Unrecognized statement line | MER1003 (error — malformed structural surface only; free-form phrase → MER2001) |
| Unparseable / unattached rule | MER1004 / MER3006 (error) |
| Malformed condition / expression carrier | MER1005 (error) |
| Misplaced frontmatter | MER1006 (error) |
| Removed body-level `import` | MER1008 (error) |
| Phrase-inline depth overflow | MER3001 (error) |
| Unrecognized `.merconfig` declaration / malformed tool | MER5002 (error) |
| Unknown rulebook `=== section ===` | MER5003 (error) |
| Unknown merconfig `=== section ===` | MER5010 (error) |
| Unknown `.meridian.test` key | MER1007 (error) |
| Unknown `allow-fallbacks:` token | MER2009 (error) |
| Unknown tool id | MER2002 (error) |
| `swift-format` failure | MER5001 (**warning** — keep valid output) |
| Internal `try? NSRegularExpression` on constant patterns | `preconditionFailure` (compiler bug) |

**Intentionally retained** runtime fallbacks (safe, documented): value-level
null modeling like `state.get("…") ?? .null` (a missing state key is a runtime
concept, not an authoring error). These are explicitly out of scope for the
strict checks.

**Escape hatches.** Per-file, opt-in, via frontmatter `allow-fallbacks:` (kinds:
`unresolved-phrases`, `unparseable-rules`, `unattached-rules`,
`unresolved-trigger-actions`, `unknown-tools`), or process-wide via
`Compiler.Options.fallbackPolicy = .lenient` for hosts/tests.

### 6.1 Intentional silent consumes (compile-time)

These are **not** errors — source that is explicitly non-executable by syntax or
role:

- blank lines and comment / blockquote-comment lines (`>`)
- inert table/checklist sentinels (`!!! table (( inert ))`, `!!! checklist (( inert ))`)
- inert/template/domain section bodies routed as non-executable
- pure outline/topic labels with no statement body (`Comments:` with empty rest)
- workflow headers in sectioned skill docs that read as prose (not `to …:`)

Every other consume/drop must emit a coded diagnostic or use a named
`allow-fallbacks:` kind. Accountability: `DiagnosticCodeCatalog.swift` lists
every `MERxxxx` code as `active`, `reserved`, or `deprecated`; tests assert each
non-reserved code has at least one production emitter.

---

## 7. Tracing

`ParserTrace` (`Sources/MeridianCore/Diagnostics/ParserTrace.swift`) is an
opt-in, category-scoped tracer for the compiler frontend. It does nothing unless
a category is enabled. See [08_TRACING.md](08_TRACING.md) for the full API; this
is the coverage + timing summary.

### Categories & pipeline coverage matrix

| Category | Emitted by | Covers |
|---|---|---|
| `tokenize` | `IndentTokenizer` | fence/table collapse, headings, indent/comment decisions |
| `merconfig` | `MerConfigParser` | each section + declaration counts |
| `parse` | `MeridianParser` | `.meridian`/`.meri` file parsing |
| `symbols` | `SymbolTable.build` | every kind/property/relation/verb/phrase/tool/constant/instance |
| `parse` / `phrase.parse` | parser productions | parse spans, branch routing, and phrase-pattern tokenization |
| `phrase.match` | `SymbolTable.matchPhrase` | candidate scoring + winner |
| `phrase.args` | `SymbolTable.extractArgs` | per-slot argument extraction |
| `phrase.inline` | `ASTToIR.inlinePhrase` | recursive body expansion |
| `statement` | `StatementParser.parseStatement` | per-statement dispatch (`L42 -> bind`, …) |
| `expression` | `ExpressionParser` | expression parsing decisions |
| `lowering` | `ASTToIR`, `RuleAnalyzer` | AST → IR (`L42 lowerStatement bind`), rule classification |
| `rulebook` | `RulebookParser` / rewrite | `.merrules` parsing + rewrites |
| `skill` | section builder | section-role classification + scoped tools |
| `codegen` | `SwiftEmitter` | per-file / per-workflow emission |
| `diagnostics` | `DiagnosticEngine` | every emitted error/warning/note |
| `timing` | `Compiler` phases | per-phase wall-clock + profile (off by default) |

Enabling a group prefix (e.g. `phrase`) enables every leaf under it. `all`
enables everything.

### Timing & profile

`Compiler.compileWithManifest` wraps the whole pipeline in a top-level `compile`
span and times each phase (`symbols`, `parse`, `lower`, `codegen`) via
`trace.phase(_:)`. At the end it prints a profile:

```
[timing] ── compile profile ──
[timing]   symbols                  1.20 ms  ( 8.0%)
[timing]   parse                    6.40 ms  (42.7%)
[timing]   lower                    4.10 ms  (27.3%)
[timing]   codegen                  3.30 ms  (22.0%)
[timing]   total                   15.00 ms
[timing]   diagnostics emitted: 0
```

`.timing` is **off by default** and excluded from `capturing()` assertions so
trace tests stay deterministic. Enable it with `--trace timing` (or `all`).

```bash
meridian compile order.meridian --trace phrase.match,lowering
meridian compile order.meridian --trace timing
MERIDIAN_TRACE=all meridian check order.meridian
meridian compile order.meridian --trace all --trace-file /tmp/compile.log
```

---

## 8. Unified compile + runtime debugging

Compile-time source positions flow all the way into runtime telemetry, so a
runtime failure maps back to a Meridian source line:

```
Meridian source line
  → codegen emits `// L{n}` provenance comments above each primitive
  → Compiler.sourceMap(fromGeneratedSwift:) builds meridian-line → swift-line
  → ManifestEmitter writes it into `meridian_skill`/source map of the manifest
  → runtime JSONL Observer events carry the source range
  → `meridian trace render events.jsonl` shows an indented execution tree
```

`Compiler.sourceMap(fromGeneratedSwift:)` is the single source of truth for the
`// L` parsing and is invoked in `compileWithManifest`, so **every** emitted
manifest carries the map (the CLI no longer rebuilds it by hand). The runtime's
`TraceTreeRenderer` (`meridian trace render`) and the compiler's `ParserTrace`
share the same "what happened, in order, with source anchors" philosophy:
`ParserTrace` answers *what happened at compile*, the JSONL event stream +
`trace render` answer *what happened at run*.

---

## 9. CLI reference for debugging

| Command | Purpose |
|---|---|
| `meridian explain <code\|decision>` | Long-form cause + fix for a `MERxxxx` code, plus the linked decision rationale + alternatives. Also accepts a `D-DX-n` id directly. |
| `meridian decisions [query]` | List/search the design-decision catalog. |
| `meridian decisions --id D-DX-5` | Print one decision in full. |
| `meridian decisions --render docs/15_DECISIONS.md` | Regenerate the readable decision log from the catalog (kept in sync by a test). |
| `meridian trace categories` | List every trace category with a description. |

### Diagnostics flags (on `compile`, `check`, `verify`, `run`)

- `--diagnostics-format human|json` — `human` is the snippet+caret form; `json`
  is the stable schema for editors / CI (includes the `decision` id).
- `--fix` — preview unambiguous quick-fixes (single ranged suggestion per
  diagnostic). **Dry-run by default**; the fixer narrows a construct-level range
  to the single misspelled token and only applies an *unambiguous* best match
  within the edit-distance budget, so it can never corrupt a line.
- `--write` — with `--fix`, apply the previewed fixes in place.
- `--trace <categories>` / `--trace-file <path>` — activate tracing per command.

JSON shape (one element per diagnostic):

```json
{
  "code": "MER2002",
  "severity": "error",
  "message": "unknown tool \"chargepaymnt\"",
  "range": { "file": "order.meridian", "startLine": 6, "startColumn": 10, "endLine": 6, "endColumn": 22 },
  "suggestions": [ { "replacement": "chargePayment", "rationale": "did you mean \"chargePayment\"?", "range": { … } } ],
  "notes": [],
  "help": "Declare it in a `=== tools ===` block …",
  "decision": "D-DX-5"
}
```

---

## 10. Per-phase debugging recipes

| Symptom | Run this |
|---|---|
| "My phrase won't resolve" (MER2001) | `meridian check f.meridian --trace phrase.match,phrase.args` — see candidate scores; the error already lists the closest phrase. |
| "My tool is unknown" (MER2002) | `meridian explain MER2002`; check the `=== tools ===` decl and frontmatter `tools:`. Try `--fix` for a typo. |
| "My property is rejected" (MER2004) | `meridian check --trace symbols,lowering` — confirm the property is declared on that kind. |
| "Where did my statement go?" | `meridian check --trace statement,tokenize` — see per-line dispatch and any fence/heading collapse. |
| "Why is codegen wrong?" | `meridian compile --trace codegen` and inspect the `// L` comments + manifest source map. |
| "Why is this even an error?" | `meridian explain <code>` — shows the rationale + alternatives from the governing decision. |
| "How slow is each phase?" | `meridian compile --trace timing`. |
| "I want all of it in a file" | `--trace all --trace-file /tmp/c.log`. |

---

## 11. Extending diagnostics

To add a new diagnostic:

1. **Add the code** to `DiagnosticCode` (and to `DiagnosticCode.all`). Pick the
   right range (`MER1xxx`…`MER5xxx`) and `kind`. If a design decision governs it,
   set `decision: DecisionRef("D-DX-n")`.
2. **Emit it** at the site:
   - name resolution → `engine.report(Diagnostic.unresolved(.yourCode, target:, among:, range:, noun:, help:))`. You *must* pass the candidate set; the suggester does the rest.
   - structural → `Diagnostic.structural(.yourCode, message:, range:, help:)` (help is mandatory).
   - other → `Diagnostic.error(.yourCode, message:, range:)`.
3. **Range precision**: pass a `SourceRange`. Tier-1 (line-accurate) is automatic
   via `SourceLine.statementRange(file:)`; for a token-precise caret use
   `SourceLine.range(file:of:)` (or `SourceRange.span(file:line:in:of:)`).
4. **Decision (optional)**: add a `DecisionRecord` to `DecisionCatalog.all`, then
   `meridian decisions --render docs/15_DECISIONS.md`.
5. **Tests**: the guarantee guard test will require a `.nameResolution` code to
   produce a suggestion/note and a `.structural` code to carry `help`. Add a
   `DiagnosticTests` case asserting the rendered output and (for fallbacks) a
   `NoSilentFallbackTests` case. Codes are the durable contract — assert on the
   code, not the message text.

See also: [08_TRACING.md](08_TRACING.md) (tracing deep-dive),
[15_DECISIONS.md](15_DECISIONS.md) (the readable decision log),
[07_CLI.md](07_CLI.md) (full CLI reference).
