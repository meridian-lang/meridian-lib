# Deviation: daily_task_manager.meri

- Original: `daily-task-manager/SKILL.md`
- Ported: `daily_task_manager.meri`
- Tier: 1 (near-verbatim)
- Similarity: 89%
- Lines: 71 -> 80 (+13 / -4)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- shell-block-routed
- inert-section-added

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L32 `Output Format`: template - Template/output shape is metadata unless explicit output assertions are authored.

## Metrics
- Sections inert total: 1/4 (25% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert categories: template=1
- Judgment: 3 blocks, 0 lines

### Inert section details
- L32 `Output Format`: template — Template/output shape is metadata unless explicit output assertions are authored.

## Unified diff

```diff
--- original-skills/daily-task-manager/SKILL.md
+++ skills/daily_task_manager.meri
@@ -20,7 +20,8 @@
 
 # Daily Task Manager
 
-## Contract
+## Contract (( role: procedure ))
+use judgment to follow the Contract guidance:
 
 This skill guarantees:
 - Tasks stored as a brain page (`ops/tasks.md`) with structured format
@@ -30,15 +31,22 @@
 - Deferred tasks carry forward with reason
 
 ## Phases
+use judgment to follow the Phases guidance:
 
-1. **Load current tasks.** `gbrain get ops/tasks` — read the task list.
 2. **Execute the requested action:**
    - **Add:** Append task with priority, description, due date. Add timeline entry.
    - **Complete:** Mark as done, move to completed section with date.
    - **Defer:** Move to next day/week with reason.
    - **Remove:** Delete from list (rare, prefer complete or defer).
    - **Review:** Display all active tasks by priority.
-3. **Save.** `gbrain put ops/tasks` — write updated task list.
+
+### Phases — steps
+
+1. Load current tasks. `gbrain get ops/tasks` — read the task list.
+
+### Phases — steps 2
+
+3. Save. `gbrain put ops/tasks` — write updated task list.
 
 ## Output Format
 
@@ -61,7 +69,8 @@
 - [x] {task} (completed: {date})
 ```
 
-## Anti-Patterns
+## Anti-Patterns (( role: procedure ))
+use judgment to follow the Anti-Patterns guidance:
 
 - Adding tasks without a priority level
 - Completing tasks without recording the completion date
```
