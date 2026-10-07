# DX Trace / Diagnostic Matrix

Inventory date: 2026-07-12 (UTC). Machine-readable companion:
[`dx-trace-diagnostic-matrix.json`](dx-trace-diagnostic-matrix.json).

This matrix records, per compiler/runtime surface, how **ParserTrace** categories,
**diagnostic families**, **fallback policy**, **suggestion behavior**, and
**redaction** align today. Status `pending` marks a known gap that is not yet
closed; everything else reflects current `Sources/` reality.

## Summary

| Status | Count |
| --- | ---: |
| `done` | 54 |
| `pending` | 0 |
| **Total rows** | **54** |

All matrix rows are `done` as of 2026-07-12 (machine JSON:
`dx-trace-diagnostic-matrix.json` `summary.pending == 0`). Residual follow-up
for dedicated `DeonticLowering` trace spans (formerly DX-DEO-002) is closed in
source/tests; see matrix row DX-DEO-002.

### Key files (reference)

| File | Why |
| --- | --- |
| `Tests/MeridianCoreTests/SilentFallbackAuditTests.swift` | Machine audit for allowlisted silent paths (`.silent()`, `try?`, catch swallows, `_unresolved`) |
| `Sources/MeridianCore/Lowering/DeonticLowering.swift` | Deontic IR application without dedicated trace spans (DX-DEO-002) |
| `Sources/MeridianCore/Lowering/ASTToIR.swift:validateDefinitionProperties` | Strict `MER2004` among declared kind properties (DX-LOWER-002) |
| `Sources/MeridianCore/Diagnostics/MeridianLinter.swift` | Lint-only anaphora heuristic + no trace (DX-LINT-002/003) |
| `Sources/MeridianCore/Compiler.swift:compileWithManifest` | Post-lower `TraceIdentityPlanner` / `NormIdStamper` traced via `annotateTraceIdentity` (DX-TRACEID-002, DX-OBL-003 done) |

---

## Parser / tokenizer

| ID | Phase | Code path(s) | ParserTrace | Diagnostic family | Fallback | Suggestions | Redaction | Tests | Status |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| DX-TOK-001 | parse | `IndentTokenizer.swift` | `tokenize` | MER1011 | none | structural help | trace secrets redacted | SentenceBreakerTests, ParserTraceTests | done |
| DX-TOK-002 | parse | `SentenceBreaker.swift` | `tokenize` | — | none | none | trace secrets redacted | SentenceBreakerTests | done |
| DX-PARSE-001 | parse | `MeridianParser.swift` | `parse` | MER1xxx | none | structural help | trace secrets redacted | Phase3ForcingFunction | done |
| DX-PARSE-002 | parse | `SkillSectionBuilder.swift` | `parse`, `skill` | MER1009, MER1010 | none | role guidance | trace secrets redacted | SkillSectionBuilderTests | done |

## Merconfig / rulebook / modules

| ID | Phase | Code path(s) | ParserTrace | Diagnostic family | Fallback | Suggestions | Redaction | Tests | Status |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| DX-MERCFG-001 | bootstrap | `MerConfigParser.swift` | `merconfig` | MER5xxx, MER-TMP-020 | none | among section/property names | trace secrets redacted | MerConfigParserTests | done |
| DX-RULEBK-001 | bootstrap | `RulebookParser.swift` | `rulebook` | MER5003, MER5004 | none | structural help | trace secrets redacted | RulebookParserTests | done |
| DX-MOD-001 | bootstrap | `ModuleResolver.swift` | `symbols` | MER-MOD | none | among module names | trace secrets redacted | ModuleResolverTests | done |

## Symbols / phrase matching

| ID | Phase | Code path(s) | ParserTrace | Diagnostic family | Fallback | Suggestions | Redaction | Tests | Status |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| DX-SYM-001 | bootstrap | `SymbolTable.swift` | `symbols` | MER2xxx | opt-in `unknown-tools` | Suggester among candidates | trace secrets redacted | SymbolTableTests, TraceAcceptanceMatrixTests | done |
| DX-SYM-002 | parse | `SymbolTable.swift`, phrase parsers | `phrase.*` | MER3001, MER2001 | opt-in `unresolved-phrases` | among phrase patterns | trace secrets redacted | PhrasePatternTests | done |

## Expression productions

