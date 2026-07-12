# MERIDIAN_DESIGN_RISKS_AND_REVIEW.md
## Hazard map for the advanced waves: required amendments, grammar collisions, engineering traps, security, versioning, and review gates

Version: draft 0.2 (comprehensive). Purpose: the problems worth anticipating on paper because they are expensive to discover in code. Each item names the risk, the failure mode if ignored, and the mitigation already encoded or the decision still owed. Sections 1, 4, and 5 contain items that MUST be resolved as amendments to MERIDIAN_SEMANTICS.md before Wave 8 implementation; the document leads, the code follows.

---

# 1. REQUIRED SEMANTICS AMENDMENTS

Gaps found while drafting the cookbook and the north star. Each originally got a clause-number proposal and SEM reservation here before implementation; amendments 1.1 through 1.9 are now folded into `MERIDIAN_SEMANTICS.md` v0.2.

Confirmation status: D0 through D4, D7, D7a, D8, D9, and D10 are now CONFIRMED. Only D11 and D12 remain explicitly deferred/open from this register.

## 1.1 Three-valued boolean composition (new clause 2.4.1)
Clauses 5 and 6 introduce indeterminate; clause 2.4 defines and/or/not classically. Unpatched, two Cursor sessions will implement two short-circuit behaviors and the difference will surface as a heisenbug in composed conditions.
Amendment: adopt Kleene strong three-valued logic (K3): `false and unknown = false`, `true or unknown = true`, `true and unknown = unknown`, `unknown or false = unknown`, `not unknown = unknown`. Totality (the mandatory unknown handling) is enforced at DECISION POINTS only: branch conditions, blocking obligations, and quantifier results feeding either. Inside expressions, unknown flows freely. Short-circuit evaluation is permitted as an optimization exactly because K3 makes it semantically invisible (`false and X` never needs X). Reserve SEM-2-10 (nine-cell truth table tests) and SEM-2-11 (decision-point enforcement tests).

## 1.2 The possibly-indeterminate static analysis (new clause 6.6)
The Wave 8 prompt says syntactic and conservative; the semantics must say exactly what that means or the analysis will creep.
Amendment: an expression is possibly-indeterminate iff it syntactically contains (a) a statistical operator, (b) a `since the last` form, or (c) an adjective whose definition body is possibly-indeterminate, computed transitively over the (acyclic) definition graph. No flow analysis, no constant propagation, no window-size reasoning in v1; conservatism is the spec, not a shortcut. Reserve SEM-6-05.

## 1.3 Temporal adjective keying (amend clause 5.7, add 2.1.1)
`flaky` on a service must query only that service's events. Unpatched, every temporal adjective silently queries globally: wrong, and undetectable in small tests.
Amendment: kinds may declare `keyed by the <property>` (one key, inherited by subkinds). Inside a definition on kind K containing event patterns, every event pattern is implicitly restricted to events whose subject key equals the instance's key. A temporal definition on an unkeyed kind is ill-formed (MER-TMP-016). Workflow-level temporal conditions (no instance) are keyless and scope by run/skill as before. Reserve SEM-5-09 (keyed restriction), SEM-5-10 (unkeyed error).

## 1.4 Anchorless since under blocking obligations (Decision D7a, confirmed)
D7 says anchorless `since` is indeterminate. For a BLOCKING obligation, indeterminate means what: block (strict), pass (pragmatic), or compile-time demand for an explicit policy arm? North-star B's cold-start scenario argues strict; ops ergonomics argue pragmatic. Confirmed outcome: compile-time demand, consistent with totality everywhere else: a blocking obligation over a possibly-indeterminate condition must carry an explicit `if it is unknown whether ...` policy. Uniformity wins; sugar can soften later.

## 1.5 Violation witness payloads (amend clause 7 / 4.1)
North-star B.3: when `all of the batch are balanced` fails, the violation event should name the witnessing instance (the unbalanced entry id), or audits degrade into rerunning the batch to find the culprit.
Amendment: `violated` and `assert-failed` events over quantified or description-based conditions carry a witness field: the key (or full payload per capture policy) of one failing instance, plus the failing count. Deterministic witness choice: first in query-plan order. Reserve SEM-7-05.

## 1.6 Time and duration semantics tightening (amend clause 2.3 / 4.5)
Durations are physical (7 days = 168 hours); no calendar arithmetic, no DST awareness, no timezones in v1. Dates compare on the timeline; `as a short date` formats in a single configured zone per deployment. Unpatched, "within the last 1 days" near a DST boundary becomes a support ticket. Amendment: one paragraph stating physical-time-only, deployment zone for formatting, calendar arithmetic deferred. Reserve SEM-2-12.

