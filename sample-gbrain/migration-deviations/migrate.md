# Deviation: migrate.meri

- Original: `migrate/SKILL.md`
- Ported: `migrate.meri`
- Tier: 2 (light edits)
- Similarity: 62%
- Lines: 137 -> 139 (+53 / -51)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- shell-block-routed
- preamble-blockquoted

## Metrics
- Sections: 5/10 inert (50% inert ratio)
- Operational inert: 0
- Unclassified inert: 0
- Inert categories: reference-documentation=3, template=1, tools-metadata=1
- Judgment: 3 blocks, 28 lines

### Inert section details
- L56 `Notion Migration`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L64 `CSV Migration`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L72 `Verification`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L89 `Output Format`: template — Template/output shape is metadata unless explicit output assertions are authored.
- L115 `Tools Used`: tools-metadata — Tools sections are metadata-mining, not workflow execution.

## Unified diff

```diff
--- original-skills/migrate/SKILL.md
+++ skills/migrate.meri
@@ -16,58 +16,59 @@
 
 # Migrate Skill
 
-Universal migration from any wiki, note tool, or brain system into GBrain.
+> Universal migration from any wiki, note tool, or brain system into GBrain.
 
-## Contract
+## Contract (( role: procedure ))
 
-- Source data is never modified or deleted; migration is additive only.
-- Every migrated page is verified round-trip: written to gbrain, read back, spot-checked.
-- Cross-references from the source system (wikilinks, block refs, tags) are converted to gbrain equivalents.
-- Migration is tested on a sample (5-10 files) before bulk execution.
-- Post-migration health check confirms page count, link integrity, and embedding coverage.
+!!! checklist (( ai-autonomy ))
+- [ ] Source data is never modified or deleted; migration is additive only.
+- [ ] Every migrated page is verified round-trip: written to gbrain, read back, spot-checked.
+- [ ] Cross-references from the source system (wikilinks, block refs, tags) are converted to gbrain equivalents.
+- [ ] Migration is tested on a sample (5-10 files) before bulk execution.
+- [ ] Post-migration health check confirms page count, link integrity, and embedding coverage.
 
-## Supported Sources
+## Supported Sources (( role: procedure ))
 
-| Source | Format | Strategy |
-|--------|--------|----------|
-| Obsidian | Markdown + `[[wikilinks]]` | Direct import, convert wikilinks to gbrain links |
-| Notion | Exported markdown or CSV | Parse Notion's export structure |
-| Logseq | Markdown with `((block refs))` | Convert block refs to page links |
-| Plain markdown | Any .md directory | Import directory into gbrain directly |
-| CSV | Tabular data | Map columns to frontmatter fields |
-| JSON | Structured data | Map keys to page fields |
-| Roam | JSON export | Convert block structure to pages |
-
+use judgment to follow the Supported Sources guidance:
+  | Source | Format | Strategy |
+  |--------|--------|----------|
+  | Obsidian | Markdown + `[[wikilinks]]` | Direct import, convert wikilinks to gbrain links |
+  | Notion | Exported markdown or CSV | Parse Notion's export structure |
+  | Logseq | Markdown with `((block refs))` | Convert block refs to page links |
+  | Plain markdown | Any .md directory | Import directory into gbrain directly |
+  | CSV | Tabular data | Map columns to frontmatter fields |
+  | JSON | Structured data | Map keys to page fields |
+  | Roam | JSON export | Convert block structure to pages |
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
+## Obsidian Migration (( role: procedure ))
 
-1. Import the vault directory into gbrain (Obsidian vaults are markdown directories)
-2. Wire the graph with native wikilink support (v0.12.1+):
-
-   ```bash
-   gbrain extract links --source db --dry-run | head -20    # preview
-   gbrain extract links --source db                         # commit
-   ```
-
-   `extract links` natively parses `[[relative/path]]` and `[[relative/path|Display Text]]`
-   alongside standard `[text](page.md)` markdown syntax. Ancestor-search resolution handles
-   wiki KBs where authors omit one or more leading `../` prefixes. The `.md` suffix is
-   inferred automatically for wikilinks.
-
-Obsidian-specific:
-- Tags (`#tag`) become gbrain tags
-- Frontmatter properties map to gbrain frontmatter
-- Attachments (images, PDFs) are noted but handled separately via file storage
-
-## Notion Migration
+use judgment to follow the Obsidian Migration guidance:
+  1. Import the vault directory into gbrain (Obsidian vaults are markdown directories)
+  2. Wire the graph with native wikilink support (v0.12.1+):
+  
+     ```bash
+     gbrain extract links --source db --dry-run | head -20    # preview
+     gbrain extract links --source db                         # commit
+     ```
+  
+     `extract links` natively parses `[[relative/path]]` and `[[relative/path|Display Text]]`
+     alongside standard `[text](page.md)` markdown syntax. Ancestor-search resolution handles
+     wiki KBs where authors omit one or more leading `../` prefixes. The `.md` suffix is
+     inferred automatically for wikilinks.
+  
+  Obsidian-specific:
+  item: Tags (`#tag`) become gbrain tags
+  item: Frontmatter properties map to gbrain frontmatter
+  item: Attachments (images, PDFs) are noted but handled separately via file storage
+## Notion Migration (( inert ))
 
 1. Export from Notion: Settings > Export > Markdown & CSV
 2. Notion exports nested directories with UUIDs in filenames
@@ -75,7 +76,7 @@
 4. Map Notion's database properties to frontmatter
 5. Import the cleaned directory into gbrain
 
-## CSV Migration
+## CSV Migration (( inert ))
 
 For tabular data (e.g., CRM exports, contact lists):
 1. For each row in the CSV, create a page with column values as frontmatter
@@ -83,7 +84,7 @@
 3. Use another column as compiled_truth (e.g., notes)
 4. Store each page in gbrain
 
-## Verification
+## Verification (( inert ))
 
 After any migration:
 1. Check gbrain statistics to verify page count matches source
@@ -92,12 +93,13 @@
 4. Spot-check 5-10 pages by reading them from gbrain
 5. Test search: search gbrain for "someone you know is in the data"
 
-## Anti-Patterns
+## Anti-Patterns (( role: procedure ))
 
-- **Bulk import without sample test.** Never import the full dataset before verifying with 5-10 files. The cost of cleaning up hundreds of bad pages is enormous.
-- **Destroying source data.** Migration is additive. Never modify, move, or delete the source files.
-- **Ignoring cross-references.** Wikilinks, block refs, and tags from the source system must be converted to gbrain equivalents. Dropping them loses the knowledge graph.
-- **Skipping verification.** A migration without post-import health check, page count comparison, and spot-check reads is incomplete.
+!!! checklist (( ai-autonomy ))
+- [ ] **Bulk import without sample test.** Never import the full dataset before verifying with 5-10 files. The cost of cleaning up hundreds of bad pages is enormous.
+- [ ] **Destroying source data.** Migration is additive. Never modify, move, or delete the source files.
+- [ ] **Ignoring cross-references.** Wikilinks, block refs, and tags from the source system must be converted to gbrain equivalents. Dropping them loses the knowledge graph.
+- [ ] **Skipping verification.** A migration without post-import health check, page count comparison, and spot-check reads is incomplete.
 
 ## Output Format
 
```
