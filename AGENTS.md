# AGENTS.md — Meridian AI Contributor Handbook

Always-on, curated handbook: orientation, norms, the phase gate, and the cross-cutting pitfalls. Keep it lean — it is injected into *every* conversation.

**Context budget / self-update rule:** change history goes to `IMPLEMENTATION_LOG.md` (append-only, UTC-timestamped; older entries rotate into `.ai/implementation-log-archive/` — search both). Area conventions go to `.cursor/rules/*.mdc`. Update *this* file only when a **norm or pitfall** changes, never as a changelog.

---

## 1. What Meridian is

Meridian is a **controlled natural language compiler**: it converts `.meridian` workflow files (plus `.merconfig` vocabulary files) into async/await Swift source that runs against `MeridianRuntime`.

```
.merconfig source → MerConfigParser → MerConfigFile → SymbolTable.build(from:)
.meridian source  → MeridianParser(symbols:) → MeridianFile
                  → ASTToIR(symbols:) → [IRWorkflow]
                  → SwiftEmitter → String (Swift source) → swift-format
```

The entire pipeline is exposed as a single call:

```swift
let out = try Compiler(options: opts).compile(
    meridianSource: mer, meridianFile: "order_processing.meridian",
    merconfigSource: cfg, merconfigFile: "ecommerce.merconfig")
```
## 2. Repository layout

- `Sources/MeridianRuntime/` — runtime used by generated Swift (`Runtime/` actor, `Value/`, `State/`, `Comparison/`, `Protocol/`, `Domain/`, `Trace/`). `Sources/MeridianTools/` — built-in tools. `Sources/MeridianTestKit/` — test helpers. `Sources/SampleDemoFlows/` — hand-written reference flows.
- `Sources/MeridianCore/` — the compiler: `Compiler.swift` (entry point), `AST/`, `IR/IRTypes.swift` (13 IR primitives, incl. the split `aiJudgment`/`aiAutonomy` pair), `Parser/` (`Lexical/`, `Productions/`), `Symbols/`, `Lowering/`, `Codegen/` (`SwiftEmitter`, `ManifestEmitter`, `DomainEmitter`), `Language/` (`EnglishLexicon`, `LexiconCategory` + `LexiconRegistry`, `FixedGrammar`), `Rulebook/`, `Grammar/`, `Verbalizer/`, `Formatter/`, `Docs/`, `Testing/`, `Diagnostics/` (diagnostic engine, `DecisionCatalog`, `ParserTrace`), `Migration/` (`SkillMigrator`, `SkillDeviation`, `Difflib`).
- `Sources/MeridianCLI/` — thin `@main` shell; `Sources/MeridianCLIKit/` — testable command library (`Commands/`, one file per subcommand).
- `Tests/` — `MeridianCoreTests/`, `MeridianRuntimeTests/`, `MeridianToolsTests/`, `MeridianCLITests/`, `MeridianIntegrationTests/`, `MeridianSlowIntegrationTests/` (live-external-process suites), `CorporaTests/`; `sample-gbrain/Tests/` is a separate SwiftPM target.
- `examples/` — `.merconfig` / `.meridian` samples + `golden/`; `examples/dx/` — DX diagnostics regression fixtures (MER1012, MER3018, lint, recovery).
- `corpora/` — validation corpora `erp/`, `procedures/`, `incident/`, `etl/`, `governance/`, `clinical/` (originals, strict ports, compile outputs, deviation indexes); `governance/` and `clinical/` also carry a flat `rules/*.meridian` fixture (Phase-8 rule sugar, flat-path regression coverage).
- `docs/` — nine numbered docs `01_OVERVIEW` … `09_SKILL_PORTING` plus `15_PROBLEM_MESSAGES`; `docs/README.md` is the index, `docs/cookbook/` the normative oracle, `docs/coverage/` the coverage policy and floors. `.ai/implementation-log-archive/docs-history/` holds the pre-consolidation docs.
- `IMPLEMENTATION_LOG.md` — append-only decision log (recent entries only).

### CLI commands

