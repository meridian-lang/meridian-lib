# Meridian — Documentation Index

Meridian is a controlled natural language compiler. It reads English-shaped
workflow specifications and produces type-safe, async/await Swift source that
runs against a small deterministic runtime.

> **Current status:** Phases 0–6 + the expressive SKILL.md surface (Phase G),
> the Inform-7-tier deterministic surface (Waves 1–3), the inert-reduction
> program (executable Markdown tables/task-lists + AI-routing), and the
> world-class diagnostics/tracing/decision-log layer (Phase DX) are all complete.
> Generated Swift compiles, links, and runs against `MeridianRuntime`.
> Replay-safe resume, all 12 IR primitives, Blueprint built-ins, full CLI,
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
| 14 | [14_DEVELOPER_EXPERIENCE.md](14_DEVELOPER_EXPERIENCE.md) | **Everyone debugging** — diagnostics, codes, did-you-mean, batch reporting, tracing, `explain`/`decisions`/`--fix` |
| 15 | [15_DECISIONS.md](15_DECISIONS.md) | The readable design-decision log (generated from `DecisionCatalog`) |
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
│   │   └── Protocol/           # MeridianWorkflow, ToolRegistry, Checkpointer
│   ├── MeridianCore/           # Compiler: parser, IR, codegen
│   │   ├── Parser/             # Lexical + grammar + statement + expression parsers
│   │   ├── AST/                # AST node types (post-parse, pre-IR)
│   │   ├── Symbols/            # SymbolTable + phrase matching
│   │   ├── Lowering/           # AST → IR (ASTToIR.swift)
│   │   ├── IR/                 # IRTypes.swift — 12 IR primitives
│   │   ├── Codegen/            # SwiftEmitter.swift + ManifestEmitter.swift
│   │   ├── Formatter/          # MeridianFormatter.swift
│   │   ├── Docs/               # MerconfigDocsRenderer.swift
│   │   ├── Testing/            # MeridianTestRunner + SpecParser + Assertions
│   │   ├── Diagnostics/        # Diagnostic, DiagnosticEngine/Renderer, Suggester,
│   │   │                       #   DiagnosticCode catalog, DecisionCatalog, ParserTrace
│   │   └── Compiler.swift      # Top-level compile() entry point
│   ├── MeridianCLI/            # thin meridian @main executable
│   ├── MeridianCLIKit/         # ArgumentParser command implementations:
│   │                           #   compile, check, verify, run, resume, format,
│   │                           #   docs, test, lint, trace, explain, decisions,
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
├── examples/
│   ├── ecommerce.merconfig     # Vocabulary, phrases, tools, instances, constants
│   ├── order_processing.meridian # Workflows that use the vocabulary
│   └── golden/                 # Expected compiler output (Phase 4 golden diff)
├── AGENTS.md                   # AI contributor handbook (self-updating)
├── IMPLEMENTATION_LOG.md       # Append-only design decision log
└── docs/                       # ← you are here
```

---

## Original spec docs

The handoff package (`meridian-handoff/docs/`) contains the locked specification
documents. These are read-only reference — do not modify them.

| Spec doc | Covers |
|---|---|
| `00_BLUEPRINT.md` | Master architecture |
| `02_LANGUAGE_REFERENCE.md` | Full grammar formal spec |
| `04_IR_SPEC.md` | IR primitive formal spec |
| `05_CODEGEN_SPEC.md` | Codegen target spec |
| `07_RUNTIME_API.md` | Runtime API contract |
| `10_BUILD_PLAN.md` | Six-phase build plan |
| `11_DECISIONS.md` | Locked design decisions |

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
