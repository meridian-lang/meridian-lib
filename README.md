# Meridian

A **controlled natural language compiler** for agent workflows and business rules.
Meridian reads English-shaped specifications and compiles them to readable,
type-checked, async/await Swift plus a small deterministic runtime.

**Current status: All phases (0–6, 6.5, 8, G) complete. 530+ tests passing. Generated Swift compiles, links, and runs.**

---

## What it does

```
# examples/order_processing.meridian

To process an order placed by a customer:
  validate the order.
  check the credit of the customer for the order's total amount.
  if the order's total amount is more than the high value threshold,
    request approval for the order from the customer's account manager.
    if the approval's verdict is denied,
      reject the order with reason "approval_denied".
  charge payment for the customer for the order's total amount via the stripe.
  complete.
```

```bash
meridian compile examples/order_processing.meridian -o build/
# → build/order_processing.swift              (compilable Swift)
# → build/order_processing.meridian.manifest.json  (companion manifest)
```

```swift
// Generated:
public struct ProcessOrder: MeridianWorkflow {
    public let runtime: Runtime
    public let order: Order
    public let customer: Customer
    public func run() async throws -> WorkflowResult { … }
}
```

---

## Quick start

```bash
# Build the compiler
swift build

# Compile the example workflow
swift run meridian compile examples/order_processing.meridian \
    --merconfig examples/ecommerce.merconfig \
    -o build/

# Run it directly (no manual build step)
swift run meridian run examples/order_processing.meridian \
    --merconfig examples/ecommerce.merconfig \
    --workflow ProcessOrder \
    --input-json 'order={"id":"o-001"}' \
    --input-json 'customer={"id":"c-001"}'

# Run all test specs
swift run meridian test Tests/MeridianCoreTests/MeridianTestSpecs

# Port a gbrain SKILL.md to a strict-compiling .meri (deterministic marking)
swift run meridian migrate-skill path/to/SKILL.md --out skill.meri

# Audit how a port deviates from its original (single pair, or --batch a corpus)
swift run meridian skill-deviation original-skills/ . \
    --batch --out migration-deviations/ --index
```

---

## Documentation

| Doc | Description |
|---|---|
| [docs/01_OVERVIEW.md](docs/01_OVERVIEW.md) | One-page pitch, mental model, three-layer diagram |
| [docs/02_ARCHITECTURE.md](docs/02_ARCHITECTURE.md) | Module map, pipeline diagram, key types |
| [docs/03_LANGUAGE_QUICK_REFERENCE.md](docs/03_LANGUAGE_QUICK_REFERENCE.md) | `.meridian` + `.merconfig` syntax at a glance |
| [docs/04_COMPILER_PIPELINE.md](docs/04_COMPILER_PIPELINE.md) | Source → AST → IR → Swift in detail |
| [docs/05_CODEGEN.md](docs/05_CODEGEN.md) | `SwiftEmitter`, replay guards, `Value` wrapping |
| [docs/06_RUNTIME.md](docs/06_RUNTIME.md) | `MeridianRuntime` API — wait delivery, resume, checkpointing |
| [docs/07_CLI.md](docs/07_CLI.md) | All `meridian` subcommands and flags |
| [docs/08_TRACING.md](docs/08_TRACING.md) | `ParserTrace` categories, capturing API, `--trace` |
| [docs/09_MERIDIAN_TESTS.md](docs/09_MERIDIAN_TESTS.md) | `.meridian.test` spec format and `meridian test` runner |
| [docs/10_BUILTIN_TOOLS.md](docs/10_BUILTIN_TOOLS.md) | Blueprint built-in tool catalog, arguments, registration |
| [docs/11_RULEBOOKS.md](docs/11_RULEBOOKS.md) | `.merrules` desugars, section roles, conventions |
| [docs/13_SKILL_MD_PORTING.md](docs/13_SKILL_MD_PORTING.md) | Porting gbrain `SKILL.md` → `.meri` (playbook, tiers, migrator) |
| [docs/14_DEVELOPER_EXPERIENCE.md](docs/14_DEVELOPER_EXPERIENCE.md) | **Debugging** — diagnostics, `MERxxxx` codes, did-you-mean, batch reporting, tracing, `explain`/`decisions`/`--fix` |
| [docs/15_DECISIONS.md](docs/15_DECISIONS.md) | The readable design-decision log (generated from `DecisionCatalog`) |
| [Tests/README.md](Tests/README.md) | Test suites, forcing functions, adding new tests |
| [docs/status.md](docs/status.md) | Phase progress, what's done, decision references |

