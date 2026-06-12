# Deviation: skill_optimizer.meri

- Original: `skill-optimizer/SKILL.md`
- Ported: `skill_optimizer.meri`
- Tier: 1 (near-verbatim)
- Similarity: 94%
- Lines: 189 -> 189 (+11 / -11)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- preamble-blockquoted

## Unified diff

```diff
--- original-skills/skill-optimizer/SKILL.md
+++ skills/skill_optimizer.meri
@@ -14,19 +14,19 @@
 
 # Skill Optimizer
 
-Self-evolving skill optimization. Treats SKILL.md as the trainable parameters
-of a frozen agent. Validation-gated, budget-capped, atomic-versioned.
+> Self-evolving skill optimization. Treats SKILL.md as the trainable parameters
+> of a frozen agent. Validation-gated, budget-capped, atomic-versioned.
 
-Based on SkillOpt (arXiv 2605.23904, Microsoft Research, May 2026).
+> Based on SkillOpt (arXiv 2605.23904, Microsoft Research, May 2026).
 
-## When to invoke this skill
+## When to invoke this skill (( inert ))
 
 The user wants to:
 - Improve an existing skill's execution quality against a benchmark
 - Bootstrap a benchmark file for a new skill
 - Re-tune a skill after switching target models
 
-## Iron Law
+## Iron Law (( inert ))
 
 - **Validation gating is MANDATORY.** Every candidate must clear median-of-3
   + epsilon=0.05 margin against the sel-set before SKILL.md gets rewritten.
@@ -44,7 +44,7 @@
   the generated judges, delete the sentinel, and re-run with
   `--bootstrap-reviewed` before optimization can use the file.
 
-## The pipeline
+## The pipeline (( inert ))
 
 ```
 gbrain skillopt <skill-name> [flags]
@@ -71,7 +71,7 @@
   └── Final test eval on D_test → run receipt
 ```
 
-## Starting a benchmark from the skill itself (the common case)
+## Starting a benchmark from the skill itself (the common case) (( inert ))
 
 **The user will NOT hand-write a benchmark, and you shouldn't start from a blank
 file either.** When the user says "make skill X better" and
@@ -122,7 +122,7 @@
 `--split 1:1:1`. The human walkthrough lives at
 `docs/tutorials/improving-skills-with-skillopt.md`.
 
-## Decision tree
+## Decision tree (( inert ))
 
 | Situation | Action |
 |---|---|
@@ -146,7 +146,7 @@
 - `skills/<name>/skillopt/rejected.json` — bounded LRU of rejected edits
 - `~/.gbrain/audit/skillopt-YYYY-Www.jsonl` — ISO-week-rotated audit trail
 
-## Anti-Patterns
+## Anti-Patterns (( inert, role: prohibitions ))
 
 - **Don't bypass the validation gate.** The median-of-3 + epsilon=0.05 is
   load-bearing; without it, the optimizer accepts noise as improvement.
@@ -164,7 +164,7 @@
   split drops the validation set below the `D_sel >= 5` floor and the run
   aborts with `d_sel_too_small`.
 
-## Contract
+## Contract (( inert, role: invariants ))
 
 `runSkillOpt(opts)` returns:
 ```
@@ -181,7 +181,7 @@
 }
 ```
 
-## Related skills
+## Related skills (( inert ))
 
 - `skillify` — scaffolds a new skill (use BEFORE skillopt)
 - `skillpack-check` — audits skill conformance (item 13 surfaces skillopt status)
```
