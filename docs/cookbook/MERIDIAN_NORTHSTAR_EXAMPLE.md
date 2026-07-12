# MERIDIAN_NORTHSTAR_EXAMPLE.md
## The end-state language, proven on paper: two complete skills, walked end to end

Version: draft 0.2 (comprehensive). Purpose: validate the whole design before any advanced wave is built. If these files read badly, the design is wrong and finding out cost a document. Three sections: Example A (Release Sentinel, agent-ops domain, exhaustive walkthrough), Example B (Ledger Reconciliation Sentinel, enterprise migration domain, the commercial case), and the Broken Twin (error UX on paper). A structured review protocol closes the document.

---

# EXAMPLE A: RELEASE SENTINEL

Chosen to exercise every layer: domain kinds with keying, definitions including temporal adjectives, a relation with a verb, a table, filters and quantifiers, typed holes, three-valued branching, temporal and statistical conditions, all three norm types, a quarantined judgment block, and templated output.

## A.1 The source: `release-sentinel.meri`

```
# Release Sentinel

## Domain

A service is a kind of value.
A service has a text called the name.
A service has a text called the owner.
A service can be production or staging. A service is usually staging.
A service is keyed by the name.

A deploy is a kind of value.
A deploy has a text called the service name.
A deploy has a date called the finished at.

An alert is a kind of value.
An alert has a text called the severity.
An alert has a text called the service name.
An alert has a date called the opened at.
An alert is keyed by the service name.

Ownership relates one engineer to various services.
Ownership is read from the service's owner.
The verb to own means the ownership relation.

Definition: an alert is critical if its severity is "sev1".
Definition: an alert is fresh if it was opened within the last 24 hours.
Definition: a service is flaky if its deploy step has failed at least 2 times within the last 7 days.
Definition: a service is troubled if it is flaky and at least 1 fresh critical alert whose service name is its name exists.

## Tables

| severity (text) | channel (text) |
| --------------- | -------------- |
| "sev1"          | "#incidents"   |
| "sev2"          | "#alerts"      |

## Contract

This skill must not invoke deploy.run whose target is production.
The sentinel may invoke slack.send only where the channel is one of #incidents, #alerts, #releases.
Every emitted note matches pattern "\[Run: .+\]" .
The fetch step succeeds in at least 95% of runs, checked every 1 days.

## Phases

1. Gather the field.
   fetchctl pull --service "{the service's name}"
   let the open alerts be the fresh alerts whose service name is the service's name, sorted by opened at, newest first.

2. Decide the posture.
   if the service is troubled:
       let the posture be "halt".
   if it is unknown whether the service is troubled:
       let the posture be "watch".
   otherwise:
       let the posture be "proceed".

3. Escalate when needed.
   for each critical open alert:
       let the channel be the channel corresponding to the severity "sev1" in the escalation table.
       slackctl send --channel "{the channel}" --text "{the alert's severity}: see sentinel note"

4. Verify the window.
   Since the last production deploy, no critical alert has occurred. This must hold, blocking.

5. Compose the note.
   use judgment to compose the status narrative, producing a text called the narrative, using gbrain search:
       Weigh stability against urgency. Keep it under five sentences. Lead with the posture.

## Output Format

[Run: {{ the run id }}]
Posture: {{ the posture }}
[if the service is flaky]This service is flaky.[otherwise]Deploy history is clean.[end if]
[if it is unknown whether the service is flaky]Deploy history is too thin to judge.[end if]
[for each critical open alert]- {{ the alert's severity }} opened {{ the alert's opened at as a short date }}[end for]
{{ the narrative }}
```

## A.2 Read-aloud observations (the design claims this file makes)

