# AGENTS.md — Meridian AI Contributor Handbook

This file is the single source of truth for any AI agent working on this
codebase. Keep it accurate. Update it whenever you introduce a new pattern,
make a significant architectural decision, fix a non-obvious bug, or change
a convention. Do not summarise — prefer specific, actionable details.

**Self-update rule:** After any substantive implementation session, append a
new entry under `## Recent decisions` and update the relevant section if the
change affects ongoing norms.

---

## Table of contents

1. [Project overview](#1-project-overview)
2. [Repository layout](#2-repository-layout)
3. [Development norms](#3-development-norms)
4. [Phase-gate rule](#4-phase-gate-rule)
5. [Compiler architecture quick reference](#5-compiler-architecture-quick-reference)
6. [IR primitives reference](#6-ir-primitives-reference)
7. [Codegen conventions](#7-codegen-conventions)
8. [Runtime conventions](#8-runtime-conventions)
9. [ParserTrace conventions](#9-parsertrace-conventions)
10. [Testing conventions](#10-testing-conventions)
11. [Known sharp edges and pitfalls](#11-known-sharp-edges-and-pitfalls)
12. [Recent decisions](#12-recent-decisions)

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

```
meridian/
├── Package.swift
├── README.md
├── AGENTS.md                          ← this file (self-updating)
├── IMPLEMENTATION_LOG.md              ← append-only decision log
│
├── Sources/
│   ├── MeridianRuntime/               ← runtime used by generated Swift
│   │   ├── Runtime/                   ← Runtime actor
│   │   ├── Value/                     ← Value enum + ValueCoercion
│   │   ├── State/                     ← State struct
│   │   ├── Comparison/                ← MeridianComparison + NumericConvertible
│   │   └── Protocol/                  ← MeridianWorkflow, MeridianTool
│   │
│   ├── MeridianCore/                  ← the compiler
│   │   ├── Compiler.swift             ← public entry point
│   │   ├── AST/MeridianAST.swift      ← all AST node types
│   │   ├── IR/IRTypes.swift           ← 11 IR primitives + IRExpression
│   │   ├── Parser/
│   │   │   ├── Lexical/
│   │   │   │   ├── IndentTokenizer.swift
│   │   │   │   └── ExpressionParser.swift
│   │   │   └── Productions/
│   │   │       ├── MerConfigParser.swift
│   │   │       ├── MeridianParser.swift
│   │   │       ├── StatementParser.swift
│   │   │       └── PhrasePatternParser.swift
│   │   ├── Symbols/SymbolTable.swift
│   │   ├── Lowering/ASTToIR.swift
│   │   ├── Codegen/
│   │   │   ├── SwiftEmitter.swift
│   │   │   └── ManifestEmitter.swift
│   │   └── Diagnostics/ParserTrace.swift
│   │
│   ├── MeridianCLI/
│   │   └── Commands/         ← one file per subcommand:
│   │       ├── CompileCommand.swift        (compile → Swift + manifest)
│   │       ├── RunCommand.swift            (compile + execute via SwiftPM)
│   │       ├── CheckCommand.swift          (parse/lower only, diagnostics)
│   │       ├── VerifyCommand.swift         (verify generated output)
│   │       ├── ResumeCommand.swift         (resume from checkpoint)
│   │       ├── TestCommand.swift           (.meridian.test runner)
│   │       ├── FormatCommand.swift         (swift-format wrapper)
│   │       ├── DocsCommand.swift           (emit docs)
│   │       ├── LintCommand.swift           (MeridianLinter)
│   │       ├── TraceRenderCommand.swift    (render ParserTrace logs)
│   │       ├── PreviewSkillCommand.swift   (SkillMarkdownImporter preview)
│   │       ├── MigrateSkillCommand.swift   (SKILL.md → .meri, marking pass)
│   │       └── SkillDeviationCommand.swift (audit .meri vs SKILL.md, difflib)
│   │
│   ├── MeridianTools/                 ← built-in tools (Phase 6)
│   ├── MeridianTestKit/               ← test helpers (Phase 6)
│   └── SampleDemoFlows/               ← hand-written Phase 1 reference flows
│       ├── OrderProcessingDemo/
│       └── EcommerceWorkflows/
│
├── Tests/
│   ├── MeridianCoreTests/
│   │   ├── SwiftEmitterTests.swift    ← codegen golden strings
│   │   ├── ParserTraceTests.swift     ← trace facility
│   │   ├── Phase3ForcingFunction.swift ← end-to-end compile + assert
│   │   ├── SymbolTableTests.swift
│   │   ├── ExpressionParserTests.swift
│   │   ├── StatementParserTests.swift
│   │   └── ASTToIRTests.swift
│   └── MeridianRuntimeTests/
│
├── examples/
│   ├── ecommerce.merconfig
│   ├── order_processing.meridian
│   └── golden/
│       └── OrderProcessing.expected.swift
│
├── docs/
│   ├── README.md                      ← doc index
│   ├── 01_OVERVIEW.md
│   ├── 02_ARCHITECTURE.md
│   ├── 03_LANGUAGE_QUICK_REFERENCE.md
│   ├── 04_COMPILER_PIPELINE.md
│   ├── 05_CODEGEN.md
│   ├── 06_RUNTIME.md
│   ├── 07_CLI.md
│   ├── 08_TRACING.md
│   ├── 09_MERIDIAN_TESTS.md
│   ├── 10_BUILTIN_TOOLS.md ← built-in tool catalog (all Blueprint families)
│   └── status.md
│
└── meridian-handoff/                  ← read-only original spec (do not edit)
    └── docs/
        ├── 00_BLUEPRINT.md
        ├── 02_LANGUAGE_REFERENCE.md
        ├── 04_IR_SPEC.md
        ├── 05_CODEGEN_SPEC.md
        ├── 07_RUNTIME_API.md
        ├── 10_BUILD_PLAN.md
        └── 11_DECISIONS.md
```

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
| `trace render` | Render captured `ParserTrace` logs. |
| `preview-skill` | Preview a `SKILL.md` via `SkillMarkdownImporter`. |
| `migrate-skill` | Convert a `SKILL.md` → strict `.meri`. Deterministic marking pass (blockquote preamble; `(( inert, role: invariants/prohibitions ))`, `(( role: procedure ))` for pure-shell unknowns, `(( inert ))` for other unknowns; recognized roles unmarked), then strict-compile. Injects no frontmatter; does NOT strip `skill: true`. `--batch` for a directory. |
| `skill-deviation` | Audit a ported `.meri` vs its original `SKILL.md`: frontmatter delta, tier, similarity, categories (`frontmatter-injected`, `section-marker-added`, `shell-block-routed`, `preamble-blockquoted`), and a `difflib`-faithful unified diff. `--batch --index` regenerates `sample-gbrain/migration-deviations/`. |

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

The user has explicitly stated: *"once impl for a phase is done, don't
automatically start the next phase. First, check if the impl is
comprehensive, give a confidence %. Get to near 100% confidence before
proceeding to the next phase."*

---

## 5. Compiler architecture quick reference

### `SymbolTable.matchPhrase`

- Anchors on the **first significant word** of the invocation.
- Scores candidates by literal-keyword overlap.
- Calls `extractArgs` → `ExpressionParser` on each argument slot.
- `stripPatternSlop` removes leading articles (`a/an/the`) and leading kind
  words (e.g. `reason`) from extracted argument text.
- `findArticle` finds the **earliest** article occurrence (not the last). This
  is a correctness invariant — do not change it.

### `ASTToIR.lowerPhraseInvocation`

1. If the invocation starts with `"invoke "` → `buildInvokeExpr` → `InvokeIR`.
2. If `matchPhrase` returns a result with `workflowStructName != nil` → emit
   `InvokeIR(toolID: "workflow:{StructName}", arguments: ordered by pattern)`.
3. If `matchPhrase` returns a regular phrase → `inlinePhrase` → `lowerBlock`
   (recursion depth-limited to 8).
4. Otherwise → `BindIR(name: "_unresolved")` placeholder.

**Argument substitution order:** sort by descending key length, then use
`wholeWordReplace` (regex `\b…\b`, case-insensitive) for each substitution.
This prevents shorter keys from mangling longer ones.

### `ASTToIR.exprToText`

Do **not** prefix bare identifiers with `"the "`. This was reverted after
causing `state.get("the order.id")` bugs. Identifiers go through as-is.

### `ExpressionParser.parseAtom`

Recognises possessive `'s` chains **without** a leading article. The check is:
```swift
t.contains("'s ") || t.hasSuffix("'s")
```
This was added so `"order's id"` parses as a property access after text
substitution strips the leading article.

### `StatementParser.collectMultiLineCounted`

Returns `(text: String, consumed: Int)`. The `consumed` count tells
`parseBlock` how many additional lines to skip. Always use this (not
`collectMultiLine`) when iterating with an explicit index `i`.

### Multi-line phrase headers

Both `MerConfigParser` and `MeridianParser` call `collectHeaderLines(…)` when
a header line ends with `,` or other non-`:` characters. It keeps appending
continuation lines (at a deeper indent) until one ends with `:`.

### Workflow stub registration

Before lowering, `ASTToIR.lower(_ file:)` calls
`symbols.registerWorkflowPhrase(workflow:)` for every `WorkflowAST`. This
makes all workflows resolvable as phrase invocations within other workflows
(and themselves), enabling self-recursion.

---

## 6. IR primitives reference

All 11 IR primitives live in `Sources/MeridianCore/IR/IRTypes.swift`:

| Primitive | Swift type | Key fields |
|---|---|---|
| `invoke` | `InvokeIR` | `toolID: String`, `arguments: [InvokeArg]`, `resultBinding: String?` |
| `bind` / `rebind` | `BindIR` | `name: String`, `expression: IRExpression`, `isRebind: Bool` (shared type) |
| `branch` | `BranchIR` | `condition: BranchCondition`, `thenBlock: IRBlock`, `elseBlock: IRBlock?` |
| `emit` | `EmitIR` | `eventID: String`, `payload: [EmitField]`, `strict: Bool` |
| `complete` | `CompleteIR` | `reason: String?` |
| `wait` | `WaitIR` | `condition: WaitConditionIR`, `timeout: Duration?` |
| `iterate` | `IterateIR` | `mode: IterateMode`, `body: IRBlock` |
| `assert` | `AssertIR` | `condition: IRExpression`, `message: String?`, `otherwiseAction: IRBlock?` |
| `commit` | `CommitIR` | `label: String?` (optional) |
| `recover` | `RecoverIR` | `pattern: ErrorPattern`, `handler: IRBlock`, `attachedTo: IRBlock` |
| `simultaneously` | `SimultaneouslyIR` | `branches: [IRBlock]` — parallel execution groups |

Key associated enums:
- `BranchCondition`: `.predicate(IRExpression)` or `.match(IRExpression, [BranchCase])`
- `IterateMode`: `.overCollection(parameter:kind:collection:)`, `.whileCondition(IRExpression)`, `.untilCondition(IRExpression)`
- `WaitConditionIR`: `.duration(Duration)`, `.signal(String)`, `.approval(of:by:)`, `.event(String, matching:)`
- `ErrorPattern`: `.anyError`, `.named(String)`, `.typed(KindRef)`, `.predicate(IRExpression)`
- `ExecutionMode`: `.strict` or `.lenient` — carried on `IRWorkflow.mode`

`IRExpression` cases:
- `.literal(IRLiteral)` — string, number, boolean, money, duration, date, dateTime, enumValue
- `.identifierRef(name: String)` — bare name (reads via `state.get`)
- `.propertyAccess(IRExpression, propertyName: String)` — `order.id` (reads via `state.get("order.id")`)
- `.constantRef(name: String)` — named constant (emits `constants.camelName`)
- `.instanceRef(name: String)` — named instance (emits `instances.camelName`)
- `.envVar(name: String)` — `$FOO` env var reference
- `.nowExpression` — current timestamp (`Date()` in plain context, `.date(Date())` in value context)
- `.comparison(IRExpression, ComparisonOp, IRExpression)` — comparison expression
- `.logical(LogicalOp, [IRExpression])` — and/or/not
- `.relationTraversal(IRExpression, relationName: String, target: IRExpression?)` — relation traversal
- `.invocation(InvokeIR)` — inline tool call (rare)

**Workflow invocations** use `InvokeIR` with `toolID: "workflow:{StructName}"`.
`SwiftEmitter` detects the prefix and emits a struct-init call instead of
`runtime.invoke(…)`.

---

## 7. Codegen conventions

### `SwiftEmitter`

- Uses `StringTemplate` (result-builder DSL from `modelhike`).
- Each `emit*` method returns a `StringTemplate`.
- Top-level: `emitFile(…).toString(separator: "\n")`.
- `Ctx` carries indent depth. `.s` is the current indent string. `.in(1)` is
  one level deeper.

### Always escape source-derived strings (`escapeSwiftString`)

Any string that originates from source text and is interpolated into a Swift
`"…"` literal **must** go through `escapeSwiftString` (escapes `\ " \n \r \t`).
This is not optional — an unescaped value with an embedded `"` or newline emits
invalid Swift that compiles to *source* fine but fails `swiftc` (and aborts
swift-format via an uncatchable assertion). Current call sites that must stay
escaped: `skillMetadata` keys/values, `state.get("…")` keys (`emitExpr`
identifier/property), `assert` messages, `complete(reason:)`, emit event IDs,
env-var names, prose-step text, choice prompts, string literals. The YAML
block-scalar `triggers:` value (multi-line) is the canonical regression case.

### Namespacing (`Options.namespaceEnum`)

When set, `emitFile` wraps all generated declarations (domain types,
`Constants`, `Instances`, workflow + trigger structs) in
`public enum <name> { … }`. The file header (imports + private
`meridianStringify`) stays at file scope; module-level `constants`/`instances`
become `private static let` (enums can't hold stored instance properties — each
`run()` still emits its own local `let`, so bare references resolve there).
Indentation inside the enum is intentionally left to swift-format. The
`Compiler`/library default is `nil` (flat — preserves the existing goldens);
the `meridian compile` CLI defaults to `--namespace auto` (PascalCase of the
file stem; `none` disables). This lets independently-generated files share one
Swift module without per-file domain-type collisions.

### Value wrapping (the `emitValueExpr` rule)

Every value placed into a `[String: Value]` dictionary (invoke args, emit
payloads) must be a `Value`. Use `emitValueExpr`:

| Expression type | Emits |
|---|---|
| `.literal(.string("x"))` | `.string("x")` |
| `.literal(.number(n))` | `.number(Decimal(n))` |
| `.nowExpression` | `.date(Date())` |
| `.identifierRef` / `.propertyAccess` | `state.get("key") ?? .null` |
| `.constantRef` | `Value.from(constants.camelName)` |
| `.instanceRef` | `Value.from(instances.camelName)` |
| `.envVar("FOO")` | `.string(ProcessInfo.processInfo.environment["FOO"] ?? "")` |

### Comparison emission

State reads return `Value?`. Never use `<`, `>`, `==` directly on `Value?`.
Always route through `MeridianComparison.*` helpers when either operand may
be a `Value?`. `needsValueComparison(_:)` detects this.

Special: `withinDuration` → `MeridianComparison.isWithin(lhs, rhs)`.

### Constants struct

Always declare as `public struct Constants: Sendable`. Both a module-level
`private let constants = Constants()` and a local `let constants = Constants()`
inside each `run()` are emitted.

### Instances struct

Always declare as `public struct Instances: Sendable`. Each instance property
is a `public let name: Value = .record([…])`. Module-level + local bindings
are both emitted.

### Workflow struct naming

`IRWorkflow.structName(from: name)` — takes significant words (strips articles)
up to the first preposition-introducing-a-parameter.

### Source-line comments

Emitted by default. Each IR primitive gets a `// L{lineNumber}` comment on its
own line above it. Disable with `SwiftEmitter.Options(emitSourceLineComments: false)`.

### Recursive workflow calls

`emitWorkflowCall` emits:
```swift
_ = try await StructName(runtime: runtime, arg1: val1, …).run()
```
`emitWorkflowCallArg` uses bare Swift names (not `state.get`) for parameters
because the init signature expects typed domain types.

---

## 8. Runtime conventions

### `Value` enum

All state bindings, invoke arguments, and emit payloads use `Value`.
It is `Sendable` but NOT `Hashable` or `Codable` at the top level.

Full case list:
```swift
case string(String)
case number(Decimal)
case boolean(Bool)
case money(Money)
case duration(Duration)
case date(Date)
case dateTime(Date)               // separate from .date
case enumValue(String, kind: String)
case record([String: Value])
case list([Value])
case reference(String)
case null                          // also exposed as Value.unit
case opaque(AnyHashableSendable)   // type-erasing box
```

Never compare `Value?` with Swift operators. Use `MeridianComparison.*`.

### `Value.from(_:)`

`ValueCoercion.swift` defines overloads for bridging typed Swift values into
`Value`. Add new overloads here if a new typed constant kind is introduced.

### `NumericConvertible`

Protocol for types that can be compared numerically inside `MeridianComparison`.
Currently adopted by: `Decimal`, `Int`, `Double`, `Money`, `Duration`.
Add new numeric types here if needed.

### `State.get` key format

Keys are dot-separated paths that mirror the source property access:
- `"order"` — top-level workflow parameter
- `"order.id"` — nested property
- `"result"` — local bind result

Bind names are **camelCased** from multi-word source names
(`"validation result"` → `"validationResult"`).

### `Runtime.init` signature

```swift
Runtime(
    toolRegistry: ToolRegistry,           // required
    instanceRegistry: InstanceRegistry,   // default .empty
    observer: any Observer,               // default JSONLObserver.stdout
    checkpointer: any Checkpointer,       // default InMemoryCheckpointer()
    clock: any Clock,                     // default SystemClock()
    runID: String,                        // default UUID
    parentRunID: String?,                 // for nested workflows
    parentSequence: Int?,
    maxNestingDepth: Int                  // default 32
)
```

Do NOT use `tools: [String: any MeridianTool]` — that API does not exist.
Tools are registered via `ToolRegistry.Builder`.

### `elapsedMS()` and `eventCount()` are NOT async

Generated code calls these without `await`. They return `Double` and `Int`
respectively.

### `RuntimeApprovalVerdict` has 2 cases

```swift
public enum RuntimeApprovalVerdict: String, Codable, Sendable {
    case approved
    case denied
}
```

The 3-case `ApprovalVerdict` (`.approved`, `.denied`, `.deferred`) is a
domain type generated from vocabulary. They are distinct.

### `Observer` not `EventSink`

The event sink protocol is `Observer` (not `EventSink`):
```swift
public protocol Observer: Sendable {
    func record(_ event: Event) async
}
```
Implementations: `JSONLObserver`, `InMemoryObserver`, `CompositeObserver`.
Use `InMemoryObserver` in tests.

### `Event` not `MeridianEvent`

The event type is `Event`, not `MeridianEvent`. It has 22 `EventKind` cases.
See `docs/06_RUNTIME.md` for the full list.

---

## 9. ParserTrace conventions

### Category hierarchy

Group prefixes enable entire groups. Leaves enable one stream.

| Enum case | Raw value (CLI / env var string) |
|---|---|
| `.phraseParse` | `phrase.parse` |
| `.phraseMatch` | `phrase.match` |
| `.phraseExtractArgs` | `phrase.args` |
| `.phraseInline` | `phrase.inline` |
| `.statement` | `statement` |
| `.expression` | `expression` |
| `.lowering` | `lowering` |
| `.symbols` | `symbols` |
| `.merconfig` | `merconfig` |

### `MERIDIAN_TRACE` env var

`ParserTrace()` reads `MERIDIAN_TRACE` **at init time** and auto-enables
categories. Both `ParserTrace.shared` and fresh `ParserTrace()` instances
read this env var. This means:
- Setting `MERIDIAN_TRACE=all swift test` activates tracing globally for that
  test run.
- Tests that create `ParserTrace()` will inherit env-var activation unless
  they call `disableAll()` explicitly.
- Use `ParserTrace.silent()` in tests that want guaranteed silence regardless
  of env var.

### Thread safety

`ParserTrace` is `@unchecked Sendable` with internal `NSLock` for all mutable
state. It is safe to call `log/push/pop` from concurrent contexts. In unit
tests, prefer a fresh `ParserTrace.capturing(…).trace` per test to avoid
cross-test output mixing.

### Adding a trace point

1. Optionally add a new `Category` case and its `rawValue` string.
2. Call `trace.log(.category, "…")` or `trace.push/pop` in the relevant method.
3. Add a `capturing(categories:)` test to `ParserTraceTests.swift`.

### The `trace` parameter convention

Every compiler component that can produce trace output takes
`trace: ParserTrace = .shared` as a constructor parameter.
- Default is `.shared` (works in production).
- Unit tests pass a fresh `ParserTrace()` or `ParserTrace.silent()`.
- The CLI sets the shared instance's categories and sink in `CompileCommand`.

---

## 10. Testing conventions

### Run all tests

```bash
swift test
```

### Run a single test file

```bash
swift test --filter Phase3ForcingFunction
swift test --filter SwiftEmitterTests
swift test --filter ParserTraceTests
```

### Phase 3 forcing function

`Tests/MeridianCoreTests/Phase3ForcingFunction.swift` — 8 tests that compile
`examples/order_processing.meridian` + `examples/ecommerce.merconfig`
in-process and assert structural correctness. These are the primary regression
gate for the compiler. They must always pass before merging.

### Golden string tests (`SwiftEmitterTests`)

Assert specific substrings (not entire files) against emitted Swift. When
codegen output changes, update the golden strings. Keep assertions minimal —
only test the structural element being introduced.

### Capturing trace in tests

```swift
// capturing() is a static factory — NOT a closure-based API.
// Pass cap.trace to the compiler; call cap.lines() afterwards.
let cap = ParserTrace.capturing(categories: [.phraseMatch])

_ = try Compiler(options: .init(trace: cap.trace)).compile(
    meridianSource: mer,
    meridianFile: "test.meridian",
    merconfigSource: cfg,
    merconfigFile: "test.merconfig"
)

let lines = cap.lines()
#expect(lines.contains { $0.contains("validate an order") })
```

### `#expect` with multi-line diagnostics

Use `Comment(rawValue:)` to pass multi-line failure messages to `#expect`:

```swift
#expect(out.contains("Constants: Sendable"),
    Comment(rawValue: "Expected 'Constants: Sendable' in:\n\(out)"))
```

---

## 11. Known sharp edges and pitfalls

### 1. `findArticle` must pick the earliest article

`PhrasePatternParser.tryParseParam.findArticle` must find the **earliest**
article (`a/an/the`) by position, not by iteration order. An earlier bug
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

---

## 12. Recent decisions

> **Note on `SkillMD-D…` / `B…` references below.** Tags like `SkillMD-D11a`,
> `SkillMD-D17`, `SkillMD-D22`, `B3`, `B6`, etc. that appear in these entries
> (and in tests / code comments) are defined in
> [`.ai/brainstorm-done/skill_md_expressiveness_d1_d28.md`](.ai/brainstorm-done/skill_md_expressiveness_d1_d28.md).
> The `SkillMD-` prefix exists specifically to distinguish them from the
> architectural decision numbering in
> [`meridian-handoff/docs/11_DECISIONS.md`](meridian-handoff/docs/11_DECISIONS.md)
> (which uses bare `D1`–`D30`). Older log entries written before the rename
> may still use the bare form (e.g. `D17`); treat any bare `D<N>` outside
> `meridian-handoff/docs/11_DECISIONS.md` as `SkillMD-D<N>`.

### 2026-06-12 — Wave 2: semantic core (booleans, definitions, quantifiers)

Three closed-grammar surfaces + a shared condition grammar, **no new IR
primitive** (only new `IRExpression`/`ComparisonOp` cases + payload structs).
**2A boolean composition**: precedence `not`>`and`>`or`; Oxford-comma tolerance
(`, and`/`, or` normalized); `it is not the case that X` → `not`; mixed bare
`and`/`or` at one level is a hard error printing both readings — the only
combiner is `either … or`, which `ExpressionParser` protects as an opaque
sentinel (`eitherSentinelPrefix`) before splitting top-level connectives.
**2B definitions**: `Definition: a <kind> is <adj> if <cond>.` (merconfig
vocabulary + `.meri` body; `it`/`its`→subject rewrite in the shared
`DefinitionParser`). Surface adjective names are globally unique (collision =
error); generated helpers are kind-namespaced `meridianDef_<Kind>_<adjCamel>`,
emitted as file-scope `private func`s. `registerDefinitions` runs FIRST (before
any workflow lowers), type-checks bodies (read properties must exist on the
kind), and rejects recursion (DFS over the adjective graph). `X is/is not <adj>`
→ `IRExpression.definitionPredicate` **only when the LHS lowers to
`.identifierRef`** (subject position) — never `.propertyAccess`. **2C
quantifiers** over a description `[quantifier] [adjectives] <kind plural> (whose
<pred> | <have/are body>)?`: `all`/`every` (body required, `allSatisfy`),
`any`/`some`, `no`/`none of`, `at least/at most/exactly N` (`.count <op> N`).
A `whose` clause terminates the description; the collection must be a fetch-once
source (a direct tool invocation is a sourced error). **Shared condition
grammar**: temporal windows (`within the last`/`in the next` →
`ComparisonOp.withinPast/.withinFuture`) and property-backed emptiness
(`has no`/`has a`/`has some`, `is empty`/`is not empty` →
`ComparisonOp.isEmpty/.isNotEmpty` → `MeridianComparison.isEmpty/isNotEmpty`,
the only new runtime helpers). Errors surface via `ExpressionAST.malformed(msg)`
(parser stays non-throwing); `ASTToIR.assertNoMalformed` runs at the top of
`lowerStatement` and walks every expression the statement holds (DFS via
`firstMalformed`), raising the carrier with the statement's line — the
now-`throws` `lowerExpr` also raises on `.malformed` as defense in depth for
non-statement positions (definition bodies, quantifier sub-expressions).
Definitions are recorded in the manifest under **`meridian_definitions`**
(`adjective`/`kind`/`function`/`line`, sorted by `function`, omitted when none).
Tests: `Inform7Wave2Tests` (incl. `at most`/`exactly` parse+emit, manifest,
malformed-condition abort) + `Wave2SpecTests` (3 `.meridian.test` specs run via
`MeridianTestRunner`) + 5 runtime `EmptinessTests`; full `swift test` (679) +
both typecheck gates green.

**New pitfalls — Wave 2.** (1) `lowerExpr` is now `throws`; every caller
(`lowerAutonomyConfig`, `lowerRecoverPattern`, `lowerIterationRefinement`,
`lowerWaitCondition`, test `lower` helpers) must `try`. (2) `qualifyToLoopVar`
must qualify only the **LHS** of a comparison (qualifying both sides was a bug)
and must recurse over `.logical`/`.definitionPredicate` trees. (3) The single-
line `if <cond>, <stmt>.` form is NOT parsed as a branch — `if` requires a
comma-terminated header with an indented body (use the multi-line form in
tests/examples). (4) merconfig property decls need `, which is <type>` (with the
comma) or the bare comma-and list form; `a summary which is text` without the
comma folds the whole phrase into the property name. (5) Adjective resolution
happens at lowering (`symbols` fully populated), not parsing — the parser keeps
modifiers/adjectives as raw `[String]`.

### 2026-06-12 — Wave 1: Inform-7-tier deterministic surface

Four new closed-grammar forms, no new IR primitive (payload/data extensions):
**1A** command annotation (` -- <note>` outside backticks → `InvokeIR.comment` →
`// note` above `shell.run`); **1B** typed command holes (`{ expr }` in a
backticked command, validated against a lightweight scope tracker threaded
through `ASTToIR.lowerBlock`; in-quote holes shell-escaped via
`meridianShellQuote`; `{{`/`}}` literal; unresolved hole = sourced error); **1C**
single-clause iteration refinements (`IterateIR.source`; `[the first N] <plural>
[whose … | within the last N <unit> | in the next N <unit>] [sorted by …]`;
pre-loop filter→sort→prefix via `emitRefinedIterate`/`emitElementExpr`; runtime
helpers `Value.member`, `MeridianComparison.orderedBefore`/`isWithinPast`/
`isWithinFuture`; `LanguageSynonyms.timestampProperty` default `updatedAt`);
**1D** metadata sections (`## Tools Used` bullets `<desc> (<tool_id>)` →
`MeridianFile.toolsUsed` → `scopedTools` + manifest `tools_used`; output
invariant `every emitted <noun> matches pattern "<regex>"` → `AssertIR` over
`meridianRegexMatches`). Surface in `docs/03`, pipeline in `docs/04`, 1A in
`docs/11`. `briefing.meri` re-ported (context-loading procedures + holes, trimmed
judgment block, real Tools Used); corpus inert 692/755→683/747, judgment
17/73→16/67. All 598 tests + `MERIDIAN_GBRAIN_TYPECHECK=1` green.

**New pitfall — block-header vs topic-label precedence.** A capitalized loop
header ending in `:` (`For every attendee:`) matches `StatementParser.topicLabel`
(uppercase, ≤40 chars, letters/spaces). The `for each`/`for every` block-header
check in `parseStatementWithoutRewrite` therefore MUST run before the topic-label
rule (it does, right after the judgment-marker check) — otherwise the header is
read as an empty label and dropped, orphaning the loop body at the top level so
`{loop var}` holes cannot resolve. Do not reorder these. Relatedly,
`parseIteration` must run `extractIterationRefinement` to strip the 1C
refinement clause BEFORE the explicit-collection ` in ` split; otherwise a
temporal `in the next N <unit>` is mis-parsed as an explicit `in {collection}`
and the future window is silently lost.

### 2026-06-11 — Universal deterministic sections (drop `skill: true`, no silent no-ops)

The markdown section-role model is now **universal and structural**. The
`skill: true` frontmatter flag and `SkillFrontmatter.isSkill` are removed; a file
is a *sectioned document* iff its implicit-workflow body contains any `##`/`###`
heading (`hasHeadings`). Heading-less files keep flat-procedure behaviour.

- **Marker family** (`SkillSectionRole.parseMarker`): a single trailing
  `(( inert ))` / `(( inert, role: R ))` / `(( role: R ))` is authoritative — when
  present the heading text is NOT used to derive a role. A non-executable marked
  section overrides even shell-block routing. `SkillSectionRole.isExecutable`
  distinguishes invariants/procedure/applicability/negative-applicability/
  prohibitions (true) from template/inert (false).
- **No silent drops** (`SkillSectionBuilder`, now strict): content before the
  first heading, an unrecognized heading with content, and a non-checkable
  `Contract`/`Anti-Patterns` item are hard `semanticError`s. Markdown blockquote
  (`>`) lines are comments (`IndentTokenizer.isComment`), so SKILL.md asides may
  sit above the first heading. `builtinRole` widened: `Phase N: …` prefix →
  procedure, plus `when to invoke/run/use this` and `output structure`/`brain
  page format`.
- **Mandatory manifest plumbing:** `build` returns `Result.sections:
  [SkillSectionRecord]` recording EVERY section. `MeridianFile.skillSections` →
  `ManifestEmitter.Input.skillSections` → `meridian_skill.sections`.
  `Compiler.compileWithManifest(…) -> (swift, manifest)` assembles the COMPLETE
  `ManifestEmitter.Input`; `compile(…)` delegates to it. `CompileCommand` writes
  the full Input (no `workflows: []` stub).
- **Migrator** (`SkillMigrator.deterministicTransform` → `markSections`) injects
  no frontmatter (`addedFrontmatterKeys` is empty) — section semantics are
  structural and `vocabulary:`/`rulebook:` are autodiscovered by the CLI — but it
  is not a no-op: it runs the deterministic corpus-marking pass (blockquote
  preamble; append `(( inert, role: invariants/prohibitions ))` /
  `(( role: procedure ))` for pure-shell unknowns / `(( inert ))` for other
  unknowns; recognized roles left unmarked). Role recognition uses
  `SkillSectionRole.builtinRole`; idempotent; does NOT strip `skill: true`. This
  is the logic `meridian migrate-skill` runs, ported from the one-off corpus
  script. Tests: `Tests/MeridianCoreTests/SkillMigratorMarkingTests.swift`.
- **Corpus migration:** all 53 `sample-gbrain` skills were migrated — `skill:
  true` stripped, prose `Contract`/`Anti-Patterns` → `(( inert, role: invariants
  / prohibitions ))`, pure-shell unrecognized sections → `(( role: procedure ))`,
  other narrative → `(( inert ))`, preambles blockquoted. The exact inert set was
  computed by compiling each file and inerting only the enclosing heading at each
  located error (keeping pure-shell/resolvable sections executable). 738 inert
  markers, 13 forced-procedure; `compile-outputs/*` (53 swift + 53 manifests) and
  `migration-deviations/*` regenerated; zero `_unresolved`. `examples/skill/skill.merrules`
  supplies organizational aliases for the examples corpus. All 553 tests pass.

### 2026-06-11 — Emitter escaping/sanitization + enum namespacing

A `swiftc -typecheck` gate over the gbrain corpus revealed that "compiles" only
ever meant "Meridian emitted Swift *source* without throwing" — the output was
never parsed as Swift. Hardening, all in `SwiftEmitter`/`EnglishLexicon`/
`DomainEmitter`/`SkillTriggers`:

- **Escape every source-derived string** via `escapeSwiftString`: `skillMetadata`
  keys/values (the YAML block-scalar `triggers:` carries newlines → was raw-
  emitted into a one-line `"…"`, which is invalid Swift *and* aborts swift-format
  uncatchably), `state.get("…")` keys, `assert` messages, `complete(reason:)`,
  emit event IDs, env-var names.
- **`structName(from:)` splits on non-identifier chars** (`webhook-transforms` →
  `WebhookTransforms`); a hyphen previously produced `struct Webhook-transforms`
  → parsed as `struct Webhook` + syntax error (and phantom redeclarations of
  same-stem domain kinds like `Brain`/`Idea`).
- **Trigger struct-name dedup** via `IRWorkflow.explicitStructName` when distinct
  trigger phrases collapse to one name.
- **`DomainEmitter` drops an explicit `id` property** (the `MeridianKind`
  identity `id` is synthesised unconditionally) — no more duplicate `id`.

**Namespacing.** `SwiftEmitter.Options.namespaceEnum: String?` wraps all
generated decls in `public enum <name> { … }` (header + private
`meridianStringify` stay at file scope; module-level `constants`/`instances`
become `private static let`). Library/`Compiler` default is `nil` (flat — keeps
the 20+ goldens); the **`meridian compile` CLI defaults to `--namespace auto`**
(PascalCase of the file stem; `none` disables). Indentation inside the enum is
left to swift-format. `compile` also gained repeatable `--rulebook`
(autodiscovers `.merrules` beside the source). gbrain skills now compile cleanly
into one shared module without domain-type collisions.

**Tests.** New `SampleGbrainTests` target at `sample-gbrain/Tests/` (relocated
smoke + conformance suites; `SampleGbrainCodegenTests` = always-on in-process
string-literal lexer flagging raw newlines in single-line `"…"` literals + the
opt-in `MERIDIAN_GBRAIN_TYPECHECK=1` `swiftc` gate over the namespaced shipped
form). All 53 emitted files type-check against MeridianRuntime; 541/87 green.

### 2026-06-11 — Skill deviation tooling + `compile --rulebook`

Migration of the gbrain corpus is now auditable and reproducible end-to-end.

- **`SkillDeviation`** (`Sources/MeridianCore/Migration/SkillDeviation.swift`) is
  a dependency-free helper that diffs an original `SKILL.md` against its ported
  `.meri`: frontmatter delta (`Added`/`Removed` rendered; `Changed` still
  computed for callers), a unified diff with `--- `/`+++ ` file headers (paths
  come from `originalDiffPath`/`portedDiffPath`, set by the batch command to
  corpus-root-relative paths like `original-skills/<x>/SKILL.md` and
  `skills/<x>.meri`), difflib-style `@@ … @@` hunk headers, added/removed/
  unchanged counts, a similarity ratio, and a deterministic tier (`>=0.85` -> 1
  near-verbatim, `0.5..<0.85` -> 2 light edits, `<0.5` -> 3 rewrite).
  `detectCategories` names exactly what the migrator's marking pass did:
  `frontmatter-injected`, `section-marker-added`, `shell-block-routed`
  (`(( role: procedure ))`), `preamble-blockquoted`. It owns the shared
  `slug(_:)` / `meriStem(forSkillAt:)` pairing helpers.
- **`Difflib.swift`** (`Sources/MeridianCore/Migration/`) is a faithful Swift
  port of CPython's `difflib.SequenceMatcher` + `unified_diff`: `chainB`
  (`autojunk` drops elements appearing > n/100+1 times when `len(b) >= 200`),
  `findLongestMatch`, `matchingBlocks`, `opcodes`, `groupedOpcodes(n=3)`,
  `ratio` (`2*M/(la+lb)`), and `_format_range_unified` (single-line ranges omit
  the count; empty ranges begin one line earlier). `SkillDeviation` computes
  `similarity = ratio`, `added = lb − M`, `removed = la − M`, `unchanged = M`.
  This makes deviation reports byte-for-byte equivalent to the original
  Python-generated corpus (verified: daily 76% +21/-15, academic 93%, ask_user
  89%, RESOLVER 18% +41/-118; tiers 42/10/1). **Do not** swap this back to a
  plain LCS — LCS maximizes total matches and diverges from difflib's
  greedy-longest-block alignment (e.g. RESOLVER differed by a line). Tests:
  `Tests/MeridianCoreTests/SkillDeviationTests.swift`.
- **`meridian skill-deviation`** (`Sources/MeridianCLI/Commands/`) drives it for
  a single pair or a whole corpus (`--batch`, `--out`, `--index`, `--no-diff`).
  Batch discovery pairs `<name>/SKILL.md` and top-level `*.md` (e.g.
  `RESOLVER.md`) with ported `.meri` found recursively; `.meri` are indexed by
  **lowercased** filename stem (NOT slugged — `slug()` drops underscores, which
  would mangle `academic_verify`). Non-skill dirs (`conventions/`, `migrations/`)
  are skipped and counted.
- **`compile --rulebook`** added to `CompileCommand` (repeatable; autodiscovers
  `.merrules` beside the source, parent fallback). Required to compile skill
  files that reference `rulebook:` in frontmatter — this is what makes
  `sample-gbrain/compile-outputs/` reproducible.
- **`sample-gbrain/`** gained three committed folders: `original-skills/` (the
  upstream gbrain `SKILL.md` snapshots), `compile-outputs/` (generated Swift per
  `.meri`, via `compile … --no-format`), and `migration-deviations/` (per-skill
  reports + `README.md` index, all 52 skills + `RESOLVER`). `swift-format`
  asserts on some generated outputs, so compile-outputs are emitted unformatted.

### 2026-06-11 — Phase G: expressive SKILL.md surface + gbrain corpus + rulebooks

The deterministic English surface is now extensible via **rulebooks**
(`.merrules`) and rich enough that a gbrain `SKILL.md` ports to `.meri` with
minimal edits. Zero new IR primitives — only a `detached` flag on
`SimultaneouslyIR` and a `.choice` case on `WaitConditionIR`. Governing rule
unchanged: nothing reaches the LLM unless the author writes `use judgment to
…:` / `with discretion` / `with autonomy`; everything else is deterministic IR
or a hard `semanticError`.

- **Rulebook engine** lives under `Sources/MeridianCore/Rulebook/`
  (`RulebookParser`, `RewriteEngine`) + `Lowering/ConventionInjector.swift`.
  Three external families in `=== desugar ===` / `=== sections ===` /
  `=== conventions ===`. Referenced via the `rulebook:` frontmatter key; loaded
  as `[RulebookInput]`. New `rulebook` trace category. The core default rulebook
  is empty, so non-`rulebook:` files are byte-for-byte unaffected. Docs:
  `docs/11_RULEBOOKS.md`.
- **`SkillFrontmatter`** (`Sources/MeridianCore/Skill/`) is the typed projection
  of `FileMetadataAST`. There is **no `isSkill` / `skill: true`** — the
  section-role model activates **structurally** (`hasHeadings`: any `##`/`###`
  heading). YAML sequences + block scalars are parsed; `tools:` → `scopedTools`;
  parameter-less skills default to a single `input` param (so `brain.merconfig`
  declares `An input is a kind of thing.`).
- **`SkillSectionBuilder`** (`Parser/Skill/`) maps headings → closed
  `SkillSectionRole` (invariants/procedure/applicability/negative-applicability/
  prohibitions/template/inert), **marker-first**: a trailing `(( inert ))` /
  `(( inert, role: R ))` / `(( role: R ))` is authoritative (no heading
  derivation; `SkillSectionRole.parseMarker`). Role is derived from heading text
  **only for unmarked executable sections** — never for inert ones. **A
  non-executable (marked) section overrides shell-block routing**; a shell fence
  under an *executable* section still routes to procedure. **No silent drops:**
  pre-heading content, unrecognized-heading-with-content, and non-checkable
  invariant/prohibition items are hard `semanticError`s. `build` returns a
  `Result` whose `sections: [SkillSectionRecord]` records EVERY section
  (executable or not) for the manifest.
- **Mandatory manifest plumbing:** `MeridianFile.skillSections` →
  `ManifestEmitter.Input.skillSections` → `meridian_skill.sections` (always
  emitted when non-empty). `Compiler.compileWithManifest(…) -> (swift, manifest)`
  builds the COMPLETE `ManifestEmitter.Input`; `compile(…)` calls it and drops
  the manifest. `CompileCommand` writes the full Input (never a `workflows: []`
  stub).
- **Critical parser gate:** in sectioned (`hasHeadings`) docs, `MeridianParser`
  does NOT extract in-body `When …`/`A …`/`An …` rules (those are narrative
  prose) and does NOT reject body-level `import` (a SKILL line may begin with the
  English verb "Import"). Both checks are gated on `!hasHeadings`. Plain
  heading-less `.meridian`/`.meri` files are unaffected.
- **Command surface:** stand-alone fenced ` ```bash `/` ```sh `/` ```shell `
  blocks and inline backticked commands lower to `invoke shell.run with command
  = "…"`. The command is base64-carried through `shellCommandSentinelPrefix`
  (`\u{E000}shell:`) during parsing and decoded in
  `ASTToIR.lowerPhraseInvocation`. One invoke per command line.
- **Choice-gate:** `ask the user to choose between "A", "B".` → emit `ask.choice`
  + `WaitConditionIR.choice(prompt:options:)` + branch. Runtime adds
  `_choiceWaiters` / `_lastChoiceSelection`, `deliverChoice(_:)`, and
  `consumeChoiceSelection()`, reusing the `.signal` continuation plumbing.
- **Background spawn:** `in the background, <stmt>.` →
  `SimultaneouslyIR(detached: true)` → detached `Task {}` (no `waitForAll`).
- **Triggers:** `TriggerClassifier` maps `triggers:` specs to
  keyword/ambient/event/schedule; `TriggerSynthesizer` emits one trigger
  workflow each (`trigger.<name>.fired` fan-out). `sample-gbrain/RESOLVER.meri`
  is the dispatcher.
- **Skillpack compile:** `Compiler.compileSkillpack([SkillpackInput], …)`
  pre-registers every file's workflows as phrase stubs first so cross-file
  invocations resolve. `SymbolTable.registerWorkflowPhrase` appends to the shared
  (reference-type) `phrases` array.
- **`SkillMigrator`** (`Sources/MeridianCore/Migration/`, NOT `Sendable` because
  it holds a `Compiler`) + `meridian migrate-skill`: deterministic frontmatter
  injection → strict compile → bounded repair closure (Core-local
  `(RepairRequest) async throws -> String`, so no Core→Runtime dependency). LLM
  proposes, compiler disposes — a migration is accepted only if it compiles
  strict.
- **Corpus:** `sample-gbrain/` ships `brain.merconfig`, `brain.merrules`, 52
  ported skills + `RESOLVER.meri`, all strict-compiling with zero `_unresolved`.
  Tests: `SampleGbrainSmokeTests` + `SampleGbrainConformanceTests` (full-corpus
  gate, rulebook data-only extensibility, migrator deterministic + mock-LLM
  repair). Porting playbook: `docs/13_SKILL_MD_PORTING.md`. 530 tests green.

**Porting pitfalls codified** (see `docs/13_SKILL_MD_PORTING.md` §"Common
porting fixes"): prose `## Phases` → `use judgment to …:`; mixed prose+CLI →
bash fences + judgment; fuzzy applicability → checkable predicate (avoid `is`
copula / comparison markers in dispatch phrases); ambiguous anaphora → spell out
the referent (the resolver runs on judgment headers); deprecated stub with no
headings → add `## Overview`. Note: `###` sub-headings re-resolve the role, so a
`### Protocol` under an inert `## Entity Detection` becomes procedure again.

### 2026-05-01 — SKILL.md expressiveness SkillMD-D8 to SkillMD-D28 completion

The SKILL.md-shaped surface now covers deterministic labels/chains/anaphora,
plan-mode prose, autonomous loops, and import/lint tooling.

- Topic labels (`Comments: complete.`) are represented by
  `StatementAST.labelled` and emitted as `HeadingEntry(kind: "topic")`.
- `do A, B, and C.` is split into same-indent statements by
  `StatementParser`.
- `SymbolTable.matchPhrase(_:defaultParam:)` performs strict single-parameter
  fill only when a workflow has exactly one parameter.
- `decide whether` emits `runtime.discretion.decide(DiscretionContext(...))`;
  it no longer executes through the `llm.decide` tool.
- `Runtime` exposes typed `Planner`, `ActPlanner`, `Discretion`,
  `LLMProvider`, `PlanPolicy`, and `PlanningResourceLimits` slots. Use
  `Runtime.Builder` when swapping these hooks in tests or hosts.
- `with discretion` lowers unresolved lines to `ProseStepIR(.planThenExecute)`;
  `with autonomy` lowers unresolved lines to `ProseStepIR(.autonomousLoop)`.
  Strict workflows still error on unresolved phrases.
- `Runtime.executeProsePlan` and `Runtime.executeAutonomousLoop` route every
  proposed action through resource limits, host policy, scoped-tool validation,
  and `runtime.invoke`; they write replay checkpoints after accepted actions.
- `MeridianTestKit` includes `MockPlanner`, `ScriptedPlanner`,
  `MockActPlanner`, `MockDiscretion`, `JSONLReplay`, `PlanFuzzer`, and
  `ClockHarness`.
- `SkillMarkdownImporter` powers `meridian preview-skill`; `MeridianLinter`
  powers `meridian lint`.
- `InformRulebookParser` is clean-room and parser-only for now. It recognises
  `before`, `instead of`, `check`, `carry out`, `after`, and `report` phases,
  sorting by Inform-style phase order and preserving source order within phase.

### 2026-05-01 — SKILL.md-shaped Tier 1 surface

Tier 1 SKILL-style syntax is deterministic sugar only:
- `IndentTokenizer` strips markdown list markers (`-`, `*`, `1.`) and records
  `##` / `###` headings as `HeadingEntry` outline metadata.
- `MeridianParser` collects top-level statements into an implicit entry
  workflow when present. The implicit workflow name comes from frontmatter
  `name:` (fallback `entry`); typed parameters come from frontmatter
  `parameters:` and must resolve to imported vocabulary kinds.
- `ManifestEmitter.Input.outline` emits heading entries under
  `meridian_skill.outline`.
- `StatementParser` desugars suffix `only when` / `unless`, leading
  `otherwise <statement>` recover handlers, `every` / `each` loops, and
  `if you decide that` / `unless you decide that` predicates.
- `EnglishLexicon.singularize(_:)` is public and backs `every` / `each`
  singular item names.
- `ASTToIR.lowerPhraseInvocation` adds implicit result bindings only when a
  naked invoke lowers to a single return-valued known tool call with no
  explicit binding. Unknown tools are not auto-bound.

`examples/babysit.meridian` now uses the implicit-entry markdown surface and
still compiles under strict mode with zero `_unresolved` placeholders.

### 2026-04-30 — No-silent-fallback policy (`FallbackPolicy`)

The compiler is **strict by default**. Every previously silent fallback now
raises `CompilerError.semanticError`:

- **Unresolved phrase invocation** (was: `_unresolved` BindIR placeholder).
- **Unparseable rule** (was: silently dropped).
- **Unattached rule** — parsed but matches no workflow (was: silently dropped).
- **Trigger action that doesn't lower** (was: stub comment in trigger body).

Per-file opt-in is via the `.meridian` frontmatter key `allow-fallbacks:`,
with a comma-separated list of kinds:

```
---
allow-fallbacks: unresolved-phrases, unattached-rules
---
```

Or `all` / `*` for everything. The four kinds: `unresolved-phrases`,
`unparseable-rules`, `unattached-rules`, `unresolved-trigger-actions`.

Process-wide opt-in for tests/hosts is `Compiler.Options.fallbackPolicy =
.lenient`. Both opt-ins are OR-merged at compile time.

**Implementation:**
- `Sources/MeridianCore/Diagnostics/FallbackPolicy.swift` — `FallbackKind`
  enum + `FallbackPolicy` struct with `parse(_:)` and `merging(_:)`.
- `Compiler.swift` — reads frontmatter, merges, passes to `ASTToIR`.
- `ASTToIR.lower(_:)` — checks the policy when classifying rules and when
  attaching them. Errors point at the rule's source line.
- `RuleInjector.buildTriggerWorkflow` — re-uses the `lowerAction` closure
  to validate the action resolves; errors point at the rule's line.
- `RuleInjector.workflowAlreadyHandlesApproval` — guards precondition
  injection so workflows with their own approval step don't deadlock on a
  duplicate runtime approval.

### 2026-04-30 — Rule subject/predicate qualification

Filter clauses (`"with status suspended"`) and parameter-guard predicates
(`"whose total amount is more than their credit limit"`) now translate
into qualified property accesses:

- Subject filter: `customer.status == "suspended"` (not bare
  `state.get("with status suspended")`).
- ParameterGuard predicate: `order.totalAmount > customer.creditLimit`
  (bare `total amount` → `order.totalAmount` because the action object is
  "an order"; possessive `their X` → `customer.X` because the rule's
  subject is "a customer").

Implementation lives in `RuleLowering.swift`:
- `parseSubject` extracts subject kind + filter introducer.
- `buildSubjectFilter` parses the filter text recognising shorthand
  comparison phrases (without leading "is", e.g. `more than`).
- `qualifyPredicate` / `qualifyIdentifier` walk parsed predicate
  expressions and prefix bare identifiers / possessive pronouns.
- `extractObjectKind` extracts the noun after an article from action
  object text (e.g. `"place an order"` → `"order"`).

### 2026-04-30 — Trigger workflow body emits a fan-out event

Trigger workflows have no parameters (they wait for an external event),
so we cannot safely lower the rule's action text into a typed
sub-workflow call inside the trigger's scope. Instead, the trigger body
emits `trigger.<eventName>.fired` after the wait. Hosts subscribe to that
event and dispatch the named action with their own parameter resolution.

The compiler still **validates** at compile time that the action text
resolves to a known workflow/phrase by running `lowerAction` and
discarding the result; that's how strict mode catches typos in trigger
actions. Skip validation with `allow-fallbacks: unresolved-trigger-actions`.

### 2026-04-30 — Permission matching has two paths

`RuleInjector.permissionMatches` accepts either:
1. **Actor + verb** — rule subject is the actor and a workflow takes that
   actor as a parameter (e.g. `"a customer may place orders"` against a
   workflow that takes a `customer` parameter and has `place` in its
   name).
2. **Object + verb** — the rule's action text mentions a noun that's a
   workflow parameter and the verb appears in the workflow name (e.g.
   `"an account manager may approve any order"` against
   `"to approve an order"`, which has no `account manager` parameter).

`extractObjectKindForPermission` extracts the noun from the action text
(after an article like "a", "an", "the", "any", "some", "all").

### Earlier:

### 2026-05-01 — Skill corpus goldens + emitter hardening

Every sample under `examples/skill/*.{meridian,meri}` has a checked-in
golden Swift file under `examples/golden/skill/<stem>.expected.swift`. The
companion test in `Tests/MeridianCoreTests/SkillCorpusGoldenTests.swift`
runs a per-sample byte-diff (`MERIDIAN_REGEN_GOLDENS=1` to re-baseline) and,
when `MERIDIAN_GOLDEN_TYPECHECK=1` is set, shells out to `swiftc -typecheck`
to verify the generated Swift compiles against the build's `MeridianRuntime`
module. All 18 corpus goldens type-check.

Codegen / lowering invariants surfaced by the type-check pass and now
encoded in the implementation:

- `SwiftEmitter.emitWorkflowCall` drops the `, ` separator when the invoke
  has no arguments. Swift rejects `Type(runtime: runtime, ).run()`.
- `SymbolTable.extractArgs` keys args by the **phrase pattern's** camelCase
  `param.name` (e.g. `pullRequest`). `ASTToIR.lowerPhraseInvocation` tries
  `p.name`, `p.name.lowercased()`, `p.kind.lowercased()`, and the
  space-stripped variant — first hit wins.
- `ASTToIR.phraseParameters` preserves camelCase param names. An older
  `.lowercased()` here drove `pullRequest` to `pullrequest` and collided
  with the camelCase identifier ref at call sites.
- `SwiftEmitter` threads a `workflowParamTypes: [structName: [(name, kind)]]`
  map and a `typedIdentifiers: Set<String>` through `Ctx`. The map is
  populated at the top of `emitFile`; the set is seeded with the current
  workflow's params in `emitWorkflow`. `emitWorkflowCallArg` wraps
  Value-typed identifier refs in
  `try Value.from(arg).coerce(to: KindName.self)`; typed identifiers pass
  through unchanged.
- `SwiftEmitter.emitFile` substitutes `Value` for any param kind not
  declared in `domainDecl.kinds`. The grammar accepts headers like `to
  plan a ci repair for a pull request` even when `ci repair` isn't a
  declared kind; the fallback keeps the generated init compileable.
- `SymbolTable.overlap` scores `2·matchedLiterals + matchedParamTokens −
  2·unmatchedLiterals`. The unmatched-literal penalty prevents a parent
  workflow stub from shadowing the more focused inner workflow when both
  share several literal tokens with the invocation.
- `StatementParser.parseRecover` strips a surrounding `"…"` or `'…'` pair
  from the name token, so `recover from "planning.host_policy_denied":`
  carries the bare name into the IR.

Authoring tips to avoid the common pitfalls:

1. Don't put a leading `a/an` in front of an action object that isn't a
   declared kind. That triggers parameter parsing and creates an unbound
   call-site identifier. Prefer `to plan careful repair` over `to plan a
   careful repair`.
2. Don't reuse a declared kind name as a workflow name. The struct-name
   collision (`public struct ReviewComment: Hashable, …` vs
   `public struct ReviewComment: MeridianWorkflow`) is a hard error in
   the generated Swift; rename the workflow or the kind.

### 2026-04-30 — Phase 5/6 completion pass

Remaining Phase 5/6 scope implemented: `simultaneously:` source/AST/IR/codegen,
runtime subprocess + HTTP dispatchers, named matching for subprocess/HTTP tool
errors, active resume context via `Runtime.prepareResume(runID:)`, generated
workflow state restore from resume context, and compile-time manifest source-map
writing.

`MeridianTools.registerBuiltins()` now registers the Blueprint tool families
only: `http.get/post/put/delete`, `file.read/write/append`,
`json.parse/stringify/transform`, `regex.match/replace`, `shell.run`,
`mcp.call`, `llm.chat`, `validate.json_schema`, `time.now/format`,
`uuid.generate`. Ecommerce demo tools (`validateOrder`, `chargePayment`, etc.)
are no longer registered as built-ins; tests/examples that need them register
domain tools explicitly in fixtures.

CLI now includes `run`, `verify`, and `resume`. `run` compiles generated Swift
for host-integrated execution rather than dynamically loading Swift in the CLI.
`resume` loads the latest `FilesystemCheckpointer` snapshot and prepares a
runtime resume context. `MeridianTestKit` includes `MockRuntime`,
`MockToolRegistry`, `RecordingTool`, and `GoldenFile`.

### 2026-04-29 — Phrase-only `order_processing.meridian`

`examples/order_processing.meridian` workflow bodies are phrase invocations
only; IR (`bind`/`invoke`/`if`/`wait`/`emit`/`complete`/`in lenient mode`) lives
in new phrase definitions in `examples/ecommerce.merconfig` (fraud screen,
account-manager approval, finalize payment + retry, record analytics).

### 2026-04-29 — `validateImports` with zero vocabularies

If `vocabularies` is empty but the `.meridian` file has any `import`, the
compiler throws `semanticError` for the first import (message still includes
the import token). Empty file + empty vocab remains a no-op.

### 2026-04-29 — Phase 3 sign-off (~99%)

Generated Swift from `order_processing.meridian` compiles, links, and runs.
8 tests in `Phase3ForcingFunction.swift` pass. Zero `_unresolved` placeholders.

Deferred to Phase 4: `Domain.swift` codegen, golden-diff test, round-trip
integration test.

### 2026-04-29 — `ParserTrace` added

Opt-in, category-scoped diagnostic logger. All compiler components take
`trace: ParserTrace = .shared`. CLI exposes `--trace <categories>` and
`--trace-file <path>`. See [docs/08_TRACING.md](docs/08_TRACING.md).

### 2026-04-29 — `MeridianComparison` for Value? comparisons

Swift cannot use `<`, `>`, `==` on `Value?`. All comparisons involving
`Value?` route through `MeridianComparison.{eq,neq,lt,le,gt,ge,isWithin}`.
Helpers in `Sources/MeridianRuntime/Comparison/Comparison.swift`.

### 2026-04-29 — `Instances` struct for named instances

Named instances (e.g. `primary mailer`, `stripe`) are emitted as a
`public struct Instances: Sendable` with `Value = .record([…])` properties.
In-body access is `instances.camelName`. IR has a dedicated
`IRExpression.instanceRef(name:)` case.

### 2026-04-29 — Workflow recursion via phrase stubs

Workflows register themselves as `PhraseDefinition` stubs (with
`workflowStructName` set) before lowering begins. This allows a workflow to
invoke itself or another workflow via the normal phrase-matching path. The
lowered IR uses `InvokeIR(toolID: "workflow:StructName", …)`.

### 2026-04-29 — Documentation created under `docs/`

Full documentation set created. `docs/README.md` is the index. `docs/status.md`
tracks phase progress, and `Tests/README.md` is the testing guide.

---

### 2026-04-30 — Phase 5 completion: wait queues, source-level recover, durable checkpointing

**Wait queues (signal / approval / event):**
- `Runtime` actor stores three queues: `_signalWaiters [String: [Continuation]]`,
  `_approvalWaiters [ApprovalKey: [Continuation]]`, `_eventWaiters [EventWaiterEntry]`.
- `withCheckedThrowingContinuation` closure runs synchronously on the actor executor
  before suspension, so registering into actor-isolated storage is race-free.
- Delivery APIs: `deliverSignal(_:)`, `deliverApproval(of:by:verdict:)`, `deliverEvent(_:)`.
- `emit(event:)` also checks `_eventWaiters` so domain events can wake `.event` waiters.
- `.denied` approval verdict resumes with `MeridianRuntimeError.approvalDenied`.
- `WaitCondition.event` matching predicate is `Optional<@Sendable (Event) -> Bool>`.
- Timeout on signal/approval/event is V2 per spec; parameter is accepted but ignored.

**Source-level recover:**
- `RecoverPatternAST` (any / named / typed / predicate) and `RecoverStatementAST`
  added to `MeridianAST.swift`.
- `StatementAST` is `indirect enum` — `recover` case holds `RecoverStatementAST`
  which contains another `StatementAST` (the attached predecessor).
- `parseRecover` reads the single header line directly (NO `collectMultiLineCounted`
  — that function would greedily absorb body lines as continuation lines).
- `parseBlock` pops the last statement and embeds it as `attached` when a `recover`
  is parsed. Chained recovers nest because the preceding statement IS a recover.
- `lowerRecover` / `lowerRecoverPattern` in `ASTToIR`.

**Recover codegen fix:**
- `.named` pattern now emits `meridianMatches(_recoveredError, named: "…")` via a
  new public free function in `MeridianRuntimeError.swift`; old `.isNamed(…)` was invalid.
- `.approval` codegen emits `RoleRef(identifier:)`, not a bare string.
- `.event` with matching emits `{ _event in … }` closure.

**FilesystemCheckpointer durability:**
- Writes: temp file → `fsync` temp → atomic `rename` → `fsync` directory.
- Per-run advisory lock via `lockf(3)` (not `flock(2)` which clashes with Darwin's
  `flock` struct name). Lock file: `<runDir>/.lock`.

### 2026-04-30 — Phase 5/6 100% completion pass

**SwiftPM execution wrapper and CLI run:**
- `SwiftPMPackageRunner` in `Sources/MeridianCore/Testing` owns temporary
  SwiftPM package creation/manipulation: write `Package.swift`, write sources,
  build, run executables, capture output, and remove or preserve the package.
- `RunCommand` must delegate generated workflow package scaffolding to
  `SwiftPMPackageRunner.writeMeridianRunDriverPackage(...)`; do not reintroduce
  inline `Package.swift` / `Driver.swift` generation in the CLI command.
- Generated run drivers register Blueprint built-ins, apply `--tool-stub`
  overrides, decode `--input-json` workflow parameters, and optionally use
  `FilesystemCheckpointer` via `--checkpoint-root`.

**Replay-safe resume:**
- Generated workflows call `runtime.consumeResumeContext()` once at startup,
  restore `State`, then use `__meridianShouldRun(label)` to skip already
  checkpointed side-effect primitives.
- Codegen emits stable progress labels like `progress:0.1:L4:C1`.
- Implicit checkpoints are emitted after invokes, emits, waits, assertions, and
  loop iteration boundaries. User-labelled `commit` statements are also guarded
  by their label.

**MCP and LLM built-ins:**
- `ToolRegistry` accepts a replaceable `MCPClient` (default:
  `DefaultMCPClient`) and `mcp.call` is registered as `.mcp(MCPSpec())`.
- Default MCP transports: HTTP JSON-RPC (`transport: "http"`, `url`, `method`,
  `params`) and subprocess stdio (`transport: "stdio"`, `binary`, `arguments`,
  `method`, `params`).
- `llm.chat` intentionally throws `llm.not_implemented`; do not convert it to a
  successful placeholder unless the user approves a provider design.

*Last updated: 2026-04-30. Update this file whenever you make a significant
change to architecture, conventions, or known pitfalls.*

### 2026-04-30 — Phase A: EnglishLexicon + lexicon threading

`EnglishLexicon` struct created at `Sources/MeridianCore/Language/EnglishLexicon.swift`.
It centralises articles, prepositions, copulas, participles, participleSuffixes,
comparisonMarkers, durationUnits, and toolStopwords. All compiler components now
accept `lexicon: EnglishLexicon = .default` and use it instead of hardcoded word lists.

Key changes:

- **`EnglishLexicon`** — `parseDuration`, `structName(from:)`, `merging(comparisonSynonyms:durationSynonyms:)`.
- **`LanguageSynonyms`** — new struct in `MeridianAST.swift`; `MerConfigFile` gains `languageSynonyms` field and merges them in `merging(_:)`.
- **`Compiler.Options`** — `lexicon: EnglishLexicon` and `allowUnresolvedPhrases: Bool` added. `compile(meridianSource:meridianFile:vocabularies:)` builds effective lexicon from config synonyms and passes it to every parser/lowerer.
- **`ExpressionParser`** — accepts `lexicon`; `parseDuration` delegates to lexicon; `parseComparison` iterates `lexicon.comparisonMarkers`; `parsePossessiveChain` strips articles from the lexicon set; `parse` now dispatches through `parseLogical → parseAnd → parseNot → parseComparison`, supporting `or`/`and`/`not` logical operators.
- **`StatementParser`** — accepts `lexicon`; `parseWaitCondition` uses `lexicon.parseDuration`; `methodize` uses `lexicon.articles`.
- **`SymbolTable`** — accepts `lexicon` in `build`; `tokenize` uses `lexicon.toolStopwords`; `stripPatternSlop` uses `lexicon.articles`; `tool(fromWords:)` replaced with token-overlap scoring (overlap×2 − extra).
- **`MerConfigParser`** + **`PhrasePatternParser`** — accept `lexicon`; `parseDuration` delegates to lexicon; `connectors`/`participles` in `tryParseParam` come from `lexicon`; `isVerb` check uses `lexicon.participleSuffixes`; new `=== language ===` section parsed into `LanguageSynonyms`.
- **`IRTypes.IRWorkflow`** — `structName(from:lexicon:)` delegates to `lexicon.structName(from:)`; `explicitStructName: String?` and `allowsDiscretion: Bool` added to struct and init.
- **`ASTToIR`** — accepts `lexicon` and `allowUnresolved`; unresolved phrases throw `CompilerError.semanticError` unless `allowUnresolved=true`; `StatementParser` instantiation passes `lexicon`.
- **`MeridianParser`** — accepts `lexicon`; passes it to `PhrasePatternParser` and `StatementParser`.

All 319 tests pass. Phase3ForcingFunction 8/8 pass.

### 2026-04-30 — Comprehensive documentation pass

All 9 existing docs (`01_OVERVIEW` through `09_MERIDIAN_TESTS`) rewritten/expanded
to reflect Phase 0–6 implementation: 11 IR primitives (not 10), `simultaneously`,
all 4 `WaitCondition` variants, `recover` source/IR/codegen, replay-safe resume
semantics (progress labels + `__meridianShouldRun` guard), `prepareResume`/
`consumeResumeContext` APIs, `deliverSignal`/`deliverApproval`/`deliverEvent`,
`FilesystemCheckpointer` durability + fsync + lockf, all CLI subcommands
(`check`, `verify`, `run`, `resume`, `format`, `docs`, `test`, `trace render`),
accurate event kind strings (`invoke.end`, `commit`, `recover.engaged`), and
programmatic `MeridianTestRunner` usage.

New file `docs/10_BUILTIN_TOOLS.md` added as the canonical Blueprint built-in
catalog: tool IDs, dispatch kinds, argument shapes, return shapes, `llm.chat`
deliberate exception, MCP transport configuration, error shapes.

`docs/README.md` updated with the new doc in the reading order table.
`README.md` (root) updated for Phase 0–6 complete status, correct feature list
(11 IR primitives, replay-safe resume, MeridianTestKit), and new quick start
using `meridian run` instead of manual `swift build`.

### 2026-04-30 — Phase B6/B7: fenced code-block literals + `{{ expr }}` interpolation

**B6 — Fenced Markdown code-block string literals:**
- `IndentTokenizer.tokenize` now does a single-pass while-loop over raw lines.
  When a line whose trimmed text starts with ` ``` ` is found, all body lines
  are collected until the matching closing ` ``` `, then the entire fence is
  collapsed into a single synthetic `SourceLine` whose `text` is a sentinel:
  `\u{E000}codeblock:<lang>:<base64-body>`.  The sentinel constant
  `codeBlockSentinelPrefix` is declared at module level in `IndentTokenizer.swift`.
- `ExpressionParser.parseAtom` decodes the sentinel at the top of its dispatch:
  decodes the base64 body and returns `.literal(.string(body))` for plain blocks.
  If the body contains `{{`, it delegates to `parseInterpolationSegments` (B7).
- `StatementParser.parseBindValue` handles two new forms:
  - `"decide using:"` — looks ahead at the next content line; if it is a
    sentinel, decodes the body and returns `.decideWhether(question: body)` with
    `extra = j - i` (consuming the sentinel line). Falls back to empty string.
  - Bare sentinel value — delegates to `exprParser.parseAtom(s)` (safety net for
    future inline-fence support; currently unreachable from the tokenizer).
- `StatementParser.parseStatement` silently skips orphaned sentinel lines
  (return `nil, 1`) so they don't become spurious phrase invocations.
- `StatementParser.decodeCodeBlockBody` — private helper that decodes
  `\u{E000}codeblock:<lang>:<base64>` to the raw body string.
- **Inline fence limitation**: fences that share a line with other tokens
  (e.g. `bind prompt = ```markdown`) are not collapsed by the tokenizer.
  Only stand-alone fence lines are handled.  Documented as future work.

**B7 — `{{ expression }}` interpolation inside code blocks:**
- `InterpolationSegment` enum (`literal(String)` / `expression(ExpressionAST)`)
  added to `MeridianAST.swift`, before `ExpressionAST`.
- `ExpressionAST.interpolatedString([InterpolationSegment])` case added.
- `IRInterpolationSegment` enum added to `IRTypes.swift`; `IRExpression.interpolatedString([IRInterpolationSegment])` case added.
- `ExpressionParser.parseInterpolationSegments(_:)` — scans body for `{{…}}`
  markers.  `\{{` is an escaped literal `{{`.  An unclosed `{{` consumes the
  rest of the body as a literal fragment.  Each expression inside `{{…}}` is
  parsed with `self.parse(exprText)` (full expression support).
- `ASTToIR.lowerExpr` maps `.interpolatedString` → `.interpolatedString` by
  recursively lowering each `.expression` segment.
- `ASTToIR.subExpr` handles `.interpolatedString` by recursing into each
  `.expression` segment for phrase-argument substitution.
- `ASTToIR.exprToText` returns `""` for `.interpolatedString` (no text form).
- `SymbolTable.describeExpr` returns `"interp(N segs)"` for tracing.
- `SwiftEmitter.fileHeader` now emits a `private func meridianStringify(_ v: Value) -> String` helper directly after the imports.  This function converts any `Value` to its human-readable string form (`.string` → raw string, `.number` → decimal, `.boolean` → "true"/"false", `.null` → "", other → `v.description`).
- `SwiftEmitter.emitExpr(.interpolatedString)` — emits `("literal" + meridianStringify(expr) + …)`.
- `SwiftEmitter.emitValueExpr(.interpolatedString)` — emits `.string("literal" + meridianStringify(expr) + …)`.
- `SwiftEmitter.escapeSwiftString` — new private helper that escapes `\`, `"`, `\n`, `\r`, `\t` for use inside Swift double-quoted string literals.  Also applied to `emitLiteral(.string)` and `emitValueLiteral(.string)` to fix a latent multi-line-string bug.
- Golden file `examples/golden/order_processing_expected.swift` regenerated with `MERIDIAN_REGEN_GOLDENS=1` to incorporate the new `meridianStringify` helper in the file header.
- All 343 tests pass.

### 2026-04-30 — Phase B1–B4: frontmatter, goal loops, decide-whether, llm.decide

**B1 — Frontmatter / skill-discovery metadata:**
- `FileMetadataAST` struct added to `MeridianAST.swift` with a `subscript(_ key:)` accessor.
- `MeridianFile` gains `metadata: FileMetadataAST? = nil`.
- `MeridianParser.parse` detects a `---`-delimited block at the top of the file
  (after skipping blanks/comments) and parses it into `FileMetadataAST`. Continuation
  lines (deeper indent) are joined with a space into the preceding entry value.
- `ManifestEmitter.Input` gains `metadata: FileMetadataAST? = nil`. `buildDict`
  emits a `meridian_skill` JSON key whose value is a flat `[String: String]` map
  (hyphen-to-underscore normalised).
- `SwiftEmitter.emitFile` gains `fileMetadata: FileMetadataAST? = nil`.
  `emitWorkflow` gains `skillMetadata: [(String, String)]? = nil`. The first workflow
  struct emits a `public static let skillMetadata: [String: String]` property when
  `fileMetadata` is present.
- `Compiler.compile` passes `ast.metadata` to `emitFile`.

**B2 — Goal-driven loops (`while`/`until`):**
- `IterationModeAST` enum added (`forEach`, `whileCondition`, `untilCondition`).
- `IterationStatementAST` replaced with a `mode: IterationModeAST` design.
  Backward-compat computed properties `variable: String?` and `collection: ExpressionAST?`
  retained for any code that already consumed the forEach fields.
- `StatementParser.parseStatement` handles `while {cond},` and `until {cond},`
  headers (body collected by indent), returning `.iteration` with the appropriate mode.
- `parseIteration` updated to produce `.forEach` mode.
- `ASTToIR.lowerStatement(.iteration)` now switches on `s.mode`; all three cases
  lower to `IterateIR` with the matching `IterateMode` (already supported by codegen
  and `emitIterate`).

**B3 — `decide whether …` statement:**
- `ExpressionAST.decideWhether(question: String)` added.
- `WorkflowAST` gains `allowsDiscretion: Bool = false`.
- `MeridianParser` detects `, with discretion` suffix (case-insensitive) on the
  workflow header and strips it before pattern parsing.
- `StatementParser.parseBindValue` intercepts `decide whether …` before `invoke`,
  returning `.decideWhether(question:)`.
- `ASTToIR.lowerExpr` lowers `.decideWhether` to `.invocation(InvokeIR(toolID: "llm.decide", …))`.
- `subExpr` in `ASTToIR` passes `.decideWhether` through unchanged (no parameter
  substitution needed for a string literal question).
- `ExpressionParser.describe` and `SymbolTable.describeExpr` both handle the new case.

**B4 — `llm.decide` / `llm.judge` built-ins:**
- Both tool IDs added to `MeridianTools.allToolIDs` (count now 21).
- `MeridianTools.invoke` dispatches both to `decideLLM(_:)`, which returns
  `.boolean(false)` deterministically (test-safe; hosts override via `ToolRegistry`).
- `registerBuiltins()` registers both as `.closure` dispatchers.
- `BuiltinToolsTests.toolListIsCanonical` updated: `count == 21`.

### 2026-04-30 — Phase C: Rule lowering and injection (C1–C5)

`RuleAST` is now executable. New files:

- **`Sources/MeridianCore/Lowering/RuleLowering.swift`** — `ParsedRule` enum (5 cases: `invariant`, `parameterGuard`, `precondition`, `trigger`, `permission`) and `RuleAnalyzer` struct. `RuleAnalyzer.classify(_ rule:)` dispatches on "when", "must be…by…before", "must not", "may" patterns. `parseSubject` extracts the subject kind and filter expression from the article-stripped subject phrase.

- **`Sources/MeridianCore/Lowering/RuleInjector.swift`** — `RuleInjector` struct. `inject(rules:into:sourceFile:)` iterates workflows and prepends `AssertIR` (for `invariant`/`parameterGuard`) or `WaitIR` (for `precondition`) when `actionMatches` returns true. `synthesizeTriggers` emits a synthetic `IRWorkflow` per `trigger` rule with a `WaitIR(.event(...))` + a stub `BindIR`. `applyPermissions` softens existing assertions when `permission` rules match (uses `changed` flag tracking instead of a broken `elementsEqual` predicate).

- **`Sources/MeridianRuntime/Permissions/Permission.swift`** — `PermissionScope` and `Permission` value types with `@Sendable` predicate closure.

- **`Sources/MeridianRuntime/Permissions/PermissionRegistry.swift`** — `PermissionRegistry` actor with `register` / `evaluate` methods. `static let empty` provides a default no-op instance.

- **`Sources/MeridianCore/Codegen/ManifestEmitter.swift`** — `RuleManifestEntry` (with `SourceInfo` nested type) added; `Input.rules: [RuleManifestEntry]` (default `[]`); `buildDict` emits `"meridian_rules"` key when rules are present.

**`ASTToIR.lower(_ file:)`** updated: after lowering workflows to IR, calls `RuleAnalyzer.classify` on each `RuleAST`, then `RuleInjector.inject` (prepends guards) and `synthesizeTriggers` (appends trigger workflows).

**Action matching heuristic** (`actionMatches`): token-overlap between the rule's action text and the workflow name after removing combined `toolStopwords ∪ articles ∪ prepositions`. Threshold: `overlap >= 1 && overlap >= actionTokens.count / 2`. This matches "place an order" → "process an order placed by a customer" (overlap=1, threshold=1).

**Golden files regenerated** with `MERIDIAN_REGEN_GOLDENS=1`. `GeneratedOrderProcessing/OrderProcessing.swift` synced to the updated golden (now includes the injected `assert` for the parameter-guard rule).

**7 new tests** in `Tests/MeridianCoreTests/RuleLoweringTests.swift`. **381/381 tests pass.**

### 2026-04-30 — Phase B5: babysit example + Phase 7 forcing function

`examples/github.merconfig` created: pull request, comment, ci run, check kinds
with full property sets (enum merge status, ci run status, etc.) and 10 tool
declarations whose display names are token-overlap-compatible with the
invocations in `babysit.meridian`.

`examples/babysit.meridian` created: four workflows that exercise B1 frontmatter
(`name`, `description`, `when-to-use`, `tools-required`), B2 `until` loops,
B3 `decide whether` and `, with discretion` annotation, and B6 `decide using:`
with an indented fenced code block. All phrases and tools fully resolve (zero
`_unresolved`).

`Tests/MeridianCoreTests/Phase7BabysitForcingFunction.swift`: 6-test forcing
function asserting compilation success, `skillMetadata`, loop construct,
`llm.decide` call, zero `_unresolved`, and `Babysit` struct name.

Tool naming convention for github domain: avoid `" with "` in display names
(e.g. "Sync Branch" not "Sync With Base") since `buildInvokeExpr` splits on the
FIRST ` with ` to separate tool name from arguments. Display names are all 2–4
words matching the corresponding invocation phrase tokens after stopword removal.

**387/387 tests pass.**

### 2026-04-30 — Phase B6 & B7: fenced code-block literals + `{{ }}` interpolation

**B6 — Fenced Markdown code-block string literals:**
- `IndentTokenizer.tokenize` collapses ` ``` … ``` ` fences into a single
  synthetic `SourceLine` whose `text` contains the sentinel
  `"\u{E000}codeblock:<lang>:<base64body>"`. No new fields were added to
  `SourceLine`; the body travels entirely inside the sentinel text.
- Closing fence is recognised as bare ` ``` ` **or** ` ```. ` (with trailing dot).
- `ExpressionParser.parseAtom` decodes the sentinel; returns `.literal(.string(body))`
  for plain bodies and `.interpolatedString([…])` when `{{ }}` markers are present
  (detected during tokenizing — tag is `"interp"` instead of the lang name).
- `decide using:` in `StatementParser.parseBindValue` calls
  `exprParser.parseAtom(l.statement)` so the question carries interpolation
  segments; result is emitted as `.invoke("llm.decide", [("question", expr)])`.
- **Limitation:** inline fences on the same line as an `invoke` (`bind x = invoke
  tool with arg = \`\`\`…\`\`\`.`) are not yet supported (deferred).

**B7 — `{{ expression }}` interpolation inside code blocks:**
- `ExpressionParser.parseInterpolationSegments` splits the decoded body on
  `{{ … }}` markers (handles `\{{` escapes and unclosed `{{`).
- `ASTToIR.lowerExpr(.interpolatedString)` lowers each segment recursively.
- `SwiftEmitter.emitExpr/.emitValueExpr` concatenate literal parts (escaped) with
  `meridianStringify(state.get(…) ?? .null)` calls for expression parts.
- `fileHeader()` emits `private func meridianStringify(_ v: Value) -> String` once.

**Note on tool ID casing:** `StatementParser.methodize` camelCases tool names that
are not declared in the `.merconfig` vocabulary (`llm.chat` → `llmChat`). When the
tool IS declared, the dot-separated name is used verbatim in `runtime.invoke(tool:)`.

31 new tests in `Tests/MeridianCoreTests/Phase6B6B7Tests.swift`. **374/374 tests pass.**

### 2026-05-01 — SkillMD-D1 to SkillMD-D28 stabilization: recover attachment and planning errors

`StatementParser.appendStatement` now treats the internal
`"__recover_placeholder__"` phrase invocation as the only recover placeholder
eligible for attachment to the preceding statement. This preserves the Phase 5
recover invariant: a `recover from ...:` line attaches to the immediately
preceding statement, and chained recovers nest outward instead of becoming
separate top-level statements.

Do not add planning/prose failure cases to `MeridianRuntimeError` unless the
full package is clean-rebuilt and recover/error matching is revalidated.
Planning resource, scope, and host-policy failures now reuse
`.toolError(.implementation(code: ...))` instead of adding new
`MeridianRuntimeError` enum cases. This keeps `approvalDenied` matching stable
for `recover from approval.denied:`.

Planning/prose failure codes are centralized in `PlanningFailureCode`:
`planning.prose_payload_too_large`,
`planning.tool_arguments_payload_too_large`, `planning.too_many_actions`,
`planning.replan_too_many_actions`, `planning.max_steps_exceeded`,
`planning.host_policy_denied`, `planning.tool_out_of_scope`, and
`planning.tool_not_registered`. `plan.error` emits `error_code` when an
implementation code is available; `plan.rejected` emits `code`.

Validation after the SkillMD-D1 to SkillMD-D28 completion pass:
- `swift package clean && swift test --filter MeridianMatchesTests`
- `swift test --filter Phase5RecoverTests`
- `swift test`

### 2026-05-01 — SkillMD-D1 to SkillMD-D28 hardening pass to close audit gaps

Autonomy predicates are now executable. `SwiftEmitter.emitProseStep` emits
`until:` / `unless:` closures for `executeAutonomousLoop`, restoring a local
`State` from the loop `StateSnapshot` before evaluating the lowered
`IRExpression`. `Runtime.executeAutonomousLoop` checks `unless` as an abort
guard and `until` as a success stop before each planning turn; action result
bindings are merged into the loop snapshot before checkpointing and before the
next predicate check.

Planner actions now validate against `ToolSchema` when a registered tool
provides one. `ToolRegistry.register` accepts an optional `schema:` and
`ToolRegistry.schemas(_:)` returns the registered schemas. `PlanExecutor`
rejects missing required args, unexpected args, and common type mismatches
before `runtime.invoke`.

`PlanningResourceLimits` now covers prose, snapshot, history, proposal,
action-count, and tool-argument budgets. New recoverable planning codes:
`planning.missing_tool_argument`, `planning.unexpected_tool_argument`,
`planning.invalid_tool_argument_type`, `planning.snapshot_payload_too_large`,
`planning.history_payload_too_large`, and
`planning.proposal_payload_too_large`.

`RedactionPolicy.redactKeys` now redacts matching keys recursively inside
records/lists in `invoke.start` payloads. Autonomy checkpoints now persist the
post-action loop snapshot, including planner-produced result bindings, so
`prepareResume(runID:)` restores those bindings.

### 2026-05-01 — Comprehensive complex-sample corpus + four lowering fixes

Added a 12-file sample corpus under `examples/skill/` driven by a fresh
standalone vocabulary `examples/skill/comprehensive_workflows.merconfig`
(26 vocabulary statements, 33 tools). Mixed `.meridian` and `.meri` extensions
to prove the shorter form works end-to-end. The corpus exercises every
SkillMD-D1 to SkillMD-D28
surface: markdown sections, frontmatter goals, topic labels, implicit
parameter fill, inline `do … and …` chains with multi-arg invokes,
`every`/`each` iteration, `recover from "<code>"` blocks, `simultaneously:`,
discretion plans, autonomous loops with `until` / `unless` / replan / max-step
caps, cross-tier nesting, and host-policy-rejection recovery. See
`Tests/MeridianCoreTests/SkillExampleCorpusTests.swift` for structural
assertions.

While building the corpus four real lowering bugs were surfaced and fixed.
Each is now load-bearing for everything else in the corpus and for the
runtime's prose-mode contract:

1. **`MerConfigParser.sectionName`** rejects all-`=` lines. A tool-title
   underline like `========================` previously matched
   `hasPrefix("===") && hasSuffix("===")` and was treated as a section
   header, dropping every tool declaration after the first one. Both
   shipped vocabularies (`ecommerce.merconfig`, `github.merconfig`) silently
   parsed 0 tools before this fix; tests didn't catch it because they only
   asserted on `IRWorkflow` shape, never on `cfg.tools`.

2. **`StatementParser.splitStatementChain`** is now invoke-args-aware. A
   chain element entering ` with ` (at depth 0, not in a quoted string)
   flips an `inInvokeArgs` flag that suppresses plain-comma splitting until
   the chain terminator (`, and `, ` and `, ` then `) appears. Without this
   guard, `do bind X = invoke Y with a = 1, b = 2, and Z` split into 3 chain
   items at every comma, producing an unresolvable `b = 2` chunk.

3. **`StatementParser.collectMultiLineCounted`** no longer folds
   continuations when (a) the header line is already `.`-terminated or
   (b) a deeper-indent line begins with a structural keyword
   (`recover from`, `recover where`, `simultaneously:`). Without this guard,
   a markdown-list `- guarded plan repair for the pull request.` line would
   absorb the attached `recover from "planning.host_policy_denied":` block
   that follows, hiding the recover from the parser.

4. **`ASTToIR.lowerPhraseInvocation`** unconditionally emits a `ProseStepIR`
   for body lines inside any workflow declared `with discretion` or
   `with autonomy`. Previously the prose-step path was reachable only if
   `matchPhrase` returned `nil`, which meant an autonomy body whose first
   word happened to overlap with a deterministic phrase silently lowered to
   that phrase's tool call instead of going through the planner — a quiet
   bypass of the LLM. The contract is now: discretion/autonomy bodies are
   never deterministic.

The Phase 4 golden file (`examples/golden/order_processing_expected.swift`)
was regenerated as a consequence of fix (1): with the tool registry now
populated for `ecommerce.merconfig`, `autoBindIfNeeded` can finally inspect
return types and adds an implicit `let order = …` binding to a previously
result-discarded `invoke update order with …` call. The new golden is the
intended behaviour; the old one was an artefact of the section-name bug.

### 2026-05-01 — Vocabulary in frontmatter, fenced `.test` syntax

`.meridian` and `.meri` files now declare vocabulary dependencies exclusively
in frontmatter under the comma-separated `vocabulary:` key. Frontmatter MUST
be the first entry in the file — only blank lines may precede the opening
`---`. The body-level `import vocabulary from "..."` and `import name.`
forms are removed; the parser emits a structured diagnostic for either, and
emits a separate diagnostic when a `---/---` block appears anywhere other
than the file head.

```
---
name: order processor
goal: Validate, charge, and finalise customer orders.
parameters: order, customer
vocabulary: ecommerce.merconfig, payments.merconfig
---
```

`.meridian.test` specs use fenced code blocks (` ```…``` `) for multi-line
values instead of the YAML-style `|` heredoc. The opening fence may carry an
optional info string (e.g. ` ```meridian `) which the parser ignores. The
body is preserved verbatim — no indent stripping — until a line whose
trimmed text is exactly three backticks. This matters because most
multi-line values (source, vocab, descriptions) now contain frontmatter
`---` markers and the fence is the only unambiguous boundary.

The legacy `|` heredoc is rejected with a structured `SpecParser.ParseError`
that points at the offending key.

### 2026-05-01 — Domain protocol hierarchy: `Meridian<Base>` semantic markers

`A foo is a kind of <base>` now means something to the type system, not just
"give me a Codable struct". Every non-scalar kind generates **two**
declarations:

```swift
public protocol PullRequestKind: MeridianThing {
    var title: String { get }
    var author: String { get }
    // …own properties only
}

public struct PullRequest: PullRequestKind {
    public var id: String
    public var title: String
    public var author: String
    // …all flattened properties
    public init(…) { … }
}
```

`Sources/MeridianRuntime/Domain/Thing.swift` defines a base
`MeridianKind` protocol (composes `Hashable + Codable + Sendable +
var id: String { get }`) and empty marker protocols composing it:
`MeridianThing`, `MeridianEvent`, `MeridianAction`, `MeridianTool`,
`MeridianSystem`, `MeridianIntegration`, `MeridianArtifact`,
`MeridianService`, `MeridianAgent`, `MeridianModel`, `MeridianDataset`,
`MeridianStorage`, `MeridianCredential`, `MeridianPolicy`,
`MeridianEnvironment`, `MeridianResource`, `MeridianMetric`,
`MeridianMemory`, `MeridianProcess`, `MeridianMessage`, `MeridianSignal`,
`MeridianFact`, `MeridianRole`, `MeridianVerdict`. The `Meridian` prefix is
mandatory because several of the bare names already resolve to existing types
in scope:

- `Event` is a public struct in `MeridianRuntime` (telemetry record).
- `Process` is a Foundation class.
- `Tool` is used as a discriminating noun in many runtime APIs (kept
  consistent for symmetry).

The semantic protocols are intentionally empty — the discriminating value is
the type name, not an opinionated baseline. Forcing `Event` to declare an
`occurredAt` or `Action` to declare a `verb` would be wrong for many host
vocabularies.

`DomainEmitter`'s `parentProtocol(for:kindNames:)` chooses the parent
protocol in three cases:

1. Parent is one of the semantic bases → `Meridian<Base>`.
2. Parent is another declared kind → `<Parent>Kind` (chains naturally).
3. Parent is unrecognised → fall back to `MeridianThing`.

Scalar parents (`String|Number|Money|Date|DateTime|Boolean|Duration|List|
Reference`) still collapse to a single `typealias` — typealiases can't carry
conformance, and most of these kinds have no behaviour worth threading
through a protocol.

**Authoring tip**: prefer the most specific base. `A reviewer is a kind of
role.` and `An audit note is a kind of event.` make generated code
self-documenting and let host code constrain APIs to "anything that's a
role" without naming individual kinds. Use `kind of thing` only when none of
the semantic bases fit.

Tests:

- `Tests/MeridianCoreTests/DomainSemanticBasesTests.swift` exercises every
  base in a one-line vocabulary fixture so a regression in
  `parentProtocol(for:kindNames:)` surfaces with a precise message instead
  of getting buried in a 200-line corpus golden.
- All 18 SKILL corpus goldens were regenerated; the comprehensive
  vocabulary now uses 7 of the 9 non-`Thing` bases (one of each, where
  semantically apt).

### 2026-05-01 — Empty-protocol elision for leaf kinds

`DomainEmitter` now skips the `<KindName>Kind` protocol when a kind has no
own properties **and** no descendants. The struct conforms directly to
the resolved parent protocol (`Meridian<Base>` or `<Parent>Kind`). This
keeps generated output proportional to the merconfig — a one-line
`A comment is a kind of thing.` produces a single struct, not a struct
plus an empty protocol.

The protocol stays whenever it's load-bearing:

- The kind has at least one own property (the protocol declares the
  property requirement).
- The kind is named as another kind's `parent` (chain anchor — child
  protocols inherit through it because structs can't be the inheritance
  anchor in Swift).

`emitDomain` precomputes `kindsWithDescendants: Set<String>` and threads
it into `emitKind`/`emitProtocolAndStruct`. The struct's conformance is
`protocolName` (when emitted) or `parentProto` (when elided).

When writing tests against generated Swift, give probe kinds at least one
own property if you want to assert against `<KindName>Kind` — otherwise
the elide rule will skip the protocol and the assertion will silently
miss it.

### 2026-05-01 — Software/AI workflow semantic bases

The domain semantic base set now includes software and AI workflow roles:
`system`, `integration`, `artifact`, `service`, `agent`, `model`, `dataset`,
`storage`, `credential`, `policy`, `environment`, `resource`, `metric`, and
`memory`. Each maps to the corresponding `Meridian<Base>` marker protocol in
`Sources/MeridianRuntime/Domain/Thing.swift` and is listed in
`DomainEmitter.semanticBases`.

`tool` remains a semantic base, but its meaning is domain-level: a capability
or instrument that does work. A runtime-registered callable may back that
tool, but `kind of tool` is not just a synonym for "external system"; use
`system`, `integration`, `service`, or `storage` for the surrounding platform
or infrastructure.

The ecommerce vocabulary now models `mailer server` as `kind of system` and
`payment processor` as `kind of service`.
