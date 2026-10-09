# Meridian — Testing Guide

Canonical reference for the three test workflows (also summarized in
`AGENTS.md` §4).

## Three test workflows

| Workflow | When | Command | Typical wall-clock |
|---|---|---|---|
| **Fast inner loop** | Iterating on in-process compiler/runtime/CLI parsing | `swift test --skip MeridianSlowIntegrationTests` | ~2 min |
| **Full test gate** | Phase sign-off, codegen/corpus/migration, before merge | `swift test` | ~8–10 min |
| **Coverage gate** | Substantive production changes | `scripts/coverage.swift --gate` | ~3 min on top of fast tests |

Coverage has three separate flows of its own (fast `--gate`, rare
`--full --gate`, occasional baseline regen) — see
[`docs/coverage/README.md`](../docs/coverage/README.md) § Commands.

### Fast inner loop

```bash
swift test --skip MeridianSlowIntegrationTests
```

### Full test gate

```bash
swift test
scripts/coverage.swift --gate
```

Use `scripts/coverage.swift --full --gate` when the change touched a file whose
reachable branches only `MeridianSlowIntegrationTests` exercises
(`RuntimeExecutor`, `SwiftPMPackageRunner`, the CLI `run`/`test` commands,
generated-Swift `swiftc -typecheck`, or process-level `meridian` E2E checks) —
see [Code Coverage](#code-coverage) below.

### Focused slow runs

```bash
swift test --filter GeneratedSwiftTypecheckSlowTests   # swiftc -typecheck only
swift test --filter MeridianSlowIntegrationTests       # all slow suites
```

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

`Tests/CorporaTests/` validates all six corpora under `corpora/` (`erp`,
`procedures`, `incident`, `etl`, `governance`, `clinical`) for completeness,
strict compile, and generated Swift sanity. The `swiftc -typecheck` gate lives
in `MeridianSlowIntegrationTests`.

`sample-gbrain/Tests/` is a separate SwiftPM test target for the gbrain corpus.
It validates the shared vocabulary/rulebook, strict compile for every ported
skill, migration behavior, generated Swift syntax guards, and committed
`compile-outputs/` freshness. The `swiftc -typecheck` gate lives in
`MeridianSlowIntegrationTests`.

`Tests/MeridianSlowIntegrationTests/` holds every suite that spawns a *live
external process* — `RuntimeExecutor` and `SwiftPMPackageRunner` driving a real
`swift build`/`swift run` through a temporary SwiftPM package, the CLI
`run`/`test` subcommands, per-file `swiftc -typecheck` over generated Swift for
goldens/corpora/gbrain, and process-level `meridian` binary E2E checks (DX
fixtures, verbalizer pipelines, trace eval/verify). These dominate wall-clock
time (minutes, not seconds) versus the rest of the suite; kept separate so
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
swift test --filter GeneratedSwiftTypecheckSlowTests
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
- For generated Swift validity, add or extend
  `Tests/MeridianSlowIntegrationTests/GeneratedSwiftTypecheckSlowTests.swift`
  (or run `swift test --filter GeneratedSwiftTypecheckSlowTests`) — do not
  treat `Compiler.compile` success as proof that Swift syntax is valid.
- For trace behavior, use `ParserTrace.capturing(categories:)`: pass
  `cap.trace` through `Compiler.Options` when the test drives a compile, or
  wrap a direct type call in `cap.trace.run { … }` (async variant for async
  bodies). Omit `trace:` when a test must ignore ambient `MERIDIAN_TRACE` —
  the default `.shared` is silent unless activated.

Minimal compile pattern:

```swift
let swift = try Compiler(options: .init()).compile(
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
the CLI `run`/`test` commands, generated-Swift `swiftc -typecheck`, or
process-level `meridian` E2E checks:

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

1. Run `swift test` (includes `MeridianSlowIntegrationTests` — typecheck,
   SwiftPM run, and CLI E2E).
2. Run `scripts/coverage.swift --gate` (add `--full` only if the phase touched
   a file whose reachable branches only `MeridianSlowIntegrationTests`
   exercises — see [Code Coverage](#code-coverage)).
3. Record decisions, blockers, confidence %, and residual risk in
   `IMPLEMENTATION_LOG.md`. When looking up prior phase work, also search
   `.ai/implementation-log-archive/` (see its `README.md`).
4. Pause for user sign-off before moving to the next phase.
