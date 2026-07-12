# MERIDIAN_SYNTAX_COOKBOOK.md
## The complete surface reference: canonical forms, synonyms, edge cases, and counter-examples for every language layer

Version: draft 0.2 (comprehensive). Companion to MERIDIAN_SEMANTICS.md (meaning), MERIDIAN_NORTHSTAR_EXAMPLE.md (integration), MERIDIAN_DESIGN_RISKS_AND_REVIEW.md (hazards).

Purpose, three uses:
1. Design review on paper: every entry should read as natural controlled English; any entry that does not is a grammar bug found for free.
2. Test seed: every CANONICAL, ALSO PARSES, and ILL-FORMED line becomes at least one test, named `COOK-<section>-<n>`.
3. Verbalizer source: the CANONICAL line of each entry is the print form in the canonicalization table. One construct, one print form, forever.

Conventions:
- CANONICAL: exactly what `meridian explain` prints.
- ALSO PARSES: accepted synonyms; parse to identical IR; never printed.
- ILL-FORMED: must fail with the stable error code shown; full problem-message texts are in Part IX.
- EDGE: a legal but subtle case whose behavior must be pinned by a test.

---

# PART I: THE KERNEL DATA LANGUAGE

## 1. Literals and values

CANONICAL
```
"daily briefing"            (text)
42                          (integer)
3.50                        (decimal, exact decimal arithmetic)
true / false                (boolean)
7 days, 48 hours, 30 minutes, 2 weeks   (duration)
#incidents                  (channel-style bare token, text subkind where declared)
```
EDGE
- `3.50` and `3.5` are the same decimal value; the verbalizer prints the source's precision for literals (formatting is preserved through IR as written-precision metadata).
- Durations are physical time: `7 days` means exactly 168 hours. Calendar-aware arithmetic (months, DST) is not in the language; see Risks 1.6.
ILL-FORMED
- `3,50` -> MER-LIT-001 (decimal point, not comma).
- `7 day` -> MER-LIT-002 (unit agreement; singular only with 1).
- `0.1 + 0.2 is 0.3` evaluates TRUE (exact decimal); a test pins this, since binary-float intuitions are the bug here.

## 2. Names, possessives, property access

CANONICAL
```
the deal
the deal's deadline
the deal's owner's name          (chained)
it                               (the bound variable inside definitions and iterations)
```
ALSO PARSES: `the deadline of the deal` (prints as the possessive form).
EDGE
- Chains through `optional` values: accessing a property through `nothing` is a runtime error routed to recover (SEM-2-02), never a default. Test both the error and that `if the deal's owner exists` guards it.
- `its deadline` parses inside a definition body as `it's deadline` semantics without the apostrophe form; CANONICAL inside definitions is `its`.
ILL-FORMED
- `the deals deadline` -> MER-REF-003 (missing possessive; did you mean "the deal's deadline"?).
- `the deadline` where no unique deadline-bearing binding is in scope -> MER-REF-004 (ambiguous or unbound; in-scope candidates listed).

## 3. Comparators (the full closed set)

CANONICAL, with kind applicability:
```
is, is not                      (all kinds)
is more than, is less than      (integer, decimal, date, duration)
is at least, is at most         (integer, decimal, date, duration)
contains                        (text contains text; list of K contains K)
is one of <list>                (any kind vs list of literals/constants)
is empty / is not empty         (list of K, optional K)
exists / does not exist         (optional K; sugar for is not empty on optionals)
matches pattern "<regex>"       (text; the regex built-in)
```
ALSO PARSES: `is greater than` -> is more than; `is no more than` -> is at most; `is among` -> is one of.
EDGE
- Date comparisons: `is more than` on dates means later-than. Print form for dates stays `is more than`; do not introduce `is after` in v1 (one comparator family, uniformly).
- `contains` on text is case-sensitive; case-insensitive matching uses `matches pattern` with an inline flag. Pin with a test.
ILL-FORMED
- `is roughly` / `is about` -> MER-CND-001 (closed comparator list shown).
- Comparing `text` with `integer` -> MER-TYP-001 (kinds named; no coercion exists).

## 4. Boolean structure

