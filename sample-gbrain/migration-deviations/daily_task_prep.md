# Deviation: daily_task_prep.meri

- Original: `daily-task-prep/SKILL.md`
- Ported: `daily_task_prep.meri`
- Tier: 2 (light edits)
- Similarity: 69%
- Lines: 62 -> 69 (+24 / -17)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- shell-block-routed

## Metrics
- Sections: 1/4 inert (25% inert ratio)
- Operational inert: 0
- Unclassified inert: 0
- Inert categories: template=1
- Judgment: 1 blocks, 4 lines

### Inert section details
- L25 `Output Format`: template — Template/output shape is metadata unless explicit output assertions are authored.

## Unified diff

```diff
--- original-skills/daily-task-prep/SKILL.md
+++ skills/daily_task_prep.meri
@@ -20,20 +20,26 @@
 
 # Daily Task Prep
 
-## Contract
+## Contract (( role: procedure ))
 
-This skill guarantees:
-- Calendar/meetings for today are loaded with brain context per attendee
-- Open threads from yesterday are surfaced
-- Active tasks reviewed with priority ordering
-- Prep briefing is actionable (not just informational)
+> This skill guarantees:
+!!! checklist (( ai-autonomy ))
+- [ ] Calendar/meetings for today are loaded with brain context per attendee
+- [ ] Open threads from yesterday are surfaced
+- [ ] Active tasks reviewed with priority ordering
+- [ ] Prep briefing is actionable (not just informational)
 
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
 
@@ -42,21 +48,22 @@
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
+## Anti-Patterns (( role: procedure ))
 
-- Listing meetings without loading attendee context from brain
-- Ignoring yesterday's unresolved threads
-- Presenting tasks without priority ordering
+!!! checklist (( ai-autonomy ))
+- [ ] Listing meetings without loading attendee context from brain
+- [ ] Ignoring yesterday's unresolved threads
+- [ ] Presenting tasks without priority ordering
 
```
