# Deviation: daily_task_manager.meri

- Original: `daily-task-manager/SKILL.md`
- Ported: `daily_task_manager.meri`
- Tier: 2 (light edits)
- Similarity: 80%
- Lines: 71 -> 89 (+25 / -7)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- doc-section-marked

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L38 `Output Format`: template - Template/output shape is metadata unless explicit output assertions are authored.

## Metrics
- generated_loc: 45 non-blank ported lines
- Sections inert total: 4/4 (100% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert markers (`(( inert ))`, target 0 — the migrator never emits these): 0
- Inert categories: reference-documentation=3, template=1
- Judgment: 3 blocks, 1 lines
- canonical_drift: synonym=2, structure=0, desugar=0, meaning=49

### Inert section details
- L4 `Contract`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L17 `Phases`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L38 `Output Format`: template — Template/output shape is metadata unless explicit output assertions are authored.
- L59 `Anti-Patterns`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.

## Unified diff

```diff
--- original-skills/daily-task-manager/SKILL.md
+++ skills/daily_task_manager.meri
@@ -20,25 +20,39 @@
 
 # Daily Task Manager
 
-## Contract
+## Contract (( role: reference ))
 
 This skill guarantees:
 - Tasks stored as a brain page (`ops/tasks.md`) with structured format
 - Task lifecycle: add → in-progress → complete | defer
 - Priority levels: P0 (urgent), P1 (today), P2 (this week), P3 (backlog)
 - Completed tasks archived with completion date
+
+### Contract — steps (( role: reference ))
+
+use judgment to follow the Contract — steps guidance:
 - Deferred tasks carry forward with reason
 
-## Phases
+## Phases (( role: reference ))
 
-1. **Load current tasks.** `gbrain get ops/tasks` — read the task list.
 2. **Execute the requested action:**
    - **Add:** Append task with priority, description, due date. Add timeline entry.
    - **Complete:** Mark as done, move to completed section with date.
-   - **Defer:** Move to next day/week with reason.
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
+use judgment to follow the Phases — steps 2 guidance:
+   - **Defer:** Move to next day/week with reason.
+
+### Phases — steps 3
+
+3. Save. `gbrain put ops/tasks` — write updated task list.
 
 ## Output Format
 
@@ -61,11 +75,15 @@
 - [x] {task} (completed: {date})
 ```
 
-## Anti-Patterns
+## Anti-Patterns (( role: reference ))
 
 - Adding tasks without a priority level
 - Completing tasks without recording the completion date
-- Deferring tasks without a reason
 - Letting the task list grow unbounded (review weekly)
 - Storing tasks outside the brain (they should be searchable)
 
+
+### Anti-Patterns — steps (( role: reference ))
+
+use judgment to follow the Anti-Patterns — steps guidance:
+- Deferring tasks without a reason
```
