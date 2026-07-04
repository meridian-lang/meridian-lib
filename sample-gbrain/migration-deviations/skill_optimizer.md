# Deviation: skill_optimizer.meri

- Original: `skill-optimizer/SKILL.md`
- Ported: `skill_optimizer.meri`
- Tier: 1 (near-verbatim)
- Similarity: 87%
- Lines: 189 -> 203 (+32 / -18)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- shell-block-routed
- preamble-blockquoted
- inert-section-added

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L9 `When to invoke this skill`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L35 `The pipeline`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L137 `Output Format`: template - Template/output shape is metadata unless explicit output assertions are authored.

## Metrics
- Sections inert total: 3/8 (38% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert categories: reference-documentation=2, template=1
- Judgment: 4 blocks, 0 lines

### Inert section details
- L9 `When to invoke this skill`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L35 `The pipeline`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L137 `Output Format`: template — Template/output shape is metadata unless explicit output assertions are authored.

## Unified diff

```diff
--- original-skills/skill-optimizer/SKILL.md
+++ skills/skill_optimizer.meri
@@ -14,12 +14,12 @@
 
 # Skill Optimizer
 
-Self-evolving skill optimization. Treats SKILL.md as the trainable parameters
-of a frozen agent. Validation-gated, budget-capped, atomic-versioned.
-
-Based on SkillOpt (arXiv 2605.23904, Microsoft Research, May 2026).
-
-## When to invoke this skill
+> Self-evolving skill optimization. Treats SKILL.md as the trainable parameters
+> of a frozen agent. Validation-gated, budget-capped, atomic-versioned.
+
+> Based on SkillOpt (arXiv 2605.23904, Microsoft Research, May 2026).
+
+## When to invoke this skill (( inert ))
 
 The user wants to:
 - Improve an existing skill's execution quality against a benchmark
@@ -27,6 +27,7 @@
 - Re-tune a skill after switching target models
 
 ## Iron Law
+use judgment to follow the Iron Law guidance:
 
 - **Validation gating is MANDATORY.** Every candidate must clear median-of-3
   + epsilon=0.05 margin against the sel-set before SKILL.md gets rewritten.
@@ -44,7 +45,7 @@
   the generated judges, delete the sentinel, and re-run with
   `--bootstrap-reviewed` before optimization can use the file.
 
-## The pipeline
+## The pipeline (( inert ))
 
 ```
 gbrain skillopt <skill-name> [flags]
@@ -72,11 +73,7 @@
 ```
 
 ## Starting a benchmark from the skill itself (the common case)
-
-**The user will NOT hand-write a benchmark, and you shouldn't start from a blank
-file either.** When the user says "make skill X better" and
-`skills/X/skillopt-benchmark.jsonl` doesn't exist, generate a starter from the
-SKILL.md directly:
+use judgment to follow the Starting a benchmark from the skill itself (the common case) guidance:
 
 1. **Generate the starter.** Run:
    ```
@@ -94,8 +91,6 @@
    real length ceilings, `min_citations` where sources are expected,
    `tool_called`/`tool_not_called` for tools the skill genuinely uses). A thin
    benchmark optimizes for a thin definition of quality — do not rubber-stamp.
-3. **Delete the sentinel line** (`# BOOTSTRAP_PENDING_REVIEW`, the last line).
-4. **Run the optimizer with `--split 1:1:1`:**
    ```
    gbrain skillopt X --bootstrap-reviewed --split 1:1:1
    ```
@@ -122,8 +117,25 @@
 `--split 1:1:1`. The human walkthrough lives at
 `docs/tutorials/improving-skills-with-skillopt.md`.
 
-## Decision tree
-
+
+### Starting a benchmark from the skill itself (the common case) — steps
+
+The user will NOT hand-write a benchmark, and you shouldn't start from a blank
+file either. When the user says "make skill X better" and
+`skills/X/skillopt-benchmark.jsonl` doesn't exist, generate a starter from the
+SKILL.md directly:
+
+
+### Starting a benchmark from the skill itself (the common case) — steps 2
+
+3. Delete the sentinel line (`# BOOTSTRAP_PENDING_REVIEW`, the last line).
+4. Run the optimizer with `--split 1:1:1`:
+## Decision tree (( inert ))
+
+
+### Decision tree — steps
+
+!!! table (( ai-discretion ))
 | Situation | Action |
 |---|---|
 | Skill has no benchmark | `gbrain skillopt foo --bootstrap-from-skill` → review + strengthen the judges → delete sentinel → `gbrain skillopt foo --bootstrap-reviewed --split 1:1:1` (see section above) |
@@ -146,7 +158,8 @@
 - `skills/<name>/skillopt/rejected.json` — bounded LRU of rejected edits
 - `~/.gbrain/audit/skillopt-YYYY-Www.jsonl` — ISO-week-rotated audit trail
 
-## Anti-Patterns
+## Anti-Patterns (( role: procedure ))
+use judgment to follow the Anti-Patterns guidance:
 
 - **Don't bypass the validation gate.** The median-of-3 + epsilon=0.05 is
   load-bearing; without it, the optimizer accepts noise as improvement.
@@ -164,7 +177,8 @@
   split drops the validation set below the `D_sel >= 5` floor and the run
   aborts with `d_sel_too_small`.
 
-## Contract
+## Contract (( role: procedure ))
+use judgment to follow the Contract guidance:
 
 `runSkillOpt(opts)` returns:
 ```
```
