# Deviation: media_ingest.meri

- Original: `media-ingest/SKILL.md`
- Ported: `media_ingest.meri`
- Tier: 1 (near-verbatim)
- Similarity: 89%
- Lines: 122 -> 122 (+14 / -14)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- preamble-blockquoted

## Metrics
- Sections: 9/9 inert (100% inert ratio)
- Operational inert: 5
- Unclassified inert: 0
- Inert categories: operational-procedure=5, reference-documentation=3, template=1
- Judgment: 0 blocks, 0 lines

### Inert section details
- L8 `Contract`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L21 `Phases`: operational-procedure — Marked or derived as procedure, but inert suppresses execution.
- L23 `Phase 1: Identify format and fetch`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L34 `Phase 2: Upload raw source`: operational-procedure — Marked or derived as procedure, but inert suppresses execution.
- L38 `Phase 3: Create brain page`: operational-procedure — Marked or derived as procedure, but inert suppresses execution.
- L62 `Phase 4: Entity extraction and propagation`: operational-procedure — Marked or derived as procedure, but inert suppresses execution.
- L72 `Phase 5: Sync`: operational-procedure — Marked or derived as procedure, but inert suppresses execution.
- L76 `Output Format`: template — Template/output shape is metadata unless explicit output assertions are authored.
- L81 `Anti-Patterns`: reference-documentation — Reference documentation, rationale, examples, or changelog.

## Unified diff

```diff
--- original-skills/media-ingest/SKILL.md
+++ skills/media_ingest.meri
@@ -35,11 +35,11 @@
 
 # Media Ingest Skill
 
-Ingest video, audio, PDF, book, screenshot, and GitHub repo content into the brain.
+> Ingest video, audio, PDF, book, screenshot, and GitHub repo content into the brain.
 
 > **Filing rule:** Read `skills/_brain-filing-rules.md` before creating any new page.
 
-## Contract
+## Contract (( inert, role: invariants ))
 
 This skill guarantees:
 - Every ingested media item has a brain page with analysis (not just a transcript dump)
@@ -52,9 +52,9 @@
 
 Every mention of a person or company with a brain page MUST create a back-link.
 
-## Phases
+## Phases (( inert, role: procedure ))
 
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
@@ -103,16 +103,16 @@
 
 A media item is NOT fully ingested until entity propagation is complete.
 
-### Phase 5: Sync
+### Phase 5: Sync (( inert, role: procedure ))
 
 `gbrain sync` to update the index.
 
-## Output Format
+## Output Format (( inert, role: template ))
 
 Brain page created with summary, highlights, and entity cross-links. Report to user:
 "Ingested {title}: {N} entities detected, {N} pages updated."
 
-## Anti-Patterns
+## Anti-Patterns (( inert, role: prohibitions ))
 
 - Dumping raw transcripts without analysis
 - Skipping entity extraction ("I'll do that separately")
```
