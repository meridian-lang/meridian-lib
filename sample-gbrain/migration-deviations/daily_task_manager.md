# Deviation: daily_task_manager.meri

- Original: `daily-task-manager/SKILL.md`
- Ported: `daily_task_manager.meri`
- Tier: 1 (near-verbatim)
- Similarity: 94%
- Lines: 71 -> 71 (+4 / -4)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- inert-section-added

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L4 `Contract`: normative-contract - Normative invariants prose needs mining into assertions or explicit AI routing.
- L13 `Phases`: operational-procedure - Marked or derived as procedure, but inert suppresses execution.
- L24 `Output Format`: template - Template/output shape is metadata unless explicit output assertions are authored.
- L45 `Anti-Patterns`: reference-documentation - Reference documentation, rationale, examples, or changelog.

## Metrics
- Sections: 4/4 inert (100% inert ratio)
- Operational inert: 2
- Unclassified inert: 0
- Inert categories: normative-contract=1, operational-procedure=1, reference-documentation=1, template=1
- Judgment: 0 blocks, 0 lines

### Inert section details
- L4 `Contract`: normative-contract — Normative invariants prose needs mining into assertions or explicit AI routing.
- L13 `Phases`: operational-procedure — Marked or derived as procedure, but inert suppresses execution.
- L24 `Output Format`: template — Template/output shape is metadata unless explicit output assertions are authored.
- L45 `Anti-Patterns`: reference-documentation — Reference documentation, rationale, examples, or changelog.

## Unified diff

```diff
--- original-skills/daily-task-manager/SKILL.md
+++ skills/daily_task_manager.meri
@@ -20,7 +20,7 @@
 
 # Daily Task Manager
 
-## Contract
+## Contract (( inert, role: invariants ))
 
 This skill guarantees:
 - Tasks stored as a brain page (`ops/tasks.md`) with structured format
@@ -29,7 +29,7 @@
 - Completed tasks archived with completion date
 - Deferred tasks carry forward with reason
 
-## Phases
+## Phases (( inert, role: procedure ))
 
 1. **Load current tasks.** `gbrain get ops/tasks` — read the task list.
 2. **Execute the requested action:**
@@ -57,11 +57,11 @@
 ## P3 — Backlog
 - [ ] {task description}
 
-## Completed
+## Completed (( inert ))
 - [x] {task} (completed: {date})
 ```
 
-## Anti-Patterns
+## Anti-Patterns (( inert, role: prohibitions ))
 
 - Adding tasks without a priority level
 - Completing tasks without recording the completion date
```