Original spec docs (read-only reference): [`meridian-handoff/docs/`](meridian-handoff/docs/)

---

## Source layout

```
Sources/
├── MeridianRuntime/          # Runtime library (generated code imports this)
├── MeridianCore/             # Compiler: parser, AST, IR, codegen, formatter, docs, testing
├── MeridianCLI/              # thin @main executable
├── MeridianCLIKit/           # command implementations (compile, run, check, test, format, docs, trace, migrate-skill, skill-deviation…)
├── MeridianTools/            # Blueprint built-in tool implementations
├── MeridianTestKit/          # Test helpers: WorkflowTestHarness, MockRuntime, etc.
└── SampleDemoFlows/          # Hand-written reference workflows (Phase 1)

Tests/
├── MeridianCoreTests/        # Compiler + Phase 3 forcing function
├── MeridianRuntimeTests/     # Runtime actor + checkpointing
├── MeridianToolsTests/       # Built-in tool behavior
├── MeridianIntegrationTests/ # Round-trip (compile → build → run) tests
└── README.md                 # Test suite guide

examples/
├── ecommerce.merconfig       # Vocabulary, constants, instances, tools
├── order_processing.meridian # Workflows
└── golden/                   # Expected compiler output (Phase 4 golden diff)

sample-gbrain/                # Ported gbrain corpus (Phase G) — see its README
├── README.md                 # Corpus guide: layout, artifacts, building, tests
├── brain.merconfig           # Shared brain-domain vocabulary
├── brain.merrules            # Desugars + section aliases + conventions
├── RESOLVER.meri             # Trigger → skill dispatcher
├── skills/*.meri             # 52 ported gbrain skills
├── original-skills/          # Verbatim upstream gbrain tree (reference)
├── migration-deviations/     # Per-skill diff vs. original SKILL.md (+ index)
├── compile-outputs/          # Generated Swift for every skill (namespaced)
└── Tests/                    # SampleGbrainTests SPM target (lives with the corpus)

docs/                         # This documentation set
AGENTS.md                     # AI contributor handbook (self-updating)
IMPLEMENTATION_LOG.md         # Append-only decision log
```

---

## Key features

- **Controlled natural language** — spec-level intent, not prompt engineering.
- **SKILL.md-shaped surface** — frontmatter parameters, markdown headings/lists,
  topic labels, implicit entry workflows, `every`/`each`, `only when`/`unless`,
  idiom/anaphora sugar, and `if you decide that …` compile to deterministic IR.
- **Typed prose modes** — `with discretion` asks a `Planner` for a bounded plan;
  `with autonomy` asks an `ActPlanner` one step at a time. Runtime validation,
  host policy, and scoped tool execution remain deterministic.
- **Deterministic compilation** — same source always produces the same Swift.
- **12 IR primitives** — invoke, bind, rebind, branch, emit, complete, iterate, assert, wait, commit, recover, simultaneously, proseStep.
- **Phrase inlining** — vocabulary phrases expand at compile time.
- **Workflow recursion** — workflows can call themselves or other workflows.
- **Typed domain** — kinds become typed Swift `struct`s; generated inits are fully typed.
- **Replay-safe resume** — generated code automatically restores state from checkpoints
  and skips already-executed side effects using stable progress labels.
