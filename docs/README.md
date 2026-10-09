# Meridian — Documentation Index

Meridian is a controlled natural language compiler: English-shaped `.meridian`
workflow files plus a `.merconfig` vocabulary compile deterministically to
readable, type-checked async/await Swift. Nine numbered docs cover it end to
end; start with [01_OVERVIEW.md](01_OVERVIEW.md).

---

## Reading order

| # | Document | Who should read |
|---|----------|-----------------|
| 1 | [01_OVERVIEW.md](01_OVERVIEW.md) | Everyone — one-page pitch, mental model, project status, permanent out-of-scope boundary |
| 2 | [02_ARCHITECTURE.md](02_ARCHITECTURE.md) | Newcomers & compiler contributors — module map, pipeline stages, codegen |
| 3 | [03_LANGUAGE.md](03_LANGUAGE.md) | Authors writing `.meridian` / `.merconfig` files — syntax, patterns, rulebooks, prose modes, deontic norms, modules |
| 4 | [04_RUNTIME.md](04_RUNTIME.md) | Runtime & tool authors — `MeridianRuntime` API, built-in tools, traces/time |
| 5 | [05_CLI.md](05_CLI.md) | Workflow authors & CI — all `meridian` subcommands and flags |
| 6 | [06_DEVELOPER_EXPERIENCE.md](06_DEVELOPER_EXPERIENCE.md) | **Everyone debugging** — diagnostics, codes, did-you-mean, tracing, verbalizer/drift, `explain-diag`/`decisions`/`--fix` |
| 7 | [07_DECISIONS.md](07_DECISIONS.md) | The readable design-decision log (generated from `DecisionCatalog`) |
| 8 | [08_TESTING.md](08_TESTING.md) | Contributors — `.meridian.test` specs, test suites, the three test workflows |
| 9 | [09_SKILL_PORTING.md](09_SKILL_PORTING.md) | Authors porting `SKILL.md` → `.meri`, and anyone generating a new corpus |
| — | [15_PROBLEM_MESSAGES.md](15_PROBLEM_MESSAGES.md) | Inform-style problem-message template and active diagnostic-code reference |
| — | [cookbook/README.md](cookbook/README.md) | **Semantics oracle** — normative meaning/surface docs for Waves 7–9 / Final Wave (`MERIDIAN_*.md`) |
| — | [coverage/README.md](coverage/README.md) | **Anyone touching tests** — how & why coverage is measured, the enforced per-file gate, and how to raise it |
| — | [../Tests/README.md](../Tests/README.md) | All contributors — pointer to the test guide |
| — | [../.ai/implementation-log-archive/docs-history/](../.ai/implementation-log-archive/docs-history/) | Archived wave-history narrative and point-in-time reports (pre-consolidation docs) |

---

## Normative oracle (`docs/cookbook/`)

The Wave 7–8 oracle documents live under [`cookbook/`](cookbook/). They define
normative semantics, canonical surface forms, integration examples, and hazard
review — enforced by `COOK-*`, `SEM_*`, and Composition Gallery tests.

| Oracle doc | Covers |
|---|---|
| `MERIDIAN_SEMANTICS.md` | Typed core, trace model, temporal/statistical/deontic operators |
| `MERIDIAN_SYNTAX_COOKBOOK.md` | Canonical forms, synonyms, ill-formed catalog, composition gallery |
| `MERIDIAN_NORTHSTAR_EXAMPLE.md` | Worked skills, lowering maps, Broken Twin acceptance fixtures |
| `MERIDIAN_DESIGN_RISKS_AND_REVIEW.md` | Amendments, collisions, per-wave exit checklists |
| `INFORM7_DESIGN_NOTES.md` | Inform 7 architecture context mapped onto Meridian |

---

## Key files at a glance