`meridian <subcommand>` (see [`docs/05_CLI.md`](docs/05_CLI.md) for full flags). `MeridianCommandCatalog` in `Sources/MeridianCLIKit/` is the source of truth for leaf paths and `--module-path` support.

| Command | Purpose |
|---|---|
| `canonicalize` | Authored vs canonical English drift audit; optional `--propose` LLM rewrites (dry-run). |
| `mcp serve` | Stdio MCP server (compile/check/explain tools); `--once` for tests. |
| `compile` | `.meridian`/`.meri` → Swift + `.meridian.manifest.json`. Repeatable `--rulebook`; `--namespace auto\|none`; `--module-path`. |
| `explain` | Canonical English verbalization of compiled IR (Wave 7). Not diagnostic codes — use `explain-diag`. |
| `explain-swift` | Explain generated Swift via `.meridian.ir.json` sidecar. |
| `drift` | Compare authored source to canonical verbalized form (no `--module-path`). |
| `grammar-doc` | Emit live grammar-table Markdown reference. |
| `lint` | `MeridianLinter` authoring diagnostics without compiling. |
| `preview-skill` | Preview a `SKILL.md` via `SkillMarkdownImporter`. |
| `migrate-skill` | Convert `SKILL.md` → strict `.meri` (`--batch` for directories). See `docs/09_SKILL_PORTING.md`. |
| `skill-deviation` | Audit ported `.meri` vs original `SKILL.md` (`--batch --index`). |
| `inert-yield` | Measure inert-section lowering yield with real vocabulary/rulebook. |
| `check` | Parse + lower only; report diagnostics (no codegen; `--module-path`). |
| `format` | Canonicalise `.meridian`/`.merconfig` whitespace. |
| `docs` | Render `.merconfig` files to static HTML. |
| `test` | Run `.meridian.test` spec fixtures. |
| `trace categories` | List compile-time `--trace` categories. |
| `trace render` | Pretty-print runtime JSONL event streams with `TraceTreeRenderer`. |
| `trace verify` | Verify semantic trace-store JSONL integrity (`--run`). |
| `trace eval` | Replay-evaluate trace-temporal/statistical expressions (`--at`). |
| `trace drift` | Compare step-path identities between two manifests. |
| `trace-eval` | Top-level alias for `trace eval`. |
| `trace-verify` | Top-level alias for `trace verify`. |
| `run` | Compile then execute through a temp SwiftPM package. |
| `verify` | Alias for `check` (diagnostics only; no `--module-path` flag on this alias). |
| `resume` | Resume a run from the latest `FilesystemCheckpointer` snapshot. |
| `explain-diag` | Long-form diagnostic/decision explanations (`MERxxxx` / `D-DX-n`). |
| `decisions` | List, search, or render `DecisionCatalog` (`--render docs/07_DECISIONS.md`). |
| `bench-parse` | Benchmark unscreened vs screened expression parsing. |
| `bench-trace` | Benchmark trace replay query latency. |

`migrate-skill` and `skill-deviation` are backed by `SkillMigrator` / `SkillDeviation` + `DiffMatcher` in `Sources/MeridianCore/Migration/` (single source of truth; the migration corpus is reproducible with no external scripts).

---

## 3. Development norms

### Files

- **No file headers** (`//  FileName.swift`, `// Created by…`) and **no obvious comments** — comments only explain non-obvious intent, trade-offs, or constraints.
- **Original `SKILL.md` files are read-only.** Never edit `sample-gbrain/original-skills/**/SKILL.md` or other upstream/original corpus `SKILL.md` sources to make strict compile pass; fix the compiler/migrator or the ported `.meri` and keep originals as the immutable deviation baseline.
- **Append-only log.** Every assumption, decision, or blocker goes in `IMPLEMENTATION_LOG.md` with a UTC timestamp. Never delete entries.
- **Commit messages.** No tool attribution footers (no `Generated with …`, no `Co-Authored-By: <tool>`). Simplification work uses the `refactor:` subject prefix — `simplify:` is not used. No implementation-stage or phase labels in subjects or bodies (`(phase 3)`, `Phase 5a/5b`, `Wave 6`, `phase-1a`) — describe the change, not the schedule. Same for branch names and PR titles.

### Coding style

