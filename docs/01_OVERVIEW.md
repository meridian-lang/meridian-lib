# Meridian — Overview

Meridian is a **controlled natural language compiler**: English-shaped
`.meridian` workflow files plus a `.merconfig` vocabulary compile
deterministically to readable, type-checked async/await Swift that runs against
`MeridianRuntime`. This is the orientation doc — what Meridian is, what it is
not, how to run it, and its permanent scope boundary.

---

## What it is

Meridian is a **controlled natural language compiler**. You write business
workflows in English-shaped prose. Meridian compiles them to readable,
type-checked, async/await Swift — plus a small deterministic runtime.

```
# order_processing.meridian

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

Compiles to:

```swift
public struct ProcessOrder: MeridianWorkflow {
    public let runtime: Runtime
    public let order: Order
    public let customer: Customer

    public func run() async throws -> WorkflowResult {
        var state = State()
        // ... validate, credit-check, approval flow, charge ...
        await runtime.complete(reason: nil)
        return WorkflowResult(reason: nil, durationMS: await runtime.elapsedMS(), …)
    }
}
```

## Two-sentence pitch

> Meridian is a controlled natural language for agent workflows and business
> rules. It compiles deterministically to readable Swift source plus a small
> runtime, giving you spec-level intent at the surface and predictable,
> debuggable code at the bottom.

## Three layers

```
┌──────────────────────────────────────┐
│  .meridian source                    │
│  English-shaped prose                │
│  Domain experts read and write here  │
└──────────────────┬───────────────────┘
                   │  parsed + phrase-inlined
                   ▼
┌──────────────────────────────────────┐
│  .merconfig vocabulary               │
│  "To validate an order:"            │
│  Phrase library, tools, types        │
└──────────────────┬───────────────────┘
                   │  lowered to IR
                   ▼
┌──────────────────────────────────────┐
│  13 IR primitives                    │
│  invoke / bind / branch / emit /     │
│  wait / iterate / assert / commit /  │
│  recover / complete / simultaneously │
│  aiJudgment / aiAutonomy             │
└──────────────────┬───────────────────┘
                   │  emitted as Swift
                   ▼
┌──────────────────────────────────────┐
│  Generated Swift + MeridianRuntime   │
│  Boring straight-line code           │
│  Source line comments preserved      │
│  Async/await structured concurrency  │
│  Replay-safe resume built in         │
└──────────────────────────────────────┘
```

## What Meridian is NOT

- Not a platform or cloud service.
- Not an LLM or AI engine.
- Not a graph execution framework.
- Not a hosted runtime.
- Not an agent framework.

It is a **compiler**. The control flow is yours. The tool outputs may be
non-deterministic. The *compilation* is deterministic.

Wave 7 also makes the compiled meaning explainable in the other direction:
`meridian explain` prints the lowered IR back as Canonical English, and
`meridian drift` compares authored source with that canonical form. See
[06_DEVELOPER_EXPERIENCE.md](06_DEVELOPER_EXPERIENCE.md).

Wave 8 extends that audit path into runtime history: temporal/statistical
conditions compile to semantic trace queries, and the CLI can replay or verify
those traces via `meridian trace eval`, `meridian trace verify`, and
`meridian bench-trace`. See [04_RUNTIME.md](04_RUNTIME.md).

## What it replaces

| Before Meridian | With Meridian |
|---|---|
| SKILL.md files understood only by LLMs | Structured prose that compiles to auditable code |
| Hand-written LangGraph boilerplate | Generated Swift with observable events |
| Business rule documents disconnected from runtime | Single source of truth: `.meridian` → compiled Swift |
| Ad hoc agent harnesses | Typed `MeridianWorkflow` protocol + runtime |

## Files you write

| Extension | Purpose |
|---|---|
| `.merconfig` | Vocabulary: kinds, properties, phrases, tools, constants, instances |
| `.meridian` | Workflows: `To {pattern}: … complete.` |

## Files Meridian produces

| Output | Description |
|---|---|
| `{stem}.swift` | Generated workflow Swift source — domain types, constants, instances, workflow struct(s) |
| `{stem}.meridian.manifest.json` | Companion manifest: parameters, events, tool IDs, source-map entries |

## Key language features

- **Phrase library** — vocabulary in `.merconfig` defines reusable phrases. Workflow
  bodies call them in prose; the compiler inlines them at IR level.
- **Typed domain** — vocabulary kinds become typed Swift `struct`s with `Codable`
  conformance. Generated workflow inits are fully typed: `ProcessOrder(runtime:order:customer:)`.
- **All IR primitives** — invoke, bind/rebind, branch, emit, wait (duration/signal/
  approval/event/choice), iterate, assert, commit, recover, complete,
  `simultaneously`, and `aiJudgment`/`aiAutonomy` (discretion vs. autonomy prose).
- **Replay-safe resume** — generated code automatically consumes a prepared resume
  context, restores state from the latest checkpoint, and skips already-executed
  side effects with stable progress labels.
- **Blueprint built-ins** — `MeridianTools.registerBuiltins()` adds HTTP, file, JSON,
  regex, shell, MCP, schema validation, time, and UUID tools out of the box.
- **Executable Markdown surface** — SKILL.md-shaped docs are first-class: `##`
  headings carry section roles, Markdown tables compile to branches / data
  records, and task lists to invariant asserts. Fuzzy tables/checklists route to
  the planner via `(( ai-discretion ))` / `(( ai-autonomy ))` instead of being
  inert documentation.
