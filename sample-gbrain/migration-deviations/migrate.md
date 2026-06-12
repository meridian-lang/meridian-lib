# Deviation: migrate.meri

- Original: `migrate/SKILL.md`
- Ported: `migrate.meri`
- Tier: 1 (near-verbatim)
- Similarity: 89%
- Lines: 137 -> 137 (+15 / -15)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- preamble-blockquoted

## Metrics
- Sections: 9/10 inert (90% inert ratio)
- Judgment: 1 blocks, 5 lines

## Unified diff

```diff
--- original-skills/migrate/SKILL.md
+++ skills/migrate.meri
@@ -16,9 +16,9 @@
 
 # Migrate Skill
 
-Universal migration from any wiki, note tool, or brain system into GBrain.
+> Universal migration from any wiki, note tool, or brain system into GBrain.
 
-## Contract
+## Contract (( inert, role: invariants ))
 
 - Source data is never modified or deleted; migration is additive only.
 - Every migrated page is verified round-trip: written to gbrain, read back, spot-checked.
@@ -26,7 +26,7 @@
 - Migration is tested on a sample (5-10 files) before bulk execution.
 - Post-migration health check confirms page count, link integrity, and embedding coverage.
 
-## Supported Sources
+## Supported Sources (( inert ))
 
 | Source | Format | Strategy |
 |--------|--------|----------|
@@ -40,14 +40,14 @@
 
 ## Phases
 
-1. **Assess the source.** What format? How many files? What structure?
-2. **Plan the mapping.** How do source fields map to gbrain fields (type, title, tags, compiled_truth, timeline)?
-3. **Test with a sample.** Import 5-10 files, verify by reading them back from gbrain and exporting.
-4. **Bulk import.** Import the full directory into gbrain.
-5. **Verify.** Check gbrain health and statistics, spot-check pages.
-6. **Build links.** Extract cross-references from content and create typed links in gbrain.
+use judgment to migrate an external source into the brain:
+  Assess the source format, file count, and structure.
+  Plan how source fields map to gbrain fields (type, title, tags, compiled truth, timeline).
+  Test with a sample of five to ten files and verify by reading them back.
+  Bulk import the full directory, then verify health and spot-check pages.
+  Extract cross-references and create typed links.
 
-## Obsidian Migration
+## Obsidian Migration (( inert ))
 
 1. Import the vault directory into gbrain (Obsidian vaults are markdown directories)
 2. Wire the graph with native wikilink support (v0.12.1+):
@@ -67,7 +67,7 @@
 - Frontmatter properties map to gbrain frontmatter
 - Attachments (images, PDFs) are noted but handled separately via file storage
 
-## Notion Migration
+## Notion Migration (( inert ))
 
 1. Export from Notion: Settings > Export > Markdown & CSV
 2. Notion exports nested directories with UUIDs in filenames
@@ -75,7 +75,7 @@
 4. Map Notion's database properties to frontmatter
 5. Import the cleaned directory into gbrain
 
-## CSV Migration
+## CSV Migration (( inert ))
 
 For tabular data (e.g., CRM exports, contact lists):
 1. For each row in the CSV, create a page with column values as frontmatter
@@ -83,7 +83,7 @@
 3. Use another column as compiled_truth (e.g., notes)
 4. Store each page in gbrain
 
-## Verification
+## Verification (( inert ))
 
 After any migration:
 1. Check gbrain statistics to verify page count matches source
@@ -92,7 +92,7 @@
 4. Spot-check 5-10 pages by reading them from gbrain
 5. Test search: search gbrain for "someone you know is in the data"
 
-## Anti-Patterns
+## Anti-Patterns (( inert, role: prohibitions ))
 
 - **Bulk import without sample test.** Never import the full dataset before verifying with 5-10 files. The cost of cleaning up hundreds of bad pages is enormous.
 - **Destroying source data.** Migration is additive. Never modify, move, or delete the source files.
@@ -125,7 +125,7 @@
 - Search test: [query] -> [result count] hits
 ```
 
-## Tools Used
+## Tools Used (( inert ))
 
 - Store/update pages in gbrain (put_page)
 - Read pages from gbrain (get_page)
```
