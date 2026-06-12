# Deviation: cron_scheduler.meri

- Original: `cron-scheduler/SKILL.md`
- Ported: `cron_scheduler.meri`
- Tier: 1 (near-verbatim)
- Similarity: 87%
- Lines: 94 -> 90 (+10 / -14)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added

## Metrics
- Sections: 5/6 inert (83% inert ratio)
- Judgment: 1 blocks, 5 lines

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
@@ -31,18 +31,14 @@
 
 ## Phases
 
-1. **Define job.** Name, schedule (cron expression), skill to run, timeout.
-2. **Validate schedule.** Check no collision with existing jobs (5-minute offset rule).
-   - Slots: :05, :10, :15, :20, :25, :30, :35, :40, :45, :50
-   - If collision detected, suggest the next available slot
-3. **Check quiet hours.** Default: 11 PM - 8 AM local time.
-   - Override: user-awake flag (if user is active, quiet hours suspended)
-   - During quiet hours: save output to held queue
-   - Morning contact releases the backlog
-4. **Register with host scheduler.** OpenClaw cron, Railway cron, crontab, or process manager. **Each registered entry should execute via Minions, not `agentTurn`.** See `skills/conventions/cron-via-minions.md` for the rewrite pattern (PGLite uses `--follow`, Postgres uses fire-and-forget + `--idempotency-key` on the cycle slot). GBrain's v0.11.0 migration auto-rewrites entries for built-in handlers; host-specific handlers need a code-level registration per `docs/guides/plugin-handlers.md`.
-5. **Write thin prompt.** Job prompt is one line: "Read skills/{name}/SKILL.md and run it."
+use judgment to schedule a cron job:
+  Define the job name, cron schedule, skill to run, and timeout.
+  Validate the schedule against existing jobs using the five-minute offset rule and suggest the next free slot on collision.
+  Check quiet hours (default 11 PM to 8 AM) and hold output during quiet hours.
+  Register the entry with the host scheduler, executing via Minions rather than a direct agent turn.
+  Write a thin one-line job prompt that reads and runs the target skill.
 
-## Idempotency Requirement
+## Idempotency Requirement (( inert ))
 
 Every cron job MUST be idempotent:
 - Running the same job twice produces the same result (no duplicate pages, no duplicate timeline entries)
@@ -53,7 +49,7 @@
 
 Job configuration saved. Report: "Job '{name}' scheduled at {cron expression}. Next run: {time}."
 
-## Multi-source brains: use `sync --all`, not per-source entries
+## Multi-source brains: use `sync --all`, not per-source entries (( inert ))
 
 When the brain has 2+ active sources (anything `gbrain sources list` shows
 with a non-null `local_path` that isn't archived), use one consolidated
@@ -81,7 +77,7 @@
 `gbrain doctor` surfaces the recommended line as a `sync_consolidation`
 check whenever it detects 2+ active sources. Paste-ready from there.
 
-## Anti-Patterns
+## Anti-Patterns (( inert, role: prohibitions ))
 
 - Scheduling jobs at the same minute (:00 for everything)
 - Inline 3000-word prompts in cron jobs (use skill file references)
```
