# Meridian — Architecture

Module map, compiler internals, the end-to-end compilation pipeline, and how IR
becomes Swift. Start here when you need to know *where* a piece of the compiler
lives; the language surface is [03_LANGUAGE.md](03_LANGUAGE.md) and the runtime
API is [04_RUNTIME.md](04_RUNTIME.md).

---

## Module map

```
┌─────────────────────────────────────────────────────────────┐
│                     meridian (CLI)                          │
│  Sources/MeridianCLI/CLI.swift (thin @main)                  │
│  Sources/MeridianCLIKit/Commands/                           │
│  compile · check · verify · run · resume · format · docs ·  │
│  test · lint · trace · explain · explain-diag · drift ·     │
│  grammar-doc · decisions · preview-skill · migrate-skill ·  │
│  skill-deviation                                             │
│  ArgumentParser + SwiftFormat integration                   │
└──────────────────────┬──────────────────────────────────────┘
                       │ depends on
         ┌─────────────┼──────────────┬────────────────┐
         ▼             ▼              ▼                ▼
┌──────────────┐ ┌──────────────┐ ┌───────────────┐ ┌──────────────────┐
│ MeridianCore │ │MeridianRuntime│ │MeridianTools  │ │MeridianTestKit   │
│ (compiler)   │ │(generated code│ │(built-in tools│ │(test helpers)    │
│              │ │ depends on   │ │ Blueprint      │ │WorkflowTestHarness
│  Parser      │ │ this)        │ │ families)      │ │MockRuntime       │
│  AST         │ └──────────────┘ └───────────────┘ │RecordingTool     │
│  Symbols     │         ▲                           └──────────────────┘
│  IR          │         │ generated code imports
│  Codegen     │         │
│  Testing/    │ ┌──────────────────────────────────┐
│  Formatter/  │ │  Generated Swift (output)        │
│  Verbalizer/ │ │  ProcessOrder.swift              │
│  Diagnostics │ │  imports MeridianRuntime         │
│  Docs/       │ │                                  │
└──────────────┘ └──────────────────────────────────┘
```

## MeridianCore — compiler internals

```
Sources/MeridianCore/
├── Compiler.swift                   ← Public entry: Compiler.compile(...)
│
├── Parser/
│   ├── Lexical/
│   │   ├── IndentTokenizer.swift    ← Raw source → SourceLine[]; collapses
│   │   │                              code-block / table / checklist blocks
│   │   │                              (BlockKind / TableMode / ChecklistMode)
│   │   └── ExpressionParser.swift  ← Parses single-line expressions
│   ├── Productions/
│   │   ├── MerConfigParser.swift    ← Parses .merconfig files (orchestrator)
│   │   ├── MerConfigParser+Language.swift ← `=== language ===` synonym blocks
│   │   ├── MerConfigParser+Trace.swift    ← `=== trace ===` settings
│   │   ├── MerConfigParser+Tools.swift    ← `=== tools ===` declarations
│   │   ├── MerConfigParser+Vocabulary.swift ← `=== vocabulary ===` decls
│   │   ├── PhrasePatternParser.swift ← Phrase pattern `a/an` slot parsing
│   │   ├── MeridianParser.swift     ← Parses .meridian files
│   │   ├── StatementParser.swift    ← Parses statements; expands table/checklist
│   │   ├── StatementParser+ControlFlow.swift ← if/unless/for-each/wait/recover
│   │   ├── StatementParser+Bindings.swift ← bind/invoke/emit/match/assert
│   │   ├── StatementParser+Idioms.swift ← English idioms / iteration helpers
│   │   ├── StatementParser+Decisions.swift ← judgment / choice / autonomy
│   │   ├── StatementParser+Blocks.swift ← shell fences / data tables / backtick
│   │   ├── StatementParser+Checklists.swift ← checklist / anaphora / append
│   │   ├── StatementParser+Collector.swift ← multi-line phrase folding
│   │   ├── TableParser.swift        ← Decodes table sentinels → branches /
│   │   │                              recordList / AI-decision prose
│   │                                  (phrase/workflow headers parse inline)
│   └── Skill/
│       ├── SkillSectionBuilder.swift ← Heading → SkillSectionRole; ## Tools Used
│       └── ConditionClassifier.swift ← checkable / dispatch-phrase / fuzzy
│
├── AST/
│   └── MeridianAST.swift           ← All AST node types
│
├── Language/
│   ├── EnglishLexicon.swift        ← Author-extensible surface vocabulary
│   │                                  (articles, copulas, comparison/duration/
│   │                                  assertion markers, emptiness, temporal,
│   │                                  aggregates, superlatives, …) + .grammar
│   ├── LexiconCategory.swift       ← The `=== language ===` categories +
│   │                                  `LanguageSynonyms` entry table
│   ├── LexiconRegistry.swift       ← One row per category: header spellings,
│   │                                  line shape, lexicon merge rule
│   ├── FixedGrammar.swift          ← Closed grammar skeleton (relativizers,
│   │                                  prose/idiom introducers, relational
│   │                                  markers) — centralized, not extensible
│   └── AnaphoraResolver.swift      ← Resolves anaphora via lexicon markers
│
├── Symbols/
│   ├── SymbolTable.swift           ← Phrase matching + arg extraction
│   └── BuiltinToolCatalog.swift    ← Core-side mirror of MeridianTools'
│                                      built-in tool ids (D-DX-5); validates
│                                      every InvokeIR.toolID
│
├── Lowering/
│   ├── ASTToIR.swift               ← Orchestrator: entry / tool-ID / block /
│   │                                  parameters / sourceRange
│   ├── ASTToIR+PhraseInvocation.swift ← Phrase / shell / invoke / AI dispatch
│   ├── ASTToIR+PhraseInlining.swift ← Phrase body inlining / arg substitution
│   ├── ASTToIR+Statements.swift    ← Statement / recover lowering
│   ├── ASTToIR+Bind.swift          ← Bind / rebind / note validation
│   ├── ASTToIR+Commands.swift      ← Shell command hole lowering
│   ├── ASTToIR+Expression.swift    ← Expression / trace-temporal / comparison lowering
│   ├── ASTToIR+Relations.swift     ← Relations, verbs, descriptions / scalar nav
│   ├── ASTToIR+Definitions.swift   ← Checkable-adjective registration / subject keys
│   ├── ASTToIR+Quantifier.swift    ← Quantifier / iteration refinement / wait helpers
│   ├── DeonticLowering.swift       ← Deontic norm attachment / deny wrapping
│   ├── RuleLowering.swift          ← Rulebook rule → IR norms
│   └── RuleInjector.swift          ← Inject conventions + synthesize triggers
│
├── Rulebook/
│   ├── Rulebook.swift              ← 4 families: desugar / sections / conventions
│   │                                  / triggers; builtin section + trigger seeds
│   ├── RulebookParser.swift        ← Parses .merrules (=== name === sections)
│   └── RewriteEngine.swift         ← Applies desugar rewrites (bounded fixpoint)
│
├── IR/
│   └── IRTypes.swift               ← IRWorkflow, IRPrimitive (13 cases: 11
│                                      deterministic primitives + aiJudgment/
│                                      aiAutonomy for the discretion/autonomy
│                                      prose path), IRExpression
│
├── Codegen/
│   ├── SwiftEmitter.swift          ← IR → Swift source (StringTemplate)
│   │                                  Replay-safe resume guards generated here
│   ├── SwiftEmitter+Expressions.swift ← expr / comparison / trace emission
│   ├── SwiftEmitter+Iterate.swift  ← for-each / element-context helpers
│   ├── SwiftEmitter+Primitives.swift ← invoke / bind / emit / AI judgment
│   ├── SwiftEmitter+ControlFlow.swift ← branch / assert / recover / wait
│   ├── SwiftEmitter+FileTail.swift ← Constants / Instances / header / helpers
│   ├── DomainEmitter.swift         ← Vocabulary → typealiases / protocol+struct
│   │                                  pairs (Meridian<Base> hierarchy)
│   └── ManifestEmitter.swift       ← IR → JSON manifest + source-map entries
│
├── Formatter/
│   └── MeridianFormatter.swift     ← Conservative whitespace-only formatter
│
├── Verbalizer/
│   ├── Verbalizer.swift            ← Lowered model → Canonical English
│   ├── Verbalizer+IRExpression.swift ← IRExpression / interpolation surfaces
│   ├── VerbalizerModel.swift       ← Public semantic model from compile(_:)
│   └── DriftEngine.swift           ← Authored vs canonical line audit
│
├── Docs/
│   └── MerconfigDocsRenderer.swift ← .merconfig → self-contained HTML
│
├── Testing/
│   ├── MeridianTestRunner.swift    ← .meridian.test spec runner
│   ├── SpecParser.swift            ← Parses .meridian.test key/value format
│   ├── Assertions.swift            ← Assertion kinds + evaluator
│   ├── RuntimeExecutor.swift       ← Builds and runs temporary SwiftPM packages
│   └── SwiftPMPackageRunner.swift  ← Reusable temporary SwiftPM scaffolding
│
└── Diagnostics/
    ├── Diagnostic.swift            ← Diagnostic + Suggestion + DiagnosticNote;
    │                                  the always-on `Diagnostic.unresolved`
    │                                  / `.structural` funnels (D-DX-4)
    ├── DiagnosticCode.swift        ← Stable `MERxxxx` catalog (id/title/
    │                                  explanation/kind/DecisionRef)
    ├── DiagnosticEngine.swift      ← Per-file collector; batch-reports with
    │                                  coarse recovery (D-DX-2)
    ├── DiagnosticRenderer.swift    ← Human (snippet+caret+did-you-mean) and
    │                                  stable-JSON renderers
    ├── Suggester.swift             ← "did you mean" engine (Levenshtein +
    │                                  token overlap)
    ├── DecisionCatalog.swift       ← `DecisionRecord`s behind the codes;
    │                                  renders docs/15 (D-DX-1…5)
    ├── FallbackPolicy.swift        ← `FallbackKind` + `allow-fallbacks:` policy
    ├── SourceSpan.swift            ← SourceRange/SourceLine span helpers for
    │                                  token-precise carets
    ├── MeridianLinter.swift        ← `meridian lint` advisory checks
    └── ParserTrace.swift           ← Category-scoped trace sink (+ timing
                                       spans, profile summary, diagnostics mirror)
```

