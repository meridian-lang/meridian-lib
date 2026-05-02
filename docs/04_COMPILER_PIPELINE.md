# Meridian — Compiler Pipeline

This document traces a `.merconfig` + `.meridian` pair from raw text through
every compiler stage to emitted Swift.

---

## Stage 0 — Entry point

`Compiler.compile(meridianSource:meridianFile:vocabularies:)` in `Sources/MeridianCore/Compiler.swift`
is the single public façade. The CLI (`CompileCommand`, `RunCommand`) and unit tests both call this.

```swift
let out = try Compiler(options: opts).compile(
    meridianSource: mer,
    meridianFile: "order_processing.meridian",
    vocabularies: [
        .init(name: "ecommerce", file: "ecommerce.merconfig", source: cfg)
    ]
)
```

A convenience overload accepting a single `merconfigSource: String` is also
available for single-vocabulary compilations.

---

## Stage 1 — Tokenisation (`IndentTokenizer`)

`IndentTokenizer` converts a raw `String` into `[SourceLine]`.

```swift
struct SourceLine {
    let number: Int       // 1-based
    let indent: Int       // leading-space count
    let statement: String // text with trailing "." stripped
    var isEmpty: Bool     // blank or comment-only
    var isComment: Bool   // starts with "#"
    var isContent: Bool   // !isEmpty && !isComment
}
```

Indentation is significant: continuation lines (deeper indent than their
parent) are detected by comparing `.indent` values.

---

## Stage 2 — Config parsing (`MerConfigParser`)

`MerConfigParser.parse(_:file:)` processes the `.merconfig` source.

### Section detection

Lines matching `=== name ===` are section headers. All content lines between
two headers belong to the preceding section. Unknown sections are skipped.

### Phrase definition parsing

Multi-line `To {pattern}:` headers are folded by `collectHeaderLines(…)`:
if the first line does not end with `:`, continuation lines (deeper indent)
are appended until one ends with `:`.

Body lines follow at a deeper indent than the `To` line.

`PhrasePatternParser.parse(_:)` tokenises a pattern like
`"send an email via a mailer server, to an email address, …"` into
`[PatternSegment]`:

```
.literal("send")
.parameter(name: "email", kind: "email")
.literal("via")
.parameter(name: "mailer_server", kind: "mailer server")
.literal("to")
.parameter(name: "email_address", kind: "email address")
…
```

`tryParseParam` finds an article (`a`/`an`) to locate the parameter boundary.
It uses `findArticle` which picks the **earliest** article occurrence by
string position (not iteration order — an important correctness detail).

Trailing punctuation (`,` `;`) in the parameter text is stripped before the
kind name is formed.

### Output

`MerConfigFile` containing:
- `vocabulary: [VocabularyStatement]` (kinds, properties, phrases, tools)
- `constants: [ConstantDeclaration]`
- `instances: [InstanceDeclaration]`
- `tools: [ToolDeclaration]`

---

## Stage 3 — Symbol table (`SymbolTable`)

`SymbolTable.build(from:)` indexes the `MerConfigFile` for fast lookup during
parsing and lowering.

Key indices:
- `kinds: [String: KindDeclaration]`
- `constants: [String: ConstantDeclaration]`
- `instances: [String: InstanceDeclaration]`
- `tools: [String: ToolDeclaration]` (keyed by camelCase method name)
- `phrases: [PhraseDefinition]`

### Phrase matching — `matchPhrase(_ invocation:)`

1. Tokenise the invocation into significant words (strip stop words).
2. Take the first significant word as a **gate** — skip any phrase whose
   pattern literals don't contain that word.
3. Score remaining candidates by literal-keyword overlap.
4. Pick the highest-scoring candidate.
5. Call `extractArgs` to pull argument values out of the raw invocation text.

### Argument extraction — `extractArgs`

