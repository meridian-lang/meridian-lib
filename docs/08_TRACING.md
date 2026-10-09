# Meridian — Tracing

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
see [19_TRACES_AND_TIME.md](19_TRACES_AND_TIME.md).

The bridge from compile to run for all three layers is the generated source map:
`Compiler.compile(_:)` records source anchors; runtime observers and trace stores
carry them forward.

---

## Activation

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

## Categories

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

### Timing & the compile profile

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

### Compile phase map

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

### Diagnostics mirroring

Every `Diagnostic` the `DiagnosticEngine` reports is mirrored into the
`.diagnostics` stream (`severity code @range: message`, plus suggestion/note
lines) and counted in the timing profile. A full trace therefore shows exactly
where each error/warning fired. See
[14_DEVELOPER_EXPERIENCE.md](14_DEVELOPER_EXPERIENCE.md) for the diagnostics
surface itself.

### Trace acceptance matrix

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

## Shared singleton

```swift
ParserTrace.shared   // the global default instance
```

At init time, `ParserTrace` reads `MERIDIAN_TRACE` from the environment and
auto-enables categories. This means tests that set `MERIDIAN_TRACE` in the
environment will also get trace output unless they use an isolated instance.

All compiler components accept `trace: ParserTrace = .shared` in their
initialiser.

---

## API

### Enabling / disabling categories

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

### Logging

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

### Capturing (for tests)

`capturing` is a **static factory**, not a throwing closure. It returns a
`(trace, lines)` tuple:

```swift
let cap = ParserTrace.capturing(categories: [.phraseMatch])

// pass cap.trace to the compiler
let out = try Compiler(options: .init(trace: cap.trace)).compile(
    meridianSource: mer,
    meridianFile: "test.meridian",
    merconfigSource: cfg,
    merconfigFile: "test.merconfig"
)

// read captured lines after compilation
let lines = cap.lines()
// lines: [String] — every line emitted in the .phraseMatch category
```

**Important:** `capturing()` does NOT take a trailing closure. Pass `cap.trace`
into the compiler, then call `cap.lines()` afterwards.

### Silence (for tests)

```swift
let trace = ParserTrace.silent()   // never logs, sink goes to /dev/null
```

Pass this to compiler stages in unit tests where trace output is noise. Production
compiler and CLI paths must not hardcode `.silent()` because that drops a
caller's `--trace`/`--trace-file` request. The only approved production-source
exceptions are probe/benchmark paths listed in
[`coverage/SILENT_FALLBACK_ALLOWLIST.md`](coverage/SILENT_FALLBACK_ALLOWLIST.md):
`TrialLowering`, `InertYieldAnalyzer`, and `ParserBenchmark`.

---

## Sink configuration

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

## CLI integration

Every subcommand that runs the compiler or migration pipeline creates a fresh
`ParserTrace()` per invocation (via the shared `makeCLITrace(spec:file:)`
bootstrap in `CLISupport.swift`), configures it, then passes it down.
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

## Passing trace through the compiler

Every major compiler component accepts `trace` as a constructor parameter
with a default of `.shared`:

```swift
MerConfigParser(trace: trace).parse(source, file: "ecommerce.merconfig")
MeridianParser(symbols: st, trace: trace).parse(source, file: "order.meridian")
StatementParser(symbols: st, trace: trace).parseBlock(lines)
ExpressionParser(symbols: st, trace: trace).parse(text)
try ASTToIR(symbols: st, sourceFile: "order.meridian", trace: trace).lower(file)
try SwiftEmitter(options: emitterOpts, trace: trace).emit(workflows: workflows, …)
try ManifestEmitter(trace: trace).emit(…)
try SkillMigrator(compiler: compiler, vocabularies: vocabs, trace: trace).migrate(markdown, file: "skill.meri")
SkillMarkdownImporter(trace: trace).preview(markdown, name: "…")
try Verbalizer(model: model, trace: trace).verbalize()
DriftEngine.diff(authored: authored, canonical: canonical, trace: trace)
```

`SkillMigrator` and `SkillMarkdownImporter` default `trace` to the owning
`Compiler`'s trace / `.shared` respectively — never to `.silent()` — so a
caller's `--trace`/`--trace-file` request is always honored, logged under the
`.skill` category (`migrate "file.meri": …`).

In unit tests you can pass an explicit `ParserTrace()` per test, or
`ParserTrace.silent()` to suppress all output.

---

## Adding a new trace point

1. If needed, add a new leaf case to `ParserTrace.Category` with a
   `rawValue` string in `group.leaf` format.
2. Call `trace.log(.yourCategory, "…")`, `trace.detail(…)`, or
   `trace.push/pop` in the relevant method.
3. Add a test using `ParserTrace.capturing(categories:)` to assert the output.

---

## Output format

### Text (default)

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

### Structured spans (`openSpan` / `closeSpan`)

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

### JSONL (`--trace-format jsonl`)

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