CANONICAL
```
not <condition>
<condition> and <condition>
<condition> or <condition>
either <condition> or <condition>
it is not the case that <condition>      (prints as "not" form where simple)
```
Precedence: not > and > or. Comma before and/or is permitted and meaning-neutral.
EDGE
- Three-valued composition follows Kleene K3 once temporal/statistical operators exist: `false and unknown` is false, `true or unknown` is true, `true and unknown` is unknown, `not unknown` is unknown. Totality is enforced at decision points, not inside expressions (Risks 1.1; semantics amendment 2.4.1). Tests must cover all nine and/or cells.
ILL-FORMED
- `A or B and C` (mixed at one level, ungrouped) -> MER-CND-010 (two rewrites offered: `either A or B, and C` / `A, or B and C` shown as `A or (both)` phrasing).
- `A nor B` -> MER-CND-011 (nor unsupported; use "not ... and not ...").

## 5. Definitions

CANONICAL
```
Definition: a page is stale if it was not updated within the last 30 days.
Definition: a deal is urgent if its deadline is in the next 48 hours and its status is active.
Definition: a page is orphaned if it has no incoming links.
Definition: an alert is critical if its severity is "sev1".
```
Usage, everywhere a condition or restriction is legal:
```
for each stale page:
unless the deal is urgent:
the number of orphaned pages
all of the critical alerts are fresh
```
EDGE
- Negation is free: `not stale` needs no second definition.
- Inheritance: an adjective defined on `page` applies to every subkind; the most specific shadowing definition wins; shadowing is lint-flagged (SEM-2-06).
- A definition may use other adjectives (`Definition: a page is risky if it is stale and it is orphaned.`); the dependency graph must stay acyclic.
- Temporal adjectives (bodies containing temporal operators) are legal and three-valued capable; they REQUIRE a keying declaration tying the kind instance to event subjects (Part IV.19; Risks 1.3).
ILL-FORMED
- Cycle -> MER-DEF-001 (the cycle's member definitions listed with spans).
- Uncheckable body (`if it seems useful`) -> MER-DEF-002 (suggest judgment step or measurable property).
- Adjective name equals an enum value on the same kind or any kind in its lattice path -> MER-DEF-003.
- `Definition: a page is stale.` (no if-clause) -> MER-DEF-004 (a definition needs a condition; for an enum-like flag use `can be`).

## 6. Quantifiers

CANONICAL
```
all of the meetings have a brain page
any open alerts are critical
no urgent deals whose owner is the user exist
at least 3 stale pages mention the entity
at most 2 of the candidates are flaky
exactly 1 row in the dispatch table matches the trigger phrase
```
ALSO PARSES: `every meeting has a brain page` -> all-form; `some` -> any; `none of the` -> no.
EDGE (pin all of these)
- Empty domain: `all` is vacuously true; `any` is false; `no` is true; `at least 1` is false; `exactly 0` is true.
- Single fetch: the quantified collection is fetched once per evaluation (SEM-2-01); a test with a mutating mock tool proves stability.
- Nesting: `all of the services that the user owns have at least 1 fresh deploy` (quantifier inside quantifier's restriction) is legal; depth is unbounded in grammar, lint warns above depth 3.
ILL-FORMED
- `most meetings` -> MER-QNT-001 (most unsupported; use at least N or a statistical form).
- `a few pages` / `several deals` -> MER-QNT-002 (vague cardinality; numeric forms listed).

---

# PART II: THE DOMAIN LANGUAGE

## 7. Kinds, properties, enums, defaults

CANONICAL (Domain section or merconfig only)
```
A deal is a kind of page.
A page has a text called the summary.
A deal has a date called the deadline.
A deploy has a duration called the build time.
A page can be archived or live. A page is usually live.
A service is keyed by the name.
```
EDGE
- Single inheritance only; the lattice roots at `value`.
- `can be` with 3+ values: `A ticket can be open, triaged, or closed.`
- `keyed by` declares the identity property used by temporal adjectives and trace subjects (Risks 1.3). One key per kind; subkinds inherit it.
- Position rule (the assertion/condition split): these sentences are assembly-time assertions; the identical words inside a procedure are conditions or errors.
ILL-FORMED
- Domain sentence in a Phases step -> MER-DOM-001.
- Contradictory defaults -> MER-DOM-002 (both spans).
- `A deal is a kind of page. A page is a kind of deal.` -> MER-DOM-003 (lattice cycle).
- Two properties with one name on one kind path -> MER-DOM-004.

## 8. Relations

CANONICAL
```
Ownership relates one engineer to various services.
Mentioning relates various pages to various entities.
Assignment relates one engineer to one task.
Ownership is read from the service's owner.
Mentioning is read via the link tool.
```
Arity grid: one-to-one, one-to-various, various-to-one, various-to-various; all four must have tests.
EDGE
- Backing freshness: a relation is evaluated at the governing fetch point, like everything else; two fetch points may see different ownership. This is the meaning, not a bug; pin it.
ILL-FORMED
- Unbacked relation -> MER-REL-001.
- Arity violation observable at compile time (a one-to-one backed by a list property) -> MER-REL-003.

## 9. Verbs

CANONICAL
```
The verb to own means the ownership relation.
The verb to mention means the mentioning relation.
The verb to be assigned to means the reversed assignment relation.
```
Irregular morphology declared inline:
```
The verb to own (he owns, it is owned) means the ownership relation.
```
The three usage forms, all printing canonically:
```
if the user owns the service:                      (active condition)
for each service owned by the user:               (passive participle restriction)
the services that the user owns                   (relative clause, object gap)
```
EDGE
- Default morphology is regular (+s, +ed); declare irregulars or get the regular form, which may read oddly but is unambiguous.
- `reversed` flips argument order so both directions of a relation get natural verbs without a second relation.
ILL-FORMED
- Undeclared verb in a restriction -> MER-REL-002 (declared verbs listed).
- Participle/adjective collision: declaring verb `to archive` when adjective `archived` exists via enum on the same kind -> MER-REL-004 (the participle "archived" would be ambiguous; rename one).

## 10. Tables

CANONICAL
```
## Tables

| trigger phrase (text) | skill (skill name) |
| --------------------- | ------------------ |
| "daily briefing"      | briefing           |
| "capture thought"     | capture            |
```
Usage:
```
for each row in the dispatch table:
the skill corresponding to the trigger phrase "daily briefing" in the dispatch table
if exactly 1 row in the dispatch table matches the trigger phrase:
```
EDGE
- Column kinds: annotated in the header; unannotated columns infer text. Enum and declared-kind columns validate per cell.
- Lookup miss on `corresponding to` is a runtime error through recover; the existence-guarded form above is the safe idiom; the cookbook pairs them deliberately.
- Tables are constants: no runtime mutation; a mutable table is a tool, not a table.
ILL-FORMED
- Cell kind violation -> MER-TBL-001 (row, column named).
- Duplicate key values in a column used by `corresponding to` -> MER-TBL-002 (lookups need uniqueness; both rows named).

---

# PART III: THE WORKFLOW SURFACE

## 11. Commands and typed holes

CANONICAL
```
fetchctl pull --service "{the service's name}"
```
Inline list form with annotation (desugars; annotation survives as a comment):
```
- `gbrain search "{the attendee's name}"` -- find their brain page
```
Escaping and quoting rules (all pinned by tests):
- `{{` and `}}` are literal braces in commands; single-brace holes are references.
- A hole inside double quotes shell-escapes the value (`"`, `\\`, backtick, `$`).
- A hole outside quotes interpolates verbatim; lint warns if the value kind is text (spaces will split arguments).
ILL-FORMED
- Unresolvable hole -> MER-REF-001 (in-scope names listed).
- Instructional hole (`{pick a good query}`) -> MER-REF-002.
- Hole in a non-command context (`let the x be {the y}`) -> MER-REF-005 (holes are command syntax; use plain reference).

## 12. Iteration

CANONICAL
```
for each deal whose status is active and whose deadline is in the next 7 days, sorted by deadline, ascending:
for each of the first 5 stale pages:
for each row in the escalation table:
for each critical open alert:
```
EDGE
- Source order is meaningful and preserved when no sort is given (D0).
- `the first 5` applies after filtering and sorting (query-plan order: source, filter, sort, take); a test pins the order.
- Iteration variable is the singular kind noun (`the deal`, `the row`, `the page`) and `it`.
ILL-FORMED
- `for each deal, probably the big ones:` -> MER-DSC-002 (restrictions are whose/adjective/verb clauses; vague restriction rejected).

## 13. Branching

CANONICAL
```
if <condition>:
otherwise:
unless <condition>:
only when <condition>:
if it is unknown whether <condition>:
```
EDGE
- `unless C` is exactly `if not C`; prints as written (both are canonical for their own keyword; this is the one sanctioned print synonym pair, because rewriting unless to if-not damages readability; the IR records which keyword was used).
- The unknown arm: required at any decision point whose condition is possibly-indeterminate (Part V; Risks 1.2). Order of arms: unknown arms may appear in any position; canonical print places them after the true-arm and before otherwise.
ILL-FORMED
- Possibly-indeterminate branch without unknown arm or otherwise -> MER-STA-001.
- `if maybe the page is stale:` -> MER-CND-012 (maybe is not an operator; the unknown-arm form shown).

## 14. Bindings, descriptions as values, counting, superlatives

CANONICAL
```
let the candidates be the stale pages that mention the entity.
let the posture be "halt".
proceed, and note "thin history" in the receipt trailer.
the number of urgent deals
the list of services owned by the user
the most recent timeline entry
the oldest stale page
the largest deal by amount
```
EDGE
- `let` bindings are single-assignment; rebinding uses the existing rebind primitive surface (`now let the posture be "watch".` prints with `now` to mark mutation visibly).
- `proceed, and note "<text>" in the <binding>` requires the named binding to be an already-declared `text` binding. The form appends deterministically and desugars to existing bind/rebind behavior; it does not introduce a new primitive.
- Superlative grammar: `the most/least <gradable> <kind>` only for adjectives declared with a measurable backing; otherwise the `by <property>` form is mandatory (MER-DSC-001). Ties: superlatives over a tie take the first in query-plan order; lint notes the tie possibility when the property is not declared unique.
ILL-FORMED
- `let the candidates be some good pages.` -> MER-DSC-002.
- Rebinding without `now` -> MER-BND-001 (rebinding must be visible; add "now").
- `proceed, and note "thin history" in the receipt trailer.` where `receipt trailer` is undeclared -> compile error (`MER-REF-004` family).
- `proceed, and note "thin history" in the retry count.` where `retry count` is non-text -> compile error (`MER-TYP-001`).

## 15. Judgment blocks (the quarantine)

CANONICAL
```
use judgment to compose the status narrative, producing a text called the narrative, using gbrain search and slack.read:
    Weigh stability against urgency. Keep it under five sentences. Lead with the posture.
```
Contract anatomy (all kernel, all checked): purpose phrase; `producing a <kind> called <name>` (output binding, type-checked downstream); `using <tool list>` (scope, must be within the skill's permissions). The indented prose is verbatim and unparsed, forever.
EDGE
- Multiple outputs: `producing a text called the subject and a text called the body`.
- A judgment block with no `using` clause has zero tool access (pure text transformation); pin this.
ILL-FORMED
- `use judgment to update the database:` (no produced binding, effectful intent) -> MER-JDG-001 (judgment produces values; effects happen in kernel steps that consume them).
- Tool in `using` outside the skill's permission scope -> MER-DEO-004.

## 16. Output templates

CANONICAL
```
[Run: {{ the run id }}]
Posture: {{ the posture }}
[if the service is flaky]This service is flaky.[otherwise]Deploy history is clean.[end if]
[if it is unknown whether the service is flaky]Deploy history is too thin to judge.[end if]
[for each critical open alert]- {{ the alert's severity }} opened {{ the alert's opened at as a short date }}[end for]
{{ the narrative }}
```
Formatter registry (closed, v1): `as a short date`, `as a long date`, `as an integer`, `as a decimal with <n> places`.
EDGE
- Nesting: `[for each]` inside `[if]` and vice versa, two levels tested.
- Whitespace policy: template line breaks are literal; `[end for]` consumes its trailing newline so loops do not double-space. Pin with golden output.
ILL-FORMED
- Unknown formatter -> MER-FMT-001.
- Unclosed `[if]` -> MER-FMT-002 (span of the opener).
- `{{ judge the best title }}` -> MER-REF-002 (templates substitute values; judgment happens in steps).

---

# PART IV: THE TEMPORAL LAYER

## 17. Event patterns (the predicate grammar over the trace)

An event pattern names what to look for in the trace. Components, all optional except the head:
```
the deploy step                         (step subject, by step name)
the fetch step of the briefing skill    (step subject scoped to a skill)
a production deploy                     (kind-flavored event noun bound via keying)
slack.send                              (tool subject)
```
Outcome verbs (closed): `has failed`, `has succeeded`, `was invoked`, `was emitted`, `was prevented`, `was violated`.
Payload restrictions reuse kernel comparators over declared payload schemas:
```
deploy.run whose target is production
slack.send whose channel is "#incidents"
```
ILL-FORMED
- Unknown step name -> MER-TMP-014 (declared step names in scope listed).
- Payload restriction on an undeclared payload field -> MER-TMP-015.

## 18. The operators (each with edge cases)

18.1 EVER
```
if the deploy step has ever failed:
```
ALSO PARSES: `has previously failed`, `has failed before`.
EDGE: "ever" means within retention (D1); the docs say so once, the compiler enforces window arithmetic everywhere else.

18.2 WITHIN-WINDOW
```
if the deploy step has failed within the last 24 hours:
```
EDGE: window boundary is closed at the old end (`t - 24h <= at <= t`); pin with an event exactly on the boundary.

18.3 COUNT-IN-WINDOW
```
if the deploy step has failed at least 2 times within the last 7 days:
if slack.send was invoked at most 10 times within the last 1 hours:
```
EDGE: `at most` with zero matches is true; `exactly 0 times` is the idiomatic never-in-window form and must parse.

18.4 IN-A-ROW (the qualifying-subsequence rule, SEM-5-05)
```
if the deploy step has failed 2 times in a row:
```
EDGE, the canonical contrast: qualifying events are deploy-step completions regardless of outcome; the claim is about the most recent N of those. Sequence success, failure, failure: count-in-window(2,7d) true AND in-a-row(2) true. Sequence failure, success, failure: count true, in-a-row FALSE. Both orderings are mandatory tests, plus interleaved events of other subjects and other runs that must not break the subsequence.

18.5 SINCE-THE-LAST
```
since the last production deploy, no critical alert has occurred
```
EDGE: anchor is the most recent matching event; condition is checked over events strictly after it. No anchor: INDETERMINATE (D7), totality applies. Anchor exactly at t: window after it is empty, condition over events vacuously per its own quantifier.

18.6 SCOPE MARKER
```
if, across all runs, the export step has failed at least 5 times within the last 30 days:
```
EDGE: default scope is the current run; `across all runs` is the only widening; it scopes the whole operator, not the whole condition; two operators in one condition may have different scopes and the verbalizer must keep the markers adjacent to their operators.

## 19. Temporal adjectives and keying

CANONICAL
```
A service is keyed by the name.
Definition: a service is flaky if its deploy step has failed at least 2 times within the last 7 days.
```
The keying rule (Risks 1.3): inside a temporal definition on kind K, event patterns are implicitly restricted to events whose subject key equals the instance's key. Without a declared key, a temporal definition on that kind is ill-formed.
ILL-FORMED
- Temporal definition on an unkeyed kind -> MER-TMP-016 (add `keyed by` or query globally via a workflow-level condition instead).

## 20. Ill-formed temporal sentences (the layer's character lives here)

- Bare perfect `if the deploy step has failed:` -> MER-TMP-010 (three rewrites offered: ever / within window / N times in a row).
- Window exceeds retention -> MER-TMP-011 (both durations named; raise retention or narrow window).
- Causal since `since the page is stale, refresh it` -> MER-TMP-012 (since is temporal; use if).
- Future tense `if the deploy step will fail` -> MER-TMP-013 (proof-mode only, unsupported).
- `has failed recently` -> MER-TMP-017 (recently is vague; window forms listed).
- `has been failing` -> MER-TMP-018 (progressive aspect unsupported; in-a-row or count forms offered).

---

# PART V: THE STATISTICAL LAYER

CANONICAL
```
the fetch step succeeds in at least 95% of runs, checked every 1 days
if the export step fails in at most 5% of occurrences:
if it is unknown whether the export step fails in at most 5% of occurrences:
```
ALSO PARSES: `usually succeeds` (prints numerically per configured P_u), `rarely fails` (per P_r).
EDGE
- Denominator words: `of runs` counts per-run outcomes; `of occurrences` counts per-event. Both must be tested against the same trace with different answers.
- Sample floor: below n0 the value is indeterminate (D2); a monitor records outcome indeterminate, never false.
- Monitors (`checked every <duration>`) are Contract-section forms; the same sentence without cadence in a branch is an inline evaluation at that decision point.
ILL-FORMED
- Missing unknown handling at a dependent decision point -> MER-STA-001.
- `with 95% confidence` -> MER-STA-002 (reserved).
- `succeeds most of the time` -> MER-STA-003 (numeric or usually/rarely forms listed).
- A statistical operator inside a definition on an unkeyed kind -> MER-TMP-016 (same keying rule).

---

# PART VI: THE DEONTIC LAYER

CANONICAL
```
This skill must not invoke deploy.run whose target is production.
The sentinel may invoke slack.send only where the channel is one of #incidents, #alerts, #releases.
Every emitted note matches pattern "\[Run: .+\]" .
Since the last production deploy, no critical alert has occurred. This must hold, blocking.
The posture must be one of "halt", "watch", "proceed". This must hold.
```
Scope attachment: workflow-level sentences bind the whole skill; Contract-section items bind the skill; section-prefixed forms (`Within Phase 3, this skill must not ...`) bind that section; kind-scoped norms live in Domain.
EDGE
- `blocking` on an obligation routes violation to recover and halts the section; non-blocking records `violated (observed)` and continues. Default is non-blocking; the keyword is the only way to block, so reading the Contract tells you exactly what can stop the skill.
- Permissions generalize scopedTools: a bare tool id is the degenerate `may invoke <tool>`; mixing bare ids and conditioned permissions is legal.
- Prevented prohibitions are witnessed: the trace shows `violated (prevented)`; auditors see attempts, not just outcomes.
ILL-FORMED
- Same-scope grant and prohibition overlap -> MER-DEO-001 (both spans; no silent winner).
- Inner `may` against outer `must not` -> MER-DEO-002 (deny is sticky downward).
- `should`, `ought to`, `probably must` -> MER-DEO-003 (norms are must / must not / may).
- Judgment block using a tool outside permissions -> MER-DEO-004.
- `must not fail` -> MER-DEO-005 (outcomes are not actions; prohibit invokes or assert conditions).

---

# PART VII: COMPOSITION GALLERY (cross-layer sentences that must all parse)

Each line is a single test of layers composing; these are the sentences that break naive implementations.

```
1.  for each flaky service owned by the user, sorted by name:                     (temporal adjective + verb clause + sort)
2.  if all of the services that the user owns are flaky:                          (quantifier over verb clause over temporal adjective; three-valued: any unknown makes the all unknown unless falsified)
3.  Definition: a service is troubled if it is flaky and at least 1 critical alert whose service name is its name is fresh.   (definition composing temporal adjective, quantifier, payload-style restriction, and "its" keying)
4.  since the last deploy of the most recent troubled service, no slack.send whose channel is "#incidents" was invoked        (superlative inside an event pattern's subject; legal, ugly, and a lint candidate: pin that it parses, lint that it should be two steps)
5.  the number of rows in the escalation table whose channel is "#alerts"          (counting over table rows with restriction)
6.  This skill may invoke slack.send only where the channel is the channel corresponding to the severity "sev2" in the escalation table.   (permission condition referencing a table lookup; evaluated per attempt)
7.  if it is unknown whether all of the services owned by the user are flaky:      (unknown-arm over a quantified three-valued condition)
8.  [for each of the first 3 troubled services]{{ its name }}: {{ the number of fresh critical alerts whose service name is its name }} open[end for]   (template loop + count + keyed restriction)
```
Every gallery line gets: a parse test, a verbalization round-trip test, and (1, 2, 3, 7, 8) an evaluation test over a fixture trace.

---

# PART VIII: NEGATIVE SPACE (English that deliberately does not parse)

The language's shape is defined as much by exclusions. Each exclusion states its rationale; these belong in user docs nearly verbatim.

- Vague hedges (`roughly`, `about`, `a few`, `recently`, `most`, `probably`): vagueness is quarantined to judgment blocks; the kernel is for claims that can be checked. MER-CND-001, MER-QNT-002, MER-TMP-017.
- Bare perfects (`has failed`): English's perfect aspect smuggles an unspecified window; Meridian makes the window mandatory. MER-TMP-010.
- Progressive aspect (`is failing`, `has been failing`): trends are statistical or count claims; say which. MER-TMP-018.
- Causal connectives (`because`, causal `since`, `therefore`): the kernel records what and when; why lives in prose and judgment. MER-TMP-012.
- Modality outside norms (`should`, `might`, `could`): obligations are must/may; possibility claims are statistical. MER-DEO-003.
- Future tense (`will fail`): the executable language evaluates the witnessed past; the future belongs to proof mode, later. MER-TMP-013.
- Imperatives aimed at the model inside kernel steps (`figure out the best X`): instructions to think are judgment blocks by definition. MER-REF-002, MER-JDG-001.
- Anthropomorphic subjects (`the system wants`, `the skill believes`): no internal-state fiction in a language whose claims must be checkable.

---

# PART IX: ERROR CODE CATALOG (problem-message seeds)

Format per Wave 5D: code, stable since, message skeleton (quote span; what was understood; what was expected; suggestion). One worked full text, then the table.

WORKED EXAMPLE, MER-TMP-010:
```
Problem MER-TMP-010 in release-sentinel.meri, line 41:
    if the deploy step has failed:
I read "the deploy step has failed" as a claim about past events, but it does not
say which past. Temporal claims need an explicit reach. I know three forms:
    if the deploy step has ever failed:
    if the deploy step has failed within the last 24 hours:
    if the deploy step has failed 2 times in a row:
```

| Code | Layer | Trigger (short) |
| --- | --- | --- |
| MER-LIT-001/002 | literals | decimal comma; unit agreement |
| MER-REF-001..005 | references | unresolvable hole; instructional hole; missing possessive; ambiguous name; hole outside command |
| MER-CND-001/002/010/011/012 | conditions | unknown comparator; near-miss spelling; mixed and/or; nor; maybe |
| MER-TYP-001 | types | incomparable kinds |
| MER-DEF-001..004 | definitions | cycle; uncheckable; adjective/enum collision; missing if-clause |
| MER-QNT-001/002 | quantifiers | most; vague cardinality |
| MER-DOM-001..004 | domain | declaration in procedure; contradictory defaults; lattice cycle; duplicate property |
| MER-REL-001..004 | relations/verbs | unbacked; undeclared verb; arity violation; participle collision |
| MER-TBL-001/002 | tables | cell kind; duplicate lookup key |
| MER-DSC-001/002 | descriptions | ungraded superlative; vague restriction |
| MER-BND-001 | bindings | invisible rebinding |
| MER-JDG-001 | judgment | effectful judgment without produced value |
| MER-FMT-001/002 | templates | unknown formatter; unclosed block |
| MER-TMP-010..018 | temporal | bare perfect; window>retention; causal since; future; unknown step; unknown payload field; unkeyed kind; recently; progressive |
| MER-STA-001..003 | statistical | missing unknown handling; confidence reserved; vague frequency |
| MER-DEO-001..005 | deontic | conflict; sticky deny; non-norm modal; tool scope; outcome-as-action |

Every code requires: one positive trigger test, one near-miss test that must NOT trigger it, and a message-snapshot test (stable code, evolvable wording).

---

# PART X: GLOSSARY (one name per concept, used in every doc, error, and report)

- adjective: named predicate on a kind, created by a Definition; may be temporal.
- canonical English: the unique print form per construct; what `meridian explain` shows.
- decision point: a branch condition or blocking obligation, where totality of three-valued logic is enforced.
- description: noun phrase denoting an ordered list: kind head + restrictions (adjectives, whose-clauses, verb clauses) + ordering + take.
- drift: categorized diff between authored and canonical English (synonym, structure, desugar, meaning-bearing).
- event pattern: predicate over trace events (subject, outcome verb, payload restrictions).
- fetch point: the named instant a collection or backing is read; everything inside one sees one snapshot.
- indeterminate / unknown: the third truth value; from sample floors and anchorless since; surfaced as `it is unknown whether`.
- keying: the declared identity property binding kind instances to event subjects.
- norm: prohibition, obligation, or permission; scope-attached.
- obligation artifact: emitted JSON record of a norm or contract claim, stable id.
- qualifying subsequence: for in-a-row, the outcome-agnostic event sequence the claim ranges over.
- query plan: source, filter, sort, take; the meaning of a description.
- retention (rho): the configured trace window; the closed world of every temporal claim.
- scope (temporal): current run, or across all runs.
- window: a metric duration bound; always within retention.
