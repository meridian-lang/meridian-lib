# INFORM7_DESIGN_NOTES.md
## Inform 7 Architecture Lessons Mapped to Meridian

This document explains the Inform 7 mechanisms the wave program referenced, what each one buys, how it maps onto Meridian's existing pipeline (Surface -> Phrases -> IR -> Swift), and what NOT to copy. Inform's source has been public since 2022 (ganelson/inform on GitHub) and its internals are documented in literate-programming form; consult it when implementation details here are insufficient.

Governing thesis, which all of this serves: **English-likeness emerges from kernel uniformity, not NLP cleverness.** Inform feels like English because a tiny number of uniform mechanisms (assertions relate values; descriptions denote sets; definitions extend vocabulary; rules respond to circumstances) compose without special cases. Every feature below is a uniformity mechanism, not a parsing trick.

---

## 1. The pipeline shape (and where Meridian already matches)

Inform compiles in staged passes, roughly: lexing and sentence breaking; syntax analysis of each sentence against the grammar; semantic analysis building the world model (kinds, objects, properties, relations); resolution of descriptions and phrase invocations with type checking; generation into Inter (a typed IR); final code generation to the target VM.

Meridian's Source -> AST -> IR -> Swift is the same shape. The mapping:

| Inform stage | Meridian counterpart | Gap addressed by |
| --- | --- | --- |
| Sentence breaker | line/section segmentation | Wave 5C |
| Preform grammar | PegexBuilder parser | Wave 5A |
| World model assembly | merconfig domain + kinds | Wave 4A |
| Definitions/relations | (absent) | Waves 2B, 3A |
| Descriptions + type checking | for-each sources, partial | Waves 1C, 3C |
| Inter IR | 11-primitive IR | exists; payload extensions only |
| Problem messages | semanticError | Wave 5D |

Implication: you are not porting Inform. You are installing four missing semantic mechanisms (definitions, relations, descriptions, declarative domain sentences) into a pipeline that already has the right shape.

---

## 2. The two readings of "is" (assertion vs condition)

Inform's most important disambiguation: the same copula sentence means different things by context.

- In top-level declarative position: `The kitchen is a room.` is an ASSERTION that builds the world model at compile time.
- Inside a rule or phrase body: `if the door is open` is a CONDITION evaluated at runtime.

Meridian must hold the same line. Wave 4A's domain sentences (`A deal is a kind of page.`) are assembly-time assertions, legal only in `.merconfig` or a `## Domain` section. The identical surface inside a procedure is a condition or an error. Enforce by position, never by guessing intent. This single rule prevents the entire class of "did the author mean to declare or to test" ambiguity, and it is why Inform never needs to ask.

Corollary: assertions are order-independent within their pass (Inform assembles the model from all assertions before checking anything). Meridian's domain assembly should likewise be a fixpoint over all declarations in the file set, with contradiction (two different defaults for the same property) as a compile error naming both source locations.

---

## 3. Definitions: the vocabulary multiplier

Inform: `Definition: a person is tall if their height is more than 180.` After this, "tall" is a first-class adjective: usable in descriptions (`every tall person`), conditions, and negation (`not tall`) with zero extra machinery. The compiler turns each definition into a predicate; adjectives are resolved during description type checking.

Why this is THE leverage point: it moves vocabulary growth from compiler releases to author keystrokes. Every domain-specific concept (stale, urgent, orphaned, overdue, notable) becomes one sentence instead of one feature request. Corpus authors stop writing judgment blocks to express checkable concepts.

Implementation guidance for Meridian (Wave 2B):
- Each definition compiles to a pure Swift predicate `func isStale(_ page: Page, runtime:) -> Bool`, namespaced per kind, generated once.
- The adjective registry is part of semantic analysis state: kind -> adjective name -> predicate reference. Subkinds (Wave 4A) inherit the registry of their superkind.
- Type checking a description (`stale page`) is: resolve the head kind, then check every adjective exists in that kind's registry (walking up the lattice), then check whose-clauses against properties. The failure message names the kind actually inferred and lists the adjectives it does have (nearest-name suggestion).
- Inform also supports graded definitions (`Definition: a person is tall if their height is 180 or more.` enabling `the tallest person`). Meridian Wave 3C gets superlatives via the explicit `by <property>` form instead; only allow bare superlatives (`the tallest`) for adjectives declared with a measurable backing property. This avoids Inform's full gradability machinery while keeping the common cases.

---

## 4. Boolean structure: restrictive on purpose

English "and/or" is genuinely ambiguous (`A and B or C`). Inform handles this with precedence plus phrasing conventions. Meridian (Wave 2A) should be stricter than Inform: mixed and/or at the same level without `either ... or` grouping is a compile error with a rewrite suggestion. Rationale: Meridian's authors include AI agents emitting Meridian as a plan representation; a grammar that errors on ambiguity is a better compilation target than one with precedence surprises. Determinism of MEANING, not just of execution.