## Strict-by-default fallback policy

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
See [14_DEVELOPER_EXPERIENCE.md](14_DEVELOPER_EXPERIENCE.md) §6 for the full
no-silent-fallback table and [coverage/SILENT_FALLBACK_ALLOWLIST.md](coverage/SILENT_FALLBACK_ALLOWLIST.md)
for the machine-checked allowlist of intentional silent paths.

---

## Troubleshooting: "I got MERxxxx — how do I debug with trace?"

Use this cookbook to pick categories and commands. Fixtures live under
`examples/dx/fixtures/` (see `examples/dx/README.md`).

### Parse / structural (`MER1001`–`MER1012`, `MER3018`)

```bash
CFG=examples/dx/dx.merconfig
meridian check examples/dx/fixtures/match_branch_missing_colon.meridian \
  --merconfig "$CFG" --trace statement,parse,diagnostics
```

Expect `[diagnostics]` lines mirroring `MER1012` with the source range, plus
`[statement]` dispatch showing which production handled (or rejected) the line.

### Phrase match / name resolution (`MER2001`, `MER2002`, `MER2004`)

```bash
meridian check examples/dx/fixtures/misspelled_tool.meridian \
  --merconfig examples/dx/dx.merconfig \
  --trace phrase.match,phrase.args,lowering,diagnostics
```

`phrase.match` shows candidate scoring; `diagnostics` mirrors `MER2002` with
did-you-mean notes. For property typos use `misspelled_property.meridian` with
the same flags — lowering may also log symbol lookup under `.lowering`.

### Lowering / rules / deontic (`MER1004`, `MER-DEO-*`, `MER3016`)

```bash
meridian check skill.meri --trace lowering,rulebook,diagnostics --trace-format jsonl \
  2>trace-banner.txt | jq -c 'select(.cat == "lowering")'
```

`MER-DEO-007` (`deontic unlowerable condition`) means a `must hold` or
`only where` clause could not lower to checkable IR — there is no opt-in
fallback; reword the condition or use an assertion/adjective the lowering
pipeline supports.

### Temporal / trace surface (`MER-TMP-*`)

```bash
meridian check workflow.meridian --trace expression,lowering,diagnostics
```

Expression parsing for `has ever`, `since the last`, `usually`, and statistical
forms logs under `.expression`; lowering failures for unsupported `since` state
predicates surface as `MER-TMP-019` before codegen.

### Norm ids / post-lower (`MER-DEO-006`, `MER-TMP-020`)

```bash
meridian compile skill.meri --trace timing,codegen,diagnostics 2>&1 | rg 'norm|traceIdentity'
```

Post-lower phases stamp `OBL-…` ids and annotate trace-capture policy.
`MER-DEO-006` is a strict collision on norm id prefixes;
`MER-TMP-020` means a production trace capture policy is missing from
`.merconfig`.

### Codegen / validation (`MER4002`, `MER-TMP-019`)

```bash
meridian compile skill.meri --trace validation,codegen,diagnostics
```

`IRValidator` opens per-workflow `.validation` spans before `SwiftEmitter` /
`Verbalizer`; malformed IR never reaches best-effort output.

### Verbalizer / explain (`MER4002`, `MER5010`)

```bash
meridian explain examples/dx/fixtures/match_branch_valid.meridian \
  --merconfig examples/dx/dx.merconfig \
  --trace verbalizer,validation,diagnostics --trace-file /tmp/explain-trace.log
```

Per-workflow `▶ workflow …` spans and per-primitive labels show which IR node
failed verbalization.

### Lint-only (`MER6001`–`MER6003`, `MER3014`)

```bash
meridian lint examples/dx/fixtures/lint_polite_uncertainty.meridian \
  --trace diagnostics,tokenize
meridian lint examples/dx/fixtures/anaphora_ambiguous.meridian \
  --trace diagnostics
```

Lint does not run lowering; trace stays in tokenizer + lint span + diagnostic
mirror.

### Batch recovery (`MER6004`)

```bash
meridian check examples/dx/fixtures/recovery_multi_error.meridian \
  --merconfig examples/dx/dx.merconfig --trace diagnostics,statement
```

After multiple errors, `[diagnostics]` includes a `MER6004` recovery summary
with skipped construct ranges.

### Joining streams

1. Note the `trace correlation id:` line on stderr.
2. Filter JSONL: `jq 'select(.corr == "<uuid>" and .kind == "event")' trace.jsonl`
3. Cross-reference `diagnostics` category lines — every rendered diagnostic is
   mirrored with `severity code @range: message`.

Full matrix: [coverage/DX_TRACE_DIAGNOSTIC_MATRIX.md](coverage/DX_TRACE_DIAGNOSTIC_MATRIX.md).

---

## End-to-end observability chain

Compile-time traces, manifest source maps, runtime events, and semantic trace
records connect as follows (see also [14_DEVELOPER_EXPERIENCE.md](14_DEVELOPER_EXPERIENCE.md) §8):

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

## Semantic trace replay (Wave 8)

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

Author-facing surface and store semantics: [19_TRACES_AND_TIME.md](19_TRACES_AND_TIME.md).
Codegen conventions: [05_CODEGEN.md](05_CODEGEN.md) §"Wave 8 trace and monitor codegen".
