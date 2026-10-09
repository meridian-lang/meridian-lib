# Meridian — Developer Experience

Diagnostics, `MERxxxx` codes, did-you-mean, batch reporting, the decision
catalog, compile-time tracing, and the canonical-English verbalizer/drift
audit — everything you need to see what the compiler did and why.

---

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
a category is enabled. See [06_DEVELOPER_EXPERIENCE.md](06_DEVELOPER_EXPERIENCE.md) for the full API; this
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
trace JSONL — they answer different questions. See [06_DEVELOPER_EXPERIENCE.md](06_DEVELOPER_EXPERIENCE.md)
and [04_RUNTIME.md](04_RUNTIME.md).

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
| `meridian decisions --render docs/07_DECISIONS.md` | Regenerate the readable decision log from the catalog (kept in sync by a test). |
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
   `meridian decisions --render docs/07_DECISIONS.md`.
5. **Tests**: the guarantee guard test will require a `.nameResolution` code to
   produce a suggestion/note and a `.structural` code to carry `help`. Add a
   `DiagnosticTests` case asserting the rendered output and (for fallbacks) a
   `NoSilentFallbackTests` case. Codes are the durable contract — assert on the
   code, not the message text.

See also: [06_DEVELOPER_EXPERIENCE.md](06_DEVELOPER_EXPERIENCE.md) (tracing deep-dive),
[07_DECISIONS.md](07_DECISIONS.md) (the readable decision log),
[05_CLI.md](05_CLI.md) (full CLI reference).

---

## Compile-time tracing — full reference

*Was `docs/08_TRACING.md`.*

Meridian has **two trace layers**:

| Layer | Mechanism | Question |
|---|---|---|
| **Compile-time** | `ParserTrace` (`--trace`, `MERIDIAN_TRACE`) | What did the compiler do? |
| **Run-time semantic** | `TraceStore` + `TraceRecord` (Wave 8) | What history do temporal/statistical conditions query? |

`ParserTrace` (in `Sources/MeridianCore/Diagnostics/ParserTrace.swift`) is an
opt-in, category-scoped diagnostic logger for compile-time compiler/tooling
work: tokenization, parsing, lowering, validation, codegen, verbalization, and
drift analysis. It is lightweight enough to ship in production builds; it does
nothing unless at least one category is enabled.

This is separate from runtime execution telemetry. `ParserTrace` answers "what
did the compiler do while understanding and emitting this file?" Legacy runtime
JSONL `Event` streams (via `Observer`) answer "what happened while the workflow
ran?" — `meridian trace render` pretty-prints those events.

**Wave 8 semantic traces** are a third, persisted layer: `Runtime` appends
`TraceRecord` rows to a `TraceStore` when `=== trace ===` configures one.
`TraceEvaluator` replays those records for `has ever`, windowed counts,
`usually`/`rarely`, and monitored assertions. CLI commands `meridian trace eval`,
`trace verify`, `trace drift`, and `bench-trace` operate on semantic trace
JSONL — not on `ParserTrace` logs. `--trace` does not enable semantic capture;
see [04_RUNTIME.md](04_RUNTIME.md).

The bridge from compile to run for all three layers is the generated source map:
`Compiler.compile(_:)` records source anchors; runtime observers and trace stores
carry them forward.

---

### Activation

Three ways to activate tracing:

```bash
# CLI flag (comma or space separated)
meridian compile src.meridian --trace phrase.match,lowering

# Environment variable (read at ParserTrace.init() time)
MERIDIAN_TRACE=phrase,lowering meridian compile src.meridian
MERIDIAN_TRACE=all swift test

# MERIDIAN_TRACE alone activates tracing — no --trace flag required.
# The CLI still prints the correlation-id banner on stderr (see below).
MERIDIAN_TRACE=lowering meridian check src.meridian

# Programmatic
ParserTrace.shared.enable([.phraseMatch, .lowering])
```

---

### Categories

Categories form a two-level hierarchy: `group.leaf`. Enabling a group prefix
enables all leaves under it. The list below mirrors `ParserTrace.Category`;
`meridian trace categories` prints the same set with descriptions.

| Enum case | Raw value | Description |
|---|---|---|
| `.tokenize` | `tokenize` | Lexing: fence/table collapse, comment/indent/heading decisions (IndentTokenizer) |
| `.parse` | `parse` | Top-level parse phase spans and parser branch routing |
| `.phraseParse` | `phrase.parse` | Pattern tokenisation for workflow and phrase headers |
| `.phraseMatch` | `phrase.match` | Candidate scoring and winner selection |
| `.phraseExtractArgs` | `phrase.args` | Argument text extraction per parameter slot |
| `.phraseInline` | `phrase.inline` | Body expansion and argument substitution |
| `.statement` | `statement` | Per-statement parser dispatch (StatementParser) |
| `.expression` | `expression` | Expression parsing decisions (ExpressionParser) |
| `.lowering` | `lowering` | AST → IR lowering decisions (ASTToIR) + rule classification |
| `.symbols` | `symbols` | Symbol-table construction (kinds/properties/phrases/tools/…) |
| `.merconfig` | `merconfig` | Vocabulary (.merconfig) section/phrase/tool parsing |
| `.rulebook` | `rulebook` | Rulebook (.merrules) parsing + rewrite |
| `.skill` | `skill` | Skill/section-role classification + scoped tools |
| `.codegen` | `codegen` | Swift/manifest/domain emission (SwiftEmitter) |
| `.verbalizer` | `verbalizer` | Canonical English verbalization (IR → source) |
| `.validation` | `validation` | IR structural validation before emission |
| `.drift` | `drift` | Authored-vs-canonical drift hunk classification |
| `.diagnostics` | `diagnostics` | Every emitted diagnostic (errors/warnings/notes) |
| `.timing` | `timing` | Per-phase wall-clock timing + end-of-compile profile (**off by default**) |

Enable group `phrase` to get all four `phrase.*` categories at once.
Enable `all` to get everything.

#### Timing & the compile profile

`Compiler.compile(_:)` wraps the whole pipeline in a top-level `compile`
span and times each phase via `trace.phase(_:)`. At end-of-compile it emits a
profile under `.timing`:

