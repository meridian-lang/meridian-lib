# Deviation: daily_task_prep.meri

- Original: `daily-task-prep/SKILL.md`
- Ported: `daily_task_prep.meri`
- Tier: 2 (light edits)
- Similarity: 82%
- Lines: 62 -> 67 (+14 / -9)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added

## Unified diff

```diff
--- original-skills/daily-task-prep/SKILL.md
+++ skills/daily_task_prep.meri
@@ -20,7 +20,7 @@
 
 # Daily Task Prep
 
-## Contract
+## Contract (( inert, role: invariants ))
 
 This skill guarantees:
 - Calendar/meetings for today are loaded with brain context per attendee
@@ -30,10 +30,15 @@
 
 ## Phases
 
-1. **Load calendar.** Check today's meetings. For each: load attendee brain pages, recent timeline, open threads.
-2. **Check yesterday's threads.** Search brain for yesterday's timeline entries. Flag anything unresolved.
-3. **Review active tasks.** Load `ops/tasks` from brain. Surface P0 and P1 items.
-4. **Compile prep briefing.** Per-meeting context cards + open threads + task priorities.
+```bash
+gbrain get ops/tasks
+```
+
+use judgment to compile the morning prep briefing:
+  Load today's calendar and, for each meeting, load attendee brain pages, recent timeline, and open threads.
+  Search the brain for yesterday's timeline entries and flag anything unresolved.
+  Surface P0 and P1 tasks from the task list.
+  Compile per-meeting context cards plus open threads and task priorities.
 
 ## Output Format
 
@@ -42,19 +47,19 @@
 ======================
 Meetings today: {N}
 
-## {Meeting 1 title} at {time}
+## {Meeting 1 title} at {time} (( inert ))
 Attendees: {names with brain context}
 Context: {recent interactions, open threads}
 Prep: {what to know before this meeting}
 
-## Open Threads
+## Open Threads (( inert ))
 - {thread from yesterday, with context}
 
-## Tasks (P0-P1)
+## Tasks (P0-P1) (( inert ))
 - {task with priority}
 ```
 
-## Anti-Patterns
+## Anti-Patterns (( inert, role: prohibitions ))
 
 - Listing meetings without loading attendee context from brain
 - Ignoring yesterday's unresolved threads
```
