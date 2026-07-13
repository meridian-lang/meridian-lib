# Meridian — Architecture

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
│   └── MeridianAST.swift           ← All AST node types (+ LanguageSynonyms)
│
├── Language/
│   ├── EnglishLexicon.swift        ← Author-extensible surface vocabulary
│   │                                  (articles, copulas, comparison/duration/
│   │                                  assertion markers, emptiness, temporal,
│   │                                  aggregates, superlatives, …) + .grammar
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
│   ├── VerbalizerModel.swift       ← Public semantic model from compileToModel
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
[14_DEVELOPER_EXPERIENCE.md](14_DEVELOPER_EXPERIENCE.md) for how these pieces fit
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
        ▼  SwiftEmitter.emitFile(workflows:constantsDecl:instancesDecl:domainDecl:)
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
[08_TRACING.md](08_TRACING.md) and [19_TRACES_AND_TIME.md](19_TRACES_AND_TIME.md).

## External dependencies

| Package | Used for |
|---|---|
| `swift-parsing` | Foundation for `PegexBuilder` |
| `pegex` (local) | `PegexBuilder` grammar DSL |
| `modelhike` (local) | `StringTemplate` used in `SwiftEmitter` |
| `swift-argument-parser` | `meridian` CLI |
| `swift-format` | Auto-format emitted Swift |
| `swift-collections` | Ordered collections in symbol tables |
