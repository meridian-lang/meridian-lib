# Deontic norms and obligations (Wave 9)

Meridian's **deontic layer** expresses prohibitions (`must not invoke …`),
obligations (`… must hold`), and permissions (`may invoke …`) as first-class
norms attached to skill, workflow, section, or kind scope. The compiler lowers
them onto existing IR primitives — attempt-time guards on `invoke`, effect-time
`assert` metadata, and recover routing — without a dedicated deontic IR
primitive.

Normative meaning lives in [`docs/cookbook/MERIDIAN_SEMANTICS.md`](cookbook/MERIDIAN_SEMANTICS.md) §7–8. Surface examples appear in
[`docs/cookbook/MERIDIAN_SYNTAX_COOKBOOK.md`](cookbook/MERIDIAN_SYNTAX_COOKBOOK.md) Part VI. This document is the
maintainer-facing reference for enforcement, diagnostics, and audit hooks.

---

## Norm kinds

| Surface | Norm kind | Enforcement time | Trace disposition |
|---|---|---|---|
| `must not invoke <tool> [whose …]` | prohibition | **Attempt-time** — before the tool runs | `violated (prevented)` when blocked |
| `<predicate> must hold [, blocking]` | obligation | **Effect-time** — at commit points and section exits | `violated (observed)` on failure |
| `may invoke <tool> [only where …]` | permission | **Attempt-time** — default-deny scopes require a covering grant | denied invoke if uncovered |

**Attempt-time** norms govern whether an `invoke` may proceed. A prevented
prohibition still emits a trace event — auditors see the attempt, not only the
outcome ([SEM-7-02](cookbook/MERIDIAN_SEMANTICS.md), decision D3).

**Effect-time** obligations check state or trace-backed conditions at designated
evaluation points. Blocking obligations route failure through `recover` and halt
the section; non-blocking obligations record `violated (observed)` and continue
unless the author marks the obligation `blocking`.

