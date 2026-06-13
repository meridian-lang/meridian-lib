# Deviation: media_ingest.meri

- Original: `media-ingest/SKILL.md`
- Ported: `media_ingest.meri`
- Tier: 1 (near-verbatim)
- Similarity: 90%
- Lines: 122 -> 122 (+12 / -12)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- preamble-blockquoted

## Metrics
- Sections: 8/9 inert (89% inert ratio)
- Judgment: 0 blocks, 0 lines

## Unified diff

```diff
--- original-skills/media-ingest/SKILL.md
+++ media_ingest.meri
@@ -35,11 +35,11 @@
 
 # Media Ingest Skill
 
-Ingest video, audio, PDF, book, screenshot, and GitHub repo content into the brain.
+> Ingest video, audio, PDF, book, screenshot, and GitHub repo content into the brain.
 
 > **Filing rule:** Read `skills/_brain-filing-rules.md` before creating any new page.
 
-## Contract
+## Contract (( inert, role: invariants ))
 
 This skill guarantees:
 - Every ingested media item has a brain page with analysis (not just a transcript dump)
@@ -54,7 +54,7 @@
 
 ## Phases
 
-### Phase 1: Identify format and fetch
+### Phase 1: Identify format and fetch (( inert, role: procedure ))
 
 | Format | Action |
 |--------|--------|
@@ -65,11 +65,11 @@
 | Screenshot/image | OCR via vision model, extract text and entities |
 | GitHub repo | Clone, read README + key files, summarize architecture |
 
-### Phase 2: Upload raw source
+### Phase 2: Upload raw source (( inert, role: procedure ))
 
 Save the original file for provenance: `gbrain files upload-raw <file> --page <slug>`
 
-### Phase 3: Create brain page
+### Phase 3: Create brain page (( inert, role: procedure ))
 
 File by primary subject (not format). Use this template:
 
@@ -80,20 +80,20 @@
 **Format:** {video/audio/PDF/book/screenshot/repo}
 **Created:** {date}
 
-## Summary
+## Summary (( inert ))
 {Key points, not a transcript dump}
 
-## Key Segments / Highlights
+## Key Segments / Highlights (( inert ))
 {For video/audio: timestamped highlights. For books: chapter summaries.}
 
-## People Mentioned
+## People Mentioned (( inert ))
 {List with links to brain pages}
 
-## Companies Mentioned
+## Companies Mentioned (( inert ))
 {List with links to brain pages}
 ```
 
-### Phase 4: Entity extraction and propagation
+### Phase 4: Entity extraction and propagation (( inert, role: procedure ))
 
 For every person and company mentioned:
 1. Check brain for existing page
@@ -103,7 +103,7 @@
 
 A media item is NOT fully ingested until entity propagation is complete.
 
-### Phase 5: Sync
+### Phase 5: Sync (( inert, role: procedure ))
 
 `gbrain sync` to update the index.
 
@@ -112,7 +112,7 @@
 Brain page created with summary, highlights, and entity cross-links. Report to user:
 "Ingested {title}: {N} entities detected, {N} pages updated."
 
-## Anti-Patterns
+## Anti-Patterns (( inert, role: prohibitions ))
 
 - Dumping raw transcripts without analysis
 - Skipping entity extraction ("I'll do that separately")
```
