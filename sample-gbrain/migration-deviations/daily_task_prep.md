# Deviation: daily_task_prep.meri

- Original: `daily-task-prep/SKILL.md`
- Ported: `daily_task_prep.meri`
- Tier: 1 (near-verbatim)
- Similarity: 90%
- Lines: 62 -> 62 (+6 / -6)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added

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
@@ -28,7 +28,7 @@
 - Active tasks reviewed with priority ordering
 - Prep briefing is actionable (not just informational)
 
-## Phases
+## Phases (( inert, role: procedure ))
 
 1. **Load calendar.** Check today's meetings. For each: load attendee brain pages, recent timeline, open threads.
 2. **Check yesterday's threads.** Search brain for yesterday's timeline entries. Flag anything unresolved.
@@ -42,19 +42,19 @@
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
