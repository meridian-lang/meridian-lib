# Meridian — Compiler Pipeline

This document traces a `.merconfig` + `.meridian` pair from raw text through
every compiler stage to emitted Swift.

---

## Stage 0 — Entry point

`Compiler.compile(meridianSource:meridianFile:vocabularies:)` in `Sources/MeridianCore/Compiler.swift`
is the single public façade. The CLI (`CompileCommand`, `RunCommand`) and unit tests both call this.

```swift
let out = try Compiler(options: opts).compile(
    meridianSource: mer,
    meridianFile: "order_processing.meridian",
    vocabularies: [
        .init(name: "ecommerce", file: "ecommerce.merconfig", source: cfg)
    ]
)
```

A convenience overload accepting a single `merconfigSource: String` is also
available for single-vocabulary compilations.

---

## Stage 1 — Tokenisation (`IndentTokenizer`)

`IndentTokenizer` converts a raw `String` into `[SourceLine]`.

```swift
struct SourceLine {
    let number: Int       // 1-based
    let indent: Int       // leading-space count
    let statement: String // text with trailing "." stripped
    var isEmpty: Bool     // blank or comment-only
    var isComment: Bool   // starts with "#"
    var isContent: Bool   // !isEmpty && !isComment
}
```

Indentation is significant: continuation lines (deeper indent than their
parent) are detected by comparing `.indent` values.

The tokenizer also collapses block-level Markdown structures into single
synthetic lines carrying a private-use sentinel:

- **Fenced code blocks** → `\u{E000}codeblock:<lang>:<base64>` (B6).
- **Tables** → `\u{E000}table:<mode>:<base64>`. A contiguous header + `|---|`
  delimiter + rows block is collapsed; an optional `!!! table (( <mode> ))`
  marker on the line directly above sets the `TableMode`: `decision` (default) /
  `data[: name]` / `iteration` / `inert` / `ai-discretion` / `ai-autonomy`.
- **Marked task lists** → `\u{E000}checklist:<mode>:<base64>`. A
  `!!! checklist (( <mode> ))` marker folds the following contiguous `- [ ]` /
  `- [x]` run into one sentinel carrying its `ChecklistMode` (`invariant` /
  `ai-discretion` / `ai-autonomy` / `inert`) and the bullet conditions
  (checkboxes stripped). An *unmarked* task list is **not** collapsed — its
  items keep their per-item `isChecklist` / `checklistChecked` tags (default =
  invariant asserts).
- **Marker errors** → `\u{E000}markererror:<base64>`. The tokenizer is
  non-throwing, so a malformed/dangling `!!!` marker is carried as a sentinel
  and raised as a located `semanticError` by `StatementParser`.

