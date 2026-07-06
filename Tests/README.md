# Meridian — Testing Guide

Run the default suite from the repository root:

```bash
swift test
```

For a fast inner loop while iterating, skip the slow, real-external-process
suites (see `MeridianSlowIntegrationTests` below):

```bash
swift test --skip MeridianSlowIntegrationTests
```

The high-signal local gate for substantive production changes is:

```bash
swift test
MERIDIAN_GOLDEN_TYPECHECK=1 MERIDIAN_GBRAIN_TYPECHECK=1 MERIDIAN_CORPORA_TYPECHECK=1 swift test
scripts/coverage.swift --gate
```

Use `scripts/coverage.swift --full --gate` instead when the change touched a
file whose reachable branches only `MeridianSlowIntegrationTests` exercises
(`RuntimeExecutor`, `SwiftPMPackageRunner`, the CLI `run`/`test` commands) —
see [Code Coverage](#code-coverage) below.

For `.meridian.test` spec files and the `meridian test` runner, see
[`docs/09_MERIDIAN_TESTS.md`](../docs/09_MERIDIAN_TESTS.md).

## Suite Map

`Tests/MeridianCoreTests/` is the compiler target. It covers parser and grammar
productions, symbol-table matching, lowering, rulebooks, migration, codegen,
manifest emission, diagnostics, tracing, testing infrastructure, and focused
regression tests for the pitfalls recorded in `AGENTS.md`.

`Tests/MeridianCLITests/` covers `MeridianCLIKit` command parsing, dependency
discovery, output paths, diagnostics, and command-specific behavior. Tests keep
real SwiftPM subprocess work narrow; pure helpers and filesystem behavior are
preferred where possible.

`Tests/MeridianRuntimeTests/` covers `Value`, `State`, comparison semantics,
runtime events, permissions, planning primitives, tracing renderers, tool
registry behavior, and workflow harness support.

`Tests/MeridianToolsTests/` covers built-in tool implementations and schema or
dispatch helpers that can run deterministically in-process.

`Tests/CorporaTests/` validates the ERP and procedure corpora for completeness,
strict compile, generated Swift sanity, and optional generated-Swift typechecks
when `MERIDIAN_CORPORA_TYPECHECK=1` is set.

`sample-gbrain/Tests/` is a separate SwiftPM test target for the gbrain corpus.
It validates the shared vocabulary/rulebook, strict compile for every ported
skill, migration behavior, generated Swift syntax guards, committed
`compile-outputs/` freshness, and optional `swiftc -typecheck` via
`MERIDIAN_GBRAIN_TYPECHECK=1`.

`Tests/MeridianSlowIntegrationTests/` holds every suite that spawns a *live
external process* — `RuntimeExecutor` and `SwiftPMPackageRunner` driving a real
`swift build`/`swift run` through a temporary SwiftPM package, and the CLI
`run`/`test` subcommands. These dominate wall-clock time (minutes, not
seconds) versus the rest of the suite; kept separate so
`swift test --skip MeridianSlowIntegrationTests` gives a fast inner loop while
plain `swift test` (used by the full gate and CI) still exercises them.

## Focused Runs

Use `swift test --filter <SuiteOrTestName>` while iterating. Common filters:

```bash
swift test --filter AGENTSSharpEdgeRegressionTests
swift test --filter InertYieldCommandTests
swift test --filter SectionRoleRulebookBehaviorTests
swift test --filter ManifestEmitterCoverageTests
swift test --filter SampleGbrainCodegenTests
MERIDIAN_CORPORA_TYPECHECK=1 swift test --filter CorporaConformanceTests
```

Some tests intentionally shell out, mutate process environment, or build
temporary SwiftPM packages. Keep those tests small, prefer `.serialized` suites
when global environment mutation is involved, and use existing helpers such as
`TempDir`, `RuntimeExecutor`, `SwiftPMPackageRunner`, and
`MeridianTestRunner` instead of custom shell loops. Any *new* test that spawns
a real `swift build`/`swift run` or otherwise depends on a live external
process belongs in `Tests/MeridianSlowIntegrationTests/`, not in
`MeridianCoreTests`/`MeridianCLITests` — see the target comment in
`Package.swift`.

## Adding Tests

Prefer behavioral tests with the narrowest surface that proves the invariant:

- For parser/lowering behavior, parse or lower directly when that exposes the
  branch clearly; use `Compiler` only when end-to-end wiring is the invariant.
- For codegen, assert stable structural snippets, not whole generated files,
  unless the test is explicitly a freshness or golden-output check.
- For generated Swift validity, use the opt-in typecheck gates rather than
  treating `Compiler.compile` success as proof that Swift syntax is valid.
- For trace behavior, use `ParserTrace.capturing(categories:)` and pass the
  captured trace explicitly; use `.silent()` when a test must ignore ambient
  `MERIDIAN_TRACE`.

Minimal compile pattern:

```swift
let swift = try Compiler(options: .init(trace: .silent())).compile(
    meridianSource: "To run:\n  complete.\n",
    meridianFile: "demo.meri",
    merconfigSource: "=== vocabulary ===\n",
    merconfigFile: "demo.merconfig"
)
#expect(swift.contains("struct Run"))
#expect(!swift.contains("_unresolved"))
```

## Code Coverage

Coverage is measured and enforced per file by `scripts/coverage.swift`. Every
in-scope `Sources/Meridian*` file requires 100% region coverage unless
`docs/coverage/coverage-exclusions.md` lists a reviewed floor or exclusion.
`docs/coverage/coverage-baseline.md` is generated by the coverage script.

```bash
scripts/coverage.swift --gate
scripts/coverage.swift --no-test --gate
scripts/coverage.swift --html .coverage-html
```

By default `scripts/coverage.swift` runs `swift test --skip MeridianSlowIntegrationTests`
— the slow, real-external-process suites aren't needed for most coverage
checks and would otherwise dominate the script's wall-clock time. Pass
`--full` when you specifically need an accurate coverage reading that depends
on that target, e.g. after editing `RuntimeExecutor`, `SwiftPMPackageRunner`,
or the CLI `run`/`test` commands:

```bash
scripts/coverage.swift --full --gate
```

Regenerating the committed baseline/exclusions is a **separate, occasional
maintenance flow**, not something the two gate commands above trigger — always
`--full` there, since a fast-only baseline understates the slow-test-dependent
files:

```bash
scripts/coverage.swift --full --baseline docs/coverage/coverage-baseline.md
```

Code that needs a live external thing, such as a subprocess, network endpoint,
SwiftPM build, terminal I/O, or LLM provider, may keep a relaxed floor. Reachable
in-process code should trend toward 100%; when tests raise coverage, update the
baseline and tighten or remove the matching floor. The detailed policy lives in
[`docs/coverage/README.md`](../docs/coverage/README.md).

## Phase Gate Checklist

Before signing off a phase:

1. Run `swift test`.
2. Run the generated-Swift typecheck gate relevant to the change, or the full
   trio for broad work.
3. Run `scripts/coverage.swift --gate` (add `--full` only if the phase touched
   `RuntimeExecutor`, `SwiftPMPackageRunner`, or the CLI `run`/`test`
   commands).
4. Record decisions, blockers, confidence %, and residual risk in
   `IMPLEMENTATION_LOG.md`.
5. Pause for user sign-off before moving to the next phase.
