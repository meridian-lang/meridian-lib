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
  *rationale* for a rule is one command away (`meridian explain-diag`).
- **Compiled meaning is explainable.** `meridian explain` is reserved for Wave
  7 Canonical English: compile a source, verbalize the lowered model, and review
  what the compiler understood. Pair it with `meridian drift` for authored-vs-
  canonical audits; diagnostic explanations remain `meridian explain-diag`.

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
  = see: meridian explain-diag MER2002 · meridian explain-diag D-DX-5
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
| `see:` | derived | Pointers to `meridian explain-diag <code>` / `<decision>` |
| `phase:` | `phase` | Optional compile-phase label (`parse`, `lower`, `codegen`, `validation`, …) for tooling filters |
| `related:` | `relatedRanges[]` | Secondary source spans (e.g. the declaration site for a duplicate-name error) |

ANSI color is emitted only when stderr is an interactive terminal and `NO_COLOR`
is unset; piping to a file or CI is automatically plain text.

JSON diagnostics mirror the same remediation surface: `phase`, `related` (array
of ranges), `help`, `suggestions`, `notes`, and `decision`. `DiagnosticRenderer.renderJSON`
is a **throwing** API (`DiagnosticRenderer.Error.jsonSerializationFailed`) so
CLI paths fail closed instead of emitting partial JSON.

---

## 3. Diagnostic code catalog

Codes are stable and grouped by phase. `meridian explain-diag <code>` prints the
long-form entry (and the linked decision). This table mirrors
`DiagnosticCode.all`; a guard test asserts they stay in sync.

### MER0xxx — legacy / generic (migration shims)

| Code | Title | Kind |
|---|---|---|
| MER0003 | not implemented | other |
| MER0004 | internal compiler error | other |

### MER1xxx — lex / parse (structural)

| Code | Title | Kind | Decision |
|---|---|---|---|
| MER1001 | malformed workflow header | structural | — |
| MER1002 | orphaned code block | structural | — |
| MER1003 | malformed statement | structural | — |
| MER1004 | unparseable rule | structural | — |
| MER1005 | malformed condition | structural | — |
| MER1006 | misplaced frontmatter | structural | — |
| MER1007 | unknown test-spec key | nameResolution | — |
| MER1008 | removed import form | structural | — |
| MER1009 | sectioned document structural error | structural | D-DX-2 |
| MER1010 | uncheckable predicate | structural | D-DX-2 |
| MER1011 | invalid table cell | structural | — |
| MER1012 | match branch missing colon | structural | D-DX-2 |

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
| MER2011 | missing phrase argument | D-DX-2 |

### MER3xxx — semantics

| Code | Title | Decision |
|---|---|---|
| MER3001 | phrase inlining too deep | D-DX-2 |
| MER3002 | recursive definition | — |
| MER3003 | duplicate declaration | — |
| MER3004 | duplicate name | — |
| MER3005 | invalid relation backing | — |
| MER3006 | unattached rule | D-DX-6 |
| MER3007 | unresolved trigger action | D-DX-2 |
| MER3008 | tool-backed expression must be a statement | — |
| MER3010 | ambiguous entry workflow | — |
| MER3011 | prose not allowed | — |
| MER3012 | command hole out of scope | — |
| MER3013 | quantifier semantic error | — |
| MER3014 | ambiguous anaphora | — |
| MER3015 | invalid enum default | — |
| MER3016 | unlowerable rule predicate | D-DX-2 |
| MER3017 | unsupported trigger condition | D-DX-2 |
| MER3018 | match branch semantic error | D-DX-2 |

### MER4xxx — codegen

| Code | Title | Decision |
|---|---|---|
| MER4001 | codegen error | — |
| MER4002 | invalid IR | D-DX-2 |

### MER5xxx — configuration / vocabulary

| Code | Title | Decision |
|---|---|---|
| MER5001 | swift-format failed (warning) | D-DX-3 |
| MER5002 | unrecognized vocabulary declaration | — |
| MER5003 | unknown rulebook section | — |
| MER5004 | malformed rulebook entry | — |
| MER5005 | unrecognized block property | — |
| MER5010 | unknown merconfig section | — |
| MER5011 | unwritable trace file | D-DX-8 |
| MER5012 | empty lexicon marker collection | D-DX-8 |