```
[timing] ── compile profile ──
[timing]   symbols                  1.20 ms  ( 8.0%)
[timing]   parse                    6.40 ms  (42.7%)
[timing]   lower                    4.10 ms  (27.3%)
[timing]   domainDecl               0.40 ms  ( 2.7%)
[timing]   traceIdentity.annotate     0.30 ms  ( 2.0%)
[timing]   obligationStamp            0.20 ms  ( 1.3%)
[timing]   codegen                  3.30 ms  (22.0%)
[timing]   manifestRules              0.15 ms  ( 1.0%)
[timing]   obligationDocument         0.10 ms  ( 0.7%)
[timing]   total                   15.00 ms
[timing]   diagnostics emitted: 0
```

`.timing` is **off by default** and is excluded from `capturing()` assertions so
trace tests remain deterministic. Enable it explicitly with `--trace timing`
(or `all`).

#### Compile phase map

The table below is the authoritative list of `trace.phase(_:)` labels and the
categories that carry detail lines. Group prefixes (`phrase`, `all`) still apply.

| Stage | `trace.phase` label(s) | Primary categories | Notes |
|---|---|---|---|
| **Bootstrap** | `bootstrap.rulebook`, `bootstrap.merconfig`, `bootstrap.modules`, `bootstrap.inlineDomain`, `bootstrap.lexiconMerge` | `rulebook`, `merconfig`, `symbols` | Module resolution and inline `## Domain` harvest run here. |
| **Symbols** | `symbols` | `symbols` | `SymbolTable.build(from:)` — kinds, properties, phrases, tools. |
| **Parse** | `parse` (single file) or `parse <file>` (skillpack) | `parse`, `statement`, `expression`, `phrase.parse`, `skill` | Per-statement dispatch and expression production decisions. |
| **Lower** | `lower` | `lowering`, `rulebook`, `skill` | AST → IR, rule classification, deontic norms, fallback warnings. |
| **Post-lower** | `domainDecl`, `traceIdentity.hash`, `traceIdentity.annotate`, `obligationStamp` | `codegen`, `timing` | Domain inline decl harvest; trace-capture policy annotation; `OBL-…` contract stamping. Summary lines: `domain decl:`, `trace identity: annotated`, `obligation stamp:`. |
| **Codegen** | `codegen`, `codegen-multi` | `codegen`, `validation` | Swift + optional multi-file emit (`multi-file emit:` summary). |
| **Manifest** | `manifestRules`, `obligationDocument` | `codegen`, `timing` | Rule manifest entries + versioned obligation JSON (`obligation document:` summary). |
| **Sidecar** | `irSidecar` | `codegen`, `timing` | `IRSidecarEmitter` canonical IR sidecar (`emit IR sidecar` span). |
| **Multi-source** | `compile (N file(s))` + per-file `parse <file>` | `timing`, `parse`, `lower` | Batch compile shares one profile; each input file gets its own parse phase. |
| **Verbalizer** | (no `trace.phase` — workflow/primitive spans) | `verbalizer`, `validation` | `meridian explain`, `DriftEngine`, `IRSidecarEmitter` callers. Per-workflow `▶`/`◀` + cheap per-primitive labels. |
| **Lint** | (no `trace.phase` — `lint <file>` span) | `diagnostics`, `tokenize` | `meridian lint` threads trace through `IndentTokenizer`; lint findings mirror under `.diagnostics`. |
| **Drift** | (hunk classification spans) | `drift`, `verbalizer` | `meridian drift`, `skill-deviation`. |

Post-lower phases run inside `annotateAndStampObligations` and are shared by
`compile(_:)`, `bootstrap(_:)`, and the one-source `compile(meridianSource:…)` wrapper.

#### Diagnostics mirroring

Every `Diagnostic` the `DiagnosticEngine` reports is mirrored into the
`.diagnostics` stream (`severity code @range: message`, plus suggestion/note
lines) and counted in the timing profile. A full trace therefore shows exactly
where each error/warning fired. See
[06_DEVELOPER_EXPERIENCE.md](06_DEVELOPER_EXPERIENCE.md) for the diagnostics
surface itself.

#### Trace acceptance matrix

The closeout acceptance target is that a developer can follow the whole
compile-time pipeline with `--trace` and no silent gaps:

| Stage | Category | Accepted evidence |
|---|---|---|
| Tokenize | `tokenize` | Line/fence/table/checklist/heading decisions are visible. |
| Parse | `parse`, `statement`, `expression`, `phrase.parse` | Top-level parse spans, statement dispatch, expression production decisions, and phrase-pattern tokenization are visible. |
| Phrase resolution | `phrase.match`, `phrase.args`, `phrase.inline` | Candidate scoring, argument extraction, and phrase body expansion are visible. |
| Lower | `lowering`, `rulebook`, `skill` | AST-to-IR decisions, rule classification, section-role routing, deontic norms, and opt-in fallback warnings are visible. |
| Post-lower | `timing`, `codegen` | `domainDecl`, `traceIdentity.*`, `obligationStamp`, `manifestRules`, `obligationDocument` phases and summary lines are visible when `.timing` or `.codegen` is enabled. |
| Validate | `validation`, `diagnostics` | Structured diagnostics (including recovery summaries) are mirrored with codes; `IRValidator` spans appear before emission. |
| Emit | `codegen` | Swift, manifest, domain, multi-file, and IR-sidecar emission decisions are visible. Trace text is redacted before it is written. |
| Verbalize | `verbalizer` | `meridian explain` and any API caller using `Verbalizer.verbalize()` can trace per-workflow and per-primitive canonical source generation. |
| Lint | `diagnostics`, `tokenize` | `meridian lint` opens a `lint <file>` span, threads tokenizer decisions, and mirrors lint findings. |
| Multi-source | `timing`, `parse` | `compile (N file(s))` top-level span and per-file `parse <file>` phases appear under `.timing`. |
| Drift | `drift` | `meridian drift` and `skill-deviation` can trace authored-vs-canonical hunk classification. |

---

### Shared singleton

```swift
ParserTrace.shared   // the global default instance
```

At init time, `ParserTrace` reads `MERIDIAN_TRACE` from the environment and
auto-enables categories. This means tests that set `MERIDIAN_TRACE` in the
environment will also get trace output unless they use an isolated instance.