## 1.7 Trace append failure policy (Decision D8, confirmed)
What happens when witnessing itself fails (disk full, store error)? For an audit-first language this is a first-class semantic question, not an ops detail.
Confirmed: fail-closed when a skill carries a blocking `AssertIR` or blocking monitor; otherwise fail-open with a degraded-witnessing marker event (`failed`, subject `trace-store`) emitted when witnessing degrades or recovers. This now lives in semantics clause 4.7 as SEM-4-07.

## 1.8 Payload capture policy (Decision D9, confirmed)
Traces capture invoke arguments and results; section 4 of this document explains why that is a privacy and secrets problem. Semantics must define capture modes before the store exists.
Confirmed: per-tool capture policy in merconfig is `full` (payload + hash), `hash-only`, or `redacted(fields...)`. The content hash is always mandatory (parity and coherence need it). Development may default to full; production REQUIRES an explicit policy per tool (compile error otherwise). This now lives in semantics clause 4.8 as SEM-4-08.

## 1.9 Concurrency and the qualifying subsequence (now folded into clause 5 preamble)
`simultaneously` interleaves events within one run. An in-a-row claim whose qualifying events can be emitted by parallel branches of the same subject has order determined by interleaving: semantically defined (run order) but author-surprising.
Amendment: state that run order includes interleavings; add a LINT (not an error) when an in-a-row pattern's subject can be touched inside a simultaneously block. This is now folded into the semantics preamble for clause 5 with SEM-5-11 (interleaving determinism test: same event sequence, same answer, regardless of which branch emitted).

---

# 2. GRAMMAR COLLISION ANALYSIS

The parser fights to expect, each with its disambiguation mechanism and the test that pins it.

2.1 **"has" is triple-booked.** Domain declaration (`A page has a text called the summary`), emptiness (`has no incoming links`), temporal perfect (`has failed within the last ...`). Mechanisms: domain reading is position-locked (assertion/condition split); temporal reading requires an explicit marker (ever/window/count/in-a-row) via MER-TMP-010, so the bare perfect never reaches ambiguity; emptiness is the fixed shape `has no <noun>`. Tests: one sentence per reading, plus the pathological `has occurred no times` pinned as unparseable.

2.2 **"since" is double-booked in English** (temporal vs causal). Only `since the last <event pattern>,` parses; causal usage gets MER-TMP-012 with a rewrite to `if` or prose. Test with genuine causal sentences harvested from the corpora, not invented ones.

2.3 **"usually" is double-booked internally**: domain default (`A page is usually live`) vs statistical (`usually succeeds`). Position-locked like 2.1; the verbalizer prints the statistical reading numerically, so printed language never exhibits the ambiguity. Paired test.

2.4 **Adjective vs enum value namespace.** `active` as definition and as enum value on one kind path makes `the active deals` ambiguous. MER-DEF-003 at definition site, checked over the whole lattice path, both directions (defining the adjective second OR declaring the enum second).

2.5 **Verb participle vs adjective.** Declared verb `to archive` yields participle `archived`; an enum value or adjective `archived` on the same kind collides in `the archived pages` (relation restriction vs property restriction). MER-REL-004 at declaration site, lattice-wide, both orders.

2.6 **"the last" is double-booked**: `since the last production deploy` (anchor) vs `the last 7 days` (window) vs `the last 3 pages` (take-suffix, if ever added). v1: take is `the first N` only; do NOT add `the last N` as take, reserving `the last` for temporal anchors and windows. Log as a deliberate exclusion.

2.7 **"no" is triple-booked**: quantifier (`no urgent deals exist`), emptiness (`has no incoming links`), event negation (`no critical alert has occurred`). All three are distinct fixed shapes; the ambiguity regression suite must include minimal pairs.

2.8 **"may" in prose vs deontic may.** Position-locked to Contract/workflow/Domain scopes; inside judgment prose it is verbatim text. One test.

2.9 **Property names colliding with reserved heads.** A user property named `the number` or `the list` collides with `the number of <description>`. Rule: `number of` and `list of` are reserved phrase heads; properties may not be named `number` or `list` bare (MER-DOM-004 family extension). Cheap now, painful later.

