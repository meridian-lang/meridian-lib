# Meridian `.meridian.test` Specs

`.meridian.test` files are line-oriented specs consumed by the `meridian test`
runner. They are useful when a workflow fixture needs compiler, generated Swift,
IR, trace, manifest, or runtime assertions but does not need a dedicated Swift
test case.

Use them for:

- Fixture-style compiler regression tests.
- Golden generated Swift or manifest checks.
- Negative parse and semantic error tests.
- IR shape checks such as tool invokes, event emits, and primitive counts.
- Trace smoke tests for parser and lowering diagnostics.
- End-to-end compile, build, and run smoke tests.

Current examples live in `Tests/MeridianCoreTests/MeridianTestSpecs/`.

## Quick Start

Run all specs in a directory:

```bash
swift run meridian test Tests/MeridianCoreTests/MeridianTestSpecs
```

Run a single spec with detailed failures:

```bash
swift run meridian test Tests/MeridianCoreTests/MeridianTestSpecs/runtime_happy.meridian.test --verbose
```

Run only specs tagged `runtime`:

```bash
swift run meridian test Tests/MeridianCoreTests/MeridianTestSpecs --tag runtime
```

Run specs whose display name contains a string:

```bash
swift run meridian test Tests/MeridianCoreTests/MeridianTestSpecs --filter "order processing"
```

Refresh golden files after intentional codegen drift:

```bash
swift run meridian test Tests/MeridianCoreTests/MeridianTestSpecs --update-golden
```

## Minimal Spec

````text
name: compile only example
tags: compile, smoke

source_inline: ```
To run:
  complete.
```

expect_compile: pass
expect_no_unresolved:
expect_workflow_count: 1
expect_workflow_named: Run
````

`expect_compile: pass` is the default, but spelling it out makes the intent
clear. `expect_no_unresolved` is recommended for most successful compile specs
because it catches unmatched phrase fallbacks in the IR.

## File Format Rules

Each non-empty, non-comment line is `key: value`.

```text
name: readable display name
tags: compile, smoke
expect_compile: pass
```

Lines starting with `#` are ignored.

```text
# This explains why the fixture exists.
expect_no_unresolved:
```

Use a fenced code block for multi-line values. The opening fence is three
backticks (optionally followed by an info string like `meridian` for editor
syntax highlighting — the parser ignores it). The body is preserved verbatim
— no indent stripping — until a line whose trimmed text is exactly three
backticks. The fence makes the value boundary unambiguous, which matters when
the body itself contains markdown-y markers like frontmatter `---`.

````text
description: ```
Verifies a self-contained workflow fixture.
Useful when no external .meridian file is needed.
```

source_inline: ```meridian
---
vocabulary: mini.merconfig
---

To run:
  complete.
```
````

The legacy YAML-style `|` heredoc is no longer accepted; the parser emits a
diagnostic that points at the offending key.

Paths are resolved relative to the `.meridian.test` file, not the shell's
current directory. Unknown keys are ignored so newer specs remain readable by
older runners.

## Key Reference

