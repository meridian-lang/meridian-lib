# Zero-Deferral Audit (Final Wave closure)

Audit date: 2026-07-12 (UTC). Authority: `FW-ZERO` in
[`final-wave-requirements.json`](final-wave-requirements.json);
permanent boundary: [`docs/21_OUT_OF_SCOPE.md`](../21_OUT_OF_SCOPE.md).

## Command evidence

```bash
# Matrix: zero pending/deferred rows
rg '"(pending|deferred)"' docs/coverage/final-wave-requirements.json
# → (no matches)

# Sources: TODO/FIXME
rg -i 'TODO|FIXME' Sources/ --glob '*.swift' -c | rg -v ':0$'
# → Rulebook.swift:1  SkillTriggers.swift:1  (exhaustive-switch invariant notes)

# Tests: TODO/FIXME (excluding negative assertions)
rg -i 'TODO|FIXME' Tests/ --glob '*.swift' -c | rg -v ':0$'
# → VerbalizerTotalityTests.swift:2  InertYieldAnalyzerTests.swift:1  ValueCoercionTests.swift:1

# D11 closure
swift test --filter 'd11UnlessAndIfNotRoundTrip'
# → ✔ Test run passed (2026-07-12)
```

## Matrix status

| Status | Count |
| --- | ---: |
| `done` | 35 |
| `partial` | 0 |
| `pending` | 0 |
| `deferred` | 0 |

One documented **non-matrix** partial: none (SEM-2-02 runtime fixture closed 2026-07-12).

## Classification summary

| Category | Count | Meaning |
| --- | ---: | --- |
| **(a) Implemented / fixed this audit** | 4 | D11 authored-form metadata; stale diagnostic copy; MCP/LLM docs |
| **(b) Tested deliberate rejection** | 8 | MER-STA-002 deprecated; MER-TMP-019/021 stable errors; iteration table reserved; llm fail-closed; etc. |
| **(c) Out of scope per `21_OUT_OF_SCOPE.md`** | 2 | Prover discharge; localization |
| **(d) Internal invariant / non-user-facing** | 18+ | Exhaustive-switch TODO lists; parser deferred-marker plumbing; domain `deferred` verdict enum; placeholder bind policy; etc. |

## Residual register (every non-(d) hit)

### (a) Implemented or docs-fixed

| ID / location | Action |
| --- | --- |
| **D11** | `BranchAuthoredForm` on `BranchIR`; parser for suffix `unless`, branch `if not`, `unless` headers; verbalizer preserves authored keyword; `ObligationIdStamper` preserves metadata. Tests: `FinalWaveClosureTests.d11UnlessAndIfNotRoundTrip`. |
| `MER-TMP-019` explanation | Removed stale “state history deferred” wording; aligns with SEM-4-12/SEM-5-13. |
| `MER-TMP-021` explanation | Points to D4a declared-list + allow-list instead of “cross-skill deferred”. |
| `ToolRegistry.swift` MCP comment | Updated — `dispatchMCP` is implemented. |
| `docs/10_BUILTIN_TOOLS.md` `llm.chat` | Updated — provider-backed, fail-closed when unconfigured. |
| `docs/18_VERBALIZER.md` | Removed stale “deontic planned for later waves”. |

### (b) Tested deliberate rejection / stable surface

| Location | Notes |
| --- | --- |
| `MER0003` | Deprecated catalog entry; no production emitter (`DiagnosticCodeCatalogTests`). |
| `MER-STA-002` `statisticalConfidenceReserved` | Deprecated; Wilson SEM-6-04 shipped (`PhaseERuntimeTests`). |
| `MER-TMP-019` / `MER-TMP-021` | Compile-time structural errors with tests in `TraceTemporalInform7Tests` / broken twins. |
| `TableParser` iteration mode | Accepted marker, zero statements (`docs/03_LANGUAGE_QUICK_REFERENCE.md`). |
| `llm.chat` without provider | Runtime `llm.not_configured` (`PhaseHLLMProviderTests`). |
| `IRTypes` judgment `producing` clause | Compile-time `judgmentWithoutProducedValue` when effectful cue lacks production binding. |

### (c) `21_OUT_OF_SCOPE.md` only

| Item | Section |
| --- | --- |
| Formal prover discharge / machine-checked coherence theorem | §1 |
| Localization / alternate canonical natural languages | §2 |

### (d) Internal / non-user-facing (no action)

| Pattern | Examples |
| --- | --- |
| Exhaustive-switch maintenance lists | `Rulebook.swift`, `SkillTriggers.swift` “TODO list” comments |
| Parser deferred-marker transport | `IndentTokenizer`, `StatementParser` (deferred *error*, not feature deferral) |
| Domain enum case `deferred` | `ApprovalVerdict` vocabulary — not a feature backlog |
| `_unresolved` / recover placeholder | `FallbackPolicy`, `recoverPlaceholder` — documented codegen/parser mechanics |
| `ObligationDischargePlaceholder` | Prover-ready artifact schema (`status: unknown`) — in scope per SEM-8-02 |
| `VerbalizerTotalityTests` | Negative grep for TODO/FIXME/placeholder in verbalizer sources |
| `Package.swift` MeridianMCP | Shipped executable product + `meridian mcp serve`; no future-target note |

## Remaining issues

1. **Permanent out of scope:** prover discharge and localization only.

No v0.2 deferred-ledger item remains unimplemented outside `21_OUT_OF_SCOPE.md` §1–§2.