Swift 5.10+, strict concurrency (`Sendable`, `actor`, `async/await`). Prefer `struct` over `class`; `actor` only for mutable shared state. `public` only on a module's public API. No force-unwrap (`!`) in production code; prefer `guard let`/`guard else` early exits over nested `if let`.

### No hardcoded English-surface vocabulary (load-bearing rule)

**Never hardcode an English-surface word/keyword/phrase list inside parser, lowering, or codegen code.** Any surface token the grammar keys on — articles, prepositions, copulas, comparison markers, duration units, assertion introducers (`make sure`/`ensure`/`assert`), quantifier determiners, connectors, stop-words — belongs in `EnglishLexicon` (`Sources/MeridianCore/Language/EnglishLexicon.swift`), the single, domain-overridable source of surface vocabulary. The `.merconfig` `=== language ===` section generalises this: it lets a domain *extend* the lexicon without recompiling Meridian. When you reach for a literal like `["make sure ", "ensure "]` or `if lower.hasPrefix("every ")` in a `Parser/`/`Lowering/` file, **stop** and instead (1) add/reuse an `EnglishLexicon` field with a sensible `.default` and — if it should be author-extensible — one `LexiconCategory` case plus one `LexiconRegistry` spec row (`Sources/MeridianCore/Language/LexiconRegistry.swift`: header spellings, the `=== language ===` line shape, and the merge rule — `parseLanguageSection`, `MerConfigFile.merging` and `EnglishLexicon.merging(from:)` all read that table, so nothing else needs an edit), then (2) read it via the threaded `lexicon` parameter at the call site.

**"Lexicon default ≠ extensible."** A field alone just moves a hardcoded list into `EnglishLexicon.swift`; a category is done only once a `.merconfig` can add to it without a Meridian recompile — `Tests/MeridianCoreTests/LexiconRegistryParityTests.swift` enforces that parity for every category and accepted header spelling. Reference examples of the complete recipe: `assertionMarkers`, `inferenceCueWords`, `normativeCueWords`, `referenceHeadingWords`.

**Fixed vs. extensible.** *Extensible vocabulary* — articles, prepositions, copulas, comparison markers, duration units, assertion introducers, stop-words, any domain-synonymisable term — MUST live in `EnglishLexicon` and SHOULD be author-extensible via `=== language ===`; a literal list of these in a `Parser/`/`Lowering/`/`Codegen/` file is a bug (use `EnglishLexicon.stripLeadingArticle`, never an inline `["the ", "a ", "an "]`). *Fixed control-flow syntax* — `if`/`while`/`until`/`for each`/`otherwise`/`unless`, the quantifier determiners (`every`/`all`/`any`/`some`/`no`), block headers, and the `let … be …` / `do … and …` shapes — defines *what the language is*, so it may stay literal, but keep each construct's trigger words in ONE commented place (its parse production), never copy-pasted. Centralized-but-fixed grammar lives in `FixedGrammar.swift`. Other narrow exceptions (justify in a comment): non-natural-language structural sentinels (`\u{E000}` code-block/shell markers), Swift-keyword output in the emitter, `(( … ))` section markers.

**GrammarTable data edits first.** New expression/description/template/idiom surface forms are registered in `PegexSurfaceGrammar` (name, canonical example, summary, anchors from `EnglishLexicon`/`FixedGrammar`) with the matching table-order test *before* parsing is wired. Do not add new expression-level quote-shielding or trailing-period scanners at call sites: pegex/grammar-table parsing owns expression markers and `SentenceBreaker` owns statement terminators.

### Dependencies & spec documents

`pegex` (remote, `https://github.com/modelhike/pegex.git`) — `PegexBuilder` grammar DSL; vendored `StringTemplate` (`Sources/MeridianCore/modelhike-vendored/`) — codegen builder DSL. Do not add new remote dependencies without explicit user approval. Normative oracle docs for Waves 7–9 live in `docs/cookbook/`; agent prompts in `.ai/meridian-*.md`; document any divergence from the oracle in `IMPLEMENTATION_LOG.md`.

## 4. Phase-gate rule

