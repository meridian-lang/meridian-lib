# Final Wave Mechanical Closure Proof

Audit date: 2026-07-12 (UTC). Authority: Phase I mechanical closure gate.

This document records the commands, artifacts, and pass/fail results that
establish Final Wave traceability, zero-deferral, and mutation-gate proof.

## 1. Traceability checker

```bash
swift scripts/final-wave-traceability.swift
```

**Checks:**

- `docs/coverage/final-wave-requirements.json` has no `pending` / `deferred` / `partial` rows
- No duplicate matrix ids
- Every `implementationFiles` / `tests` / `docs` evidence path exists on disk
- Every `SEM-*` tag in `docs/cookbook/MERIDIAN_SEMANTICS.md` appears in the matrix,
  `COOK_EVIDENCE.md`, or `WAVE8_REQUIREMENTS.md`
- Every `COOK-*` tag in cookbook oracles appears in evidence corpora
- `DiagnosticCode.all` static inventory matches `DiagnosticCode.catalog` entry count (regex spot-check)

**Result (2026-07-12):** `final-wave-traceability: OK (34 matrix rows, 52 SEM tags, 0 COOK tags)`

Matrix evidence paths corrected during closure (stale paths in JSON):

| Row | Corrected path |
| --- | --- |
| FW-9A, SEM-7-04 | `Sources/MeridianCore/Lowering/DeonticLowering.swift` |
| SEM-7-03 | `Sources/MeridianCore/Lowering/RuleLowering.swift` |
| SEM-7-05, D12 | `Sources/MeridianRuntime/Trace/WitnessCapture.swift` |
| SEM-4-10 | `Sources/MeridianCore/Lowering/ASTToIR.swift` |
| SEM-2-13 | `Sources/MeridianRuntime/Trace/CalendarAmountEvaluator.swift` |
| SEM-4-11 | `Sources/MeridianRuntime/Trace/TraceStoreHelpers.swift` |
| FW-LLM | `HTTPLLMProvider.swift` + `DeterministicLLMProvider.swift` |

## 2. Forbidden-deferral scan

```bash
swift scripts/forbidden-deferral-scan.swift
```

**Scans:** `Sources/`, `Tests/`, `scripts/`, `docs/` (active tree).

**Patterns:** `\bTODO\b`, `\bFIXME\b`, `not implemented`, `later wave`, `deferred feature`,
`planned for later`, `not yet implemented`.

**Allowlist:** `docs/21_OUT_OF_SCOPE.md` categories; `docs/coverage/*` audit vocabulary;
documented internal-invariant false positives (exhaustive-switch lists, deferred-marker
parser plumbing, MER0003 catalog entry, domain `deferred` enum case, negative test greps).

**Result (2026-07-12):** `forbidden-deferral-scan: OK (no unallowlisted deferral promises)`

## 3. Mutation gate smoke

```bash
swift test --filter 'FinalWaveMutationGate|FinalWaveClosure'
```

**Suite:** `Tests/MeridianCoreTests/Inform7/FinalWaveMutationGateTests.swift`

Controlled mutations on test-only fixtures; each gate must fail when regressed:

| Gate | Mutation | Expected failure |
| --- | --- | --- |
| Verbalizer template | Empty `.logical(.and, [])` IR | `MER4002` / `invalidIR` |
| Authored form (D11) | Canonical `unless` must not become `if not` | Round-trip keyword preserved |
| Deontic coherence | Bare `invoked` without `prevented` witness | `CoherenceHarness` incoherent |
| Obligation id | `time.now` → `shell.run` norm edit | Stable id changes |
| Witness redaction | PII field in redacted envelope | `<redacted>` not plaintext |
| Wilson (SEM-6-04) | 10/20 vs 18/20 success count | Lower bound drops below 0.9 gate |
| Migration (P1 cat-4) | Operational Phases prose, `routeFuzzy: false` | `migrate()` `compiledOK == false` |
| Runtime redaction | `shell.run` with `capturePolicy: .redacted` | Command/output_summary redacted |

**Result (2026-07-12):** 11 tests passed (8 mutation + 3 closure conformance).

## 4. CI wiring

`.github/workflows/ci.yml` — **Final Wave mechanical closure** step:

```yaml
swift scripts/final-wave-traceability.swift
swift scripts/forbidden-deferral-scan.swift
swift test --filter 'FinalWaveMutationGate|FinalWaveClosure'
```

Runs after the focused Final Wave conformance filter and before the coverage gate.

## 5. Proof status

| Gate | Status | Evidence |
| --- | --- | --- |
| Matrix traceability | **PASS** | `swift scripts/final-wave-traceability.swift` |
| Zero-deferral scan | **PASS** | `swift scripts/forbidden-deferral-scan.swift` |
| Mutation gate smoke | **PASS** | `FinalWaveMutationGateTests` + `FinalWaveClosureTests` |
| Full `swift test` | **PASS** | 2560 tests / 320 suites (2026-07-12) |
| Coverage `--full --gate` | **PASS** | TOTAL ≈ 87.80% region; all floors met |
| CI wired | **PASS** | `.github/workflows/ci.yml` mechanical closure + coverage |
| Independent reviews | **PASS** | `docs/coverage/INDEPENDENT_CLOSURE_REVIEWS.md` |

**Residual:** none in-scope.

**Permanent out of scope:** formal prover discharge; localization (`docs/21_OUT_OF_SCOPE.md` §1–§2).
