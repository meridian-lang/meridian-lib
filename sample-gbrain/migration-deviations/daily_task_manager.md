# Deviation: daily_task_manager.meri

- Original: `daily-task-manager/SKILL.md`
- Ported: `daily_task_manager.meri`
- Tier: 2 (light edits)
- Similarity: 76%
- Lines: 71 -> 77 (+21 / -15)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added

## Metrics
- Sections: 3/4 inert (75% inert ratio)
- Judgment: 1 blocks, 5 lines

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
@@ -31,37 +31,43 @@
 
 ## Phases
 
-1. **Load current tasks.** `gbrain get ops/tasks` — read the task list.
-2. **Execute the requested action:**
-   - **Add:** Append task with priority, description, due date. Add timeline entry.
-   - **Complete:** Mark as done, move to completed section with date.
-   - **Defer:** Move to next day/week with reason.
-   - **Remove:** Delete from list (rare, prefer complete or defer).
-   - **Review:** Display all active tasks by priority.
-3. **Save.** `gbrain put ops/tasks` — write updated task list.
+```bash
+gbrain get ops/tasks
+```
+
+use judgment to choose and apply the requested task action:
+  Add: append a task with priority, description, due date, and a timeline entry.
+  Complete: mark the task as done and move it to the completed section with the date.
+  Defer: move the task to the next day or week with a reason.
+  Remove: delete the task from the list (rare; prefer complete or defer).
+  Review: display all active tasks by priority.
+
+```bash
+gbrain put ops/tasks
+```
 
 ## Output Format
 
 ```markdown
 # Tasks
 
-## P0 — Urgent
+## P0 — Urgent (( inert ))
 - [ ] {task description} (due: {date})
 
-## P1 — Today
+## P1 — Today (( inert ))
 - [ ] {task description}
 
-## P2 — This Week
+## P2 — This Week (( inert ))
 - [ ] {task description}
 
-## P3 — Backlog
+## P3 — Backlog (( inert ))
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
