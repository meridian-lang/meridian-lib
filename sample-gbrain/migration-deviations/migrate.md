# Deviation: migrate.meri

- Original: `migrate/SKILL.md`
- Ported: `migrate.meri`
- Tier: 2 (light edits)
- Similarity: 81%
- Lines: 137 -> 150 (+34 / -21)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- shell-block-routed
- preamble-blockquoted
- inert-section-added

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L100 `Output Format`: template - Template/output shape is metadata unless explicit output assertions are authored.
- L126 `Tools Used`: tools-metadata - Tools sections are metadata-mining, not workflow execution.

## Metrics
- Sections inert total: 4/9 (44% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert categories: reference-documentation=2, template=1, tools-metadata=1
- Judgment: 3 blocks, 0 lines

### Inert section details
- L40 `Obsidian Migration`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L71 `CSV Migration`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L100 `Output Format`: template — Template/output shape is metadata unless explicit output assertions are authored.
- L126 `Tools Used`: tools-metadata — Tools sections are metadata-mining, not workflow execution.

## Unified diff

```diff
--- original-skills/migrate/SKILL.md
+++ skills/migrate.meri
@@ -16,9 +16,10 @@
 
 # Migrate Skill
 
-Universal migration from any wiki, note tool, or brain system into GBrain.
+> Universal migration from any wiki, note tool, or brain system into GBrain.
 
-## Contract
+## Contract (( role: procedure ))
+use judgment to follow the Contract guidance:
 
 - Source data is never modified or deleted; migration is additive only.
 - Every migrated page is verified round-trip: written to gbrain, read back, spot-checked.
@@ -26,8 +27,12 @@
 - Migration is tested on a sample (5-10 files) before bulk execution.
 - Post-migration health check confirms page count, link integrity, and embedding coverage.
 
-## Supported Sources
+## Supported Sources (( inert ))
 
+
+### Supported Sources — steps
+
+!!! table (( ai-discretion ))
 | Source | Format | Strategy |
 |--------|--------|----------|
 | Obsidian | Markdown + `[[wikilinks]]` | Direct import, convert wikilinks to gbrain links |
@@ -40,23 +45,16 @@
 
 ## Phases
 
-1. **Assess the source.** What format? How many files? What structure?
-2. **Plan the mapping.** How do source fields map to gbrain fields (type, title, tags, compiled_truth, timeline)?
-3. **Test with a sample.** Import 5-10 files, verify by reading them back from gbrain and exporting.
-4. **Bulk import.** Import the full directory into gbrain.
-5. **Verify.** Check gbrain health and statistics, spot-check pages.
-6. **Build links.** Extract cross-references from content and create typed links in gbrain.
+1. What format? How many files? What structure?
+2. How do source fields map to gbrain fields (type, title, tags, compiled_truth, timeline)?
+3. Import 5-10 files, verify by reading them back from gbrain and exporting.
+4. Import the full directory into gbrain.
+5. Check gbrain health and statistics, spot-check pages.
+6. Extract cross-references from content and create typed links in gbrain.
 
-## Obsidian Migration
+## Obsidian Migration (( inert ))
 
 1. Import the vault directory into gbrain (Obsidian vaults are markdown directories)
-2. Wire the graph with native wikilink support (v0.12.1+):
-
-   ```bash
-   gbrain extract links --source db --dry-run | head -20    # preview
-   gbrain extract links --source db                         # commit
-   ```
-
    `extract links` natively parses `[[relative/path]]` and `[[relative/path|Display Text]]`
    alongside standard `[text](page.md)` markdown syntax. Ancestor-search resolution handles
    wiki KBs where authors omit one or more leading `../` prefixes. The `.md` suffix is
@@ -67,6 +65,16 @@
 - Frontmatter properties map to gbrain frontmatter
 - Attachments (images, PDFs) are noted but handled separately via file storage
 
+
+### Obsidian Migration — steps
+
+> 2. Wire the graph with native wikilink support (v0.12.1+):
+
+   ```bash
+   gbrain extract links --source db --dry-run | head -20    # preview
+   gbrain extract links --source db                         # commit
+   ```
+
 ## Notion Migration
 
 1. Export from Notion: Settings > Export > Markdown & CSV
@@ -75,15 +83,19 @@
 4. Map Notion's database properties to frontmatter
 5. Import the cleaned directory into gbrain
 
-## CSV Migration
+## CSV Migration (( inert ))
 
-For tabular data (e.g., CRM exports, contact lists):
-1. For each row in the CSV, create a page with column values as frontmatter
 2. Use a designated column as the slug (e.g., name)
 3. Use another column as compiled_truth (e.g., notes)
 4. Store each page in gbrain
 
+
+### CSV Migration — steps
+
+> For tabular data (e.g., CRM exports, contact lists):
+1. For each row in the CSV, create a page with column values as frontmatter
 ## Verification
+use judgment to follow the Verification guidance:
 
 After any migration:
 1. Check gbrain statistics to verify page count matches source
@@ -92,7 +104,8 @@
 4. Spot-check 5-10 pages by reading them from gbrain
 5. Test search: search gbrain for "someone you know is in the data"
 
-## Anti-Patterns
+## Anti-Patterns (( role: procedure ))
+use judgment to follow the Anti-Patterns guidance:
 
 - **Bulk import without sample test.** Never import the full dataset before verifying with 5-10 files. The cost of cleaning up hundreds of bad pages is enormous.
 - **Destroying source data.** Migration is additive. Never modify, move, or delete the source files.
```