2.10 **Desugar vs round-trip.** Rulebook desugars rewrite pre-parse, so `V(parse(authored))` differs from authored wherever idioms fired: BY DESIGN, the `desugar-expanded` drift category. The law is IR equality (`parse(V(ir)) = ir`), never authored-string equality. Risk: a future session "fixes" round-trip by comparing authored text. Restated here because it WILL be attempted.

2.11 **Ambiguity regression at scale.** Waves 2 to 4 roughly triple productions; accidental ambiguous parses between new and old forms are inevitable without machinery. Mandatory: an ambiguity regression suite that parses every cookbook example, every gallery line, and every corpus sentence asserting EXACTLY ONE parse each, run on every grammar-table change forever. The suite is cheap; archaeology after a shipped ambiguity is not.

2.12 **Plural morphology of kind names.** Descriptions need plurals (`the stale pages`); kinds with irregular plurals (`entry/entries`) need declared plurals or a regular default with declared exceptions: `A journal entry (plural journal entries) is a kind of value.` Default +s/+ies rule; declaration overrides. Without this, B's domain does not parse and nobody notices until B is typed in.

---

# 3. ENGINEERING HARD SPOTS

Where agent implementations typically go wrong; each with the test that catches it.

3.1 **Step-path stability.** Temporal operators, obligations, and WDD key on stable step identities; positional-index paths reshuffle history on every edit, silently corrupting in-a-row semantics. Requirement (Wave 8B): structure-derived paths plus the unrelated-edit test (edit phase 5, assert phase 1 to 4 paths unchanged). Treat failures as release-blocking, never flaky.

3.2 **The qualifying-subsequence rule (SEM-5-05).** The most likely silent miscount: counting failures over the whole trace instead of over qualifying attempts. Canonical tests: the north-star e42/e58/e72 contrast, both orderings, plus interleaved other-subject and other-run events, plus a prevented invoke (does a prevented attempt qualify? Answer per semantics: prevented invokes never produced a completion, so no; pin it).

3.3 **Clock and ordering edges.** Same-millisecond events, ULID tiebreaks, replay across stores. Differential test: identical event sequences through in-memory and JSONL stores produce identical operator answers, including boundary-instant events (window edge inclusive at the old end).

3.4 **Trace volume and indexing.** Iterate-heavy skills emit per-iteration events; 100k-event benches are realistic. Budget: sub-millisecond per operator query at 10k events with a per-run (tag, subject) index in the file store. If JSONL cannot hold the line with that index, THAT is the moment SQLite is allowed, not before.

3.5 **Crash consistency of the JSONL store.** Partial trailing writes after a crash must not poison the store. Requirement: line-framed records with per-line checksum; reader tolerates and quarantines a torn final line; hash chaining (when enabled) detects anything worse. Crash-recovery test with truncated files at every byte offset of the last record (a loop, not a sample).

3.6 **Guard interaction with commit/recover.** A prevented invoke inside a committed group must not half-poison the group; an observed obligation failure inside commit must fire recover exactly once. Semantics 9.3 defers formalization; until then, two targeted integration tests carry the weight, and any surprise found there becomes a semantics amendment, not a code workaround.

3.7 **Three-valued plumbing in codegen.** The cheap mistake: representing unknown as a thrown error or as false-with-a-flag. Requirement: a real three-valued enum through condition evaluation, with K3 tables unit-tested at the codegen level (not only at the language level), because optimizer-style shortcuts reintroduce two-valued assumptions.

3.8 **Replay determinism vs the moving now.** `meridian trace-eval --at t` must pin the evaluation instant; any code path that reaches for the wall clock during replay breaks SEM-5-08. Requirement: now is a parameter threaded explicitly; a lint or review grep for direct clock access in the evaluator.

3.9 **Verbalizer totality vs velocity.** Totality-as-build-failure means every grammar PR writes a print template; the predictable agent move is placeholder templates. Forbid placeholders: CI greps the canonicalization table for TODO/FIXME/placeholder markers; review rejects empty-ish templates.

3.10 **Generated code size.** Definitions, guards, monitors, and instrumentation all add Swift; a 50-skill corpus could bloat. Track generated-LOC per skill in the deviation index from Wave 8 onward; investigate any 2x jump at a wave boundary (usually a codegen template repeating what should be a runtime helper).

---

# 4. SECURITY AND PRIVACY (new section; resolves into D9 and store requirements)