```
meridian/
├── Sources/
│   ├── MeridianRuntime/        # Runtime used by emitted Swift
│   │   ├── Runtime/            # Runtime actor + wait delivery APIs
│   │   ├── Value/              # Value enum + ValueCoercion
│   │   ├── State/              # State struct + StateSnapshot
│   │   ├── Comparison/         # MeridianComparison + NumericConvertible
│   │   ├── Trace/              # TraceRecord, TraceStore, TraceEvaluator (Wave 8)
│   │   └── Protocol/           # MeridianWorkflow, ToolRegistry, Checkpointer
│   ├── MeridianCore/           # Compiler: parser, IR, codegen
│   │   ├── Parser/             # Lexical + grammar + statement + expression parsers
│   │   │                       #   Lexical/Productions/ — one file per expression
│   │   │                       #   grammar production (pegex or hand-written)
│   │   ├── AST/                # AST node types (post-parse, pre-IR)
│   │   ├── Symbols/            # SymbolTable + phrase matching
│   │   ├── Lowering/           # AST → IR (ASTToIR.swift)
│   │   ├── IR/                 # IRTypes.swift — 13 IR primitives
│   │   ├── Codegen/            # SwiftEmitter.swift + ManifestEmitter.swift
│   │   ├── Formatter/          # MeridianFormatter.swift
│   │   ├── Verbalizer/         # Verbalizer, DriftEngine, VerbalizerModel
│   │   ├── Docs/               # MerconfigDocsRenderer.swift
│   │   ├── Testing/            # MeridianTestRunner + SpecParser + Assertions
│   │   ├── Grammar/            # Wave 5 GrammarTable (per-production registry),
│   │   │                       #   NonterminalScreen, parser benchmark
│   │   ├── Diagnostics/        # Diagnostic, DiagnosticEngine/Renderer, Suggester,
│   │   │                       #   DiagnosticCode catalog, DecisionCatalog, ParserTrace
│   │   └── Compiler.swift      # Top-level compile() entry point
│   ├── MeridianCLI/            # thin meridian @main executable
│   ├── MeridianCLIKit/         # ArgumentParser command implementations:
│   │                           #   compile, check, verify, run, resume, format,
│   │                           #   docs, test, lint, trace, explain,
│   │                           #   explain-diag, drift, grammar-doc, decisions,
│   │                           #   preview-skill, migrate-skill, skill-deviation
│   ├── MeridianTools/          # Blueprint built-in tool implementations
│   ├── MeridianTestKit/        # Test helpers: WorkflowTestHarness, MockRuntime, etc.
│   └── SampleDemoFlows/        # Hand-written reference workflows (Phase 1)
├── Tests/
│   ├── MeridianCoreTests/      # Compiler + Phase 3 forcing function
│   ├── MeridianRuntimeTests/   # Runtime actor and checkpointing
│   ├── MeridianToolsTests/     # Built-in tool behaviour
│   ├── MeridianIntegrationTests/ # Round-trip (compile → build → run) tests
│   └── README.md               # Test suite guide (pointer)
├── corpora/
│   ├── erp/                    # Wave 6 synthetic ERP/OFBiz proxy corpus
│   ├── procedures/             # Wave 6 synthetic stored-procedure proxy corpus
│   ├── incident/               # synthetic SRE/on-call proxy corpus
│   ├── etl/                    # synthetic data-pipeline/ETL proxy corpus
│   ├── governance/             # synthetic access/security-compliance proxy corpus
│   └── clinical/               # synthetic clinical-safety proxy corpus
├── examples/
│   ├── ecommerce.merconfig     # Vocabulary, phrases, tools, instances, constants
│   ├── order_processing.meridian # Workflows that use the vocabulary
│   └── golden/                 # Expected compiler output (Phase 4 golden diff)
├── AGENTS.md                   # AI contributor handbook (self-updating)
├── IMPLEMENTATION_LOG.md       # Append-only design decision log (recent)
├── .ai/implementation-log-archive/  # Frozen older log snapshots
└── docs/                       # ← you are here
```