### MER6xxx — lint / authoring warnings

| Code | Title | Decision |
|---|---|---|
| MER6001 | polite command lint | D-DX-7 |
| MER6002 | uncertainty lint | D-DX-7 |
| MER6003 | migration fuzzy-route downgrade | D-DX-7 |
| MER6004 | diagnostic recovery summary | D-DX-2 |

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

- **within edit-distance budget and unambiguous** → attaches a
  `did you mean "<closest>"?` `Suggestion` carrying `replacement` + `range` (so
  `--fix` and editors can apply it).
- **within budget but tied** (two or more candidates at the same Levenshtein
  distance) → **no** auto-suggestion; instead a `note` listing the tied
  alternates (`Suggester.closestAmbiguous`). This prevents `--fix` from picking
  an arbitrary winner when distances are equal.
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
(MER2009), unknown trace category (MER2010), unknown template formatter
(MER2012), unknown rulebook section (MER5003), and unknown test-spec key
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
When recovery skips one or more constructs to keep collecting errors, the engine
also emits a `MER6004` warning summary with notes naming the skipped construct
ranges. That makes recovery visible without losing the multi-error report.

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
| Unknown `--trace` category | MER2010 (error, rendered before command work starts) |
| Unknown tool id | MER2002 (error) |
| Match branch missing `:` | MER1012 (error) |
| Invalid/duplicate/empty match branch arms | MER3018 (error) |
| Malformed hand-built IR before verbalization or Swift emission | MER4002 (error) |
| Unwritable `--trace-file` at CLI startup | MER5011 (error) |
| `swift-format` failure | MER5001 (**warning** — keep valid output) |
| Recovery skip after reporting an error | MER6004 (**warning** summary) |
| `migrate-skill --route-fuzzy` downgrades an operational section | MER6003 (**warning** in migration report) |
| Internal `try? NSRegularExpression` on constant patterns | `preconditionFailure` (compiler bug) |

**Intentionally retained** runtime fallbacks (safe, documented): value-level
null modeling like `state.get("…") ?? .null` (a missing state key is a runtime
concept, not an authoring error). These are explicitly out of scope for the
strict checks.

**Escape hatches.** Per-file, opt-in, via frontmatter `allow-fallbacks:` (kinds:
`unresolved-phrases`, `unparseable-rules`, `unattached-rules`,
`unresolved-trigger-actions`, `unknown-tools`), or process-wide via
`Compiler.Options.fallbackPolicy = .lenient` for hosts/tests.

Applying an `allow-fallbacks:` kind is visible: the compiler emits a warning
diagnostic at the fallback site and a `.lowering` trace line when tracing is
enabled. The escape hatch remains available for staged authoring, but it is no
longer silent.

### 6.1 IR validation and throwing tooling APIs

`IRValidator` guards manually constructed or transformed IR before the two public
rendering surfaces that could otherwise hide malformed structure:
`Verbalizer.verbalize()` and `SwiftEmitter.emit()` both call it and throw
`MER4002` diagnostics on invalid IR. This covers empty identifiers/field names,
bad inline invocation positions, invalid match branches, empty wait/event/choice
payloads, and record/table shape mismatches.

The API consequence is intentional: `Verbalizer.verbalize()` and
`SwiftEmitter.emit()` are throwing APIs. CLI commands (`explain`, `drift`,
`compile`, `run`) render those failures through the same `DiagnosticRenderer`
path as parser/lowering errors.

### 6.2 Intentional silent consumes (compile-time)

These are **not** errors — source that is explicitly non-executable by syntax or
role:

- blank lines and comment / blockquote-comment lines (`>`)
- inert table/checklist sentinels (`!!! table (( inert ))`, `!!! checklist (( inert ))`)
- `reference`/`inert`/template/domain section bodies routed as non-executable
- pure outline/topic labels with no statement body (`Comments:` with empty rest)
- workflow headers in sectioned skill docs that read as prose (not `to …:`)

