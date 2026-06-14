# Deviation: daily_task_manager.meri

- Original: `daily-task-manager/SKILL.md`
- Ported: `daily_task_manager.meri`
- Tier: 2 (light edits)
- Similarity: 60%
- Lines: 71 -> 79 (+34 / -26)

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
- Judgment: 1 blocks, 5 lines

### Inert section details
- L31 `Output Format`: template — Template/output shape is metadata unless explicit output assertions are authored.

## Unified diff

```diff
--- original-skills/daily-task-manager/SKILL.md
+++ skills/daily_task_manager.meri
@@ -20,52 +20,60 @@
 
 # Daily Task Manager
 
-## Contract
+## Contract (( role: procedure ))
 
-This skill guarantees:
-- Tasks stored as a brain page (`ops/tasks.md`) with structured format
-- Task lifecycle: add → in-progress → complete | defer
-- Priority levels: P0 (urgent), P1 (today), P2 (this week), P3 (backlog)
-- Completed tasks archived with completion date
-- Deferred tasks carry forward with reason
+> This skill guarantees:
+!!! checklist (( ai-autonomy ))
+- [ ] Tasks stored as a brain page (`ops/tasks.md`) with structured format
+- [ ] Task lifecycle: add → in-progress → complete | defer
+- [ ] Priority levels: P0 (urgent), P1 (today), P2 (this week), P3 (backlog)
+- [ ] Completed tasks archived with completion date
+- [ ] Deferred tasks carry forward with reason
 
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
+## Anti-Patterns (( role: procedure ))
 
-- Adding tasks without a priority level
-- Completing tasks without recording the completion date
-- Deferring tasks without a reason
-- Letting the task list grow unbounded (review weekly)
-- Storing tasks outside the brain (they should be searchable)
+!!! checklist (( ai-autonomy ))
+- [ ] Adding tasks without a priority level
+- [ ] Completing tasks without recording the completion date
+- [ ] Deferring tasks without a reason
+- [ ] Letting the task list grow unbounded (review weekly)
+- [ ] Storing tasks outside the brain (they should be searchable)
 
```
