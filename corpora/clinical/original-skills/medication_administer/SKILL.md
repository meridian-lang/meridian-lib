---
name: medication administer
description: Check a medication order for allergy conflicts and administration risk before a nurse gives the dose, routing anything high-risk through an attending's sign-off instead of letting a busy shift skip the check. Use this whenever a medication order reaches the point of actually being given to a patient.
triggers:
  - "administer medication"
  - "give medication order"
parameters: medication order, patient, nurse
---

# Medication Administer

A wrong medication reaching a patient is rarely a single mistake — it is
usually a chain of small skips: the allergy list wasn't re-checked, the
order's risk tier wasn't looked at, or a high-risk order went in without a
second set of eyes. This skill is that second set of eyes. It checks the
order against the patient's allergy history before anything is given,
and it holds any high-risk order for an attending's approval rather than
trusting a single nurse's judgment call under time pressure.

## Contract
- Input: a patient, the medication order to give, and the nurse giving it.
- Output: either a completed administration or a held order pending
  attending approval.
- Side effect: every administration attempt is logged, whether it succeeds,
  is blocked by an allergy conflict, or waits on approval.

## When to invoke
- "administer medication"
- "give medication order"

## Rules
A medication order with allergy check "conflict" must not be administered.
A high risk medication order must be approved by an attending before administration.

## Workflow
check the allergy history for the medication order.
if the medication order is cleared,
  administer the medication order.
  recover from medication.administer.failed:
    Note: "administration failed at the device, hold the dose and notify the attending",
otherwise,
  Note: "allergy conflict found, dose withheld".
log an audit entry for the medication order.
Emit: "medication administer pass complete".

## Anti-Patterns
- Don't override an allergy conflict because the reaction "was mild last
  time" — a documented allergy stays a hard stop regardless of how the last
  exposure went.
- Don't administer a high-risk order first and page the attending after;
  the approval gate exists precisely so the sign-off happens before the
  dose, not as paperwork afterward.

## When NOT to use this skill
Use `dose check` instead for a pure shift-total question: how many doses has
a nurse already given today. That question is about a running count, never
about whether this particular order is safe to give. Use `consent capture`
first if the medication order requires patient consent that hasn't been
recorded yet.

## Report shape
The receipt records whether the dose was given, blocked by an allergy
conflict, or parked for attending approval, plus the audit entry reference
for the attempt.
