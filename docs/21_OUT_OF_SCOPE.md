# Out of scope for Meridian Final Wave

This document is the permanent boundary for capabilities Meridian deliberately does
not implement. Everything **not** listed here that appeared in the v0.2 deferred
ledger (`MERIDIAN_SEMANTICS.md` §9.3, `MERIDIAN_DESIGN_RISKS_AND_REVIEW.md` §8) is
**Final Wave in-scope** — implemented (see `status.md` and
`IMPLEMENTATION_LOG.md`).

The kernel semantics oracle remains [`docs/cookbook/MERIDIAN_SEMANTICS.md`](cookbook/MERIDIAN_SEMANTICS.md).

---

## 1. Formal prover discharge / machine-checked coherence theorem

Meridian defines a verification projection (`⟦·⟧_proof`) and emits **prover-ready**
obligation artifacts (SEM-8-02). The coherence requirement (SEM-8-01) is
established in this repository by **differential testing**: replay instrumented
traces through an independent obligation evaluator and assert agreement with
runtime `violated` / `assert-failed` events.

**Out of scope:** integrating Z3, Soufflé, Datalog, or any external proof engine;
discharging obligations automatically; proving a machine-checked theorem that
`⟦·⟧_exec` and `⟦·⟧_proof` agree for all traces. That work belongs to the
ModelHike formal-engine program, not `meridian-lib`.

**In scope (not out of scope):** structured obligation JSON, stable obligation ids,
canonical IR + English in artifacts, witness hashes, capture-policy metadata, and
CI harnesses that validate artifacts against traces.

---

## 2. Localization / alternate canonical natural languages

Meridian's verbalization law (SEM-8-03) defines a single **canonical English**
surface per IR construct. Synonyms may parse; exactly one English form prints per
construct for the deterministic kernel.

**Out of scope:** alternate canonical natural languages (French, Japanese, …),
locale-aware canonicalization tables, translated problem messages as a parallel
oracle, and runtime selection of non-English canonical forms.

**In scope (not out of scope):** English synonym parsing, authored-form metadata
(e.g. D11 `unless` vs `if not`), deployment timezone for calendar amounts, and
formatting of dates/times in the configured zone.

---

## Explicitly in scope (formerly deferred)

The following are **not** out of scope; they moved into Final Wave when v0.3
semantics closed the deferred list:

- Wilson confidence intervals (SEM-6-04)
- State-history retention for keyed kinds (SEM-4-12, SEM-5-13)
- Bounded future monitors in Contract/obligation contexts (SEM-5-12)
- Calendar amounts distinct from physical duration (SEM-2-13)
- Clock skew / hybrid ingest ordering (SEM-4-11)
- Cross-skill trace scopes via declared lists (SEM-4-10, D4a)
- Formalized commit/recover meaning (SEM-3-01)
- Module/shared imports (SEM-MOD-01, SEM-MOD-02; see `docs/22_MODULES_AND_IMPORTS.md`)
- Deontic layer, violation witnesses (SEM-7-01–05), coherence harness (SEM-8-01)
- SQLite / networked trace stores, OTLP export, signed trace chains
- LLM provider surfaces, MCP integration, CI conformance gates
- Zero-deferral audit against this document and the requirements matrix
