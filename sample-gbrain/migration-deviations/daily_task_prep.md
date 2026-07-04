# Deviation: daily_task_prep.meri

- Original: `daily-task-prep/SKILL.md`
- Ported: `daily_task_prep.meri`
- Tier: 1 (near-verbatim)
- Similarity: 89%
- Lines: 62 -> 64 (+8 / -6)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- shell-block-routed
- inert-section-added

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L20 `Output Format`: template - Template/output shape is metadata unless explicit output assertions are authored.

## Metrics
- Sections inert total: 1/4 (25% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert categories: template=1
- Judgment: 2 blocks, 0 lines

### Inert section details
- L20 `Output Format`: template — Template/output shape is metadata unless explicit output assertions are authored.

## Unified diff

```diff
--- original-skills/daily-task-prep/SKILL.md
+++ skills/daily_task_prep.meri
@@ -20,7 +20,8 @@
 
 # Daily Task Prep
 
-## Contract
+## Contract (( role: procedure ))
+use judgment to follow the Contract guidance:
 
 This skill guarantees:
 - Calendar/meetings for today are loaded with brain context per attendee
@@ -30,10 +31,10 @@
 
 ## Phases
 
-1. **Load calendar.** Check today's meetings. For each: load attendee brain pages, recent timeline, open threads.
-2. **Check yesterday's threads.** Search brain for yesterday's timeline entries. Flag anything unresolved.
-3. **Review active tasks.** Load `ops/tasks` from brain. Surface P0 and P1 items.
-4. **Compile prep briefing.** Per-meeting context cards + open threads + task priorities.
+1. Check today's meetings. For each: load attendee brain pages, recent timeline, open threads.
+2. Search brain for yesterday's timeline entries. Flag anything unresolved.
+3. Review active tasks. Load `ops/tasks` from brain. Surface P0 and P1 items.
+4. Per-meeting context cards + open threads + task priorities.
 
 ## Output Format
 
@@ -54,7 +55,8 @@
 - {task with priority}
 ```
 
-## Anti-Patterns
+## Anti-Patterns (( role: procedure ))
+use judgment to follow the Anti-Patterns guidance:
 
 - Listing meetings without loading attendee context from brain
 - Ignoring yesterday's unresolved threads
```