Iterates `PhrasePattern.segments`. For each `.literal`, it finds and advances
past the literal text. For each `.parameter`, it consumes text up to the next
literal (or end of string), then runs `stripPatternSlop` to remove leading
articles and kind words, and trailing list punctuation.

`ExpressionParser.parse` turns the extracted text into an `ExpressionAST`.

---

## Stage 4 — Meridian file parsing (`MeridianParser`)

`MeridianParser(symbols:).parse(_:file:)` processes the `.meridian` source.

Like `MerConfigParser`, it folds multi-line workflow headers before parsing
the body. The body is handed to `StatementParser`.

### `StatementParser.parseStatement`

Dispatches based on the first word:

- `complete` / `commit` → direct AST nodes
- `emit` → `parseEmit` (event ID + payload fields)
- `wait` → `parseWait`:
  - `wait <duration>.` → `WaitConditionAST.duration`
  - `wait for signal "<name>".` → `WaitConditionAST.signal`
  - `wait for approval of <expr> from <role>.` → `WaitConditionAST.approval`
  - `wait for event <id>.` / `wait for event <id> matching <predicate>.` → `WaitConditionAST.event`
- `if … ,` → `parseConditional` (recursive)
- `bind … = …` / `rebind … = …` → `parseBindValue` → `parseInvokeExpr` or `ExpressionParser`
- `for each … in …` → `parseIteration`
- `assert …` → `parseAssert` (optional `otherwise:` block)
- `recover` → `parseRecover` (attaches to the preceding statement; does NOT use
  `collectMultiLineCounted` — that would greedily consume body lines)
- `simultaneously:` → `parseSimultaneously` (indented block of parallel steps)
- everything else → `phraseInvocation` collected via `collectMultiLineCounted`

`collectMultiLineCounted` folds continuation lines (deeper indent than the
parent) into a single text fragment *and* returns the consumed count so
`parseBlock` skips those lines.

### `ExpressionParser.parse`

Parses a single-line expression string:
1. `parseComparison` — splits on markers (`is more than`, `equals`, `is within`,
   …) **outside** quoted string regions (quote-aware via `rangeOfMarkerOutsideQuotes`).
2. `parseAtom` — recognises:
   - Possessive chains (`the X's Y`) → `parsePossessiveChain`
   - Bare possessives (`X's Y`, detected by `'s` presence) → `parsePossessiveChain`
   - Quoted string literals
   - Duration literals (`30 days`)
   - Numeric literals
   - Money literals (`$5000`)
   - `now` keyword
   - Identifier / constant / instance ref

`resolveBase` checks `SymbolTable` to decide whether a bare name is a
`.constantRef`, `.instanceRef`, or plain `.identifierRef`.

### Output

`MeridianFile` containing `workflows: [WorkflowAST]`.

---

## Stage 5 — Lowering (`ASTToIR`)

`ASTToIR(symbols:sourceFile:).lower(_ file:)` produces `[IRWorkflow]`.

### Workflow stub registration

Before lowering any workflow, every `WorkflowAST` is registered in the
symbol table as a `PhraseDefinition` stub (`workflowStructName` set,
empty body). This makes recursive and forward-reference workflow calls
resolvable during lowering.

### `lowerStatement`

Matches `StatementAST` cases and calls the appropriate `lower*` helper.
`phraseInvocation` is the interesting path:

```
lowerPhraseInvocation
  ├── starts with "invoke " → buildInvokeExpr → InvokeIR
  ├── matchPhrase finds a workflow stub → InvokeIR(toolID: "workflow:StructName")
  │     args ordered by pattern.parameters (not dict order)
  ├── matchPhrase finds a phrase → inlinePhrase
  │     substituteArgs (text + AST substitution, longest-param-first)
  │     then lowerBlock recursively (depth-limited to 8)
  └── no match → BindIR(name: "_unresolved", …) placeholder
```

`simultaneously` lowers to `SimultaneouslyIR` whose `branches` is a list of
`IRBlock`s (one per parallel step).

