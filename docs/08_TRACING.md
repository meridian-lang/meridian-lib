# Meridian — Parser Tracing

`ParserTrace` (in `Sources/MeridianCore/Diagnostics/ParserTrace.swift`) is an
opt-in, category-scoped diagnostic logger for the compiler frontend.
It is lightweight enough to ship in production builds; it does nothing unless
at least one category is enabled.

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

Pass this to compiler stages in unit tests where trace output is noise.

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

---

## CLI integration

`CompileCommand` creates a fresh `ParserTrace()` per compilation (via the shared
`makeCLITrace` bootstrap in `CLISupport.swift`), configures it, then passes it
through `Compiler.Options`. `compile` accepts both `--trace` and `--trace-file`;
`check`, `verify`, and `run` accept `--trace` (all routed through the same
bootstrap). `meridian trace categories` lists the valid category tokens:

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
# Trace available on compile, check, verify, and run
meridian check examples/order_processing.meridian --trace phrase.match
meridian verify examples/order_processing.meridian --trace lowering
meridian run examples/order_processing.meridian --trace all
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
ASTToIR(symbols: st, sourceFile: "order.meridian", trace: trace).lower(file)
```

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
