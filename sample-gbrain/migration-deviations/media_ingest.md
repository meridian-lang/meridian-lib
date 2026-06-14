# Deviation: media_ingest.meri

- Original: `media-ingest/SKILL.md`
- Ported: `media_ingest.meri`
- Tier: 2 (light edits)
- Similarity: 60%
- Lines: 122 -> 124 (+50 / -48)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- shell-block-routed
- preamble-blockquoted

## Metrics
- Sections: 2/9 inert (22% inert ratio)
- Operational inert: 0
- Unclassified inert: 0
- Inert categories: reference-documentation=1, template=1
- Judgment: 4 blocks, 14 lines

### Inert section details
- L24 `Phase 1: Identify format and fetch`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L77 `Output Format`: template — Template/output shape is metadata unless explicit output assertions are authored.

## Unified diff

```diff
--- original-skills/media-ingest/SKILL.md
+++ skills/media_ingest.meri
@@ -35,26 +35,27 @@
 
 # Media Ingest Skill
 
-Ingest video, audio, PDF, book, screenshot, and GitHub repo content into the brain.
+> Ingest video, audio, PDF, book, screenshot, and GitHub repo content into the brain.
 
 > **Filing rule:** Read `skills/_brain-filing-rules.md` before creating any new page.
 
-## Contract
+## Contract (( role: procedure ))
 
-This skill guarantees:
-- Every ingested media item has a brain page with analysis (not just a transcript dump)
-- Transcripts (video/audio) saved in raw and human-readable formats
-- Entity extraction: every person and company mentioned gets back-linked
-- Raw source files preserved via `gbrain files upload-raw`
-- Filing by primary subject, not by media format
+> This skill guarantees:
+!!! checklist (( ai-autonomy ))
+- [ ] Every ingested media item has a brain page with analysis (not just a transcript dump)
+- [ ] Transcripts (video/audio) saved in raw and human-readable formats
+- [ ] Entity extraction: every person and company mentioned gets back-linked
+- [ ] Raw source files preserved via `gbrain files upload-raw`
+- [ ] Filing by primary subject, not by media format
 
-> **Convention:** See `skills/conventions/quality.md` for Iron Law back-linking.
+> > **Convention:** See `skills/conventions/quality.md` for Iron Law back-linking.
 
-Every mention of a person or company with a brain page MUST create a back-link.
+> Every mention of a person or company with a brain page MUST create a back-link.
 
 ## Phases
 
-### Phase 1: Identify format and fetch
+### Phase 1: Identify format and fetch (( inert, role: procedure ))
 
 | Format | Action |
 |--------|--------|
@@ -65,58 +66,59 @@
 | Screenshot/image | OCR via vision model, extract text and entities |
 | GitHub repo | Clone, read README + key files, summarize architecture |
 
-### Phase 2: Upload raw source
+### Phase 2: Upload raw source (( role: procedure ))
 
-Save the original file for provenance: `gbrain files upload-raw <file> --page <slug>`
-
-### Phase 3: Create brain page
-
-File by primary subject (not format). Use this template:
-
-```markdown
-# {Title}
-
-**Source:** {URL or file path}
-**Format:** {video/audio/PDF/book/screenshot/repo}
-**Created:** {date}
-
-## Summary
+use judgment to follow the Phase 2: Upload raw source guidance:
+  Save the original file for provenance: `gbrain files upload-raw <file> --page <slug>`
+### Phase 3: Create brain page (( role: procedure ))
+  
+use judgment to follow the Phase 3: Create brain page guidance:
+  File by primary subject (not format). Use this template:
+  
+  ```markdown
+  # {Title}
+  
+  **Source:** {URL or file path}
+  **Format:** {video/audio/PDF/book/screenshot/repo}
+  **Created:** {date}
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
+### Phase 4: Entity extraction and propagation (( role: procedure ))
 
-For every person and company mentioned:
-1. Check brain for existing page
-2. Create/enrich if needed (delegate to enrich skill)
-3. Add back-link from entity page to this media page
-4. Add timeline entry on entity page
-
-A media item is NOT fully ingested until entity propagation is complete.
-
-### Phase 5: Sync
-
-`gbrain sync` to update the index.
-
+use judgment to follow the Phase 4: Entity extraction and propagation guidance:
+  For every person and company mentioned:
+  1. Check brain for existing page
+  2. Create/enrich if needed (delegate to enrich skill)
+  3. Add back-link from entity page to this media page
+  4. Add timeline entry on entity page
+  
+  A media item is NOT fully ingested until entity propagation is complete.
+### Phase 5: Sync (( role: procedure ))
+  
+use judgment to follow the Phase 5: Sync guidance:
+  `gbrain sync` to update the index.
 ## Output Format
 
 Brain page created with summary, highlights, and entity cross-links. Report to user:
 "Ingested {title}: {N} entities detected, {N} pages updated."
 
-## Anti-Patterns
+## Anti-Patterns (( role: procedure ))
 
-- Dumping raw transcripts without analysis
-- Skipping entity extraction ("I'll do that separately")
-- Filing **raw ingest** by format (all videos in `media/videos/`) instead of by subject. Note: format-prefixed paths under `media/<format>/<slug>` ARE sanctioned for **synthesized one-of-one output** like book-mirror's `media/books/<slug>-personalized.md`. The anti-pattern is for raw ingest, not for sui generis synthesis. See `skills/_brain-filing-rules.md` "Sanctioned exception: synthesis output is sui generis."
-- Not preserving raw source files
-- Creating stub pages without meaningful content
+!!! checklist (( ai-autonomy ))
+- [ ] Dumping raw transcripts without analysis
+- [ ] Skipping entity extraction ("I'll do that separately")
+- [ ] Filing **raw ingest** by format (all videos in `media/videos/`) instead of by subject. Note: format-prefixed paths under `media/<format>/<slug>` ARE sanctioned for **synthesized one-of-one output** like book-mirror's `media/books/<slug>-personalized.md`. The anti-pattern is for raw ingest, not for sui generis synthesis. See `skills/_brain-filing-rules.md` "Sanctioned exception: synthesis output is sui generis."
+- [ ] Not preserving raw source files
+- [ ] Creating stub pages without meaningful content
 
```