`BlockKind` (`table` / `checklist`), `TableMode`, and `ChecklistMode` are all
**enums**, never raw dispatch strings (AGENTS.md "No hardcoded English-surface
vocabulary"). A single `!!!` marker awaits its block via a `PendingBlock` enum;
a marker whose following block is the wrong kind (or absent) is a marker error.
`TableParser` and `StatementParser` decode these sentinels/flags in Stage 4/5.

---

## Stage 2 — Config parsing (`MerConfigParser`)

`MerConfigParser.parse(_:file:)` processes the `.merconfig` source.

### Section detection

Lines matching `=== name ===` are section headers. All content lines between
two headers belong to the preceding section. Unknown sections are skipped.

### Phrase definition parsing

Multi-line `To {pattern}:` headers are folded by `collectHeaderLines(…)`:
if the first line does not end with `:`, continuation lines (deeper indent)
are appended until one ends with `:`.

Body lines follow at a deeper indent than the `To` line.

Header parsing tokenises a pattern like
`"send an email via a mailer server, to an email address, …"` into
`[PatternSegment]`:

```
.literal("send")
.parameter(name: "email", kind: "email")
.literal("via")
.parameter(name: "mailer_server", kind: "mailer server")
.literal("to")
.parameter(name: "email_address", kind: "email address")
…
```

`MerConfigParser` / `MeridianParser` share the same phrase-pattern logic.
Parameter detection uses `EnglishLexicon.findEarliestArticle(_:)` over
`parameterArticles` (`a`/`an`) to pick the **earliest** article occurrence by
string position (not iteration order — an important correctness detail).

Trailing punctuation (`,` `;`) in the parameter text is stripped before the
kind name is formed.

### Output

`MerConfigFile` containing:
- `vocabulary: [VocabularyStatement]` (kinds, properties, phrases, tools)
- `constants: [ConstantDeclaration]`
- `instances: [InstanceDeclaration]`
- `tools: [ToolDeclaration]`

---

## Stage 3 — Symbol table (`SymbolTable`)

`SymbolTable.build(from:)` indexes the `MerConfigFile` for fast lookup during
parsing and lowering.

Key indices:
- `kinds: [String: KindDeclaration]`
- `constants: [String: ConstantDeclaration]`
- `instances: [String: InstanceDeclaration]`
- `tools: [String: ToolDeclaration]` (keyed by camelCase method name)
- `phrases: [PhraseDefinition]`

### Phrase matching — `matchPhrase(_ invocation:)`

1. Tokenise the invocation into significant words (strip stop words).
2. Take the first significant word as a **gate** — skip any phrase whose
   pattern literals don't contain that word.
3. Score remaining candidates by literal-keyword overlap.
4. Pick the highest-scoring candidate.
5. Call `extractArgs` to pull argument values out of the raw invocation text.

### Argument extraction — `extractArgs`

Iterates `PhrasePattern.segments`. For each `.literal`, it finds and advances
past the literal text. For each `.parameter`, it consumes text up to the next
literal (or end of string), then runs `stripPatternSlop` to remove leading
articles and kind words, and trailing list punctuation.

`ExpressionParser.parse` turns the extracted text into an `ExpressionAST`.

---

## Stage 4 — Meridian file parsing (`MeridianParser`)

`MeridianParser(symbols:).parse(_:file:)` processes the `.meridian` source.

Like `MerConfigParser`, it folds multi-line workflow headers before parsing
the body. The body is handed to `StatementParser`.

### `StatementParser.parseStatement`

Dispatches based on the first word:

- `complete` / `commit` → direct AST nodes
- `emit` → `parseEmit` (event ID + payload fields)
- `wait` → `parseWait`:
  - `wait <duration>.` → `WaitConditionAST.duration`
  - `wait for signal "<name>".` → `WaitConditionAST.signal`
  - `wait for approval of <expr> from <role>.` → `WaitConditionAST.approval`
  - `wait for event <id>.` / `wait for event <id> matching <predicate>.` → `WaitConditionAST.event`
  - choice gates lower to `WaitConditionAST.choice`
- `if … ,` → `parseConditional` (recursive)
- `bind … = …` / `rebind … = …` → `parseBindValue` → `parseInvokeExpr` or `ExpressionParser`
- `for each … in …` → `parseIteration`
- `assert …` → `parseAssert` (optional `otherwise:` block)
- `recover` → `parseRecover` (attaches to the preceding statement; does NOT use
  `collectMultiLineCounted` — that would greedily consume body lines)
- `simultaneously:` → `parseSimultaneously` (indented block of parallel steps)
- everything else → `phraseInvocation` collected via `collectMultiLineCounted`

`collectMultiLineCounted` folds continuation lines (deeper indent than the
parent) into a single text fragment *and* returns the consumed count so
`parseBlock` skips those lines.

### `ExpressionParser.parse`

Parses a single-line expression string:
1. `parseComparison` — splits on markers (`is more than`, `equals`, `is within`,
   …) **outside** quoted string regions (quote-aware via `rangeOfMarkerOutsideQuotes`).
2. `parseAtom` — recognises:
   - Possessive chains (`the X's Y`) → `parsePossessiveChain`
   - Bare possessives (`X's Y`, detected by `'s` presence) → `parsePossessiveChain`
   - Quoted string literals
   - Duration literals (`30 days`)
   - Numeric literals
   - Money literals (`$5000`)
   - `now` keyword
   - Identifier / constant / instance ref

`resolveBase` checks `SymbolTable` to decide whether a bare name is a
`.constantRef`, `.instanceRef`, or plain `.identifierRef`.

### Output

`MeridianFile` containing `workflows: [WorkflowAST]`.

---

## Stage 5 — Lowering (`ASTToIR`)

`ASTToIR(symbols:sourceFile:).lower(_ file:)` produces `[IRWorkflow]`.

### Workflow stub registration

Before lowering any workflow, every `WorkflowAST` is registered in the
symbol table as a `PhraseDefinition` stub (`workflowStructName` set,
empty body). This makes recursive and forward-reference workflow calls
resolvable during lowering.

### `lowerStatement`

Matches `StatementAST` cases and calls the appropriate `lower*` helper.
`phraseInvocation` is the interesting path:

```
lowerPhraseInvocation
  ├── starts with "invoke " → buildInvokeExpr → InvokeIR
  ├── matchPhrase finds a workflow stub → InvokeIR(toolID: "workflow:StructName")
  │     args ordered by pattern.parameters (not dict order)
  ├── matchPhrase finds a phrase → inlinePhrase
  │     substituteArgs (text + AST substitution, longest-param-first)
  │     then lowerBlock recursively (depth-limited to 8)
  └── no match → strict default: a coded `MER2001` diagnostic via
        `Diagnostic.unresolved` (always carrying a did-you-mean / candidate
         list). Only under `allow-fallbacks: unresolved-phrases` / lenient mode
         does it degrade to a `BindIR(name: "_unresolved", …)` placeholder
```

`simultaneously` lowers to `SimultaneouslyIR` whose `branches` is a list of
`IRBlock`s (one per parallel step).

#### Iteration refinements (1C)

A `for each` / `for every` / `every`/`each` loop may carry a single-clause
refinement that `StatementParser.extractIterationRefinement` strips off the noun
phrase, in this order:

```
for each [the first N] <kind plural>
        [whose <prop> <comp> <value> | within the last N <unit> | in the next N <unit>]
        [sorted by <prop>[, newest first|oldest first|ascending|descending]]
```

It parses into `IterationRefinementAST` (predicate / temporal / sort / take).
`ASTToIR.lowerIterationRefinement` lowers it to `IterateIR.source:
IRIterationRefinement?` (a struct payload — no new IR primitive; `nil` =
plain iteration):

- `whose` → the predicate's bare LHS is qualified to a property access on the
  loop variable (`whose total is at least 100` → `order.total >= 100`).
- temporal → a one-sided window comparison on the loop element's timestamp
  property (`ComparisonOp.withinPast` / `.withinFuture`). The property defaults
  to `updatedAt` and is configurable via a `=== language ===` `timestamp = …`
  entry (`LanguageSynonyms.timestampProperty` → `EnglishLexicon`).
- `sorted by` → `(camelCase(prop), ascending)`; `newest first`/`descending` =
  descending.
- `the first N` → `take = N` (applied **post-filter**).

`comparison` markers gained `is one of` (`.oneOf`) and `contains`
(`.contains`).

`SwiftEmitter.emitRefinedIterate` builds the refined source **pre-loop** so
`first N` counts after filtering:

```swift
let __src = (<collection>?.asList ?? [])
  .filter { __e in <predicate via emitElementExpr> }
  .sorted { __a, __b in MeridianComparison.orderedBefore(__a.member("p"), __b.member("p"), ascending: <bool>) }
let __srcRefined = Array(__src.prefix(<N>))   // omitted when take == nil
for (i, e) in __srcRefined.enumerated() { … }
```

`emitElementExpr` rewrites loop-var references into the closure parameter
(`__e`) and property accesses into `__e.member("p")`. The runtime helpers
`Value.member(_:)`, `MeridianComparison.orderedBefore(_:_:ascending:)`, and
`MeridianComparison.isWithinPast/isWithinFuture` back the generated closures.

#### Semantic core (Wave 2)

**Definition registration (runs first).** At the very top of `lower(_ file:)`,
`registerDefinitions(...)` ingests definitions from **both** the merconfig
vocabulary (`VocabularyStatement.definition`) and the `.meri` body
(`MeridianFile.definitions`) — before any workflow lowers — so an adjective
resolves regardless of source order or file. Registration:

1. Synthesizes a kind-namespaced function name `meridianDef_<Kind>_<adjCamel>`
   and rejects duplicate surface adjectives (collision error naming both sites).
2. Type-checks each body: every property the body reads must exist on the
   subject kind (own + ancestor chain), else a sourced error listing the known
   properties.
3. Detects recursion (direct or mutual) by DFS over the adjective-reference
   graph — a cycle is a hard error.

`lowerRegisteredDefinitions()` then lowers each body once (subject = the
definition's singular variable) into a `LoweredDefinition` carrying the
precomputed function name, which `Compiler.lowerAndEmit` threads into
`SwiftEmitter.emitFile`.

**Adjective predicates.** In `lowerComparison`, `X is/is not <adj>` where `adj`
is a registered definition **and** the LHS lowers to `.identifierRef` (subject
position) becomes `IRExpression.definitionPredicate(functionName:subject:)`
(`is not` wraps it in `.logical(.not, …)`). A `.propertyAccess` LHS is never
rewritten, keeping adjectives distinct from enum-value comparisons.

**Boolean trees in filters.** `qualifyToLoopVar` recurses over `.logical` and
`.definitionPredicate` trees (and qualifies only the **LHS** of a comparison),
so boolean conditions work inside `whose`/element filters and definition bodies.

**Quantifiers.** `lowerQuantifier` builds `IRExpression.quantified(QuantifierIR)`
with a `DescriptionIR { collection, elementVar, filters }`. The collection must
lower to a fetch-once source (`.identifierRef` / `.propertyAccess` /
`.constantRef` / `.instanceRef`); a direct `.invocation` source is a sourced
error. Leading adjectives and `whose` clauses lower to element-context filters
(adjectives → `.definitionPredicate`, `whose` → qualified comparison/logical).

**Shared condition grammar.** `lowerComparison` maps the new AST comparison
operators `withinPast` / `withinFuture` (temporal windows) and `isEmpty` /
`isNotEmpty` (property-backed emptiness) to their IR counterparts.

**Error carrier.** `ExpressionParser` stays non-throwing; surface violations
(mixed `and`/`or`, malformed quantifier/description, unidentifiable kind) become
an `ExpressionAST.malformed(String)` carrying a fully-formed diagnostic. The
throwing `lowerExpr` surfaces it as a sourced `CompilerError.semanticError`.

#### Relational layer (Wave 3)

**Symbol registration.** `MerConfigParser` parses two new sentence shapes into
`SymbolTable`: relation backings (`<Relation> is read from the <kind>'s
<property>.` / `… is read via the <tool> tool.` → `relationBackings`) and verbs
(`The verb to <base> (it <3rd>, it is <participle>) means the <relation>
relation.` → `verbs`, keyed by base form). `resolveVerbForm` maps any
conjugation back to its declared verb + role (`base` / `thirdPerson` /
`pastParticiple`).

**Validation (runs after definitions).** `ASTToIR.validateRelationsAndVerbs`:
every declared backing must name a declared relation and a valid kind/property
(property backing) or declared tool (tool backing); every verb must name a
**backed** relation; verb forms must be globally unambiguous. An unbacked
relation that no verb references is permitted (legacy vocabularies).

**Parser precedence.** `ExpressionParser.parseComparison` runs the active-verb
infix check *before* the comparison markers, but skips a verb immediately
preceded by a relativizer (`that`/`which`/`who`/`whose`) so a description's
relative clause is not mistaken for a top-level predicate. `parseAtom` tries
aggregate → superlative → scalar-navigation → description before falling back to
the possessive-chain atom.

**Lowering.**
- `lowerVerbPredicate` (active verb) → `.comparison(<obj>.<backingProp>,
  .identifies, <subj>)` for a property-backed relation; tool-backed verbs raise
  a sourced error (bind the related set first).
- `lowerScalarTraversal` (one-to-one navigation) → `.propertyAccess` for a
  property-backed relation; tool-backed inline navigation is an error.
- `lowerDescriptionPlan` → `DescriptionIR { collection, elementVar, filters,
  sort, take }`. The collection name is normalized singular→plural
  (`EnglishLexicon.pluralize`) so `the largest deal` reads the `deals` bind.
  A **tool-backed** clause sets the collection to a synthesized prelude `invoke`
  (hoisted via `lowerBindValue`), so descriptions over tool-backed relations are
  statement-only. Aggregates wrap a `DescriptionIR` (`.count` / `.list`);
  superlatives wrap one with a sort key (`SuperlativeIR`).

`ComparisonOp` gains `.identifies` (relation identity, runtime
`MeridianComparison.identifies`).

#### Markdown tables and task lists → IR

A table/checklist sentinel is expanded by `StatementParser` (Stage 4) *before*
lowering — it never produces a new IR primitive, only ordinary statements:

| Surface | Mode | Becomes |
|---|---|---|
| table | `decision` | one `if <conds>, <action>.` per row (re-parsed through the normal grammar → `BranchIR`) |
| table | `data[: name]` | `bind <name> = recordList(…)` → `IRExpression.recordList` |
| table | `ai-discretion` / `ai-autonomy` | one `ProseStepAST` (`TableParser.aiDecisionProse` renders rows as `when …, …`) → `ProseStepIR(.planThenExecute / .autonomousLoop)` |
| table | `iteration` / `inert` | nothing (reserved / documentation) |
| checklist | `invariant` (or unmarked) | one `assert` per item (checkable-or-error via `ConditionClassifier`) → `AssertIR` |
| checklist | `ai-discretion` / `ai-autonomy` | one `ProseStepAST` embedding every criterion as the goal → `ProseStepIR` |
| checklist | `inert` | nothing |

The AI-routed modes take the **same** `ProseStepAST → ProseStepIR` path as
`use judgment to …:` (an explicit dispatch), so they are valid in any workflow
— a fuzzy decision table or acceptance checklist becomes a planner step instead
of inert documentation. See [12_PROSE_AND_AUTONOMY.md](12_PROSE_AND_AUTONOMY.md).

`recover` lowers to `RecoverIR(attachedTo: IRBlock, pattern: ErrorPattern, handler: IRBlock)`.
The `attachedTo` block is the protected statement(s); `handler` is the catch block.

`wait` lowers the `WaitConditionAST` to `WaitConditionIR`:
- `.duration` → `WaitConditionIR.duration(Duration)`
- `.signal` → `WaitConditionIR.signal(String)`
- `.approval` → `WaitConditionIR.approval(of: IRExpression, by: RoleRef)`
- `.event` → `WaitConditionIR.event(String, matching: IRExpression?)`
- `.choice` → `WaitConditionIR.choice(prompt: String, options: [String])`

### `lowerExpr`

Maps `ExpressionAST` to `IRExpression`:
- `.identifierRef(n)` → checks symbols: `constantRef` / `instanceRef` / `identifierRef`
- Multi-word identifiers (bind variable names) are camelCased via `camelCase(_:)`
- `.propertyAccess` traverses possessive chains
- `.comparison(lhs, op, rhs)` → `IRExpression.comparison`
- `.quantified(q)` → `IRExpression.quantified` (see "Semantic core" above)
- `.malformed(msg)` → throws a sourced `CompilerError.semanticError`

---

## Stage 6 — Emission (`SwiftEmitter`)

`SwiftEmitter.emitFile(workflows:constantsDecl:instancesDecl:domainDecl:)` produces a
Swift source `String`. Uses `StringTemplate` from `modelhike`; each `emit*`
method returns a `StringTemplate` that is flattened via
`toString(separator: "\n")`.

See [05_CODEGEN.md](05_CODEGEN.md) for the full emission spec.

### Progress labels and replay-safe resume

`SwiftEmitter` assigns a stable **progress label** to every side-effecting
primitive (`invoke`, `emit`, `wait`, `assert`, `commit`) based on its path
through the IR tree (e.g. `progress:0.1.then.0:L85:C0`). Each primitive is
wrapped in an `if __meridianShouldRun("…")` guard. An implicit `runtime.checkpoint`
call follows each guarded primitive. Loop iterations also checkpoint at boundaries.

The generated `__meridianShouldRun` helper compares a progress label against
the last checkpoint label from a `ResumeContext`, implementing
lexicographic-order skipping. A generated workflow starts `run()` by calling
`runtime.consumeResumeContext()` — if a context is present, state is restored
from `restoredState` and the run resumes past the checkpoint label.

---

## Stage 7 — Formatting (optional)

`CompileCommand` passes the emitted string through `swift-format` unless
`--no-format` is provided. Errors during formatting are non-fatal (the
unformatted string is written).

---

## Section lowering (sectioned documents)

When the implicit-workflow body contains a `##`/`###` heading, the parser routes
it through `SkillSectionBuilder` (no `skill: true` flag — the discriminator is
structural). The builder splits the body into sections, resolves each heading
marker-first (`(( … ))` is authoritative) then by rulebook/built-in alias,
lowers executable sections per role, and **records every section** (executable
and non-executable alike) into `MeridianFile.skillSections`. There are no silent
drops: pre-heading content, unrecognized-heading-with-content, and non-checkable
invariant items are hard `semanticError`s.

A `## Tools Used` section (role `.tools`) is non-executable but
metadata-extracting: `extractToolID` mines each bullet's tool id into
`scopedTools` + the manifest `tools_used`. Two bullet forms are accepted —
`<description> (<tool_id>)` and the leading-backtick `` `<tool_id>` — <description>``
(any separator). A bullet matching neither (e.g. a backticked CLI command whose
token has spaces) is a hard error, so such sections stay `(( inert ))`.

## Stage 8 — Manifest emission (mandatory plumbing)

The manifest is a first-class, always-produced output. `Compiler.compileWithManifest`
assembles a COMPLETE `ManifestEmitter.Input` — workflows, constants, tools,
kinds, instances, metadata, heading `outline`, rules, and the recorded
`skillSections` — during the same compile that emits Swift. `ManifestEmitter.emit(_:)`
writes a `{stem}.meridian.manifest.json` companion: workflow names, parameters,
event IDs, tool IDs, source-map entries (from the `// L{line}` comments), and
`meridian_skill.sections` for sectioned documents. Non-executable section content
is guaranteed to reach the manifest, never best-effort.

---

## `Compiler.compile` return type

`compile(…)` returns a plain `String` — the Swift source — by calling
`compileWithManifest(…) -> (swift: String, manifest: ManifestEmitter.Input)`
internally and discarding the manifest. Callers that need the manifest (the CLI)
use `compileWithManifest` so the rich data computed during compilation is never
silently discarded.

## `Compiler` also exposes

```swift
// Emit Swift from pre-built IR (no parsing)
public func emit(workflows: [IRWorkflow], constantsDecl: SwiftEmitter.ConstantsDecl?) -> String

// Emit companion JSON manifest
public func emitManifest(_ input: ManifestEmitter.Input) throws -> String
```

## `CompilerError`

```swift
public enum CompilerError: Error, Sendable {
    case notImplemented(String)
    case syntaxError(message: String, range: SourceRange)
    case semanticError(message: String, range: SourceRange)
    case codegenError(message: String)
    /// The modern path: one or more structured, coded diagnostics. A failed
    /// compile reports *all* collected errors here.
    case diagnostics([Diagnostic])

    /// Project ANY case into structured diagnostics so renderers, the CLI, and
    /// tests treat every error uniformly. Legacy cases map to generic `MER0xxx`
    /// codes; `.diagnostics` returns its payload.
    public var diagnostics: [Diagnostic] { … }
}
```

Each `Diagnostic` carries a stable `DiagnosticCode` (e.g. `MER2002`), a
severity, the primary `SourceRange`, plus the remediation surface — a
did-you-mean `Suggestion` or candidate-list `DiagnosticNote`, optional `help`,
and the governing `DecisionRef`. See
[14_DEVELOPER_EXPERIENCE.md](14_DEVELOPER_EXPERIENCE.md) for the full anatomy and
the `MERxxxx` catalog, and [15_DECISIONS.md](15_DECISIONS.md) for the decisions
the codes link to.

## Batch reporting via `DiagnosticEngine`

Lowering does not abort on the first error. A per-file, single-threaded
`DiagnosticEngine` (`Sources/MeridianCore/Diagnostics/DiagnosticEngine.swift`)
**collects** diagnostics and recovers at construct boundaries (workflow / rule /
statement), skipping the offending construct wholesale rather than resyncing
token-by-token (which would spawn cascade/phantom errors). Phrase stubs are
pre-registered first, so a later workflow still resolves a reference to an
earlier one even if that earlier one had an error. At the end of the phase
`throwIfErrors()` raises a single `CompilerError.diagnostics([…])` with every
collected error. The engine also mirrors each diagnostic into the trace stream
(`.diagnostics` category) so `--trace diagnostics` shows them inline. This is
decision **D-DX-2** (no silent fallbacks; batch-report with coarse recovery).

## Error handling

| Stage | Error type | Behaviour |
|---|---|---|
| Tokenisation | `\u{E000}markererror` sentinel | Non-throwing; raised later as a coded diagnostic by `StatementParser` |
| Config parse | `CompilerError` | Unrecognized vocabulary declarations → `MER5002`; bad rulebook sections → `MER5003` |
| Meridian parse | `CompilerError` | Malformed headers → `MER1001`, orphaned code blocks → `MER1002`, unparseable statements/rules → `MER1003`/`MER1004`, misplaced frontmatter → `MER1006`, removed `import` form → `MER1008` |
| Lowering | `CompilerError.diagnostics` | **Strict-by-default, batch-collected.** Unresolved phrase → `MER2001`; unknown tool → `MER2002`; unknown kind/property/adjective/verb → `MER2003`/`MER2004`/`MER2007`/`MER2008`; unattached rule → `MER3006`; unresolved trigger action → `MER3007`. Per-file `allow-fallbacks:` (or `Compiler.Options.fallbackPolicy = .lenient`) downgrades the matching kind back to a `_unresolved`/stub placeholder |
| Emission | none | Always succeeds |
| Formatting | warning (`MER5001`) | **Non-fatal** (D-DX-3): the unformatted Swift is kept and written; a warning is reported to stderr |

The CLI renders all of the above through a single `DiagnosticRenderer`
(`reportCompilerError`), in either human (snippet + caret + did-you-mean) or
`--diagnostics-format json` form, and `--fix` applies the unambiguous
suggestions. See [07_CLI.md](07_CLI.md) and
[14_DEVELOPER_EXPERIENCE.md](14_DEVELOPER_EXPERIENCE.md).

## Wave 4 Pipeline Notes

`.meri` `## Domain` sections are harvested before symbol-table construction.
The harvester reuses `MerConfigParser` vocabulary productions and merges the
result into the effective `MerConfigFile`, so inline kinds/properties participate
in parameter parsing, relation validation, and domain codegen exactly like
`.merconfig` declarations.

Under `## Tables`, unmarked Markdown tables are rewritten to data-table mode by
`SkillSectionBuilder` before statement parsing. `StatementParser` validates typed
cells, then lowers the table to the existing record-list expression. Table lookup
syntax lowers to `IRExpression.tableLookup`, an expression-only scan over the
bound table that throws `table.lookup_miss` on a required miss.

Text substitutions remain expression payloads: `ExpressionParser` emits nested
`InterpolationSegment` trees for `[if]`, `[for each]`, and formatted holes;
`ASTToIR` recursively lowers them to `IRInterpolationSegment`; `SwiftEmitter`
turns the payload into Swift string-building code.