The diagnostics subsystem is the backbone of the debugging experience — see
[06_DEVELOPER_EXPERIENCE.md](06_DEVELOPER_EXPERIENCE.md) for how these pieces fit
together (codes, did-you-mean, batch reporting, tracing, `explain-diag`/`decisions`/
`--fix`).

## MeridianRuntime — execution actor

```
Sources/MeridianRuntime/
├── Runtime.swift                 ← Orchestrator: properties / wait queues / init
├── Runtime+Planning.swift        ← Prose plan / judgment / autonomy loops
├── Runtime+Assert.swift          ← Assert / branch / iterate / violation /
│                                    statistical monitors
├── Runtime+Wait.swift            ← wait / deliverSignal|Choice|Approval|Event
├── Runtime+Tools.swift           ← invoke + capture/redaction helpers
├── Runtime+Events.swift          ← emit / emitLenient domain events
├── Runtime+Checkpoints.swift     ← checkpoint / resume / state snapshots
├── Runtime+Lifecycle.swift       ← complete / cancel / instances /
│                                    workflow started|failed / recordEvent
├── Runtime+Diagnostics.swift     ← elapsedMS / eventCount / evaluateTrace
├── Runtime+Emit.swift            ← emit core / observer / trace-store plumbing
├── RuntimeBuilder.swift          ← Fluent Runtime construction
├── Value/ · State/ · Wait/ · Events/ · Trace/ · Planning/ · Tools/ …
```

## Compilation pipeline

```
.merconfig source text
        │
        ▼  MerConfigParser.parse(_:)
MerConfigFile
  - vocabulary: kinds, properties, relations, phrases, tools
  - constants: typed named literals
  - instances: named typed objects (primary mailer, stripe, …)
        │
        ├──► SymbolTable.build(from:)
        │         phrase library + kind index + instance index
        │
        ▼  MeridianParser(symbols:).parse(_:)
MeridianFile
  - imports: [String]
  - workflows: [WorkflowAST]  (header pattern + body statements)
        │
        ▼  ASTToIR(symbols:).lower(_:)
[IRWorkflow]
  - For each phraseInvocation in the body: matchPhrase → inlinePhrase
  - Workflow stubs registered before lowering → recursive calls resolve
  - instanceRef / constantRef lifted out of identifierRef
  - Progress labels assigned to side-effecting primitives for replay safety
        │
        ├──► VerbalizerModel → Verbalizer → Canonical English
        │                     → DriftEngine → authored/canonical drift report
        │
        ├──► ManifestEmitter → {stem}.meridian.manifest.json
        │
        ▼  SwiftEmitter.emit(workflows:constantsDecl:instancesDecl:domainDecl:)
           (+ runtimeTraceConfiguration, trace query/monitor codegen when configured)
Swift source String  ← toString(separator: "\n") from StringTemplate
        │
        ▼  swift-format (optional, --no-format to skip)
Formatted Swift String
        │
        ▼  Written to -o <dir>/{stem}.swift
```

## Data flow summary

| Stage | Input type | Output type |
|---|---|---|
| Tokenisation | `String` (raw source) | `[SourceLine]` |
| Config parse | `[SourceLine]` | `MerConfigFile` |
| Symbol build | `MerConfigFile` | `SymbolTable` |
| Meridian parse | `[SourceLine]` + `SymbolTable` | `MeridianFile` |
| Lowering | `MeridianFile` + `SymbolTable` | `[IRWorkflow]` |
| Verbalization model | `[IRWorkflow]` + symbols/lexicon/metadata | `VerbalizerModel` |
| Canonical English | `VerbalizerModel` | `String` (`meridian explain`) |
| Drift audit | authored source + canonical source | `DriftReport` |
| Emission | `[IRWorkflow]` | `String` (Swift) |
| Manifest | `[IRWorkflow]` | `String` (JSON) |

## Key types cheat-sheet

| Type | Where | Role |
|---|---|---|
| `SourceLine` | `IndentTokenizer` | `(number, indent, statement)` — one logical line |
| `PhrasePattern` | `MeridianAST` | Pattern segments: `.literal` / `.parameter` |
| `PhraseDefinition` | `MeridianAST` | Pattern + body block + optional `workflowStructName` |
| `SymbolTable` | `Symbols/` | Keyed index; drives `matchPhrase` + `extractArgs` |
| `ExpressionAST` | `MeridianAST` | Parsed expression tree (pre-IR) |
| `IRExpression` | `IRTypes` | Lowered expression (post-IR) |
| `IRPrimitive` | `IR/IRTypes` | One of 13 lowered statement cases |
| `IRWorkflow` | `IR/IRTypes` | Struct name, parameters, body block, execution mode |
| `VerbalizerModel` | `Verbalizer/` | Lowered workflows plus symbols, lexicon, metadata, definitions, sections, and authored source |
| `Verbalizer` | `Verbalizer/` | Renders Canonical English from `VerbalizerModel`, `IRExpression`, or `IRPrimitive` |
| `DriftEngine` | `Verbalizer/` | Classifies authored-vs-canonical line hunks for drift reports |
| `StringTemplate` | `modelhike` | Result-builder code builder used by `SwiftEmitter` |
| `Diagnostic` | `Diagnostics/` | Coded error/warning: code + range + suggestions/notes/help + decision |
| `DiagnosticCode` | `Diagnostics/` | Stable `MERxxxx` identity + kind + linked `DecisionRef` |
| `DiagnosticEngine` | `Diagnostics/` | Per-file collector; batch-reports many errors with coarse recovery |
| `TraceRecord` / `TraceStore` | `MeridianRuntime/Trace/` | Semantic trace schema, append-only store, `TraceEvaluator` replay |

## Runtime trace seam (Wave 8)

Generated workflows may carry `runtimeTraceConfiguration` (from `=== trace ===`).
At run time, `Runtime` appends semantic `TraceRecord` rows to an optional
`TraceStore` (`InMemoryTraceStore` or `JSONLTraceStore`). Temporal/statistical
conditions in generated code call `TraceEvaluator.evaluate(...)` against that
store. This is separate from compile-time `ParserTrace` — see
[06_DEVELOPER_EXPERIENCE.md](06_DEVELOPER_EXPERIENCE.md) and [04_RUNTIME.md](04_RUNTIME.md).

## External dependencies

| Package | Used for |
|---|---|
| `swift-parsing` | Foundation for `PegexBuilder` |
| `pegex` (remote, `modelhike/pegex`) | `PegexBuilder` grammar DSL |
| `StringTemplate` (vendored, `Sources/MeridianCore/modelhike-vendored/`) | Codegen builder DSL used in `SwiftEmitter` |
| `swift-argument-parser` | `meridian` CLI |
| `swift-format` | Auto-format emitted Swift |
| `swift-collections` | Ordered collections in symbol tables |

---

## Compiler pipeline

*Was `docs/04_COMPILER_PIPELINE.md`.*

This document traces a `.merconfig` + `.meridian` pair from raw text through
every compiler stage to emitted Swift.

---

### Stage 0 — Entry point

`Compiler` in `Sources/MeridianCore/Compiler.swift` is the single public façade,
and **one pipeline** backs every entry point: bootstrap the vocabulary/rulebook
knowledge once, parse every source against a shared `SymbolTable`, pre-register
every source's workflows as phrase stubs, then lower + emit each source.

```swift
let unit = Compiler.CompilationUnit(
    sources: [Compiler.SourceInput(source: mer, file: "order_processing.meridian")],
    vocabularies: [
        .init(name: "ecommerce", file: "ecommerce.merconfig", source: cfg)
    ]
)
let compiled = try Compiler(options: opts).compile(unit)["order_processing.meridian"]!
compiled.swift          // single-file Swift (the historical emitFile output)
compiled.domainSwift    // multi-file split: domain half
compiled.workflowsSwift // multi-file split: workflows half
compiled.manifest       // complete ManifestEmitter.Input
compiled.model          // VerbalizerModel (canonical English, drift, IR sidecar)
```

