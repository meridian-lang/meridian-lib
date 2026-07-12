# Deviation: reports.meri

- Original: `reports/SKILL.md`
- Ported: `reports.meri`
- Tier: 1 (near-verbatim)
- Similarity: 88%
- Lines: 60 -> 60 (+7 / -7)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- doc-section-marked

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L4 `Contract`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L12 `Phases`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L32 `Output Format`: template - Template/output shape is metadata unless explicit output assertions are authored.
- L37 `Anti-Patterns`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.

## Metrics
- generated_loc: 33 non-blank ported lines
- Sections inert total: 4/4 (100% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert markers (`(( inert ))`, target 0 — the migrator never emits these): 0
- Inert categories: reference-documentation=3, template=1
- Judgment: 0 blocks, 0 lines
- canonical_drift: synonym=0, structure=0, desugar=0, meaning=36

### Inert section details
- L4 `Contract`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L12 `Phases`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L32 `Output Format`: template — Template/output shape is metadata unless explicit output assertions are authored.
- L37 `Anti-Patterns`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.

## Unified diff

```diff
--- original-skills/reports/SKILL.md
+++ skills/reports.meri
@@ -18,7 +18,7 @@
 
 # Reports Skill
 
-## Contract
+## Contract (( role: reference ))
 
 This skill guarantees:
 - Reports saved with timestamped filenames and frontmatter
@@ -26,9 +26,9 @@
 - Latest report loadable by category name
 - Reports are searchable via gbrain search/query
 
-## Phases
+## Phases (( role: reference ))
 
-1. **Save report.** Write to `reports/{category}/{YYYY-MM-DD-HHMM}.md` with frontmatter:
+1. Save report. Write to `reports/{category}/{YYYY-MM-DD-HHMM}.md` with frontmatter:
    ```yaml
    ---
    title: {report title}
@@ -38,20 +38,20 @@
    time: {HH:MM PT}
    ---
    ```
-2. **Load latest.** Given a category, find the most recent report file.
-3. **Keyword routing.** Map common queries to report categories:
+2. Given a category, find the most recent report file.
+3. Map common queries to report categories:
    - "email" / "inbox" → ea-inbox-sweep
    - "social" / "mentions" → social-mentions
    - "briefing" / "morning" → morning-briefing
    - "meeting" → meeting-sync
    - Custom mappings configurable
 
-## Output Format
+## Output Format (( role: template ))
 
 Saved: `reports/{category}/{YYYY-MM-DD-HHMM}.md`
 Loaded: full report content with metadata.
 
-## Anti-Patterns
+## Anti-Patterns (( role: reference ))
 
 - Saving reports without frontmatter (makes them unsearchable)
 - Using inconsistent category names across runs
```
