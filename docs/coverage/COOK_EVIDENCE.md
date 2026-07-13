# Cookbook (COOK / SEM) evidence matrix

Harvest of `docs/cookbook/` conformance tags mapped to automated tests or
documented evidence paths. Status: `covered` | `partial` | `out-of-scope`.

Authority: `docs/cookbook/MERIDIAN_SYNTAX_COOKBOOK.md` (COOK-* naming),
`docs/cookbook/MERIDIAN_SEMANTICS.md` (SEM-* naming).

## COOK canonical round-trips (`VerbalizerCookbookTests`)

| Tag / section | Cookbook source | Test | Status |
|---|---|---|---|
| COOK-comparison | Part I §3 comparators | `COOK-comparison canonical form round trips` | covered |
| COOK-04 | Part I §4 boolean | `COOK-04 boolean canonical form round trips` | covered |
| COOK-definition | Part I §5 definitions | `COOK-definition canonical form round trips` | covered |
| COOK-quantifier | Part I §6 quantifiers | `COOK-quantifier canonical form round trips` | covered |
| COOK-wait | Part III wait | `COOK-wait canonical form round trips` | covered |
| COOK-recover | Part III recover | `COOK-recover canonical form round trips` | covered |
| COOK-13 | Part III branch / unknown arm | `COOK-13 branch` + `COOK-13 unknown-arm` | covered |
| COOK-let-bind | Part III bind | `COOK-let-bind canonical form round trips` | covered |
| COOK-14 | compound note | `COOK-14 compound note` + `CompoundNoteTests` | covered |
| COOK-description | descriptions | `COOK-description canonical form round trips` | covered |
| COOK-template | templates | `COOK-template canonical form round trips` | covered |
| COOK-assert-otherwise | assert otherwise | `COOK-assert-otherwise canonical form round trips` | covered |
| COOK-wait-approval | wait approval | `COOK-wait-approval canonical form round trips` | covered |
| COOK-wait-event-matching | wait event | `COOK-wait-event-matching canonical form round trips` | covered |
| COOK-choice-gate | choice gate | `COOK-choice-gate canonical form round trips` | covered |
| COOK-background-shortcut | background | `COOK-background-shortcut canonical form round trips` | covered |
| COOK-18 | temporal operators | `COOK-18 ever/within/count/in-a-row/since` suite | covered |
| COOK-19 | keyed temporal adjective | `COOK-19 keyed temporal adjective` | covered |
| COOK-STAT | statistical forms | `COOK-STAT statistical canonical form round trips` | covered |
| COOK-northstar | north-star gallery | `COOK-northstar-definition-and-judgment` | covered |
| COOK-20 | progressive aspect | `COOK-20 progressive aspect reports MER-TMP-018` | covered |

## SEM foundation tags (MERIDIAN_SEMANTICS §2)

| Tag | Meaning | Primary test | Status |
|---|---|---|---|
| SEM-2-01 | single-fetch rule | `SEM_2_01 tool-backed quantifier hoists a single fetch invoke` | covered |
| SEM-2-02 | property projection / no default through nothing | `SEM_2_02 property access lowers to member projection` + `SEM202NothingRecoverRuntimeTests` | covered |
| D11 | unless vs if-not authored form | `D11 unless and if not round-trip with authored-form metadata` | done |
| SEM-2-03 | exact decimal arithmetic | `SEM_2_03 decimal literals lower through exact Decimal arithmetic` | covered |
| SEM-2-04 | boolean precedence / mixed and-or ill-formed | `SEM_2_04 mixed and/or without grouping is ill-formed` | covered |
| SEM-2-05 | acyclic definitions | `SEM_2_05 recursive definition is a hard error` | covered |
| SEM-2-06 | inheritance / shadowing | `SEM_2_06 subkind inherits parent adjective definitions` | covered |
| SEM-2-07 | backed relations | `SEM_2_07 unbacked relation is ill-formed at compile time` | covered |
| SEM-2-08..12 | Wave 8 temporal/K3/duration | `WAVE8_REQUIREMENTS.md` / `Inform7WaveTests` | covered |
| SEM-2-13 | calendar amounts | `PhaseERuntimeTests` / `PhaseEFinalWaveTests` | covered |

## Wave 9 / Final Wave deontic & coherence

| Tag | Primary test suite | Status |
|---|---|---|
| SEM-7-01..05 | `DeonticInform7Tests.swift` | covered |
| SEM-8-01 | `CoherenceHarnessTests.swift` | covered |
| SEM-8-02 | `ObligationArtifactTests.swift` | covered |
| SEM-8-03 | `VerbalizerRoundTripTests` / `VerbalizerEndToEndTests` | covered |

## Out of scope (not COOK/SEM gaps)

| Item | Reason |
|---|---|
| Formal prover discharge | `docs/21_OUT_OF_SCOPE.md` §1 |
| Localization / alternate canonical languages | `docs/21_OUT_OF_SCOPE.md` §2 |

## Residuals

None for COOK/SEM matrix tags. Permanent out-of-scope items remain in the table above.
