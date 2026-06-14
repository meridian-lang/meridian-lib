# Deviation: ingest.meri

- Original: `ingest/SKILL.md`
- Ported: `ingest.meri`
- Tier: 2 (light edits)
- Similarity: 71%
- Lines: 312 -> 297 (+81 / -96)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- shell-block-routed
- preamble-blockquoted

## Metrics
- Sections: 15/20 inert (75% inert ratio)
- Operational inert: 0
- Unclassified inert: 0
- Inert categories: reference-documentation=13, template=1, tools-metadata=1
- Judgment: 3 blocks, 32 lines

### Inert section details
- L19 `Citation Requirements (MANDATORY)`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L39 `Entity Detection on Every Message`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L55 `What counts as notable`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L63 `What to capture from the user's own thinking`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L74 `Media Workflows`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L79 `Articles & Web Content`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L95 `Videos & Podcasts`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L118 `PDFs & Documents`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L131 `Screenshots & Images`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L143 `Meeting Transcripts`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L166 `Social Media Content`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L212 `Test Before Bulk`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L226 `Quality Rules`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L246 `Output Format`: template — Template/output shape is metadata unless explicit output assertions are authored.
- L264 `Tools Used`: tools-metadata — Tools sections are metadata-mining, not workflow execution.

## Unified diff

