# Meridian — Documentation Index

Meridian is a controlled natural language compiler. It reads English-shaped
workflow specifications and produces type-safe, async/await Swift source that
runs against a small deterministic runtime.

> **Current status:** Phases 0–6 + the expressive SKILL.md surface (Phase G),
> the Inform-7-tier deterministic surface (Waves 1–3), the inert-reduction
> program (executable Markdown tables/task-lists + AI-routing), the
> world-class diagnostics/tracing/decision-log layer (Phase DX), Wave 5 parser
> infrastructure (grammar table, screening, sentence breaker, problem messages),
> Wave 6 validation/reporting across six corpus families, the Wave 7 canonical
> verbalizer/drift audit surface, and the Wave 8 trace-backed time/statistics
> gate are all complete.
> Generated Swift compiles, links, and runs against `MeridianRuntime`.
> Replay-safe resume, all 13 IR primitives, Blueprint built-ins, full CLI,
> MeridianTestKit, and DocC bundles are shipped. Every error is a stable
> `MERxxxx` code with always-on did-you-mean and a linked design decision. See
> [status.md](status.md) and [14_DEVELOPER_EXPERIENCE.md](14_DEVELOPER_EXPERIENCE.md).

---

## Reading order

| # | Document | Who should read |
|---|----------|-----------------|
| 1 | [01_OVERVIEW.md](01_OVERVIEW.md) | Everyone — one-page pitch + mental model |
| 2 | [02_ARCHITECTURE.md](02_ARCHITECTURE.md) | Newcomers — module map, pipeline diagram |
| 3 | [03_LANGUAGE_QUICK_REFERENCE.md](03_LANGUAGE_QUICK_REFERENCE.md) | Authors writing `.meridian` / `.merconfig` files |
| 4 | [04_COMPILER_PIPELINE.md](04_COMPILER_PIPELINE.md) | Compiler contributors — source → AST → IR → Swift in full detail |
| 5 | [05_CODEGEN.md](05_CODEGEN.md) | Compiler contributors — `SwiftEmitter`, replay guards, `Value` wrapping, special forms |
| 6 | [06_RUNTIME.md](06_RUNTIME.md) | Runtime & tool authors — API surface visible to generated code |
| 7 | [07_CLI.md](07_CLI.md) | Workflow authors & CI — all `meridian` subcommands and flags |
| 8 | [08_TRACING.md](08_TRACING.md) | Debuggers — `ParserTrace` categories, timing, capturing, `--trace` CLI flag |
| 9 | [09_MERIDIAN_TESTS.md](09_MERIDIAN_TESTS.md) | Contributors — `.meridian.test` spec format and `meridian test` runner |
| 10 | [10_BUILTIN_TOOLS.md](10_BUILTIN_TOOLS.md) | Tool authors — Blueprint built-in catalog, registration, arguments |
| 11 | [11_RULEBOOKS.md](11_RULEBOOKS.md) | Authors extending the surface — `.merrules` desugars, section roles, conventions |
| 12 | [12_PROSE_AND_AUTONOMY.md](12_PROSE_AND_AUTONOMY.md) | Authors using plan/autonomy prose modes |
| 13 | [13_SKILL_MD_PORTING.md](13_SKILL_MD_PORTING.md) | Authors porting gbrain `SKILL.md` → `.meri` (playbook + tiers + migrator) |
| 14 | [14_DEVELOPER_EXPERIENCE.md](14_DEVELOPER_EXPERIENCE.md) | **Everyone debugging** — diagnostics, codes, did-you-mean, batch reporting, tracing, `explain-diag`/`decisions`/`--fix` |
| 15 | [15_DECISIONS.md](15_DECISIONS.md) | The readable design-decision log (generated from `DecisionCatalog`) |
| 15b | [15_PROBLEM_MESSAGES.md](15_PROBLEM_MESSAGES.md) | Inform-style problem-message template and active diagnostic-code reference |
| 16 | [16_EXPRESSIVENESS_REPORT.md](16_EXPRESSIVENESS_REPORT.md) | Wave 6 corpus metrics, mechanism coverage, and caveats |
| 17 | [17_MERIDIAN_PATTERNS.md](17_MERIDIAN_PATTERNS.md) | **Anyone about to "fix" a restriction** — recurring architectural patterns and why they're intentional, not gaps |
| 18 | [18_VERBALIZER.md](18_VERBALIZER.md) | Wave 7 canonical English, round-trip law, drift audit, and verbalizer API |
| 19 | [19_TRACES_AND_TIME.md](19_TRACES_AND_TIME.md) | Wave 8 trace schema, temporal/statistical operators, monitors, capture policy, and replay |
| — | [cookbook/README.md](cookbook/README.md) | **Semantics oracle** — normative meaning/surface docs for Waves 7–8 (`MERIDIAN_*.md`) |
| — | [coverage/README.md](coverage/README.md) | **Anyone touching tests** — how & why coverage is measured, the enforced per-file gate, and how to raise it |
| — | [../Tests/README.md](../Tests/README.md) | All contributors — test suites, forcing functions, adding tests |
| — | [status.md](status.md) | Implementers — what's done, what's next, decision references |

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
│   └── SampleDemoFlows/        # Phase 1 hand-written reference workflows
├── Tests/
│   ├── MeridianCoreTests/      # Compiler + Phase 3 forcing function
│   ├── MeridianRuntimeTests/   # Runtime actor and checkpointing
│   ├── MeridianToolsTests/     # Built-in tool behaviour
│   ├── MeridianIntegrationTests/ # Round-trip (compile → build → run) tests
│   └── README.md               # Test suite guide + how to add tests
├── corpora/
│   ├── erp/                    # Wave 6 synthetic ERP/OFBiz proxy corpus
│   ├── procedures/             # Wave 6 synthetic stored-procedure proxy corpus
│   ├── incident/                # synthetic SRE/on-call proxy corpus
│   ├── etl/                     # synthetic data-pipeline/ETL proxy corpus
│   ├── governance/              # synthetic access/security-compliance proxy corpus
│   └── clinical/                # synthetic clinical-safety proxy corpus
├── examples/
│   ├── ecommerce.merconfig     # Vocabulary, phrases, tools, instances, constants
│   ├── order_processing.meridian # Workflows that use the vocabulary
│   └── golden/                 # Expected compiler output (Phase 4 golden diff)
├── AGENTS.md                   # AI contributor handbook (self-updating)
├── IMPLEMENTATION_LOG.md       # Append-only design decision log (recent)
├── .ai/implementation-log-archive/  # Frozen older log snapshots
└── docs/                       # ← you are here
```

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

Wave implementation agent prompts are archived in [`.ai/`](../.ai/)
(`meridian-wave7-verbalizer-prompt.md`, `meridian-wave8-9-trace-deontic-prompt.md`,
`meridian-cursor-master-prompt.md`).

---

## Getting started: key caveats

### Permission enforcement is actor-blind by default

Meridian's `may` rules generate compile-time `Permission` struct entries and
runtime `AssertIR` gates. These evaluate *data predicates* (workflow parameter
values). They do **not** check caller identity out of the box.

If your domain requires role-based or identity-based permission enforcement,
inject a custom `PermissionRegistry` into `Runtime`:

```swift
Runtime(toolRegistry: …, permissionRegistry: myActorAwareRegistry)
```

See [`06_RUNTIME.md`](06_RUNTIME.md) §"Permissions and Policy" for the API and
a wiring example. See [`../README.md`](../README.md) §"Permissions" for a
one-paragraph summary.

This is an intentional design decision: Meridian has no built-in user identity
model. Permission logic that requires identity is a host concern.

### `llm.decide` returns `false` without an LLM host

The built-in `llm.decide` and `llm.judge` tools return `.boolean(false)`
deterministically when no LLM provider is configured. This is intentional for
test safety. To connect a real provider, register your own closure tool under the
same ID:

```swift
toolRegistry.register("llm.decide") { args in
    let question = args["question"]?.stringValue ?? ""
    // call your LLM API...
    return .boolean(answer == "true")
}
```
