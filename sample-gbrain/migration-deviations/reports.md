# Deviation: reports.meri

- Original: `reports/SKILL.md`
- Ported: `reports.meri`
- Tier: 2 (light edits)
- Similarity: 77%
- Lines: 60 -> 47 (+6 / -19)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added

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
@@ -28,30 +28,17 @@
 
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
 
 ## Output Format
 
 Saved: `reports/{category}/{YYYY-MM-DD-HHMM}.md`
 Loaded: full report content with metadata.
 
-## Anti-Patterns
+## Anti-Patterns (( inert, role: prohibitions ))
 
 - Saving reports without frontmatter (makes them unsearchable)
 - Using inconsistent category names across runs
```
