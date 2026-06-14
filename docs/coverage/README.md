# Meridian — Code Coverage

This folder is the canonical reference for how code coverage is measured and
**enforced** in Meridian. If you just want the quick commands, jump to
[Commands](#commands). If you're trying to push a number up, jump to
[Increasing coverage](#increasing-coverage).

> **One-line summary.** Coverage is a per-file, regression-based gate run by a
> single Swift shebang script (`scripts/coverage.swift`). Every in-scope source
> file has a required floor — 100% by default — and the build fails the moment
> any file drops below its floor. `coverage-exclusions.md` is the reviewed list
> of every file allowed below 100%, each with a justification.

> **The policy in one sentence.** Code that requires a *live external thing* — a
> spawned subprocess, a network endpoint, a SwiftPM toolchain build, an LLM
> provider — does **not** need 100% coverage; **everything else should aim for
> 100%.** A floor below 100 on reachable, in-process code is a *temporary target*
> to be ratcheted up, not a resting state.

---

## Table of contents

1. [Why it's done this way](#why-its-done-this-way)
2. [How it works (the pipeline)](#how-it-works-the-pipeline)
3. [Commands](#commands)
4. [The two files](#the-two-files-baseline--exclusions)
5. [What's in scope](#whats-in-scope)
6. [The floor buckets](#the-floor-buckets)
7. [Current state](#current-state)
8. [Increasing coverage](#increasing-coverage)
9. [Pitfalls](#pitfalls)
10. [FAQ](#faq)

---

## Why it's done this way

The goal is to **catch silent breakages**: a refactor that deletes a branch, an
emitter path that stops being reached, a helper that quietly goes dead, a new
`else` arm nobody tests.

A single global percentage can't catch that — one file can lose coverage while
the repo-wide number stays flat (or even rises, if you added tests elsewhere). So
the gate is:

- **Per-file.** Each `Sources/Meridian*` file is checked individually.
- **Regression-based.** Each file has a required *floor*. The floor is the
  region% already achieved, so the gate fails the instant a change drops a file
  below where it stands today — even if the global total is unchanged.
- **100% by default.** A file with no entry in `coverage-exclusions.md` must be
  at 100% region coverage. Anything lower is a deliberate, written-down decision.

### The line: integrations vs. everything else

The single rule that decides whether a file is *allowed* to sit below 100%:

> **Does exercising the uncovered code require a live external thing?** A spawned
> subprocess, a network call, a real SwiftPM build/run, an LLM provider, terminal
> I/O the test can't capture. If **yes**, that tail is exempt — it can't be
> deterministically unit-tested in-process. If **no**, it must aim for 100%.

So the two buckets ([below](#the-floor-buckets)) are not equals:

- **(A) Integration boundaries** keep a relaxed floor *permanently*. Reaching
  100% there would mean writing brittle, environment-dependent tests inside a
  unit harness — not worth it. We still floor them so they can't *regress*.
- **(B) Reachable, in-process code** is held to a floor only *temporarily*. Its
  uncovered lines are reachable by a deterministic test; the floor exists so the
  gate stays green while those tests are written, and it should be **ratcheted
  toward 100** every time someone touches the file. A bucket-B file at 100% has
  its threshold entry removed (so the gate then requires 100% of it forever).

There is deliberately **no shell script and no GitHub Actions workflow** for
this — the repo has a no-`.sh` rule, and the gate is a Swift script run as part
of the normal test workflow.

---

## How it works (the pipeline)

`scripts/coverage.swift` runs:

1. **`swift test --enable-code-coverage`** — produces an instrumented test
   binary and a merged profile. Skip with `--no-test` to reuse the previous
   run's profile data (fast, when you only changed the exclusions file).
2. **Locate artifacts** under `.build/`: the merged
   `…/codecov/default.profdata` and the instrumented
   `meridianPackageTests.xctest` binary.
3. **`xcrun llvm-cov report`**, scoped to the in-scope modules. The base ignore
   regex always drops `.build/`, `/Tests/`, `/checkouts/`, and
   `Sources/SampleDemoFlows/`, plus anything in the `exclude-files` block.
4. **Parse** the per-file table (region%, line%, missed regions) for rows in the
   in-scope `Meridian*` modules.
5. **Apply `coverage-exclusions.md`** — per-file floors override the global
   threshold.
6. **Report**, and with `--gate`, **exit non-zero** if any non-excluded file is
   below its required region coverage.

Coverage is reported on **regions** (the gate metric) as well as functions and
lines (informational). Regions are the finest granularity `llvm-cov` exposes per
file.

---

## Commands

```bash
# Build + test, then print the report (report-only, never fails)
scripts/coverage.swift

# Reuse the last run's .profdata (fast — no rebuild/retest)
scripts/coverage.swift --no-test

# ENFORCE: exit 1 if any non-excluded file is below its floor
scripts/coverage.swift --no-test --gate

# Build + test + enforce, in one shot
scripts/coverage.swift --gate

# Override the global floor (applies to files without a per-file entry)
scripts/coverage.swift --threshold 95

# Write the report to a file (regenerate the committed baseline)
scripts/coverage.swift --baseline docs/coverage/coverage-baseline.md

# Emit a clickable HTML drill-down (great for finding red lines)
scripts/coverage.swift --html .coverage-html
```

The enforced check is `scripts/coverage.swift --gate` (or
`--no-test --gate` after a normal coverage-enabled `swift test`).

---

## The two files (baseline + exclusions)

Both live in this folder, `docs/coverage/`. The script reads
`docs/coverage/coverage-exclusions.md` by path; the baseline is written wherever
`--baseline` points (use `docs/coverage/coverage-baseline.md`).

### `coverage-baseline.md` — generated report

Written by `--baseline`. It's the full per-file table plus the `TOTAL` line.
**Do not edit by hand** — regenerate it after any coverage-affecting change so
reviewers can see the diff.

### `coverage-exclusions.md` — reviewed source of truth

The only place a file is allowed below 100%. The script parses two fenced
blocks; trailing `# comments` and blank lines are ignored:

````markdown
```exclude-files
# path substrings removed from the denominator entirely (folded into
# llvm-cov -ignore-filename-regex). Use ONLY for code that cannot be
# meaningfully unit-tested in-process. Currently empty.
```

```file-thresholds
# path-substring                                  = min-region-percent
MeridianCore/Lowering/RuleInjector.swift          = 75
MeridianRuntime/Planning/PlanExecutor.swift       = 42
…
```
````

- **`exclude-files`** removes a file from the denominator entirely. Strongest and
  bluntest — prefer a threshold instead, so the file still catches drops.
- **`file-thresholds`** keeps the file measured but lowers its required floor.
  The number is a regression floor: set it to the region% the file has actually
  reached. Tighten it toward 100 as more branches gain tests; only lower it for
  genuinely unreachable code, and say why in the file.

Matching is by **substring** of the `llvm-cov` file path, so
`Lowering/RuleInjector.swift` matches the full
`Sources/MeridianCore/Lowering/RuleInjector.swift` row.

---

## What's in scope

In-scope modules (rows the gate evaluates):
`MeridianCore`, `MeridianRuntime`, `MeridianTools`, `MeridianTestKit`,
`MeridianCLIKit`.

Always out of scope (hard-coded in the script, regardless of the exclusions
file): `.build/`, `/Tests/`, `/checkouts/`, and `Sources/SampleDemoFlows/`. The
demo flows (`EcommerceWorkflows`, `GeneratedOrderProcessing`,
`OrderProcessingDemo`) are committed reference fixtures, behavior-tested by
`MeridianIntegrationTests` (compile → build → run + event goldens), not held to a
coverage bar.

---

## The floor buckets

Every entry in `file-thresholds` is one of two kinds (documented inline in
`coverage-exclusions.md`):

**(A) Integration boundaries** — the uncovered tail genuinely cannot run
in-process because its success path needs a live toolchain, server, or
subprocess:

- CLI subcommands (`MeridianCLIKit/*`) — `run()` bodies write stdout/stderr and
  the real filesystem, and several shell out (`run`, `migrate-skill`,
  `skill-deviation`, `resume`, `test`). Pure helpers are covered; the
  process-spawn/terminal-output tails are not.
- `Testing/RuntimeExecutor`, `Testing/SwiftPMPackageRunner` — scaffold and
  `swift build` / `swift run` a temp SwiftPM package. Early-returns and string
  building are covered; the build/run subprocess tail is not.
- `Tools/ToolRegistry` — HTTP / MCP / subprocess dispatch needs a live endpoint.
  Registration, schema, closure, and error-wrapping paths are covered.
- `Planning/PlanExecutor`, `ActPlanner`, `Planner`, `MockPlanning` — the LLM
  planning loop needs a provider. Value-type and policy paths are covered.

**(B) Reachable residual** — defensive guards, `preconditionFailure`s, dead
"future-pass" code, and hard-to-trigger error arms. None of these need a live
external thing, so **all of them should aim for 100%.** Their floors are
*temporary* — ratchet each toward 100 as targeted tests land, and remove the
threshold entry entirely once a file hits 100% (the gate then locks it there).
This bucket is the standing backlog; the [Increasing coverage](#increasing-coverage)
loop is exactly how you burn it down.

A genuinely unreachable line in bucket (B) — e.g. an `internal:`
`preconditionFailure` that can only fire on a compiler bug — may keep a floor a
notch below 100 *with a comment naming the line*. That is the only acceptable
permanent sub-100 floor for reachable code.

---

## Current state

At the lock point (see `IMPLEMENTATION_LOG.md` → "2026-06-14 — Coverage lock"):

- **TOTAL ≈ 82% region / 84% function / 90% line** across the in-scope modules.
- **~33 files at literal 100%** region coverage (the gate requires it of them).
- The remainder carry documented floors in the two buckets above.
- The gate is **green**.

Regenerate the live numbers any time with `scripts/coverage.swift --baseline
docs/coverage/coverage-baseline.md`.

---

## Increasing coverage

A repeatable loop:

### 1. Find the unexecuted lines

The `Missed` column in the report ranks the worst files. Then drill in:

```bash
PROFDATA=$(find .build -name default.profdata -path '*codecov*' | head -1)
BIN=$(find .build -name meridianPackageTests.xctest | head -1)/Contents/MacOS/meridianPackageTests

xcrun llvm-cov show "$BIN" -instr-profile "$PROFDATA" \
  Sources/MeridianCore/Lowering/RuleLowering.swift | rg -n '\|\s+0\|'
```

Lines whose execution-count column is `0` are unexecuted. For a whole-repo,
clickable view use `scripts/coverage.swift --html .coverage-html` and open
`.coverage-html/index.html`.

### 2. Write a direct unit test for the branch

Prefer **constructing the data structure directly** and calling the unit under
test over driving a full compile — it's faster and pins the exact branch:

- Codegen → build an `IRWorkflow` / `IRExpression` and call `SwiftEmitter`
  (`emitExpr`, `emitValueExpr`, `emitFile`). See `SwiftEmitterCoverageTests`.
- Manifest/domain → `ManifestEmitter.Input` / `DomainEmitter`. See
  `CodegenManifestCoverageTests`.
- Spec-runner → build an `AssertionContext` and call `evaluate`; walk IR with
  `IRWalker`. See `AssertionsCoverageTests`, `TestingInfraCoverageTests`.
- Tools → call `MeridianTools.invoke(id, args:)` directly. See
  `MeridianToolsCoverageTests`.
- Tracing → feed event arrays / JSONL to `TraceTreeRenderer`. See
  `TraceTreeRendererCoverageTests`.
- Lowering heuristics that only run during injection → a small full compile with
  rules + a matching workflow. See `RuleLoweringCoverageTests`.

Use Swift Testing throughout (`@Test`, `@Suite`, `#expect`) — never XCTest.

### 3. Re-baseline and tighten the floor

```bash
   scripts/coverage.swift --baseline docs/coverage/coverage-baseline.md   # full run
   scripts/coverage.swift --no-test --gate                                # confirm still green
```

Edit `coverage-exclusions.md` so each improved file's floor matches its new
(floored) region%. The point of raising the floor is that the gate now *protects*
the gain you just made.

---

## Pitfalls

- **Coverage is measured per *file*, and a floor can move down.** Adding or
  removing test files recompiles the test binary, which recomputes region counts;
  a `Sources/` file's ratio can shift a fraction in *either* direction. After
  changing the test set, always re-run `--baseline` and reconcile floors against
  the fresh numbers — never assume floors only go up, and set floors from the
  current run, not a remembered value.
- **`--no-test` reuses stale profile data.** If you changed source or tests, the
  numbers are from the *previous* binary until you run a full pass. Use
  `--no-test` only when you changed nothing but `coverage-exclusions.md`.
- **Substring matching.** A threshold path-substring matches any row containing
  it. Keep substrings specific enough (include the directory) to avoid matching
  two files.
- **`exclude-files` hides the file from the denominator.** It then catches *no*
  regressions in that file. Prefer a low `file-thresholds` floor over an
  `exclude-files` entry whenever the file has any testable surface.

---

## FAQ

**Why not just require 100% everywhere?** Some code's success path is a live
external process (SwiftPM build, HTTP server, LLM provider) or is unreachable
defensive code (`preconditionFailure`). Forcing 100% there means either deleting
safety nets or writing brittle integration tests in a unit-test harness. The
floor mechanism makes the exception explicit and reviewable instead of silent.

**Where do the floor numbers come from?** The achieved region% from a real
`llvm-cov` run, floored to an integer. They are a no-regression contract, not a
target — raise them as you add tests.

**How do I see coverage for one file fast?** `--html` then open the file, or the
`llvm-cov show … | rg '\|\s+0\|'` recipe above.

**Does this run in CI?** There's no separate CI workflow file. The gate is the
Swift script; run `scripts/coverage.swift --gate` wherever you run `swift test`.

---

See also: [`../../Tests/README.md`](../../Tests/README.md) (test suites and the
condensed coverage section), [`coverage-exclusions.md`](coverage-exclusions.md)
(the live floor list), [`coverage-baseline.md`](coverage-baseline.md) (the
generated report), and `../../IMPLEMENTATION_LOG.md` (the lock decision and
rationale).