Every other consume/drop must emit a coded diagnostic or use a named
`allow-fallbacks:` kind. Accountability: every `MERxxxx` code definition in
`DiagnosticCode.swift` carries its `status` (`active`, `reserved`, or
`deprecated`) and its production `emitters`, and `DiagnosticCode.catalog`
projects that straight off `DiagnosticCode.all`; tests assert each
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
| `verbalizer` | `Verbalizer` | Canonical English emission from validated IR |
| `drift` | `DriftEngine` | authored-vs-canonical hunk classification |
| `diagnostics` | `DiagnosticEngine` | every emitted error/warning/note |
| `timing` | `Compiler` phases | per-phase wall-clock + profile (off by default) |

Enabling a group prefix (e.g. `phrase`) enables every leaf under it. `all`
enables everything.

### Timing & profile

`Compiler.compile(_:)` wraps the whole pipeline in a top-level `compile`
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

Three observability layers connect Meridian source to run-time behavior:

1. **Compile-time `ParserTrace`** — `--trace` on `compile`/`check`/… shows
   parser, lowering, and codegen decisions ([§7](#7-tracing)).
2. **Legacy runtime events** — generated code emits `Event`s; observers write
   JSONL; `meridian trace render` shows an execution tree with source anchors.
3. **Semantic traces (Wave 8)** — `TraceStore` retains `TraceRecord` rows;
   temporal/statistical conditions and monitors query them via
   `TraceEvaluator`; audit with `meridian trace eval` / `verify` / `drift`.

### End-to-end recipe (correlation id → manifest → run → traces)

Use this chain when debugging a single workflow from source through execution:

```bash
# 1. Compile with structured compile-time trace + manifest
meridian compile order.meridian --trace all --trace-format jsonl \
  --diagnostics-format json 2>compile-trace.log
# stderr banner: trace correlation id: <uuid>  (every JSONL line has "corr":"<uuid>")

# 2. Inspect manifest source map (meridian line ↔ Swift line)
jq '.sourceMap' order.meridian.manifest.json

# 3. Run and capture runtime Event JSONL
meridian run order.meridian --events /tmp/events.jsonl
# Events carry "run_id", optional "source": {file,line,col}, and payload "step"

# 4. When === trace === is configured, semantic TraceRecord JSONL is separate
meridian trace eval /tmp/semantic-trace.jsonl "…" --at 2026-01-01T00:00:00Z
meridian trace render /tmp/events.jsonl   # legacy event tree (not semantic JSONL)
```

| Link | Field / artifact | Role |
|---|---|---|
| Compile invocation | `ParserTrace.correlationID` / JSONL `"corr"` | Groups one command's compile-time trace records |
| Source positions | Manifest `sourceMap` + `// L{n}` in generated Swift | Maps runtime `source` back to `.meridian` lines |
| Run identity | `Runtime.runID` → Event `"run_id"`, TraceRecord `"run"` | Scopes one execution |
| Step continuity | TraceRecord `"step"`, Event payload `"step"` | Stable path for history / monitors |
| Execution telemetry | `JSONLObserver` Event JSONL | `meridian trace render` |
| Semantic history | `TraceStore` TraceRecord JSONL | `trace eval` / `verify` / temporal replay |

`Compiler.sourceMap(fromGeneratedSwift:)` is the single source of truth for the
`// L` parsing and is invoked in `compile(_:)`, so **every** emitted
manifest carries the map. Do not confuse `ParserTrace` stderr/JSONL with semantic
trace JSONL — they answer different questions. See [08_TRACING.md](08_TRACING.md)
and [19_TRACES_AND_TIME.md](19_TRACES_AND_TIME.md).

### Fail-closed defaults

Several observability paths default to **fail closed** (surface the error, do not
silently continue):

- Unknown `--trace` categories → `MER2010` before work starts; unwritable
  `--trace-file` → `MER5011`.
- `DiagnosticRenderer.renderJSON` throws on serialization failure (CLI exits 1).
- Missing CLI input paths / directory enumeration failures → `MER5013` /
  `MER5014` (see `CLISupport.swift`).
- Wave 8 `store failure policy: auto` resolves at **compile time** to
  `.failClosed` (`TraceIdentityPlanner`); `TraceConfiguration.default` is also
  `.failClosed` for hosts that skip the planner.
- `Observer.record` is `async throws`; `JSONLObserver` propagates write failures
  instead of dropping events. Under `.failClosed` trace policy, observer/trace-store
  failures surface as `MeridianRuntimeError` on the next strict emit.

---

## 9. CLI reference for debugging

| Command | Purpose |
|---|---|
| `meridian explain <source>` | Print the Canonical English form of the compiled IR. Use this to audit lowered meaning, not to explain diagnostics. |
| `meridian drift <source>` | Compare authored source with Canonical English; reports synonym, structure, desugar, and meaning-bearing hunks. |
| `meridian grammar-doc` | Print the live canonical grammar reference generated from `GrammarTable`. |
| `meridian explain-diag <code\|decision>` | Long-form cause + fix for a `MERxxxx` code, plus the linked decision rationale + alternatives. Also accepts a `D-DX-n` id directly. |
| `meridian decisions [query]` | List/search the design-decision catalog. |
| `meridian decisions --id D-DX-5` | Print one decision in full. |
| `meridian decisions --render docs/15_DECISIONS.md` | Regenerate the readable decision log from the catalog (kept in sync by a test). |
| `meridian trace categories` | List every compile-time `ParserTrace` category with a description. |
| `meridian trace render <events.jsonl>` | Pretty-print legacy runtime **event** JSONL (execution tree). |
| `meridian trace eval <trace.jsonl> "<expr>" --at …` | Evaluate a Wave 8 semantic trace expression offline. |
| `meridian trace verify <trace.jsonl> --run <id>` | Verify semantic trace hash chain / checksums. |
| `meridian trace drift …` | Audit semantic trace outcome drift. |
| `meridian bench-trace` | Trace-evaluation performance baseline. |

### Diagnostics and trace flags

- `--diagnostics-format human|json` — `human` is the snippet+caret form; `json`
  is the stable schema for editors / CI (includes the `decision` id). Available
  on `compile`, `check`, `verify`, and `run`.
- `meridian lint --format human|json` (also `--diagnostics-format`) uses the
  same `DiagnosticRenderer` and shared `Diagnostic` values for authoring
  warnings such as MER3014, MER6001, and MER6002.
- `--fix` — preview unambiguous quick-fixes (single ranged suggestion per
  diagnostic). **Dry-run by default**; the fixer narrows a construct-level range
  to the single misspelled token and only applies an *unambiguous* best match
  within the edit-distance budget, so it can never corrupt a line.
- `--write` — with `--fix`, apply the previewed fixes in place.
- `--trace <categories>` / `--trace-file <path>` / `--trace-format text|jsonl` —
  activate tracing per command. Available on `compile`, `check`, `verify`, `run`,
  `migrate-skill`, `preview-skill`, `explain`, `drift`, `inert-yield`, and
  `skill-deviation`. When `--trace` is set, stderr prints one **correlation id**
  line; JSONL records include matching `"corr"`. Unknown categories are `MER2010`
  hard errors; unwritable trace files are `MER5011` hard errors, while
  mid-stream file sink failures visibly fall back to stderr.

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
| "My tool is unknown" (MER2002) | `meridian explain-diag MER2002`; check the `=== tools ===` decl and frontmatter `tools:`. Try `--fix` for a typo. |
| "My property is rejected" (MER2004) | `meridian check --trace symbols,lowering` — confirm the property is declared on that kind. |
| "Where did my statement go?" | `meridian check --trace statement,tokenize` — see per-line dispatch and any fence/heading collapse. |
| "Why is codegen wrong?" | `meridian compile --trace codegen` and inspect the `// L` comments + manifest source map. |
| "Why is this even an error?" | `meridian explain-diag <code>` — shows the rationale + alternatives from the governing decision. |
| "What did the compiler understand?" | `meridian explain f.meri --trace verbalizer --merconfig ... --rulebook ...` — prints Canonical English from the lowered IR. |
| "How far is my authored surface from canonical?" | `meridian drift f.meri --json --trace drift` — use the category counts in reviews or migration audits. |
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