4.1 **Traces are a data liability by design.** Invoke payloads contain user data, customer records (B's journal entries), and potentially secrets in command arguments. A trace store with full payloads is a shadow database of everything the skills touched, with none of the access controls of the systems of record. Mitigations: capture policy per tool (amendment 1.8); hash-only mode preserves parity/coherence checking without retention of content; redacted mode for known-sensitive fields; retention rho doubles as a compliance lever and must be documentable per deployment.

4.2 **Typed holes are an injection surface, twice.** First at execution (shell escaping, already mandated in Wave 1B); second at witnessing: the trace records the INTERPOLATED command line, so a full-capture policy on shell.run retains whatever user data flowed through holes. Requirement: shell.run defaults to redacting hole-derived segments in trace payloads unless capture policy says full; the hash always covers the full line.

4.3 **The trace as attack target.** Hash chaining gives tamper EVIDENCE, not tamper PREVENTION; say so plainly in docs and never market it as immutability. Threat model v1: trusted host, untrusted readers; anything stronger (signed chains, remote anchoring) is deferred ledger material.

4.4 **Verbalized artifacts leak by readability.** `meridian explain` output and obligation artifacts embed canonical English of conditions, which can include literal values (channel names, thresholds, patterns). Fine by default; flag that obligation artifacts shipped outside the trust boundary may need the same redaction pass as payloads. One paragraph in docs, one deferred-ledger item (artifact redaction profiles).

4.5 **Judgment blocks and data egress.** A judgment block's tool scope is its egress surface; the `judged` event records input/output hashes, so full-capture deployments retain LLM inputs containing whatever the workflow bound. Capture policy applies to judgment events identically; the docs must state it, because "we log prompts" is a compliance question every enterprise will ask in week one.

---

# 5. VERSIONING AND EVOLUTION (new section)

5.1 **Skill identity vs history continuity.** Events carry skill identity + version hash; a one-line edit changes the hash. Do temporal claims see pre-edit events? If scoped to the exact hash: every edit amnesia-wipes flakiness history (wrong). If scoped to the name alone: a renamed step inherits an unrelated step's history (also wrong). Recommended amendment (clause 4.9): temporal scope binds to skill NAME plus stable STEP PATH; the version hash is recorded for audit but does not partition history; a step-path change is therefore a semantic event, which is exactly why 3.1 makes paths structure-derived and why `meridian drift` should warn when an edit changes any step path. Owed: register entry D10.

5.2 **Trace schema versioning.** Event records carry a schema version from day one; readers support N and N-1. Cheap now; a migration tool later is not.

5.3 **Obligation id stability.** Ids must survive unrelated edits (A.5 property) but change when the norm's meaning changes. Rule: id = hash of (scope, kind, condition IR canonical form); wording-only edits that produce identical IR keep the id; meaning edits change it, and the artifact diff makes that visible. Test both directions.

5.4 **Semantics document versioning discipline.** Already in clause 9.2; the habit that makes it real: every Cursor question answered in chat is answered by AMENDING THE DOCUMENT, then pointing Cursor at the clause. No oral law.

5.5 **Corpus version pinning.** External corpora (Wave 6) evolve upstream; pin exact versions in `corpora/README.md` so expressiveness metrics are comparable across waves.

---

# 6. PROGRAM-LEVEL RISKS

6.1 **Scope gravity.** Every wave makes the next shiny thing visible (module system, provers, OpenTelemetry, signed traces). Standing rule: new ideas enter the deferred ledger with one paragraph, never the current wave. The ledger IS the Wave 10+ backlog; that is a feature, not a parking lot of shame.

6.2 **The semantics doc going stale.** The moment code and document diverge, the oracle is dead. Mechanisms: SEM-tagged conformance tests, 9.2 versioning, and habit 5.4.

6.3 **Claim discipline.** Until the coherence harness is green on three corpora: "trace-grounded, formally projectable workflow language," never "formally verified." The expressiveness report's honesty sections exist to make overclaiming embarrassing internally first.

6.4 **Corpus overfit.** gbrain shaped Waves 1 to 4; the temporal/deontic layers were shaped by two invented examples. Risk: the language fits its own demos. Mitigation is already scheduled (Wave 6 foreign corpora) plus one addition: harvest temporal/deontic sentences from REAL ops runbooks and migration playbooks (you own several) into a sentence-level test corpus before Wave 8 grammar work begins.

6.5 **Single-maintainer bus factor on decisions.** The register concentrates judgment; correct for coherence, risky for momentum. Timebox each D-item to one sitting with the north star open; an imperfect confirmed decision beats a perfect pending one; 9.2 makes revision survivable.

6.6 **Agent-authored drift in long sessions.** Multi-hour Cursor sessions drift from constraints regardless of prompt quality. Mechanisms: one wave per session, exit checklists below, and the standing instruction that ambiguity goes to the log as a question, never into code as a guess.

6.7 **Benchmark rot.** Perf budgets (3.4) measured once are decoration. bench-parse and bench-trace run at every wave boundary and the numbers land in the log; a regression without an explanation blocks the wave exit.

---

# 7. WAVE-BOUNDARY CHECKLISTS (maintainer-run, fifteen minutes each)

**Before Wave 7 starts:**
- [x] Amendments 1.1 through 1.9 folded into `MERIDIAN_SEMANTICS.md` v0.2 with clause numbers and reserved SEM tags.
- [x] Decision Register: D0 to D4, D7, D7a, D8, D9, and D10 all CONFIRMED.
- [ ] North-star review protocol D.1 to D.4 executed; D.2 answers recorded; D.3 coverage gaps resolved.
- [ ] Cookbook examples read aloud; smells filed; gallery lines accepted as targets.
- [ ] Runbook/playbook sentence harvest (6.4) at least started.

**Wave 7 exit:**
- [ ] Round-trip law is IR equality; an authored-text comparison appears nowhere (2.10).
- [ ] Totality test fails on a deliberately added template-less node (actually try it).
- [ ] No placeholder templates (3.9 grep clean).
- [ ] `meridian drift` on three corpus skills: meaning-bearing residue empty; categories read sensibly.
- [ ] Ambiguity regression suite (2.11) exists and is wired to grammar-table changes.

**Wave 8 exit:**
- [ ] SEM-5-05 contrast tests exactly as north-star A.6, both orderings, interleavings, prevented-invoke case (3.2).
- [ ] MER-TMP-010 through 018 fire with message-snapshot tests; Broken Twin lines 1 to 5 reproduce exactly.
- [ ] Window-vs-retention error names both durations; keying errors (MER-TMP-016) fire; K3 nine-cell tests pass at language AND codegen levels (3.7).
- [ ] Broken Twin line 6's true-arm-only fixture fails compilation; line 7 exercises Wave 8 D7a totality at a blocking temporal obligation; possibly-indeterminate analysis matches amendment 1.2 exactly.
- [ ] Step-path unrelated-edit test green (3.1); crash-consistency loop test green (3.5); store differential test green (3.3).
- [ ] bench-trace numbers logged within budget (3.4); replay determinism grep clean (3.8).
- [ ] Capture policy (D9) implemented; production profile without per-tool policy fails compilation.

**Wave 9 exit:**
- [ ] Conflict lattice tests: same-scope, nested-scope, both declaration orders (2.4/2.5 analogues for norms).
- [ ] Prevented violations visible in traces; witness payloads per amendment 1.5.
- [ ] Obligation ids: byte-stable across clean builds; stable under unrelated edits; changed by meaning edits (5.3, both directions).
- [ ] Coherence harness disagreement message names obligation id and event ids; harness green in CI on all corpora.
- [ ] Broken Twin compiles to its exact error list as a snapshot test.
- [ ] Expressiveness report updated with 6.3's honest wording; claim audit done.

---

# 8. DEFERRED LEDGER (seeded; one paragraph each when promoted)

Module system / shared Domain imports (north-star D.2 Q5). Prover integration for obligations (Z3/Soufflé; ModelHike formal engine territory). Confidence intervals (SEM-6-04). Cross-skill trace scopes (D4). State-history past tense (snapshot retention design). Future-looking operators in proof mode. OpenTelemetry export adapter. SQLite store (gated by 3.4). Signed/anchored trace chains (4.3). Artifact redaction profiles (4.4). LLM canonicalize --propose authoring tool (non-compiler). Unknown-handling sugar (`treating unknown as ...`). Calendar-aware durations and timezones (1.6). `the last N` as take-suffix (2.6 exclusion). Gradable adjective machinery beyond `by <property>`.

# 9. OPEN QUESTIONS REGISTER (remaining additions owed to `MERIDIAN_SEMANTICS.md` section 10)

- D11 (new, from cookbook 13): is `unless` a separate canonical keyword or print-synonym of if-not? Cookbook currently says both stay canonical for their own keyword; confirm.
- D12 (new, from north-star D.2 Q3): violation witness payload contents under hash-only capture (key only? key + hash?). Recommended: key + hash.
