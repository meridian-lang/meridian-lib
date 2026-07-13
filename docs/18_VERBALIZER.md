# Meridian — Wave 7 Verbalizer

Wave 7 adds V, the deterministic verbalizer for Meridian's lowered model. V
prints Canonical English from compiled IR so humans can audit what the compiler
actually understood, compare authored prose to the canonical form, and prove
that the printed form can be compiled back to the same structure.

Evidence and coverage live in
[`coverage/VERBALIZER_EVIDENCE.md`](coverage/VERBALIZER_EVIDENCE.md).
The normative canonical surface oracle is
[`cookbook/MERIDIAN_SYNTAX_COOKBOOK.md`](cookbook/MERIDIAN_SYNTAX_COOKBOOK.md).
Wave 8 extends that same verbalizer surface to temporal/statistical conditions
and the compound-note form; the operational runtime semantics for those forms
live in [`19_TRACES_AND_TIME.md`](19_TRACES_AND_TIME.md).

---

## What V Is

V is a compiler-side pretty-printer over the same semantic model used for
Swift emission:

```swift
let model = try Compiler(options: .init()).compileToModel(
    meridianSource: source,
    meridianFile: "skill.meri",
    vocabularies: vocabularies,
    rulebooks: rulebooks
)
let canonical = try Verbalizer(model: model).verbalize()
```

It is intentionally boring:

- It prints lowered workflows, inline definitions, frontmatter needed to reparse
  the model, and the statement/expression surface for every IR primitive.
- It canonicalizes equivalent authoring forms to one stable spelling.
- It uses the real `SymbolTable`, `EnglishLexicon`, rulebooks, triggers, scoped
  tools, and lowered definitions. It does not reconstruct these from shape
  heuristics.
- It is total over the in-scope Wave 7 IR surface. In-scope cases must produce
  concrete source text, never placeholders or unfinished markers.

## What V Is Not

V is not a natural-language paraphraser, a source formatter, or a reversible
Markdown serializer. It does not preserve comments, documentary reference
sections, heading prose, or the author's exact phrasing. It is also not a proof
that an original `SKILL.md` meant the same thing as the compiled model; it is a
proof of what the compiled model is.

Use `meridian explain` when you want the canonical compiled meaning. Use
`meridian drift` when you want a line-oriented audit of how far the authoring
surface is from that canonical form. For trace-backed replay or runtime
semantics, use `meridian trace eval` / `trace-eval` and the Wave 8 trace docs,
not the verbalizer alone.

---

## Round-Trip Law

The governing Wave 7 law is `SEM-8-03`:

```text
compile(source) -> model A
verbalize(model A) -> canonical source
compile(canonical source) -> model B
assert structurallyEqual(A, B)
```

The equality oracle is IR structural equality, not byte-for-byte source
equality. Source locations, file names, comments, formatting, and documentation
that never lowers to IR are ignored. Semantic fields are compared: workflow
names/parameters, primitive cases, tool ids, bindings, expressions, branch and
loop bodies, wait/recover/commit payloads, AI judgment/autonomy payloads, and
lowered definitions.

The tests also assert a fixpoint for representative corpus files:

```text
verbalize(compile(verbalize(compile(source)))) == verbalize(compile(source))
```

That second law makes canonical output stable enough for reviews and drift
baselines.

---

## Canonicalization Policy

Canonical English is a normalized audit surface, not the only accepted source
surface.

| Authored surface | Canonical policy |
|---|---|
| Comparison synonyms such as `exceeds` | Print the core comparator, e.g. `is more than`. |
| Rulebook desugars such as `Check:` / `Publish:` | Print the lowered statement, e.g. `assert ...` / `emit ...`. |
| Phrase invocations backed by vocabulary | Prefer the declared phrase pattern when the invocation can be inverted. |
| Direct tool calls | Print `invoke <toolID> with ...` when no phrase inversion is available. |
| `let ... be ...` | Print canonical `bind ... = ...`. |
| Markdown data tables | Print explicit `!!! table (( data: name ))` plus a table. |
| Judgment/autonomy prose | Print the explicit `use judgment to ...:` / `with autonomy ...:` boundary. |
| Comments/reference/template prose | Omit from canonical IR output unless it participates in the lowered model. |
| Fenced template holes `{ expr }` | Re-emit B7 double-brace `{{ expr }}`; shell holes stay single `{…}`. |
| Match-branch wildcards `_` | Print canonical `anything`. |