#### Task-local threading

Compiler components do **not** take a `trace:` parameter. The active trace is a
task-local, `ParserTrace.current`, which defaults to `ParserTrace.shared`:

```swift
@TaskLocal public static var current: ParserTrace = .shared
```

There are exactly two injection points:

- **`Compiler.Options.trace`** — every `Compiler` entry point (`compile(_:)`,
  `bootstrap(_:)`, `emit(workflows:)`, `emitManifest(_:)`) installs
  `options.trace` as `ParserTrace.current` for the duration of the call, so the
  whole pipeline (parse → lower → emit) sees it without threading.
- **`trace.run { … }`** — wraps a direct API call (a parser/emitter/linter used
  outside a compile) so the components inside read `trace` from the task-local:

  ```swift
  try trace.run { try Verbalizer(model: model).verbalize() }
  ```

`@TaskLocal` values are inherited by child tasks, so `await`ed work inside a
compile sees the same trace. `Task.detached` does not inherit; nothing in the
compiler detaches (detached work falls back to `.shared`, which is silent
unless activated).

Hot paths (`IndentTokenizer.tokenize`, `StatementParser` entry points,
`ExpressionParser.parse`, `ASTToIR.lowerWorkflow`, `SwiftEmitter.emit`,
`DiagnosticEngine.report`) read `ParserTrace.current` once per entry call into
a local rather than per loop iteration.

---

### API

#### Enabling / disabling categories

```swift
let trace = ParserTrace.shared

// Enable by passing an array of Category enum cases
trace.enable([.phraseMatch])
trace.enable([.phrase])           // enables all phrase.* leaves
trace.enable(Category.allCases)  // enable everything

// Enable by parsing a comma/space string (same as CLI --trace)
trace.enable(parsing: "phrase.match,lowering")
trace.enable(parsing: "all")

// Disable everything
trace.disableAll()

// Check
trace.isEnabled(.phraseInline)    // → Bool
```

#### Logging

```swift
// Single log line (no-op when category disabled — no string allocation)
trace.log(.phraseMatch, "no candidates found for \"\(invocation)\"")

// Key/value detail line (indented under current scope)
trace.detail(.phraseMatch, "score", "\(score)")

// Scoped span (push/pop — delegates to openSpan/closeSpan)
let token = trace.push(.phraseInline, "inlining: \"\(phrase.signature)\"")
defer { trace.pop(token) }

// Structured spans (same nesting as push/pop; optional JSONL via outputFormat)
let span = trace.openSpan(.validation, "validate workflows", range: workflow.sourceRange)
defer { trace.closeSpan(span, outcome: .success) }
// ... everything logged here is indented one level deeper

// Pop with a result message
trace.pop(token, "→ \(resultCount) primitives")
```

#### Capturing (for tests)

`capturing` is a **static factory**, not a throwing closure. It returns a
`(trace, lines)` tuple:

```swift
let cap = ParserTrace.capturing(categories: [.phraseMatch])

// Compile-driving tests: pass cap.trace through Compiler.Options — the compile
// installs it as the task-local for the whole pipeline.
let out = try Compiler(options: .init(trace: cap.trace)).compile(
    meridianSource: mer,
    meridianFile: "test.meridian",
    merconfigSource: cfg,
    merconfigFile: "test.merconfig"
)

// Direct-API tests: wrap the call so the component reads the captured trace.
_ = cap.trace.run { PhrasePatternParser().parse("validate an order") }

// read captured lines after the call
let lines = cap.lines()
// lines: [String] — every line emitted in the .phraseMatch category
```

**Important:** `capturing()` does NOT take a trailing closure. Pass `cap.trace`
into the compiler (or wrap the call in `cap.trace.run { … }`), then call
`cap.lines()` afterwards. An async variant of `run` exists for `await`ed
bodies.

#### Silence (for tests)

```swift
let trace = ParserTrace.silent()   // never logs, sink goes to /dev/null
```

A compile that does not capture anything can simply omit `trace:` — the default
`.shared` is silent unless `MERIDIAN_TRACE` is set. Production compiler and CLI
paths must not hardcode `.silent()` because that drops a
caller's `--trace`/`--trace-file` request. The only approved production-source
exceptions are probe/benchmark paths listed in
[`coverage/SILENT_FALLBACK_ALLOWLIST.md`](coverage/SILENT_FALLBACK_ALLOWLIST.md):
`TrialLowering`, `InertYieldAnalyzer`, and `ParserBenchmark`.

---

### Sink configuration

```swift
// Default: write to stderr
trace.sink = .stderr

// Write to stdout
trace.sink = .stdout

// Write to a file
trace.sink = .file(URL(fileURLWithPath: "/tmp/meridian.log"))

// Custom handler (used internally by `capturing`)
trace.sink = .custom { line in myLogger.debug(line) }
```

CLI sink setup is validated up front. An unknown category token is a hard
`MER2010` diagnostic with did-you-mean guidance and exit 1. An unwritable
`--trace-file` path is a hard `MER5011` diagnostic and exit 1. If a file sink is
created successfully but later becomes unwritable mid-stream, `ParserTrace`
emits a visible `MER5011` warning line to stderr, writes the current trace line
there, and switches the sink to stderr for the rest of the command.

Trace emission redacts obvious secret-bearing strings before writing to any
sink: `Authorization` headers, bearer tokens, `password=...`, `api_key=...`,
`apiKey=...`, and `secret=...` style fields are replaced with `<redacted>`.

---

### CLI integration

Every subcommand that runs the compiler or migration pipeline creates a fresh
`ParserTrace()` per invocation (via the shared `makeCLITrace(spec:file:)`
bootstrap in `CLISupport.swift`), configures it, passes it to
`Compiler.Options.trace`, and wraps any direct-API work in `trace.run { … }`.
`compile`, `check`, `verify`, `run`, `migrate-skill`, `preview-skill`,
`explain`, `drift`, `inert-yield`, `skill-deviation`, and `lint` ALL accept
`--trace`, `--trace-file`, and `--trace-format` (full parity — none are
`--trace`-only).
`meridian trace categories` lists the valid category tokens:

```swift
let traceInstance = ParserTrace()
if let spec = trace { traceInstance.enable(parsing: spec) }
if let path = traceFile { traceInstance.sink = .file(URL(fileURLWithPath: path)) }

let opts = Compiler.Options(
    emitterOptions: SwiftEmitter.Options(…),
    trace: traceInstance
)

// Direct-API work outside a compile (verbalizer, drift, lint, preview, …):
try traceInstance.run { try Verbalizer(model: model).verbalize() }
```

This does NOT touch `ParserTrace.shared` — each CLI invocation gets its own
isolated instance.

```bash
# Trace available on compile/check/verify/run and analysis/migration commands
meridian check examples/order_processing.meridian --trace phrase.match
meridian verify examples/order_processing.meridian --trace lowering
meridian run examples/order_processing.meridian --trace all
meridian migrate-skill SKILL.md --trace skill --trace-file /tmp/migrate.log
meridian preview-skill SKILL.md --trace skill
meridian explain skill.meri --trace verbalizer
meridian drift skill.meri --trace verbalizer,drift
meridian inert-yield sample-gbrain/skills --batch --trace skill,lowering
meridian skill-deviation original/SKILL.md ported.meri --trace drift

# Lint: tokenizer + lint findings under diagnostics/tokenize
meridian lint examples/dx/fixtures/lint_polite_uncertainty.meridian --trace diagnostics,tokenize

# --trace-file redirects to a file instead of stderr, on every one of the above
meridian check examples/order_processing.meridian --trace all --trace-file /tmp/check.log
meridian compile order.meridian --trace validation --trace-format jsonl

# MERIDIAN_TRACE env alone is enough — correlation id still announced on stderr
MERIDIAN_TRACE=lowering meridian check order.meridian
```

`--trace-format` accepts `text` (default) or `jsonl`. When tracing is active —
whether from `--trace` **or** from `MERIDIAN_TRACE` read at `ParserTrace()`
init — the CLI prints one stderr line with the trace **correlation id**; JSONL
records carry the same value in `"corr"`.

```
trace correlation id: 6F2E4A1B-… (JSONL records include "corr")
```

`makeCLITrace` calls `announceCLITrace` whenever at least one category is
enabled after init, so env-only activation gets the same banner as an explicit
`--trace` flag.

---

### Injecting a trace

Compiler components read the task-local `ParserTrace.current`; none take a
`trace:` parameter. Two ways to inject one:

```swift
// 1. The compile scope — covers parse → lower → emit for the whole call.
let compiler = Compiler(options: .init(trace: trace))
try compiler.compile(unit)

// 2. Direct API calls outside a compile — wrap the call.
try trace.run { try Verbalizer(model: model).verbalize() }
try trace.run { try SkillMigrator(compiler: compiler, vocabularies: vocabs).migrate(markdown, file: "skill.meri") }
trace.run { SkillMarkdownImporter().preview(markdown, name: "…") }
trace.run { DriftEngine.diff(authored: authored, canonical: canonical) }
```

`DiagnosticEngine()` and every parser/emitter/lowerer read `ParserTrace.current`
at their entry call, so an engine constructed inside a compile scope sees the
compile's trace. `SkillMigrator` and `SkillMarkdownImporter` log under `.skill`
(`migrate "file.meri": …`) and never force `.silent()` — a caller's
`--trace`/`--trace-file` request is always honored (wrap the call in `run {}`
when invoking them directly rather than through a compile).

In unit tests you can pass an explicit `ParserTrace()` through
`Compiler.Options`, or `ParserTrace.silent()` (or just the silent default) to
suppress all output.

---

### Adding a new trace point

1. If needed, add a new leaf case to `ParserTrace.Category` with a
   `rawValue` string in `group.leaf` format.
2. Call `trace.log(.yourCategory, "…")`, `trace.detail(…)`, or
   `trace.push/pop` in the relevant method.
3. Add a test using `ParserTrace.capturing(categories:)` to assert the output.

---

### Output format

#### Text (default)

Each line is prefixed with the category name:

```
[phrase.match] ▶ matchPhrase: "validate the order"
[phrase.match]   → candidate: "validate an order" (score: 3)
[phrase.match] ◀ winner: "validate an order"
[phrase.args]  ▶ extractArgs for "validate an order"
[phrase.args]     param order ← "the order" → "order"
[phrase.args]  ◀ done
```

`▶` opens a scope, `◀` closes it (with optional result). Indent is two
spaces per nesting level.

#### Structured spans (`openSpan` / `closeSpan`)

`push`/`pop` delegate to `openSpan`/`closeSpan`. Prefer the structured API
when you need correlation metadata or optional source ranges:

```swift
let span = trace.openSpan(.validation, "validate workflows", range: workflow.sourceRange)
defer { trace.closeSpan(span, outcome: .success) }
```

- **Zero-cost when disabled.** `openSpan`, `closeSpan`, `log`, and `detail`
  return immediately when the category is off — no string allocation, no sink
  I/O.
- **Per-thread nesting.** Span stacks and indent levels are keyed by
  `ObjectIdentifier(Thread.current)`; concurrent compiles on one trace instance
  stay balanced (`ParserTraceSpanConcurrencyTests`).
- **`.validation` category.** `IRValidator` opens/closes validation spans before
  `Verbalizer` / `SwiftEmitter` run; enable `--trace validation` to see
  per-workflow validation scopes and failure summaries.

Each `ParserTrace` instance gets a stable **`correlationID`** (UUID) for the
whole command. CLI commands print it once to stderr when tracing is active
(`--trace` or `MERIDIAN_TRACE`):

```
trace correlation id: 6F2E4A1B-… (JSONL records include "corr")
```

Use the correlation id to join stderr diagnostics, a `--trace-file` text log,
and a `--trace-format jsonl` stream from the same invocation. Filter JSONL with
`jq 'select(.corr == "<uuid>")'`.

#### JSONL (`--trace-format jsonl`)

`--trace-format jsonl` (or `trace.outputFormat = .jsonl`) emits one JSON object
per record. Keys (sorted in output):