| ID | Phase | Code path(s) | ParserTrace | Diagnostic family | Fallback | Suggestions | Redaction | Tests | Status |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| DX-EXPR-001 | parse | `ExpressionParser.swift`, `PegexSurfaceGrammar.swift`, `NonterminalScreen.swift` | `expression` | MER1005, MER3012, MER3013 | none | malformed help | trace secrets redacted | ExpressionParserGoldenTests, NonterminalScreeningTests | done |
| DX-EXPR-TMP | parse | `TraceTemporalGrammar.swift`, `TraceEventPatternGrammar.swift` | `expression` | MER-TMP | none | structural help | trace secrets redacted | TraceTemporalInform7Tests | done |
| DX-EXPR-STA | parse | `TraceStatisticalGrammar.swift` | `expression` | MER-STA, MER-TMP | none | structural help | trace secrets redacted | TraceStatisticalInform7Tests | done |
| DX-EXPR-DSC | parse | `DescriptionGrammar.swift`, `SuperlativeGrammar.swift`, `QuantifierGrammar.swift` | `expression` | MER-DSC, MER3013 | none | among properties/relations | trace secrets redacted | Inform7Wave3/4Tests | done |

## Statement parsing

| ID | Phase | Code path(s) | ParserTrace | Diagnostic family | Fallback | Suggestions | Redaction | Tests | Status |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| DX-STMT-001 | parse | `StatementParser.swift` | `statement` | MER1002–1011, MER-JDG, MER-CND | none | Diagnostic.problem templates | trace secrets redacted | StatementParserTests | done |
| DX-STMT-002 | parse | `StatementParser.swift:parseMatchBranch` | `statement` | MER1012, MER3018 | none | Suggester + colon rewrite | trace secrets redacted | DXCorpusFixtureSlowTests | done |
| DX-STMT-003 | parse | `StatementParser.swift:parseRecover` | `statement` | MER1003 | none | structural help + colon rewrite | trace secrets redacted | StatementParserCoverageTests | done |
| DX-STMT-004 | parse | `StatementParser.swift`, `DiagnosticEngine.swift` | `statement`, `diagnostics` | MER6004 | batch `recovering` | recovery summary note | trace secrets redacted | DXCorpusFixtureSlowTests, ObservabilityFaultInjectionTests | done |
| DX-STMT-005 | parse | `AnaphoraResolver.swift` | `statement` | MER3014 | none | spell-out help | trace secrets redacted | AnaphoraResolverTests | done |

## Rule lowering

| ID | Phase | Code path(s) | ParserTrace | Diagnostic family | Fallback | Suggestions | Redaction | Tests | Status |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| DX-RULE-001 | lower | `RuleLowering.swift`, `RuleAnalyzer.swift` | `lowering` | MER1004, MER-DEO | opt-in `unparseable-rules` | structural help | trace secrets redacted | RuleLoweringTests | done |
| DX-RULE-002 | lower | `RuleInjector.swift` | `lowering` | MER3006, MER3007, MER3019–3020 | opt-in unattached/trigger | among actions/formatters | trace secrets redacted | RuleInjectorTests | done |
| DX-RULE-003 | lower | `RuleLowering.swift` deontic classifiers | `lowering` | MER-DEO-007 | none | structural help on unsupported conditions | trace secrets redacted | SilentCompileBehaviorTests | done |

## AST lowering / deontic lowering

| ID | Phase | Code path(s) | ParserTrace | Diagnostic family | Fallback | Suggestions | Redaction | Tests | Status |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| DX-LOWER-001 | lower | `ASTToIR.swift` | `lowering` | MER2xxx, MER3xxx, MER-REF, MER-TYP | opt-in `unresolved-phrases` | Suggester among candidates | trace secrets redacted | Phase3ForcingFunction, ASTToIRTests | done |
| DX-LOWER-002 | lower | `ASTToIR.swift:validateDefinitionProperties` | `lowering` | MER2004 | strict | among declared properties | trace secrets redacted | DefinitionLoweringTests | done |
| DX-LOWER-003 | lower | `FallbackPolicy.swift`, `ASTToIR.swift` | `lowering`, `diagnostics` | MER2xxx, MER3xxx | opt-in per `FallbackKind` | warning names opt-in to remove | trace secrets redacted | ObservabilityFaultInjectionTests | done |
| DX-DEO-001 | lower | `DeonticLowering.swift` | `lowering` | MER-DEO | strict | structural help | trace secrets redacted | DeonticInform7Tests | done |
| DX-DEO-002 | lower | `DeonticLowering.swift` | `lowering` | MER-DEO | strict | structural help on conflicts / sticky deny / tool outside permissions | trace secrets redacted | DeonticInform7Tests, DXMutationGateTests | done |