Canonicalization is allowed to change spelling, punctuation, and layout. It must
not change the lowered structure.

---

## Match-branch (`branch on`)

`BranchCondition.match` is a third branch modality alongside predicate `if` /
`otherwise`. Canonical English:

```text
branch on choice:
  "yes":
    complete.
  approved:
    complete.
  anything:
    complete.
  otherwise:
    complete.
```

Patterns are string literals, bare enum identifiers, or the FixedGrammar
wildcard labels (`anything` / `_`; Verbalizer always emits `anything`). The
optional `otherwise:` arm is IR `BranchIR.thenBlock` and codegen emits it as
Swift `default:`.

Authored ordinary skills rarely emit this surface today; the Verbalizer and
`matchBranchIRRoundTrip` lock the IR ↔ Canonical English round-trip. Structural
markers (`branch on`, wildcards, template directives) live in `FixedGrammar`
and are shared by parser and Verbalizer.

---

## Formatting Policy

The verbalizer owns source formatting for Canonical English:

- two-space indentation under workflow and block headers;
- one statement per line unless the canonical form is inherently block-shaped;
- terminal periods on single-line statements;
- comma-terminated headers for branches, loops, and `otherwise`;
- fenced blocks for multi-line interpolated strings;
- stable frontmatter list rendering for triggers/tools/vocabulary-like fields.

This is separate from `meridian format`, which is a conservative formatter for
authored source files. `meridian format` preserves the author's surface; V emits
the compiler's canonical surface.

---

## Invoke And Phrase Inversion

Lowering erases some phrase-level syntax: a phrase invocation may inline into
several primitives, and a direct tool call is just `InvokeIR(toolID:args:)`.
V reconstructs the most readable surface it can:

1. If an `InvokeIR` corresponds to a declared phrase or workflow pattern,
   `InvokeInverter` prints that phrase surface with arguments rendered through
   the expression verbalizer.
2. If no phrase pattern can be recovered, V prints the direct tool form:
   `invoke <toolID> with key = value`.
3. Shell commands get the command-surface spelling:
   `` `command` -- optional comment. ``
4. If an invoke has a result binding, V prints it as `bind <name> = ...`.

Example from `corpora/erp/skills/placeorder.meri`:

```text
bind orders = invoke order.list with status = "open".
for each order in orders,
  bind inventory = invoke inventory.reserve with order = order.
  bind invoice = invoke invoice.create with order = order.
```

This is more explicit than the authored ERP runbook, but it is the exact lowered
meaning that Swift emission will use.

---

## Judgment Verbalization

The AI boundary is explicit in Canonical English. `AIJudgmentIR` prints as:

```text
use judgment to <goal>:
  <optional embedded/guidance lines>
```

`AIAutonomyIR` prints as:

```text
with autonomy until <condition> unless <condition> re-plan after N failures up to M steps, <goal>:
  <optional embedded/guidance lines>
```

No unmarked prose is inferred. Fuzzy Markdown tables/checklists and explicit
`use judgment to ...:` / `with autonomy ...:` markers all lower through the same
typed IR path. Scoped tools and guidance are preserved in the model even when
the canonical printed surface is intentionally concise.

Example from `corpora/incident/skills/triagealert.meri`:

```text
otherwise,
  use judgment to classify the alert and recommend a response, weighing its severity and service name before escalating:
```

---

## Drift Categories

`DriftEngine.diff(authored:canonical:)` compares authored source to canonical
source line by line and classifies each changed hunk:

| Category | Meaning | Example |
|---|---|---|
| `synonymCanonicalized` | The canonical side uses a known normalized marker. | Authored `exceeds`; canonical `is more than`. |
| `structureNormalized` | Only spacing/structural layout changed. | Extra indentation or whitespace collapses to canonical indentation. |
| `desugarExpanded` | A compact rulebook or idiom form expanded. | Authored `do A and B`; canonical prints two statements. |
| `meaningBearing` | The line changed in a way the simple classifier cannot prove cosmetic. | Authored documentation disappears from canonical IR output, or a phrase becomes an explicit invoke. |

The current engine is intentionally conservative. A `meaningBearing` hunk means
"review this", not necessarily "the compiler changed semantics." Sectioned
SKILL files often produce many meaning-bearing hunks because reference/template
documentation is retained in the manifest but omitted from canonical IR source.

Example summary from `corpora/erp/skills/placeorder.meri`:

```text
# Drift: placeorder.meri

## Summary
- Total hunks: 37
- Synonym canonicalized: 6
- Structure normalized: 0
- Desugar expanded: 0
- Meaning-bearing: 31
```

---

## Public API

### `Compiler.compileToModel`

`compileToModel` runs the same bootstrap, parse, validation, trigger synthesis,
and lowering path as `compileWithManifest`, but returns the semantic model before
Swift emission:

```swift
public func compileToModel(
    meridianSource: String,
    meridianFile: String = "workflow.meridian",
    vocabularies: [Compiler.VocabularyInput],
    rulebooks: [RulebookInput] = []
) throws -> VerbalizerModel
```

Use it for tooling that needs compiled meaning: verbalization, drift audits,
semantic previews, and future obligation/deontic annotations.

### `VerbalizerModel`

`VerbalizerModel` carries:

- `workflows`: lowered `IRWorkflow` values;
- `loweredDefinitions` and `inlineDefinitions`;
- `symbols` and `lexicon` used to parse the source;
- `sourceFileName` and `authoredSource`;
- `metadata`, `outline`, `skillSections`, and `toolsUsed`.

It is deliberately richer than `[IRWorkflow]` so Canonical English can print
frontmatter, definitions, trigger-derived context, and invoke/phrase surfaces
with real vocabulary knowledge.

### `Verbalizer`

`Verbalizer(model:)` exposes:

```swift
public func verbalize() throws -> String
public func verbalize(_ expr: IRExpression) -> String
public func verbalize(_ prim: IRPrimitive) -> String
```

The whole-model overload is the CLI surface. It validates the model's workflows
with `IRValidator` before printing and throws structured `MER4002` diagnostics
for malformed hand-built IR. The expression and primitive overloads are used by
tests, grammar examples, and focused tools.

### `DriftEngine`

```swift
public enum DriftCategory: String, Sendable {
    case synonymCanonicalized
    case structureNormalized
    case desugarExpanded
    case meaningBearing
}

public struct DriftEngine: Sendable {
    public static func diff(
        authored: String,
        canonical: String,
        trace: ParserTrace = .shared
    ) -> DriftReport
}
```

`DriftReport.counts` aggregates category counts. `meridian drift --json` emits a
stable JSON shape for scripts; the default output is Markdown.

---

## CLI

Print Canonical English:

```bash
meridian explain sample-gbrain/skills/capture.meri \
  --merconfig sample-gbrain/brain.merconfig \
  --rulebook sample-gbrain/brain.merrules
```

Compare authored source with Canonical English:

```bash
meridian drift corpora/erp/skills/placeorder.meri \
  --merconfig corpora/erp/erp.merconfig \
  --rulebook corpora/erp/erp.merrules

meridian drift corpora/erp/skills/placeorder.meri \
  --merconfig corpora/erp/erp.merconfig \
  --rulebook corpora/erp/erp.merrules \
  --json
```

Both `explain` and `drift` accept `--trace` / `--trace-file`. Use
`--trace verbalizer` to follow canonical emission, and `--trace drift` to follow
hunk classification.