| Key | Repeatable | Value | Purpose |
|---|---:|---|---|
| `name` | no | text | Display name. Defaults to filename without extensions. |
| `description` | no | text or fenced block | Human-readable context for the fixture. |
| `tags` | no | comma-separated text | Enables `--tag` filtering. |
| `only` | no | `true` | If any discovered spec has `only: true`, only `only` specs run. |
| `skip` | no | `true` | Skip this spec. |
| `skip_reason` | no | text | Reason printed when skipped. |
| `trace` | no | category list | Enables `ParserTrace` categories. |
| `source` | no | path | External `.meridian` source. |
| `source_inline` | no | fenced block | Inline `.meridian` source. |
| `vocab` | yes | path | External `.merconfig` vocabulary. |
| `vocab_inline <name>` | yes | fenced block | Inline `.merconfig` vocabulary. |
| `expect_compile` | no | `pass` or `fail` | Expected compile outcome. |
| `expect_error_kind` | no | `syntax`, `semantic`, `codegen` | Error class for failed compile specs. |
| `expect_error_contains` | no | text | Error substring for failed compile specs. |
| `expect_error_line` | no | integer | Reported source line for failed compile specs. |
| `expect_swift_contains` | yes | text | Generated Swift substring assertion. |
| `expect_swift_not_contains` | yes | text | Generated Swift absence assertion. |
| `expect_swift_matches` | yes | regex | Generated Swift regex assertion. |
| `expect_swift_line_count_min` | no | integer | Lower bound on generated Swift line count. |
| `expect_swift_line_count_max` | no | integer | Upper bound on generated Swift line count. |
| `golden_swift` | yes | path | Byte-for-byte generated Swift golden. |
| `golden_swift_path` | yes | path | Alias for `golden_swift`. |
| `golden_manifest` | yes | path | Byte-for-byte manifest JSON golden. |
| `no_line_comments` | no | `true` | Disable generated source-line comments before Swift assertions. |
| `expect_workflow_count` | no | integer | Number of lowered workflows. |
| `expect_workflow_named` | yes | struct name | Expected workflow struct name. |
| `expect_workflow_mode` | yes | `<StructName> strict|lenient` | Expected workflow execution mode. |
| `expect_no_unresolved` | no | empty | Assert there are no `_unresolved` binds. |
| `expect_invoke_tool` | yes | tool ID | Expected `InvokeIR.toolID`. |
| `expect_emit_event` | yes | event ID | Expected `EmitIR.eventID`. |
| `expect_primitive_count` | yes | `<kind> <count>` | Expected count of one IR primitive kind. |
| `expect_formatter_idempotent` | no | `true` | Source must already be formatter-stable. |
| `expect_trace_contains` | yes | text | Captured trace output substring. |
| `expect_run` | no | `true` | Build and execute generated Swift. |
| `workflow` | no | struct name | Workflow struct to execute. Defaults to first workflow. |
| `input <param>` | yes | JSON | Runtime input for workflow parameter. |
| `tool_stub <toolID>` | yes | JSON | Runtime return value for a tool stub. |
| `expect_event_kinds` | no | comma-separated event kinds | Exact runtime event-kind sequence. |
| `expect_event_kinds_prefix` | no | comma-separated event kinds | Prefix of runtime event-kind sequence. |
| `expect_final_event_kind` | no | event kind | Final emitted runtime event kind. |
| `expect_run_succeeded` | no | `true` or `false` | Assert whether the run completed successfully. |

## Source and Vocabulary Inputs

Use exactly one source input:

```text
source: order_processing.meridian
```

or:

````text
source_inline: ```
To run:
  complete.
```
````

Vocabulary inputs are optional and repeatable:

```text
vocab: ecommerce.merconfig
vocab: payments.merconfig
```

Inline vocabularies are named by the suffix after `vocab_inline`. The source
declares its dependencies in frontmatter as `vocabulary:` (comma-separated).

````text
vocab_inline mini: ```
An order is a kind of thing.
An order has an id, which is a String.
An order has a total, which is a Number.
```

source_inline: ```
---
vocabulary: mini.merconfig
---

To process an order:
  complete.
```
````

The runner provides all external and inline vocabularies to the compiler. A
source whose frontmatter `vocabulary:` references a name not in the supplied
inputs should be covered with an expected failure spec.

## Example: External Compile Fixture

This mirrors `compile_only.meridian.test` and is the most common shape for
fixture tests.

```text
name: compile only - order processing
description: Verifies that order_processing.meridian compiles cleanly.
tags: smoke, compile

source: order_processing.meridian
vocab: ecommerce.merconfig
no_line_comments: true

expect_compile: pass
expect_no_unresolved:
expect_workflow_count: 2
expect_workflow_named: ProcessOrder
```

Use `no_line_comments: true` when the assertion should not depend on source-line
comment placement in generated Swift.

## Example: Inline Self-Contained Fixture

Inline specs are good for small language regressions because the test case is
readable without opening supporting files.

````text
name: inline self-contained spec
description: Demonstrates inline source and vocabulary blocks.
tags: inline, smoke

vocab_inline mini: ```
An order is a kind of thing.
An order has an id, which is a String.
An order has a total, which is a Number.
```

source_inline: ```
---
vocabulary: mini.merconfig
---

To process an order:
  complete.
```

expect_compile: pass
expect_no_unresolved:
expect_workflow_count: 1
expect_workflow_named: ProcessOrder
expect_swift_contains: struct ProcessOrder: MeridianWorkflow
````

## Example: Expected Compile Failure

Negative specs should assert both the error class and a stable substring from
the diagnostic. Add `expect_error_line` when line reporting is part of the
behavior being pinned.

````text
name: expect error - unknown vocabulary import
description: A vocabulary referenced in frontmatter that was not supplied is a semantic error.
tags: compile, error

vocab_inline ecommerce: ```
An order is a kind of thing.
An order has an id, which is a String.
```

source_inline: ```
---
vocabulary: mystery.merconfig
---

To run:
  complete.
```

expect_compile: fail
expect_error_kind: semantic
expect_error_contains: mystery
````