- **Blueprint built-ins** — `registerBuiltins()` provides HTTP, file, JSON, regex, shell,
  MCP, validation, time, UUID tools out of the box.
- **`ParserTrace`** — opt-in category-scoped diagnostic tracing for debugging the compiler.
- **`MeridianTestKit`** — `WorkflowTestHarness`, `MockRuntime`, `RecordingTool`, `GoldenFile` for integration tests.
- **`.meridian.test` specs** — declarative compile/run test files; `meridian test` runs them.
- **Rulebooks (`.merrules`)** — extend the deterministic English surface with
  external, declarative desugar idioms, section-role aliases, and Inform-style
  conventions — no compiler edit. See [docs/11_RULEBOOKS.md](docs/11_RULEBOOKS.md).
- **gbrain SKILL.md surface** — any file with `##`/`###` headings maps Markdown
  sections to deterministic roles (Contract→assert, Phases→procedure,
  When-To-Use→applicability) — no `skill: true` flag. A trailing
  `(( inert ))` / `(( inert, role: R ))` / `(( role: R ))` marker is
  authoritative for documentation. Fenced `bash` blocks → `shell.run`,
  `use judgment to …:` markers → prose steps, `triggers:` → dispatch,
  choice-gates, and background spawn. Every section is recorded into
  `meridian_skill.sections`; fuzzy conditions, unmarked narrative headings, and
  pre-heading content are hard errors (no silent drops).
- **`meridian migrate-skill`** — convert a `SKILL.md` to a strict-compiling
  `.meri`. Runs a deterministic marking pass (blockquote pre-heading preamble;
  append `(( inert, role: invariants/prohibitions ))` to prose
  Contract/Anti-Patterns, `(( role: procedure ))` to pure-shell unknown
  headings, `(( inert ))` to other unknowns; recognized roles left unmarked),
  then strict-compiles; optional bounded LLM-assisted repair, always
  compiler-gated. See [docs/13_SKILL_MD_PORTING.md](docs/13_SKILL_MD_PORTING.md).
