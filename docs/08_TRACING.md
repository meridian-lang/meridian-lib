# Meridian — Parser Tracing

`ParserTrace` (in `Sources/MeridianCore/Diagnostics/ParserTrace.swift`) is an
opt-in, category-scoped diagnostic logger for compile-time compiler/tooling
work: tokenization, parsing, lowering, validation, codegen, verbalization, and
drift analysis. It is lightweight enough to ship in production builds; it does
nothing unless at least one category is enabled.

This is separate from runtime execution telemetry. `ParserTrace` answers "what
did the compiler do while understanding and emitting this file?" Runtime JSONL
events answer "what happened while the generated workflow ran?" The bridge is
the generated source map: `compileWithManifest` records source anchors, runtime
observers write JSONL events with those anchors, and `meridian trace render`
turns that runtime event stream into an execution tree. `trace render` does not
render `ParserTrace` logs, and `--trace` does not enable runtime JSONL capture.

---

## Activation

Three ways to activate tracing:

```bash
# CLI flag (comma or space separated)
meridian compile src.meridian --trace phrase.match,lowering

# Environment variable (read at ParserTrace.init() time)
MERIDIAN_TRACE=phrase,lowering meridian compile src.meridian
MERIDIAN_TRACE=all swift test

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
| `.drift` | `drift` | Authored-vs-canonical drift hunk classification |
| `.diagnostics` | `diagnostics` | Every emitted diagnostic (errors/warnings/notes) |
| `.timing` | `timing` | Per-phase wall-clock timing + end-of-compile profile (**off by default**) |

Enable group `phrase` to get all four `phrase.*` categories at once.
Enable `all` to get everything.

### Timing & the compile profile

`Compiler.compileWithManifest` wraps the whole pipeline in a top-level `compile`
span and times each phase (`symbols`, `parse`, `lower`, `codegen`) via
`trace.phase(_:)`. At end-of-compile it emits a profile under `.timing`:

```
[timing] ── compile profile ──
[timing]   symbols                  1.20 ms  ( 8.0%)
[timing]   parse                    6.40 ms  (42.7%)
[timing]   lower                    4.10 ms  (27.3%)
[timing]   codegen                  3.30 ms  (22.0%)
[timing]   total                   15.00 ms
[timing]   diagnostics emitted: 0
```

`.timing` is **off by default** and is excluded from `capturing()` assertions so
trace tests remain deterministic. Enable it explicitly with `--trace timing`
(or `all`).

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
| Lower | `lowering`, `rulebook`, `skill` | AST-to-IR decisions, rule classification, section-role routing, and fallback warnings are visible. |
| Validate | `diagnostics` | Structured diagnostics, including recovery summaries, are mirrored with codes. |
| Emit | `codegen` | Swift, manifest, and domain emission decisions are visible. Trace text is redacted before it is written. |
| Verbalize | `verbalizer` | `meridian explain` and any API caller using `Verbalizer.verbalize()` can trace canonical source generation. |
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

// Scoped span (push/pop)
let token = trace.push(.phraseInline, "inlining: \"\(phrase.signature)\"")
defer { trace.pop(token) }
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
`explain`, `drift`, `inert-yield`, and `skill-deviation` ALL accept both
`--trace` and `--trace-file` (full parity — none of them are `--trace`-only).
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

# --trace-file redirects to a file instead of stderr, on every one of the above
meridian check examples/order_processing.meridian --trace all --trace-file /tmp/check.log
```

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
try SwiftEmitter(options: emitterOpts, trace: trace).emitFile(workflows: workflows, …)
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