Advisory modals (`should`, `ought to`, `probably must`) are rejected at
compile time ([MER-DEO-003](#diagnostic-catalog)). Outcome words (`must not
fail`) are not actions — use `must not invoke …` or `<predicate> must hold`
instead ([MER-DEO-005](#diagnostic-catalog)).

---

## Scope attachment

Norms bind where they are authored:

- **Skill scope** — `This skill must not …` or a Contract-section sentence with
  no narrower qualifier.
- **Workflow scope** — workflow-prefixed forms (future tightening) or norms
  harvested from a named workflow's executable section.
- **Kind scope** — `A customer must not invoke …` binds the norm to instances of
  that kind.
- **Section scope** — `Within Phase 3, this skill must not …` (when supported
  by rulebook sugar).

Conflict analysis compares scopes using a containment lattice: skill ⊃ workflow
⊃ section; kind scopes interact only with matching kind subjects.

---

## Blocking routing

The `blocking` keyword on an obligation is the **only** way to make a violation
halt the enclosing section. Non-blocking obligations record the violation and
continue — the Contract section is the audit surface for which claims can stop
execution.

Lowering wires blocking obligations to `AssertIR.blocking` and attaches recover
handlers when authored. Prohibitions may also carry blocking disposition on the
guarded invoke arm.

---

## Conflict lattice (MER-DEO-001 / MER-DEO-002)

| Situation | Code | Behavior |
|---|---|---|
| Same-scope prohibition and permission overlap the same invoke pattern | [MER-DEO-001](#diagnostic-catalog) | **Compile-time error on both spans** — no silent winner |
| Inner `may` grant inside an outer `must not` prohibition | [MER-DEO-002](#diagnostic-catalog) | **Sticky deny** — inner permission cannot override outer prohibition |
| Non-overlapping scopes or patterns | — | Both norms lower; evaluation applies the most specific applicable norm |

Overlap is defined on normalized `toolID` plus argument constraints: identical
tool with empty or compatible `whose` clauses overlaps; conditioned permissions
narrow the pattern.

---

## Permissions generalize `scopedTools`

A bare tool id in `## Tools Used` or `scopedTools` is the degenerate permission
`may invoke <tool>` with no argument conditions. Wave 9 adds **argument-conditioned**
permissions:

```text
This skill may invoke slack.send only where the channel is one of "#incidents", "#alerts".
The briefing skill may invoke email.send only where the recipient is the user's own address.
```

`only where …` lowers to invoke guards evaluated **per attempt**. Table-conditioned
lookups in the permission predicate (Composition Gallery line 6) compose with
the same guard mechanism.

Mixing bare allow-list entries and conditioned `may` lines in one skill is legal:
each invoke is checked against the union of covering permissions.

Tool use outside the permission envelope in a judgment block is diagnosed as
[MER-DEO-004](#diagnostic-catalog) (reserved / partial enforcement in 9B).

---

## D12 witness envelopes

Runtime `recordViolation` emits `EventKind.violated` with operational detail
(`prevented` vs `observed`). Decision D12 reserves structured witness payloads
(tool id, argument hash, scope, norm id) for auditor-grade receipts.
Population of the full witness envelope in traces is Wave 9C work; compile-time
norm ids already carry the stable identity needed to correlate trace events with
norms.

---

## `meridian explain` and `[OBL-…]` annotations

`meridian explain` prints Canonical English for lowered norms and annotates each
with its norm id by default:

```text
[OBL-a1b2c3d4] This skill must not invoke deploy.run whose target is production.
```

Opt out with `--no-norm-ids`. The annotation links human-readable audit output
to the stable norm identity used by runtime trace events without recompilation.

---

## Argument-conditioned permission example

From the Composition Gallery (cookbook Part VII, line 6):

```text
This skill may invoke slack.send only where the channel is the channel
corresponding to the severity "sev2" in the escalation table.
```

The permission guard evaluates the table lookup on each `slack.send` attempt.
Tests: `CompositionGalleryTests.gallery6` (parse + verbalize round-trip).

---

## Worked prohibition + obligation (Release Sentinel)

Contract norms from the north-star example:

```text
This skill must not invoke deploy.run whose target is production.
The sentinel may invoke slack.send only where the channel is one of "#incidents", "#alerts", "#releases".
Since the last production deploy, no critical alert has occurred. This must hold, blocking.
```

Fixture: `Tests/MeridianCoreTests/Fixtures/Trace/release-sentinel-wave9.meri`.

---

## Diagnostic catalog

| Code | Trigger |
|---|---|
| MER-DEO-001 | Same-scope prohibition and permission overlap (both spans reported) |
| MER-DEO-002 | Inner `may` cannot override outer `must not` (sticky deny) |
| MER-DEO-003 | Non-norm modal (`should`, `ought to`, …) |
| MER-DEO-004 | Tool invoke outside permission scope |
| MER-DEO-005 | Outcome-as-action (`must not fail`) |
| MER-DEO-006 | Norm id prefix collision after semantic hash |

Broken Twin line 8 exercises MER-DEO-001; see
[`docs/cookbook/MERIDIAN_NORTHSTAR_EXAMPLE.md`](cookbook/MERIDIAN_NORTHSTAR_EXAMPLE.md) Part C and
`DeonticBrokenTwinTests` in `Tests/MeridianCoreTests/Inform7/`.

---

## Related documents

- [`docs/21_OUT_OF_SCOPE.md`](21_OUT_OF_SCOPE.md) — formal prover discharge boundary
- [`docs/19_TRACES_AND_TIME.md`](19_TRACES_AND_TIME.md) — trace-backed `since … must hold`
- [`docs/cookbook/MERIDIAN_SEMANTICS.md`](cookbook/MERIDIAN_SEMANTICS.md) §7–8 — normative oracle
- [`docs/07_CLI.md`](07_CLI.md) — `meridian explain` flags