- **`meridian skill-deviation`** — audit how a ported `.meri` deviates from its
  original `SKILL.md`: frontmatter delta, tier, similarity, structural
  categories, and a unified diff. The diff engine is a faithful Swift port of
  Python's `difflib`, so reports are byte-for-byte reproducible. `--batch
  --index` regenerates the whole `sample-gbrain/migration-deviations/` audit.
- **gbrain corpus** — `sample-gbrain/` ships a shared brain vocabulary, a
  rulebook, and 52 ported skills + a resolver, all compiling strict. It also
  carries the verbatim upstream skills, a per-skill migration-deviation audit,
  and the generated Swift for every skill. All 53 emitted files type-check
  against `MeridianRuntime`. See [sample-gbrain/README.md](sample-gbrain/README.md).
- **Namespaced codegen** — `meridian compile` defaults to wrapping each file's
  output in `public enum <SkillName> { … }` (`--namespace auto`) so many
  generated files share one Swift module without colliding; `--namespace none`
  restores flat output. `compile` also takes repeatable `--rulebook`.

---

## Phase status

| Phase | Name | Status |
|---|---|---|
| 0 | Scaffolding + Runtime | ✅ Done |
| 1 | Hand-written reference flows | ✅ Done |
| 2 | Parser + AST | ✅ Done |
| 3 | IR + Codegen | ✅ Done |
| 4 | Typed domain codegen + golden diffs | ✅ Done |
| 5 | Hard IR primitives + checkpointing | ✅ Done |
| 6 | Built-in tools + full CLI + TestKit + DocC | ✅ Done |
| 6.5 | EnglishLexicon + SKILL-shaped extensions | ✅ Done |
| 8 | Executable rules | ✅ Done |
| G | Expressive SKILL.md surface + gbrain corpus | ✅ Done |

Full detail: [`docs/status.md`](docs/status.md)
Implementation decisions: [`IMPLEMENTATION_LOG.md`](IMPLEMENTATION_LOG.md)

---

## AI contributor guide

See [`AGENTS.md`](AGENTS.md) for the self-updating AI contributor handbook.

---

## ⚠️  Permissions: default is actor-blind

Meridian's `may` rules produce `AssertIR` gates and `Permission` struct entries
at compile time. At runtime the `PermissionRegistry` evaluates these as *data
predicates* — checking workflow parameters like `customer.status` or
`order.totalAmount`. **It does not check the identity of the caller** unless you
wire actor context in explicitly.

**What this means:**
- Data-driven caps (e.g. `may approve any order up to $10000`) are enforced
  against the order's `totalAmount` value.
- Role-based checks (e.g. "only account managers may approve") require the host
  to populate `scope.actor` via a custom `PermissionRegistry`.

**To enable actor-aware permissions:**
```swift
let registry = PermissionRegistry()
await registry.register(Permission(
    subjectKind: "order",
    actionDisplayName: "approve orders",
    description: "account manager may approve orders up to $10000",
    isBounded: true,
    predicate: { scope in
        guard let actor = scope.actor,
              let role = actor["role"]?.stringValue else { return false }
        let amount = scope.parameters["order"]?["totalAmount"]?.decimalValue ?? 0
        return role == "account_manager" && amount <= 10_000
    }
))
let runtime = Runtime(toolRegistry: registry, permissionRegistry: registry)
```

See [`docs/06_RUNTIME.md`](docs/06_RUNTIME.md) §"Permissions and Policy" for details.

---

## ⚠️  No silent fallbacks: every resolution failure is a hard error

Meridian compiles **strictly by default**. If something can't be resolved at
compile time, the compiler raises a coded, sourced `Diagnostic` (with a source
caret and a `did you mean`/`help` hint) instead of silently emitting a
placeholder:

| Failure | What used to happen (V1) | What happens now |
|---|---|---|
| Phrase doesn't match any phrase or workflow | `_unresolved` BindIR placeholder | MER2001 error with did-you-mean |
| Unknown tool id | invoke that failed only at runtime | MER2002 error with did-you-mean |
| Rule that the analyser can't classify | dropped silently | MER1004 error |
| Rule whose action verb matches no workflow | dropped silently | MER3006 error |
| `When …, do X` trigger whose action doesn't lower | stub comment | MER3007 error |
| Malformed header / unknown config key / rulebook section | dropped silently | MER1001 / MER1007 / MER5003 error |
| `swift-format` failure | swallowed | MER5001 **warning** (valid output kept) |

The full diagnostics, tracing, and decision-log surface is documented in
[docs/14_DEVELOPER_EXPERIENCE.md](docs/14_DEVELOPER_EXPERIENCE.md). Every
compile error is queryable: `meridian explain MER2002`.

**Opting back into a fallback is per-file**, via the `.meridian` frontmatter
key `allow-fallbacks:` (comma-separated list, or `all`/`*` for everything):

```
---
name: experimental
allow-fallbacks: unresolved-phrases, unattached-rules
---
```

The kinds:
- `unresolved-phrases` — emit `_unresolved` BindIR for unknown phrase
  invocations.
- `unknown-tools` — emit an unrecognized tool id as-is (for host-provided tools
  registered only at runtime).
- `unparseable-rules` — drop rules the analyser can't classify (still in
  manifest).
- `unattached-rules` — drop rules whose action doesn't match any workflow
  (still in manifest).
- `unresolved-trigger-actions` — keep the `trigger.X.fired` fan-out event
  even when the action workflow doesn't exist.

The host-level escape hatch `Compiler.Options.fallbackPolicy = .lenient`
applies the same opt-in process-wide; the frontmatter list is OR-merged
with this option, so both have to be off for the strict default.