**Do not start the next phase until the current one is signed off.** After completing a phase: (1) run `swift test` — all tests pass; (2) run the CLI forcing function (compile → build → run → diff); (3) assign a confidence percentage; (4) record it in `IMPLEMENTATION_LOG.md` under `### Phase N confidence audit`; (5) ask the user to sign off before proceeding.

### Three test workflows

Pick the first row that applies; only run slower tiers when the change needs them. Full detail: [`docs/08_TESTING.md`](docs/08_TESTING.md).

| Workflow | When | Command |
|---|---|---|
| **Fast inner loop** | Iterating on parser/lowering/codegen/runtime in-process | `swift test --skip MeridianSlowIntegrationTests` |
| **Full test gate** | Phase sign-off, codegen/corpus/migration changes, before merge | `swift test` |
| **Coverage gate** | Substantive production changes (per-file floors) | `scripts/coverage.swift --gate` |

`MeridianSlowIntegrationTests` holds every live-external-process suite: `swift build`/`swift run` via temp SwiftPM packages, CLI `run`/`test`, per-file `swiftc -typecheck` over generated Swift (`GeneratedSwiftTypecheckSlowTests`), and process-level `meridian` binary E2E. Plain `swift test` runs it; the fast inner loop skips it. Focused runs: `swift test --filter GeneratedSwiftTypecheckSlowTests` / `--filter MeridianSlowIntegrationTests`. Coverage's own three flows (fast `--gate`, rare `--full --gate`, occasional baseline regen): [`docs/coverage/README.md`](docs/coverage/README.md) § Commands.

After any major implementation session (even outside a formal phase), run the full local gate unless the user explicitly narrows validation: `swift test` then `scripts/coverage.swift --gate`. `--gate` skips `MeridianSlowIntegrationTests` by default (those files carry permanent floors); use `scripts/coverage.swift --full --gate` when the session touched `RunCommand`, `TestCommand`, `RuntimeExecutor`, `SwiftPMPackageRunner`, generated-Swift `swiftc -typecheck`, or process-level `meridian` E2E checks. Never skip plain `swift test` when generated Swift, codegen, domain emission, migration, or any committed corpus changed — the `swiftc -typecheck` gates live there.

Regenerate committed artifacts with the shared scripts, never hand-written loops (`{…}` is a bash brace list — one line, once per corpus):

```bash
swift scripts/generate-migration.swift       --corpus {gbrain,erp,procedures,incident,etl,governance,clinical}
swift scripts/generate-compile-outputs.swift --corpus {gbrain,erp,procedures,incident,etl,governance,clinical}
swift scripts/generate-deviations.swift      --corpus {gbrain,erp,procedures,incident,etl,governance,clinical}
swift scripts/strict-compile-report.swift    [--root corpora/erp --vocab … --rulebook …]
```

`generate-migration` runs `migrate-skill <root>/original-skills --out <root>/skills --batch --force` plus a single-file call for `RESOLVER.md` → `RESOLVER.meri` (`--batch` never discovers it), and appends derived section-role aliases to the corpus `.merrules` (idempotent). `generate-compile-outputs` cleans and recompiles with `--no-format --namespace auto`. `generate-deviations` runs `skill-deviation --batch --index` and prints the deviation index plus a per-file operational-inert worklist (worst offenders first) as the actionable worklist. Regenerate goldens/compile-outputs/deviations/coverage baselines in the same change set as the code that affects them; never edit original `SKILL.md` sources to improve metrics. Coverage baseline/floor regeneration (`docs/coverage/coverage-baseline.md` / `docs/coverage/coverage-exclusions.md`) is its own occasional `--full` flow ([`docs/coverage/README.md`](docs/coverage/README.md) "Commands", flow 3), not part of routine `--gate`. If a gate cannot be run, say exactly why and record the residual risk in the final response and `IMPLEMENTATION_LOG.md`.

The user has explicitly stated: *"once impl for a phase is done, don't automatically start the next phase. First, check if the impl is comprehensive, give a confidence %. Get to near 100% confidence before proceeding to the next phase."*

## 5. Area-scoped reference rules