Print the canonical grammar reference generated from `GrammarTable`:

```bash
meridian grammar-doc
```

Diagnostic explanations use the renamed command:

```bash
meridian explain-diag MER2002
meridian explain-diag D-DX-5
```

---

## Worked Examples

### 1. `sample-gbrain/skills/capture.meri`

`capture` is documentation-heavy: most original sections are `reference` or
`template`, and the executable content is mostly shell-command examples. The
canonical form therefore collapses to the executable workflow:

```text
To capture a input:
  assert not (Don't try to bulk-import dozens of files by looping over `gbrain capture`. That's what `gbrain sync` (or `gbrain import`) is for. Capture is for single thoughts, single notes, single transcripts).
  `gbrain capture "the thought I want to remember"`.
  `gbrain capture --file ./notes/today.md`.
  `echo "from a pipe" | gbrain capture --stdin`.
```

This is a useful audit case: it shows exactly which formerly narrative lines
became executable and which documentary sections are absent from canonical IR
source. The omitted documentation is still available through the manifest's
section records; it is just not part of the lowered workflow.

### 2. `corpora/erp/skills/placeorder.meri`

The authored ERP runbook uses corpus-specific aliases:

```text
Step: `ofbiz order-check --queue open --json` to snapshot the open order queue.
fetch open orders.
Check: all orders have a number.
Check: at most 5 orders whose total amount exceeds the high value threshold.
```

Canonical English expands those aliases and synonyms:

```text
To place order:
  `ofbiz order-check --queue open --json` -- snapshot the open order queue.
  bind orders = invoke order.list with status = "open".
  assert all orders have a number.
  assert at most 5 orders whose totalAmount is more than the high value threshold.
```

The SEM-8-03 law says this explicit canonical version must compile back to the
same IR as the authored runbook.

### 3. `corpora/incident/skills/triagealert.meri`

This skill mixes deterministic handling with judgment routing:

```text
To triage alert:
  assert any alerts whose status equals "firing".
  bind alerts = invoke alert.list with status = "firing".
  for each alert in alerts,
    if alert is critical,
      bind oncallEngineer = invoke page.send with alert = alert.
      wait for signal "alert.acknowledged".
    otherwise,
      use judgment to classify the alert and recommend a response, weighing its severity and service name before escalating:
  emit incident.report with message = "alert triage pass complete".
```

The judgment line remains visibly marked. Reviewers can see that clear critical
alerts page deterministically, while borderline alerts cross the planner
boundary only at the explicit `use judgment` step.

---

## Test And Evidence Gates

Wave 7 coverage includes:

- `SEM-8-03` corpus round-trip over sample-gbrain and all corpora fixtures;
- byte-identical canonical fixpoint tests for representative files;
- totality tests over every `IRPrimitive` and `IRExpression` variant;
- seeded generative expression/primitive round trips;
- `COOK-*` cookbook forms for the published canonical surface;
- ambiguity/no-placeholder tests for representative examples and corpora;
- named complex E2E locks (`VerbalizerEndToEndTests`) plus CLI capture/triagealert
  zero-drift (`drift --json` → `total == 0`);
- `matchBranchIRRoundTrip` for `branch on` / `anything` / `otherwise:`;
- evidence-matrix staleness coverage in
  [`coverage/VERBALIZER_EVIDENCE.md`](coverage/VERBALIZER_EVIDENCE.md).

The current matrix reports every in-scope IR primitive, expression family,
GrammarTable production, legacy statement form, and cookbook/gallery row as
covered.

## Out Of Scope

Wave 7 deliberately did not include temporal/statistical operators; Wave 8 now
does. Wave 9 deontic/obligation operators are in scope. Still out of scope:

- an LLM canonicalization/proposal tool;
- source-preserving Markdown/documentation round-trips;
- generated Swift -> Meridian verbalization;
- localization or alternate natural languages;
- proof that authored prose outside the lowered IR was semantically equivalent.

