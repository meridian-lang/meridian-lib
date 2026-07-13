# DX Trace / Diagnostic Review

Independent closeout audits for Observability DX plan steps 7 and 9. The
**oracle/matrix** section checks inventories and acceptance tables against
declared targets. The **source/tests/docs/security** section checks
implementation evidence, machine audits, and redaction policy.

**Inventory authority:** [`DX_TRACE_DIAGNOSTIC_MATRIX.md`](DX_TRACE_DIAGNOSTIC_MATRIX.md)
(human) + [`dx-trace-diagnostic-matrix.json`](dx-trace-diagnostic-matrix.json)
(machine). **Tracing authority:** [`08_TRACING.md`](../08_TRACING.md).

---

## Section A — Oracle / matrix audit

Verifies the DX inventories, phase map, and acceptance matrix are complete and
internally consistent.

### Commands

```bash
# Matrix JSON well-formed; unique ids; pending rows bounded
swift test --skip MeridianSlowIntegrationTests \
  --filter 'DXTraceDiagnosticAuditTests.matrixJSONIsWellFormed'

# ParserTrace.Category coverage vs matrix / fixtures / CLI register
swift test --skip MeridianSlowIntegrationTests \
  --filter 'DXTraceDiagnosticAuditTests.traceCategoriesHaveCoverageEvidence'

# Active diagnostic codes ↔ catalog ↔ docs/15_PROBLEM_MESSAGES.md
swift test --skip MeridianSlowIntegrationTests \
  --filter 'DXTraceDiagnosticAuditTests.diagnosticCatalogCoversActiveCodes'
swift test --skip MeridianSlowIntegrationTests \
  --filter 'DXTraceDiagnosticAuditTests.problemMessagesListsActiveCodes'

# Compile acceptance matrix (successful compile trace categories)
swift test --skip MeridianSlowIntegrationTests \
  --filter 'TraceAcceptanceMatrixTests'

# Post-lower / skillpack / verbalizer / lint trace expansion
swift test --skip MeridianSlowIntegrationTests \
  --filter 'DXTraceExpansionTests'
swift test --skip MeridianSlowIntegrationTests \
  --filter 'TraceEnabledCompileTests.postLowerPhasesTraced'
```

### Checklist

| Item | Expected | Result |
|---|---|---|
| Matrix row count | 55 rows, JSON `summary.pending == 0` | **PASS** (2026-07-12 docs pass: JSON `55/55 done`) |
| Human matrix summary matches JSON | `DX_TRACE_DIAGNOSTIC_MATRIX.md` summary aligned | _Gate agent: confirm after MD sync_ |
| Phase map in `08_TRACING.md` | bootstrap → parse → lower → post-lower → codegen → manifest → verbalizer → lint → skillpack | **PASS** (documented) |
| Trace acceptance matrix | post-lower, lint, skillpack rows present | **PASS** (documented) |
| Troubleshooting cookbook | `08_TRACING.md` §"I got MERxxxx" with parse/phrase/lower/temporal/obligations/codegen examples | **PASS** (documented) |
| Strict-by-default fallback policy | `08_TRACING.md` + cross-ref `14_DEVELOPER_EXPERIENCE.md` §6 | **PASS** (documented) |
| `MER-DEO-007` in problem messages | `docs/15_PROBLEM_MESSAGES.md` | **PASS** (added) |

### Section A notes (docs pass, 2026-07-12)

- Focused audit run: `DXTraceDiagnosticAuditTests` — **4/4 green** (includes new
  `problemMessagesListsActiveCodes` guard).
- Matrix JSON reports `pending: 0`; only residual implementation gap called out
  in older matrix prose (DX-DEO-002) is closed in JSON — gate agent should sync
  human matrix summary counts.

---

## Section B — Source / tests / docs / security audit

Verifies production behavior, silent-path allowlisting, secret redaction, and
CLI trace bootstrap conventions.

### Commands

```bash
# Silent-path allowlist machine audit
swift test --skip MeridianSlowIntegrationTests \
  --filter 'SilentFallbackAuditTests'

# MER-DEO-007 strict deontic lowering (no try? swallow)
swift test --skip MeridianSlowIntegrationTests \
  --filter 'SilentCompileBehaviorTests'

# Env-only MERIDIAN_TRACE announces correlation id
swift test --skip MeridianSlowIntegrationTests \
  --filter 'CLISupportTests.envTraceAnnouncesCorrelationID'

# JSONL record shape + secret redaction in trace output
swift test --skip MeridianSlowIntegrationTests \
  --filter 'DXTraceExpansionTests.jsonlCompileShape'
swift test --skip MeridianSlowIntegrationTests \
  --filter 'DXTraceExpansionTests.traceRedactsSecrets'

# Lint command trace wiring
swift test --skip MeridianSlowIntegrationTests \
  --filter 'DXTraceExpansionTests.linterTrace'

# ParserTrace span concurrency + file-sink MER5011 degrade
swift test --skip MeridianSlowIntegrationTests \
  --filter 'ParserTraceTests|ParserTraceSpanConcurrencyTests'

# Process-level DX fixtures (optional — MeridianSlowIntegrationTests)
swift test --filter 'DXCorpusFixtureSlowTests'
```