---

## 5. Quantifiers and determiners

Inform supports `all/each/every/any/some/no/most/at least N/at most N/exactly N` over descriptions, compiled to loops with counters over the description's domain. Notes for Meridian (Wave 2C):
- Quantifier evaluation must fetch the underlying collection exactly once per evaluation (bind, then test). Inform can iterate the object tree cheaply; Meridian's collections may come from tool calls, so repeated fetching would be both slow and non-deterministic under concurrent mutation. Make single-fetch a documented semantic guarantee.
- Skip `most` (vague in a workflow context) unless a corpus demands it; the prompt's set (all/any/no/at least/at most/exactly) covers the corpora.
- Empty-domain semantics: `all` over an empty set is true (vacuous truth), `any` is false. State this in the docs explicitly with an example; it is the most common author surprise.

---

## 6. Relations: the semantic backbone

Inform's deepest idea: almost everything is a relation between values. Containment, support, possession, adjacency are built-in relations; authors declare new ones (`Friendship relates various people to various people.`) and bind verbs to them (`The verb to be friends with means the friendship relation.`). The sentence grammar then gets verb-based conditions, passives, and relative clauses for free, uniformly, for every declared relation.

Meridian mapping (Waves 3A/3B):
- The critical adaptation: Inform's relations live in its own world model store. Meridian has no world store; its data lives behind tools and in workflow values. Therefore every Meridian relation declaration MUST name its evaluation backing: a property path or a declared tool. A relation is a typed, named view over data the runtime can already reach. This keeps relations witnessable (WDD-compatible) and avoids smuggling in a database.
- Verb binding gives three surface forms per verb: active condition (`X owns Y`), passive participle (`pages owned by X`), and relative clause (`pages that X owns` / `pages that mention Y`). Implement these as three productions parameterized by the verb table; do not write per-verb grammar.
- Inform supports relation calculus (next step via, number of steps via) for pathfinding. Skip entirely; out of scope for workflows. If graph traversal is ever needed it is a tool, not grammar.

---

## 7. Descriptions as compiled query plans

In Inform, a description (`the open doors in lighted rooms`) is a first-class value denoting a set, type-checked at compile time and compiled to efficient iteration. This is exactly a query plan: source, filters, sort, limit.

Meridian (Wave 3C) should make the plan explicit in the IR payload: `{ source, adjectiveFilters[], whoseFilters[], verbFilters[], sort?, take? }`. Benefits: golden-testable, optimizable later (push filters into tool query parameters when the tool declares support), and it gives `the number of <description>` and `the list of <description>` for free as terminal operations on the same plan. This struct is also the natural seam for future formal verification of plan properties.

---

## 8. Preform: grammar as data

Inform's entire surface syntax lives in Preform, a declarative grammar notation read at startup: hundreds of nonterminals, each a list of alternatives over ptokens (literal words, other nonterminals, wildcards). The compiler's parser is an interpreter over this data. Consequences: the grammar is inspectable, testable production-by-production, and even translatable to other natural languages by swapping the data.

Meridian adaptation (Wave 5A): keep PegexBuilder as the engine but lift production definitions into a declarative table (Swift result-builder DSL or generated source from a grammar file at build time). Do NOT interpret a grammar file at runtime; Meridian's value proposition includes compile-time guarantees and portability (zero-Foundation, WASM), so bake the grammar into the binary. The win to capture is the authoring model: adding an idiom is a data edit with a focused test, and the language reference can be generated from the grammar table so docs never drift.

---

## 9. NTI screening: how Inform parses a huge grammar fast

With hundreds of productions, trying every nonterminal against every word range would be quadratic pain. Inform computes, for each nonterminal, bit-vector "incidence" summaries of which vocabulary must or might appear in any match (NTI: nonterminal incidence). Before attempting a parse, it intersects the sentence's word bitmap with the production's required bitmap; on mismatch the production is skipped without parsing.

Meridian adaptation (Wave 5B): per production, precompute the set of anchor tokens (closed-class words like `whose`, `sorted`, `every`, `relates`, comparator words, unit words) at build time into a 64/128-bit mask over a small anchor vocabulary; tokenize each sentence once into the same mask; skip productions whose required mask is not a subset. Validate with a differential test (screening on vs off produces identical parses over all corpora) and a benchmark. This matters because Waves 2 to 4 will roughly triple the production count; without screening, parse time on 500-line skills will degrade noticeably.

---

## 10. Sentence breaking is harder than it looks

