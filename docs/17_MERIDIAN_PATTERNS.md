# Meridian — Architectural Patterns

This doc catalogs recurring architectural patterns behind Meridian's compiler
— the "why is it built this way, and why is that intentional rather than a
bug" reasoning that's too deep for `AGENTS.md` (always-injected, kept lean)
and too cross-cutting for a single `.cursor/rules/*.mdc` (area-scoped,
attaches per file glob). `docs/15_DECISIONS.md` (generated from
`DecisionCatalog`) covers the same territory but only for decisions tied to a
specific diagnostic code; a pattern here may span several diagnostics, or
none. When you're about to "fix" something that turns out to already be
intentional, check here first — and when you resolve a "why not fixed?"
question that isn't captured yet, add a pattern for it instead of leaving the
reasoning buried in a chat transcript or a single `IMPLEMENTATION_LOG.md`
entry.

---

## Pattern: A restricted sub-language rejects unsupported forms loudly instead of approximating them

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
respectively); `docs/15_DECISIONS.md` `D-DX-2` ("no silent compile-time
fallbacks" — the general principle this pattern is a specific application
of); `docs/13_SKILL_MD_PORTING.md` §"Common porting fixes" item 8 (the
four-way narrative-classification precedence, which draws the same
loud-reject-over-silent-miscategorize line for prose rather than
expressions).

---

## Pattern: A blunt, context-blind classifier is intentional when the alternative is guessing

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

## Pattern: A capability that needs a host/runtime integration is a compiler *hook*, not a missing compiler *feature*

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
§"Getting started: key caveats"; `docs/06_RUNTIME.md` §"Permissions and
Policy".

---

## Pattern: A passing gate proves exactly what it checks — not a stronger claim

**Where it shows up:** AGENTS.md pitfall #12 ("`Compiles` means Meridian
emitted Swift *source* — not that it `swiftc`s"); the tiered gate structure
in `AGENTS.md` §4 (`swift test` vs. the `MERIDIAN_*_TYPECHECK=1`-gated
re-run vs. `scripts/coverage.swift --gate`); `D-DX-3` ("swift-format failure
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
tests run on every change, and the two typecheck-gated env vars
(`MERIDIAN_GOLDEN_TYPECHECK=1`/`MERIDIAN_GBRAIN_TYPECHECK=1`/
`MERIDIAN_CORPORA_TYPECHECK=1`) plus `scripts/coverage.swift --gate` are the
*only* real Swift validators, run deliberately less often (once per
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
`docs/15_DECISIONS.md` `D-DX-3`.
