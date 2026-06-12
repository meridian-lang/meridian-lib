# Deviation: reports.meri

- Original: `reports/SKILL.md`
- Ported: `reports.meri`
- Tier: 2 (light edits)
- Similarity: 71%
- Lines: 60 -> 56 (+15 / -19)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- shell-block-routed

## Metrics
- Sections: 3/5 inert (60% inert ratio)
- Judgment: 1 blocks, 3 lines

## Unified diff

```diff
--- original-skills/reports/SKILL.md
+++ skills/reports.meri
@@ -18,7 +18,7 @@
 
 # Reports Skill
 
-## Contract
+## Contract (( inert, role: invariants ))
 
 This skill guarantees:
 - Reports saved with timestamped filenames and frontmatter
@@ -28,30 +28,26 @@
 
 ## Phases
 
-1. **Save report.** Write to `reports/{category}/{YYYY-MM-DD-HHMM}.md` with frontmatter:
-   ```yaml
-   ---
-   title: {report title}
-   type: report
-   category: {category name}
-   date: {YYYY-MM-DD}
-   time: {HH:MM PT}
-   ---
-   ```
-2. **Load latest.** Given a category, find the most recent report file.
-3. **Keyword routing.** Map common queries to report categories:
-   - "email" / "inbox" → ea-inbox-sweep
-   - "social" / "mentions" → social-mentions
-   - "briefing" / "morning" → morning-briefing
-   - "meeting" → meeting-sync
-   - Custom mappings configurable
+use judgment to save, load, and route reports by keyword:
+  Save a report to reports/{category}/{date}.md with title, type, category, date, and time frontmatter.
+  Load the most recent report file for a given category.
+  Route common queries to report categories (for example "inbox" to ea-inbox-sweep, "morning" to morning-briefing).
+
+## Escalation guard (( role: procedure ))
+
+> When a report run finds two or more high-priority pages, escalate so the
+> pulse never buries multiple p0s in a routine digest.
+
+bind pages = invoke list pages with filter = "report".
+if at least 2 urgent pages,
+  emit reports.escalate with severity "high".
 
 ## Output Format
 
 Saved: `reports/{category}/{YYYY-MM-DD-HHMM}.md`
 Loaded: full report content with metadata.
 
-## Anti-Patterns
+## Anti-Patterns (( inert, role: prohibitions ))
 
 - Saving reports without frontmatter (makes them unsearchable)
 - Using inconsistent category names across runs
```