1. The bare perfect never appears: every temporal claim carries `ever`, a window, a count, or `since the last`. MER-TMP-010 made vagueness unwritable, and the file reads BETTER for it, which is the whole bet.
2. Step 2's unknown arm was not the author's idea; the totality rule forced it. `troubled` depends on `flaky`, `flaky` contains a windowed count over the trace, the trace may be thinner than the sample basis, so the condition is possibly-indeterminate, so the branch must say what happens under ignorance. The language converts an unexamined assumption into a written decision. No mainstream language does this at compile time.
3. Definitions stack: `troubled` composes `flaky` (temporal) with a keyed quantified existence claim. Four definitions turn the Phases into nearly plain English.
4. The Contract is the entire risk surface of the skill in eight lines: what it may never do, what it may do conditionally, what its output always looks like, and what reliability it claims. A reviewer who reads only the Contract knows the blast radius.
5. The judgment block is five lines in a file where everything else is deterministic. Its contract line (output kind text, tool scope gbrain search) is kernel; only the prose is quarantined.
6. Keying does silent load-bearing work: `flaky` on a service queries only THAT service's deploy events because `keyed by the name` ties instances to event subjects. Without keying this definition would be ill-formed (MER-TMP-016), not silently global.

## A.3 Lowering map (what the compiler produces, step by step)

Domain:
- Three kinds with properties; one enum with default; two keyed kinds. Swift: three Codable structs; enum with a default initializer path; key metadata into the trace-query layer.
- Ownership: relation record backed by property path `service.owner`; verb table entry for own/owns/owned.
- Four adjective predicates: `isCritical(Alert)`, `isFresh(Alert)` (temporal, keyed), `isFlaky(Service)` (temporal, keyed), `isTroubled(Service)` (composes the others plus a count query). Each is one pure function taking (instance, snapshot, traceAPI, now) as needed; `isTroubled`'s possibly-indeterminate flag is set transitively.

Contract:
- Prohibition OBL-7f3a: no `deploy.run` invoke exists in this skill, so the attempt-time guard compiles to nothing at runtime and the obligation artifact records kind unreachability with status statically-satisfied. (If a later edit adds such an invoke, the guard appears automatically; the norm is durable, not advisory.)
- Permission OBL-9c11: argument guard wrapped around every `slack.send` lowering: channel must be in the literal set; out-of-set attempt emits `violated (prevented)` and skips per non-blocking default.
- Regex invariant OBL-2b58: AssertIR after each emit, regex built-in.
- Statistical monitor OBL-d402: scheduled evaluation artifact with cadence 1 day, threshold 0.95, denominator runs, sample floor from config; emits asserted events with three-valued outcome.

Phases:
- Step 1: hole-bound `shell.run` invoke (escaped interpolation of `service.name`); then a query plan: source = alerts fetch point, filter = isFresh AND serviceName == service.name, sort = openedAt desc; bound as `openAlerts`.
- Step 2: three-valued branch; codegen represents the condition as a three-valued enum; the unknown arm is a real branch target, not a catch.
- Step 3: iterate over filter(isCritical, openAlerts); table lookup compiles to a constant dictionary access with miss routed to recover; second hole-bound invoke wrapped by OBL-9c11's argument guard.
- Step 4: effect-time obligation at section exit: evaluate the since-form against the trace; on false emit `violated (observed)`, blocking => recover route; on indeterminate (no production deploy in retention) totality forced an explicit policy at compile time (see Broken Twin C.7 for the error when it is missing; here assume the author added `if it is unknown whether ..., this holds vacuously.` after D7a is decided).
- Step 5: judgment invoke: emits `judged` with input hash, output hash, declared kind text, tool scope.
- Output: template AST; conditional, unknown-conditional, loop; formatters from the registry; final emit guarded by OBL-2b58.

## A.4 Full canonical verbalization (`meridian explain release-sentinel.meri`, abridged only at Domain, which prints as written)