```diff
--- original-skills/ingest/SKILL.md
+++ skills/ingest.meri
@@ -24,25 +24,22 @@
 
 # Ingest Skill
 
-Ingest meetings, articles, media, documents, and conversations into the brain.
+> Ingest meetings, articles, media, documents, and conversations into the brain.
 
 > **Filing rule:** Read `skills/_brain-filing-rules.md` before creating any new page.
 
-## Contract
-
-- Every fact written to a brain page carries an inline `[Source: ...]` citation with date and provenance.
-- Every entity mention creates a back-link from the entity's page to the page mentioning them (Iron Law).
-- Raw sources are preserved for provenance via `gbrain files upload-raw` with automatic size routing.
-- State sections are rewritten with current best understanding, never appended to.
-- Entity detection fires on every inbound message; notable entities get pages or updates.
-
-> **Convention:** See `skills/conventions/quality.md` for Iron Law back-linking.
-
-Every mention of a person or company with a brain page MUST create a back-link
-FROM that entity's page TO the page mentioning them. An unlinked mention is a
-broken brain. See `skills/_brain-filing-rules.md` for format.
-
-## Citation Requirements (MANDATORY)
+## Contract (( role: procedure ))
+
+!!! checklist (( ai-autonomy ))
+- [ ] Every fact written to a brain page carries an inline `[Source: ...]` citation with date and provenance.
+- [ ] Every entity mention creates a back-link from the entity's page to the page mentioning them (Iron Law).
+- [ ] Raw sources are preserved for provenance via `gbrain files upload-raw` with automatic size routing.
+- [ ] State sections are rewritten with current best understanding, never appended to.
+- [ ] Entity detection fires on every inbound message; notable entities get pages or updates.
+
+> > **Convention:** See `skills/conventions/quality.md` for Iron Law back-linking.
+
+## Citation Requirements (MANDATORY) (( inert ))
 
 Every fact written to a brain page must carry an inline `[Source: ...]` citation.
 
@@ -55,43 +52,30 @@
 
 ## Phases
 
-> **Router note:** This skill is a router. For specialized ingestion, see: idea-ingest, media-ingest, meeting-ingestion.
-
-1. **Parse the source.** Extract people, companies, dates, and events from the input.
-2. **For each entity mentioned:**
-   - Read the entity's page from gbrain to check if it exists
-   - If exists: update compiled_truth (rewrite State section with new info, don't append)
-   - If new: check notability gate, then store the page in gbrain with the appropriate type and slug
-3. **Append to timeline.** Add a timeline entry in gbrain for each event, with date, summary, and source citation.
-4. **Create cross-reference links.** Link entities in gbrain for every entity pair mentioned together, using the appropriate relationship type.
-5. **Back-link all entities.** Update EVERY mentioned entity's page with a back-link to this page (Iron Law).
-6. **Timeline merge.** The same event appears on ALL mentioned entities' timelines. If Alice met Bob at Acme Corp, the event goes on Alice's page, Bob's page, and Acme Corp's page.
-
-## Entity Detection on Every Message
+use judgment to ingest the source and update the brain:
+  Parse the source to extract people, companies, dates, and events.
+  For each entity mentioned, read its page and update compiled truth, or create a new page after the notability gate.
+  Append a timeline entry for each event with date, summary, and source citation.
+  Create cross-reference links for every entity pair mentioned together.
+  Back-link every mentioned entity's page to this page, and merge the event onto each entity's timeline.
+
+## Entity Detection on Every Message (( inert ))
 
 Production agents should detect entity mentions on EVERY inbound message. This is
 the signal detection loop that makes the brain compound over time.
 
 ### Protocol
 
-1. **Scan the message** for entity mentions: people, companies, concepts, original
-   thinking. Fire on every message (no exceptions unless purely operational).
-2. **For each entity detected:**
-   - `gbrain search "name"` -- does a page already exist?
-   - **If yes:** load context with `gbrain get <slug>`. Use the compiled truth to
-     inform your response. Update the page if the message contains new information.
-   - **If no:** assess notability (see `skills/_brain-filing-rules.md`). If the entity
-     is worth tracking, create a new page with `gbrain put <type/slug>` and populate
-     with what you know.
-3. **After creating or updating pages:** sync to gbrain:
-   ```bash
-   gbrain sync --no-pull --no-embed
-   ```
-4. **Don't block the conversation.** Entity detection and enrichment should happen
-   alongside the response, not before it. The user shouldn't wait for brain writes
-   to get an answer.
-
-### What counts as notable
+use judgment to detect and file entities on every message:
+  Scan the message for mentions of people, companies, concepts, and original thinking.
+  For each entity, search the brain; load and update an existing page, or create a new page after the notability gate.
+  Detect and enrich alongside the response so the conversation is never blocked.
+
+```bash
+gbrain sync --no-pull --no-embed
+```
+
+### What counts as notable (( inert ))
 
 - People the user interacts with or discusses (not random mentions)
 - Companies relevant to the user's work or interests
@@ -99,7 +83,7 @@
 - The user's own original thinking (ideas, theses, observations) -- highest value
 - See `skills/_brain-filing-rules.md` for the full notability gate
 
-### What to capture from the user's own thinking
+### What to capture from the user's own thinking (( inert ))
 
 Original thinking is the most valuable signal. Capture exact phrasing -- the user's
 language IS the insight. Don't paraphrase.
@@ -110,12 +94,12 @@
 - Contrarian positions with reasoning
 - Strong reactions to external stimuli (what triggered it and why)
 
-## Media Workflows
+## Media Workflows (( inert ))
 
 Content the user encounters should be captured in the brain. File by PRIMARY
 SUBJECT, not by format (see `skills/_brain-filing-rules.md`).
 
-### Articles & Web Content
+### Articles & Web Content (( inert ))
 
 **Input:** URL shared by user, or article mentioned in conversation.
 
@@ -131,7 +115,7 @@
 **Write to:** appropriate directory per filing rules (about a person -> `people/`,
 about a company -> `companies/`, reusable framework -> `concepts/`, raw data -> `sources/`)
 
-### Videos & Podcasts
+### Videos & Podcasts (( inert ))
 
 **Input:** URL (YouTube, podcast, etc.) or local audio/video file.
 
@@ -154,7 +138,7 @@
 - Verbatim quotes with real speaker names (not "speaker_0")
 - All entities extracted with context and back-linked
 
-### PDFs & Documents
+### PDFs & Documents (( inert ))
 
 **Input:** File path or URL.
 
@@ -167,7 +151,7 @@
 
 **Write to:** per filing rules (file by primary subject, not format).
 
-### Screenshots & Images
+### Screenshots & Images (( inert ))
 
 **Input:** Image file.
 
@@ -179,7 +163,7 @@
 
 **Write to:** depends on content -- route to the appropriate workflow above.
 
-### Meeting Transcripts
+### Meeting Transcripts (( inert ))
 
 **Input:** Transcript from meeting recording service, or manual notes.
 
@@ -202,7 +186,7 @@
 - Names tension or what was left unsaid
 - Captures actual dynamic, not performative summary
 
-### Social Media Content
+### Social Media Content (( inert ))
 
 **Input:** Tweet, thread, or social media post.
 
@@ -216,39 +200,39 @@
 **Write to:** `media/x/` for daily aggregation, or entity-specific directories
 if the post is primarily about a person/company.
 
-## Raw Source Preservation
-
-Every ingested item must have its raw source preserved for provenance.
-
-**Use `gbrain files upload-raw` for automatic size routing:**
-```bash
-gbrain files upload-raw <file> --page <page-slug> --type <type>
-```
-
-- **< 100 MB text/PDF**: stays in git (brain repo `.raw/` sidecar directories)
-- **>= 100 MB OR media** (video, audio, images): uploaded to cloud storage
-  via TUS resumable upload, `.redirect.yaml` pointer left in the brain repo
-
-The `.redirect.yaml` pointer format:
-```yaml
-target: supabase://brain-files/page-slug/filename.mp4
-bucket: brain-files
-storage_path: page-slug/filename.mp4
-size: 524288000
-size_human: 500 MB
-hash: sha256:abc123...
-mime: video/mp4
-uploaded: 2026-04-11T...
-type: transcript
-```
-
-**Accessing stored files:**
-- `gbrain files signed-url <storage-path>` -- generate 1-hour signed URL for viewing/sharing
-- `gbrain files restore <dir>` -- download back to local from cloud storage
-
-Use `put_raw_data` in gbrain to store raw API responses and metadata (JSON, not binary).
-
-## Test Before Bulk
+## Raw Source Preservation (( role: procedure ))
+
+use judgment to follow the Raw Source Preservation guidance:
+  Every ingested item must have its raw source preserved for provenance.
+  
+  **Use `gbrain files upload-raw` for automatic size routing:**
+  ```bash
+  gbrain files upload-raw <file> --page <page-slug> --type <type>
+  ```
+  
+  item: **< 100 MB text/PDF**: stays in git (brain repo `.raw/` sidecar directories)
+  item: **>= 100 MB OR media** (video, audio, images): uploaded to cloud storage
+    via TUS resumable upload, `.redirect.yaml` pointer left in the brain repo
+  
+  The `.redirect.yaml` pointer format:
+  ```yaml
+  target: supabase://brain-files/page-slug/filename.mp4
+  bucket: brain-files
+  storage_path: page-slug/filename.mp4
+  size: 524288000
+  size_human: 500 MB
+  hash: sha256:abc123...
+  mime: video/mp4
+  uploaded: 2026-04-11T...
+  type: transcript
+  ```
+  
+  **Accessing stored files:**
+  item: `gbrain files signed-url <storage-path>` -- generate 1-hour signed URL for viewing/sharing
+  item: `gbrain files restore <dir>` -- download back to local from cloud storage
+  
+  Use `put_raw_data` in gbrain to store raw API responses and metadata (JSON, not binary).
+## Test Before Bulk (( inert ))
 
 When processing multiple items (batch video ingestion, bulk meeting processing, etc.):
 
@@ -262,7 +246,7 @@
 The marginal cost of testing 3 items first is near zero. The cost of cleaning
 up 100 bad pages is enormous.
 
-## Quality Rules
+## Quality Rules (( inert ))
 
 - Executive summary in compiled_truth must be updated, not just timeline appended
 - State section is REWRITTEN, not appended to. Current best understanding only.
@@ -273,13 +257,14 @@
 - Back-links: every entity mention creates a back-link (Iron Law)
 - Filing: file by primary subject, not format or source (see filing rules)
 
-## Anti-Patterns
-
-- **Appending to State sections.** State is rewritten with the current best understanding on every update. Append-only State sections grow stale and contradictory.
-- **Ingesting without back-links.** An unlinked mention is a broken brain. Every entity mentioned must have a back-link from their page to the page mentioning them.
-- **Skipping raw source preservation.** Every ingested item must have its raw source preserved. A brain page without provenance is unverifiable.
-- **Bulk processing without sample test.** Test on 3-5 items first. Fix quality issues in the approach, not via one-off patches.
-- **Paraphrasing the user's original thinking.** The user's exact language IS the insight. Capture verbatim phrasing for ideas, theses, and frameworks.
+## Anti-Patterns (( role: procedure ))
+
+!!! checklist (( ai-autonomy ))
+- [ ] **Appending to State sections.** State is rewritten with the current best understanding on every update. Append-only State sections grow stale and contradictory.
+- [ ] **Ingesting without back-links.** An unlinked mention is a broken brain. Every entity mentioned must have a back-link from their page to the page mentioning them.
+- [ ] **Skipping raw source preservation.** Every ingested item must have its raw source preserved. A brain page without provenance is unverifiable.
+- [ ] **Bulk processing without sample test.** Test on 3-5 items first. Fix quality issues in the approach, not via one-off patches.
+- [ ] **Paraphrasing the user's original thinking.** The user's exact language IS the insight. Capture verbatim phrasing for ideas, theses, and frameworks.
 
 ## Output Format
 
```
