# Deviation: migrate.meri

- Original: `migrate/SKILL.md`
- Ported: `migrate.meri`
- Tier: 2 (light edits)
- Similarity: 75%
- Lines: 137 -> 155 (+46 / -28)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- preamble-blockquoted
- doc-section-marked

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L32 `Phases`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L64 `Notion Migration`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L105 `Output Format`: template - Template/output shape is metadata unless explicit output assertions are authored.
- L131 `Tools Used`: tools-metadata - Tools sections are metadata-mining, not workflow execution.

## Metrics
- Sections inert total: 9/9 (100% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert markers (`(( inert ))`, target 0 — the migrator never emits these): 0
- Inert categories: reference-documentation=7, template=1, tools-metadata=1
- Judgment: 0 blocks, 0 lines

### Inert section details
- L6 `Contract`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L32 `Phases`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L41 `Obsidian Migration`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L64 `Notion Migration`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L72 `CSV Migration`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L83 `Verification`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L95 `Anti-Patterns`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L105 `Output Format`: template — Template/output shape is metadata unless explicit output assertions are authored.
- L131 `Tools Used`: tools-metadata — Tools sections are metadata-mining, not workflow execution.

## Unified diff

```diff
--- original-skills/migrate/SKILL.md
+++ skills/migrate.meri
@@ -16,17 +16,23 @@
 
 # Migrate Skill
 
-Universal migration from any wiki, note tool, or brain system into GBrain.
+> Universal migration from any wiki, note tool, or brain system into GBrain.
 
-## Contract
+## Contract (( role: reference ))
 
-- Source data is never modified or deleted; migration is additive only.
 - Every migrated page is verified round-trip: written to gbrain, read back, spot-checked.
 - Cross-references from the source system (wikilinks, block refs, tags) are converted to gbrain equivalents.
 - Migration is tested on a sample (5-10 files) before bulk execution.
 - Post-migration health check confirms page count, link integrity, and embedding coverage.
 
+
+### Contract — steps (( role: reference ))
+
+- Source data is never modified or deleted; migration is additive only.
 ## Supported Sources
+
+
+### Supported Sources — steps (( role: reference ))
 
 | Source | Format | Strategy |
 |--------|--------|----------|
@@ -38,25 +44,18 @@
 | JSON | Structured data | Map keys to page fields |
 | Roam | JSON export | Convert block structure to pages |
 
-## Phases
+## Phases (( role: reference ))
 
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
+## Obsidian Migration (( role: reference ))
 
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
@@ -67,7 +66,17 @@
 - Frontmatter properties map to gbrain frontmatter
 - Attachments (images, PDFs) are noted but handled separately via file storage
 
-## Notion Migration
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
+## Notion Migration (( role: reference ))
 
 1. Export from Notion: Settings > Export > Markdown & CSV
 2. Notion exports nested directories with UUIDs in filenames
@@ -75,30 +84,39 @@
 4. Map Notion's database properties to frontmatter
 5. Import the cleaned directory into gbrain
 
-## CSV Migration
+## CSV Migration (( role: reference ))
 
-For tabular data (e.g., CRM exports, contact lists):
-1. For each row in the CSV, create a page with column values as frontmatter
 2. Use a designated column as the slug (e.g., name)
 3. Use another column as compiled_truth (e.g., notes)
 4. Store each page in gbrain
 
-## Verification
+
+### CSV Migration — steps
+
+> For tabular data (e.g., CRM exports, contact lists):
+1. For each row in the CSV, create a page with column values as frontmatter
+## Verification (( role: reference ))
 
 After any migration:
 1. Check gbrain statistics to verify page count matches source
-2. Check gbrain health for orphans and missing embeddings
 3. Export pages from gbrain for round-trip verification
 4. Spot-check 5-10 pages by reading them from gbrain
 5. Test search: search gbrain for "someone you know is in the data"
 
-## Anti-Patterns
 
-- **Bulk import without sample test.** Never import the full dataset before verifying with 5-10 files. The cost of cleaning up hundreds of bad pages is enormous.
-- **Destroying source data.** Migration is additive. Never modify, move, or delete the source files.
-- **Ignoring cross-references.** Wikilinks, block refs, and tags from the source system must be converted to gbrain equivalents. Dropping them loses the knowledge graph.
+### Verification — steps
+
+2. Check gbrain health for orphans and missing embeddings
+## Anti-Patterns (( role: reference ))
+
 - **Skipping verification.** A migration without post-import health check, page count comparison, and spot-check reads is incomplete.
 
+
+### Anti-Patterns — steps (( role: reference ))
+
+- Never import the full dataset before verifying with 5-10 files. The cost of cleaning up hundreds of bad pages is enormous.
+- Migration is additive. Never modify, move, or delete the source files.
+- Wikilinks, block refs, and tags from the source system must be converted to gbrain equivalents. Dropping them loses the knowledge graph.
 ## Output Format
 
 ```
```