```
Release Sentinel.

Contract.
  [OBL-7f3a] This skill must not invoke deploy.run whose target is production.
             (statically satisfied: no such invoke exists)
  [OBL-9c11] The sentinel may invoke slack.send only where the channel is one of
             #incidents, #alerts, #releases.
  [OBL-2b58] Every emitted note matches pattern "\[Run: .+\]".
  [OBL-d402] The fetch step succeeds in at least 95% of runs, checked every 1 days.

Phase 1. Gather the field.
  Run: fetchctl pull --service "{the service's name}".
  Let the open alerts be the fresh alerts whose service name is the service's name,
  sorted by opened at, newest first.

Phase 2. Decide the posture.
  If the service is troubled, let the posture be "halt".
  If it is unknown whether the service is troubled, let the posture be "watch".
  Otherwise, let the posture be "proceed".

Phase 3. Escalate when needed.
  For each critical open alert:
    Let the channel be the channel corresponding to the severity "sev1"
    in the escalation table.
    Run: slackctl send --channel "{the channel}" --text "{the alert's severity}: see sentinel note".
    [guarded by OBL-9c11]

Phase 4. Verify the window.
  [OBL-e917] Since the last production deploy, no critical alert has occurred.
             This must hold, blocking.

Phase 5. Compose the note.
  Use judgment to compose the status narrative, producing a text called the narrative,
  using gbrain search:
      Weigh stability against urgency. Keep it under five sentences. Lead with the posture.
```
What this artifact is for: a reviewer reads THIS, not the author's text and not the Swift. Drift between authored and canonical is a separate categorized report; meaning-bearing drift should be empty.

## A.5 The obligation artifact set (complete)

```json
[
 {"id":"OBL-7f3a","span":"release-sentinel.meri:30","scope":"skill:release-sentinel@sha256:ab12",
  "kind":"unreachability","status":"statically-satisfied",
  "condition_ir":{"invokePattern":{"tool":"deploy.run","args":[{"path":"target","cmp":"is","value":"production"}]}},
  "canonical_english":"This skill must not invoke deploy.run whose target is production."},

 {"id":"OBL-9c11","span":"release-sentinel.meri:31","scope":"skill:release-sentinel@sha256:ab12",
  "kind":"coverage","status":"guarded",
  "condition_ir":{"permitPattern":{"tool":"slack.send","args":[{"path":"channel","cmp":"is one of",
    "value":["#incidents","#alerts","#releases"]}]}},
  "canonical_english":"The sentinel may invoke slack.send only where the channel is one of #incidents, #alerts, #releases."},

 {"id":"OBL-2b58","span":"release-sentinel.meri:32","scope":"skill:release-sentinel@sha256:ab12",
  "kind":"invariant","status":"guarded",
  "condition_ir":{"emitMatches":{"pattern":"\\[Run: .+\\]"}},
  "canonical_english":"Every emitted note matches pattern \"\\[Run: .+\\]\"."},

 {"id":"OBL-d402","span":"release-sentinel.meri:33","scope":"skill:release-sentinel@sha256:ab12",
  "kind":"statistical-monitor","status":"monitored",
  "condition_ir":{"frequency":{"event":{"step":"fetch","outcome":"success"},"denominator":"runs",
    "cmp":"at least","p":0.95,"cadence":"P1D","sampleFloor":20}},
  "canonical_english":"The fetch step succeeds in at least 95% of runs, checked every 1 days."},

 {"id":"OBL-e917","span":"release-sentinel.meri:56","scope":"skill:release-sentinel@sha256:ab12#phase-4",
  "kind":"invariant","status":"guarded","blocking":true,
  "condition_ir":{"sinceLast":{"anchor":{"kindEvent":"deploy","where":[{"path":"target","cmp":"is","value":"production"}]},
    "holds":{"noneOf":{"kindEvent":"alert","adjective":"critical"}}}},
  "canonical_english":"Since the last production deploy, no critical alert has occurred."}
]
```
Properties to test: byte-stable across two clean builds; ids stable under unrelated edits; canonical_english always equals the verbalizer's output for the same IR (one source of truth, two views).

## A.6 Trace walkthrough (evaluation, the contrast, the monitor, and a violation)

Retained trace for service "checkout" (key = name), evaluation instant t = Jun 12, 09:00, retention 30 days, sample floor 20. Events (tag, subject(key), outcome, at):

