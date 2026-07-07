# Deviation: skill_optimizer.meri

- Original: `skill-optimizer/SKILL.md`
- Ported: `skill_optimizer.meri`
- Tier: 2 (light edits)
- Similarity: 67%
- Lines: 189 -> 223 (+85 / -51)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- preamble-blockquoted
- doc-section-marked

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L9 `When to invoke this skill`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L44 `The pipeline`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L156 `Output Format`: template - Template/output shape is metadata unless explicit output assertions are authored.
- L188 `Contract`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.

## Metrics
- Sections inert total: 7/8 (88% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert markers (`(( inert ))`, target 0 — the migrator never emits these): 0
- Inert categories: reference-documentation=6, template=1
- Judgment: 4 blocks, 5 lines

### Inert section details
- L9 `When to invoke this skill`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L16 `Iron Law`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L44 `The pipeline`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L71 `Starting a benchmark from the skill itself (the common case)`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L156 `Output Format`: template — Template/output shape is metadata unless explicit output assertions are authored.
- L167 `Anti-Patterns`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L188 `Contract`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.

## Unified diff

```diff
--- original-skills/skill-optimizer/SKILL.md
+++ skills/skill_optimizer.meri
@@ -14,37 +14,47 @@
 
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
+## When to invoke this skill (( role: reference ))
 
 The user wants to:
 - Improve an existing skill's execution quality against a benchmark
 - Bootstrap a benchmark file for a new skill
 - Re-tune a skill after switching target models
 
-## Iron Law
-
-- **Validation gating is MANDATORY.** Every candidate must clear median-of-3
-  + epsilon=0.05 margin against the sel-set before SKILL.md gets rewritten.
+## Iron Law (( role: reference ))
+
 - **Frontmatter mutation is FORBIDDEN.** The optimizer only edits the body.
   Routing surface (`triggers:`, `brain_first:`) stays invariant.
-- **Bundled skills require explicit opt-in AND an independent held-out set.**
+
+### Iron Law — steps (( role: reference ))
+
+- Every candidate must clear median-of-3
+  + epsilon=0.05 margin against the sel-set before SKILL.md gets rewritten.
+
+### Iron Law — steps 2 (( role: reference ))
+
+- Bundled skills require explicit opt-in AND an independent held-out set.
   Skills shipping with gbrain cannot be auto-mutated. To rewrite one in place
   the user passes BOTH `--allow-mutate-bundled` AND `--held-out <path>` with
   at least 5 benchmark-disjoint tasks; without the held-out set the run
   hard-refuses (exit 2). Drop `--allow-mutate-bundled` (or pass `--no-mutate`,
   the default for the dream-cycle phase) to write proposed.md for review
   instead — no held-out needed for review-only output.
+
+### Iron Law — steps 3
+
+use judgment to follow the Iron Law — steps 3 guidance:
 - **Bootstrap output requires human review.** Both `--bootstrap-from-skill`
   and `--bootstrap-from-routing` write a sentinel; you must review + STRENGTHEN
   the generated judges, delete the sentinel, and re-run with
   `--bootstrap-reviewed` before optimization can use the file.
 
-## The pipeline
+## The pipeline (( role: reference ))
 
 ```
 gbrain skillopt <skill-name> [flags]
@@ -71,59 +81,80 @@
   └── Final test eval on D_test → run receipt
 ```
 
-## Starting a benchmark from the skill itself (the common case)
-
-**The user will NOT hand-write a benchmark, and you shouldn't start from a blank
-file either.** When the user says "make skill X better" and
+## Starting a benchmark from the skill itself (the common case) (( role: reference ))
+
+1. **Generate the starter.** Run:
+   ```
+   gbrain skillopt X --bootstrap-from-skill
+   ```
+2. **Review AND STRENGTHEN the judges.** This is YOUR job and it is load-bearing.
+   ```
+   gbrain skillopt X --bootstrap-reviewed --split 1:1:1
+   ```
+Benchmark line shape (what the generator writes, one per line):
+```
+{"task_id":"x-001","task":"<user prompt>","judge":{"kind":"rule","checks":[{"op":"max_chars","arg":1800},{"op":"contains","arg":"agenda"}]}}
+```
+
+Rule-check vocabulary you'll strengthen with: `contains`, `regex`,
+`section_present`, `max_chars`, `min_citations`, `tool_called`, `tool_not_called`.
+**Fallback — author freehand.** If the generated starter is poor (rare, but
+possible for very behavior-shaped skills), discard it and write the JSONL
+yourself: read the SKILL.md, write ~15 realistic tasks covering the boring middle,
+attach >=2 rule checks each, save to `skills/X/skillopt-benchmark.jsonl`, run with
+`--split 1:1:1`. The human walkthrough lives at
+`docs/tutorials/improving-skills-with-skillopt.md`.
+
+
+### Starting a benchmark from the skill itself (the common case) — steps
+
+The user will NOT hand-write a benchmark, and you shouldn't start from a blank
+file either. When the user says "make skill X better" and
 `skills/X/skillopt-benchmark.jsonl` doesn't exist, generate a starter from the
 SKILL.md directly:
 
-1. **Generate the starter.** Run:
-   ```
-   gbrain skillopt X --bootstrap-from-skill
-   ```
+
+### Starting a benchmark from the skill itself (the common case) — steps 2
+
+use judgment to follow the Starting a benchmark from the skill itself (the common case) — steps 2 guidance:
    One LLM call reads `skills/X/SKILL.md`, infers what the skill produces and what
    "good" looks like, and writes ~15 tasks (each with rule judges) to
    `skills/X/skillopt-benchmark.jsonl` plus a `# BOOTSTRAP_PENDING_REVIEW`
    sentinel. No `routing-eval.jsonl` is needed. Tune the count with
    `--bootstrap-tasks N` (max 50).
-2. **Review AND STRENGTHEN the judges.** This is YOUR job and it is load-bearing.
+
+### Starting a benchmark from the skill itself (the common case) — steps 3
+
    The generated rule checks are weak drafts — the model tends to emit generic
    `contains`, loose `max_chars`, or invented headings. Read each task, fix soft
    checks, add the must-haves the skill actually requires (real section names,
    real length ceilings, `min_citations` where sources are expected,
    `tool_called`/`tool_not_called` for tools the skill genuinely uses). A thin
    benchmark optimizes for a thin definition of quality — do not rubber-stamp.
-3. **Delete the sentinel line** (`# BOOTSTRAP_PENDING_REVIEW`, the last line).
-4. **Run the optimizer with `--split 1:1:1`:**
-   ```
-   gbrain skillopt X --bootstrap-reviewed --split 1:1:1
-   ```
+3. Delete the sentinel line (`# BOOTSTRAP_PENDING_REVIEW`, the last line).
+4. Run the optimizer with `--split 1:1:1`:
+
+### Starting a benchmark from the skill itself (the common case) — steps 4
+
    The 1:1:1 split is REQUIRED for a 15-task starter — the default `4:1:5` makes
    the validation set `floor(15/10)=1`, below the `D_sel >= 5` floor, and the
    optimizer refuses with `d_sel_too_small`. (4:1:5 needs ~50 tasks.) Add
    `--dry-run` first to preview cost.
 
-Benchmark line shape (what the generator writes, one per line):
-```
-{"task_id":"x-001","task":"<user prompt>","judge":{"kind":"rule","checks":[{"op":"max_chars","arg":1800},{"op":"contains","arg":"agenda"}]}}
-```
-
-Rule-check vocabulary you'll strengthen with: `contains`, `regex`,
-`section_present`, `max_chars`, `min_citations`, `tool_called`, `tool_not_called`.
+
+### Starting a benchmark from the skill itself (the common case) — steps 5
+
+use judgment to follow the Starting a benchmark from the skill itself (the common case) — steps 5 guidance:
 Rule judges are deterministic and free, but shallow for skills whose quality is
 sequencing, privacy, refusal boundaries, or file placement — for those, hand-add
 richer checks (or an `llm` judge) during review.
 
-**Fallback — author freehand.** If the generated starter is poor (rare, but
-possible for very behavior-shaped skills), discard it and write the JSONL
-yourself: read the SKILL.md, write ~15 realistic tasks covering the boring middle,
-attach >=2 rule checks each, save to `skills/X/skillopt-benchmark.jsonl`, run with
-`--split 1:1:1`. The human walkthrough lives at
-`docs/tutorials/improving-skills-with-skillopt.md`.
-
 ## Decision tree
 
+
+### Decision tree — steps
+
+!!! table (( ai-discretion ))
 | Situation | Action |
 |---|---|
 | Skill has no benchmark | `gbrain skillopt foo --bootstrap-from-skill` → review + strengthen the judges → delete sentinel → `gbrain skillopt foo --bootstrap-reviewed --split 1:1:1` (see section above) |
@@ -146,25 +177,28 @@
 - `skills/<name>/skillopt/rejected.json` — bounded LRU of rejected edits
 - `~/.gbrain/audit/skillopt-YYYY-Www.jsonl` — ISO-week-rotated audit trail
 
-## Anti-Patterns
+## Anti-Patterns (( role: reference ))
 
 - **Don't bypass the validation gate.** The median-of-3 + epsilon=0.05 is
   load-bearing; without it, the optimizer accepts noise as improvement.
-- **Don't optimize bundled skills without `--allow-mutate-bundled` AND
-  `--held-out`.** They ship with gbrain and are load-bearing for downstream
-  agents. In-place mutation requires both flags (held-out >=5 benchmark-disjoint
-  tasks); without the held-out set the run hard-refuses and points you at
-  proposed.md.
+- **Don't skip `--split 1:1:1` on a ~15-task starter.** The default `4:1:5`
+  split drops the validation set below the `D_sel >= 5` floor and the run
+  aborts with `d_sel_too_small`.
+
+
+### Anti-Patterns — steps (( role: reference ))
+
+- They ship with gbrain and are load-bearing for downstream agents. In-place mutation requires both flags (held-out >=5 benchmark-disjoint tasks); without the held-out set the run hard-refuses and points you at proposed.md.
+
+### Anti-Patterns — steps 2 (( role: reference ))
+
+use judgment to follow the Anti-Patterns — steps 2 guidance:
 - **Don't use bootstrap output without strengthening it.** Both
   `--bootstrap-from-skill` and `--bootstrap-from-routing` have the optimizer
   model invent success criteria — generic and weak by default. Review and
   tighten the judges before SkillOpt optimizes against them, or it trains the
   skill toward benchmark artifacts instead of real quality.
-- **Don't skip `--split 1:1:1` on a ~15-task starter.** The default `4:1:5`
-  split drops the validation set below the `D_sel >= 5` floor and the run
-  aborts with `d_sel_too_small`.
-
-## Contract
+## Contract (( role: reference ))
 
 `runSkillOpt(opts)` returns:
 ```
```
