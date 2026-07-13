# Final Wave Requirements Matrix

Phase I closure tracker for Meridian Final Wave (Waves 9A–9D, closure Phases E–H,
conformance Phase I). Updated 2026-07-12.

Status legend: `pending` | `done` | `partial` | `deferred` (only if re-promoted to
`docs/21_OUT_OF_SCOPE.md` by maintainer amendment).

Authority: primary normative source per row; machine-readable companion at
[`final-wave-requirements.json`](final-wave-requirements.json).

COOK/SEM harvest evidence: [`COOK_EVIDENCE.md`](COOK_EVIDENCE.md).

| ID | Category | Requirement | Authority | Status | Evidence |
| --- | --- | --- | --- | --- | --- |
| FW-9A | Deontic | Deontic surface with attempt-time prohibitions and effect-time obligations | `MERIDIAN_SEMANTICS.md` §7, Wave 9A | done | `DeonticInform7Tests.swift` |
| FW-9B | Deontic | Obligation artifacts: versioned JSON per skill | `MERIDIAN_SEMANTICS.md` §8.2 | done | `ObligationArtifactTests.swift`, `obligations` CLI |
| FW-9C | Coherence | Differential coherence harness (SEM-8-01) | `MERIDIAN_SEMANTICS.md` §8.1 | done | `CoherenceHarnessTests.swift` |
| FW-9D | Docs/corpus | `docs/20_DEONTIC.md`, corpus examples, expressiveness report | Wave 9D | done | `Wave9NorthStarFixtureTests.swift`, `docs/20_DEONTIC.md` |
| SEM-7-01 | Deontic | Trace compliance for prohibitions, obligations, permissions | §7.2 | done | `SEM_7_01` in `DeonticInform7Tests` |
| SEM-7-02 | Deontic | Violation timing: attempt-time / effect-time / prevented | §7.3, D3 | done | `SEM_7_02` in `DeonticInform7Tests` |
| SEM-7-03 | Deontic | Permissions generalize scopedTools | §7.4 | done | `SEM_7_03` in `DeonticInform7Tests` |
| SEM-7-04 | Deontic | Conflict lattice: same-scope error; sticky deny | §7.5 | done | `SEM_7_04`, `DeonticBrokenTwinTests` |
| SEM-7-05 | Deontic | Violation witnesses + D12 capture modes | §7.7, D12 | done | `PhaseGTraceInfrastructureTests` |
| SEM-8-01 | Coherence | Differential exec/proof agreement (no theorem) | §8.1, `21_OUT_OF_SCOPE.md` §1 | done | `CoherenceHarnessTests.swift` |
| SEM-8-02 | Coherence | Prover-ready obligation artifacts | §8.2 | done | `ObligationArtifactTests.swift` |
| D11 | Verbalization | `unless` and `if not` separately canonical with authored-form metadata | §8.3, §11 | done | `FinalWaveClosureTests` — suffix `unless` + branch `if not` round-trip |
| D12 | Trace/capture | hash-only / full / redacted capture modes | §4.8, §7.7 | done | `PhaseGTraceInfrastructureTests` |
| D4a | Trace scope | `across skills` + merconfig allow-list | §4.3, §11 | done | `TraceTemporalInform7Tests` SEM_4_10 |
| SEM-MOD-01 | Modules | Shared module imports | §10.1, `22_MODULES_AND_IMPORTS.md` | done | `ModuleSystemTests.swift` |
| SEM-MOD-02 | Modules | Explicit cross-skill coupling allow-list | §10.2 | done | `TraceTemporalInform7Tests` cross-skill gate |
| SEM-6-04 | Statistics | Wilson confidence intervals | §6.5 | done | `PhaseERuntimeTests`, `TraceTemporalInform7Tests` |
| SEM-4-12 | State history | Keyed state snapshots within ρ | §4.10 | done | `PhaseEFinalWaveTests` |
| SEM-5-13 | State history | State-predicate `since the last` via snapshots | §5.10 | done | `PhaseEFinalWaveTests` |
| SEM-4-10 | Trace scope | Cross-skill declared-list scopes | §4.3 | done | `TraceTemporalInform7Tests` |
| SEM-3-01 | Workflow | Commit checkpoint; typed recover; no auto rollback | §3.1 | done | `FinalWaveClosureTests`, `Phase5RecoverTests` |
| SEM-2-13 | Time | Calendar amounts vs physical duration; deployment TZ | §2.3.2 | done | `PhaseERuntimeTests`, `PhaseEFinalWaveTests` |
| SEM-4-11 | Trace/time | Hybrid ordering: at → ingest_order → id | §4.5 | done | `PhaseERuntimeTests` |
| SEM-5-12 | Temporal | Bounded future monitors (Contract/obligation) | §5.9 | done | `PhaseEFinalWaveTests`, `PhaseERuntimeTests` |
| FW-SQLITE | Infrastructure | SQLite trace store | Design Risks §3.4 | done | `PhaseGTraceInfrastructureTests` |
| FW-NET | Infrastructure | Networked trace store adapters | Final Wave | done | `PhaseGTraceInfrastructureTests` HTTP client |
| FW-OTLP | Observability | OpenTelemetry export adapter | Final Wave | done | `PhaseGTraceInfrastructureTests` |
| FW-SIGN | Security | Signed trace hash chains | Design Risks §4.3 | done | `PhaseGTraceInfrastructureTests` HMAC anchors |
| FW-LLM | Runtime | LLM provider surfaces | `12_PROSE_AND_AUTONOMY.md` | done | `PhaseHLLMProviderTests.swift` |
| FW-MCP | Runtime | MCP integration | `06_RUNTIME.md` | done | `PhaseHCLITests.swift`, `MeridianMCPSmokeTests.swift`, `MeridianMCP` product |
| FW-CI | Process | Final Wave conformance suites in CI | this matrix | done | `.github/workflows/ci.yml` |
| FW-CONF | Conformance | Every SEM tag has a named automated test | §9.1 | done | `FinalWaveSEM2FoundationTests`, `COOK_EVIDENCE.md` |
| FW-PROVER-ART | Artifacts | Prover-ready artifacts without discharge | `21_OUT_OF_SCOPE.md` §1 | done | `ObligationArtifactTests` + coherence harness |
| FW-ZERO | Audit | Zero-deferral audit vs `21_OUT_OF_SCOPE.md` | Phase 0 closure | done | only prover discharge + localization deferred |

## Phase I residuals

| Item | Status | Notes |
| --- | --- | --- |
| SEM-2-02 runtime `nothing` recover | done | `SEM202NothingRecoverRuntimeTests.swift` + `FinalWaveSEM2FoundationTests` compile projection |
| SEM-5-12 Contract-section context | done | assert-path + obligation monitors; advisory Contract-section lint only |
| Phase F module visibility | done | `exports: public\|internal` export-surface filtering in `ModuleSymbolSnapshot` |