```
e41 invoked    deploy-step(checkout)  -            Jun 06 10:02
e42 completed  deploy-step(checkout)  success      Jun 06 10:04
e50 emitted    alert(checkout)        sev2         Jun 08 09:00
e57 invoked    deploy-step(checkout)  -            Jun 09 17:30
e58 completed  deploy-step(checkout)  failure      Jun 09 17:31
e60 emitted    deploy(checkout)       production   Jun 10 12:00
e66 emitted    alert(checkout)        sev1         Jun 11 07:50
e71 invoked    deploy-step(checkout)  -            Jun 11 08:15
e72 completed  deploy-step(checkout)  failure      Jun 11 08:16
e80 invoked    slack.send(#general)   -            Jun 11 08:17
```

- `flaky`: window opens Jun 05 09:00; keyed failures: e58, e72; count 2 >= 2: TRUE.
- The in-a-row contrast (SEM-5-05): qualifying subsequence is keyed deploy-step completions regardless of outcome: e42, e58, e72. Most recent 2 are e58, e72, both failures: in-a-row(2) TRUE. Had the order been failure, success, failure: count-in-window still TRUE, in-a-row FALSE. Same trace family, different claims, both checkable; this pair is the layer's signature test.
- `fresh` for e66's alert at t: opened Jun 11 07:50, within 24h of Jun 12 09:00? 25h10m ago: FALSE. Note the trap: a human skimming "yesterday morning" calls it fresh; the semantics does not. The walkthrough keeps this case deliberately because boundary intuition is where reviewers must calibrate.
- `troubled`: flaky TRUE, but fresh critical alerts count = 0 (e66 not fresh): FALSE => posture "proceed". If t were O8:00, e66 is fresh and troubled is TRUE => "halt". One hour, different posture, fully explainable from the trace.
- OBL-e917: anchor = e60 (most recent production deploy). Critical alerts after e60: e66. Condition FALSE => `violated (observed)`, blocking => recover. The skill halts and the trace shows exactly why, with event ids.
- OBL-9c11 and e80: channel #general is outside the permitted set => the guard fires, e80's invoke is replaced by `violated (prevented)`; Slack never receives it; the auditor still sees the attempt.
- OBL-d402: suppose 12 runs in window, 12 < 20 => outcome INDETERMINATE recorded; not false, not silent.
- Coherence harness: replaying this trace through the obligation evaluator must reproduce exactly these verdicts; any disagreement names the obligation id and event ids.

## A.7 Drift report sample (`meridian drift release-sentinel.meri`)

```
synonym-canonicalized (2):
  line 44: "newest first" kept; "filtered to" in earlier draft would print as whose-form
  line 47: "every meeting" style all-form: none present
structure-normalized (1):
  Phase 2 arm order: unknown arm printed after the true-arm (authored order preserved in source, canonical order in explain)
desugar-expanded (1):
  line 45 annotation bullet expanded to invoke + comment
meaning-bearing residue (0)
```
The empty last category is the health signal; non-empty means the compiler read something the author did not write, and that line is the review meeting.

---

# EXAMPLE B: LEDGER RECONCILIATION SENTINEL (the enterprise case)

Domain: a legacy-to-modern migration running in shadow mode, Sybase-era ledger writes mirrored into a new system, with WDD-style parity receipts. This is the commercial demonstration: the language carrying real migration invariants (double-entry balance, parity, no-oversell-shaped constraints) in reviewable English. Walked completely but less exhaustively than A.

## B.1 The source: `ledger-recon.meri`