- **Plan & autonomy prose** — `with discretion` / `with autonomy` (and the AI
  Markdown markers) lower to a typed planner boundary, so judgment-bearing steps
  are interwoven with deterministic IR rather than hand-waved.
- **World-class diagnostics** — every error is a stable, documented `MERxxxx`
  code with a source snippet + caret. Name-resolution errors **always** carry a
  `did you mean "X"?` suggestion (or a candidate list); there are no silent
  fallbacks (strict-by-default, opt out per-file with `allow-fallbacks:`).
  Errors are batch-reported, link to the design decision that governs them, and
  are queryable via `meridian explain-diag <code>` / `meridian decisions`. `--fix`
  applies the unambiguous suggestions; `--diagnostics-format json` feeds editors
  and CI. See [06_DEVELOPER_EXPERIENCE.md](06_DEVELOPER_EXPERIENCE.md).
- **Gap-free tracing** — `ParserTrace` exposes category-scoped, timed spans over
  every compile phase (tokenize → parse → lower → codegen), a compile profile,
  and diagnostics mirrored into the stream. Enable with `--trace <categories>`.
  See [06_DEVELOPER_EXPERIENCE.md](06_DEVELOPER_EXPERIENCE.md).
- **Canonical English verbalizer** — every `Compiler.compile(_:)` result carries
  a `VerbalizerModel` (`CompiledFile.model`); `Verbalizer` renders Canonical English that must compile
  back to structurally equal IR (`SEM-8-03`). `DriftEngine` classifies authored
  vs. canonical differences for corpus audits. See
  [06_DEVELOPER_EXPERIENCE.md](06_DEVELOPER_EXPERIENCE.md).
- **Trace-backed time and statistics** — retained semantic traces power
  `has ever`, `within the last`, `in a row`, `since the last`, and percentage
  frequency claims. The same trace layer supports replay evaluation, chain
  verification, and benchmarked store behavior. See
  [04_RUNTIME.md](04_RUNTIME.md).

## End-to-end flow

```
.merconfig  ──► MerConfigParser ──► SymbolTable ──┐
                                                  │
.meridian   ──► MeridianParser ──► MeridianFile ──┤
                                                  ▼
                            ASTToIR ──► [IRWorkflow]
                                │                 │
                                │                 ├──► Verbalizer ──► Canonical English
                                ▼                 │
                         SwiftEmitter ──► Swift source
                                                  │
                      swift-format (optional) ──► formatted Swift
                                                  │
                           Written to  {stem}.swift + {stem}.meridian.manifest.json
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

## Source layout

```
Sources/
├── MeridianRuntime/          # Runtime library (generated code imports this)
├── MeridianCore/             # Compiler: parser, AST, IR, codegen, verbalizer, formatter, docs, testing
├── MeridianCLI/              # thin @main executable
├── MeridianCLIKit/           # command implementations (compile, run, check, test, format, docs, trace, explain, drift, grammar-doc, migrate-skill, skill-deviation...)
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
IMPLEMENTATION_LOG.md         # Append-only decision log (recent entries)
.ai/implementation-log-archive/  # Frozen older log snapshots
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
- **Canonical English verbalizer** — `meridian explain` prints the compiled IR
  back as Canonical English; `meridian drift` compares authored source against
  that canonical form. See [docs/06_DEVELOPER_EXPERIENCE.md](docs/06_DEVELOPER_EXPERIENCE.md).
- **13 IR primitives** — invoke, bind, rebind, branch, emit, complete, iterate, assert, wait, commit, recover, simultaneously, aiJudgment, aiAutonomy.
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
  conventions — no compiler edit. See [docs/03_LANGUAGE.md](docs/03_LANGUAGE.md).
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
  route documentary sections to `(( role: reference ))`, recognized procedure
  headings unmarked, normative-but-unlowerable lines left unmarked for precise
  compiler errors, inference-cue lines to judgment markers — the migrator never
  emits `(( inert ))`), then strict-compiles; optional bounded LLM-assisted
  repair, always compiler-gated. See [docs/09_SKILL_PORTING.md](docs/09_SKILL_PORTING.md).
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

## Project status