Use the error keys only with `expect_compile: fail`. If compilation succeeds,
the runner reports the spec as failed before evaluating success-only assertions.

## Example: Swift Substring and Regex Checks

Use Swift output assertions when the exact full file is too noisy for a golden
but a few generated structures are important.

````text
name: generated Swift contains workflow shape
tags: codegen

source_inline: ```
To run:
  complete.
```

expect_swift_contains: public struct Run: MeridianWorkflow
expect_swift_contains: public func run() async throws -> Value
expect_swift_not_contains: _unresolved
expect_swift_matches: struct\s+Run:\s+MeridianWorkflow
expect_swift_line_count_min: 20
````

`expect_swift_matches` uses `NSRegularExpression` with dot matches line
separators enabled, so a regex can span the generated file.

## Example: Golden Swift and Manifest Checks

Golden checks compare the emitted output byte-for-byte with files on disk.

```text
name: order processing golden Swift
tags: golden, codegen

source: order_processing.meridian
vocab: ecommerce.merconfig
no_line_comments: true

golden_swift: golden/order_processing_expected.swift
expect_no_unresolved:
```

When a codegen change is intentional, refresh goldens with:

```bash
swift run meridian test Tests/MeridianCoreTests/MeridianTestSpecs --update-golden
```

Review golden diffs before accepting them. `--update-golden` makes a failed
golden assertion pass by overwriting the golden with current output.

## Example: IR Shape Assertions

IR assertions are less brittle than full Swift output checks when you care
about compiler semantics, not formatting.

```text
name: IR assertions - order processing invokes and emits
description: Exercises IRWalker assertions against lowered workflows.
tags: ir

source: order_processing.meridian
vocab: ecommerce.merconfig
no_line_comments: true

expect_workflow_count: 2
expect_workflow_named: ProcessOrder
expect_no_unresolved:
expect_invoke_tool: validateOrder
expect_invoke_tool: chargePayment
expect_emit_event: analytics.order_processed
expect_workflow_mode: ProcessOrder strict
expect_primitive_count: invoke 4
```

`expect_primitive_count` supports these primitive kinds:

```text
invoke, bind, branch, emit, complete, wait, iterate, assert, commit, recover, simultaneously
```

Prefer IR assertions for phrase matching, lowering, mode selection, and
primitive-level behavior. Prefer Swift assertions for codegen-specific details
such as replay guards, emitted imports, or function signatures.

## Example: Formatter Idempotence

Formatter specs assert that source is already in canonical format and that
formatting it twice is stable.

````text
name: formatter idempotent - tiny workflow
tags: formatter

source_inline: ```
To run:
  complete.
```

expect_compile: pass
expect_formatter_idempotent: true
````

This is intentionally stricter than "formatter can produce valid output": it
fails if formatting changes the original source at all.

## Example: Trace Assertions

Trace specs enable one or more trace categories, compile the source, and inspect
captured trace lines.

````text
name: phrase match trace includes matched phrase
tags: trace

trace: phrase.match, phrase.args

vocab_inline mini: ```
To check an order:
  complete.
```

source_inline: ```
---
vocabulary: mini.merconfig
---

To run:
  check an order.
```

expect_compile: pass
expect_trace_contains: phrase.match
expect_trace_contains: check an order
````

The `trace` key accepts exact category names such as `phrase.match`, group
prefixes such as `phrase`, or `all`. See `docs/08_TRACING.md` for the full
trace category list.

## Example: Runtime Smoke Test

Set `expect_run: true` to compile the source, scaffold a temporary SwiftPM
package, build it, run the generated workflow, and assert on runtime events.

````text
name: runtime - simple workflow smoke test
description: ```
Builds and runs a self-contained workflow in a subprocess to verify the
end-to-end compile, build, and run pipeline.
```
tags: runtime, slow

source_inline: ```
To run:
  complete.
```

expect_compile: pass
expect_no_unresolved:

expect_run: true
workflow: Run
expect_event_kinds_prefix: workflow.started
expect_final_event_kind: workflow.completed
expect_run_succeeded: true
````

The runtime path uses `SwiftPMPackageRunner`, so it requires the Swift toolchain
on `PATH` and is slower than compile-only specs. Tag runtime specs as `slow`
when they should be easy to exclude in local loops.

## Example: Runtime Inputs and Tool Stubs

Runtime specs can provide JSON inputs for workflow parameters and JSON return
values for invoked tools.

````text
name: runtime - process order with stubbed validation
tags: runtime, slow