| Key | Meaning |
|---|---|
| `seq` | Monotonic sequence number within the trace instance |
| `corr` | Correlation id (matches `ParserTrace.correlationID` / stderr banner) |
| `span` | Span id (uint64) |
| `parent` | Parent span id, when nested |
| `cat` | Category raw value (e.g. `validation`, `lowering`, `verbalizer`) |
| `kind` | `open`, `event`, or `close` |
| `op` | Operation label on `open` records (e.g. `validate workflows`, `workflow AuditOrder`) |
| `outcome` | `success` or `failure` on `close` records |
| `msg` | Human message (redacted; text format uses `▶`/`◀` prefixes here) |
| `range` | Optional `SourceRange` object (`file`, `startLine`, `startColumn`, `endLine`, `endColumn`) |

Record kinds:

- **`open`** — span start; has `op`, optional `range`, optional `parent`.
- **`event`** — `log`/`detail` line inside a span; `msg` carries the payload.
- **`close`** — span end; has `outcome` and optional result `msg`.

```bash
meridian check order.meridian --trace validation,lowering --trace-format jsonl 2>/dev/null \
  | jq -c 'select(.kind == "open" and .cat == "validation")'
```

---

### Strict-by-default fallback policy

Meridian's compile-time default is **strict**: unresolved phrases, unparseable
rules, unattached rules, unresolved trigger actions, and unknown tools all
surface as hard errors — never silent placeholders. Deontic norms (`must` /
`must not` / `may`) and obligation/trace-identity stamping are also strict; an
unlowerable deontic condition is `MER-DEO-007`, not a dropped guard.

**Opt-in escape hatches** (every use is visible):

| Mechanism | Scope | Effect |
|---|---|---|
| Frontmatter `allow-fallbacks: <kinds>` | Per `.meridian` / `.meri` file | Enables named `FallbackKind` values only for that file. Unknown tokens → `MER2009`. |
| `Compiler.Options.fallbackPolicy = .lenient` | Process-wide (hosts/tests) | Allows all `FallbackKind` cases. |
| `migrate-skill --route-fuzzy` | Migration only | Downgrades some operational sections to `(( role: reference ))` with `MER6003` warning — not a compile fallback. |

`FallbackKind` tokens (comma-separated in frontmatter):

- `unresolved-phrases` — emit `_unresolved` bind instead of `MER2001`
- `unparseable-rules` — drop unclassified rules from IR (still in manifest)
- `unattached-rules` — drop rules that don't attach to any workflow surface
- `unresolved-trigger-actions` — document trigger body instead of executing
- `unknown-tools` — emit unrecognized tool id for host-provided runtime tools

Shorthand: `all`, `*`, or `lenient` in frontmatter enables every kind.

When a fallback fires, the compiler emits a **warning diagnostic** at the site
and a `.lowering` trace line naming the kind — never a silent substitution.
See [06_DEVELOPER_EXPERIENCE.md](06_DEVELOPER_EXPERIENCE.md) §6 for the full
no-silent-fallback table and [coverage/SILENT_FALLBACK_ALLOWLIST.md](coverage/SILENT_FALLBACK_ALLOWLIST.md)
for the machine-checked allowlist of intentional silent paths.

---

### Troubleshooting: "I got MERxxxx — how do I debug with trace?"

Use this cookbook to pick categories and commands. Fixtures live under
`examples/dx/fixtures/` (see `examples/dx/README.md`).

#### Parse / structural (`MER1001`–`MER1012`, `MER3018`)

```bash
CFG=examples/dx/dx.merconfig
meridian check examples/dx/fixtures/match_branch_missing_colon.meridian \
  --merconfig "$CFG" --trace statement,parse,diagnostics
```

Expect `[diagnostics]` lines mirroring `MER1012` with the source range, plus
`[statement]` dispatch showing which production handled (or rejected) the line.

#### Phrase match / name resolution (`MER2001`, `MER2002`, `MER2004`)

```bash
meridian check examples/dx/fixtures/misspelled_tool.meridian \
  --merconfig examples/dx/dx.merconfig \
  --trace phrase.match,phrase.args,lowering,diagnostics
```

`phrase.match` shows candidate scoring; `diagnostics` mirrors `MER2002` with
did-you-mean notes. For property typos use `misspelled_property.meridian` with
the same flags — lowering may also log symbol lookup under `.lowering`.

#### Lowering / rules / deontic (`MER1004`, `MER-DEO-*`, `MER3016`)

```bash
meridian check skill.meri --trace lowering,rulebook,diagnostics --trace-format jsonl \
  2>trace-banner.txt | jq -c 'select(.cat == "lowering")'
```

`MER-DEO-007` (`deontic unlowerable condition`) means a `must hold` or
`only where` clause could not lower to checkable IR — there is no opt-in
fallback; reword the condition or use an assertion/adjective the lowering
pipeline supports.

#### Temporal / trace surface (`MER-TMP-*`)

```bash
meridian check workflow.meridian --trace expression,lowering,diagnostics
```

Expression parsing for `has ever`, `since the last`, `usually`, and statistical
forms logs under `.expression`; lowering failures for unsupported `since` state
predicates surface as `MER-TMP-019` before codegen.

#### Norm ids / post-lower (`MER-DEO-006`, `MER-TMP-020`)

```bash
meridian compile skill.meri --trace timing,codegen,diagnostics 2>&1 | rg 'norm|traceIdentity'
```

Post-lower phases stamp `OBL-…` ids and annotate trace-capture policy.
`MER-DEO-006` is a strict collision on norm id prefixes;
`MER-TMP-020` means a production trace capture policy is missing from
`.merconfig`.

#### Codegen / validation (`MER4002`, `MER-TMP-019`)

```bash
meridian compile skill.meri --trace validation,codegen,diagnostics
```

`IRValidator` opens per-workflow `.validation` spans before `SwiftEmitter` /
`Verbalizer`; malformed IR never reaches best-effort output.

#### Verbalizer / explain (`MER4002`, `MER5010`)

```bash
meridian explain examples/dx/fixtures/match_branch_valid.meridian \
  --merconfig examples/dx/dx.merconfig \
  --trace verbalizer,validation,diagnostics --trace-file /tmp/explain-trace.log
```

Per-workflow `▶ workflow …` spans and per-primitive labels show which IR node
failed verbalization.

