# Deviation: reports.meri

- Original: `reports/SKILL.md`
- Ported: `reports.meri`
- Tier: 1 (near-verbatim)
- Similarity: 93%
- Lines: 60 -> 60 (+4 / -4)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added

## Metrics
- Sections: 4/4 inert (100% inert ratio)
- Operational inert: 2
- Unclassified inert: 0
- Inert categories: normative-contract=1, operational-procedure=1, reference-documentation=1, template=1
- Judgment: 0 blocks, 0 lines

### Inert section details
- L4 `Contract`: normative-contract — Normative invariants prose needs mining into assertions or explicit AI routing.
- L12 `Phases`: operational-procedure — Marked or derived as procedure, but inert suppresses execution.
- L32 `Output Format`: template — Template/output shape is metadata unless explicit output assertions are authored.
- L37 `Anti-Patterns`: reference-documentation — Reference documentation, rationale, examples, or changelog.

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
@@ -26,7 +26,7 @@
 - Latest report loadable by category name
 - Reports are searchable via gbrain search/query
 
-## Phases
+## Phases (( inert, role: procedure ))
 
 1. **Save report.** Write to `reports/{category}/{YYYY-MM-DD-HHMM}.md` with frontmatter:
    ```yaml
@@ -46,12 +46,12 @@
    - "meeting" → meeting-sync
    - Custom mappings configurable
 
-## Output Format
+## Output Format (( inert, role: template ))
 
 Saved: `reports/{category}/{YYYY-MM-DD-HHMM}.md`
 Loaded: full report content with metadata.
 
-## Anti-Patterns
+## Anti-Patterns (( inert, role: prohibitions ))
 
 - Saving reports without frontmatter (makes them unsearchable)
 - Using inconsistent category names across runs
```
