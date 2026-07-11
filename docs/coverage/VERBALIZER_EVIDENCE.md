# Wave 7 Verbalizer Evidence Matrix

Status key: `covered` | `blocked` | `out-of-scope`.

Wave 7 exit requires every in-scope row `covered`, with zero `blocked` / `xfail` rows.

## IR primitives

| Construct | Canonical template | Parser fixture | Round-trip | Ambiguity | Drift category | Docs | Status |
|---|---|---|---|---|---|---|---|
| `invoke` | `InvokeInverter` / `CanonicalForms` | VerbalizerSmokeTests | SEM-8-03 / VerbalizerRoundTripTests | VerbalizerAmbiguityTests | synonym/structure | 18_VERBALIZER | covered |
| `bind` / `rebind` | `bind x = …` / `rebind x = …` | VerbalizerSmokeTests | SEM-8-03 | VerbalizerAmbiguityTests | structure | 18_VERBALIZER | covered |
| `branch` | `if …,` / `otherwise` / `branch on …:` / `anything` / match `otherwise:` | VerbalizerSmokeTests, VerbalizerCoverageTests | SEM-8-03, matchBranchIRRoundTrip | VerbalizerAmbiguityTests | structure | 18_VERBALIZER | covered |
| `iterate` | `for each` / `while` / `until` | VerbalizerTotalityTests | SEM-8-03 | VerbalizerAmbiguityTests | structure | 18_VERBALIZER | covered |
| `assert` | `assert …` | VerbalizerSmokeTests | SEM-8-03 | VerbalizerAmbiguityTests | synonym | 18_VERBALIZER | covered |
| `emit` | `emit <id> with …` | VerbalizerTotalityTests | SEM-8-03 | VerbalizerAmbiguityTests | structure | 18_VERBALIZER | covered |
| `wait` | duration/signal/approval/event/choice | VerbalizerTotalityTests | SEM-8-03 | VerbalizerAmbiguityTests | structure | 18_VERBALIZER | covered |
| `commit` | `commit.` / `commit with label` | VerbalizerTotalityTests | SEM-8-03 | VerbalizerAmbiguityTests | structure | 18_VERBALIZER | covered |
| `recover` | `recover from any/named/where` | VerbalizerTotalityTests | SEM-8-03 | VerbalizerAmbiguityTests | structure | 18_VERBALIZER | covered |
| `simultaneously` | `simultaneously:` / background | VerbalizerTotalityTests | SEM-8-03 | VerbalizerAmbiguityTests | structure | 18_VERBALIZER | covered |
| `aiJudgment` | judgment prose + contract | VerbalizerTotalityTests | SEM-8-03 | VerbalizerAmbiguityTests | meaning/structure | 18_VERBALIZER | covered |
| `aiAutonomy` | autonomy prose + contract | VerbalizerTotalityTests | SEM-8-03 | VerbalizerAmbiguityTests | meaning/structure | 18_VERBALIZER | covered |
| `complete` | `complete.` / `with reason` | VerbalizerSmokeTests | SEM-8-03 | VerbalizerAmbiguityTests | structure | 18_VERBALIZER | covered |

## IR expressions / sub-enums

| Construct | Canonical template | Tests | Status |
|---|---|---|---|
| literals / refs / propertyAccess | CanonicalForms + Verbalizer | VerbalizerTotalityTests, SEM-8-03 | covered |
| comparison / logical | CanonicalForms markers | VerbalizerSmokeTests, COOK | covered |
| envVar / now | `$NAME` / `now` | VerbalizerTotalityTests | covered |
| invocation / interpolatedString | InvokeInverter + holes | VerbalizerSmokeTests | covered |
| recordList / tableLookup | table surface | VerbalizerTotalityTests, COOK | covered |
| definitionPredicate | `X is <adj>` / definition helper | VerbalizerSmokeTests | covered |
| quantified / description / aggregate / superlative | cookbook forms | VerbalizerTotalityTests, COOK | covered |
| WaitConditionIR / ErrorPattern / IterateMode / BranchCondition | docs/03 forms incl. `.match` | VerbalizerTotalityTests, matchBranchIRRoundTrip | covered |
| ComparisonOp / LogicalOp / QuantifierKind / AggregateKind | CanonicalForms | VerbalizerTotalityTests | covered |
| IRInterpolationSegment | `{{ }}` template holes / `{ }` shell / `[if]`/`[for each]` directives | VerbalizerTotalityTests, COOK | covered |