Deep per-area conventions live in `.cursor/rules/*.mdc` (kept out of the always-on budget). Each carries a `description` and `globs`, so it auto-attaches when a matching file is in context. **Always-on directive (do not skip):** before substantive work in any area below — including cross-cutting changes, and even if the rule did not auto-attach — open and read the matching `.cursor/rules/*.mdc` first. When an area convention changes, update its rule file, not this handbook.

| Rule file | Covers | Attaches when editing |
|---|---|---|
| `compiler-internals.mdc` | `matchPhrase`/lowering/parsing invariants + the 13 IR primitives & `IRExpression` cases | `Sources/MeridianCore/{Parser,Lowering,Symbols,IR}/**` |
| `codegen.mdc` | `SwiftEmitter` escaping, namespacing, `emitValueExpr`, comparison emission, struct conventions | `Sources/MeridianCore/Codegen/**` |
| `runtime.mdc` | `Value` enum, `State.get` keys, `Runtime.init`, `Observer`/`TraceRecord` naming, sync helpers | `Sources/MeridianRuntime/**` |
| `tracing.mdc` | `ParserTrace` categories, `MERIDIAN_TRACE`, thread safety, the task-local trace convention | `Sources/MeridianCore/Diagnostics/**` |
| `testing.mdc` | Running tests, the per-file coverage gate, forcing functions, golden/trace test patterns | `Tests/**`, `scripts/coverage.swift` |

## 6. Known sharp edges and pitfalls