`recover` lowers to `RecoverIR(attachedTo: IRBlock, pattern: ErrorPattern, handler: IRBlock)`.
The `attachedTo` block is the protected statement(s); `handler` is the catch block.

`wait` lowers the `WaitConditionAST` to `WaitConditionIR`:
- `.duration` → `WaitConditionIR.duration(Duration)`
- `.signal` → `WaitConditionIR.signal(String)`
- `.approval` → `WaitConditionIR.approval(of: IRExpression, by: RoleRef)`
- `.event` → `WaitConditionIR.event(String, matching: IRExpression?)`

### `lowerExpr`

Maps `ExpressionAST` to `IRExpression`:
- `.identifierRef(n)` → checks symbols: `constantRef` / `instanceRef` / `identifierRef`
- Multi-word identifiers (bind variable names) are camelCased via `camelCase(_:)`
- `.propertyAccess` traverses possessive chains
- `.comparison(lhs, op, rhs)` → `IRExpression.comparison`

---

## Stage 6 — Emission (`SwiftEmitter`)

`SwiftEmitter.emitFile(workflows:constantsDecl:instancesDecl:domainDecl:)` produces a
Swift source `String`. Uses `StringTemplate` from `modelhike`; each `emit*`
method returns a `StringTemplate` that is flattened via
`toString(separator: "\n")`.

See [05_CODEGEN.md](05_CODEGEN.md) for the full emission spec.

### Progress labels and replay-safe resume

`SwiftEmitter` assigns a stable **progress label** to every side-effecting
primitive (`invoke`, `emit`, `wait`, `assert`, `commit`) based on its path
through the IR tree (e.g. `progress:0.1.then.0:L85:C0`). Each primitive is
wrapped in an `if __meridianShouldRun("…")` guard. An implicit `runtime.checkpoint`
call follows each guarded primitive. Loop iterations also checkpoint at boundaries.

The generated `__meridianShouldRun` helper compares a progress label against
the last checkpoint label from a `ResumeContext`, implementing
lexicographic-order skipping. A generated workflow starts `run()` by calling
`runtime.consumeResumeContext()` — if a context is present, state is restored
from `restoredState` and the run resumes past the checkpoint label.

---

## Stage 7 — Formatting (optional)

`CompileCommand` passes the emitted string through `swift-format` unless
`--no-format` is provided. Errors during formatting are non-fatal (the
unformatted string is written).

---

## Stage 8 — Manifest emission

`ManifestEmitter.emit(_:)` runs in parallel to Stage 6 and writes a
`{stem}.meridian.manifest.json` companion file containing workflow names,
parameters, event IDs, tool IDs, and source-map entries derived from the
`// L{line}` comments in generated Swift.

---

## `Compiler.compile` return type

`compile(…)` returns a plain `String` — the Swift source. There is no wrapper
struct. The manifest is emitted separately via `Compiler.emitManifest(_:)`.

## `Compiler` also exposes

```swift
// Emit Swift from pre-built IR (no parsing)
public func emit(workflows: [IRWorkflow], constantsDecl: SwiftEmitter.ConstantsDecl?) -> String

// Emit companion JSON manifest
public func emitManifest(_ input: ManifestEmitter.Input) throws -> String
```

## `CompilerError`

```swift
public enum CompilerError: Error, Sendable {
    case notImplemented(String)
    case syntaxError(message: String, range: SourceRange)
    case semanticError(message: String, range: SourceRange)
    case codegenError(message: String)
}
```

## Error handling

| Stage | Error type | Behaviour |
|---|---|---|
| Tokenisation | none | Always succeeds |
| Config parse | `MerConfigParseError` | Thrown to caller |
| Meridian parse | `StatementParseError` | Thrown to caller |
| Lowering | `CompilerError` | Thrown; unresolvable phrases produce `_unresolved` placeholders |
| Emission | none | Always succeeds |
| Formatting | Swift error | Non-fatal; logged to stderr, raw output written |
