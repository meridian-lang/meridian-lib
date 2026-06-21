# Meridian — Architecture

## Module map

```
┌─────────────────────────────────────────────────────────────┐
│                     meridian (CLI)                          │
│  Sources/MeridianCLI/CLI.swift (thin @main)                  │
│  Sources/MeridianCLIKit/Commands/                           │
│  compile · check · verify · run · resume · format · docs ·  │
│  test · lint · trace · explain · decisions · preview-skill ·│
│  migrate-skill · skill-deviation                            │
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
│  Diagnostics │ │  ProcessOrder.swift              │
│  Docs/       │ │  imports MeridianRuntime         │
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
│   │   ├── MerConfigParser.swift    ← Parses .merconfig files
│   │   ├── MeridianParser.swift     ← Parses .meridian files
│   │   ├── StatementParser.swift    ← Parses statements; expands table/checklist
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
│   └── ASTToIR.swift               ← AST → IR primitives + phrase inlining
│
├── Rulebook/
│   ├── Rulebook.swift              ← 4 families: desugar / sections / conventions
│   │                                  / triggers; builtin section + trigger seeds
│   ├── RulebookParser.swift        ← Parses .merrules (=== name === sections)
│   └── RewriteEngine.swift         ← Applies desugar rewrites (bounded fixpoint)
│
├── IR/
│   └── IRTypes.swift               ← IRWorkflow, IRPrimitive (12 cases: 11
│                                      deterministic primitives + proseStep for the
│                                      discretion/autonomy prose path), IRExpression
│
├── Codegen/
│   ├── SwiftEmitter.swift          ← IR → Swift source (StringTemplate)
│   │                                  Replay-safe resume guards generated here
│   ├── DomainEmitter.swift         ← Vocabulary → typealiases / protocol+struct
│   │                                  pairs (Meridian<Base> hierarchy)
│   └── ManifestEmitter.swift       ← IR → JSON manifest + source-map entries
│
├── Formatter/
│   └── MeridianFormatter.swift     ← Conservative whitespace-only formatter
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
together (codes, did-you-mean, batch reporting, tracing, `explain`/`decisions`/
`--fix`).

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
        ├──► ManifestEmitter → {stem}.meridian.manifest.json
        │
        ▼  SwiftEmitter.emitFile(workflows:constantsDecl:instancesDecl:domainDecl:)
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
| `IRPrimitive` | `IR/IRTypes` | One of 12 lowered statement kinds |
| `IRWorkflow` | `IR/IRTypes` | Struct name, parameters, body block, execution mode |
| `StringTemplate` | `modelhike` | Result-builder code builder used by `SwiftEmitter` |
| `Diagnostic` | `Diagnostics/` | Coded error/warning: code + range + suggestions/notes/help + decision |
| `DiagnosticCode` | `Diagnostics/` | Stable `MERxxxx` identity + kind + linked `DecisionRef` |
| `DiagnosticEngine` | `Diagnostics/` | Per-file collector; batch-reports many errors with coarse recovery |

## External dependencies

| Package | Used for |
|---|---|
| `swift-parsing` | Foundation for `PegexBuilder` |
| `pegex` (local) | `PegexBuilder` grammar DSL |
| `modelhike` (local) | `StringTemplate` used in `SwiftEmitter` |
| `swift-argument-parser` | `meridian` CLI |
| `swift-format` | Auto-format emitted Swift |
| `swift-collections` | Ordered collections in symbol tables |