> **Current status:** Phases 0–6 + the expressive SKILL.md surface (Phase G),
> the Inform-7-tier deterministic surface (Waves 1–3), the inert-reduction
> program (executable Markdown tables/task-lists + AI-routing), the
> world-class diagnostics/tracing/decision-log layer (Phase DX), Wave 5 parser
> infrastructure (grammar table, screening, sentence breaker, problem messages),
> Wave 6 validation/reporting across six corpus families, the Wave 7 canonical
> verbalizer/drift audit surface, and the Wave 8 trace-backed time/statistics
> gate are all complete. **Wave 9 / Final Wave (deontic norms, modules, and
> closure) is complete** — see
> [03_LANGUAGE.md](03_LANGUAGE.md). Generated Swift
> compiles, links, and runs against
> `MeridianRuntime`.
> Replay-safe resume, all 13 IR primitives, Blueprint built-ins, full CLI,
> MeridianTestKit, and DocC bundles are shipped. Every error is a stable
> `MERxxxx` code with always-on did-you-mean and a linked design decision. See
> [06_DEVELOPER_EXPERIENCE.md](06_DEVELOPER_EXPERIENCE.md).

### Phase status

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
| W7 | Canonical verbalizer + drift audit | ✅ Done |
| W8 | Traces, time, and oracle gate | ✅ Done |

Phase-by-phase history (archived): [`../.ai/implementation-log-archive/docs-history/status.md`](../.ai/implementation-log-archive/docs-history/status.md)
Implementation decisions: [`IMPLEMENTATION_LOG.md`](IMPLEMENTATION_LOG.md)
(recent) and [`.ai/implementation-log-archive/`](.ai/implementation-log-archive/)
(older entries)

---

## Key caveats

### Permission enforcement is actor-blind by default

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

See [`docs/04_RUNTIME.md`](docs/04_RUNTIME.md) §"Permissions and Policy" for details.

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

### No silent fallbacks: every resolution failure is a hard error

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
[docs/06_DEVELOPER_EXPERIENCE.md](docs/06_DEVELOPER_EXPERIENCE.md). Every
compile error is queryable: `meridian explain-diag MER2002`.

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

---

## Out of scope

*Permanent scope boundary — was `docs/21_OUT_OF_SCOPE.md` (now archived).*

This document is the permanent boundary for capabilities Meridian deliberately does
not implement. Everything **not** listed here that appeared in the v0.2 deferred
ledger (`MERIDIAN_SEMANTICS.md` §9.3, `MERIDIAN_DESIGN_RISKS_AND_REVIEW.md` §8) is
**Final Wave in-scope** — implemented (see `../.ai/implementation-log-archive/docs-history/status.md` and
`IMPLEMENTATION_LOG.md`).

The kernel semantics oracle remains [`docs/cookbook/MERIDIAN_SEMANTICS.md`](cookbook/MERIDIAN_SEMANTICS.md).

---

### 1. Formal prover discharge / machine-checked coherence theorem

Meridian defines a verification projection (`⟦·⟧_proof`) and a stable
compile-time **norm identity** (`OBL-<hash>`) that correlates runtime `violated`
/ `assert-failed` events with the lowered norms they falsify.

**Out of scope:** integrating Z3, Soufflé, Datalog, or any external proof engine;
discharging proof obligations automatically; proving a machine-checked theorem that
`⟦·⟧_exec` and `⟦·⟧_proof` agree for all traces. That work belongs to the
ModelHike formal-engine program, not `meridian-lib`.

**In scope (not out of scope):** stable norm ids, canonical IR + English for
lowered norms, witness hashes, and capture-policy metadata.

---

### 2. Localization / alternate canonical natural languages

Meridian's verbalization law (SEM-8-03) defines a single **canonical English**
surface per IR construct. Synonyms may parse; exactly one English form prints per
construct for the deterministic kernel.

**Out of scope:** alternate canonical natural languages (French, Japanese, …),
locale-aware canonicalization tables, translated problem messages as a parallel
oracle, and runtime selection of non-English canonical forms.

**In scope (not out of scope):** English synonym parsing, authored-form metadata
(e.g. D11 `unless` vs `if not`), deployment timezone for calendar amounts, and
formatting of dates/times in the configured zone.

---

### Explicitly in scope (formerly deferred)

The following are **not** out of scope; they moved into Final Wave when v0.3
semantics closed the deferred list:

- Wilson confidence intervals (SEM-6-04)
- State-history retention for keyed kinds (SEM-4-12, SEM-5-13)
- Bounded future monitors in Contract/obligation contexts (SEM-5-12)
- Calendar amounts distinct from physical duration (SEM-2-13)
- Clock skew / hybrid ingest ordering (SEM-4-11)
- Cross-skill trace scopes via declared lists (SEM-4-10, D4a)
- Formalized commit/recover meaning (SEM-3-01)
- Module/shared imports (SEM-MOD-01, SEM-MOD-02; see `docs/03_LANGUAGE.md`)
- Deontic layer, violation witnesses (SEM-7-01–05), coherence harness (SEM-8-01)
- SQLite / networked trace stores, OTLP export, signed trace chains
- LLM provider surfaces, MCP integration, CI conformance gates
- Zero-deferral audit against this document and the requirements matrix