## Norm identity / trace identity / validation

| ID | Phase | Code path(s) | ParserTrace | Diagnostic family | Fallback | Suggestions | Redaction | Tests | Status |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| DX-OBL-002 | post-lower | `IR/NormIdentity.swift:NormIdStamper` | — | MER-DEO-006 | strict | n/a | n/a | DeonticInform7Tests | done |
| DX-OBL-003 | post-lower | `NormIdStamper`, `Compiler.annotateTraceIdentity` | `timing`, `codegen` | — | none | n/a | n/a | DXTraceExpansionTests, TraceEnabledCompileTests | done |
| DX-TRACEID-001 | post-lower | `TraceIdentityPlanner.swift` | — | MER-TMP-020 | strict | structural help | n/a | TraceIdentityPlannerTests | done |
| DX-TRACEID-002 | post-lower | `TraceIdentityPlanner.annotate`, `Compiler.compileWithManifest` | `timing`, `codegen` | — | none | n/a | n/a | DXTraceExpansionTests, TraceEnabledCompileTests | done |
| DX-VAL-001 | validation | `IRValidator.swift` | `validation` | MER4002, MER3018 | none | help + `phase: validation` | trace secrets redacted | IRValidatorTests, ObservabilityFaultInjectionTests | done |

## Codegen / manifest / sidecar

| ID | Phase | Code path(s) | ParserTrace | Diagnostic family | Fallback | Suggestions | Redaction | Tests | Status |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| DX-CG-001 | codegen | `SwiftEmitter.swift` | `codegen`, `validation` | MER4002, MER-TMP-019 | none | IR validation help | trace secrets redacted | SwiftEmitterTests, GeneratedSwiftTypecheckSlowTests | done |
| DX-CG-002 | codegen | `DomainEmitter.swift` | `codegen` | MER-DOM | none | n/a | trace secrets redacted | DomainEmitterTests | done |
| DX-CG-003 | codegen | `IRSidecarEmitter.swift` | `codegen`, `timing` | — | none | n/a | trace secrets redacted | DXTraceExpansionTests, IRSidecarTests | done |
| DX-MAN-001 | manifest | `ManifestEmitter.swift` | `codegen` | — | none | n/a | trace secrets redacted | ManifestEmitterTests | done |
| DX-MAN-002 | manifest | `Compiler.compileWithManifest` | `codegen` | — | none | n/a | trace secrets redacted | CompileWithManifestTests | done |

## Verbalizer / linter

| ID | Phase | Code path(s) | ParserTrace | Diagnostic family | Fallback | Suggestions | Redaction | Tests | Status |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| DX-VERB-001 | verbalizer | `Verbalizer.swift`, `CanonicalForms.swift` | `verbalizer`, `validation` | MER5010, MER4002 | none | n/a | trace secrets redacted | VerbalizerTotalityTests | done |
| DX-VERB-002 | verbalizer | `DriftEngine.swift` | `drift` | — | none | n/a | trace secrets redacted | DriftEngineTests | done |
| DX-LINT-001 | lint | `MeridianLinter.swift` | — | MER6001–6003, MER6005 | none | marker-scoped help | authored source text | DXCorpusFixtureSlowTests | done |
| DX-LINT-002 | lint | `MeridianLinter.swift`, `AnaphoraResolver.swift` | — | MER3014 | none | spell-out help; lint heuristic + resolver null-check | authored source text | DXCorpusFixtureSlowTests | done |
| DX-LINT-003 | lint | `MeridianLinter.swift`, `LintCommand.swift` | `diagnostics`, `tokenize` | MER6xxx | none | n/a | trace secrets redacted | DXTraceExpansionTests, MeridianLinterTests | done |

## CLI commands

| ID | Phase | Code path(s) | ParserTrace | Diagnostic family | Fallback | Suggestions | Redaction | Tests | Status |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| DX-CLI-001 | cli | `CLISupport.swift`, compile/check/verify/run | `timing`, `diagnostics` | MER5011–5014, MER2010 | none | among trace categories | trace secrets redacted | TraceAcceptanceMatrixTests | done |
| DX-CLI-002 | cli | explain / explain-diag / decisions | `verbalizer`, `diagnostics` | catalog-wide | none | catalog + DecisionCatalog | trace secrets redacted | VerbalizerCLIE2ETests, DiagnosticCodeCatalogTests | done |
| DX-CLI-003 | cli | trace render/eval/verify/drift | — | — | none | n/a | capture-time policies | TraceEvalCLITests, TraceTreeRendererTests | done |
| DX-CLI-004 | cli | migrate-skill / preview-skill / skill-deviation | `skill`, `parse`, `lowering` | MER6003, MER2xxx, MER3xxx | opt-in `route-fuzzy` | compiler codes on hard error | trace secrets redacted | SkillMigratorMarkingTests | done |