`compile(meridianSource:meridianFile:merconfigSource:merconfigFile:)` is the
one-source convenience wrapper returning just the Swift string, and
`bootstrap(_ unit:)` runs the bootstrap phase alone for authoring-time tooling
(the migrator's marking pass, the inert-yield analyzer, `trace eval`). The CLI
(`CompileCommand`, `RunCommand`), MCP tools, and unit tests all call these.

---

### Stage 1 — Tokenisation (`IndentTokenizer`)

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

The tokenizer also collapses block-level Markdown structures into single
synthetic lines carrying a private-use sentinel:

- **Fenced code blocks** → `\u{E000}codeblock:<lang>:<base64>` (B6).
- **Tables** → `\u{E000}table:<mode>:<base64>`. A contiguous header + `|---|`
  delimiter + rows block is collapsed; an optional `!!! table (( <mode> ))`
  marker on the line directly above sets the `TableMode`: `decision` (default) /
  `data[: name]` / `iteration` / `inert` / `ai-discretion` / `ai-autonomy`.
- **Marked task lists** → `\u{E000}checklist:<mode>:<base64>`. A
  `!!! checklist (( <mode> ))` marker folds the following contiguous `- [ ]` /
  `- [x]` run into one sentinel carrying its `ChecklistMode` (`invariant` /
  `ai-discretion` / `ai-autonomy` / `inert`) and the bullet conditions
  (checkboxes stripped). An *unmarked* task list is **not** collapsed — its
  items keep their per-item `isChecklist` / `checklistChecked` tags (default =
  invariant asserts).
- **Marker errors** → `\u{E000}markererror:<base64>`. The tokenizer is
  non-throwing, so a malformed/dangling `!!!` marker is carried as a sentinel
  and raised as a located `semanticError` by `StatementParser`.

`BlockKind` (`table` / `checklist`), `TableMode`, and `ChecklistMode` are all
**enums**, never raw dispatch strings (AGENTS.md "No hardcoded English-surface
vocabulary"). A single `!!!` marker awaits its block via a `PendingBlock` enum;
a marker whose following block is the wrong kind (or absent) is a marker error.
`TableParser` and `StatementParser` decode these sentinels/flags in Stage 4/5.

---

### Stage 2 — Config parsing (`MerConfigParser`)

`MerConfigParser.parse(_:file:)` processes the `.merconfig` source.

#### Section detection

Lines matching `=== name ===` are section headers. All content lines between
two headers belong to the preceding section. Unknown sections are skipped.

#### Phrase definition parsing

Multi-line `To {pattern}:` headers are folded by `collectHeaderLines(…)`:
if the first line does not end with `:`, continuation lines (deeper indent)
are appended until one ends with `:`.

Body lines follow at a deeper indent than the `To` line.

Header parsing tokenises a pattern like
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

`MerConfigParser` / `MeridianParser` share the same phrase-pattern logic.
Parameter detection uses `EnglishLexicon.findEarliestArticle(_:)` over
`parameterArticles` (`a`/`an`) to pick the **earliest** article occurrence by
string position (not iteration order — an important correctness detail).

Trailing punctuation (`,` `;`) in the parameter text is stripped before the
kind name is formed.

#### Output

`MerConfigFile` containing:
- `vocabulary: [VocabularyStatement]` (kinds, properties, phrases, tools)
- `constants: [ConstantDeclaration]`
- `instances: [InstanceDeclaration]`
- `tools: [ToolDeclaration]`

---

### Stage 3 — Symbol table (`SymbolTable`)

`SymbolTable.build(from:)` indexes the `MerConfigFile` for fast lookup during
parsing and lowering.

Key indices:
- `kinds: [String: KindDeclaration]`
- `constants: [String: ConstantDeclaration]`
- `instances: [String: InstanceDeclaration]`
- `tools: [String: ToolDeclaration]` (keyed by camelCase method name)
- `phrases: [PhraseDefinition]`

#### Phrase matching — `matchPhrase(_ invocation:)`

1. Tokenise the invocation into significant words (strip stop words).
2. Take the first significant word as a **gate** — skip any phrase whose
   pattern literals don't contain that word.
3. Score remaining candidates by literal-keyword overlap.
4. Pick the highest-scoring candidate.
5. Call `extractArgs` to pull argument values out of the raw invocation text.

#### Argument extraction — `extractArgs`

Iterates `PhrasePattern.segments`. For each `.literal`, it finds and advances
past the literal text. For each `.parameter`, it consumes text up to the next
literal (or end of string), then runs `stripPatternSlop` to remove leading
articles and kind words, and trailing list punctuation.

`ExpressionParser.parse` turns the extracted text into an `ExpressionAST`.

---

### Stage 4 — Meridian file parsing (`MeridianParser`)

`MeridianParser(symbols:).parse(_:file:)` processes the `.meridian` source.

Like `MerConfigParser`, it folds multi-line workflow headers before parsing
the body. The body is handed to `StatementParser`.

#### `StatementParser.parseStatement`

Dispatches based on the first word:

- `complete` / `commit` → direct AST nodes
- `emit` → `parseEmit` (event ID + payload fields)
- `wait` → `parseWait`:
  - `wait <duration>.` → `WaitConditionAST.duration`
  - `wait for signal "<name>".` → `WaitConditionAST.signal`
  - `wait for approval of <expr> from <role>.` → `WaitConditionAST.approval`
  - `wait for event <id>.` / `wait for event <id> matching <predicate>.` → `WaitConditionAST.event`
  - choice gates lower to `WaitConditionAST.choice`
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

#### `ExpressionParser.parse`

`ExpressionParser` is a thin orchestrator over ~16 independent production
units (`Sources/MeridianCore/Parser/Lexical/Productions/`), each either a real
`pegex` grammar or a dedicated hand-written Swift function — whichever is
clearer for that specific pattern (see `GrammarTable`'s
`GrammarProduction.implementation`, and `IMPLEMENTATION_LOG.md`'s "Per-production
expression grammar" entry for the full pegex-vs-hand-written rationale table).
There is one expression parser implementation and no rollout flag.

Dispatch is **nested**, not a flat list of alternatives:
- `parse(_:)` is the `boolean` production (`not`/`either`/`and`/`or`,
  `it is not the case that …`), built from `pegex` keyword/choice primitives
  over a `QuoteAwareScanner`-protected `and`/`or` split. Mixing `and` and `or`
  at the same level without an intervening `either` is a hard `.malformed`
  error (2A rule); a leading comma before `and`/`or` is tolerated
  (Oxford-comma).
- `boolean`'s fundamental **atom**, tried at *every* leaf position it recurses
  to (the top of the expression, an `either`'s body, each and/or operand), is
  `parseClause`: `quantifier` → `emptiness`/`temporal-window` → `active-verb`
  → `comparison` → `parseAtom`, in that order.
- `parseAtom` tries `literal-atom` → `table-lookup` → (with a symbol table)
  `aggregate` → `superlative` → `scalar-navigation` → `description` →
  undeclared-passive-verb error → `possessive-chain` → bare identifier, in
  that order.

So a bare quantifier/description/etc. with no `and`/`or` in it still flows
through the same `parseClause` step as a combined `A and B` expression's
operands — there is no separate top-level branch for the uncombined case.

`NonterminalScreen` (Wave 5B) is wired in as a live pre-filter: `quantifier`,
`comparison`, `aggregate`, and `superlative` are gated by it before being
tried, since their anchor vocabularies are closed, lexicon-derived keyword
sets that fully cover what each production matches on. Productions with
open-ended or dynamic trigger sets (`active-verb`'s domain-declared verbs,
`emptiness`/`temporal-window`'s suffix forms) are always tried unconditionally.

`resolveBase` (inside `PossessiveChainParser`) checks `SymbolTable` to decide
whether a bare name is a `.constantRef`, `.instanceRef`, or plain
`.identifierRef`.

#### Output

`MeridianFile` containing `workflows: [WorkflowAST]`.

---

### Stage 5 — Lowering (`ASTToIR`)

`ASTToIR(symbols:sourceFile:).lower(_ file:)` produces `[IRWorkflow]`.

#### Workflow stub registration

Before lowering any workflow, every `WorkflowAST` is registered in the
symbol table as a `PhraseDefinition` stub (`workflowStructName` set,
empty body). This makes recursive and forward-reference workflow calls
resolvable during lowering.

#### `lowerStatement`

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
  └── no match → strict default: a coded `MER2001` diagnostic via
        `Diagnostic.unresolved` (always carrying a did-you-mean / candidate
         list). Only under `allow-fallbacks: unresolved-phrases` / lenient mode
         does it degrade to a `BindIR(name: "_unresolved", …)` placeholder
```

`simultaneously` lowers to `SimultaneouslyIR` whose `branches` is a list of
`IRBlock`s (one per parallel step).

##### Iteration refinements (1C)

A `for each` / `for every` / `every`/`each` loop may carry a single-clause
refinement that `StatementParser.extractIterationRefinement` strips off the noun
phrase, in this order:

```
for each [the first N] <kind plural>
        [whose <prop> <comp> <value> | within the last N <unit> | in the next N <unit>]
        [sorted by <prop>[, newest first|oldest first|ascending|descending]]
```

It parses into `IterationRefinementAST` (predicate / temporal / sort / take).
`ASTToIR.lowerIterationRefinement` lowers it to `IterateIR.source:
IRIterationRefinement?` (a struct payload — no new IR primitive; `nil` =
plain iteration):

- `whose` → the predicate's bare LHS is qualified to a property access on the
  loop variable (`whose total is at least 100` → `order.total >= 100`).
- temporal → a one-sided window comparison on the loop element's timestamp
  property (`ComparisonOp.withinPast` / `.withinFuture`). The property defaults
  to `updatedAt` and is configurable via a `=== language ===` `timestamp = …`
  entry (`LanguageSynonyms.timestampProperty` → `EnglishLexicon`).
- `sorted by` → `(camelCase(prop), ascending)`; `newest first`/`descending` =
  descending.
- `the first N` → `take = N` (applied **post-filter**).

`comparison` markers gained `is one of` (`.oneOf`) and `contains`
(`.contains`).

`SwiftEmitter.emitRefinedIterate` builds the refined source **pre-loop** so
`first N` counts after filtering:

```swift
let __src = (<collection>?.asList ?? [])
  .filter { __e in <predicate via emitElementExpr> }
  .sorted { __a, __b in MeridianComparison.orderedBefore(__a.member("p"), __b.member("p"), ascending: <bool>) }
let __srcRefined = Array(__src.prefix(<N>))   // omitted when take == nil
for (i, e) in __srcRefined.enumerated() { … }
```

`emitElementExpr` rewrites loop-var references into the closure parameter
(`__e`) and property accesses into `__e.member("p")`. The runtime helpers
`Value.member(_:)`, `MeridianComparison.orderedBefore(_:_:ascending:)`, and
`MeridianComparison.isWithinPast/isWithinFuture` back the generated closures.

##### Semantic core (Wave 2)

**Definition registration (runs first).** At the very top of `lower(_ file:)`,
`registerDefinitions(...)` ingests definitions from **both** the merconfig
vocabulary (`VocabularyStatement.definition`) and the `.meri` body
(`MeridianFile.definitions`) — before any workflow lowers — so an adjective
resolves regardless of source order or file. Registration:

1. Synthesizes a kind-namespaced function name `meridianDef_<Kind>_<adjCamel>`
   and rejects duplicate surface adjectives (collision error naming both sites).
2. Type-checks each body: every property the body reads must exist on the
   subject kind (own + ancestor chain), else a sourced error listing the known
   properties.
3. Detects recursion (direct or mutual) by DFS over the adjective-reference
   graph — a cycle is a hard error.

`lowerRegisteredDefinitions()` then lowers each body once (subject = the
definition's singular variable) into a `LoweredDefinition` carrying the
precomputed function name, which `Compiler.lowerAndEmit` threads into
`SwiftEmitter.emit`.

**Adjective predicates.** In `lowerComparison`, `X is/is not <adj>` where `adj`
is a registered definition **and** the LHS lowers to `.identifierRef` (subject
position) becomes `IRExpression.definitionPredicate(functionName:subject:)`
(`is not` wraps it in `.logical(.not, …)`). A `.propertyAccess` LHS is never
rewritten, keeping adjectives distinct from enum-value comparisons.

**Boolean trees in filters.** `qualifyToLoopVar` recurses over `.logical` and
`.definitionPredicate` trees (and qualifies only the **LHS** of a comparison),
so boolean conditions work inside `whose`/element filters and definition bodies.

**Quantifiers.** `lowerQuantifier` builds `IRExpression.quantified(QuantifierIR)`
with a `DescriptionIR { collection, elementVar, filters }`. The collection must
lower to a fetch-once source (`.identifierRef` / `.propertyAccess` /
`.constantRef` / `.instanceRef`); a direct `.invocation` source is a sourced
error. Leading adjectives and `whose` clauses lower to element-context filters
(adjectives → `.definitionPredicate`, `whose` → qualified comparison/logical).

**Shared condition grammar.** `lowerComparison` maps the new AST comparison
operators `withinPast` / `withinFuture` (temporal windows) and `isEmpty` /
`isNotEmpty` (property-backed emptiness) to their IR counterparts.

**Error carrier.** `ExpressionParser` stays non-throwing; surface violations
(mixed `and`/`or`, malformed quantifier/description, unidentifiable kind) become
an `ExpressionAST.malformed(String)` carrying a fully-formed diagnostic. The
throwing `lowerExpr` surfaces it as a sourced `CompilerError.semanticError`.

##### Relational layer (Wave 3)

**Symbol registration.** `MerConfigParser` parses two new sentence shapes into
`SymbolTable`: relation backings (`<Relation> is read from the <kind>'s
<property>.` / `… is read via the <tool> tool.` → `relationBackings`) and verbs
(`The verb to <base> (it <3rd>, it is <participle>) means the <relation>
relation.` → `verbs`, keyed by base form). `resolveVerbForm` maps any
conjugation back to its declared verb + role (`base` / `thirdPerson` /
`pastParticiple`).

**Validation (runs after definitions).** `ASTToIR.validateRelationsAndVerbs`:
every declared backing must name a declared relation and a valid kind/property
(property backing) or declared tool (tool backing); every verb must name a
**backed** relation; verb forms must be globally unambiguous. An unbacked
relation that no verb references is permitted (legacy vocabularies).

**Parser precedence.** `ExpressionParser.parseComparison` runs the active-verb
infix check *before* the comparison markers, but skips a verb immediately
preceded by a relativizer (`that`/`which`/`who`/`whose`) so a description's
relative clause is not mistaken for a top-level predicate. `parseAtom` tries
aggregate → superlative → scalar-navigation → description before falling back to
the possessive-chain atom.

**Lowering.**
- `lowerVerbPredicate` (active verb) → `.comparison(<obj>.<backingProp>,
  .identifies, <subj>)` for a property-backed relation; tool-backed verbs raise
  a sourced error (bind the related set first).
- `lowerScalarTraversal` (one-to-one navigation) → `.propertyAccess` for a
  property-backed relation; tool-backed inline navigation is an error.
- `lowerDescriptionPlan` → `DescriptionIR { collection, elementVar, filters,
  sort, take }`. The collection name is normalized singular→plural
  (`EnglishLexicon.pluralize`) so `the largest deal` reads the `deals` bind.
  A **tool-backed** clause sets the collection to a synthesized prelude `invoke`
  (hoisted via `lowerBindValue`), so descriptions over tool-backed relations are
  statement-only. Aggregates wrap a `DescriptionIR` (`.count` / `.list`);
  superlatives wrap one with a sort key (`SuperlativeIR`).

`ComparisonOp` gains `.identifies` (relation identity, runtime
`MeridianComparison.identifies`).

##### Markdown tables and task lists → IR

A table/checklist sentinel is expanded by `StatementParser` (Stage 4) *before*
lowering — it never produces a new IR primitive, only ordinary statements:

| Surface | Mode | Becomes |
|---|---|---|
| table | `decision` | one `if <conds>, <action>.` per row (re-parsed through the normal grammar → `BranchIR`) |
| table | `data[: name]` | `bind <name> = recordList(…)` → `IRExpression.recordList` |
| table | `ai-discretion` / `ai-autonomy` | one `ProseStepAST` (`TableParser.aiDecisionProse` renders rows as `when …, …`) → `IRPrimitive.aiJudgment(AIJudgmentIR)` / `.aiAutonomy(AIAutonomyIR)` |
| table | `iteration` / `inert` | nothing (reserved / documentation) |
| checklist | `invariant` (or unmarked) | one `assert` per item (checkable-or-error via `ConditionClassifier`) → `AssertIR` |
| checklist | `ai-discretion` / `ai-autonomy` | one `ProseStepAST` embedding every criterion as the goal → `IRPrimitive.aiJudgment` / `.aiAutonomy` |
| checklist | `inert` | nothing |

The AI-routed modes take the **same** `ProseStepAST →` (`aiJudgment` /
`aiAutonomy`) path as `use judgment to …:` (an explicit dispatch, via
`ASTToIR.makeAIPrimitive`), so they are valid in any workflow
— a fuzzy decision table or acceptance checklist becomes a planner step instead
of inert documentation. See [03_LANGUAGE.md](03_LANGUAGE.md).

`recover` lowers to `RecoverIR(attachedTo: IRBlock, pattern: ErrorPattern, handler: IRBlock)`.
The `attachedTo` block is the protected statement(s); `handler` is the catch block.

`wait` lowers the `WaitConditionAST` to `WaitConditionIR`:
- `.duration` → `WaitConditionIR.duration(Duration)`
- `.signal` → `WaitConditionIR.signal(String)`
- `.approval` → `WaitConditionIR.approval(of: IRExpression, by: RoleRef)`
- `.event` → `WaitConditionIR.event(String, matching: IRExpression?)`
- `.choice` → `WaitConditionIR.choice(prompt: String, options: [String])`

#### Wave 7 verbalization model seam

Every `CompiledFile` carries the `VerbalizerModel` built by the same bootstrap,
parse, validation, trigger synthesis, and lowering pass that produced its Swift
— `compile(_:)` no longer needs a second, model-only compile. The model holds
the lowered workflows plus the vocabulary context required to print them back as
Canonical English:

```swift
let model = try compiler.compile(unit)[file]!.model
```

`VerbalizerModel` contains `workflows`, lowered and inline definitions,
`SymbolTable`, `EnglishLexicon`, the source file name, authored source,
frontmatter metadata, outline, recorded skill sections, and `toolsUsed`.
`Verbalizer(model:).verbalize()` validates the workflows with `IRValidator` and
then renders the model as Canonical English; malformed hand-built IR throws
structured `MER4002` diagnostics before any placeholder canonical text can be
printed. The SEM-8-03 gate recompiles that canonical source and checks IR
structural equality. `DriftEngine` compares the authored source with the
canonical output for audit reports. Match-branch (`branch on`) lowers through
`MatchBranchStatementAST` and round-trips via the Verbalizer (`otherwise:` ↔
`BranchIR.thenBlock`). See [06_DEVELOPER_EXPERIENCE.md](06_DEVELOPER_EXPERIENCE.md).

#### Wave 8 trace-expression lowering

Trace-backed conditions are `IRExpression` cases — no new IR primitive:

- `.traceTemporal(TraceTemporalIR)` — `ever`, count-in-window, consecutive
  streak, `since the last` (resolved `holdsPattern: EventPatternIR` for codegen;
  pure state-predicate holds → **MER-TMP-019**).
- `.traceStatistical(TraceStatisticalIR)` — `usually`/`rarely`, percentage
  bounds, `occurrences`/`runs` denominators.
- `.eventPattern(EventPatternIR)` — step/event subjects with optional `whose`
  payload predicates.

`ASTToIR` validates window-vs-retention (**MER-TMP-011**), anchorless
`since the last` at obligation sites (**MER-STA-001**), and near-miss step/
field names (**MER-TMP-014**/**MER-TMP-015**). Monitored statistical asserts
carry `cadence` on `AssertIR`. See [04_RUNTIME.md](04_RUNTIME.md).

#### `lowerExpr`

Maps `ExpressionAST` to `IRExpression`:
- `.identifierRef(n)` → checks symbols: `constantRef` / `instanceRef` / `identifierRef`
- Multi-word identifiers (bind variable names) are camelCased via `camelCase(_:)`
- `.propertyAccess` traverses possessive chains
- `.comparison(lhs, op, rhs)` → `IRExpression.comparison`
- `.quantified(q)` → `IRExpression.quantified` (see "Semantic core" above)
- `.malformed(msg)` → throws a sourced `CompilerError.semanticError`

---

### Stage 6 — Emission (`SwiftEmitter`)

`SwiftEmitter.emit(workflows:constantsDecl:instancesDecl:domainDecl:fileMetadata:definitions:)`
validates the workflows with `IRValidator`, then produces all three Swift
strings from one traversal — `combined` (the single-file output), `domain` and
`workflows` (the multi-file split). It throws `MER4002` diagnostics for invalid
IR before emission. It uses `StringTemplate` from `modelhike`; each `emit*`
method returns a `StringTemplate` that is flattened via
`toString(separator: "\n")`.

See [02_ARCHITECTURE.md](02_ARCHITECTURE.md) for the full emission spec.

#### Progress labels and replay-safe resume

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

### Stage 7 — Formatting (optional)

`CompileCommand` passes the emitted string through `swift-format` unless
`--no-format` is provided. Errors during formatting are non-fatal (the
unformatted string is written).

---

### Section lowering (sectioned documents)

When the implicit-workflow body contains a `##`/`###` heading, the parser routes
it through `SkillSectionBuilder` (no `skill: true` flag — the discriminator is
structural). The builder splits the body into sections, resolves each heading
marker-first (`(( … ))` is authoritative) then by rulebook/built-in alias,
lowers executable sections per role, and **records every section** (executable
and non-executable alike) into `MeridianFile.skillSections`. There are no silent
drops: pre-heading content, unrecognized-heading-with-content, and non-checkable
invariant items are hard `semanticError`s.

A `## Tools Used` section (role `.tools`) is non-executable but
metadata-extracting: `extractToolID` mines each bullet's tool id into
`scopedTools` + the manifest `tools_used`. Two bullet forms are accepted —
`<description> (<tool_id>)` and the leading-backtick `` `<tool_id>` — <description>``
(any separator). A bullet matching neither (e.g. a backticked CLI command whose
token has spaces) is a hard error, so such sections stay `(( inert ))`.

### Stage 8 — Manifest emission (mandatory plumbing)

The manifest is a first-class, always-produced output. `Compiler.compile(_:)`
assembles a COMPLETE `ManifestEmitter.Input` — workflows, constants, tools,
kinds, instances, metadata, heading `outline`, rules, and the recorded
`skillSections` — during the same compile that emits Swift (`CompiledFile.manifest`). `ManifestEmitter.emit(_:)`
writes a `{stem}.meridian.manifest.json` companion: workflow names, parameters,
event IDs, tool IDs, source-map entries (from the `// L{line}` comments), and
`meridian_skill.sections` for sectioned documents. Non-executable section content
is guaranteed to reach the manifest, never best-effort.

---

### `Compiler.compile` return type

`compile(_ unit: CompilationUnit) -> [String: CompiledFile]` returns everything
one source produces, keyed by `SourceInput.file`: the Swift strings, the
complete `ManifestEmitter.Input`, and the `VerbalizerModel`. The one-source
`compile(meridianSource:…)` convenience returns just `CompiledFile.swift`.

### `Compiler` also exposes

```swift
// Emit Swift from pre-built IR (no parsing)
public func emit(workflows: [IRWorkflow], constantsDecl: SwiftEmitter.ConstantsDecl?) throws -> String

// Emit companion JSON manifest
public func emitManifest(_ input: ManifestEmitter.Input) throws -> String

// Bootstrap-only: real vocabulary/rulebook knowledge, no parse/lower/emit
public func bootstrap(_ unit: CompilationUnit) throws -> KnowledgeContext
```

### `CompilerError`

```swift
public enum CompilerError: Error, Sendable {
    case codegenError(message: String)
    /// One or more structured, coded diagnostics. A failed compile reports
    /// *all* collected errors here.
    case diagnostics([Diagnostic])

    /// Project ANY case into structured diagnostics so renderers, the CLI, and
    /// tests treat every error uniformly.
    public var diagnostics: [Diagnostic] { … }
}
```

Each `Diagnostic` carries a stable `DiagnosticCode` (e.g. `MER2002`), a
severity, the primary `SourceRange`, plus the remediation surface — a
did-you-mean `Suggestion` or candidate-list `DiagnosticNote`, optional `help`,
and the governing `DecisionRef`. See
[06_DEVELOPER_EXPERIENCE.md](06_DEVELOPER_EXPERIENCE.md) for the full anatomy and
the `MERxxxx` catalog, and [07_DECISIONS.md](07_DECISIONS.md) for the decisions
the codes link to.

### Batch reporting via `DiagnosticEngine`

Lowering does not abort on the first error. A per-file, single-threaded
`DiagnosticEngine` (`Sources/MeridianCore/Diagnostics/DiagnosticEngine.swift`)
**collects** diagnostics and recovers at construct boundaries (workflow / rule /
statement), skipping the offending construct wholesale rather than resyncing
token-by-token (which would spawn cascade/phantom errors). Phrase stubs are
pre-registered first, so a later workflow still resolves a reference to an
earlier one even if that earlier one had an error. At the end of the phase
`throwIfErrors()` raises a single `CompilerError.diagnostics([…])` with every
collected error. The engine also mirrors each diagnostic into the trace stream
(`.diagnostics` category) so `--trace diagnostics` shows them inline. This is
decision **D-DX-2** (no silent fallbacks; batch-report with coarse recovery).

### Error handling

| Stage | Error type | Behaviour |
|---|---|---|
| Tokenisation | `\u{E000}markererror` sentinel | Non-throwing; raised later as a coded diagnostic by `StatementParser` |
| Config parse | `CompilerError` | Unrecognized vocabulary declarations → `MER5002`; bad rulebook sections → `MER5003` |
| Meridian parse | `CompilerError` | Malformed headers → `MER1001`, orphaned code blocks → `MER1002`, unparseable statements/rules → `MER1003`/`MER1004`, misplaced frontmatter → `MER1006`, removed `import` form → `MER1008` |
| Lowering | `CompilerError.diagnostics` | **Strict-by-default, batch-collected.** Unresolved phrase → `MER2001`; unknown tool → `MER2002`; unknown kind/property/adjective/verb → `MER2003`/`MER2004`/`MER2007`/`MER2008`; a matched workflow/phrase call missing a declared parameter's argument (hardening guard; see `ASTToIR.lowerPhraseInvocation`) → `MER2011`; unattached rule → `MER3006`; unresolved trigger action → `MER3007`; a rule predicate that can't lower to a rule-body expression (quantifier/description/aggregate/superlative/relation-traversal/verb-predicate/table-lookup/parse-error inside a `must`/`must not` predicate) → `MER3016`. Per-file `allow-fallbacks:` (or `Compiler.Options.fallbackPolicy = .lenient`) downgrades the matching kind back to a `_unresolved`/stub placeholder |
| Emission | `IRValidationError` / `CompilerError` | `IRValidator` rejects malformed IR before `Verbalizer` or `SwiftEmitter` output with `MER4002`; codegen failures surface as `MER4001` |
| Formatting | warning (`MER5001`) | **Non-fatal** (D-DX-3): the unformatted Swift is kept and written; a warning is reported to stderr |

The CLI renders all of the above through a single `DiagnosticRenderer`
(`reportCompilerError`), in either human (snippet + caret + did-you-mean) or
`--diagnostics-format json` form, and `--fix` applies the unambiguous
suggestions. See [05_CLI.md](05_CLI.md) and
[06_DEVELOPER_EXPERIENCE.md](06_DEVELOPER_EXPERIENCE.md).

### Wave 4 Pipeline Notes

`.meri` `## Domain` sections are harvested before symbol-table construction.
The harvester reuses `MerConfigParser` vocabulary productions and merges the
result into the effective `MerConfigFile`, so inline kinds/properties participate
in parameter parsing, relation validation, and domain codegen exactly like
`.merconfig` declarations.

Under `## Tables`, unmarked Markdown tables are rewritten to data-table mode by
`SkillSectionBuilder` before statement parsing. `StatementParser` validates typed
cells, then lowers the table to the existing record-list expression. Table lookup
syntax lowers to `IRExpression.tableLookup`, an expression-only scan over the
bound table that throws `table.lookup_miss` on a required miss.

Text substitutions remain expression payloads: `ExpressionParser` emits nested
`InterpolationSegment` trees for `[if]`, `[for each]`, and formatted holes;
`ASTToIR` recursively lowers them to `IRInterpolationSegment`; `SwiftEmitter`
turns the payload into Swift string-building code.

---

## Code generation

*Was `docs/05_CODEGEN.md`.*

`SwiftEmitter` (in `Sources/MeridianCore/Codegen/SwiftEmitter.swift`) converts
an `[IRWorkflow]` into a single Swift source file. It uses `StringTemplate`
from the `modelhike` package as a DSL for building indented code blocks.

---

### File structure

A generated file looks like this:

```swift
// THIS FILE IS GENERATED BY MERIDIAN. DO NOT EDIT.
// Source: order_processing.meridian

import Foundation
import MeridianRuntime

// Domain types (from vocabulary)
public enum OrderStatus: String, Hashable, Codable, Sendable { case draft, submitted, … }

public protocol OrderKind: MeridianThing {
    var totalAmount: Money { get }
    // …own properties only
}
public struct Order: OrderKind { var id: String; var totalAmount: Money; … }

public protocol CustomerKind: PersonKind { … }
public struct Customer: CustomerKind { var id: String; var name: String; var email: String; … }

public struct Constants: Sendable {
    public let highValueThreshold: Money = Money(amount: Decimal(5000), currency: "USD")
    public let maximumRetryCount: Decimal = Decimal(3)
    // …
}

private let constants = Constants()

public struct Instances: Sendable {
    public let primaryMailer: Value = .record([
        "host": .string(ProcessInfo.processInfo.environment["SMTP_HOST"] ?? ""),
        "port": .number(Decimal(587)),
        "authType": .string("tls"),
    ])
    public let stripe: Value = .record([…])
}

private let instances = Instances()

public struct ProcessOrder: MeridianWorkflow {
    public let runtime: Runtime
    public let order: Order
    public let customer: Customer

    public init(runtime: Runtime, order: Order, customer: Customer) { … }

    public func run() async throws -> WorkflowResult {
        var state = State()
        state.bind("order", order)
        state.bind("customer", customer)
        let constants = Constants()
        let instances = Instances()

        // Resume context — replay-safe resume
        let __meridianResumeContext = await runtime.consumeResumeContext()
        if let ctx = __meridianResumeContext {
            state.restore(from: ctx.restoredState)
        }
        func __meridianShouldRun(_ label: String) -> Bool {
            guard let ctx = __meridianResumeContext else { return true }
            guard let last = ctx.lastCheckpointLabel else { return true }
            return label > last
        }

        await runtime.workflowStarted(workflowName: "ProcessOrder", parameters: [:])

        // L80
        if __meridianShouldRun("progress:0.0:L80:C0") {
            let result = try await runtime.invoke(
                tool: "validateOrder",
                args: [ "id": state.get("order.id") ?? .null ]
            )
            state.bind("result", result)
            try await runtime.checkpoint(label: "progress:0.0:L80:C0", state: state.snapshot())
        }
        // …
        await runtime.complete(reason: nil)
        return WorkflowResult(reason: nil, durationMS: await runtime.elapsedMS(), …)
    }
}
```

---

### Domain types (`DomainEmitter`)

When the merged `MerConfigFile.vocabulary` declares any `kind`, codegen emits
a typed Swift block before `Constants` / `Instances`.

#### Three emission paths

| Kind shape | Output |
|---|---|
| Scalar parent + no own properties | Single `public typealias <KindName> = <SwiftScalar>`. Typealiases can't carry conformance, and most of these kinds have no behaviour worth threading through a protocol. |
| Has own properties **or** is named as some other kind's parent (chain anchor) | `public protocol <KindName>Kind: <ParentProto>` + `public struct <KindName>: <KindName>Kind`. |
| Leaf kind with no own properties and no descendants | `public struct <KindName>: <ParentProto>` only — the `<KindName>Kind` protocol is elided because it would be empty and add nothing the parent doesn't already give us. |

`<ParentProto>` is `Meridian<Base>` for semantic-base parents, or
`<ParentKind>Kind` when the parent is another declared kind.

The elision rule keeps generated output proportional to the information in
the merconfig. Vocabulary authors who *want* a named protocol for a
property-less kind get one for free by either adding a single property or
declaring a child kind that inherits from it (chain-anchor case).

For each `which is one of (a, b, c)` property, codegen also emits a top-level
`enum <KindType><PropertyName>: String, Hashable, Codable, Sendable` (e.g.
`OrderStatus`, `ApprovalVerdict`). Multi-word raw values are spelled out:
`case underReview = "under review"`.

#### Generated protocol/struct pair

`A pull request is a kind of thing.` lowers to:

```swift
public protocol PullRequestKind: MeridianThing {
    var title: String { get }
    var author: String { get }
    // …own properties only — inherited come transitively
}

public struct PullRequest: PullRequestKind {
    public var id: String
    public var title: String
    public var author: String
    // …all flattened properties in declaration order

    public init(
        id: String = "",
        title: String = "",
        author: String = ""
    ) { … }
}
```

Protocol requirements list **own** properties only — inherited requirements
come transitively through `<Parent>Kind`. The struct flattens the entire
chain so a single instance satisfies every level. The defaulted init keeps
fixtures terse.

A leaf kind with no own properties skips the protocol entirely:

```swift
// `A comment is a kind of thing.`  (no own properties, no descendants)
public struct Comment: MeridianThing {
    public var id: String
    public init(id: String = "") { self.id = id }
}
```

#### Semantic bases — `Meridian<Base>` runtime protocols

`Sources/MeridianRuntime/Domain/Thing.swift` defines a base
`MeridianKind` protocol (composes `Hashable`, `Codable`, `Sendable`,
`var id: String { get }`) and semantic marker protocols composing it:

| Vocabulary base | Generated parent | Use for |
|---|---|---|
| `thing` | `MeridianThing` | Generic identity-bearing entity (orders, repos, …) |
| `event` | `MeridianEvent` | Something that occurred — emit/wait/observability records |
| `action` | `MeridianAction` | A discrete operation a workflow can take |
| `tool` | `MeridianTool` | A domain capability or instrument that does work |
| `system` | `MeridianSystem` | External/internal platforms, products, or servers |
| `integration` | `MeridianIntegration` | Configured connectors, accounts, webhooks, or adapters |
| `artifact` | `MeridianArtifact` | Software/work products such as repos, patches, reports, logs |
| `service` | `MeridianService` | Hosted APIs or service endpoints |
| `agent` | `MeridianAgent` | Autonomous AI/software actors |
| `model` | `MeridianModel` | LLMs, embedding models, classifiers, or evaluators |
| `dataset` | `MeridianDataset` | Corpora, eval sets, indexes, or knowledge bases |
| `storage` | `MeridianStorage` | Databases, buckets, queues, caches, vector stores |
| `credential` | `MeridianCredential` | API keys, tokens, service accounts, auth configs |
| `policy` | `MeridianPolicy` | Guardrails, routing rules, approval/retention policies |
| `environment` | `MeridianEnvironment` | Runtime targets and boundaries |
| `resource` | `MeridianResource` | Infrastructure or allocatable capacity |
| `metric` | `MeridianMetric` | Measured signals, SLOs, eval scores, quality indicators |
| `memory` | `MeridianMemory` | Agent/session memory, retained context, long-term knowledge |
| `process` | `MeridianProcess` | A long-running unit of work with lifecycle state |
| `message` | `MeridianMessage` | A one-way communication payload |
| `signal` | `MeridianSignal` | A named broadcast workflows can wait/deliver |
| `fact` | `MeridianFact` | Asserted knowledge / evidence |
| `role` | `MeridianRole` | An actor identity used in permissions / approvals |
| `verdict` | `MeridianVerdict` | A decision outcome |

These markers are intentionally empty — the discriminator is the type name,
not an opinionated baseline. Forcing `Event` to declare an `occurredAt` or
`Action` to declare a `verb` would be wrong for many host vocabularies.

The `Meridian` prefix is mandatory: `Event` is already a public struct in
`MeridianRuntime`, `Process` is in Foundation. Prefixing every base
uniformly avoids surprise for vocabulary authors.

#### Workflow init signatures

Generated workflow init signatures use the structs directly (the protocol
is for host code that needs to constrain to "anything that's a Role" or
"anything that's an Event"):

```swift
public init(runtime: Runtime, order: Order, customer: Customer)
```

---

### `Constants` struct

Generated when `MerConfigFile.constants` is non-empty.

- Type is `public struct Constants: Sendable`.
- Each constant becomes a `public let` with an inferred Swift type.
- A `private let constants = Constants()` module-level binding is also emitted.
- Inside each workflow's `run()`, `let constants = Constants()` shadows the
  module binding (so workflows always have a local `constants`).

---

### `Instances` struct

Generated when `MerConfigFile.instances` is non-empty.

- Type is `public struct Instances: Sendable`.
- Each instance becomes a `public let name: Value = .record([…])`.
- Property values are emitted as `Value` cases.
- A `private let instances = Instances()` module-level binding is emitted.
- Inside each workflow's `run()`, `let instances = Instances()` is emitted too.

`IRExpression.instanceRef(name:)` emits as `instances.<camelCaseName>`.

---

### IR primitive emission details

| Primitive | Key emission detail |
|---|---|
| `invoke` | `let x = try await runtime.invoke(tool: "id", args: […])` + `state.bind("x", x)` |
| `bind` / `rebind` | Both use `BindIR` (`isRebind: Bool`). Emit `state.bind(…)` or `state.rebind(…)`. |
| `branch` | `BranchIR.condition` is `BranchCondition`: `.predicate(expr)` → `if/else`; `.match(expr, cases)` → `switch`/`case`, plus `default:` when `BranchIR.thenBlock` is non-empty (Verbalizer `otherwise:` ↔ IR `thenBlock` ↔ codegen `default:`) |
| `iterate` | `IterateIR.mode` is `IterateMode`: `.overCollection` → `for x in (state.get("items")?.asList ?? []) { … }`; `.whileCondition` → `while`; `.untilCondition` → `while !(…)`. Loop iterations checkpoint at each boundary with a unique `__meridianLoopLabel_N` identifier. |
| `assert` | `AssertIR.otherwiseAction: IRBlock?`. If nil: `try await runtime.assert(condition, message: "…")`. If set: `if !condition { try await runtime.assert(false, …); <block> } else { try await runtime.assert(true, …) }`. Both shapes route through `Runtime.assert` so `assert.passed` / `assert.failed` events fire. |
| `emit` | `EmitIR.payload: [EmitField]` (not a dict). `EmitIR.strict: Bool` × `IRWorkflow.mode` decides `try await runtime.emit` vs `await runtime.emitLenient` |
| `wait` | `WaitIR.condition: WaitConditionIR`. Duration emits `try await runtime.wait(.duration(.seconds(…)))`. Signal emits `try await runtime.wait(.signal("name"))`. Approval emits `try await runtime.wait(.approval(of: …, by: RoleRef(identifier: "…")))`. Event with matching emits a `{ _event in … }` closure. Choice gates emit `ask.choice` + `runtime.wait(.choice(prompt:options:))`. |
| `commit` | `CommitIR.label: String?`. Emits `try await runtime.checkpoint(label: "x", state: state.snapshot())` |
| `recover` | `RecoverIR.attachedTo` is the protected block, `.handler` is the catch block. Emits `do { <attachedTo> } catch let _recoveredError { <handler> }`. Named patterns use `meridianMatches(_recoveredError, named: "…")`. |
| `complete` | Emits two statements: `await runtime.complete(reason:)` then `return WorkflowResult(…)` |
| `simultaneously` | Emits a `try await withThrowingTaskGroup(of: Void.self) { group in … }` block. Each `SimultaneouslyIR.branches[i]` becomes `group.addTask { … }`. After all tasks are added, the group drains with `for try await _ in group { }`. |
| `aiJudgment` | `emitAIJudgment(AIJudgmentIR)` → `try await runtime.executeProsePlan(prose: "…", scopedTools: […], …)`. The prose `text` is `escapeSwiftString`-escaped. Produced by `use judgment to …:`, `with discretion` bodies, AND `!!! table (( ai-discretion ))` / `!!! checklist (( ai-discretion ))` (see [03_LANGUAGE.md](03_LANGUAGE.md)). When `AIJudgmentIR.guidance` is non-nil, it is emitted as a trailing, `escapeSwiftString`-escaped `guidance: "…"` argument on the same call — extra planner context distinct from `text`, not folded into the dispatch goal. `ManifestEmitter` records every workflow's judgment steps (`text`, `scoped_tools`, `guidance`, `line`) under `workflows[].judgment_steps`. |
| `aiAutonomy` | `emitAIAutonomy(AIAutonomyIR)` → `runtime.executeAutonomousLoop(…)` with the `AutonomyConfigIR` (`until` / `unless` closures over a restored `StateSnapshot`, `replanAfterFailures`, `maxSteps`). The prose `text` is `escapeSwiftString`-escaped. Produced by `with autonomy` bodies AND `!!! table (( ai-autonomy ))` / `!!! checklist (( ai-autonomy ))` (see [03_LANGUAGE.md](03_LANGUAGE.md)). `AIAutonomyIR.guidance`, when non-nil, is emitted the same way as `aiJudgment`'s. `ManifestEmitter` records every workflow's autonomy steps under `workflows[].autonomy_steps`. Two distinct IR cases (not one primitive branching on a `dispatchMode` field) keep judgment and autonomy separately auditable in the manifest and exhaustively `switch`-checked in codegen/IR-walking code. |

---

### Replay-safe resume

Every generated `run()` has three replay components:

**1. Resume context consumption** (top of `run()`):

```swift
let __meridianResumeContext = await runtime.consumeResumeContext()
if let ctx = __meridianResumeContext {
    state.restore(from: ctx.restoredState)
}
func __meridianShouldRun(_ label: String) -> Bool {
    guard let ctx = __meridianResumeContext else { return true }
    guard let last = ctx.lastCheckpointLabel else { return true }
    return label > last
}
```

**2. Progress guard on each side-effecting primitive**:

```swift
if __meridianShouldRun("progress:0.0:L80:C0") {
    let result = try await runtime.invoke(…)
    state.bind("result", result)
    try await runtime.checkpoint(label: "progress:0.0:L80:C0", state: state.snapshot())
}
```

**3. Implicit checkpoint after each guarded primitive** — so a resumed run that
crashes mid-workflow advances the checkpoint frontier.

Progress labels are stable across compilations for the same source. They encode
the IR tree path and source line/column so relocated statements get new labels
automatically.

To resume a run from a checkpoint, call:

```swift
try await runtime.prepareResume(runID: "my-run")
let result = try await ProcessOrder(runtime: runtime, order: order, customer: customer).run()
```

`prepareResume` stores the context on the actor; `consumeResumeContext()` returns
and clears it atomically at the start of `run()`.

---

### Workflow struct naming

`IRWorkflow.structName(from: name)` converts a natural-language workflow
name to UpperCamelCase:

| Natural name | Struct name |
|---|---|
| `process an order placed by a customer` | `ProcessOrder` |
| `validate an order` | `ValidateOrder` |
| `leniently sync analytics for an order placed by a customer` | `LenientlySyncAnalytics` |

The algorithm: take significant words (skip articles `a/an/the`) up to and
excluding the first preposition-that-introduces-a-parameter.

---

### Value wrapping

`[String: Value]` dictionaries (invoke args, emit payloads) need every value
to be a `Value`. Two emission helpers exist:

**`emitExpr`** — used in conditions (returns Swift expression, often `Value?`):

| IRExpression | Emitted by `emitExpr` |
|---|---|
| `.literal(.string("x"))` | `"x"` |
| `.literal(.number(n))` | `Decimal(n)` |
| `.nowExpression` | `Date()` (bare — NOT `.date(Date())`) |
| `.identifierRef("key")` | `state.get("key")` → returns `Value?` |
| `.propertyAccess(base, "prop")` | `state.get("base.prop")` → returns `Value?` |
| `.constantRef("x")` | `constants.camelX` |
| `.instanceRef("x")` | `instances.camelX` |
| `.envVar("FOO")` | `ProcessInfo.processInfo.environment["FOO"] ?? ""` |

**`emitValueExpr`** — used inside `[String: Value]` dict literals (invoke args, emit payloads):

| IRExpression | Emitted by `emitValueExpr` |
|---|---|
| `.literal(.string("x"))` | `.string("x")` |
| `.literal(.number(n))` | `.number(Decimal(n))` |
| `.literal(.boolean(b))` | `.boolean(b)` |
| `.literal(.money(a, c))` | `.money(Money(amount: Decimal(a), currency: "c"))` |
| `.literal(.duration(d))` | `.duration(Duration.seconds(…))` |
| `.nowExpression` | `.date(Date())` |
| `.identifierRef` / `.propertyAccess` | `state.get("key") ?? .null` |
| `.constantRef` / `.instanceRef` | `Value.from(constants.x)` / `Value.from(instances.x)` |
| `.envVar("FOO")` | `.string(ProcessInfo.…["FOO"] ?? "")` |
| `.recordList(fields, rows)` | `Value.list([.record([...]), …])` |

`Value.from(_:)` overloads in `MeridianRuntime/Value/ValueCoercion.swift` bridge
typed Swift primitives into `Value`.

A `.recordList` (lowered from a Markdown *data table*) emits a
`Value.list([.record([...]), ...])`, one record per row; field keys are
camelCased so a later `for each row in <name>` resolves `row.<field>` against the
record. Both `emitExpr` and `emitValueExpr` share `emitRecordList`.

---

### Comparison emission

`state.get(…)` returns `Value?`. Swift cannot compare `Value?` with `<`, `>`, or `==`
directly. When either operand of a comparison reads from state, codegen routes
through `MeridianComparison.*` helpers.

```swift
// Generated from: if the available credit is less than the order's total amount
if MeridianComparison.lt(state.get("available"), state.get("order.totalAmount")) {
```

```swift
// Generated from: if the order's total amount is more than the high value threshold
if MeridianComparison.gt(state.get("order.totalAmount"), constants.highValueThreshold) {
```

Overloads exist for `Value? op Value?`, `Value? op T`, and `T op Value?` where
`T: NumericConvertible` (Decimal, Money, Duration, Int, Double).

Special comparisons:

| ComparisonOp | Emitted |
|---|---|
| `.withinDuration` | `MeridianComparison.isWithin(lhs, rhs)` |
| `.contains` | `(lhs).contains(rhs)` |
| `.startsWith` | `(lhs).hasPrefix(rhs)` |
| `.endsWith` | `(lhs).hasSuffix(rhs)` |
| `.oneOf` | `(rhs).contains(lhs)` |
| `.withinPast` | `MeridianComparison.isWithinPast(lhs, rhs)` (`of:` defaults to `Date()`) |
| `.withinFuture` | `MeridianComparison.isWithinFuture(lhs, rhs)` (`of:` defaults to `Date()`) |
| `.isEmpty` | `MeridianComparison.isEmpty(lhs)` |
| `.isNotEmpty` | `MeridianComparison.isNotEmpty(lhs)` |

---

### Semantic core emission (Wave 2)

#### Definition predicates

Each lowered `Definition` emits a file-scope `private func` right after the file
header (alongside `meridianStringify`), so enum namespacing is unaffected. The
body is emitted in **element context** (subject = the closure parameter):

```swift
// Definition: a page is stale if it has no summary.
private func meridianDef_Page_stale(_ __subject: Value?) -> Bool {
  return MeridianComparison.isEmpty(__subject.member("summary"))
}
```

`IRExpression.definitionPredicate(functionName:subject:)` emits a call to that
helper. In statement context the subject reads from state
(`meridianDef_Page_stale(state.get("page"))`); in element context it passes the
loop/closure element (`meridianDef_Page_stale(__e)`). `is not <adj>` wraps the
call: `!(meridianDef_Page_stale(...))`.

#### Quantifier expressions

`IRExpression.quantified` emits a single self-contained Swift expression so it
slots into any condition position (`if`, `assert`, …). The collection is fetched
once (`?.asList ?? []`), the description's `whose`/adjective filters apply first,
then the optional `have/are` body and the cardinality reducer:

```swift
// if at least 2 pages whose status is "published" have a summary
((((state.get("pages"))?.asList ?? []).filter { __e in
  (MeridianComparison.eq(__e.member("status"), .string("published")))
}).filter { __e in MeridianComparison.isNotEmpty(__e.member("summary")) }.count >= 2)
```

Let `base = ((coll)?.asList ?? []).filter { __e in <filters> }` and
`bodyClause = .filter { __e in <body> }` (empty when there is no body). Reducers
by quantifier kind:

| Kind | Reducer |
|---|---|
| `all` / `every` | `base.allSatisfy { __e in <body> }` (body required; vacuously true on empty) |
| `any` / `some` | `!(base bodyClause).isEmpty` |
| `none` | `(base bodyClause).isEmpty` |
| `at least N` | `(base bodyClause).count >= N` |
| `at most N` | `(base bodyClause).count <= N` |
| `exactly N` | `(base bodyClause).count == N` |

The closure parameter is always `__e`. The runtime helpers `Value.asList`,
`Value.member`, `MeridianComparison.isEmpty` / `isNotEmpty`, and the Wave 1
temporal/order helpers back the generated closures.

### Relational layer emission (Wave 3)

#### Active-verb conditions

A property-backed active verb (`the user owns the page`) emits an identity
comparison on the backing property — no tool call:

```swift
if MeridianComparison.identifies(state.get("page.owner"), state.get("user")) { … }
```

`MeridianComparison.identifies(link, entity)` matches a foreign-key string /
reference / record-`id` on either side, and a list link matches when any element
identifies the entity. `ComparisonOp.identifies` also drives `emitElementExpr`
(when the verb appears inside a description filter, the operand is the closure
element `__e`).

#### Descriptions, aggregates, superlatives

`emitDescriptionList` renders a description as a `[Value]` pipeline over the
fetch-once collection: `(coll.asList ?? []).filter { __e in … }`, then an
optional `.sorted { __a, __b in MeridianComparison.orderedBefore(…) }`, then an
optional `.prefix(N)`.

```swift
// let owned be the pages owned by the user.
state.bind("owned", Value.list(((state.get("pages"))?.asList ?? [])
  .filter { __e in (MeridianComparison.identifies(__e.member("owner"), state.get("user") ?? .null)) }))

// let biggest be the largest deal by amount.
state.bind("biggest", (((state.get("deals"))?.asList ?? [])
  .sorted { __a, __b in MeridianComparison.orderedBefore(__a.member("amount"), __b.member("amount"), ascending: false) }.first))
```

| IR | Emission |
|---|---|
| `.description(d)` | `Value.list(<pipeline>)` |
| `.aggregate(.count, d)` | `Decimal(<pipeline>.count)` (wrapped so `> 5` type-checks) |
| `.aggregate(.list, d)` | `Value.list(<pipeline>)` |
| `.superlative(s)` | `(<sorted-pipeline>.first)` |

A **tool-backed** description is lowered with its collection set to a hoisted
prelude `invoke`; the emitted bind reads that synthetic result. `let assigned be
the task assigned to the user.` (scalar navigation, property-backed) emits
`state.bind("assigned", state.get("user.task"))`.

`needsValueComparison` returns `true` for `.superlative`, `.description`, and
`.aggregate(.list)` so `Value`-aware comparison helpers are used; a `.count`
aggregate is a `Decimal` and compares with the plain numeric operators.

---

### Workflow recursion

When `lowerPhraseInvocation` matches a phrase stub registered for a workflow
(i.e., `phrase.workflowStructName != nil`), it emits:

```
InvokeIR(toolID: "workflow:ProcessOrder", arguments: [ordered by pattern])
```

`SwiftEmitter.emitInvoke` detects the `workflow:` prefix and calls
`emitWorkflowCall`, which produces:

```swift
_ = try await ProcessOrder(runtime: runtime, order: order, customer: customer).run()
```

Argument order follows the workflow's pattern parameter list (not dict
iteration order).

`emitWorkflowCallArg` forwards typed in-scope variables directly — `.identifierRef`
emits as a bare Swift name, not `state.get(…)`, because the init expects the
domain type (`Order`), not `Value`.

---

### Source-line comments

When `SwiftEmitter.Options.emitSourceLineComments` is `true` (the default),
each IR primitive gets a `// L{lineNumber}` comment on its own line above it.
Disable with `--no-line-comments` via the CLI or `SwiftEmitter.Options(emitSourceLineComments: false)`.

---

### Manifest emission

`ManifestEmitter.emit(_:)` produces a `{stem}.meridian.manifest.json` companion.
The manifest includes:

- Source file names
- Workflow names, struct names, parameters, and execution modes
- Event IDs emitted by each workflow
- Tool IDs invoked by each workflow
- Source-map entries: `{ "primitive": "invoke", "line": 80, "tool": "validateOrder" }`
- `meridian_skill` — frontmatter metadata, the heading `outline`, and (for
  sectioned documents) the `sections` array (below).

#### `meridian_skill.sections` (mandatory)

For a sectioned document, **every** markdown section — executable and
non-executable alike — is recorded under `meridian_skill.sections`. This is a
hard guarantee, not best-effort: non-executable content is never silently
dropped, it is always preserved here verbatim. Each entry is:

```json
{ "heading": "Contract", "role": "invariants", "executes": false,
  "line": 23, "lines": ["This skill guarantees:", "- …"] }
```

- `role` — the executable role derived/forced for executable sections; the
  explicit `role:` for marked-inert sections; `"inert"` for `(( inert ))` with
  no role (never derived from the heading).
- `executes` — whether the section lowered to runnable IR.
- `lines` — the section's verbatim content lines.
- `outline[].kind` follows the same resolved-role rule.

`meridian_skill` is emitted whenever `metadata != nil || !outline.isEmpty ||
!skillSections.isEmpty`. `JSONSerialization` uses `.sortedKeys` and section
order follows source order, so two compiles of the same input are byte-identical.

#### `meridian_definitions` (Wave 2B)

Every checkable adjective `Definition:` (from either the `.meri` body or a
`.merconfig` vocabulary) is recorded under `meridian_definitions` when present.
Each entry pairs the surface adjective with its generated predicate function so
a host can map an adjective back to the emitted Swift:

```json
{ "adjective": "stale", "kind": "page",
  "function": "meridianDef_Page_stale", "line": 6 }
```

Entries are sorted by `function` (deterministic). The key is omitted entirely
when no definitions are present, so non-definition files are byte-unchanged.

#### `meridian_relations` / `meridian_verbs` (Wave 3)

Declared relations (with a backing) and verbs are recorded so a host can map a
verb back to its relation and evaluation strategy:

```json
"meridian_relations": [
  { "name": "ownership", "left_kind": "user", "left_cardinality": "one",
    "right_kind": "page", "right_cardinality": "many",
    "backing": "property", "via": "page.owner", "line": 34 }
],
"meridian_verbs": [
  { "base": "own", "third_person": "owns", "past_participle": "owned",
    "relation": "ownership", "line": 36 }
]
```

`backing` is `"property"` or `"tool"`; `via` holds the `<kind>.<path>` (property
backing) or the tool id (tool backing). Only relations that have a declared
backing are emitted. Both keys are omitted when empty, so non-relational files
are byte-unchanged.

#### Complete manifest input

`Compiler.compile(_:) -> [String: CompiledFile]` assembles a COMPLETE
`ManifestEmitter.Input` (workflows, constants, tools, kinds, instances,
metadata, outline, rules, and `skillSections`) as part of every compile
(`CompiledFile.manifest`) — there is no longer a silent-loss point where rich
data computed during compilation is discarded. The one-source
`compile(meridianSource:…)` convenience returns just the Swift string. The CLI
writes the full Input (merging in the source map) on every `meridian compile`.

---

### StringTemplate

`SwiftEmitter` uses `StringTemplate` from `modelhike`. Each `emit*` method
returns a `StringTemplate` instance. The top-level
`emit(…).combined` render flattens nested templates into a line-per-item
`String`.

`Ctx` (context object) carries indent depth and options, and exposes `.s`
(the current indent string) and `.in(n)` (deeper context).

---

### `emit` signature

```swift
public func emit(
    workflows: [IRWorkflow],
    constantsDecl: ConstantsDecl? = nil,
    instancesDecl: InstancesDecl? = nil,
    domainDecl:    DomainDecl?    = nil,
    fileMetadata:  FileMetadataAST? = nil,
    definitions:   [LoweredDefinition] = []
) throws -> SwiftEmitter.Output   // { combined, domain, workflows }
```

`Compiler.compile` builds `ConstantsDecl`, `InstancesDecl`, and
`DomainDecl` from the parsed `MerConfigFile` and passes them here; the
`combined` string is the single-file output and `domain` / `workflows` are the
`--multi-file` split.

---

### Multi-vocabulary

`Compiler.CompilationUnit.vocabularies` accepts a list of
`Compiler.VocabularyInput` records (`name`, `file`, `source`).
Every input is parsed and merged via `MerConfigFile.merging(_:)` before
the symbol table is built.

`Compiler.validateImports(_:against:file:)` rejects a `vocabulary:` reference
that doesn't name a supplied vocabulary with a coded `MER2005` diagnostic
(`Diagnostic.unresolved` — sourced, with a did-you-mean against the supplied
names). `Compiler.requireUniqueDeclarations(in:)` rejects duplicate kind /
phrase / tool / constant / instance names in the merged config with a sourced
error.

The CLI's `--merconfig` flag is repeatable; if it's omitted, every
`.merconfig` next to the input is auto-discovered (sorted by name for
deterministic ordering).

---

### gbrain SKILL surface emission

Three additive codegen forms support the gbrain SKILL surface. They reuse
existing emitters; no new IR primitives are involved.

#### Shell command invokes

A fenced ` ```bash ` block or inline backticked `gbrain …` command in a
`procedure` section lowers to `InvokeIR(toolID: "shell.run", arguments:
[("command", .literal(.string(cmd)))])`. This is plain invoke codegen — one
`runtime.invoke(tool: "shell.run", …)` call per command line — so no codegen
change was needed beyond routing the command text through the existing path.
The command string is base64-carried through a sentinel
(`shellCommandSentinelPrefix`) during parsing to avoid escaping issues, then
decoded in `ASTToIR.lowerPhraseInvocation` before emission.

#### Detached `Task {}` (background spawn)

`SimultaneouslyIR` gained a `detached: Bool` flag. `emitSimultaneously` branches
on it:

```swift
// detached: false (default) — joins all branches
try await withThrowingTaskGroup(of: Void.self) { group in
    group.addTask { … }
    try await group.waitForAll()
}

// detached: true — fire-and-forget, no join
Task {
    …
}
```

`in the background, <stmt>.` lowers to a single-branch
`SimultaneouslyIR(detached: true)`, so the spawned work never blocks the caller.

#### Choice-gate

`ask the user to choose between "A", "B".` lowers to three pieces:

1. `emit ask.choice` with the prompt + options payload,
2. `wait` on `WaitConditionIR.choice(prompt:options:)` — `emitWait` emits
   `try await runtime.wait(.choice(prompt: "…", options: ["A", "B"]))`,
3. the subsequent `if the choice is "A",` branch reads the delivered selection
   via `runtime.consumeChoiceSelection()`.

The host delivers the user's pick with `runtime.deliverChoice(_:)`. See
[04_RUNTIME.md](04_RUNTIME.md) §"Choice-gate".

### Wave 4 Codegen

Enum-typed domain properties now preserve an author `usually` default. If no
default is written, generated initializers continue to default to the first enum
case.

Data tables still emit as `Value.list([.record(...)])`, so loops and state reads
use the existing value path. `IRExpression.tableLookup` emits a deterministic
scan over the table list and throws `ToolError.implementation(code:
"table.lookup_miss", ...)` when no row matches the required key.

Interpolated strings can contain conditionals, loops, and formatted holes.
`SwiftEmitter` builds those strings with local string buffers and includes the
private `meridianFormat(_:as:)` helper in the generated header for `integer`,
`decimal(N)`, `short date`, and `long date`.

### Wave 8 trace and monitor codegen

When a workflow carries `runtimeTraceConfiguration` (from `=== trace ===`),
`SwiftEmitter` emits `public static let runtimeTraceConfiguration = …` on the
workflow struct and threads store-failure policy into generated `Runtime` init.

Trace-backed conditions route through `emitTruthValueExpr` (three-valued
`TruthValue` for indeterminate statistical/temporal results) rather than bare
`Bool` comparisons:

| IR shape | Emits |
|---|---|
| `.traceTemporal` | `await runtime.evaluateTemporal(...)` / inlined event-pattern helper |
| `.traceStatistical` | `await runtime.evaluateStatistical(...)` |
| `AssertIR` + `monitored` + `.traceStatistical` | `await runtime.registerMonitor(query:cadence:message:blocking:step:…)` |

Async definition predicates whose bodies contain trace queries emit as
`private func` helpers that take `Runtime` and are awaited at call sites.
`since the last` with a non-event holds must never reach the emitter — lowering
rejects it with **MER-TMP-019**. See [04_RUNTIME.md](04_RUNTIME.md)
and [04_RUNTIME.md](04_RUNTIME.md) §"Semantic traces".
