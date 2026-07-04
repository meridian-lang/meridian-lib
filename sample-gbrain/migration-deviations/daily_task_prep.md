# Deviation: daily_task_prep.meri

- Original: `daily-task-prep/SKILL.md`
- Ported: `daily_task_prep.meri`
- Tier: 1 (near-verbatim)
- Similarity: 85%
- Lines: 62 -> 62 (+9 / -9)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- inert-section-added

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L4 `Contract`: normative-contract - Normative invariants prose needs mining into assertions or explicit AI routing.
- L12 `Phases`: operational-procedure - Marked or derived as procedure, but inert suppresses execution.
- L19 `Output Format`: template - Template/output shape is metadata unless explicit output assertions are authored.
- L38 `Anti-Patterns`: reference-documentation - Reference documentation, rationale, examples, or changelog.

## Metrics
- Sections: 4/4 inert (100% inert ratio)
- Operational inert: 2
- Unclassified inert: 0
- Inert categories: normative-contract=1, operational-procedure=1, reference-documentation=1, template=1
- Judgment: 0 blocks, 0 lines

### Inert section details
- L4 `Contract`: normative-contract — Normative invariants prose needs mining into assertions or explicit AI routing.
- L12 `Phases`: operational-procedure — Marked or derived as procedure, but inert suppresses execution.
- L19 `Output Format`: template — Template/output shape is metadata unless explicit output assertions are authored.
- L38 `Anti-Patterns`: reference-documentation — Reference documentation, rationale, examples, or changelog.

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
@@ -28,12 +28,12 @@
 - Active tasks reviewed with priority ordering
 - Prep briefing is actionable (not just informational)
 
-## Phases
+## Phases (( inert, role: procedure ))
 
-1. **Load calendar.** Check today's meetings. For each: load attendee brain pages, recent timeline, open threads.
-2. **Check yesterday's threads.** Search brain for yesterday's timeline entries. Flag anything unresolved.
-3. **Review active tasks.** Load `ops/tasks` from brain. Surface P0 and P1 items.
-4. **Compile prep briefing.** Per-meeting context cards + open threads + task priorities.
+1. Load calendar. Check today's meetings. For each: load attendee brain pages, recent timeline, open threads.
+2. Check yesterday's threads. Search brain for yesterday's timeline entries. Flag anything unresolved.
+3. Review active tasks. Load `ops/tasks` from brain. Surface P0 and P1 items.
+4. Compile prep briefing. Per-meeting context cards + open threads + task priorities.
 
 ## Output Format
 
@@ -42,7 +42,7 @@
 ======================
 Meetings today: {N}
 
-## {Meeting 1 title} at {time}
+## {Meeting 1 title} at {time} (( inert ))
 Attendees: {names with brain context}
 Context: {recent interactions, open threads}
 Prep: {what to know before this meeting}
@@ -50,11 +50,11 @@
 ## Open Threads
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