vocab_inline shop: ```
An order is a kind of thing.
An order has an id, which is a String.

A validation is a kind of thing.
A validation has a verdict, which is a String.

To validate an order:
  invoke validate order with order = the order.

=== tools ===

Validate Order
==============
~ validateOrder(order: Order) : Validation
```

source_inline: ```
---
vocabulary: shop.merconfig
---

To process an order:
  validate the order.
  complete.
```

expect_compile: pass
expect_no_unresolved:

expect_run: true
workflow: ProcessOrder
input order: {"id":"o-001"}
tool_stub validateOrder: {"verdict":"valid"}
expect_event_kinds_prefix: workflow.started, invoke.start, invoke.end
expect_final_event_kind: workflow.completed
expect_run_succeeded: true
````

`input <param>` names must match workflow parameter names after parsing.
`tool_stub <toolID>` names must match the lowered `InvokeIR.toolID`, not
necessarily the natural-language phrase text.

## Programmatic use

`MeridianTestRunner` lives in `Sources/MeridianCore/Testing/MeridianTestRunner.swift` and
is exported from `MeridianCore`. You can use it directly without the CLI in
IDE plugins, CI status checks, or MCP endpoints:

```swift
import MeridianCore

let runner = MeridianTestRunner(verbose: true)
let roots = [URL(fileURLWithPath: "Tests/MeridianCoreTests/MeridianTestSpecs")]
let reports = runner.runAll(roots: roots)
for r in reports {
    print(r.spec.displayName, r.outcome)
}
```

The CLI's `TestCommand` is a thin wrapper that formats `runner.runAll` results
to stdout and exits non-zero on failure.

---

## Runtime Event Assertions

Use `expect_event_kinds_prefix` when the start of the run is stable but later
events may grow as instrumentation changes:

```text
expect_event_kinds_prefix: workflow.started, invoke.start
```

Use `expect_event_kinds` for exact event sequences:

```text
expect_event_kinds: workflow.started, commit, workflow.completed
```

Use `expect_final_event_kind` for the most stable success/failure assertion:

```text
expect_final_event_kind: workflow.completed
```

Use `expect_run_succeeded: false` for runtime failure fixtures:

```text
expect_run: true
expect_final_event_kind: workflow.failed
expect_run_succeeded: false
```

## CLI Options

```bash
swift run meridian test <path> [--verbose] [--update-golden] [--quiet] [--tag <tag>] [--filter <name>]
```

- `--verbose`: Print fuller diffs and runtime/build failures.
- `--update-golden`: Rewrite golden files instead of failing on drift.
- `--quiet`: Suppress individual success lines and print only the summary.
- `--tag`: Run specs whose tags overlap the supplied tag list. Repeatable.
- `--filter`: Run specs whose display name contains the string.

The command exits non-zero when any spec fails or when no `.meridian.test` files
are found.

## Choosing Assertions

Use the narrowest assertion that protects the behavior:

- Use `expect_no_unresolved` on nearly every successful compile spec.
- Use IR assertions when testing parser, phrase matching, or lowering behavior.
- Use Swift substring assertions when testing codegen shape.
- Use golden Swift only for important full-file fixtures.
- Use runtime specs sparingly because they build and run a temporary package.
- Use trace assertions for diagnostics behavior, not ordinary compiler behavior.

## Existing Specs

Current specs in `Tests/MeridianCoreTests/MeridianTestSpecs/`:

- `compile_only.meridian.test`: External source and vocab compile smoke.
- `expect_error_unknown_vocab.meridian.test`: Negative semantic error fixture.
- `formatter_idempotent.meridian.test`: Formatter stability fixture.
- `inline_self_contained.meridian.test`: Inline source and vocab example.
- `ir_invoke_count.meridian.test`: IR-level invoke and emit assertions.
- `runtime_happy.meridian.test`: End-to-end compile, build, and run smoke.
- `swift_substring_only.meridian.test`: Generated Swift substring fixture.

## Common Pitfalls

- `source` and `vocab` paths are relative to the spec file, not the current
  shell directory.
- Fenced-block bodies are read verbatim. Indentation is preserved, so don't
  add extra leading spaces unless they belong in the value.
- Use the generated workflow struct name in `workflow` and `expect_workflow_named`
  (`ProcessOrder`), not the source phrase (`process an order`).
- Use the lowered tool ID in `tool_stub` and `expect_invoke_tool`.
- Keep `only: true` out of committed specs unless the intent is to temporarily
  narrow discovery.
- `--update-golden` overwrites files. Use it only for intentional output drift.
- Runtime specs need a working Swift toolchain and can be noticeably slower than
  compile-only specs.
