# Meridian — Language Quick Reference

Two file types: `.merconfig` (vocabulary) and `.meridian` (workflows).

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

| Phrase | Operator |
|---|---|
| `equals` / `is` | `==` |
| `does not equal` / `is not` | `!=` |
| `is less than` / `is fewer than` | `<` |
| `is more than` / `is greater than` | `>` |
| `is at most` / `is no more than` | `<=` |
| `is at least` / `is no fewer than` | `>=` |
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
something can't be resolved: an unknown phrase, an unparseable rule, a rule
whose action verb doesn't match any workflow, or a trigger whose action
doesn't lower. Each of these raises a hard `semanticError`. Set the
`allow-fallbacks` frontmatter key to a comma-separated list of fallback
kinds to opt back into the older silent behaviour for **this file only**:

```
---
name: experimental
allow-fallbacks: unresolved-phrases, unattached-rules
---
```

The four fallback kinds:

| Kind | What's allowed |
|---|---|
| `unresolved-phrases` | A phrase invocation that doesn't match any phrase or workflow lowers to an `_unresolved` `BindIR` placeholder. |
| `unparseable-rules` | A rule whose text the analyser cannot classify is dropped from IR (still recorded in the manifest). |
| `unattached-rules` | A rule that classified but matched no workflow is dropped from IR (still recorded in the manifest). |
| `unresolved-trigger-actions` | A `When …, do X` trigger whose action verb resolves to nothing emits the `trigger.X.fired` fan-out event without validating that the action workflow exists. |

`allow-fallbacks: all` (or `*`) opts into every kind. Without the key, every
listed failure is reported as a sourced compile-time error pointing at the
offending line.

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
```

Synonyms are merged into the `EnglishLexicon` before parsing begins. They take
priority over defaults (prepended to the comparison-marker list).

---

## Phase 8 additions — Executable rules (Phase C)

Rules at the top of a `.meridian` file are now lowered to executable IR
rather than being documentation-only.

### Rule forms

| Form | Lowers to |
|---|---|
| `A customer with status suspended must not place orders.` | `AssertIR` prepended to matching workflow |
| `A customer must not place an order whose total amount is more than their credit limit.` | `AssertIR` with two-parameter predicate |
| `An order … must be approved by an account manager before fulfillment.` | `WaitIR(.approval(…))` prepended |
| `When an order has been on hold for more than 7 days, escalate the order.` | New synthetic `IRWorkflow` with `WaitIR(.event)` |
| `A customer with status verified may place orders.` | Permission struct entry; softens matching `must not` assertions |

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
