# Deviation: reports.meri

- Original: `reports/SKILL.md`
- Ported: `reports.meri`
- Tier: 1 (near-verbatim)
- Similarity: 93%
- Lines: 60 -> 63 (+6 / -3)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- shell-block-routed
- inert-section-added

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L34 `Output Format`: template - Template/output shape is metadata unless explicit output assertions are authored.

## Metrics
- Sections inert total: 1/4 (25% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert categories: template=1
- Judgment: 3 blocks, 0 lines

### Inert section details
- L34 `Output Format`: template — Template/output shape is metadata unless explicit output assertions are authored.

## Unified diff

```diff
--- original-skills/reports/SKILL.md
+++ skills/reports.meri
@@ -18,7 +18,8 @@
 
 # Reports Skill
 
-## Contract
+## Contract (( role: procedure ))
+use judgment to follow the Contract guidance:
 
 This skill guarantees:
 - Reports saved with timestamped filenames and frontmatter
@@ -27,6 +28,7 @@
 - Reports are searchable via gbrain search/query
 
 ## Phases
+use judgment to follow the Phases guidance:
 
 1. **Save report.** Write to `reports/{category}/{YYYY-MM-DD-HHMM}.md` with frontmatter:
    ```yaml
@@ -46,12 +48,13 @@
    - "meeting" → meeting-sync
    - Custom mappings configurable
 
-## Output Format
+## Output Format (( inert, role: template ))
 
 Saved: `reports/{category}/{YYYY-MM-DD-HHMM}.md`
 Loaded: full report content with metadata.
 
-## Anti-Patterns
+## Anti-Patterns (( role: procedure ))
+use judgment to follow the Anti-Patterns guidance:
 
 - Saving reports without frontmatter (makes them unsearchable)
 - Using inconsistent category names across runs
```
