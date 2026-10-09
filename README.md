# Meridian

A **controlled natural language compiler** for agent workflows and business rules.
Meridian reads English-shaped specifications and compiles them to readable,
type-checked, async/await Swift plus a small deterministic runtime.

**Current status: Phases 0–6, 6.5, 8, G, Inform-7 Waves 1–8 complete. Generated Swift compiles, links, and runs; Wave 7 canonical English and Wave 8 trace-backed time/statistics round-trip across the committed corpora.**

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
| [`docs/README.md`](docs/README.md) | **Start here** — reading-order index for the nine numbered docs (`01_OVERVIEW` … `09_SKILL_PORTING`), `15_PROBLEM_MESSAGES`, the `cookbook/` semantics oracle, and `coverage/` |
| [`docs/01_OVERVIEW.md`](docs/01_OVERVIEW.md) | One-page pitch, mental model, quick start, project status, key caveats, permanent out-of-scope boundary |
| [`AGENTS.md`](AGENTS.md) | AI contributor handbook — norms, phase gate, pitfalls, repo layout, CLI table |
| [`IMPLEMENTATION_LOG.md`](IMPLEMENTATION_LOG.md) | Append-only decision log (recent); older entries in [`.ai/implementation-log-archive/`](.ai/implementation-log-archive/) |
| [`docs/cookbook/`](docs/cookbook/) | Normative semantics/surface oracle (Waves 7–9 / Final Wave) |

---

## Important caveats

- **Permissions are actor-blind by default.** `may` rules compile to `Permission`
  structs + `AssertIR` gates that evaluate *data predicates* (e.g.
  `order.totalAmount`), not caller identity. Role-based checks need a custom
  `PermissionRegistry`. See [`docs/01_OVERVIEW.md`](docs/01_OVERVIEW.md)
  § "Permission enforcement is actor-blind by default" and
  [`docs/04_RUNTIME.md`](docs/04_RUNTIME.md) § "Permissions and Policy".
- **No silent fallbacks.** Every resolution failure is a hard, coded `MERxxxx`
  error with a source caret and a did-you-mean hint; opt back in per file with
  the `.meridian` frontmatter key `allow-fallbacks:`. See
  [`docs/01_OVERVIEW.md`](docs/01_OVERVIEW.md) § "No silent fallbacks" and
  [`docs/06_DEVELOPER_EXPERIENCE.md`](docs/06_DEVELOPER_EXPERIENCE.md).
- **`llm.decide` / `llm.judge` return `false` without an LLM host** — deliberate
  test safety. Register your own closure tool under the same ID to connect a
  provider.
