# Deviation: migrate.meri

- Original: `migrate/SKILL.md`
- Ported: `migrate.meri`
- Tier: 1 (near-verbatim)
- Similarity: 93%
- Lines: 137 -> 137 (+9 / -9)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- preamble-blockquoted

## Metrics
- Sections: 10/10 inert (100% inert ratio)
- Operational inert: 5
- Unclassified inert: 0
- Inert categories: normative-contract=2, operational-content=2, operational-procedure=1, reference-documentation=3, template=1, tools-metadata=1
- Judgment: 0 blocks, 0 lines

### Inert section details
- L6 `Contract`: normative-contract — Normative invariants prose needs mining into assertions or explicit AI routing.
- L14 `Supported Sources`: operational-content — Body contains command, table, checklist, or explicit AI-routing surface.
- L26 `Phases`: operational-procedure — Marked or derived as procedure, but inert suppresses execution.
- L35 `Obsidian Migration`: operational-content — Body contains command, table, checklist, or explicit AI-routing surface.
- L55 `Notion Migration`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L63 `CSV Migration`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L71 `Verification`: normative-contract — Normative invariants prose needs mining into assertions or explicit AI routing.
- L80 `Anti-Patterns`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L87 `Output Format`: template — Template/output shape is metadata unless explicit output assertions are authored.
- L113 `Tools Used`: tools-metadata — Tools sections are metadata-mining, not workflow execution.

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
@@ -38,7 +38,7 @@
 | JSON | Structured data | Map keys to page fields |
 | Roam | JSON export | Convert block structure to pages |
 
-## Phases
+## Phases (( inert, role: procedure ))
 
 1. **Assess the source.** What format? How many files? What structure?
 2. **Plan the mapping.** How do source fields map to gbrain fields (type, title, tags, compiled_truth, timeline)?
@@ -47,7 +47,7 @@
 5. **Verify.** Check gbrain health and statistics, spot-check pages.
 6. **Build links.** Extract cross-references from content and create typed links in gbrain.
 
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
+## Verification (( inert, role: invariants ))
 
 After any migration:
 1. Check gbrain statistics to verify page count matches source
@@ -92,7 +92,7 @@
 4. Spot-check 5-10 pages by reading them from gbrain
 5. Test search: search gbrain for "someone you know is in the data"
 
-## Anti-Patterns
+## Anti-Patterns (( inert, role: prohibitions ))
 
 - **Bulk import without sample test.** Never import the full dataset before verifying with 5-10 files. The cost of cleaning up hundreds of bad pages is enormous.
 - **Destroying source data.** Migration is additive. Never modify, move, or delete the source files.
```