```
# Ledger Reconciliation Sentinel

## Domain

A journal entry is a kind of value.
A journal entry has a text called the entry id.
A journal entry has a decimal called the debit total.
A journal entry has a decimal called the credit total.
A journal entry has a text called the source system.
A journal entry is keyed by the entry id.

A parity receipt is a kind of value.
A parity receipt has a text called the entry id.
A parity receipt has a text called the verdict.
A parity receipt is keyed by the entry id.

Definition: a journal entry is balanced if its debit total is its credit total.
Definition: a journal entry is legacy-sourced if its source system is "sybase".
Definition: a parity receipt is clean if its verdict is "match".
Definition: a journal entry is reconciled if exactly 1 clean parity receipt whose entry id is its entry id exists.
Definition: the pipeline is degraded if the parity step has failed at least 3 times within the last 1 hours.

## Tables

| verdict (text) | action (text)   |
| -------------- | --------------- |
| "match"        | "none"          |
| "amount-drift" | "quarantine"    |
| "missing"      | "replay"        |

## Contract

Every journal entry processed by this skill must be balanced. This must hold, blocking.
This skill must not invoke ledger.write whose target system is "sybase".
The recon skill may invoke ledger.write only where the target system is "mongo-ledger".
The parity step succeeds in at least 99% of occurrences, checked every 4 hours.
Every emitted receipt matches pattern "\[Entry: .+, verdict: .+\]" .

## Phases

1. Pull the shadow batch.
   reconctl pull --window "{the batch window}"
   let the batch be the legacy-sourced journal entries sorted by entry id, ascending.

2. Gate on health.
   if the pipeline is degraded:
       complete with the note "degraded; deferring batch".
   if it is unknown whether the pipeline is degraded:
       proceed, and note "thin history" in the receipt trailer.

3. Reconcile each entry.
   for each of the batch:
       parityctl check --entry "{its entry id}"
       if it is not reconciled:
           let the action be the action corresponding to the verdict of its latest parity receipt in the verdict table.
           reconctl apply --entry "{its entry id}" --action "{the action}"

4. Assert the books.
   all of the batch are balanced. This must hold, blocking.
   at most 0 of the batch are not reconciled, or the unreconciled entries were quarantined within the last 1 hours. This must hold.

5. Report.
   use judgment to summarize anomalies for the migration lead, producing a text called the summary, using gbrain search:
       Name patterns, not individual entries. Flag anything suggesting systematic drift.

## Output Format

[Entry batch: {{ the batch window }}]
Balanced: {{ the number of balanced journal entries in the batch }} of {{ the number of the batch }}
[for each of the first 5 journal entries in the batch that are not reconciled]- {{ its entry id }}: {{ the verdict of its latest parity receipt }}[end for]
{{ the summary }}
```

## B.2 Why this example matters commercially

1. The double-entry invariant (`must be balanced, blocking`) is the OFBiz-class hard invariant expressed in one English sentence with attempt-to-effect enforcement and an audit trail. This single line is the demo for every modernization client conversation: the constraint a CFO cares about, readable by the CFO, enforced by the compiler, witnessed in traces.
2. `must not invoke ledger.write whose target system is "sybase"` is zero-trust modernization as a norm: the shadow system physically cannot write back to the legacy system, and prevented attempts are still visible. That is the receipts story with teeth.
3. `reconciled` shows definitions doing WDD work: parity receipts are trace-adjacent artifacts, and "exactly 1 clean receipt exists" is characterization-test logic in domain English.
4. `degraded` is an ops circuit breaker as a temporal adjective; step 2's unknown arm encodes the cold-start policy explicitly, which is precisely the conversation ops teams never have until 3am.
5. Decimal exactness (cookbook 1) is silently load-bearing: `balanced` compares decimals exactly; in a float language this invariant is a lie.

## B.3 Compressed walkthrough

- Lowering highlights: `balanced` is a pure decimal equality; `reconciled` is a keyed exactly-1 quantifier over a receipts fetch point; `degraded` is a keyless skill-scoped temporal count (legal at workflow level; the keying rule applies only to kind-instance definitions). Step 4's first sentence is an obligation over a quantifier; its second composes a quantifier with a temporal window inside an or, exercising K3 and gallery-style composition.
- Trace sketch: a batch of 40 entries, one with debit 1200.00 / credit 1199.99: `balanced` FALSE => step 4's blocking obligation emits `violated (observed)` naming the entry id via the failing instance (the evaluator records the witness instance in the violation payload: a semantics-amendment candidate, see Risks 1.5), recover runs, the batch is held. The obligation artifact, the violation event, and the verbalized Contract line form one auditable chain from English to event id.
- The monitor: parity step at 99% of occurrences with a 4 hour cadence: 600 checks, 4 failures = 99.33%: asserted success; 7 failures = 98.8%: assert-failed, non-blocking, visible.

---

# PART C: THE BROKEN TWIN (error UX on paper)

