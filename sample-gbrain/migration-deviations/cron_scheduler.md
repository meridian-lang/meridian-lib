# Deviation: cron_scheduler.meri

- Original: `cron-scheduler/SKILL.md`
- Ported: `cron_scheduler.meri`
- Tier: 1 (near-verbatim)
- Similarity: 94%
- Lines: 94 -> 98 (+8 / -4)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- shell-block-routed
- inert-section-added

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L38 `Output Format`: template - Template/output shape is metadata unless explicit output assertions are authored.
- L42 `Multi-source brains: use `sync --all`, not per-source entries`: reference-documentation - Reference documentation, rationale, examples, or changelog.

## Metrics
- Sections inert total: 2/6 (33% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert categories: reference-documentation=1, template=1
- Judgment: 4 blocks, 0 lines

### Inert section details
- L38 `Output Format`: template — Template/output shape is metadata unless explicit output assertions are authored.
- L42 `Multi-source brains: use `sync --all`, not per-source entries`: reference-documentation — Reference documentation, rationale, examples, or changelog.

## Unified diff

```diff
--- original-skills/cron-scheduler/SKILL.md
+++ skills/cron_scheduler.meri
@@ -20,7 +20,8 @@
 
 > **Convention:** See `skills/conventions/test-before-bulk.md` — test every cron job on 3-5 items first.
 
-## Contract
+## Contract (( role: procedure ))
+use judgment to follow the Contract guidance:
 
 This skill guarantees:
 - Schedule staggering: max 1 job per 5-minute slot, no collisions
@@ -30,6 +31,7 @@
 - Results saved as reports: `reports/{job-name}/{YYYY-MM-DD-HHMM}.md`
 
 ## Phases
+use judgment to follow the Phases guidance:
 
 1. **Define job.** Name, schedule (cron expression), skill to run, timeout.
 2. **Validate schedule.** Check no collision with existing jobs (5-minute offset rule).
@@ -43,17 +45,18 @@
 5. **Write thin prompt.** Job prompt is one line: "Read skills/{name}/SKILL.md and run it."
 
 ## Idempotency Requirement
+use judgment to follow the Idempotency Requirement guidance:
 
 Every cron job MUST be idempotent:
 - Running the same job twice produces the same result (no duplicate pages, no duplicate timeline entries)
 - Use checkpoint state files to track progress and resume interrupted runs
 - Check for existing output before creating new output
 
-## Output Format
+## Output Format (( inert, role: template ))
 
 Job configuration saved. Report: "Job '{name}' scheduled at {cron expression}. Next run: {time}."
 
-## Multi-source brains: use `sync --all`, not per-source entries
+## Multi-source brains: use `sync --all`, not per-source entries (( inert ))
 
 When the brain has 2+ active sources (anything `gbrain sources list` shows
 with a non-null `local_path` that isn't archived), use one consolidated
@@ -81,7 +84,8 @@
 `gbrain doctor` surfaces the recommended line as a `sync_consolidation`
 check whenever it detects 2+ active sources. Paste-ready from there.
 
-## Anti-Patterns
+## Anti-Patterns (( role: procedure ))
+use judgment to follow the Anti-Patterns guidance:
 
 - Scheduling jobs at the same minute (:00 for everything)
 - Inline 3000-word prompts in cron jobs (use skill file references)
```