Inform's breaker is a small explicit state machine because naive period-splitting fails on: quoted text containing periods, abbreviations, decimal literals, and (for Meridian) inline code spans, fenced blocks, list-item boundaries, and headings. Wave 5C: enumerate the states (normal, in-double-quote, in-backtick, in-fence, in-number) and transitions explicitly, and differential-test against current segmentation over the full corpus. Boring, high-yield, prevents a whole class of "parser saw half a sentence" ghost bugs.

---

## 11. Problem messages: the feature users remember

Inform's error messages are famous: they quote the source, explain what the compiler understood and where understanding diverged, and usually show a corrected example. This is not cosmetics; in a natural-language surface, the error channel IS the teaching channel, because authors cannot consult a BNF in their heads.

Wave 5D style guide to enforce:
1. Quote the exact source span.
2. Say what was understood up to the failure point ("I read 'the stale pages' as a description of pages...").
3. Say what was expected, as a closed list when the set is small ("...but 'sortted' is not a known ordering word; I know: sorted by, newest first, oldest first, ascending, descending").
4. When a near-miss is detectable cheaply (edit distance 1 to 2 against the registry in scope), suggest it ("did you mean 'sorted'?").
5. Stable error codes so corpora regression tests can assert on the code, not the wording, letting wording improve freely.

---

## 12. What NOT to copy from Inform (and why)

- **The world model (rooms, things, containment, scenery).** Interactive-fiction ontology. Meridian's ontology is kinds + tools + workflows, declared per domain in merconfig. Copy the lattice mechanism (section 13), not the contents.
- **Actions, the action-processing rulebooks (before/instead/check/carry out/after/report), and scenes.** This is Inform's runtime event model for a simulated world. Meridian's runtime model is workflows + triggers + conventions, which already exists. Conventions in `.merrules` are Meridian's analog of injected rules; extend conventions if rule-ordering needs arise, do not import the six-stage action pipeline.
- **The runtime command parser and `Understand` grammar lines.** Inform parses player input at runtime; Meridian dispatch is compile-time triggers plus the RESOLVER, and runtime fuzziness is exactly what `use judgment` quarantines. Importing runtime NLU would violate the strict-determinism principle.
- **Past-tense conditions** (`if the door has been open`). Inform implements these by compiling hidden state-tracking flags into the program. For Meridian this collides with replay/checkpoint semantics and is better served by WDD traces; deferred with a logged design sketch, not built.
- **Full gradability/comparative machinery** (`taller than`). The `by <property>` explicit form covers the need at a fraction of the grammar surface.
- **Multiple inheritance and kind variables.** Single-inheritance lattice is enough for workflow domains and keeps the type checker simple and fast.
- **Inform's literate-programming build system.** Admirable, orthogonal.

---

## 13. The kind lattice, minimally

Inform's kinds form a lattice with "kind of" edges; properties, adjectives, relations, and phrases attach at a kind and apply to all subkinds; resolution picks the most specific applicable definition. Meridian Wave 4A needs exactly this with single inheritance:
- `A deal is a kind of page.` adds an edge; cycles are compile errors.
- Lookup for any name (property, adjective, verb role, phrase parameter match) walks from the most specific kind upward; first hit wins; an ambiguity between unrelated kinds in scope is an error naming both candidates.
- Codegen: subkind structs embed or compose the superkind's stored properties (pick one strategy, document it, golden-test it; embedding is simpler for Codable round-trips).
- The lattice is also what makes definitions and relations scale: define `stale` on page once; deals, meeting-pages, and entity-pages all get it.

---

## 14. Sequencing rationale (why the waves are ordered this way)

Definitions (2B) before relations (3A): definitions need only existing property machinery and immediately reduce corpus judgment lines, proving the loop. Relations before declarative domain sentences (4A): verbs and relative clauses are the expressiveness users feel; the lattice mainly amplifies what 2 and 3 built. Infrastructure (5) after the grammar has grown: screening and grammar-as-data are solutions to problems Waves 2 to 4 create; building them first would be speculative. Corpus diversification (6) last but planned from Wave 0: the metrics exist from day one so the final claim is a measurement, not an opinion.

## 15. Effort honesty

Inform 7 is the product of roughly two decades of design and polish by a small number of people. This program does not replicate that; it installs Inform's load-bearing mechanisms (definitions, relations, descriptions, lattice, grammar-as-data, problem messages) into a domain two orders of magnitude narrower than general fiction, which is precisely why it is feasible. Expect Waves 0 to 2 to be the proof point, Waves 3 to 4 to be the bulk of the engineering, Wave 5 to be discipline, and Wave 6 to be where the real grammar gaps are found. Budget for a second pass after Wave 6; every controlled natural language finds its missing idioms only on contact with foreign corpora.