## Runtime stores / host tools / replay

| ID | Phase | Code path(s) | ParserTrace | Diagnostic family | Fallback | Suggestions | Redaction | Tests | Status |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| DX-RT-STORE-001 | runtime | `TraceStore.swift` + implementations | — | — | failClosed default | n/a | capture policy + ShellHoleRedaction | TraceStoreTests, RuntimeObservabilityFaultInjectionTests | done |
| DX-RT-STORE-002 | runtime | `Runtime.swift`, `State.swift` | — | runtime.operational | none | n/a | tool payload policies + RuntimeSecretRedaction | RuntimeTests, ObserverTests, ObservabilityRuntimeCoverageTests, RuntimeObservabilityFaultInjectionTests | done |
| DX-RT-TOOL-001 | runtime | `ToolRegistry.swift`, `MeridianTools.swift` | — | — | opt-in unknown-tools compile | n/a | auth header redaction | ToolRegistryTests | done |
| DX-RT-TOOL-002 | runtime | `LLMTools.swift`, `HTTPLLMProvider.swift` | — | — | fail-closed `llm.not_configured` | n/a | API keys not echoed | PhaseHLLMProviderTests | done |
| DX-RT-EVAL-001 | runtime | `TraceEvaluator.swift` | — | — | none | n/a | reads stored records | TraceEvaluatorTests, CoherenceHarnessTests | done |
| DX-RT-EVAL-002 | runtime | `TraceTreeRenderer.swift`, `TraceRenderCommand.swift` | — | — | none | n/a | display-only | TraceTreeRendererTests | done |

## Cross-cutting

| ID | Phase | Code path(s) | ParserTrace | Diagnostic family | Fallback | Suggestions | Redaction | Tests | Status |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| DX-X-001 | cross-cutting | `DiagnosticEngine.swift`, `Diagnostic.swift`, `Suggester.swift` | `diagnostics` | all active | MER6004 recovery summary | did-you-mean / candidate list | trace mirror redacts secrets | DiagnosticTests, DiagnosticQualityAuditTests | done |
| DX-X-002 | cross-cutting | `SILENT_FALLBACK_ALLOWLIST.md` | — | — | allowlisted opt-in only | n/a | n/a | SilentFallbackAuditTests | done |
| DX-X-003 | cross-cutting | `ParserTrace.swift` | all categories | MER2010 | none | among categories | Authorization/Bearer/password/api_key redact | ParserTraceTests, ParserTraceSpanConcurrencyTests | done |

---

## Conventions

- **Phase** — pipeline stage: `bootstrap`, `parse`, `lower`, `post-lower`, `validation`, `codegen`, `manifest`, `verbalizer`, `lint`, `cli`, `runtime`, `cross-cutting`.
- **Fallback** — `strict` (default), `opt-in` (frontmatter `allow-fallbacks:` / CLI policy), or `none`.
- **Suggestions** — `Suggester` did-you-mean within edit budget; otherwise candidate-list `DiagnosticNote`; structural codes carry non-empty `help`.
- **Redaction** — compile-time `ParserTrace` redacts auth/bearer/password/api-key patterns; runtime trace uses merconfig `capture:` policies (`full` / `hash-only` / `redacted(fields)`).

Authority for acceptance gates: `TraceAcceptanceMatrixTests` (successful compile must show `symbols`, `merconfig`, `parse`/`statement`, `lowering`, `codegen`; failures must show `diagnostics`).

## Trace category coverage register

Machine-checked by `DXTraceDiagnosticAuditTests.traceCategoriesHaveCoverageEvidence`.
Each `ParserTrace.Category` must appear in at least one test fixture, a `done`
matrix row with non-empty `tests`, or the documented CLI-only table below.

| Category | Evidence |
| --- | --- |
| all cases | `ParserTraceTests` (`Category.allCases` sweep), matrix row DX-X-003 |
| `timing` | `ParserTraceCoverageTests`, `TraceEnabledCompileTests`, `DXTraceExpansionTests`, DX-CLI-001 (`meridian compile --trace timing`) |