#### Lint-only (`MER6001`–`MER6003`, `MER3014`)

```bash
meridian lint examples/dx/fixtures/lint_polite_uncertainty.meridian \
  --trace diagnostics,tokenize
meridian lint examples/dx/fixtures/anaphora_ambiguous.meridian \
  --trace diagnostics
```

Lint does not run lowering; trace stays in tokenizer + lint span + diagnostic
mirror.

#### Batch recovery (`MER6004`)

```bash
meridian check examples/dx/fixtures/recovery_multi_error.meridian \
  --merconfig examples/dx/dx.merconfig --trace diagnostics,statement
```

After multiple errors, `[diagnostics]` includes a `MER6004` recovery summary
with skipped construct ranges.

#### Joining streams

1. Note the `trace correlation id:` line on stderr.
2. Filter JSONL: `jq 'select(.corr == "<uuid>" and .kind == "event")' trace.jsonl`
3. Cross-reference `diagnostics` category lines — every rendered diagnostic is
   mirrored with `severity code @range: message`.

Full matrix: [coverage/DX_TRACE_DIAGNOSTIC_MATRIX.md](coverage/DX_TRACE_DIAGNOSTIC_MATRIX.md).

---

### End-to-end observability chain

Compile-time traces, manifest source maps, runtime events, and semantic trace
records connect as follows (see also [06_DEVELOPER_EXPERIENCE.md](06_DEVELOPER_EXPERIENCE.md) §8):

```
meridian compile --trace … --trace-format jsonl
  → ParserTrace.correlationID (stderr banner + JSONL "corr")
  → Compiler.sourceMap source map (meridian line ↔ generated Swift line)
meridian run …
  → Runtime.runID (Event "run_id", TraceRecord "run")
  → stable step paths (TraceRecord "step", Event payload "step")
  → JSONLObserver Event JSONL (execution tree; meridian trace render)
  → TraceStore TraceRecord JSONL (semantic history; trace eval / verify)
```

`--trace` does **not** enable semantic `TraceStore` capture — that requires
`=== trace ===` in `.merconfig` and host wiring. The correlation id ties one
compile invocation's `ParserTrace` stream together; the manifest source map
bridges compile positions to runtime `source` fields on events and trace rows.

---

### Semantic trace replay (Wave 8)

When a `.merconfig` declares `=== trace ===`, generated workflows emit
`runtimeTraceConfiguration` and the host wires a `TraceStore` into `Runtime`.
Temporal/statistical conditions in generated Swift call
`runtime.evaluateTemporal` / `evaluateStatistical` (delegating to
`TraceEvaluator`).

| CLI command | Purpose |
|---|---|
| `meridian trace eval <jsonl> "<expr>" --at <iso8601>` | Evaluate a trace expression against a retained JSONL file |
| `meridian trace verify <jsonl> --run <id>` | Verify checksum integrity and ordering for a run |
| `meridian trace drift <jsonl> …` | Compare expected vs actual trace outcomes |
| `meridian bench-trace` | Performance baseline for trace evaluation |
| `meridian trace render <events.jsonl>` | Pretty-print legacy **event** JSONL (not semantic trace JSONL) |

Author-facing surface and store semantics: [04_RUNTIME.md](04_RUNTIME.md).
Codegen conventions: [02_ARCHITECTURE.md](02_ARCHITECTURE.md) §"Wave 8 trace and monitor codegen".

---

## Verbalizer and drift — full reference

*Was `docs/18_VERBALIZER.md` (Wave 7).*

Wave 7 adds V, the deterministic verbalizer for Meridian's lowered model. V
prints Canonical English from compiled IR so humans can audit what the compiler
actually understood, compare authored prose to the canonical form, and prove
that the printed form can be compiled back to the same structure.

The normative canonical surface oracle is
[`cookbook/MERIDIAN_SYNTAX_COOKBOOK.md`](cookbook/MERIDIAN_SYNTAX_COOKBOOK.md).
Wave 8 extends that same verbalizer surface to temporal/statistical conditions
and the compound-note form; the operational runtime semantics for those forms
live in [`04_RUNTIME.md`](04_RUNTIME.md).

---

### What V Is

V is a compiler-side pretty-printer over the same semantic model used for
Swift emission:

```swift
let unit = Compiler.CompilationUnit(
    sources: [Compiler.SourceInput(source: source, file: "skill.meri")],
    vocabularies: vocabularies,
    rulebooks: rulebooks
)
let model = try Compiler(options: .init()).compile(unit)["skill.meri"]!.model
let canonical = try Verbalizer(model: model).verbalize()
```

It is intentionally boring:

- It prints lowered workflows, inline definitions, frontmatter needed to reparse
  the model, and the statement/expression surface for every IR primitive.
- It canonicalizes equivalent authoring forms to one stable spelling.
- It uses the real `SymbolTable`, `EnglishLexicon`, rulebooks, triggers, scoped
  tools, and lowered definitions. It does not reconstruct these from shape
  heuristics.
- It is total over the in-scope Wave 7 IR surface. In-scope cases must produce
  concrete source text, never placeholders or unfinished markers.

### What V Is Not

V is not a natural-language paraphraser, a source formatter, or a reversible
Markdown serializer. It does not preserve comments, documentary reference
sections, heading prose, or the author's exact phrasing. It is also not a proof
that an original `SKILL.md` meant the same thing as the compiled model; it is a
proof of what the compiled model is.

Use `meridian explain` when you want the canonical compiled meaning. Use
`meridian drift` when you want a line-oriented audit of how far the authoring
surface is from that canonical form. For trace-backed replay or runtime
semantics, use `meridian trace eval` / `trace-eval` and the Wave 8 trace docs,
not the verbalizer alone.

---

### Round-Trip Law

The governing Wave 7 law is `SEM-8-03`:

```text
compile(source) -> model A
verbalize(model A) -> canonical source
compile(canonical source) -> model B
assert structurallyEqual(A, B)
```

The equality oracle is IR structural equality, not byte-for-byte source
equality. Source locations, file names, comments, formatting, and documentation
that never lowers to IR are ignored. Semantic fields are compared: workflow
names/parameters, primitive cases, tool ids, bindings, expressions, branch and
loop bodies, wait/recover/commit payloads, AI judgment/autonomy payloads, and
lowered definitions.