A deliberately flawed Sentinel fragment; each numbered line triggers the named error. The right column is the test list for Wave 8/9 problem messages.

```
1.  if the deploy step has failed:                                  MER-TMP-010 (bare perfect)
2.  if the deploy step has failed within the last 90 days:          MER-TMP-011 (retention 30; both durations named)
3.  since the build is slow, skip the deploy.                       MER-TMP-012 (causal since)
4.  Definition: a service is flaky if it has failed recently.       MER-TMP-017 then MER-TMP-016 ordering: vague window reported first
5.  Definition: a deploy is risky if it will fail.                  MER-TMP-013 (future tense)
6.  if the service is flaky: let the posture be "halt".
    (no otherwise / unknown arm)                                  MER-STA-001
7.  Since the last production deploy, no critical alert has
    occurred. This must hold, blocking.                             MER-STA-001 variant at obligation site when D7a policy is missing
8.  The sentinel may invoke slack.send where the channel is "#ops".
    This skill must not invoke slack.send.                          MER-DEO-001 (same-scope conflict; both spans)
9.  use judgment to clean up old alerts:                            MER-JDG-001 (no produced value; effectful intent)
10. let the best service be the best service.                       MER-DSC-001 (ungraded superlative) plus self-reference note
11. for each deal whose status looks active:                        MER-CND-001
12. A page can be archived or live. A page is usually live.
    A page is usually archived.                                     MER-DOM-002
```
Note: ordinary `otherwise` now explicitly covers BOTH false and indeterminate when no unknown arm exists. The older line-6 variant with an `otherwise:` arm is therefore no longer an error under the confirmed semantics; the true-arm-only fragment above remains the canonical missing-totality fixture.

Acceptance idea this enables: the Broken Twin compiles to EXACTLY this error list, in this order, as a snapshot test; problem-message wording can evolve, codes and spans cannot.

---

# PART D: STRUCTURED REVIEW PROTOCOL (run before Wave 7 begins)

## D.1 Read-aloud pass (30 minutes)
Read A.1 and B.1 aloud, marking any line that feels like code wearing an English costume. Each mark is a grammar smell; file it against the cookbook entry it instantiates. Known candidates planted for calibration: gallery line 4's superlative-inside-event-pattern (legal, should it lint harder?), B step 4's compound or-sentence (is it one sentence too clever?).

## D.2 Decision questions (answer in the Decision Register, one sitting)
1. Step 2 ergonomics: is the forced unknown arm acceptable, or is `treating unknown as flaky` sugar needed at launch? (Sugar is a later desugar; the DEFAULT posture toward ignorance is semantics.)
2. D7a: anchorless `since` under blocking obligations: uniform indeterminate (strict), or trivially-compliant for obligations only (pragmatic)? B's cold-start argues strict; ops ergonomics argue pragmatic. Decide once.
3. Violation witness payloads (B.3): should obligation violations carry the witnessing instance key? Recommended yes; requires semantics amendment (Risks 1.5).
4. `[OBL-...]` annotations in explain output: default on or off? (Audit gold vs reading noise; one flag either way, the default is the demo.)
5. Shared Domain imports: B duplicates nothing yet, but two skills over one ledger domain will. Module system is Wave 10+ material; confirm it stays deferred.
6. Is `proceed, and note "..." in the receipt trailer` (B step 2) a real form or hand-waving? If real, it needs a cookbook entry (compound step with emit-annotation); if not, rewrite B before it becomes folklore.

## D.3 Coverage audit (one hour, mechanical)
For every cookbook Part I to VI section, find its instantiation in A or B; any section with no instantiation gets one added to an example or is consciously marked exercised-by-tests-only. Current known gaps to resolve: `is one of` list form (A has it in Contract only), `reversed` verbs (neither), `at most` quantifier (neither), `exists` comparator (B implicitly).

## D.4 Exit criterion
This document, the cookbook, the semantics amendments, and the Decision Register are mutually consistent and the maintainer has signed each (a line in IMPLEMENTATION_LOG.md per document, with date). Then, and only then, hand Wave 7 to Cursor.
