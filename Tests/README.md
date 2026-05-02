# Meridian — Testing Guide

All tests live in `Tests/`. Run with:

```bash
swift test                                          # all tests
swift test --filter MeridianCoreTests               # core compiler tests
swift test --filter Phase3ForcingFunction           # end-to-end forcing function
swift test --filter ParserTraceTests                # trace facility tests
swift test --filter SwiftEmitterTests               # codegen golden tests
```

For `.meridian.test` spec files and the `meridian test` runner, see
[`docs/09_MERIDIAN_TESTS.md`](../docs/09_MERIDIAN_TESTS.md).

---

## Test suites

### `MeridianCoreTests`

The main test target. Contains:

| File | What it tests |
|---|---|
| `SwiftEmitterTests.swift` | Codegen golden strings for each IR primitive |
| `ParserTraceTests.swift` | `ParserTrace` capturing, category enabling, `silent()` |
| `Phase2ForcingFunction.swift` | End-to-end: compile test, parsing-level assertions |
| `Phase3ForcingFunction.swift` | End-to-end: compile `order_processing.meridian`, assert generated Swift is correct |

### `MeridianRuntimeTests`

Tests for `Value`, `State`, `MeridianComparison`, and `Runtime` actor.

### `MeridianIntegrationTests`

Contains `HandWrittenOrderProcessingTests.swift` — tests against the
hand-written Phase 1 reference flows in `SampleDemoFlows/`.

### `MeridianToolsTests` (Phase 6)

Tests for built-in tool implementations.

---

## Phase 3 forcing function in detail

`Phase3ForcingFunction.swift` compiles `examples/order_processing.meridian`
plus `examples/ecommerce.merconfig` in-process and makes assertions about the
generated Swift string. The 8 tests are:

| Test | What it checks |
|---|---|
| `compilesWithoutError` | `Compiler.compile` does not throw |
| `noUnresolvedPlaceholders` | No `_unresolved` anywhere in the output |
| `hasConstantsStruct` | `public struct Constants: Sendable` is present |
| `hasInstancesStruct` | `public struct Instances: Sendable` is present |
| `hasRecursiveWorkflowCall` | `ProcessOrder(runtime: runtime` appears (recursive call) |
| `hasMeridianComparisonIsWithin` | `MeridianComparison.isWithin` appears |
| `instanceRefsResolve` | `instances.primaryMailer` or `instances.stripe` appears |
| `payloadValuesAreWrapped` | `?? .null` and `.string(` appear in invoke args |

These tests are the **primary regression gate** for the compiler.

---

## Adding a new end-to-end test

1. Put new `.meridian` and `.merconfig` files in `examples/`.
2. Add a test file under `Tests/MeridianCoreTests/` (or a new group folder).
3. Use the `Compiler` facade directly:

```swift
import Testing
@testable import MeridianCore

@Test func myNewWorkflowCompiles() throws {
    let mer = try String(contentsOfFile: "examples/my_workflow.meridian", encoding: .utf8)
    let cfg = try String(contentsOfFile: "examples/my_vocabulary.merconfig", encoding: .utf8)

    let out = try Compiler().compile(
        meridianSource: mer,
        meridianFile: "my_workflow.meridian",
        merconfigSource: cfg,
        merconfigFile: "my_vocabulary.merconfig"
    )

    #expect(out.swift.contains("public struct MyWorkflow"))
    #expect(!out.swift.contains("_unresolved"))
}
```

---

## Adding a codegen golden test

Use `SwiftEmitterTests.swift` as a template:

```swift
@Test func myNewPrimitive() {
    let ir = IRWorkflow(
        name: "do something",
        parameters: [],
        body: [
            .invoke(InvokeIR(toolID: "myTool", arguments: [], sourceRange: nil))
        ]
    )
    let emitter = SwiftEmitter(options: .init(emitSourceLineComments: false))
    let out = emitter.emitFile(workflows: [ir])

    #expect(out.contains("try await runtime.invoke(tool: \"myTool\""))
}
```

Keep golden strings minimal — assert only the structural element you care
about, not the entire file.

---

## Adding a trace-capture test

`ParserTrace.capturing` is a static factory returning `(trace, lines)` — not
a closure. Pass `cap.trace` into the compiler; call `cap.lines()` after.

```swift
@Test func phraseMatchEmitsCandidate() throws {
    let cap = ParserTrace.capturing(categories: [.phraseMatch])

    _ = try Compiler(options: .init(trace: cap.trace)).compile(
        meridianSource: myMer,
        meridianFile: "test.meridian",
        merconfigSource: myCfg,
        merconfigFile: "test.merconfig"
    )

    let lines = cap.lines()
    #expect(lines.contains { $0.contains("validate an order") })
}
```

---

## CI expectations

The CI matrix runs `swift test` on:

- macOS 14 (minimum deployment target)
- macOS 15 (latest)

All 128+ tests must pass before merging to `main`. The Phase 3 forcing
function is the most important gate.

---

## Confidence audit checklist (phase gate rule)

Before signing off a phase:

1. Run `swift test` — zero failures.
2. Run the CLI forcing function manually (compile → build → run → diff).
3. Check `IMPLEMENTATION_LOG.md` — every decision for this phase is recorded.
4. Assign a confidence % and record it in `IMPLEMENTATION_LOG.md` under
   `### Phase N confidence audit`.
5. Only proceed to the next phase at ≥ 95%.