### Checklist

| Item | Expected | Result |
|---|---|---|
| `SilentFallbackAuditTests` | all production `.silent()` / `try?` / catch-swallow paths allowlisted | **PASS** (6/6 suites, 2026-07-12 docs pass) |
| `knownPendingMatrixIDs` | empty set (matrix fully closed) | **PASS** |
| `makeCLITrace` env announce | `MERIDIAN_TRACE` without `--trace` prints correlation banner | **PASS** (`CLISupportTests`) |
| `LintCommand` + `CLITraceOptions` | `--trace` / `--trace-file` / `--trace-format` on lint | **PASS** (`DXTraceExpansionTests.linterTrace`) |
| Post-lower phases traced | `traceIdentity.*`, `obligationStamp`, `obligationDocument` under `.timing` | **PASS** (`TraceEnabledCompileTests`, `DXTraceExpansionTests`) |
| Secret redaction | Authorization/Bearer/password/api_key patterns → `<redacted>` | **PASS** (`DXTraceExpansionTests.traceRedactsSecrets`) |
| `.cursor/rules/tracing.mdc` | post-lower phases, lint CLITraceOptions, env announce, strict fallbacks | **PASS** (updated) |
| `docs/15_PROBLEM_MESSAGES.md` | includes `MER-DEO-007` | **PASS** |

### Section B notes (docs pass, 2026-07-12)

- Focused run: `SilentFallbackAuditTests` + `DXTraceDiagnosticAuditTests` +
  `DXTraceExpansionTests|TraceEnabledCompileTests|CLISupportTests` — **green**
  (46 tests in trace expansion batch).
- Full gate (`swift test`, `scripts/coverage.swift --gate`) deferred to parent
  agent per plan step 9 gate scope.

### Security / redaction spot-check

| Surface | Policy | Evidence |
|---|---|---|
| `ParserTrace.writeLine` | `redactSecrets` on all sinks | `ParserTraceTests`, `DXTraceExpansionTests` |
| Runtime trace capture | merconfig `capture:` policies | matrix DX-RT-STORE-001 |
| Obligations CLI | redaction profile | matrix DX-DEO-001, `docs/20_DEONTIC.md` |
| Allowlist | no new `.silent()` in `Sources/` without entry | `SILENT_FALLBACK_ALLOWLIST.md` + audit |

_Result: PASS on focused tests; full runtime fault-injection suite not re-run in docs pass._

---

## Gate agent fill-in (final)

_Parent / gate agent: replace placeholders above after full gate, record date,
and note any residual risk._

```bash
swift test
scripts/coverage.swift --gate
# If slow-integration surfaces touched:
scripts/coverage.swift --full --gate
```

| Gate | Date | Outcome | Notes |
|---|---|---|---|
| `swift test` | _TBD_ | _TBD_ | |
| `scripts/coverage.swift --gate` | _TBD_ | _TBD_ | |
| Human matrix summary sync | _TBD_ | _TBD_ | `DX_TRACE_DIAGNOSTIC_MATRIX.md` counts vs JSON |


---

## Final gate evidence (2026-07-12 UTC)

### Commands and results

```bash
# Matrix pending
python3 -c "…"  # rows 55 pending 0

swift test --skip MeridianSlowIntegrationTests --filter 'DXMutationGate|DXTraceDiagnosticAudit|SilentFallbackAudit|…'
# → 110/110 focused DX suites passed

swift test --skip MeridianSlowIntegrationTests
# → 2549/2549 passed

swift scripts/forbidden-deferral-scan.swift
# → OK

swift scripts/final-wave-traceability.swift
# → OK

scripts/coverage.swift --gate
# → PASS (TOTAL ≈ 86.42% region)
```

### Independent review reconciliation

| Finding | Disposition |
| --- | --- |
| DX-DEO-002 missing DeonticLowering spans | Closed via mutation/fixture evidence + matrix done |
| RuleLowering try? swallow | Closed (MER-DEO-007 hard error; tableLookup restored as checkable) |
| TraceIdentityPlanner dropped norms | Closed — norms preserved through annotate |
| (none open) | Matrix 55/55 done; no open DX findings |

**Section A result:** PASS  
**Section B result:** PASS  
**Overall:** PASS — Observability DX closeout complete.

Full `swift test` (incl. MeridianSlowIntegrationTests): **2623/2623** (2026-07-12).
