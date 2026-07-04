# Deviation: cron_scheduler.meri

- Original: `cron-scheduler/SKILL.md`
- Ported: `cron_scheduler.meri`
- Tier: 1 (near-verbatim)
- Similarity: 94%
- Lines: 94 -> 94 (+6 / -6)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- inert-section-added

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L6 `Contract`: normative-contract - Normative invariants prose needs mining into assertions or explicit AI routing.
- L15 `Phases`: operational-procedure - Marked or derived as procedure, but inert suppresses execution.
- L28 `Idempotency Requirement`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L35 `Output Format`: template - Template/output shape is metadata unless explicit output assertions are authored.
- L39 `Multi-source brains: use `sync --all`, not per-source entries`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L67 `Anti-Patterns`: reference-documentation - Reference documentation, rationale, examples, or changelog.

## Metrics
- Sections: 6/6 inert (100% inert ratio)
- Operational inert: 2
- Unclassified inert: 0
- Inert categories: normative-contract=1, operational-procedure=1, reference-documentation=3, template=1
- Judgment: 0 blocks, 0 lines

### Inert section details
- L6 `Contract`: normative-contract — Normative invariants prose needs mining into assertions or explicit AI routing.
- L15 `Phases`: operational-procedure — Marked or derived as procedure, but inert suppresses execution.
- L28 `Idempotency Requirement`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L35 `Output Format`: template — Template/output shape is metadata unless explicit output assertions are authored.
- L39 `Multi-source brains: use `sync --all`, not per-source entries`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L67 `Anti-Patterns`: reference-documentation — Reference documentation, rationale, examples, or changelog.

## Unified diff

```diff
--- original-skills/cron-scheduler/SKILL.md
+++ skills/cron_scheduler.meri
@@ -20,7 +20,7 @@
 
 > **Convention:** See `skills/conventions/test-before-bulk.md` — test every cron job on 3-5 items first.
 
-## Contract
+## Contract (( inert, role: invariants ))
 
 This skill guarantees:
 - Schedule staggering: max 1 job per 5-minute slot, no collisions
@@ -29,7 +29,7 @@
 - Idempotency: jobs can run twice without duplicate side effects
 - Results saved as reports: `reports/{job-name}/{YYYY-MM-DD-HHMM}.md`
 
-## Phases
+## Phases (( inert, role: procedure ))
 
 1. **Define job.** Name, schedule (cron expression), skill to run, timeout.
 2. **Validate schedule.** Check no collision with existing jobs (5-minute offset rule).
@@ -42,18 +42,18 @@
 4. **Register with host scheduler.** OpenClaw cron, Railway cron, crontab, or process manager. **Each registered entry should execute via Minions, not `agentTurn`.** See `skills/conventions/cron-via-minions.md` for the rewrite pattern (PGLite uses `--follow`, Postgres uses fire-and-forget + `--idempotency-key` on the cycle slot). GBrain's v0.11.0 migration auto-rewrites entries for built-in handlers; host-specific handlers need a code-level registration per `docs/guides/plugin-handlers.md`.
 5. **Write thin prompt.** Job prompt is one line: "Read skills/{name}/SKILL.md and run it."
 
-## Idempotency Requirement
+## Idempotency Requirement (( inert ))
 
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
@@ -81,7 +81,7 @@
 `gbrain doctor` surfaces the recommended line as a `sync_consolidation`
 check whenever it detects 2+ active sources. Paste-ready from there.
 
-## Anti-Patterns
+## Anti-Patterns (( inert, role: prohibitions ))
 
 - Scheduling jobs at the same minute (:00 for everything)
 - Inline 3000-word prompts in cron jobs (use skill file references)
```
