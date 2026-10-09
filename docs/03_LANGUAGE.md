# Meridian — Language

The author-facing language reference: `.merconfig` vocabulary, `.meridian`
workflow surface, the recurring architectural patterns behind its restrictions,
`.merrules` rulebooks, prose/autonomy modes, deontic norms, and shared module
imports. Normative semantics live in [`cookbook/`](cookbook/).

---

Two file types: `.merconfig` (vocabulary) and `.meridian` (workflows).

For normative semantics and canonical surface forms (Waves 7–8 oracle), see
[`docs/cookbook/`](cookbook/) — especially `MERIDIAN_SYNTAX_COOKBOOK.md` and
`MERIDIAN_SEMANTICS.md`. This quick reference is the practical author guide;
the cookbook is the test-backed oracle.

---

## `.merconfig` file

### Sections

```
=== vocabulary ===
=== constants ===
=== instances ===
=== tools ===
```

Sections are delimited by `=== name ===` headers (case-insensitive).
Lines are indentation-sensitive. A line ending in `.` terminates a statement.

---

### Vocabulary section

#### Kind declarations

```
A mailer server is a kind of system.
An order is a kind of thing.
A customer is a kind of person.
```

Wave 4 also accepts domain declarations inside a `.meri` `## Domain` section.
Those declarations are harvested before workflow parsing, so frontmatter
parameters and later procedure statements can reference the newly-declared kinds.

**Semantic bases** — pick the one that matches the kind's role; the type
system carries that role through every workflow that references the kind.
Each base maps to a `Meridian<Base>` runtime protocol; the kind's generated
`<KindName>Kind` protocol composes that base.

| Use | When |
|---|---|
| `kind of thing` | Generic identity-bearing entity (order, repository, customer). |
| `kind of event` | Something that occurred — emit/wait/observability records (`audit note`). |
| `kind of action` | A discrete operation a workflow can take (`remediation task`). |
| `kind of tool` | A domain capability or instrument that does work (`linter`, `repair tool`, `retriever`). |
| `kind of system` | External/internal platforms, products, or servers (`mailer server`, `GitHub`, `Stripe`). |
| `kind of integration` | Configured connectors, accounts, webhooks, or adapters (`GitHub app`, `Slack webhook`). |
| `kind of artifact` | Software/work products (`repository`, `pull request`, `patch`, `report`, `build log`). |
| `kind of service` | Hosted APIs or service endpoints (`payment processor`, `embedding service`). |
| `kind of agent` | Autonomous AI/software actors (`review agent`, `release bot`). |
| `kind of model` | LLMs, embedding models, classifiers, or evaluators. |
| `kind of dataset` | Corpora, eval sets, indexes, or knowledge bases. |
| `kind of storage` | Databases, buckets, queues, caches, vector stores, or artifact registries. |
| `kind of credential` | API keys, tokens, secrets, service accounts, or auth configs. |
| `kind of policy` | Guardrails, routing rules, approval policies, or retention policies. |
| `kind of environment` | Runtime targets and boundaries (`prod`, `staging`, `tenant`, `cluster`). |
| `kind of resource` | Infrastructure or allocatable capacity (`host`, `container`, `compute job`). |
| `kind of metric` | Measured signals, SLOs, eval scores, or quality indicators. |
| `kind of memory` | Agent/session memory, retained context, conversation history, or long-term knowledge. |
| `kind of process` | A long-running unit of work with lifecycle state (`incident`, `deployment run`). |
| `kind of message` | A one-way communication payload (`review comment`, `notification`). |
| `kind of signal` | A named broadcast workflows can `wait for` or deliver. |
| `kind of fact` | Asserted knowledge / evidence (`vulnerability`, `claim`). |
| `kind of role` | An actor identity used in permissions and approvals (`reviewer`, `account manager`). |
| `kind of verdict` | A decision outcome (`approval`, `policy decision`). |

Prefer the most specific base. `kind of thing` is the safe fallback when
none of the semantic bases fit.

**Scalar bases** (`String`, `Number`, `Money`, `Date`, `DateTime`, `Boolean`,
`Duration`, `List`, `Reference`) collapse to a `typealias` — no protocol or
struct is generated.

```
An email address is a kind of String.
→ public typealias EmailAddress = String
```

**Chained inheritance**: `A customer is a kind of person.` chains
`CustomerKind: PersonKind` and `Customer` flattens all properties from
`Person` plus its own.

#### Declarative properties and states

```
A page has a text called the summary.
A page can be draft or published, called the lifecycle.
A page is usually draft.
```

`called the` names a typed property from the leading type noun. `can be ... or
...` declares an enum-backed state property; without `called the`, the property
name is derived as `<kind> state` (for example `pageState`). `usually` sets the
generated Swift initializer default for the matching enum case.

### Tables

Markdown pipe tables are executable data when marked explicitly or when they
appear under a `.meri` `## Tables` section:

```
## Tables
| trigger phrase | skill | score (Number) |
| --- | --- | --- |
| daily briefing | briefing | 10 |
```

Unmarked tables outside `## Tables` remain decision tables. A data table binds a
`Value.list` of records; annotated headers such as `score (Number)` validate
cells and report row/column coordinates. Lookups use:

```
the skill corresponding to the trigger phrase "daily briefing" in the table
```

A required miss throws `table.lookup_miss`, so `recover from "table.lookup_miss":`
can handle it.

### Text Substitutions

Fenced string templates support expression holes plus closed directives:

```
[if the score is more than 5]high[otherwise]low[end if]
[for each row in rows]{{ row.name }}[end for]
{{ total as a integer }}
```

Only `[if ...]`, `[otherwise]`, `[end if]`, `[for each ...]`, and `[end for]`
are directives; other bracketed text such as `[date]` stays literal. Template
holes use double braces `{{ expr }}` (B7); shell-command holes stay single
`{…}`. `meridian explain` re-emits the B7 `{{ }}` form for fenced templates.

**Empty-protocol elision**: a leaf kind with no own properties and no
descendants gets a struct only — no `<KindName>Kind` protocol is emitted,
because an empty protocol composing the parent adds nothing the parent
doesn't already give us. The struct conforms directly to the parent
protocol (`Meridian<Base>` or `<Parent>Kind`).

```
A comment is a kind of thing.
→ public struct Comment: MeridianThing { public var id: String; … }
```

To force a named protocol for a property-less kind, give it at least one
property or declare a child kind that inherits from it (the chain-anchor
case keeps the protocol).

#### Property declarations

```
A mailer server has a host, a port, and an auth type.
A customer has an id, an email, a signup date, and an account manager.
An order has an id, a total amount, and a status.
An order has a status, which is one of (draft, submitted, approved, rejected).
```

The `which is one of (…)` form emits a typed Swift enum at codegen time.

#### Phrase definitions

```
To validate an order:
  invoke validate order with id = the order's id.

To reject an order with a reason:
  invoke update order with id = the order's id, status = "rejected".
  emit order.rejected with
    order = the order,
    reason = the reason.

To notify a person that their order is on hold because of a reason:
  send an email via the primary mailer,
    to the person's email,
    with subject line "Your order is on hold",
    and message body the reason.
```

**Multi-line phrase headers** are supported — indent continuation lines deeper
than the `To` keyword:

```
To send an email via a mailer server,
              to an email address,
              with a subject line,
              and a message body:
  invoke send email with
    via = the mailer server,
    to = the email address,
    subject = the subject line,
    body = the message body.
```

**Article tolerance:** `with reason "X"` and `with a reason "X"` both work
for a slot declared as `a reason`.

---

### Constants section

```
The default currency is "USD".
The high value threshold is $5000.
The maximum retry count is 3.
The new customer threshold is 30 days.
The fraud risk threshold is 0.5.
```

Supported literal kinds:

| Syntax | Type |
|---|---|
| `"string"` | String |
| `42` | Integer |
| `0.5` | Double |
| `$5000` | Money (USD) |
| `$5000.00 AUD` | Money (explicit currency) |
| `30 days` / `2 hours` / `1 week` | Duration |
| `true` / `false` | Bool |

---

### Instances section

```
There is a mailer server called primary mailer:
  host = $SMTP_HOST
  port = 587
  auth type = "tls"

There is a payment processor called stripe:
  api endpoint = "https://api.stripe.com/v1"
  api key = $STRIPE_API_KEY
```

Properties may be string literals or `$ENV_VAR` references.
Instances are emitted as the generated `Instances` struct; codegen writes
`instances.primaryMailer`, `instances.stripe`, etc.

---

### Tools section

```
Validate Order
==============
-- Validates an order. Returns a validation result with a verdict.
~ validateOrder(id: String) : ValidationResult

Charge Payment
==============
-- Charges a customer. Returns a payment result.
~ chargePayment(via: String, customer: String, amount: Decimal) : PaymentResult
```

Format: `~ methodName(param: Type, …) : ReturnType`

---

## `.meridian` file

### Frontmatter and vocabulary

`.meridian` (and `.meri`) files declare their vocabulary dependencies
exclusively in frontmatter. Frontmatter MUST be the first entry in the
file — only blank lines may precede the opening `---`. Multiple
vocabularies are listed comma-separated under `vocabulary:`.

```
---
name: order processor
goal: Validate, charge, and finalise customer orders.
parameters: order, customer
vocabulary: ecommerce.merconfig, payments.merconfig
---
```

Each entry must name a vocabulary that's present in the compile
invocation (`--merconfig path.merconfig`, repeatable; auto-discovered if
omitted). Duplicate kinds / phrases / tools / constants / instances
across the merged set are rejected at compile time. The previous
body-level `import vocabulary from "..."` and `import name.` syntaxes
have been removed; the parser emits a structured diagnostic if either
appears in the source.

### Workflow declarations

```
To {phrase pattern}:
  {statements}
  complete.
```

### Canonical English and verbalization

Wave 7 defines a canonical print form for the compiled IR. `meridian explain`
compiles a `.meridian` / `.meri` file, then prints the lowered model back as
Canonical English:

```bash
meridian explain sample-gbrain/skills/capture.meri \
  --merconfig sample-gbrain/brain.merconfig \
  --rulebook sample-gbrain/brain.merrules
```

Canonical English is not a formatter and not a source-preserving Markdown
round-trip. It normalizes accepted synonyms and rulebook sugar to one stable
surface (`exceeds` -> `is more than`, `Check:` -> `assert`, `let ... be` ->
`bind ... = ...`) and omits documentation that does not lower to IR. The law is
semantic: compiling the canonical output must produce structurally equal IR
(`SEM-8-03`). Use `meridian drift` to audit authored-vs-canonical differences.
See [06_DEVELOPER_EXPERIENCE.md](06_DEVELOPER_EXPERIENCE.md).

### Execution modes

```
To leniently sync analytics for an order placed by a customer:
  in lenient mode.
  emit analytics.order_processed with …
  complete.
```

`in lenient mode.` — emits do not throw; failures are silent.
`in strict mode.` — (default) any emit failure propagates.

---

## Statements

| Statement form | IR primitive |
|---|---|
| `validate the order.` | phrase invocation → inlined |
| `bind result = invoke validate order with id = …` | `bind` |
| `rebind retry count = invoke get retry count with …` | `rebind` |
| `emit order.approved with order = the order.` | `emit` |
| `if the amount is more than the threshold,` | `branch` |
| `wait 1 hour.` | `wait` (duration) |
| `wait for signal "payment_confirmed".` | `wait` (signal) |
| `wait for approval of the order from an account manager.` | `wait` (approval) |
| `wait for event order.confirmed matching the order's id equals the order's id.` | `wait` (event) |
| `for each item in the order's items,` | `iterate` |
| `assert the order's status is "active".` | `assert` |
| `commit with label "payment_done".` | `commit` |
| `complete.` | `complete` |
| `complete with reason "fraud_rejected".` | `complete` |
| `reject the order with reason "invalid".` | phrase → emit + complete |
| `recover from any:` | `recover` (any error) |
| `recover from payment.declined:` | `recover` (named) |
| `recover where the error code equals "timeout":` | `recover` (predicate) |
| `simultaneously:` | `simultaneously` |

---

### Conditionals — three modalities

A predicate branch may be written **multi-line** (comma-terminated header + an indented
body) or **single-line** (the action follows the comma on the same line). The
comma after the condition is the delimiter in both, so the single-line form
reads as plain English:

```
if the entity does not link to the input, add a back-link from the entity to the input.
```

is exactly equivalent to

```
if the entity does not link to the input,
  add a back-link from the entity to the input.
```

The single-line form also takes an optional `, otherwise <action>` tail for the
else-block (`if ci is passed, complete, otherwise complete with reason "blocked".`).
The condition/action split is the first top-level comma outside quotes that is
not an Oxford `, and`/`, or` joiner, so multi-argument actions
(`emit e with a = 1, b = 2`) and grouped conditions still parse. (Per-line guard
forms `<action> only when <cond>` / `<action> unless <cond>` remain available.)

The third modality is **match-branch** (`branch on <expr>:`), with indented
`pattern:` arms and an optional `otherwise:` default (IR `thenBlock` → Swift
`default:`). Patterns are string literals, bare enum identifiers, or
`anything`/`_`. See [06_DEVELOPER_EXPERIENCE.md](06_DEVELOPER_EXPERIENCE.md) §Match-branch.

### `wait` forms

Duration wait — suspends for a fixed duration:

```
wait 1 hour.
wait 30 days.
```

Signal wait — suspends until `Runtime.deliverSignal(_:)` is called:

```
wait for signal "payment_confirmed".
```

Approval wait — suspends until `Runtime.deliverApproval(of:by:verdict:)` is called.
A `.denied` verdict throws `MeridianRuntimeError.approvalDenied`:

```
wait for approval of the order from an account manager.
```

Event wait — suspends until a matching event fires via `emit` or `Runtime.deliverEvent(_:)`:

```
wait for event order.confirmed.
wait for event order.confirmed matching the event's order id equals the order's id.
```

An optional `timeout:` parameter is accepted at codegen level; for signal/approval/event
waits it is noted but not enforced in v1 (only `.duration` honours the timeout clock).

