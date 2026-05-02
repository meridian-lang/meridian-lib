# Meridian — Architecture

## Module map

```
┌─────────────────────────────────────────────────────────────┐
│                     meridian (CLI)                          │
│  Sources/MeridianCLI/Commands/                              │
│  compile · check · verify · run · resume · format ·         │
│  docs · test · trace                                        │
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
│   │   ├── IndentTokenizer.swift    ← Converts raw source to SourceLine[]
│   │   └── ExpressionParser.swift  ← Parses single-line expressions
│   └── Productions/
│       ├── MerConfigParser.swift    ← Parses .merconfig files
│       ├── MeridianParser.swift     ← Parses .meridian files
│       ├── StatementParser.swift    ← Parses individual statements
│       └── PhrasePatternParser.swift ← Parses "To {verb} a {kind}:" headers
│
├── AST/
│   └── MeridianAST.swift           ← All AST node types
│
├── Symbols/
│   └── SymbolTable.swift           ← Phrase matching + arg extraction
│
├── Lowering/
│   └── ASTToIR.swift               ← AST → IR primitives + phrase inlining
│
├── IR/
│   └── IRTypes.swift               ← IRWorkflow, IRPrimitive (11 cases), IRExpression
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
    └── ParserTrace.swift           ← Category-scoped trace sink
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
| `IRPrimitive` | `IR/IRTypes` | One of 11 lowered statement kinds |
| `IRWorkflow` | `IR/IRTypes` | Struct name, parameters, body block, execution mode |
| `StringTemplate` | `modelhike` | Result-builder code builder used by `SwiftEmitter` |

## External dependencies

| Package | Used for |
|---|---|
| `swift-parsing` | Foundation for `PegexBuilder` |
| `pegex` (local) | `PegexBuilder` grammar DSL |
| `modelhike` (local) | `StringTemplate` used in `SwiftEmitter` |
| `swift-argument-parser` | `meridian` CLI |
| `swift-format` | Auto-format emitted Swift |
| `swift-collections` | Ordered collections in symbol tables |
