# Meridian — Overview

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
│  11 IR primitives                    │
│  invoke / bind / branch / emit /     │
│  wait / iterate / assert / commit /  │
│  recover / complete / simultaneously │
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
- **All IR primitives** — invoke, bind, rebind, branch, emit, wait (duration/signal/
  approval/event), iterate, assert, commit, recover, complete, and `simultaneously`.
- **Replay-safe resume** — generated code automatically consumes a prepared resume
  context, restores state from the latest checkpoint, and skips already-executed
  side effects with stable progress labels.
- **Blueprint built-ins** — `MeridianTools.registerBuiltins()` adds HTTP, file, JSON,
  regex, shell, MCP, schema validation, time, and UUID tools out of the box.

## End-to-end flow

```
.merconfig  ──► MerConfigParser ──► SymbolTable ──┐
                                                  │
.meridian   ──► MeridianParser ──► MeridianFile ──┤
                                                  ▼
                            ASTToIR ──► [IRWorkflow]
                                                  │
                         SwiftEmitter ──► Swift source
                                                  │
                      swift-format (optional) ──► formatted Swift
                                                  │
                           Written to  {stem}.swift + {stem}.meridian.manifest.json
```