The tests also assert a fixpoint for representative corpus files:

```text
verbalize(compile(verbalize(compile(source)))) == verbalize(compile(source))
```

That second law makes canonical output stable enough for reviews and drift
baselines.

---

### Canonicalization Policy

Canonical English is a normalized audit surface, not the only accepted source
surface.

| Authored surface | Canonical policy |
|---|---|
| Comparison synonyms such as `exceeds` | Print the core comparator, e.g. `is more than`. |
| Rulebook desugars such as `Check:` / `Publish:` | Print the lowered statement, e.g. `assert ...` / `emit ...`. |
| Phrase invocations backed by vocabulary | Prefer the declared phrase pattern when the invocation can be inverted. |
| Direct tool calls | Print `invoke <toolID> with ...` when no phrase inversion is available. |
| `let ... be ...` | Print canonical `bind ... = ...`. |
| Markdown data tables | Print explicit `!!! table (( data: name ))` plus a table. |
| Judgment/autonomy prose | Print the explicit `use judgment to ...:` / `with autonomy ...:` boundary. |
| Comments/reference/template prose | Omit from canonical IR output unless it participates in the lowered model. |
| Fenced template holes `{ expr }` | Re-emit B7 double-brace `{{ expr }}`; shell holes stay single `{…}`. |
| Match-branch wildcards `_` | Print canonical `anything`. |

Canonicalization is allowed to change spelling, punctuation, and layout. It must
not change the lowered structure.

---

### Match-branch (`branch on`)

`BranchCondition.match` is a third branch modality alongside predicate `if` /
`otherwise`. Canonical English:

```text
branch on choice:
  "yes":
    complete.
  approved:
    complete.
  anything:
    complete.
  otherwise:
    complete.
```

Patterns are string literals, bare enum identifiers, or the FixedGrammar
wildcard labels (`anything` / `_`; Verbalizer always emits `anything`). The
optional `otherwise:` arm is IR `BranchIR.thenBlock` and codegen emits it as
Swift `default:`.

Authored ordinary skills rarely emit this surface today; the Verbalizer and
`matchBranchIRRoundTrip` lock the IR ↔ Canonical English round-trip. Structural
markers (`branch on`, wildcards, template directives) live in `FixedGrammar`
and are shared by parser and Verbalizer.

---

### Formatting Policy

The verbalizer owns source formatting for Canonical English:

- two-space indentation under workflow and block headers;
- one statement per line unless the canonical form is inherently block-shaped;
- terminal periods on single-line statements;
- comma-terminated headers for branches, loops, and `otherwise`;
- fenced blocks for multi-line interpolated strings;
- stable frontmatter list rendering for triggers/tools/vocabulary-like fields.

This is separate from `meridian format`, which is a conservative formatter for
authored source files. `meridian format` preserves the author's surface; V emits
the compiler's canonical surface.

---

### Invoke And Phrase Inversion

Lowering erases some phrase-level syntax: a phrase invocation may inline into
several primitives, and a direct tool call is just `InvokeIR(toolID:args:)`.
V reconstructs the most readable surface it can:

1. If an `InvokeIR` corresponds to a declared phrase or workflow pattern,
   `InvokeInverter` prints that phrase surface with arguments rendered through
   the expression verbalizer.
2. If no phrase pattern can be recovered, V prints the direct tool form:
   `invoke <toolID> with key = value`.
3. Shell commands get the command-surface spelling:
   `` `command` -- optional comment. ``
4. If an invoke has a result binding, V prints it as `bind <name> = ...`.

Example from `corpora/erp/skills/placeorder.meri`:

```text
bind orders = invoke order.list with status = "open".
for each order in orders,
  bind inventory = invoke inventory.reserve with order = order.
  bind invoice = invoke invoice.create with order = order.
```

This is more explicit than the authored ERP runbook, but it is the exact lowered
meaning that Swift emission will use.

---

### Judgment Verbalization

The AI boundary is explicit in Canonical English. `AIJudgmentIR` prints as:

```text
use judgment to <goal>:
  <optional embedded/guidance lines>
```

`AIAutonomyIR` prints as:

```text
with autonomy until <condition> unless <condition> re-plan after N failures up to M steps, <goal>:
  <optional embedded/guidance lines>
```

No unmarked prose is inferred. Fuzzy Markdown tables/checklists and explicit
`use judgment to ...:` / `with autonomy ...:` markers all lower through the same
typed IR path. Scoped tools and guidance are preserved in the model even when
the canonical printed surface is intentionally concise.

Example from `corpora/incident/skills/triagealert.meri`:

```text
otherwise,
  use judgment to classify the alert and recommend a response, weighing its severity and service name before escalating:
```

---

### Drift Categories

`DriftEngine.diff(authored:canonical:)` compares authored source to canonical
source line by line and classifies each changed hunk:

| Category | Meaning | Example |
|---|---|---|
| `synonymCanonicalized` | The canonical side uses a known normalized marker. | Authored `exceeds`; canonical `is more than`. |
| `structureNormalized` | Only spacing/structural layout changed. | Extra indentation or whitespace collapses to canonical indentation. |
| `desugarExpanded` | A compact rulebook or idiom form expanded. | Authored `do A and B`; canonical prints two statements. |
| `meaningBearing` | The line changed in a way the simple classifier cannot prove cosmetic. | Authored documentation disappears from canonical IR output, or a phrase becomes an explicit invoke. |

The current engine is intentionally conservative. A `meaningBearing` hunk means
"review this", not necessarily "the compiler changed semantics." Sectioned
SKILL files often produce many meaning-bearing hunks because reference/template
documentation is retained in the manifest but omitted from canonical IR source.

Example summary from `corpora/erp/skills/placeorder.meri`:

```text
# Drift: placeorder.meri

## Summary
- Total hunks: 37
- Synonym canonicalized: 6
- Structure normalized: 0
- Desugar expanded: 0
- Meaning-bearing: 31
```

---

### Public API

#### `CompiledFile.model`

Every `Compiler.compile(_:)` result carries the semantic model produced by the
same bootstrap, parse, validation, trigger synthesis, and lowering pass as the
emitted Swift, returned before
Swift emission:

```swift
let compiled = try compiler.compile(unit)[file]!
let model: VerbalizerModel = compiled.model
```

Use it for tooling that needs compiled meaning: verbalization, drift audits,
semantic previews, and future obligation/deontic annotations.

#### `VerbalizerModel`

`VerbalizerModel` carries:

- `workflows`: lowered `IRWorkflow` values;
- `loweredDefinitions` and `inlineDefinitions`;
- `symbols` and `lexicon` used to parse the source;
- `sourceFileName` and `authoredSource`;
- `metadata`, `outline`, `skillSections`, and `toolsUsed`.

It is deliberately richer than `[IRWorkflow]` so Canonical English can print
frontmatter, definitions, trigger-derived context, and invoke/phrase surfaces
with real vocabulary knowledge.

#### `Verbalizer`

`Verbalizer(model:)` exposes:

```swift
public func verbalize() throws -> String
public func verbalize(_ expr: IRExpression) -> String
public func verbalize(_ prim: IRPrimitive) -> String
```

The whole-model overload is the CLI surface. It validates the model's workflows
with `IRValidator` before printing and throws structured `MER4002` diagnostics
for malformed hand-built IR. The expression and primitive overloads are used by
tests, grammar examples, and focused tools.

#### `DriftEngine`

```swift
public enum DriftCategory: String, Sendable {
    case synonymCanonicalized
    case structureNormalized
    case desugarExpanded
    case meaningBearing
}

public struct DriftEngine: Sendable {
    public static func diff(
        authored: String,
        canonical: String,
        trace: ParserTrace = .shared
    ) -> DriftReport
}
```

`DriftReport.counts` aggregates category counts. `meridian drift --json` emits a
stable JSON shape for scripts; the default output is Markdown.

---

### CLI

Print Canonical English:

```bash
meridian explain sample-gbrain/skills/capture.meri \
  --merconfig sample-gbrain/brain.merconfig \
  --rulebook sample-gbrain/brain.merrules
```

Compare authored source with Canonical English:

```bash
meridian drift corpora/erp/skills/placeorder.meri \
  --merconfig corpora/erp/erp.merconfig \
  --rulebook corpora/erp/erp.merrules

meridian drift corpora/erp/skills/placeorder.meri \
  --merconfig corpora/erp/erp.merconfig \
  --rulebook corpora/erp/erp.merrules \
  --json
```

Both `explain` and `drift` accept `--trace` / `--trace-file`. Use
`--trace verbalizer` to follow canonical emission, and `--trace drift` to follow
hunk classification.

Print the canonical grammar reference generated from `GrammarTable`:

```bash
meridian grammar-doc
```

Diagnostic explanations use the renamed command:

```bash
meridian explain-diag MER2002
meridian explain-diag D-DX-5
```

---

### Worked Examples

#### 1. `sample-gbrain/skills/capture.meri`

`capture` is documentation-heavy: most original sections are `reference` or
`template`, and the executable content is mostly shell-command examples. The
canonical form therefore collapses to the executable workflow:

```text
To capture a input:
  assert not (Don't try to bulk-import dozens of files by looping over `gbrain capture`. That's what `gbrain sync` (or `gbrain import`) is for. Capture is for single thoughts, single notes, single transcripts).
  `gbrain capture "the thought I want to remember"`.
  `gbrain capture --file ./notes/today.md`.
  `echo "from a pipe" | gbrain capture --stdin`.
```

This is a useful audit case: it shows exactly which formerly narrative lines
became executable and which documentary sections are absent from canonical IR
source. The omitted documentation is still available through the manifest's
section records; it is just not part of the lowered workflow.

#### 2. `corpora/erp/skills/placeorder.meri`

The authored ERP runbook uses corpus-specific aliases:

```text
Step: `ofbiz order-check --queue open --json` to snapshot the open order queue.
fetch open orders.
Check: all orders have a number.
Check: at most 5 orders whose total amount exceeds the high value threshold.
```

Canonical English expands those aliases and synonyms:

```text
To place order:
  `ofbiz order-check --queue open --json` -- snapshot the open order queue.
  bind orders = invoke order.list with status = "open".
  assert all orders have a number.
  assert at most 5 orders whose totalAmount is more than the high value threshold.
```

The SEM-8-03 law says this explicit canonical version must compile back to the
same IR as the authored runbook.

#### 3. `corpora/incident/skills/triagealert.meri`

This skill mixes deterministic handling with judgment routing:

```text
To triage alert:
  assert any alerts whose status equals "firing".
  bind alerts = invoke alert.list with status = "firing".
  for each alert in alerts,
    if alert is critical,
      bind oncallEngineer = invoke page.send with alert = alert.
      wait for signal "alert.acknowledged".
    otherwise,
      use judgment to classify the alert and recommend a response, weighing its severity and service name before escalating:
  emit incident.report with message = "alert triage pass complete".
```

The judgment line remains visibly marked. Reviewers can see that clear critical
alerts page deterministically, while borderline alerts cross the planner
boundary only at the explicit `use judgment` step.

---

### Test And Evidence Gates

Wave 7 coverage includes:

- `SEM-8-03` corpus round-trip over sample-gbrain and all corpora fixtures;
- byte-identical canonical fixpoint tests for representative files;
- totality tests over every `IRPrimitive` and `IRExpression` variant;
- seeded generative expression/primitive round trips;
- `COOK-*` cookbook forms for the published canonical surface;
- ambiguity/no-placeholder tests for representative examples and corpora;
- named complex E2E locks (`VerbalizerEndToEndTests`) plus CLI capture/triagealert
  zero-drift (`drift --json` → `total == 0`);
- `matchBranchIRRoundTrip` for `branch on` / `anything` / `otherwise:`.

### Out Of Scope

Wave 7 deliberately did not include temporal/statistical operators; Wave 8 now
does. Wave 9 deontic/obligation operators are in scope. Still out of scope:

- an LLM canonicalization/proposal tool;
- source-preserving Markdown/documentation round-trips;
- generated Swift -> Meridian verbalization;
- localization or alternate natural languages;
- proof that authored prose outside the lowered IR was semantically equivalent.