## Named complex locks (human audit)

CI still keys the evidence matrix on IR/grammar names; these named fixtures lock
complex corpus round-trips and CLI zero-drift:

| Lock | Fixture / filter | What it proves |
|---|---|---|
| Named E2E | `VerbalizerEndToEndTests` (orderapproval, triagepatient, accessmatrix, …) | Structure-normalized SEM-8-03 on complex skills |
| Match-branch | `matchBranchIRRoundTrip` | `branch on` / `anything` / `otherwise:` IR round-trip |
| CLI zero-drift | capture + triagealert → explain → `drift --json` | `total == 0` on canonical input |
| Template B7 | accessmatrix / policyaudit / COOK-template | Executable `[if]`/`{{ }}` in procedure/`— steps` |

## GrammarTable productions

| Production | Canonical example owner | Tests | Status |
|---|---|---|---|
| literal-atom | GrammarTable + Verbalizer | VerbalizerGenerativeTests, VerbalizerAmbiguityTests | covered |
| possessive-chain | GrammarTable + Verbalizer | VerbalizerGenerativeTests, VerbalizerAmbiguityTests | covered |
| comparison | GrammarTable + Verbalizer | VerbalizerGenerativeTests, COOK | covered |
| boolean | GrammarTable + Verbalizer | VerbalizerGenerativeTests, COOK | covered |
| temporal-window | GrammarTable + Verbalizer | VerbalizerGenerativeTests | covered |
| emptiness | GrammarTable + Verbalizer | VerbalizerGenerativeTests | covered |
| quantifier | GrammarTable + Verbalizer | VerbalizerGenerativeTests, COOK | covered |
| aggregate | GrammarTable + Verbalizer | VerbalizerGenerativeTests | covered |
| superlative | GrammarTable + Verbalizer | VerbalizerGenerativeTests | covered |
| description | GrammarTable + Verbalizer | VerbalizerGenerativeTests | covered |
| active-verb | GrammarTable + Verbalizer | VerbalizerGenerativeTests | covered |
| scalar-navigation | GrammarTable + Verbalizer | VerbalizerGenerativeTests | covered |
| table-lookup | GrammarTable + Verbalizer | VerbalizerGenerativeTests | covered |
| template-conditional | GrammarTable + Verbalizer | VerbalizerGenerativeTests | covered |
| template-loop | GrammarTable + Verbalizer | VerbalizerGenerativeTests | covered |
| template-formatter | GrammarTable + Verbalizer | VerbalizerGenerativeTests | covered |
| after-idiom | GrammarTable + Verbalizer | VerbalizerAmbiguityTests | covered |
| except-when-idiom | GrammarTable + Verbalizer | VerbalizerAmbiguityTests | covered |
| try-recover-idiom | GrammarTable + Verbalizer | VerbalizerAmbiguityTests | covered |
| suffix-conditional | GrammarTable + Verbalizer | VerbalizerAmbiguityTests | covered |

## Legacy statement forms (`docs/03`)

| Form | Canonical | Tests | Status |
|---|---|---|---|
| wait duration/signal/approval/event | docs/03 tables | VerbalizerTotalityTests, SEM-8-03 | covered |
| recover any/named/predicate | docs/03 tables | VerbalizerTotalityTests | covered |
| simultaneously | docs/03 | VerbalizerTotalityTests | covered |
| commit / complete / emit / rebind | docs/03 | VerbalizerTotalityTests / Smoke | covered |
| branch / iterate | docs/03 | VerbalizerSmokeTests | covered |

## Cookbook / gallery

| Source | Tests | Status |
|---|---|---|
| `MERIDIAN_SYNTAX_COOKBOOK.md` CANONICAL lines | `COOK-*` in VerbalizerCookbookTests | covered |
| `MERIDIAN_NORTHSTAR_EXAMPLE.md` gallery samples | VerbalizerCookbookTests | covered |

## Out of scope (Wave 7)

| Item | Status |
|---|---|
| Temporal / statistical / deontic operators (Waves 8–9) | out-of-scope |
| LLM canonicalize propose tool | out-of-scope |
| Verbalizing generated Swift | out-of-scope |
| Localization | out-of-scope |

## Automated coverage assertion

`VerbalizerEvidenceTests` fails if an IR primitive case or GrammarTable production lacks a row in this matrix.
