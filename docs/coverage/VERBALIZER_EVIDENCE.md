# Wave 7-8 Verbalizer Evidence Matrix

Status key: `covered` | `blocked` | `out-of-scope`.

Wave 7 established the canonical verbalizer gate; Wave 8 extends the same matrix
to temporal/statistical/compound-note surfaces. Every in-scope row must remain
`covered`, with zero `blocked` rows.

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

### Wave 8 trace / statistical / compound-note productions

Column-0 codes match the exact `GrammarTable` production names so
`VerbalizerEvidenceTests` and `VerbalizerGenerativeTests` both key on them. See
the "Wave 8 additions" section below for the canonical templates and round-trip
tests.

| Production | Canonical example owner | Tests | Status |
|---|---|---|---|
| `trace-event-pattern` | GrammarTable + Verbalizer | VerbalizerGenerativeTests, COOK-18 | covered |
| `trace-scope-marker` | GrammarTable + Verbalizer | VerbalizerGenerativeTests, COOK-18 | covered |
| `trace-temporal-ever` | GrammarTable + Verbalizer | VerbalizerGenerativeTests, COOK-18 | covered |
| `trace-temporal-window` | GrammarTable + Verbalizer | VerbalizerGenerativeTests, COOK-18 | covered |
| `trace-temporal-count` | GrammarTable + Verbalizer | VerbalizerGenerativeTests, COOK-18 | covered |
| `trace-temporal-in-a-row` | GrammarTable + Verbalizer | VerbalizerGenerativeTests, COOK-18 | covered |
| `trace-temporal-since` | GrammarTable + Verbalizer | VerbalizerGenerativeTests, COOK-18 | covered |
| `trace-statistical-frequency` | GrammarTable + Verbalizer | VerbalizerGenerativeTests, COOK-STAT | covered |
| `compound-note` | GrammarTable + Verbalizer | VerbalizerGenerativeTests, COOK-14 | covered |

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
| `docs/cookbook/MERIDIAN_SYNTAX_COOKBOOK.md` CANONICAL lines | `COOK-*` in VerbalizerCookbookTests | covered |
| `docs/cookbook/MERIDIAN_NORTHSTAR_EXAMPLE.md` gallery samples | VerbalizerCookbookTests | covered |

## Wave 8 additions (temporal / statistical / compound note)

These surfaces were `out-of-scope` in Wave 7 and are now verbalized and
round-tripped. Each row compiles -> verbalizes -> recompiles to structural IR
equality through `VerbalizerCookbookTests` unless noted otherwise.

| Construct | Canonical template | Tests | Status |
|---|---|---|---|
| `ever` | `<subject> has ever <outcome>` | `COOK-18 ever canonical form round trips` | covered |
| within-window | `<subject> has <outcome> within the last <D>` | `COOK-18 within-window canonical form round trips` | covered |
| count-in-window | `<subject> has <outcome> <cmp> N times within the last <D>` | `COOK-18 count-in-window canonical form round trips` | covered |
| in-a-row | `<subject> has <outcome> N times in a row` | `COOK-18 in-a-row canonical form round trips` | covered |
| since-the-last | `<pred> since the last <E>` (authored `holds` preserved via `TraceTemporalKind.sinceLast.holds`) | `COOK-18 since-the-last canonical form round trips` | covered |
| keyed temporal adjective | `Definition: a <kind> is <adj> if …` (keyed) | `COOK-19 keyed temporal adjective canonical form round trips` | covered |
| statistical (`usually`/`rarely`/`N%`) | `<subject> <succeeds/fails> in at least N% of runs/occurrences [within the last <D>]` | `COOK-STAT statistical canonical form round trips`, `SEM_6_01 usually and rarely verbalize numerically` | covered |
| monitored statistical assert | `assert <subject> succeeds in at least N% of runs/occurrences [within the last <D>]` | `COOK-STAT statistical canonical form round trips`, `SEM_2_11 decision-point totality is not enforced on monitored statistical assertions` | covered |
| compound note | `proceed, and note "<text>" in the <binding>` (recognizes the desugared text-appending `rebind`) | `COOK-14 compound note canonical form round trips` | covered |
| unknown arm | `if it is unknown whether:` | `COOK-13 unknown-arm canonical form round trips` | covered |

Verbalizer note: the `since the last` and `unknown whether` canonical markers are
read from `FixedGrammar` (per pitfall #20); the compound-note surface uses
`FixedGrammar.compoundNoteIntroducer` / `compoundNoteInMarker`. The verbalizer
runs `IRValidator` before printing (pitfall #21) and reproduces the authored
`since` `holds` wording from the retained `IRExpression`, not the resolved
`holdsPattern`. Statistical sugar such as `usually` / `rarely` canonicalizes to
numeric thresholds, and compound-note diagnostics (`MER-REF-004`,
`MER-TYP-001`) are covered by `CompoundNoteTests` even though they are error
paths rather than verbalized output.

## Out of scope (Wave 8)

| Item | Status |
|---|---|
| Deontic / obligation operators (Wave 9) | out-of-scope |
| LLM canonicalize propose tool | out-of-scope |
| Verbalizing generated Swift | out-of-scope |
| Localization | out-of-scope |

## Automated coverage assertion

`VerbalizerEvidenceTests` fails if an IR primitive case or GrammarTable production lacks a row in this matrix.
