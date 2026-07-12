# Deviation: cron_scheduler.meri

- Original: `cron-scheduler/SKILL.md`
- Ported: `cron_scheduler.meri`
- Tier: 2 (light edits)
- Similarity: 75%
- Lines: 94 -> 103 (+29 / -20)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- doc-section-marked

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L6 `Contract`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L15 `Phases`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L38 `Output Format`: template - Template/output shape is metadata unless explicit output assertions are authored.
- L76 `Anti-Patterns`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.

## Metrics
- generated_loc: 60 non-blank ported lines
- Sections inert total: 6/6 (100% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert markers (`(( inert ))`, target 0 — the migrator never emits these): 0
- Inert categories: reference-documentation=5, template=1
- Judgment: 0 blocks, 0 lines
- canonical_drift: synonym=0, structure=0, desugar=0, meaning=63

### Inert section details
- L6 `Contract`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L15 `Phases`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L28 `Idempotency Requirement`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L38 `Output Format`: template — Template/output shape is metadata unless explicit output assertions are authored.
- L42 `Multi-source brains: use `sync --all`, not per-source entries`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L76 `Anti-Patterns`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.

## Unified diff

```diff
--- original-skills/cron-scheduler/SKILL.md
+++ skills/cron_scheduler.meri
@@ -20,7 +20,7 @@
 
 > **Convention:** See `skills/conventions/test-before-bulk.md` — test every cron job on 3-5 items first.
 
-## Contract
+## Contract (( role: reference ))
 
 This skill guarantees:
 - Schedule staggering: max 1 job per 5-minute slot, no collisions
@@ -29,35 +29,34 @@
 - Idempotency: jobs can run twice without duplicate side effects
 - Results saved as reports: `reports/{job-name}/{YYYY-MM-DD-HHMM}.md`
 
-## Phases
+## Phases (( role: reference ))
 
-1. **Define job.** Name, schedule (cron expression), skill to run, timeout.
-2. **Validate schedule.** Check no collision with existing jobs (5-minute offset rule).
+1. Name, schedule (cron expression), skill to run, timeout.
+2. Check no collision with existing jobs (5-minute offset rule).
    - Slots: :05, :10, :15, :20, :25, :30, :35, :40, :45, :50
    - If collision detected, suggest the next available slot
-3. **Check quiet hours.** Default: 11 PM - 8 AM local time.
+3. Default: 11 PM - 8 AM local time.
    - Override: user-awake flag (if user is active, quiet hours suspended)
    - During quiet hours: save output to held queue
    - Morning contact releases the backlog
-4. **Register with host scheduler.** OpenClaw cron, Railway cron, crontab, or process manager. **Each registered entry should execute via Minions, not `agentTurn`.** See `skills/conventions/cron-via-minions.md` for the rewrite pattern (PGLite uses `--follow`, Postgres uses fire-and-forget + `--idempotency-key` on the cycle slot). GBrain's v0.11.0 migration auto-rewrites entries for built-in handlers; host-specific handlers need a code-level registration per `docs/guides/plugin-handlers.md`.
-5. **Write thin prompt.** Job prompt is one line: "Read skills/{name}/SKILL.md and run it."
+4. Register with host scheduler. OpenClaw cron, Railway cron, crontab, or process manager. Each registered entry should execute via Minions, not `agentTurn`. See `skills/conventions/cron-via-minions.md` for the rewrite pattern (PGLite uses `--follow`, Postgres uses fire-and-forget + `--idempotency-key` on the cycle slot). GBrain's v0.11.0 migration auto-rewrites entries for built-in handlers; host-specific handlers need a code-level registration per `docs/guides/plugin-handlers.md`.
+5. Job prompt is one line: "Read skills/{name}/SKILL.md and run it."
 
-## Idempotency Requirement
+## Idempotency Requirement (( role: reference ))
 
-Every cron job MUST be idempotent:
 - Running the same job twice produces the same result (no duplicate pages, no duplicate timeline entries)
 - Use checkpoint state files to track progress and resume interrupted runs
 - Check for existing output before creating new output
 
-## Output Format
+
+### Idempotency Requirement — steps (( role: reference ))
+
+Every cron job MUST be idempotent:
+## Output Format (( role: template ))
 
 Job configuration saved. Report: "Job '{name}' scheduled at {cron expression}. Next run: {time}."
 
-## Multi-source brains: use `sync --all`, not per-source entries
-
-When the brain has 2+ active sources (anything `gbrain sources list` shows
-with a non-null `local_path` that isn't archived), use one consolidated
-cron line instead of N per-source entries.
+## Multi-source brains: use `sync --all`, not per-source entries (( role: reference ))
 
 **Preferred (multi-source)**:
 
@@ -70,7 +69,20 @@
 connections during the wave (each per-file worker opens its own
 2-connection pool). Stay under your Postgres `max_connections` setting.
 
-**Avoid (legacy)**: separate `gbrain sync --source default` and
+`gbrain doctor` surfaces the recommended line as a `sync_consolidation`
+check whenever it detects 2+ active sources. Paste-ready from there.
+
+
+### Multi-source brains: use `sync --all`, not per-source entries — steps (( role: reference ))
+
+When the brain has 2+ active sources (anything `gbrain sources list` shows
+with a non-null `local_path` that isn't archived), use one consolidated
+cron line instead of N per-source entries.
+
+
+### Multi-source brains: use `sync --all`, not per-source entries — steps 2 (( role: reference ))
+
+Avoid (legacy): separate `gbrain sync --source default` and
 `gbrain sync --source zion-brain` entries staggered by 5 minutes. They
 require manual deconfliction every time a new source is added, and a
 slow source can race a fast source on the legacy global `gbrain-sync`
@@ -78,10 +90,7 @@
 per-source cron pattern doesn't benefit from the parallelism that
 `--all --parallel` actually delivers).
 
-`gbrain doctor` surfaces the recommended line as a `sync_consolidation`
-check whenever it detects 2+ active sources. Paste-ready from there.
-
-## Anti-Patterns
+## Anti-Patterns (( role: reference ))
 
 - Scheduling jobs at the same minute (:00 for everything)
 - Inline 3000-word prompts in cron jobs (use skill file references)
```