1. **`findArticle` must pick the earliest article** — `EnglishLexicon.findEarliestArticle(_:)`, earliest by position, never iteration order (that bug produced `state.get("l amount")`).
2. **No `"the "` prefix in `exprToText`** — `ASTToIR.exprToText` must not prefix bare identifiers; it produced `state.get("the order.id")`. Tried and reverted.
3. **Possessive recognition without an article** — `ExpressionParser.parseAtom` must still detect `X's Y` after argument substitution strips `the/a/an`.
4. **Quote-aware splitting** — `rangeOfMarkerOutsideQuotes` keeps comparison markers (` is `, ` equals `, …) out of double-quoted strings; never treat single-quote as a string boundary (possessives contain `'`).
5. **Argument substitution order** — `ASTToIR.substituteArgs` sorts arguments by descending key length, or `"amount"` clobbers `"total amount"`.
6. **Workflow call argument order** — `lowerPhraseInvocation` orders workflow-stub arguments by the declared `phrase.pattern.parameters`, not the dictionary; the generated `init` labels depend on it.
7. **`collectMultiLineCounted` vs `collectMultiLine`** — always use the counted variant when iterating with an explicit index; the other re-processes continuation lines as top-level statements (spurious `_unresolved` binds).
8. **`splitArgs` and single quotes** — double-quote only (see #4).
9. **`Sendable` Constants struct** — `Constants` must be `public struct Constants: Sendable`; it is used from async `run()` methods.
10. **Vendored `StringTemplate` powers codegen** — `SwiftEmitter` uses it and `emit` calls `toString(separator: "\n")`, which recursively flattens nested templates.
11. **`StringConvertibleBuilder` must stay `public`** in the vendored `StringConvertible.swift`, or the result-builder attribute is unavailable across module boundaries.
12. **"Compiles" means Meridian emitted Swift *source*** — `Compiler.compile` and `SkillMigrator.compiledOK` never run `swiftc`; invalid Swift can pass every compile test and only fail later. The real validators are the `swiftc -typecheck` gates in `Tests/MeridianSlowIntegrationTests/GeneratedSwiftTypecheckSlowTests.swift`.
13. **Generated identifiers must be sanitized** — struct names go through `EnglishLexicon.structName` (`webhook-transforms` → `WebhookTransforms`); colliding trigger phrases get a numeric suffix via `IRWorkflow.explicitStructName`; `DomainEmitter` drops an explicit merconfig `id` because the `MeridianKind` identity `id` is synthesised.
14. **A `role` section's body must be exclusively executable — split, don't comment.** Never blockquote prose to silence the error (a `>` line is dropped from the IR — lossy and author-chosen); add a separate sibling/child heading whose body is only executable statements. Long form: [`docs/09_SKILL_PORTING.md`](docs/09_SKILL_PORTING.md) § pitfalls #14–#15.
15. **Narrative encodes executable contracts — mine it, route it, or let it hard-error; never auto-wrap or inert it.** `SkillMigrator`'s four-way precedence: lowerable → lower; inference-cue → the only AI-marker case; genuinely documentary → `(( role: reference ))` (never `(( inert ))`); cue-less normative → left unmarked for a precise compiler error. Classify every normative sentence before marking it. Long form: [`docs/09_SKILL_PORTING.md`](docs/09_SKILL_PORTING.md) § pitfalls #14–#15.
16. **`(( role: procedure ))` is redundant on a recognized procedure heading** (`Phases`, `Workflow`, `Pipeline`, `Protocol`, `Steps`, `Process`, `Procedure`, `Phase N:`); never add it there, never strip it from a custom heading without renaming to a recognized synonym.
17. **`NonterminalScreen` masks must fully represent a production's anchors** — the bitmask vocabulary is fixed-capacity (`Bitset128`); if any anchor is missing the whole production falls back to mask `0`, never a partial mask (that wrongly screens out valid expressions). Long form: [`docs/03_LANGUAGE.md`](docs/03_LANGUAGE.md) § "Architectural patterns".
18. **Authoring a new corpus** has its own playbook and gotchas — read [`docs/09_SKILL_PORTING.md`](docs/09_SKILL_PORTING.md) § "Generating a new synthetic corpus" before starting rather than rediscovering them.
19. **`meridian explain` is the verbalizer; diagnostics are `explain-diag`** — never reintroduce `explain` with `MERxxxx` codes. The verbalizer is a totality surface: no placeholder/TODO/`_unresolved`/"malformed" fallback text to make a new case compile. Long form: [`docs/06_DEVELOPER_EXPERIENCE.md`](docs/06_DEVELOPER_EXPERIENCE.md).
20. **Verbalizer canonical surface lives in `FixedGrammar`** — read `model.lexicon.grammar` (`statement`, `verbalizer`, `waitSignalIntroducer`, `choiceGateIntroducers`, `judgmentIntroducers`, …); add emit tokens to `FixedVerbalizerSurface`/`FixedGrammar` first, extensible synonym tables stay in `EnglishLexicon`. Long form: [`docs/06_DEVELOPER_EXPERIENCE.md`](docs/06_DEVELOPER_EXPERIENCE.md).
21. **`Verbalizer`/`SwiftEmitter` validate IR and throw** — `IRValidator` runs before printing; malformed IR is a structured `MER4002`, never placeholder output. No `.silent()` in `Sources/` except the machine-checked allowlist in `docs/coverage/SILENT_FALLBACK_ALLOWLIST.md` (`TrialLowering`, `InertYieldAnalyzer`, `ParserBenchmark`). Long form: [`docs/06_DEVELOPER_EXPERIENCE.md`](docs/06_DEVELOPER_EXPERIENCE.md).
22. **`since the last` holds must reduce to an event pattern** — a pure state predicate is a compile-time `MER-TMP-019` (`traceStateHistorySince`), never an emitter `preconditionFailure`; the compound note form desugars to an existing `rebind`, never a new IR primitive. Long form: [`docs/06_DEVELOPER_EXPERIENCE.md`](docs/06_DEVELOPER_EXPERIENCE.md).

## 7. Decision history

- **`IMPLEMENTATION_LOG.md`** — active/recent entries (append new work here); **`.ai/implementation-log-archive/`** — frozen older snapshots (see its `README.md`). Read both on demand; do not mirror log content into this file. Pre-consolidation docs (wave-history narrative, point-in-time reports) live in `.ai/implementation-log-archive/docs-history/`.
- Architectural decision numbering (`D1`–`D30`) and the generated decision catalog (`D-DX-*`): [`docs/07_DECISIONS.md`](docs/07_DECISIONS.md), or `meridian explain-diag <code|decision>`.
- SKILL.md expressiveness tags (`SkillMD-D1`…`SkillMD-D28`): `.ai/brainstorm-done/skill_md_expressiveness_d1_d28.md`. A bare `D<N>` outside `docs/07_DECISIONS.md` means `SkillMD-D<N>`.
