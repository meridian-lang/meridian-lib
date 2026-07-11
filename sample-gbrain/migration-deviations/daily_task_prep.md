# Deviation: daily_task_prep.meri

- Original: `daily-task-prep/SKILL.md`
- Ported: `daily_task_prep.meri`
- Tier: 1 (near-verbatim)
- Similarity: 89%
- Lines: 62 -> 62 (+7 / -7)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- doc-section-marked

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L4 `Contract`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L12 `Phases`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L19 `Output Format`: template - Template/output shape is metadata unless explicit output assertions are authored.
- L38 `Anti-Patterns`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.

## Metrics
- Sections inert total: 4/4 (100% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert markers (`(( inert ))`, target 0 — the migrator never emits these): 0
- Inert categories: reference-documentation=3, template=1
- Judgment: 0 blocks, 0 lines
- canonical_drift: synonym=0, structure=0, desugar=0, meaning=35

### Inert section details
- L4 `Contract`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L12 `Phases`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L19 `Output Format`: template — Template/output shape is metadata unless explicit output assertions are authored.
- L38 `Anti-Patterns`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.

## Unified diff

```diff
--- original-skills/daily-task-prep/SKILL.md
+++ skills/daily_task_prep.meri
@@ -20,7 +20,7 @@
 
 # Daily Task Prep
 
-## Contract
+## Contract (( role: reference ))
 
 This skill guarantees:
 - Calendar/meetings for today are loaded with brain context per attendee
@@ -28,12 +28,12 @@
 - Active tasks reviewed with priority ordering
 - Prep briefing is actionable (not just informational)
 
-## Phases
+## Phases (( role: reference ))
 
-1. **Load calendar.** Check today's meetings. For each: load attendee brain pages, recent timeline, open threads.
-2. **Check yesterday's threads.** Search brain for yesterday's timeline entries. Flag anything unresolved.
-3. **Review active tasks.** Load `ops/tasks` from brain. Surface P0 and P1 items.
-4. **Compile prep briefing.** Per-meeting context cards + open threads + task priorities.
+1. Check today's meetings. For each: load attendee brain pages, recent timeline, open threads.
+2. Search brain for yesterday's timeline entries. Flag anything unresolved.
+3. Review active tasks. Load `ops/tasks` from brain. Surface P0 and P1 items.
+4. Per-meeting context cards + open threads + task priorities.
 
 ## Output Format
 
@@ -54,7 +54,7 @@
 - {task with priority}
 ```
 
-## Anti-Patterns
+## Anti-Patterns (( role: reference ))
 
 - Listing meetings without loading attendee context from brain
 - Ignoring yesterday's unresolved threads
```