---

### `recover` forms

`recover` attaches to the immediately preceding statement and wraps it in a
`do/catch` block. Multiple `recover` clauses after the same statement nest outward.

Catch any error:

```
invoke charge payment …
recover from any:
  put the order on hold with reason "payment_failed".
```

Catch a named error:

```
invoke charge payment …
recover from payment.declined:
  reject the order with reason "card_declined".
```

Catch by predicate:

```
invoke charge payment …
recover where the error code equals "timeout":
  wait 5 minutes.
  invoke charge payment …
```

---

### `simultaneously` form

Run multiple steps in parallel. All branches complete before execution continues:

```
simultaneously:
  fetch the customer profile.
  fetch the order history.
```

---

## Expressions

Wave 5 records the expression/description/template/idiom surface in
`GrammarTable` (`Sources/MeridianCore/Grammar/`) — the single reviewable
registry for anchors, screening, and generated grammar reference text.
`ExpressionParser` dispatches to one independent production unit per
`GrammarTable` entry (`Sources/MeridianCore/Parser/Lexical/Productions/`),
each either a real `pegex` grammar or a dedicated hand-written Swift function
per `GrammarProduction.implementation` — there is one parser implementation
and no rollout flag (see `docs/02_ARCHITECTURE.md`'s
`ExpressionParser.parse` section).

| Form | Example |
|---|---|
| Possessive chain | `the order's total amount` |
| Property access | `the customer's account manager's id` |
| Constant ref | `the high value threshold` |
| Instance ref | `the primary mailer` |
| String literal | `"approved"` |
| Number literal | `3` |
| Comparison | `is more than`, `is less than`, `equals`, `is within` |
| Logical | `and`, `or`, `not` |
| Env var | `$STRIPE_API_KEY` |
| Now | `now` |

### Comparison keywords

The copula (`is`) is **optional** — each comparison has a copula-less form so a
condition reads naturally either way (`the total is greater than 5` ≡ `the total
greater than 5`). The full `… than or equal to` spellings are also accepted
(the marker-internal `or` is shielded from the boolean `or` splitter).

| Phrase | Operator |
|---|---|
| `equals` / `equal to` / `is` | `==` |
| `does not equal` / `is not` | `!=` |
| `less than` / `fewer than` (opt. `is `) | `<` |
| `more than` / `greater than` (opt. `is `) | `>` |
| `at most` / `is no more than` / `less than or equal to` | `<=` |
| `at least` / `is no fewer than` / `greater than or equal to` / `more than or equal to` | `>=` |
| `is within` | `MeridianComparison.isWithin(…)` |
| `contains` | `.contains(…)` |
| `starts with` | `.hasPrefix(…)` |

---

## Pattern parameters

Phrase patterns use `a {kind}` / `an {kind}` / `the {kind}` to declare
parameters. The kind name (one or two words) becomes the parameter name after
snake_casing. It is also the expected Swift type in the generated init.

```
To request approval for an order from an account manager:
  ─────────────────────────────────────────
  Parameters: order: Order, accountManager: AccountManager
```

Multi-word kinds: `a mailer server` → param name `mailer_server`, type `MailerServer`.

---

## Phase 6.5 additions — EnglishLexicon + SKILL-shaped extensions

### Frontmatter / discovery metadata (B1)

A `.meridian` file may begin with an optional `---`-delimited metadata block.
Most keys are descriptive and are emitted under `meridian_skill` in the
companion manifest. The reserved `parameters:` key is executable only when the
file uses top-level statements as an implicit entry workflow.

```
---
name: babysit
description: Keep a PR merge-ready by triaging comments and CI in a loop.
when-to-use: When a PR is open and needs to be driven to merge.
tools-required: gh, git
parameters: pull request
vocabulary: github.merconfig
---

## Comments
- bind comments = invoke list pull request comments with pr = the pull request's number.
- review every comment.
```

The first workflow in the file also receives a `static let skillMetadata: [String: String]`
property containing all frontmatter entries.

### Markdown-shaped workflow surface

For SKILL.md-style files, Meridian accepts a markdown-flavoured surface while
preserving deterministic codegen:

```
---
name: babysit
parameters: pull request
vocabulary: github.merconfig
---

## Comments
- bind comments = invoke list pull request comments with pr = the pull request's number.
- review every comment.

## CI
1. bind ci status = invoke get ci status with pr = the pull request's number.
2. invoke push branch with branch = the pull request's head branch unless the ci status is passed.
```

- `##` / `###` headings are ignored by statement parsing and emitted as
  `meridian_skill.outline` entries in the manifest.
- List markers (`-`, `*`, `1.`) are stripped before parsing, so list items are
  normal Meridian statements.
- If a file has top-level statements and no explicit entry workflow, Meridian
  synthesizes one from frontmatter `name:` and typed `parameters:`.
- `only when` and `unless` suffixes become single-statement branches.
- `every X` / `each X` becomes iteration over the plural collection (`comment`
  → `comments`) with the singular item in scope.
- Naked return-valued `invoke …` statements receive an implicit result binding
  derived from the invocation's object words.
- `if you decide that …` and `unless you decide that …` lower to
  `runtime.discretion.decide(...)` boolean predicates.
- `Label: statement.` creates a topic outline anchor and parses `statement`.
- `do A, B, and C.` splits into multiple same-indent statements.
- `with discretion` allows unmatched prose lines; generated Swift calls
  `runtime.executeProsePlan(...)`.
- `with autonomy` allows autonomous prose loops; generated Swift calls
  `runtime.executeAutonomousLoop(...)`.
- `meridian lint` reports ambiguity and paraphrase hints. `meridian
  preview-skill` previews common `SKILL.md` markdown as Meridian syntax.

#### Reserved frontmatter key — `allow-fallbacks` (no-silent-fallback policy)

By default the compiler refuses to silently substitute a placeholder when
something can't be resolved: an unknown phrase, an unknown tool, an unparseable
rule, a rule whose action verb doesn't match any workflow, or a trigger whose
action doesn't lower. Each of these raises a coded diagnostic (a stable
`MERxxxx` code with a source caret and a did-you-mean — see
[06_DEVELOPER_EXPERIENCE.md](06_DEVELOPER_EXPERIENCE.md)). Set the
`allow-fallbacks` frontmatter key to a comma-separated list of fallback
kinds to opt back into the older silent behaviour for **this file only**:

```
---
name: experimental
allow-fallbacks: unresolved-phrases, unattached-rules
---
```

The five fallback kinds:

| Kind | Code suppressed | What's allowed |
|---|---|---|
| `unresolved-phrases` | `MER2001` | A phrase invocation that doesn't match any phrase or workflow lowers to an `_unresolved` `BindIR` placeholder. |
| `unknown-tools` | `MER2002` | An invoked tool id that isn't a built-in, vocabulary/frontmatter tool, or workflow reference is emitted as-is (for host-provided tools registered at runtime). |
| `unparseable-rules` | `MER1004` | A rule whose text the analyser cannot classify is dropped from IR (still recorded in the manifest). |
| `unattached-rules` | `MER3006` | A rule that classified but matched no workflow is dropped from IR (still recorded in the manifest). |
| `unresolved-trigger-actions` | `MER3007` | A `When …, do X` trigger whose action verb resolves to nothing emits the `trigger.X.fired` fan-out event without validating that the action workflow exists. |

`allow-fallbacks: all` (or `*`) opts into every kind. Without the key, every
listed failure is reported as a sourced compile-time diagnostic pointing at the
offending line. An unrecognized token here is itself an error (`MER2009`).

---

### Goal-driven loops — `until` and `while` (B2)

```
until the ci status is passed,
  bind ci status = invoke get latest ci status with pr = the pull request's number.

while the queue is not empty,
  bind next = invoke dequeue item.
  process the next item.
```

`until` lowers to `repeat { … } while !condition`.
`while` lowers to `while condition { … }`.
Predicates use the full expression grammar including `and`/`or`/`not`.

---

### `decide whether` — LLM discretion (B3)

Workflows annotated `with discretion` may use `decide whether <question>` as
a bind value or as an `if` predicate (via the `discretion says <question>` form):

```
To babysit a pull request, with discretion:
  bind ready = decide whether "the comments are triaged and CI is green".
  if discretion says the user agrees with this change,
    invoke approve pull request with pr = the pull request's number.
```

Both forms lower to `InvokeIR(toolID: "llm.decide", ...)`. The built-in
`llm.decide` tool returns `.boolean(false)` deterministically when no LLM host
is wired (safe for tests).

---

### Fenced Markdown code-block string literals (B6)

Triple-backtick fences become multi-line string literals usable anywhere a
string is accepted — most usefully as LLM prompts:

```
bind judgement = decide using:
  ```
  You are a code reviewer.
  Diff: {{ the diff's content }}
  Should we merge? Answer yes or no.
  ```
```

The fence body is dedented relative to the opening ```` ``` ```` column.
An optional language tag after the opening fence is recorded but ignored at
codegen time.

---

### `{{ expression }}` interpolation inside code blocks (B7)

Any `{{ expr }}` inside a fenced block is expanded at runtime. The expression
inside the braces uses the full Meridian expression grammar (possessive chains,
comparisons, etc.). Escape a literal `{{` with `\{{`.

The resulting AST node is `ExpressionAST.interpolatedString([…])`, lowered to
`IRExpression.interpolatedString([…])`, and codegen emits a
`Value.string([…].joined())` expression using `meridianStringify` for non-string
values.

---

### `=== language ===` vocabulary synonyms (A2)

A `.merconfig` may define a `language` section with comparison and duration
synonyms that extend the compiler's default English surface for that domain:

```
=== language ===
Comparison synonyms:
  exceeds = is more than
  below = is less than
  at least = is greater than or equal to
Duration synonyms:
  fortnight = week
  hr = hour
Assertion synonyms:
  verify
  guarantee that
```

Synonyms are merged into the `EnglishLexicon` before parsing begins. They take
priority over defaults (prepended to the comparison-marker list).

`Assertion synonyms:` lists bare leading keywords that introduce an
invariant/assertion statement, alongside the built-in `make sure`, `ensure`,
and `assert`. Each entry is the literal phrase that precedes the condition
(`verify the score is more than 100.`). The merged set is de-duplicated and
sorted longest-first, so a multi-word marker (`guarantee that`) wins over any
single-word prefix.

In addition to `Comparison`/`Duration`/`Assertion`, the `=== language ===`
section accepts synonym sub-blocks for every author-extensible category the
condition/description grammar keys on (each merged into `EnglishLexicon` the same
way): `Emptiness synonyms:` / `Filled synonyms:`, `Past window synonyms:` /
`Future window synonyms:`, `Timestamp aliases:`, `Aggregate synonyms:`,
`Superlative synonyms:`, `Sort-by synonyms:` / `Ascending synonyms:` /
`Descending synonyms:`, `Possessive synonyms:`, `Anaphora synonyms:`, the
table-header sets (`Condition header synonyms:` / `Action header synonyms:` /
`Wildcard synonyms:`), `Shell fence synonyms:` (extra fenced-code info-string
tags treated as deterministic `shell.run` blocks — e.g. `fish`, `pwsh`, `nu` —
on top of the default `bash`/`sh`/`shell`/`console`/`zsh`), `Fence tool
mapping:` (`<fence-tag> = <tool-id>` pairs for non-shell fenced blocks),
`Vague-hedge synonyms:` / `Effectful-judgment synonyms:` (condition/judgment
cue vocabulary), `Article synonyms:` / `Parameter-article synonyms:` /
`Preposition synonyms:` / `Copula synonyms:` / `Participle synonyms:` /
`Tool-stopword synonyms:` (surface stop-word tables), `Irregular-plural
mapping:` (`singular = plural` pairs), `Contract-reference synonyms:`
(documentary contract-guard body phrases), and
`Trace-auxiliary synonyms:` (extra outcome verbs after a trace subject, e.g.
`occurred`).

Every sub-block is one row in `LexiconRegistry`
(`Sources/MeridianCore/Language/LexiconRegistry.swift`) — its accepted header
spellings, the shape of its lines, and the rule that merges its entries into the
`EnglishLexicon` field it names. `MerConfigParser.parseLanguageSection`,
`MerConfigFile.merging` and `EnglishLexicon.merging(from:)` all read that one
table, so adding a category is a `LexiconCategory` case plus a spec row, nothing
else. `Tests/MeridianCoreTests/LexiconRegistryParityTests.swift` checks, for
every category and every accepted header spelling, that a block lands in its own
lexicon field and leaves every other category untouched.

Three cleanup synonym blocks tune structural sugar introduced in the quality
closeout (same merge recipe as every other `=== language ===` category):

```
=== language ===
Guarded-fence synonyms:
  , then run:
Fallback-chain synonyms:
  attempt the following in order:
Approval-tool synonyms:
  sign-off
```

- **`Guarded-fence synonyms:`** extends `EnglishLexicon.guardedFenceIntroducers`
  (default: `, run:`, `, execute:`). An `if <cond><marker>:` line immediately
  followed by a fenced shell block lowers the block's `shell.run` invokes inside
  a `branch` — no new IR primitive.
- **`Fallback-chain synonyms:`** extends `EnglishLexicon.fallbackChainIntroducers`
  (default: `try the following in order until one succeeds:`, `try each of the
  following until one works:`). The following ordered list lowers to a nested
  `recover` chain.
- **`Approval-tool synonyms:`** extends `EnglishLexicon.approvalToolIDSubstrings`
  (default: `approval`, `approve`). Matched against tool/workflow IDs so
  `RuleInjector` does not inject a duplicate `wait for approval` when an
  approval step already exists.

### `SkillMigrator` classification synonyms (P1 four-way policy)

Three more `=== language ===` sub-blocks tune how `meridian migrate-skill`
classifies a non-lowerable line or block into judgment / reference / hard
error (see [09_SKILL_PORTING.md](09_SKILL_PORTING.md) for the full
policy). Like every other category above, a Swift default is not sufficient —
these are wired through the complete `LexiconCategory` registry recipe
(`LexiconRegistry` spec row → `MerConfigParser.parseLanguageSection` →
`LanguageSynonyms.entries` → `EnglishLexicon.merging(from:)` →
`Compiler.compile`, AGENTS.md §3), so a corpus tunes classification entirely
through its own `.merconfig`, never a Meridian recompile:

```
=== language ===
Inference-cue synonyms:
  triage
  prioritize
Normative-cue synonyms:
  shall
  is required to
Reference-heading synonyms:
  glossary
  faq
```

- **`Inference-cue synonyms:`** extends `EnglishLexicon.inferenceCueWords`
  (default: `analyse`/`analyze`, `assess`, `evaluate`, `judge`, `decide`,
  `determine`, `interpret`, `consider`, `reason`, `infer`, `diagnose`,
  `critique`, `synthesize`, `understand`). A whole-word, case-insensitive hit
  on a non-lowerable line is the **only** signal that may route it to
  `use judgment to …:` / `ai-discretion` / `ai-autonomy`. A lowerable line
  that happens to contain one of these words still lowers normally —
  lowerability is always tested first.
- **`Normative-cue synonyms:`** extends `EnglishLexicon.normativeCueWords`
  (default: `must`, `never`, `always`, plus refusal/requirement cues such as
  `refuse*`/`require*`/`forbidden`/`mandatory`). A hit marks a non-lowerable,
  cue-less line as an **operational contract**, not documentation — the
  migrator leaves it unmarked so the real compiler raises its own precise
  `uncheckablePredicate`/`unresolvedPhrase` diagnostic naming the reword
  needed, rather than silently filing it as `reference` or wrapping it in
  judgment.
- **`Reference-heading synonyms:`** extends
  `EnglishLexicon.referenceHeadingWords` — heading words (`overview`,
  `rationale`, `background`, `example`, `example:`, `for reference`, …) that
  mark a section as documentary when its body has neither a lowerable
  statement nor an inference/normative cue. Such a section gets
  `(( role: reference ))`, never `(( inert ))` — the migrator does not emit
  that keyword.
- **`Contract-reference synonyms:`** extends
  `EnglishLexicon.contractReferencePhrases` (default: `already enforced`,
  `enforced above`, `workflow's own`, …) — body substrings that mark a
  documentary note that the executable workflow already carries the referenced
  guard.

**Where the line is — extensible vs. fixed.** Synonym categories above are
*domain-renamable* and live in `EnglishLexicon`. The closed **grammar skeleton**
— relativizers, the prose/idiom introducers (`with discretion`, `with autonomy`,
`use judgment to`, `decide whether`, the wait/choice/background markers), and the
relational markers (`is empty`, the passive ` by `, scalar-nav connectors) — is
centralized in `FixedGrammar` (`EnglishLexicon.grammar`) and is **not**
author-extensible; it defines *what the language is*, not *what a domain calls
things*. See AGENTS.md §3.

---

## Phase 8 additions — Executable rules (Phase C)

Rules at the top of a `.meridian` file are lowered to executable IR rather
than being documentation-only. This now applies **inside sectioned (SKILL.md-
style, heading-bearing) documents too** — a `must not` / `may` [+ bounded
`up to N`] / `must be … by … before` / `When …, …` sentence fires exactly the
same way whether it sits at the top of a flat `.meridian` file or inside a
`##`/`###` executable section (`procedure`, `invariants`, `prohibitions`).
Prose is opt-in, never inferred: mark the section `(( role: reference ))` /
`(( inert ))`, or comment the line (`#`/`>`), to keep it as documentation. See
"gbrain SKILL surface" below for the exact classification precedence and the
`When …,` = trigger rule.

### Rule forms

| Form | Lowers to |
|---|---|
| `A customer with status suspended must not place orders.` | `AssertIR` prepended to matching workflow |
| `A customer must not place an order whose total amount is more than their credit limit.` | `AssertIR` with two-parameter predicate |
| `An order … must be approved by an account manager before fulfillment.` | `WaitIR(.approval(…))` prepended |
| `When an order is flagged as stale, escalate the order.` | New synthetic `IRWorkflow` with `WaitIR(.event)` |
| `A customer with status verified may place orders.` | Permission struct entry; softens matching `must not` assertions |

`When <condition>, <action>` always compiles to an external-event stub — the
condition is never re-evaluated by a scheduler/poller, only matched against a
host-raised event. Because of that, `<condition>` must be opaque
externally-raised-event prose (bare equality/passive voice, e.g. `"a refund is
requested"`, `"an order is flagged as stale"`), not a real checkable
predicate. A condition that structurally names one (a magnitude/pattern/set
comparison, an emptiness/temporal-window check, a duration mention, a
quantifier, a relation traversal, a description, an aggregate, a superlative,
a table lookup, or a declared-verb predicate — e.g. `"an order has been on
hold for more than 7 days"`) is rejected with `MER3017` instead of silently
compiling to an event nobody will ever raise. Rewrite it as an explicit
workflow guard/assertion the compiler can evaluate directly, or phrase it as
the external event/signal a host actually raises.

### `may` rules and permission softening

`may` rules are exceptions that relax `must not` rules for a subset of
subjects. They OR a permission predicate into the negated condition of any
matching invariant or parameter-guard assertion:

```
A customer with status suspended must not place orders.
A customer with status verified may place orders.
```

Combined assert condition: `customer.status != "suspended" || customer.status == "verified"`.

### Bounded permissions (C3c)

`may` rules with an explicit condition clause (`up to`, `at most`, `if`) are
**bounded**. They inject an additional `AssertIR` gate at the start of matching
workflows to enforce the cap at runtime. Bounded permission entries appear in
the manifest with `"bounded": true`.

### Rule manifest entries (C5)

Every rule, whether lowered or not, is emitted in the manifest under
`meridian_rules: [{ text, kind, executes, source }]`. Unparseable rules
produce `Diagnostic.warning` and appear with `"executes": false`.

---

## Worked examples — comprehensive sample corpus

`examples/skill/` contains a curated SKILL-style corpus that exercises every
language feature documented above end-to-end. Both file extensions are
supported and demonstrated:

- `.meridian` — the long form
- `.meri` — the short form

The corpus shares one standalone vocabulary
(`examples/skill/comprehensive_workflows.merconfig`) so each sample stays
focused on the language feature it demonstrates. Pick the closest analog to
your problem and adapt:

| Sample | Highlights |
|---|---|
| `security_review_triage.meridian` | Markdown sections, implicit entry workflow, `every comment` iteration, `with discretion` plan |
| `flaky_ci_stabilizer.meri` | Autonomy with `until`, `unless`, replan after N failures, max steps |
| `large_release_train.meridian` | Cross-tier nesting: deterministic gate → discretion → autonomy |
| `dependency_upgrade_sweep.meri` | Inline `do … and …` chain, `every dependency` iteration, `recover from any` |
| `hotfix_commander.meridian` | `wait for approval`, `wait for signal`, autonomy abort guard, recover |
| `review_comment_refactor.meri` | Topic labels, implicit single-parameter fill, `make sure …` idiom |
| `merge_conflict_playbook.meridian` | Branch + discretion plan combined |
| `incident_pr_response.meri` | Multi-section SKILL file, frontmatter goal, mixed waits/emits/recover |
| `policy_guarded_autonomy.meridian` | Recover from `planning.host_policy_denied` and `planning.tool_out_of_scope` |
| `planner_schema_validation_demo.meri` | Recover from every schema-validation `PlanningFailureCode` |
| `customer_support_router.meridian` | VIP escalation branch + discretion draft |
| `deployment_promotion.meri` | `simultaneously:` parallelism, `if … otherwise …`, recover |

Structural assertions per sample live in
[`Tests/MeridianCoreTests/SkillExampleCorpusTests.swift`](../Tests/MeridianCoreTests/SkillExampleCorpusTests.swift).

---

## gbrain SKILL surface — section semantics, command surface, dispatch

This surface lets a gbrain-style `SKILL.md` be renamed to `.meri` and compiled
with minimal edits. The section model activates **structurally**: any file whose
implicit-workflow body contains a `##`/`###` heading is a *sectioned document*
and gets section-role lowering. A file with no headings keeps the flat-procedure
behaviour byte-for-byte. There is **no `skill: true` flag** — it was removed.
Section roles are driven by a rulebook (see [03_LANGUAGE.md](03_LANGUAGE.md));
normal heading-less `.meridian` files are unaffected. The porting playbook is
[09_SKILL_PORTING.md](09_SKILL_PORTING.md).

### Section markers (`(( … ))`)

A heading may carry a single trailing `(( … )))` marker (comma-separated terms)
that is **authoritative** — when present, the heading text is never used to
derive a role:

| Marker | Meaning |
|---|---|
| `(( inert ))` | non-executable documentation; manifest records `role: "inert"` (no role derived from the heading) |
| `(( inert, role: <R> ))` | non-executable, with the author-specified role label `<R>` recorded (e.g. `(( inert, role: invariants ))`) |
| `(( role: <R> ))` | forces role `<R>`, overriding heading derivation; executable iff `<R>` is an executable role |

A non-executable section runs nothing — the marker overrides even shell-block
routing — but its verbatim text is **always** preserved in the manifest under
`meridian_skill.sections` (see [02_ARCHITECTURE.md](02_ARCHITECTURE.md)).

### gbrain frontmatter keys

```
---
name: capture
description: Save any thought or content into the brain via one CLI command.
vocabulary: brain.merconfig
rulebook: brain.merrules
tools:
  - capture
  - search
triggers:
  - "capture this"
  - "save this thought"
  - every inbound message
writes_pages:
  - "inbox/*"
---
```

- YAML **sequences** (`- item`) and **block scalars** (`description: |`) are
  parsed in addition to scalar `key: value` lines.
- `tools:` is the per-skill scoped tool allow-list (replaces the hardcoded
  all-tools default in `AIJudgmentIR.scopedTools` / `AIAutonomyIR.scopedTools`).
- `triggers:` are classified into typed kinds and synthesised into trigger
  workflows (below). All other keys are projected through the typed
  `SkillFrontmatter` and emitted under `meridian_skill` in the manifest.
- **Rule/statement/prose classification precedence, inside an executable
  section (`procedure`/`invariants`/`prohibitions`):** for each one-line,
  non-table/checklist/code-block statement group, in order —
  1. If the section is the guidance body of a `use judgment to follow the …
     guidance:` step, the line is guidance prose for that step, never a rule
     or a statement (the judgment step swallows every following same-section
     line regardless of indentation).
  2. Otherwise, if the line is rule-shaped (starts with a parameter article
     `a`/`an`/`the`, or the literal `when `) **and** matches one of the Phase-8
     rule forms below, it fires as a rule — `must not` / `may` [+ bounded
     `up to N`] / `must be … by … before` / `When …, …` are **always** trigger
     rules here, never inline `if`/`unless` conditionals, even in prose-heavy
     SKILL.md-style writing. Use `if`/`unless`/`only when` for an ordinary
     inline conditional statement.
  3. Otherwise it lowers as an ordinary statement per its section's role.
  `applicability`/`negative-applicability` sections are exempt from step 2 —
  their bullets are dispatch-phrase fragments (e.g. `When the user says "X"`),
  not rule sentences, and are always mined as dispatch predicates instead.
  Skill triggers otherwise come from frontmatter `triggers:`; cross-cutting
  behaviour comes from rulebook conventions.

### Section roles (rulebook-driven)

An **unmarked** `##` / `###` heading resolves to a closed `SkillSectionRole` via
the rulebook's `=== sections ===` aliases, then the built-in aliases. Role
derivation from the heading text happens **only for unmarked executable
sections** — it is never applied to inert sections (for documentation we do not
guess; the author writes `role:` if they want a label). The role decides how the
section body lowers:

| Role (default headings) | Lowers to |
|---|---|
| `invariants` (Contract, Guarantees) | `assert` (checkable items only; leading assertion markers such as `make sure`, `ensure`, and `assert` are accepted) |
| `procedure` (Phases, Workflow, Protocol, Steps, `Phase N: …`) | executable statements |
| `applicability` (When To Use, When to invoke/run) | preconditions / dispatch predicates |
| `negative-applicability` (When NOT To Use, Do NOT Use) | soft-skip guards / negative dispatch predicates |
| `prohibitions` (Anti-Patterns) | `must not` where checkable |
| `template` (Output Format, Output Structure) | result template (non-executable) |
| `reference` (explicit `(( role: reference ))` marker) | manifest/outline metadata, runs nothing — the preferred non-executable-documentation marker |
| `inert` (explicit `(( inert ))` marker) | manifest/outline metadata, runs nothing — a hand-authorable synonym of `reference`; `meridian migrate-skill` never emits it (see [09_SKILL_PORTING.md](09_SKILL_PORTING.md)) |

**No silent drops — three hard errors.** The strict builder never discards
content:

1. **Content before the first heading** in a sectioned document is a
   `semanticError`. Move it under a heading, or make it a comment (`#`/`>`).
   Markdown blockquote (`>`) lines are treated as comments, so SKILL.md
   `> **Convention:** …` asides may sit above the first heading.
2. **An unrecognized heading with content** (no marker, no alias) is a
   `semanticError`: rename it to a recognized role, add a `=== sections ===`
   alias, force a role with `(( role: <R> ))`, or mark it
   `(( role: reference ))` (or the hand-authorable `(( inert ))` synonym).
3. **A non-checkable `Contract`/`Anti-Patterns` item** (prose, not a structural
   comparison or quantifier) is a `semanticError`. Rephrase it as a comparison,
   quantifier, or `make sure …` / `ensure …` assertion, or mark the
   section `(( inert, role: invariants ))` / `(( inert, role: prohibitions ))`
   to keep it as labelled documentation. (`meridian migrate-skill` never emits
   this marker itself — a cue-less non-checkable item is left for this exact
   `semanticError` to catch, naming the reword needed; see
   [09_SKILL_PORTING.md](09_SKILL_PORTING.md).)

**Fuzzy applicability = hard error.** An applicability condition that is neither
a literal dispatch phrase nor structurally checkable (e.g. "the request is
ambiguous") is a compile-time `semanticError`. Rephrase to a checkable
predicate, move it to `triggers:`, or wrap it in `use judgment to …:`.

### Procedure idioms (rulebook desugars)

Inside a `procedure`-role section, the shipped `brain.merrules` adds:

```
If the note is "urgent" -> capture the note.      # arrow conditional → only-when branch
Report: "done".                                    # → emit skill.report
for each page:                                     # bare for-each header (singular bound)
  publish the page at the slug.
- [ ] the citations are valid                      # checklist → make sure … assert
```

### Command surface — shell commands

Fenced ` ```bash `/` ```sh `/` ```shell ` blocks and inline backticked commands
in a `procedure` section lower to `invoke shell.run with command = "…"` against
the built-in `shell.run` subprocess tool. A multi-line block lowers to one
invoke per command line.

````
## Phases
```bash
gbrain search "acme corp"
gbrain publish
```
`gbrain doctor`
````

Natural-language imperative phrases (no literal `gbrain` prefix, e.g. "search
the brain for the attendee") still resolve **strictly** against declared tool
phrases; an unresolved NL phrase is a hard error (`MER2001`, with a did-you-mean
against the declared phrases — see
[06_DEVELOPER_EXPERIENCE.md](06_DEVELOPER_EXPERIENCE.md)).

### Inform 7-tier surface (Wave 1)

Four deterministic forms that let a gbrain `SKILL.md` port with fewer
`(( role: reference ))` sections and shorter judgment blocks. All are closed
grammars — an ambiguity is a sourced error, never a guess — and none add an IR
primitive.

**Command annotation (1A).** A trailing ` -- <note>` *outside* backticks is
stripped and carried as a source comment above the emitted `shell.run`:

```
`gbrain get acme-corp` -- load compiled truth and recent timeline
```

**Typed holes in commands (1B).** A `{ … }` span inside a backticked command
interpolates an in-scope expression. The hole's head name is validated against
the lexical scope (workflow parameters, earlier binds, and the enclosing
`for each`/`for every` loop variable); an unresolved name is a hard
`semanticError`. Holes inside a double-quoted span are shell-escaped
(`meridianShellQuote`); holes outside quotes interpolate verbatim. Write `{{` /
`}}` for a literal brace.

```
For every attendee:
  - `gbrain search "{the attendee's name}"` -- find their brain page
  - `gbrain get {the attendee's slug}`
```

**Iteration refinements (1C).** A single-clause filter / temporal window /
ordering / count, in this order: `for each [the first N] <kind plural> [whose
<prop> <comp> <value> | [is] within the last N <unit> | [is] in the next N <unit>]
[sorted by <prop>[, newest first|oldest first]]`. The list is filtered, sorted,
and truncated **pre-loop** (so `the first N` counts post-filter). `whose` lowers
to a comparison on the loop element; `[is] within the last`/`[is] in the next`
lower to a one-sided temporal window on a configurable timestamp property
(`LanguageSynonyms.timestampProperty`, default `updatedAt`). New comparators:
`contains`, `is one of`. See [02_ARCHITECTURE.md](02_ARCHITECTURE.md).

**Metadata sections (1D).** A `## Tools Used` section is non-executable but
metadata-extracting: each bullet's tool id is mined into the workflow's
scoped-tool set and the manifest `tools_used`. **Two bullet forms are accepted**
(use whichever the source SKILL.md already uses — no reformatting required):

```
## Tools Used

- Search gbrain by name (query)            ← <description> (<tool_id>)
- `get_page` — read a page from gbrain     ← `<tool_id>` — <description>
```

A bullet matching neither form (e.g. a backticked CLI command whose token
contains spaces) is a hard error — such a section should stay
`(( role: reference ))` (or the hand-authorable `(( inert ))` synonym).
An invariant of the form `every emitted <noun> matches pattern "<regex>"`
lowers to an `AssertIR` over `meridianRegexMatches`.

### Inform 7-tier semantic core (Wave 2)

Three closed-grammar surfaces — boolean composition, checkable adjective
**Definitions**, and **quantifiers** over descriptions — plus a shared condition
grammar (temporal windows + emptiness). All lower to existing IR primitives with
richer expression payloads (no new IR primitive); every ambiguity is a sourced
`semanticError`, never a guess.

**Boolean composition (2A).** Precedence is `not` > `and` > `or`. A trailing
Oxford comma before a connective (`, and` / `, or`) is tolerated. Mixing bare
`and` and `or` at one level is a **hard error** that prints both readings — group
explicitly with `either … or …`:

```
if the page is risky and either the merge status is "behind" or the merge status is "conflicting",
  ...
```

`not <cond>` and `it is not the case that <cond>` both negate. `and`/`or` inside
double-quoted strings are never split.

**Definitions (2B).** `Definition: a <kind> is <adjective> if <condition>.` —
valid in a `.merconfig` vocabulary section and at the top of a `.meri` body.
Inside the body, `it` / `its` bind to the subject:

```
Definition: a page is stale if it has no summary.
Definition: a page is risky if its risk score is more than 0.7.
Definition: a page is neglected if it is stale and it is risky.
```

A definition is used as a checkable adjective in **subject position**:

```
if the page is stale, ...          # → meridianDef_Page_stale(state.get("page"))
if the page is not risky, ...      # → !(meridianDef_Page_risky(...))
for each stale page: ...           # adjective filters the iterated set
no pages that are neglected        # adjective filters a quantified description
```

Adjective surface names are **globally unique** (a collision is an error naming
both sites); generated helpers are **kind-namespaced** as
`meridianDef_<Kind>_<adjCamel>`. Definitions may compose other definitions but
**recursion (direct or mutual) is a hard error**, and every property a body
reads must exist on the kind. An adjective fires only in subject position, so
`the deal is urgent` (adjective) stays distinct from `whose status is urgent`
(enum value).

**Quantifiers (2C).** Over a *description* —
`[quantifier] [adjectives] <kind plural> ( whose <pred> | <have/are body> )?`:

| Form | Meaning |
|---|---|
| `all X` / `every X` | every element satisfies the body (vacuously true on empty) — body **required** |
| `any X` / `some X` | at least one element satisfies the body |
| `no X` / `none of X` | no element satisfies the body |
| `at least N X` | the matching set has `count >= N` |
| `at most N X` | the matching set has `count <= N` |
| `exactly N X` | the matching set has `count == N` |

```
if all pages have a summary, ...
if at least 2 pages whose status is "published" have a summary, ...
if no pages whose status is "draft", ...
```

A `whose`/`that` clause **terminates** the description (the quantifier asserts
the cardinality of the filtered set); a `have/are` body is recognized only when
there is no `whose`. The collection must be a fetch-once source (a bound name,
identifier, or property) — quantifying directly over a tool invocation is a
sourced error ("bind the result first, then quantify over it").

**Shared condition grammar (2A/2B/2C).** Available in any condition:

- **Temporal windows:** `<property> within the last N <unit>` / `<property> in
  the next N <unit>` (one-sided windows on a date property). A participle form
  (`was updated within the last 7 days`) targets the configurable timestamp
  property (`LanguageSynonyms.timestampProperty`, default `updatedAt`).
- **Property-backed emptiness:** `X has no <property>` → empty; `X has a/an/some
  <property>` → non-empty; `X is empty` / `X is not empty` over the subject
  itself. These lower through `MeridianComparison.isEmpty` / `isNotEmpty`.
  A relation has no bare-noun surface of its own (only a conjugated verb), so
  a **relation-backed** emptiness condition is expressed as a `none`-kind
  quantifier restricted by a relative clause instead — see "Inform 7-tier
  relational layer (Wave 3)" below (e.g. `no pages owned by the user`,
  `no pages that mention the entity`).

### Inform 7-tier relational layer (Wave 3)

Relations, verbs, and descriptions make the relationships between kinds
first-class — still 100% deterministic, no LLM. Three surfaces:

**Relations + evaluation backing (3A).** A relation is declared in `.merconfig`
with a cardinality and an **evaluation backing** that says how to compute it:

```
Ownership relates one user to various pages.
Ownership is read from the page's owner.        # property-backed
Mentioning relates various pages to various entities.
Mentioning is read via the link tool.           # tool-backed
```

`various` is a synonym for `many`. A **property backing** (`read from the
<kind>'s <property>`) means the link is stored at `<kind>.<property>` (a
foreign-key id, a reference, or a list of them). A **tool backing** (`read via
the <tool> tool`) means the related set is produced by invoking `<tool>` once.
A relation that is named by a verb (below) **must** have a backing; an
unbacked relation that no verb references is allowed (legacy vocabularies).

**Verbs (3B).** A verb names a relation and supplies its conjugations:

```
The verb to own (it owns, it is owned) means the ownership relation.
```

The three forms are `base` (`own`), `third-person` (`owns`), and
`past-participle` (`owned`); omitted forms fall back to regular morphology
(`EnglishLexicon.thirdPersonSingular` / `regularPastParticiple`). A verb form
must be globally unambiguous across relations.

An **active-verb condition** uses the third-person form as an infix predicate:

```
if the user owns the page, ...
```

For a **property-backed** relation this lowers to an identity check on the
backing property — `MeridianComparison.identifies(page.owner, user)` — with no
tool call and no LLM. A tool-backed verb **cannot** be tested inline (it needs
an `await` fetch): materialise the related set with a description first.

A verb predicate may be **negated** with do-support — `the entity does not link
to the input` (or the contraction `doesn't`) — which wraps the predicate in a
logical `not`. A governing preposition between verb and object (`link to …`) is
absorbed. This makes the iron-law guard executable: fetch the related set, then
only act when the link is genuinely missing —

```
let mentioned be the entities mentioned by the input.
for each entity in mentioned:
  if the entity does not link to the input, add a back-link from the entity to the input.
```

(`mention` is tool-backed → the set is fetched once; `link` is property-backed
on `entity.links` → the guard is a `MeridianComparison.identifies` check.)

**Descriptions, aggregates, superlatives (3C).** A *description* is a
deterministic query plan over a bound collection. Relation clauses restrict the
element set:

```
let owned be the pages owned by the user.              # passive (object gap)
let mentioned be the pages that mention the entity.    # relative clause (subject gap)
let top be the first 3 pages sorted by view count descending.
```

| Form | Lowers to |
|---|---|
| `the <adj> <plural> [owned by X \| that <verb> X]` | `.filter` over the collection |
| `the number of <desc>` / `the count of <desc>` | `Decimal(filtered.count)` (compares numerically) |
| `the list of <desc>` | `Value.list(filtered)` |
| `the most recent <desc>` / `the oldest <desc>` | timestamp superlative → `.sorted{…}.first` |
| `the largest <desc> by <property>` | magnitude superlative (requires `by`) |
| `the first N <desc> sorted by <property> [descending]` | `.sorted{…}.prefix(N)` |

A **property-backed** description filters the in-scope collection. A
**tool-backed** description (`that mention …`) hoists a single prelude `invoke`
before the statement and reads its bound result — so it is only valid in a
**statement** position (a `bind` / `let` / loop), never inline in an expression.

**Scalar relation navigation.** A one-to-one relation can be navigated to a
single value:

```
let assigned be the task assigned to the user.    # → user.task
```

Property-backed scalar navigation lowers to a `.propertyAccess`
(`state.get("user.task")`); tool-backed scalar navigation in an inline
expression is a sourced error.

**`let <name> be <value>.`** is syntactic sugar for `bind <name> = <value>.`
(introduced for readable relational binds).

**Relation-backed emptiness.** A relation has no bare-noun surface of its own
(only a conjugated verb), so `X has no <relation>` cannot resolve which
relation is meant — a relation-backed emptiness condition is instead written
as a `no`-kind quantifier restricted by the same relative clause used above:

```
if no pages owned by the user, ...          # passive (object gap)
if no pages that mention the entity, ...    # relative clause (subject gap)
```

A property-backed clause lowers straight to `MeridianComparison.isEmpty` over
the filtered description (no tool call); a tool-backed clause inside a
quantifier is rejected with a sourced "bind it first" diagnostic, since
quantifiers evaluate as a pure boolean expression with no prelude slot for an
`await` fetch.

### Explicit judgment markers

```
use judgment to decide if the entity is notable:
  Weigh prominence, recency, and reliability of sources.
```

`use judgment to <goal>:` (and `with discretion` / `with autonomy` on the
workflow header) lower to `IRPrimitive.aiJudgment(AIJudgmentIR)` (discretion,
plan-then-execute) or `IRPrimitive.aiAutonomy(AIAutonomyIR)` (autonomy, looping),
picked by the same `ProseDispatchMode` the AST already carries. This is the
ONLY path prose reaches the planner; unmarked freeform prose is a hard error.

### Choice-gate

```
ask the user to choose between "proceed", "cancel".
if the choice is "proceed",
  publish the page at the slug.
```

Lowers to `emit ask.choice` + `wait` (`WaitConditionIR.choice`) + a `branch` on
the selection (read at runtime via `runtime.consumeChoiceSelection()`).

### Background spawn

```
in the background, publish the page at the slug.
```

Lowers to `SimultaneouslyIR(detached: true)`; codegen emits a detached `Task {}`
with no `waitForAll` join.

### Triggers and the resolver

Frontmatter `triggers:` are classified into four typed kinds and synthesised
into one trigger workflow each, emitting a `trigger.<name>.fired` fan-out event:

| `TriggerKind` | Example spec |
|---|---|
| `schedule` | `nightly`, `0 9 * * *` |
| `ambient` | `every inbound message` |
| `event` | `meeting transcript received` |
| `keyword` | `summarize my day` |

Classification keyword sets are **data**: built-in defaults live in
`Rulebook.defaultTriggers`, and a rulebook's `=== triggers ===` block
(`<kind>: word1, word2, …`) extends them per kind (see
[03_LANGUAGE.md](03_LANGUAGE.md) Family 4). `keyword` is the fallback.

`sample-gbrain/RESOLVER.meri` is the trigger → skill dispatcher.

### Multi-source compilation

`Compiler.compile(Compiler.CompilationUnit(sources:vocabularies:rulebooks:))`
compiles one-or-many `.meri` files against shared vocabularies + rulebooks,
pre-registering every source's workflows as phrase stubs first so cross-file
invocations and the resolver resolve across files. A single-source unit is the
common case; the result is keyed by `SourceInput.file`.

### Markdown tables (executable)

A Markdown table is **executable by default** (a *decision table*). The
tokenizer collapses a contiguous header + delimiter + rows block into one
synthetic line; `TableParser` then lowers it per its mode. A table needs no
heading, so its mode is set by an optional `!!! table (( <mode> ))` marker on
the line **directly above** the table:

| Marker | Mode | Lowers to |
|---|---|---|
| *(none)* / `!!! table (( decision table ))` | decision | one `if <conds>, <action>.` per row |
| `!!! table (( data table[: <name>] ))` | data | `bind <name> = <recordList>` (name optional, defaults to `table`) |
| `!!! table (( iteration table ))` | iteration | reserved (accepted; no statements yet) |
| `!!! table (( ai-discretion ))` | ai-discretion | a discretion step (`IRPrimitive.aiJudgment(AIJudgmentIR)`) — the planner picks the matching row and does its action |
| `!!! table (( ai-autonomy ))` | ai-autonomy | an autonomy step (`IRPrimitive.aiAutonomy(AIAutonomyIR)`) |
| `!!! table (( inert ))` | inert | nothing (documentation only) |

**Decision table.** The last column (or one headed `action`/`then`/`do`/`result`)
is the action; the remaining columns are conditions joined with `and`. A cell
maps to a predicate: a bare value → `header is value`; an operator-prefixed cell
(`>= 90`) → the canonical spelling (`header is more than or equal to 90`); a
comparison phrase (`more than 5`, `contains x`) is used as-is; a wildcard
(`*`, `-`, `any`, empty) drops the column. An all-wildcard row is an
unconditional action.

```
| status | priority | action               |
|--------|----------|----------------------|
| open   | >= p1    | escalate the issue   |
| closed | *        | archive the issue    |
```

**Data table.** A list of records, one per row, bound to a name. Field names are
camelCased so a later `for each row in <name>` resolves `row.<field>`.

```
!!! table (( data table: tiers ))
| name  | floor |
|-------|-------|
| gold  | 100   |
| silver| 50    |
```

**Fuzzy decision table → the planner.** When the condition cells are *intent
descriptions* rather than checkable comparisons, mark the table
`!!! table (( ai-discretion ))`. The rows are rendered as a ruleset
(`when <conds>, <action>`; a wildcard row → `otherwise, <action>`) and handed to
a discretion prose step — the same path as `use judgment to …:`, valid in any
workflow. Use `(( ai-autonomy ))` for a loop instead of a single decision.

```
!!! table (( ai-discretion ))
| Condition                       | Action                      |
|---------------------------------|-----------------------------|
| user asks for a deterministic run | submit a shell job        |
| user asks for an iterative agent  | spawn a research subagent |
```

An unrecognized block kind, an unknown mode, or a `!!!` marker not directly
above a table is a **hard error** (no silent drop).

### Task lists (invariants, or AI acceptance loops)

A Markdown checklist item is an **invariant assert** by default. `- [ ]` and
`- [x]` desugar to `make sure <condition>`, routed through the same
checkable-or-error classifier as Contract invariants: a structurally checkable
predicate becomes an `assert`; a fuzzy/descriptive item is a **hard error**.

```
- [ ] the link count is at least 1
- [ ] the page's body is not empty
```

**Fuzzy acceptance checklist → the planner.** When the items are genuine
acceptance criteria that aren't structurally checkable, don't inert them — put a
`!!! checklist (( <mode> ))` marker directly above the list. The contiguous run
collapses into one prose step with every criterion embedded as the goal:

| Marker | Lowers to |
|---|---|
| *(none)* / `!!! checklist (( invariant ))` | one `assert` per item (each must be checkable) |
| `!!! checklist (( ai-autonomy ))` | `IRPrimitive.aiAutonomy(AIAutonomyIR)` — loop, act until every criterion holds |
| `!!! checklist (( ai-discretion ))` | `IRPrimitive.aiJudgment(AIJudgmentIR)` — verify/resolve the criteria once |
| `!!! checklist (( inert ))` | nothing (documentation only) |

```
!!! checklist (( ai-autonomy ))
- [ ] all entity pages are cross-linked
- [ ] no DRY violations across skills
- [ ] gbrain doctor reports schema_pack_consistency: ok
```

A `!!! checklist` marker not directly above a task list, or an unknown mode, is a
**hard error**.

### Output-format invariants (generalized 1D)

`every emitted <noun> <predicate>` (and `each emitted …`) is sugar for an assert
on the bound result `<noun>` — generalized beyond `matches pattern "<regex>"` to
**any** checkable predicate (`contains`, comparisons, `is empty`, …):

```
- every emitted report contains "Sources".
- each emitted summary is not empty.
```

---

## Inform-7 Wave 8 — traces, time, and statistics

Wave 8 adds **trace-backed** conditions and monitors on top of the Wave 2–3
condition grammar. Temporal and statistical expressions lower to
`IRExpression.traceTemporal` / `.traceStatistical` and evaluate at runtime
against a `TraceStore` (in-memory in tests; JSONL when configured). Full
semantics: [04_RUNTIME.md](04_RUNTIME.md).

### Author-facing surface (at a glance)

| Form | Meaning |
|---|---|
| `<step> has ever failed` | `.ever` — at least one retained `failed` record for the step |
| `within the last <D>, <event pattern>` | count-in-window temporal query |
| `<N> times in a row, <event pattern>` | consecutive occurrence streak |
| `since the last <event>, <holds>` | strict-after-anchor window; `holds` must lower to an event pattern (**MER-TMP-019** for pure state predicates) |
| `usually` / `rarely` | statistical thresholds (numeric at codegen; configurable via `=== trace ===`) |
| `assert <statistical query>, checked every <D>` | monitored assertion → `runtime.registerMonitor(...)` |
| `proceed, and note "<text>" in the <binding>` | text-appending `rebind` (no new IR primitive) |

Scoped history uses stable step paths and skill names; `across all runs` scopes
by skill identity. Vague frequency wording (`most of the time`) is rejected at
compile time (**MER-STA-003**).

### `=== trace ===` configuration

Optional `.merconfig` block merged into generated `runtimeTraceConfiguration`:

```
=== trace ===
store: file
retention: 30 days
hash chaining: enabled
usually at least: 90%
rarely at most: 10%
sample floor: 5
default monitor cadence: 1 days
profile: production
store failure policy: fail-closed
```

Per-tool capture policy (`full` / `hash-only` / `redacted(fields)`) is declared
on tool entries in `=== tools ===`. A temporal window wider than configured
retention is a compile error naming both durations (**MER-TMP-011**).

CLI replay/audit: `meridian trace eval`, `meridian trace verify`,
`meridian trace drift`, `meridian bench-trace` — see [05_CLI.md](05_CLI.md) and
[06_DEVELOPER_EXPERIENCE.md](06_DEVELOPER_EXPERIENCE.md) for the compile-time `ParserTrace` vs semantic
trace distinction.

---

## Architectural patterns

*Was `docs/17_MERIDIAN_PATTERNS.md`.*

This doc catalogs recurring architectural patterns behind Meridian's compiler
— the "why is it built this way, and why is that intentional rather than a
bug" reasoning that's too deep for `AGENTS.md` (always-injected, kept lean)
and too cross-cutting for a single `.cursor/rules/*.mdc` (area-scoped,
attaches per file glob). `docs/07_DECISIONS.md` (generated from
`DecisionCatalog`) covers the same territory but only for decisions tied to a
specific diagnostic code; a pattern here may span several diagnostics, or
none. When you're about to "fix" something that turns out to already be
intentional, check here first — and when you resolve a "why not fixed?"
question that isn't captured yet, add a pattern for it instead of leaving the
reasoning buried in a chat transcript or a single `IMPLEMENTATION_LOG.md`
entry.

---

### Pattern: A restricted sub-language rejects unsupported forms loudly instead of approximating them

**Where it shows up:** `RuleInjector.lowerExprSimple` (in-section rule
filters/conditions/predicates — an `.invariant` filter, a bounded
`.permission`'s conditions, a `.precondition`'s gate) and
`RuleAnalyzer.isSelfEvaluatingTriggerCondition` (`When …, …` trigger
conditions) are the two clearest instances, but the shape recurs anywhere a
narrow grammar sits inside a broader one.

**The pattern:** When a compiler position is deliberately given a *narrower*
expression grammar than the language's full grammar supports elsewhere (rule
filters accept only literals/comparisons/property-access/boolean
combinations, not quantifiers/aggregates/relation-traversals/table-lookups;
`When` conditions accept only opaque externally-raised events, not
self-evaluating predicates), an input that falls outside the narrow grammar
must raise a **named, specific diagnostic** (`MER3016`, `MER3017`) — never
silently approximate, coerce to a default, or guess a plausible-looking
substitute.

**Why the narrow grammar itself is correct, not a gap to "fix" by widening it:**

1. **The position has no IR to express the wider form.** A rule filter
   compiles to a single `AssertIR.condition: IRExpression` with no
   surrounding control-flow scaffold; a `When` trigger compiles to a
   `wait for trigger.<event>.fired` stub with no scheduler. A quantifier or
   aggregate implies iteration over a collection and (for aggregates) an
   accumulation strategy — there is nowhere for that structure to live in a
   single expression slot or an event-wait stub. Widening the grammar here
   isn't a parser change; it's inventing new IR/runtime machinery
   (a scheduler, a compound-assert-with-embedded-loop primitive) for a
   position that was deliberately kept terse.
2. **The narrow grammar has a genuine escape hatch elsewhere.** Anything that
   needs a quantifier, aggregate, relation traversal, or table lookup can be
   expressed as an ordinary statement in the skill's own `## Workflow`/`##
   Rules` body (`if`/`assert`/`for each`/`until`), which goes through the
   full `ASTToIR` lowerer with no restriction. The restriction is scoped to
   *one syntactic position*, not to the language as a whole — so there is no
   author need actually left unmet.
3. **Approximating instead of rejecting produces a rule that "compiles" and
   enforces nothing.** This is the concrete failure mode each of these was
   *actually* observed to hit before the loud rejection existed: a relation
   traversal like `"active prescriptions include a contraindicated drug"`
   degraded (with no symbol table in scope) to a meaningless
   `patient.active_prescriptions_include_a_contraindicated == drug`
   comparison; a duration-based `When … has been on hold for more than 7
   days, …` trigger silently compiled to an external-event stub nobody would
   ever raise. Both "worked" (compiled, ran, never errored) while checking
   or firing on literally nothing — strictly worse than a compile-time
   error, because nothing surfaces the gap until an incident.

   Both `MER3016`'s and `MER3017`'s `help:` text carry a worked before/after
   rewrite inline (not just an abstract "move it to `## Workflow`"
   instruction), each modeled on a real, already-compiling corpus file so an
   agent fixing the error cold doesn't have to invent untested syntax:

   - `MER3016`: `A patient whose active prescriptions include a
     contraindicated drug must not receive the new order.` (relation
     traversal — rejected) → `## Workflow` `if any of the patient's active
     prescriptions is contraindicated: stop with "cannot administer:
     contraindicated prescription".` — the same `if any of … is …` shape
     `corpora/clinical/skills/triagepatient.meri` already uses (`if any of
     the vital signs is critical, escalate the patient.`).
   - `MER3017`: `When an order has been on hold for more than 7 days,
     escalate the order.` (self-evaluating duration — rejected) →
     `When an order is flagged as stale, escalate the order.` (opaque
     event, the actual fix applied to `examples/order_processing.meridian`
     in this repo), or a `## Workflow` `while`/`for each` polling loop
     shaped like `corpora/incident/skills/cooldownwatch.meri`'s `while any
     alerts whose status is "firing", for each alert …` loop if the
     duration genuinely needs to be re-checked live.

   **Any new diagnostic for this pattern should follow the same rule: the
   `help:` text must include a concrete, validated before/after rewrite, not
   just a description of the restriction.** An author (or an AI) fixing the
   error cold, with no other context, should be able to copy the shape of
   the "after" example directly.
4. **A false negative is recoverable; a false positive is not.** Given a
   choice between under- and over-detecting the unsupported shape, both
   `isSelfEvaluatingTriggerCondition` and `lowerExprSimple`'s rejection list
   are deliberately biased toward leaving today's behavior alone when
   unsure (a false negative just keeps the status quo) rather than risking
   blocking a legitimate simple form (a false positive breaks something that
   worked). Bare equality/inequality is kept out of the self-evaluating
   check for exactly this reason — it's indistinguishable from idiomatic
   passive-voice event phrasing (`"a refund is requested"`).

**How to tell whether you're looking at this pattern vs. a real bug:** ask
whether the rejected input has a real IR shape to lower into *at that
specific position* — not whether Meridian could express it *somewhere*. If
the answer is "it already has a full-featured equivalent elsewhere
(`## Workflow`), just not in this terse slot," the loud rejection is the
pattern above, not a gap. If the answer is "this input's classifier itself
is unreliable at the position it's checked" (e.g. the pre-fix `symbols: nil`
bug, which was a real recognition failure, not a grammar restriction), that
*is* a bug — fix the classifier, not the restriction.

**See also:** `corpora/GENERATING_A_CORPUS.md` gotchas #6 and #7 (worked
examples of this pattern for `When` triggers and rule predicates,
respectively); `docs/07_DECISIONS.md` `D-DX-2` ("no silent compile-time
fallbacks" — the general principle this pattern is a specific application
of); `docs/09_SKILL_PORTING.md` §"Common porting fixes" item 8 (the
four-way narrative-classification precedence, which draws the same
loud-reject-over-silent-miscategorize line for prose rather than
expressions).

---

### Pattern: A blunt, context-blind classifier is intentional when the alternative is guessing

**Where it shows up:** `EnglishLexicon.normativeCueWords` matching
(`TrialLowering.isNormativeNarrative`, `SkillMigrator+SplitPlan.swift`'s P1
category-4 path) is the clearest instance.

**The pattern:** `normativeCueWords` (`must`/`never`/`always`/`refuse*`/
`require*`/`forbidden`/`mandatory`) flags **any** line containing one of
these words as a candidate contract/invariant — including ordinary
conversational prose that was never meant as a real rule (`"a classified
grant is never issued without an approval record"` inside a narrative
`## Contract` bullet). This looks like it should be smarter — e.g. only
flag imperative/second-person phrasing, or auto-lower the declarative shape
into a `must not` rule — and both of those "smarter" fixes were actually
tried and rejected:

- **A "does this look imperative" heuristic** would silently reclassify real
  third-person-declarative invariants (`"a user's session must expire after
  30 minutes"` — the *normal* way domain rules are phrased) as harmless
  documentation. That's a silent loss of a real rule, which is strictly
  worse than the current behavior.
- **Auto-lowering the declarative shape** (`"X is never Y"` → `X must not
  Y`) requires guessing a semantic mapping that is frequently wrong — `"is
  never issued without an approval record"` is closer to a *precondition on
  the action* than an *invariant on the subject*, and silently compiling the
  wrong one is worse than a loud error asking the author to reword.

**Why blunt-and-loud beats smart-and-silent here:** a word-level match can
only ever produce two kinds of mistake — a false positive (flags harmless
prose, forcing an unnecessary reword) or a false negative (misses a real
rule, silently losing enforcement). Every refinement considered here traded
a reduction in false positives for an increase in false negatives. Because a
false positive costs a human a few seconds of rewording (and the diagnostic
names exactly what to do), while a false negative costs a *silently
unenforced domain rule* discovered only in production, the blunt matcher
that over-flags is the correct trade — do not "fix" it by trying to make it
context-aware unless the smarter version can be proven to never misclassify
a genuine third-person declarative invariant as documentation.

**See also:** `corpora/GENERATING_A_CORPUS.md` gotcha #1 (the full worked
example, including the exact two rejected alternatives);
`IMPLEMENTATION_LOG.md` 2026-07-06T19:25:56Z entry (the investigation that
confirmed this).

---

### Pattern: A capability that needs a host/runtime integration is a compiler *hook*, not a missing compiler *feature*

**Where it shows up:** `When …, …` triggers compile to an external-event
wait stub, never a poller (see the first pattern above); `may` permission
rules generate data-predicate `AssertIR` gates but are actor-blind by
default (no caller-identity check without a custom `PermissionRegistry`,
`docs/README.md` §"Permission enforcement is actor-blind by default");
`llm.decide`/`llm.judge` deterministically return `.boolean(false)` with no
LLM provider configured (`docs/README.md` §"`llm.decide` returns `false`
without an LLM host").

**The pattern:** Some things a workflow author writes in natural language
(`"When an order has been on hold for 7 days"`, `"a manager may approve
this"`, `"use judgment to decide"`) name a capability that fundamentally
requires infrastructure outside the compiler's own scope — a task
scheduler, a caller-identity/session model, a live LLM backend.
`MeridianRuntime` deliberately ships none of these. The compiler's job stops
at emitting a well-defined, inspectable **hook**: a `wait for
trigger.<event>.fired` construct, a `Permission` struct + data-predicate
gate, a `runtime.discretion.decide`/`AIJudgmentIR` call. Wiring the hook up
to something real — a cron job that raises the event, a
`PermissionRegistry` that checks caller identity, a registered `llm.decide`
tool that calls a real API — is explicitly the **host's** job, done by
injecting real implementations at `Runtime` construction time, not
something to add inside `MeridianCore`/`MeridianRuntime` itself.

**Why not build the missing piece in?** Each of these would require
inventing genuinely new architecture with no existing home: a
cron/poll-scheduler primitive, a user-identity/session model, a network
client for an LLM provider — none of which are compiler concerns, and all
of which vary per deployment (which scheduler, which identity system, which
LLM vendor) in ways a single hard-coded implementation could never satisfy
correctly for every host. Building one in blind, guessing at a host's real
requirements, would be worse than leaving an explicit, documented seam.

**How to tell whether you're looking at this pattern vs. a real gap:**
check whether the *hook itself* is inspectable, real, and validated (not a
silent no-op) — `buildTriggerWorkflow` really does resolve/validate its
action and emit a real `wait`; the `Permission` struct really is emitted
and really does gate on the data predicate; `llm.decide` really does return
a deterministic, documented value rather than crashing or hanging. If the
hook itself is broken (doesn't validate, doesn't emit, crashes), that's a
bug. If the hook works exactly as documented and the missing piece is
"nobody has wired in a real scheduler/identity system/LLM provider yet,"
that's this pattern — the fix is host-side integration code, not a
`MeridianCore`/`MeridianRuntime` change.

**See also:** `corpora/GENERATING_A_CORPUS.md` gotcha #6; `docs/README.md`
§"Getting started: key caveats"; `docs/04_RUNTIME.md` §"Permissions and
Policy".

---

### Pattern: A passing gate proves exactly what it checks — not a stronger claim

**Where it shows up:** AGENTS.md pitfall #12 ("`Compiles` means Meridian
emitted Swift *source* — not that it `swiftc`s"); the tiered gate structure
in `AGENTS.md` §4 (`swift test` vs. `GeneratedSwiftTypecheckSlowTests` in
`MeridianSlowIntegrationTests` vs. `scripts/coverage.swift --gate`); `D-DX-3` ("swift-format failure
is a recoverable warning, not an error").

**The pattern:** `Compiler.compile(...)` and `SkillMigrator.compiledOK` only
assert that the pipeline produced Swift *text* without throwing — the result
is never fed to a Swift parser or `swiftc` in that path. So invalid Swift
(unescaped strings, hyphenated identifiers, duplicate declarations) can pass
every "compiles" test and every corpus-conformance test, and only surface
later when `swift-format` chokes or `swiftc -typecheck` actually runs. This
is not an oversight to "fix" by making every compile call typecheck its own
output (that would make every unit test that calls `Compiler.compile` pay
for a full `swiftc` invocation) — it's a deliberate tiering: fast structural
tests run on every change, and generated-Swift typecheck
(`swift test --filter GeneratedSwiftTypecheckSlowTests` / plain `swift test`)
plus `scripts/coverage.swift --gate` are the real Swift validators, with the
slow typecheck suite run on every full gate (once per
substantive session, per `AGENTS.md` §4) because they're expensive.

Similarly, `swift-format` failing on otherwise-valid generated Swift is
surfaced as a **warning**, not a build failure (`D-DX-3`) — formatting is
cosmetic, so keeping unformatted-but-valid output is strictly better than
discarding a correct compile over a cosmetic step.

**Why this matters in practice:** don't treat "the corpus conformance suite
is green" as proof that generated Swift actually type-checks — it isn't
that claim. When touching the emitter, codegen, domain emission, migration,
or the gbrain/corpora corpora, always run the typecheck-gated re-run (see
`AGENTS.md` §4) before trusting the result; a green `swift test` alone is
not sufficient signal for those areas, by design, not by gap.

**See also:** `AGENTS.md` §4 "Phase-gate rule" and pitfall #12;
`docs/07_DECISIONS.md` `D-DX-3`.

---

## Rulebooks (`.merrules`)

*Was `docs/11_RULEBOOKS.md`.*

A **rulebook** extends Meridian's deterministic English surface with
externally-authored, declarative rules. The compiler ships the *engine* plus a
small closed set of roles/rule-kinds; every domain-specific idiom, section
alias, and cross-cutting behaviour is **data** in a `.merrules` file. Adding a
construct for a new domain is an authoring task, not a recompile.

Rulebooks are the generalisation of the existing `=== language ===` synonym
section. They are parsed by `RulebookParser`
(`Sources/MeridianCore/Rulebook/RulebookParser.swift`) — a hand-written
recursive-descent parser in the same style as `MerConfigParser` — and applied
by `RewriteEngine` (desugars) and `ConventionInjector` (behavioural rules).

> **Design rule — surface vocabulary is data, not code.** Never hardcode an
> English-surface word/phrase list (articles, prepositions, comparison markers,
> duration units, assertion introducers like `make sure`/`ensure`/`assert`,
> quantifier determiners, connectors, stop-words, …) inside the parser, lowering,
> or codegen. It belongs in `EnglishLexicon` and — when it should be
> domain-extensible — in the `=== language ===` section (or a `.merrules`
> rulebook), so authors can extend the surface without recompiling Meridian. See
> AGENTS.md §3 "No hardcoded English-surface vocabulary" for the end-to-end
> procedure; `assertionMarkers` / `Assertion synonyms:` is the reference example.

---

### The invariant that keeps the core clean

Whatever a rule produces is validated by the **same** core checks as normal
lowering: strict-mode phrase resolution, the scoped-tool allow-list, the
no-unmarked-prose rule, and the no-new-primitives rule. A rule is a
**compile-time equivalence**, never a runtime decision. It therefore can never:

- widen the tool scope,
- bypass strict mode, or
- introduce an LLM call.

Determinism holds by construction. A malformed rule fails loudly with source
attribution rather than silently degrading.

---

### Wiring a rulebook into a compile

Reference a rulebook from frontmatter with the `rulebook:` key (comma-separated,
alongside `vocabulary:`):

```
---
name: capture
vocabulary: brain.merconfig
rulebook: brain.merrules
---
```

(There is no `skill: true` flag — the section-role model activates structurally
whenever the body contains a `##`/`###` heading.)

Programmatically, rulebooks are passed as `[RulebookInput]`, analogous to
`[VocabularyInput]`:

```swift
let out = try Compiler(options: .init()).compile(
    meridianSource: meri, meridianFile: "capture.meri",
    vocabularies: [brainVocab],
    rulebooks: [RulebookInput(name: "brain", file: "brain.merrules", source: rulesSrc)]
)
```

The core's default rulebook is **empty**, so existing `.meridian`/`.meri` files
that don't list a `rulebook:` are byte-for-byte unaffected.

---

### File structure

A `.merrules` file has four section families, each introduced by a
`=== name ===` header (the same delimiter style as `.merconfig`). `#` comment
lines are ignored.

```
=== desugar ===
=== sections ===
=== conventions ===
=== triggers ===
```

---

### Family 1 — Desugar rules (`=== desugar ===`)

A desugar rule rewrites an English surface form into a canonical Meridian
statement. Each rule has a `match:` pattern with typed holes (`{name}`) and
either a `rewrite:` template (re-parsed through the normal path) or a
`lowers to:` template (the validated escape hatch).

```
rule "arrow-conditional":
  match: If {condition} -> {action}
  rewrite: {action} only when {condition}.

rule "report-emit":
  match: Report: {message}
  lowers to: emit skill.report with message = {message}.
```

- **`rewrite:` (preferred, surface-only).** The output re-parses + lowers
  through the strict pipeline, so a bad rewrite fails loudly. Use this for
  anything expressible as an existing canonical statement.
- **`lowers to:` (escape hatch).** Targets one of the 12 existing primitives
  directly via the canonical statement surface (e.g. `emit …`). This is "use an
  existing primitive directly," **not** hand-authored IR and **not** new
  semantics. Reserve it for constructs with no clean canonical equivalent.

Holes are matched by a hand-written matcher over `[SourceLine]`; captured holes
are parsed by the existing Expression/Statement parsers. The engine applies
rules ordered by priority then source order, as a bounded fixpoint (reusing the
depth-8 inline limit); conflicts are first-match-wins. Every rewrite step is
logged under the `rulebook` trace category.

Idioms the shipped `brain.merrules` covers: `If … -> …` / `If … then …` arrow
conditionals, `Report:` / `Output:` → `emit skill.report`, Markdown checklists
(`- [ ] item`, `[x] item`, `□ item`) → `make sure …` asserts, and the
command-with-annotation idiom below.

#### Worked example — a desugar rule that reaches the command surface

The deterministic command surface (a fenced ` ```bash ` block or an inline
backticked command on its own line → one `shell.run` invoke) is detected by
`parseInlineChain` / `inlineBacktickedCommand` **before** the per-statement
desugar hook runs. So that a desugar rule's *output* can also become a command,
the engine applies the desugar **at the top of `parseBlock`'s loop** (before the
command/chain detectors), replacing the source line with its rewrite. A rule can
therefore normalize a surface variant into the canonical
backticked-command-with-annotation form and have it routed to the shell path:

```
rule "annotated-command":
  match: Run `{command}` to {purpose}
  rewrite: `{command}` -- {purpose}.
```

`` Run `gbrain doctor --json` to check index health. `` rewrites to
`` `gbrain doctor --json` -- check index health ``, which lowers to a single
`shell.run` invoke whose `command` is `gbrain doctor --json` and whose
`-- check index health` note is emitted as a `//` source comment above the call.

The annotation (a trailing ` -- <note>` recognized **outside** backticks — so a
`--flag` or an in-backtick ` -- ` is never split) is a parser feature of the
command surface itself; the rule above merely produces the canonical form. The
rewrite is fixpoint-stable, so the downstream per-statement desugar hook is a
no-op second pass, and the whole path is inert without a `rulebook:`.

---

### Family 2 — Section-role rules (`=== sections ===`)

A section rule maps one or more Markdown heading aliases to one of the **closed**
`SkillSectionRole` values. The roles and their lowering strategies are core; the
alias → role mapping is data.

```
section "Contract", "Guarantees", "Invariants" -> invariants
section "Phases", "Workflow", "Protocol", "Steps" -> procedure
section "When To Use", "Primary Triggers" -> applicability
section "When NOT To Use", "Do NOT Use" -> negative-applicability
section "Anti-Patterns", "Pitfalls" -> prohibitions
section "Output Format", "Result Format" -> template
```

The closed role set (exhaustive `switch`, no `default:`):

| Role | Lowers to |
|---|---|
| `invariants` | `assert` (the skill's guarantees become runtime-checked). |
| `procedure` | Executable statements (deterministic phrase invocations / idioms). |
| `applicability` | Deterministic preconditions: checkable conditions → `if <cond>, complete.` guards; literal phrases → dispatch predicates. |
| `negative-applicability` | Negative guards: checkable conditions → soft-skip `if <cond>, complete.`; literal phrases → negative dispatch predicates. |
| `prohibitions` | `must not` asserts where structurally checkable. |
| `template` | Declared result template (fenced literal + `{{ }}` interpolation). |
| `reference` | Outline / manifest metadata only — no executable lowering. The preferred non-executable-documentation role; `meridian migrate-skill` emits `(( role: reference ))` for genuinely documentary content and never emits `inert`. |
| `inert` | Same as `reference` (a hand-authorable synonym kept for backward compatibility) — Outline / manifest metadata only, no executable lowering. |

An **unmarked** heading with no rulebook alias resolves to its built-in default
(`SkillSectionRole.builtinRole(forHeading:)`, which also recognizes the
`Phase N: …` prefix and common applicability/output variants). The built-in
aliases are themselves **data** — `SkillSectionRole.builtinSectionAliases` (a
single table, also exposed as the `Rulebook.defaultSections` rulebook) — so the
defaults and author `=== sections ===` extensions share one representation.
Resolution precedence is `rulebook alias ?? builtin`. A heading that
resolves to nothing **and has content** is a hard `semanticError` — there is no
silent `reference`/`inert` fallback. The author then adds a `=== sections ===`
alias here, forces a role inline with `(( role: <R> ))`, or marks it
`(( role: reference ))`. Section semantics activate **structurally** on the
presence of a `##`/`###` heading; there is no `skill: true` flag.
`=== sections ===` aliases are the sanctioned, data-only path for
organizational/applicability headings — see `sample-gbrain/brain.merrules` and
`examples/skill/skill.merrules`.

#### `meridian migrate-skill`'s classification vocabulary

`SkillMigrator` (the `.meri`-porting engine behind `meridian migrate-skill`)
never emits `(( inert ))`: every non-lowerable block resolves to lower /
`use judgment …` (if an inference cue is present) / `(( role: reference ))`
(if documentary) / a hard reword error (otherwise). Three `=== language ===`
sub-blocks tune this classification — `Inference-cue synonyms:`,
`Normative-cue synonyms:`, and `Reference-heading synonyms:` — each wired
through the same `EnglishLexicon` recipe as the categories above (Family 1's
opening design-rule callout applies equally here). Full defaults and the
worked `=== language ===` example live in
[03_LANGUAGE.md](03_LANGUAGE.md#skillmigrator-classification-synonyms-p1-four-way-policy);
the end-to-end porting policy lives in
[09_SKILL_PORTING.md](09_SKILL_PORTING.md).

#### Fuzzy conditions are a hard error

An applicability / negative-applicability condition that is **neither** a literal
dispatch phrase **nor** structurally checkable (e.g. "the request is ambiguous",
"the entity is notable") raises a compile-time `semanticError`. The author must:

1. rephrase it to a checkable predicate,
2. move it to `triggers:` as a literal dispatch phrase, or
3. wrap it in an explicit `use judgment to …:` marker.

It is never silently turned into an LLM check or silently dropped.

---

### Family 3 — Conventions (`=== conventions ===`)

Conventions are Inform-style, cross-cutting behaviours declared **once** and
injected into every matching workflow by `ConventionInjector`. They use the
`before` / `after` phase verbs with an action clause and an indented body.

```
=== conventions ===

# Iron-Law back-linking: any page that mentions an entity gets a reciprocal link.
after writing a page that mentions an entity:
  create a back-link from the entity to the page.

# Notability gate before creating entity pages.
before writing a page about an entity:
  make sure the entity is notable.

# Brain-first: consult the local knowledge graph before any external call.
before calling an external service:
  check the brain first.
```

`ConventionInjector` matches a convention's action against each workflow by
token overlap (stemmed, stopword-stripped), then prepends (`before`) or appends
(`after`) the lowered body. This makes gbrain's Iron-Law / notability /
brain-first guarantees a single shared rulebook entry instead of per-skill
restatement — fewer edits, DRY, and matching gbrain's own `conventions/` design.

The convention body is parsed and lowered through the same strict pipeline as
any workflow statement, so an unresolved phrase inside a convention is a hard
error.

---

### Family 4 — Trigger words (`=== triggers ===`)

`triggers:` frontmatter entries describe **how** a skill is activated and are
classified into a closed `TriggerKind` — `keyword` / `ambient` / `event` /
`schedule` — by `TriggerClassifier`. The classification keyword sets are data:
built-in defaults live in `Rulebook.defaultTriggers`, and a rulebook extends them
per kind. `keyword` is the fallback (no words needed); the other three are
keyword-driven (plus cron-shape detection for `schedule`).

```
=== triggers ===
schedule: fortnightly, quarterly
ambient: firehose
event: ingested, reconciled
```

Each line is `<kind>: word1, word2, …` where `<kind>` is a `TriggerKind` raw
value; an unknown kind is a hard `semanticError`. Author words **add to** (never
remove from) the built-in set for a kind — `Rulebook.triggerWordSets()` unions
`defaultTriggers` with the author rules. So with the block above, a `triggers:`
spec of `fortnightly digest` classifies as `schedule` while the built-in
`nightly`/`webhook received`/… still classify as before.

A trigger never reaches the LLM: each compiles to a deterministic `wait` + a
`trigger.<name>.fired` fan-out event (the host owns actual firing; routing is the
resolver workflow's job). The typed kind + spec are recorded in the manifest
under `meridian_skill.triggers`. See [03_LANGUAGE.md](03_LANGUAGE.md)
for the `triggers:` frontmatter surface.

---

### Extending a rulebook is pure data

Adding a new idiom or section alias requires **no dispatcher edit** — only a new
rule entry:

```
=== desugar ===
rule "memo-emit":
  match: Memo: {message}
  lowers to: emit skill.report with message = {message}.

=== sections ===
section "Recipe" -> procedure
```

This is exercised directly in
[`Tests/MeridianCoreTests/SampleGbrainConformanceTests.swift`](../Tests/MeridianCoreTests/SampleGbrainConformanceTests.swift)
("a new desugar idiom + a new section alias can be added as pure rulebook
data"), which adds both as inline data and compiles a skill that uses them with
zero changes to compiler code.

---

### Tracing

Set the `rulebook` trace category to see every desugar rewrite and convention
injection with source attribution:

```bash
MERIDIAN_TRACE=rulebook meridian compile sample-gbrain/skills/ingest.meri \
    --merconfig sample-gbrain/brain.merconfig
```

See also [06_DEVELOPER_EXPERIENCE.md](06_DEVELOPER_EXPERIENCE.md).

### Built-In Wave 4 Section Roles

`## Domain` (`Vocabulary`, `Types`) is a non-executable section whose body is
harvested as vocabulary before workflow parsing. Use it for small skill-local
kind/property/state declarations.

`## Tables` (`Data Tables`, `Dispatch Tables`) is executable. Unmarked Markdown
pipe tables in this section default to data mode, while explicit `!!! table`
markers still override the mode. Rulebook `=== sections ===` aliases can route
other recurring table headings to `tables` when a corpus uses different
terminology.

---

## Prose and autonomy

*Was `docs/12_PROSE_AND_AUTONOMY.md`.*

Meridian supports two opt-in prose modes for SKILL.md-shaped workflows.

`with discretion` is plan-then-execute mode. Unmatched English lines in that
workflow are lowered to `IRPrimitive.aiJudgment(AIJudgmentIR)`; generated Swift
calls `runtime.executeProsePlan(...)`. The runtime asks a typed `Planner` for a
`PlanProposal`, validates each proposed tool against the scoped tool list, and
executes the action itself.

`with autonomy` is loop mode. Unmatched English lines are lowered to
`IRPrimitive.aiAutonomy(AIAutonomyIR)`; generated Swift calls
`runtime.executeAutonomousLoop(...)`.
The runtime asks an `ActPlanner` for one action per turn, records observations,
routes every action through the same sealed executor, and can call a `Planner`
again after repeated failures.

`AIJudgmentIR` and `AIAutonomyIR` are separate IR structs (not one primitive
distinguishing modes via a `dispatchMode` field) — codegen (`emitAIJudgment` /
`emitAIAutonomy`), the manifest (`judgment_steps` / `autonomy_steps`, below),
and any IR-walking code each handle the two modes as distinct cases, so a
`switch` over `IRPrimitive` cannot forget one. The AST layer still carries
a single `ProseStepAST` with a `ProseDispatchMode`; `ASTToIR.makeAIPrimitive`
is the one place that dispatches AST mode → IR case.

Autonomy `until` and `unless` header clauses are enforced by generated
predicates over the runtime's current `StateSnapshot`. The runtime checks
`unless` as an abort guard and `until` as a success stop before planning; after
each accepted action, result bindings are merged into the loop snapshot so the
next predicate check can stop on newly produced state.

Examples:

```meridian
To plan risky cleanup for a pull request, with discretion:
  Read the current diff and propose the smallest safe cleanup actions.

To stabilize a pull request, with autonomy until the ci status is passed re-plan after 2 failures:
  Keep inspecting CI and apply the next smallest safe repair.
```

The LLM boundary is typed:

- `LLMProvider` can only produce completions.
- `Discretion` can only answer a boolean question.
- `Planner` can only propose a bounded plan.
- `ActPlanner` can only propose the next action or declare done.
- `PlanExecutor` is runtime-owned and validates tool IDs before invocation.
- Planner actions are validated against registered `ToolSchema` argument specs
  when a schema is present: missing required arguments, unexpected arguments,
  and common type mismatches are rejected before invocation.

Strict workflows still reject unresolved lines. Prose fallback only applies
inside headers that explicitly opt in with `with discretion` or `with autonomy`.

### Entry points

There are **three** ways prose reaches the planner — all of them explicit, none
of them a silent fallthrough:

1. A workflow header opts in with `, with discretion` / `, with autonomy` (every
   body line is prose — see the strict contract below).
2. A local `use judgment to <goal>:` / `with discretion:` / `with autonomy …:`
   marker wraps one block inside an otherwise-deterministic workflow.
3. A **fuzzy Markdown table or checklist** is routed to the planner with a
   `(( ai-discretion ))` / `(( ai-autonomy ))` marker (below).

All three lower through the same `ProseStepAST`, which `ASTToIR.makeAIPrimitive`
turns into `IRPrimitive.aiJudgment(AIJudgmentIR)` or `.aiAutonomy(AIAutonomyIR)`
by dispatch mode; (2) and (3) carry an explicit dispatch, so they are valid in
**any** workflow.

#### Optional guidance: extra planner context distinct from the goal

`ProseStepAST` (and both `AIJudgmentIR`/`AIAutonomyIR`) carry an optional
`guidance: String?` alongside `text`. `text` stays the short dispatch goal;
`guidance`, when present, is extra narrative context handed to the planner
without being folded into that goal. The one producer today is the `use
judgment to follow the <heading> guidance:` migrator idiom (below): it
collects the section's leftover narrative verbatim into `guidance` rather than
concatenating it onto `text`. Ordinary `use judgment to <goal>:` / `with
discretion:` / `with autonomy …:` blocks with an indented instruction body
still fold that body into `text` unchanged — `guidance` is specifically for
narrative context that a section's migrator-generated judgment step inherited
from its own (otherwise-`reference`) documentation, not a second copy of the
instructions themselves.

`guidance` threads end to end on both IR cases: `SwiftEmitter.emitAIJudgment` /
`emitAIAutonomy` each emit it as a trailing `guidance: "…"` argument on
`runtime.executeProsePlan`/`executeAutonomousLoop`; `PlanContext.guidance` /
`ActContext.guidance` carry it into `Planner`/`ActPlanner` implementations;
`ManifestEmitter` records it per workflow under `judgment_steps[].guidance` /
`autonomy_steps[].guidance` so it is auditable from the
`.meridian.manifest.json` without reading the generated Swift.

#### Fuzzy tables and checklists → the planner

A decision table whose condition cells are *intent descriptions* (not checkable
comparisons) and an acceptance checklist whose items are *not structurally
checkable* are workflow steps that need judgment — not documentation, when they
genuinely carry an inference cue. Instead of marking them `(( role: reference
))`, route them (a cue-less fuzzy table/checklist is a reword error, not a free
pass to either judgment or reference — see `docs/09_SKILL_PORTING.md` P1):

```meridian
## Route the request

!!! table (( ai-discretion ))
| Condition                          | Action                      |
|------------------------------------|-----------------------------|
| user asks for a deterministic run  | submit a shell job          |
| user asks for an iterative agent   | spawn a research subagent   |

## Confirm

!!! checklist (( ai-autonomy ))
- [ ] all entity pages are cross-linked
- [ ] no DRY violations across skills
```

- `!!! table (( ai-discretion ))` → `TableParser.aiDecisionProse` renders the
  rows as a ruleset (`when <conds>, <action>`; a wildcard row → `otherwise, …`)
  and emits `IRPrimitive.aiJudgment(AIJudgmentIR)`: the planner picks the
  matching case and carries out its action. `(( ai-autonomy ))` emits
  `.aiAutonomy(AIAutonomyIR)` (a loop) instead.
- `!!! checklist (( ai-autonomy ))` → `checklistProse` embeds every criterion as
  the loop goal ("Ensure every acceptance criterion below holds, taking
  corrective action until all are satisfied: - …") and emits
  `IRPrimitive.aiAutonomy(AIAutonomyIR)`. `(( ai-discretion ))` verifies/resolves
  once via `.aiJudgment(AIJudgmentIR)`.

The criteria/rules are embedded **verbatim** in the prose step text, so the
planner has the full ruleset as its goal context. The enclosing section must be
executable (a `(( role: reference ))` — or hand-authored `(( inert ))` —
section still suppresses the whole body). See
[03_LANGUAGE.md](03_LANGUAGE.md) for the marker
grammar and [09_SKILL_PORTING.md](09_SKILL_PORTING.md) rule 12 for the
"does the workflow act on this?" porting heuristic.

### Failure Identity

Planning/prose failures use stable `PlanningFailureCode` raw values carried by
`MeridianRuntimeError.toolError(.implementation(code: ...))`. Generated
`recover from ...:` blocks can match these names through `meridianMatches`.

Current codes:

- `planning.prose_payload_too_large`
- `planning.tool_arguments_payload_too_large`
- `planning.too_many_actions`
- `planning.replan_too_many_actions`
- `planning.max_steps_exceeded`
- `planning.host_policy_denied`
- `planning.tool_out_of_scope`
- `planning.tool_not_registered`
- `planning.missing_tool_argument`
- `planning.unexpected_tool_argument`
- `planning.invalid_tool_argument_type`
- `planning.snapshot_payload_too_large`
- `planning.history_payload_too_large`
- `planning.proposal_payload_too_large`

Telemetry uses the same values: `plan.error` includes `error_code` when one is
available, and `plan.rejected` includes `code`.

Resource limits cover prose bytes, state snapshot bytes, observation-history
bytes, planner-proposal bytes, action count, and tool-argument bytes. Accepted
prose/autonomy actions checkpoint the post-action loop snapshot so resume
contexts include planner-produced bindings.

### Strict contract: discretion / autonomy bodies are always prose

A workflow declared `with discretion` or `with autonomy` runs every body line
through the planner — there is no deterministic fallthrough. Even if a body
sentence happens to share words with a deterministic vocabulary phrase
(e.g. "Inspect the failing job…" overlapping with `to inspect the ci status of
a pull request`), the lowering emits an `aiJudgment`/`aiAutonomy` primitive and
the `Planner` / `ActPlanner` decides what runtime actions are taken. This is enforced in
`ASTToIR.lowerPhraseInvocation` and is verified by the
[`SkillExampleCorpusTests`](../Tests/MeridianCoreTests/SkillExampleCorpusTests.swift)
suite.

### Worked examples

End-to-end prose / autonomy samples live under `examples/skill/`. They share
the standalone `comprehensive_workflows.merconfig` vocabulary so each file can
focus on a single feature:

- `flaky_ci_stabilizer.meri` — autonomy with `until` / `unless` / replan / max steps.
- `large_release_train.meridian` — deterministic gate → discretion → autonomy.
- `policy_guarded_autonomy.meridian` — recover from `planning.host_policy_denied`
  and `planning.tool_out_of_scope`.
- `planner_schema_validation_demo.meri` — recover from every schema-validation
  `PlanningFailureCode` and from `planning.max_steps_exceeded`.
- `hotfix_commander.meridian` — autonomy abort guard via `unless` predicate
  combined with `wait for approval` and `wait for signal`.
- `incident_pr_response.meri` — discretion plan + autonomy mitigation with
  recover-on-failure cleanup.

Structural lowering assertions for each sample (autonomy config presence,
discretion vs autonomous-loop dispatch mode, recover code names, and so on)
live in [`SkillExampleCorpusTests`](../Tests/MeridianCoreTests/SkillExampleCorpusTests.swift).

---

## Deontic norms and obligations

*Was `docs/20_DEONTIC.md` (Wave 9).*

Meridian's **deontic layer** expresses prohibitions (`must not invoke …`),
obligations (`… must hold`), and permissions (`may invoke …`) as first-class
norms attached to skill, workflow, section, or kind scope. The compiler lowers
them onto existing IR primitives — attempt-time guards on `invoke`, effect-time
`assert` metadata, and recover routing — without a dedicated deontic IR
primitive.

Normative meaning lives in [`docs/cookbook/MERIDIAN_SEMANTICS.md`](cookbook/MERIDIAN_SEMANTICS.md) §7–8. Surface examples appear in
[`docs/cookbook/MERIDIAN_SYNTAX_COOKBOOK.md`](cookbook/MERIDIAN_SYNTAX_COOKBOOK.md) Part VI. This document is the
maintainer-facing reference for enforcement, diagnostics, and audit hooks.

---

### Norm kinds

| Surface | Norm kind | Enforcement time | Trace disposition |
|---|---|---|---|
| `must not invoke <tool> [whose …]` | prohibition | **Attempt-time** — before the tool runs | `violated (prevented)` when blocked |
| `<predicate> must hold [, blocking]` | obligation | **Effect-time** — at commit points and section exits | `violated (observed)` on failure |
| `may invoke <tool> [only where …]` | permission | **Attempt-time** — default-deny scopes require a covering grant | denied invoke if uncovered |

**Attempt-time** norms govern whether an `invoke` may proceed. A prevented
prohibition still emits a trace event — auditors see the attempt, not only the
outcome ([SEM-7-02](cookbook/MERIDIAN_SEMANTICS.md), decision D3).

**Effect-time** obligations check state or trace-backed conditions at designated
evaluation points. Blocking obligations route failure through `recover` and halt
the section; non-blocking obligations record `violated (observed)` and continue
unless the author marks the obligation `blocking`.

Advisory modals (`should`, `ought to`, `probably must`) are rejected at
compile time ([MER-DEO-003](#diagnostic-catalog)). Outcome words (`must not
fail`) are not actions — use `must not invoke …` or `<predicate> must hold`
instead ([MER-DEO-005](#diagnostic-catalog)).

---

### Scope attachment

Norms bind where they are authored:

- **Skill scope** — `This skill must not …` or a Contract-section sentence with
  no narrower qualifier.
- **Workflow scope** — workflow-prefixed forms (future tightening) or norms
  harvested from a named workflow's executable section.
- **Kind scope** — `A customer must not invoke …` binds the norm to instances of
  that kind.
- **Section scope** — `Within Phase 3, this skill must not …` (when supported
  by rulebook sugar).

Conflict analysis compares scopes using a containment lattice: skill ⊃ workflow
⊃ section; kind scopes interact only with matching kind subjects.

---

### Blocking routing

The `blocking` keyword on an obligation is the **only** way to make a violation
halt the enclosing section. Non-blocking obligations record the violation and
continue — the Contract section is the audit surface for which claims can stop
execution.

Lowering wires blocking obligations to `AssertIR.blocking` and attaches recover
handlers when authored. Prohibitions may also carry blocking disposition on the
guarded invoke arm.

---

### Conflict lattice (MER-DEO-001 / MER-DEO-002)

| Situation | Code | Behavior |
|---|---|---|
| Same-scope prohibition and permission overlap the same invoke pattern | [MER-DEO-001](#diagnostic-catalog) | **Compile-time error on both spans** — no silent winner |
| Inner `may` grant inside an outer `must not` prohibition | [MER-DEO-002](#diagnostic-catalog) | **Sticky deny** — inner permission cannot override outer prohibition |
| Non-overlapping scopes or patterns | — | Both norms lower; evaluation applies the most specific applicable norm |

Overlap is defined on normalized `toolID` plus argument constraints: identical
tool with empty or compatible `whose` clauses overlaps; conditioned permissions
narrow the pattern.

---

### Permissions generalize `scopedTools`

A bare tool id in `## Tools Used` or `scopedTools` is the degenerate permission
`may invoke <tool>` with no argument conditions. Wave 9 adds **argument-conditioned**
permissions:

```text
This skill may invoke slack.send only where the channel is one of "#incidents", "#alerts".
The briefing skill may invoke email.send only where the recipient is the user's own address.
```

`only where …` lowers to invoke guards evaluated **per attempt**. Table-conditioned
lookups in the permission predicate (Composition Gallery line 6) compose with
the same guard mechanism.

Mixing bare allow-list entries and conditioned `may` lines in one skill is legal:
each invoke is checked against the union of covering permissions.

Tool use outside the permission envelope in a judgment block is diagnosed as
[MER-DEO-004](#diagnostic-catalog) (reserved / partial enforcement in 9B).

---

### D12 witness envelopes

Runtime `recordViolation` emits `EventKind.violated` with operational detail
(`prevented` vs `observed`). Decision D12 reserves structured witness payloads
(tool id, argument hash, scope, norm id) for auditor-grade receipts.
Population of the full witness envelope in traces is Wave 9C work; compile-time
norm ids already carry the stable identity needed to correlate trace events with
norms.

---

### `meridian explain` and `[OBL-…]` annotations

`meridian explain` prints Canonical English for lowered norms and annotates each
with its norm id by default:

```text
[OBL-a1b2c3d4] This skill must not invoke deploy.run whose target is production.
```

Opt out with `--no-norm-ids`. The annotation links human-readable audit output
to the stable norm identity used by runtime trace events without recompilation.

---

### Argument-conditioned permission example

From the Composition Gallery (cookbook Part VII, line 6):

```text
This skill may invoke slack.send only where the channel is the channel
corresponding to the severity "sev2" in the escalation table.
```

The permission guard evaluates the table lookup on each `slack.send` attempt.
Tests: `CompositionGalleryTests.gallery6` (parse + verbalize round-trip).

---

### Worked prohibition + obligation (Release Sentinel)

Contract norms from the north-star example:

```text
This skill must not invoke deploy.run whose target is production.
The sentinel may invoke slack.send only where the channel is one of "#incidents", "#alerts", "#releases".
Since the last production deploy, no critical alert has occurred. This must hold, blocking.
```

Fixture: `Tests/MeridianCoreTests/Fixtures/Trace/release-sentinel-wave9.meri`.

---

### Diagnostic catalog

| Code | Trigger |
|---|---|
| MER-DEO-001 | Same-scope prohibition and permission overlap (both spans reported) |
| MER-DEO-002 | Inner `may` cannot override outer `must not` (sticky deny) |
| MER-DEO-003 | Non-norm modal (`should`, `ought to`, …) |
| MER-DEO-004 | Tool invoke outside permission scope |
| MER-DEO-005 | Outcome-as-action (`must not fail`) |
| MER-DEO-006 | Norm id prefix collision after semantic hash |

Broken Twin line 8 exercises MER-DEO-001; see
[`docs/cookbook/MERIDIAN_NORTHSTAR_EXAMPLE.md`](cookbook/MERIDIAN_NORTHSTAR_EXAMPLE.md) Part C and
`DeonticBrokenTwinTests` in `Tests/MeridianCoreTests/Inform7/`.

---

### Related documents

- [`docs/01_OVERVIEW.md`](01_OVERVIEW.md) — formal prover discharge boundary
- [`docs/04_RUNTIME.md`](04_RUNTIME.md) — trace-backed `since … must hold`
- [`docs/cookbook/MERIDIAN_SEMANTICS.md`](cookbook/MERIDIAN_SEMANTICS.md) §7–8 — normative oracle
- [`docs/05_CLI.md`](05_CLI.md) — `meridian explain` flags

---

## Modules and shared imports

*Was `docs/22_MODULES_AND_IMPORTS.md`.*

Status: Final Wave Phase F (SEM-MOD-01, SEM-MOD-02 companion).

Meridian modules package reusable vocabulary — domain kinds, tools, constants,
language synonyms, and `=== imports ===` chains — under a stable module id.
Skills import modules instead of copying `.merconfig` fragments.

### Package layout

```
modules/
  shared-domain/
    module.meridian     # optional manifest frontmatter
    module.merconfig    # required vocabulary entry point
```

Discovery order for `import <name>`:

1. `<anchor>/<name>/module.merconfig`
2. `<anchor>/<name>.merconfig`
3. Each `--module-path/<name>/module.merconfig`

`<anchor>` is the importer's directory (the skill or merconfig being compiled).

### Surface syntax

**Skill frontmatter**

```yaml
---
imports: shared-domain, billing-core as billing
vocabulary: local.merconfig
---
```

**Merconfig section**

```merconfig
=== imports ===
import shared-domain
import billing-core as billing
```

Both `import <module>` and `import module <module>` are accepted. Optional
`as <alias>` renames the merged vocabulary bucket (defaults to the module id).

Legacy `vocabulary:` frontmatter remains for direct `.merconfig` references
alongside module imports.

### Merge semantics

1. Resolve the import graph (depth-first, deterministic by module name).
2. Merge module configs in topological order.
3. Merge the importer's local `.merconfig` and inline `## Domain` sections on
   top — **importer wins** on name collisions.
4. If a module export is listed in manifest `sealed:` (or `sealed:` frontmatter),
   the importer cannot override that symbol (MER-MOD-004).

Cross-module export collisions (same kind/tool name from two imports) are
MER-MOD-003. Cycles are MER-MOD-002. Missing packages are MER-MOD-001.

### Manifest (`module.meridian`)

```yaml
---
module: shared-domain
version: 1.0.0
exports: public
sealed: policy, customer
---
```

- `exports: public|internal` — `public` modules publish symbols on the export
  surface (cross-module collision checks). `internal` modules still merge
  vocabulary for direct importers but do not export symbols to sibling imports.
- `sealed:` — comma-separated symbols the importer must not redefine.

### Lockfile

`ModuleLockfile` records resolved `{id, path, contentHash, alias?}` entries in
sorted order for reproducible builds. Hosts may persist the JSON beside a skill;
the compiler computes it during bootstrap.

### CLI

```bash
meridian compile skill.meridian --module-path ./modules
meridian check skill.meridian --module-path ./modules
meridian explain skill.meri --module-path ./modules
```

### API

- `ModuleManifest` — parsed manifest metadata
- `ModuleResolver` — graph resolution + cycle/collision checks
- `ModuleSymbolSnapshot` — exported symbol sets per module
- `ModuleLockfile` — deterministic lock encoding
- `Compiler.Options.moduleSearchPaths` / `anchorDirectory`

### Related

- SEM-MOD-01: `docs/cookbook/MERIDIAN_SEMANTICS.md` §10.1
- SEM-MOD-02: explicit imports + deployment allow-lists (no implicit globals)
