# Deviation: reports.meri

- Original: `reports/SKILL.md`
- Ported: `reports.meri`
- Tier: 2 (light edits)
- Similarity: 54%
- Lines: 60 -> 58 (+26 / -28)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- shell-block-routed

## Metrics
- Sections: 1/5 inert (20% inert ratio)
- Operational inert: 0
- Unclassified inert: 0
- Inert categories: template=1
- Judgment: 1 blocks, 3 lines

### Inert section details
- L29 `Output Format`: template — Template/output shape is metadata unless explicit output assertions are authored.

## Unified diff

```diff
--- original-skills/reports/SKILL.md
+++ skills/reports.meri
@@ -18,43 +18,41 @@
 
 # Reports Skill
 
-## Contract
+## Contract (( role: procedure ))
 
-This skill guarantees:
-- Reports saved with timestamped filenames and frontmatter
-- Keyword routing: query → report category mapping
-- Latest report loadable by category name
-- Reports are searchable via gbrain search/query
+> This skill guarantees:
+!!! checklist (( ai-autonomy ))
+- [ ] Reports saved with timestamped filenames and frontmatter
+- [ ] Keyword routing: query → report category mapping
+- [ ] Latest report loadable by category name
+- [ ] Reports are searchable via gbrain search/query
 
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
+## Escalation guard
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
+## Anti-Patterns (( role: procedure ))
 
-- Saving reports without frontmatter (makes them unsearchable)
-- Using inconsistent category names across runs
-- Loading all reports when only the latest is needed
-- Not routing by keyword (forcing exact category name)
+!!! checklist (( ai-autonomy ))
+- [ ] Saving reports without frontmatter (makes them unsearchable)
+- [ ] Using inconsistent category names across runs
+- [ ] Loading all reports when only the latest is needed
+- [ ] Not routing by keyword (forcing exact category name)
 
```
