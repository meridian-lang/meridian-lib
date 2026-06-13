# Meridian design decisions (diagnostics & developer experience)

> Generated from `DecisionCatalog` by `meridian decisions --render docs/15_DECISIONS.md`.
> Do not edit by hand — update `Sources/MeridianCore/Diagnostics/DecisionCatalog.swift`
> and re-render. A test fails if this file drifts from the catalog.

Each decision is reachable from the errors it governs: run
`meridian explain <code>` (e.g. `meridian explain MER2002`) or
`meridian explain <decision-id>` (e.g. `meridian explain D-DX-5`).

## D-DX-1 — Unresolved phrases are hard errors by default

**Status:** accepted

An invocation that matches no phrase or workflow is almost always a typo or a missing declaration. Emitting a silent `_unresolved` placeholder hid real bugs until runtime. Strict-by-default surfaces them at compile time; the `allow-fallbacks: unresolved-phrases` escape hatch keeps early-authoring ergonomic.

**Alternatives considered:**

- Always emit an `_unresolved` placeholder (the old behaviour) — hides typos until runtime.
- Warn instead of error — warnings are routinely ignored in CI.

**Consequences:**

- Every phrase must resolve, or the file must opt into the fallback.
- The error funnels through `Diagnostic.unresolved`, so it always carries a did-you-mean or candidate list.

**See also:** MER2001, D-DX-2

## D-DX-2 — No silent compile-time fallbacks; batch-report with coarse recovery

**Status:** accepted

Silent drops (malformed headers, unparseable rules/statements, unknown config keys/sections) erased authoring mistakes. Every former silent site is now a coded diagnostic. The DiagnosticEngine collects rather than aborts, recovering at construct boundaries (workflow / rule / statement) so one compile reports many errors instead of one-at-a-time.

**Alternatives considered:**

- Abort on the first error — slow edit/compile loops; hides co-occurring errors.
- Token-level resync recovery — produces cascade/phantom errors.

**Consequences:**

- Constructs are skipped wholesale on error (cascade-resistant); phrase stubs are pre-registered so dependents still resolve.
- Structural codes carry a mandatory `help` string with the concrete fix.

**See also:** MER1001, MER1002, MER1003, MER1004, MER3006, MER3007

## D-DX-3 — swift-format failure is a recoverable warning, not an error

**Status:** accepted

Formatting is cosmetic. If swift-format chokes on otherwise-valid generated Swift, keeping the unformatted output is strictly better than failing the compile. The condition is surfaced as a warning so it is visible but non-fatal.

**Alternatives considered:**

- Fail the compile when formatting fails — loses valid output over a cosmetic step.
- Swallow the failure silently — hides a real formatter/codegen interaction bug.

**Consequences:**

- `compile` always writes Swift; a formatting failure is reported as a warning.

**See also:** MER5001

## D-DX-4 — Always-on did-you-mean for every name-resolution error

**Status:** accepted

A name-resolution failure is, by definition, a mismatch against a finite candidate set, so a remediation can always be named. Every such failure funnels through `Diagnostic.unresolved(code:target:among:range:)`, which attaches a `did you mean "X"?` suggestion when within edit-distance budget, or an enumerated candidate-list note otherwise — never a bare "unknown X".

**Alternatives considered:**

- Per-site ad-hoc messages — drift and inconsistency; easy to forget the hint.
- Only suggest when very close — leaves the user stuck when nothing is close.

**Consequences:**

- A guard test enumerates all `.nameResolution` codes and asserts each yields a suggestion or candidate-list note.
- Suggestions carry `replacement` + `range`, powering `--fix` and editor quick-fixes.

**See also:** MER2003, MER2004, MER2007, MER2008

## D-DX-5 — Unknown tools are errors; Core mirrors the runtime built-in catalog

**Status:** accepted

A misspelled or undeclared tool id silently compiled to an invoke that failed only at runtime. Core cannot import MeridianTools, so `BuiltinToolCatalog` hand-mirrors the runtime's built-in ids (kept in lockstep by a guard test). Every `InvokeIR.toolID` is validated against built-ins ∪ vocabulary `=== tools ===` ∪ frontmatter `tools:` ∪ workflow references, with did-you-mean.

**Alternatives considered:**

- Trust every emitted tool id — runtime-only failures, far from the source.
- Validate only vocabulary tools — false positives on built-ins and frontmatter tools.

**Consequences:**

- Recognition mirrors the invoke path (case-insensitive against methodName; methodized built-ins).
- `allow-fallbacks: unknown-tools` downgrades per-file for host-provided tools.

**See also:** MER2002
