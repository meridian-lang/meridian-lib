# Deviation: ingest.meri

- Original: `ingest/SKILL.md`
- Ported: `ingest.meri`
- Tier: 1 (near-verbatim)
- Similarity: 88%
- Lines: 312 -> 337 (+53 / -28)

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
- L49 `Entity Detection on Every Message`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L105 `Articles & Web Content`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L145 `PDFs & Documents`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L158 `Screenshots & Images`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L251 `Test Before Bulk`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L286 `Output Format`: template - Template/output shape is metadata unless explicit output assertions are authored.
- L304 `Tools Used`: tools-metadata - Tools sections are metadata-mining, not workflow execution.

## Metrics
- Sections inert total: 7/19 (37% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert categories: reference-documentation=5, template=1, tools-metadata=1
- Judgment: 10 blocks, 0 lines

### Inert section details
- L49 `Entity Detection on Every Message`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L105 `Articles & Web Content`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L145 `PDFs & Documents`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L158 `Screenshots & Images`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L251 `Test Before Bulk`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L286 `Output Format`: template — Template/output shape is metadata unless explicit output assertions are authored.
- L304 `Tools Used`: tools-metadata — Tools sections are metadata-mining, not workflow execution.

## Unified diff

```diff
--- original-skills/ingest/SKILL.md
+++ skills/ingest.meri
@@ -24,11 +24,12 @@
 
 # Ingest Skill
 
-Ingest meetings, articles, media, documents, and conversations into the brain.
+> Ingest meetings, articles, media, documents, and conversations into the brain.
 
 > **Filing rule:** Read `skills/_brain-filing-rules.md` before creating any new page.
 
-## Contract
+## Contract (( role: procedure ))
+use judgment to follow the Contract guidance:
 
 - Every fact written to a brain page carries an inline `[Source: ...]` citation with date and provenance.
 - Every entity mention creates a back-link from the entity's page to the page mentioning them (Iron Law).
@@ -54,6 +55,7 @@
 - **Synthesis:** `[Source: compiled from {sources}]`
 
 ## Phases
+use judgment to follow the Phases guidance:
 
 > **Router note:** This skill is a router. For specialized ingestion, see: idea-ingest, media-ingest, meeting-ingestion.
 
@@ -67,30 +69,34 @@
 5. **Back-link all entities.** Update EVERY mentioned entity's page with a back-link to this page (Iron Law).
 6. **Timeline merge.** The same event appears on ALL mentioned entities' timelines. If Alice met Bob at Acme Corp, the event goes on Alice's page, Bob's page, and Acme Corp's page.
 
-## Entity Detection on Every Message
+## Entity Detection on Every Message (( inert ))
 
 Production agents should detect entity mentions on EVERY inbound message. This is
 the signal detection loop that makes the brain compound over time.
 
 ### Protocol
+use judgment to follow the Protocol guidance:
 
 1. **Scan the message** for entity mentions: people, companies, concepts, original
    thinking. Fire on every message (no exceptions unless purely operational).
-2. **For each entity detected:**
+4. **Don't block the conversation.** Entity detection and enrichment should happen
+   alongside the response, not before it. The user shouldn't wait for brain writes
+   to get an answer.
+
+
+#### Protocol — steps
+
+2. For each entity detected:
    - `gbrain search "name"` -- does a page already exist?
-   - **If yes:** load context with `gbrain get <slug>`. Use the compiled truth to
+   - If yes: load context with `gbrain get <slug>`. Use the compiled truth to
      inform your response. Update the page if the message contains new information.
-   - **If no:** assess notability (see `skills/_brain-filing-rules.md`). If the entity
+   - If no: assess notability (see `skills/_brain-filing-rules.md`). If the entity
      is worth tracking, create a new page with `gbrain put <type/slug>` and populate
      with what you know.
-3. **After creating or updating pages:** sync to gbrain:
+> 3. **After creating or updating pages:** sync to gbrain:
    ```bash
    gbrain sync --no-pull --no-embed
    ```
-4. **Don't block the conversation.** Entity detection and enrichment should happen
-   alongside the response, not before it. The user shouldn't wait for brain writes
-   to get an answer.
-
 ### What counts as notable
 
 - People the user interacts with or discusses (not random mentions)
@@ -100,6 +106,7 @@
 - See `skills/_brain-filing-rules.md` for the full notability gate
 
 ### What to capture from the user's own thinking
+use judgment to follow the What to capture from the user's own thinking guidance:
 
 Original thinking is the most valuable signal. Capture exact phrasing -- the user's
 language IS the insight. Don't paraphrase.
@@ -110,12 +117,15 @@
 - Contrarian positions with reasoning
 - Strong reactions to external stimuli (what triggered it and why)
 
-## Media Workflows
+## Media Workflows (( inert ))
+
+
+### Media Workflows — steps
 
 Content the user encounters should be captured in the brain. File by PRIMARY
 SUBJECT, not by format (see `skills/_brain-filing-rules.md`).
 
-### Articles & Web Content
+### Articles & Web Content (( inert ))
 
 **Input:** URL shared by user, or article mentioned in conversation.
 
@@ -132,6 +142,7 @@
 about a company -> `companies/`, reusable framework -> `concepts/`, raw data -> `sources/`)
 
 ### Videos & Podcasts
+use judgment to follow the Videos & Podcasts guidance:
 
 **Input:** URL (YouTube, podcast, etc.) or local audio/video file.
 
@@ -154,7 +165,7 @@
 - Verbatim quotes with real speaker names (not "speaker_0")
 - All entities extracted with context and back-linked
 
-### PDFs & Documents
+### PDFs & Documents (( inert ))
 
 **Input:** File path or URL.
 
@@ -167,7 +178,7 @@
 
 **Write to:** per filing rules (file by primary subject, not format).
 
-### Screenshots & Images
+### Screenshots & Images (( inert ))
 
 **Input:** Image file.
 
@@ -180,6 +191,7 @@
 **Write to:** depends on content -- route to the appropriate workflow above.
 
 ### Meeting Transcripts
+use judgment to follow the Meeting Transcripts guidance:
 
 **Input:** Transcript from meeting recording service, or manual notes.
 
@@ -203,6 +215,7 @@
 - Captures actual dynamic, not performative summary
 
 ### Social Media Content
+use judgment to follow the Social Media Content guidance:
 
 **Input:** Tweet, thread, or social media post.
 
@@ -217,19 +230,13 @@
 if the post is primarily about a person/company.
 
 ## Raw Source Preservation
+use judgment to follow the Raw Source Preservation guidance:
 
 Every ingested item must have its raw source preserved for provenance.
 
-**Use `gbrain files upload-raw` for automatic size routing:**
-```bash
-gbrain files upload-raw <file> --page <page-slug> --type <type>
-```
-
-- **< 100 MB text/PDF**: stays in git (brain repo `.raw/` sidecar directories)
 - **>= 100 MB OR media** (video, audio, images): uploaded to cloud storage
   via TUS resumable upload, `.redirect.yaml` pointer left in the brain repo
 
-The `.redirect.yaml` pointer format:
 ```yaml
 target: supabase://brain-files/page-slug/filename.mp4
 bucket: brain-files
@@ -242,13 +249,29 @@
 type: transcript
 ```
 
-**Accessing stored files:**
+Use `put_raw_data` in gbrain to store raw API responses and metadata (JSON, not binary).
+
+
+### Raw Source Preservation — steps
+
+Use `gbrain files upload-raw` for automatic size routing:
+```bash
+gbrain files upload-raw <file> --page <page-slug> --type <type>
+```
+
+- < 100 MB text/PDF: stays in git (brain repo `.raw/` sidecar directories)
+
+### Raw Source Preservation — steps 2
+
+The `.redirect.yaml` pointer format:
+
+### Raw Source Preservation — steps 3
+
+> **Accessing stored files:**
 - `gbrain files signed-url <storage-path>` -- generate 1-hour signed URL for viewing/sharing
 - `gbrain files restore <dir>` -- download back to local from cloud storage
 
-Use `put_raw_data` in gbrain to store raw API responses and metadata (JSON, not binary).
-
-## Test Before Bulk
+## Test Before Bulk (( inert ))
 
 When processing multiple items (batch video ingestion, bulk meeting processing, etc.):
 
@@ -262,7 +285,8 @@
 The marginal cost of testing 3 items first is near zero. The cost of cleaning
 up 100 bad pages is enormous.
 
-## Quality Rules
+## Quality Rules (( role: procedure ))
+use judgment to follow the Quality Rules guidance:
 
 - Executive summary in compiled_truth must be updated, not just timeline appended
 - State section is REWRITTEN, not appended to. Current best understanding only.
@@ -273,7 +297,8 @@
 - Back-links: every entity mention creates a back-link (Iron Law)
 - Filing: file by primary subject, not format or source (see filing rules)
 
-## Anti-Patterns
+## Anti-Patterns (( role: procedure ))
+use judgment to follow the Anti-Patterns guidance:
 
 - **Appending to State sections.** State is rewritten with the current best understanding on every update. Append-only State sections grow stale and contradictory.
 - **Ingesting without back-links.** An unlinked mention is a broken brain. Every entity mentioned must have a back-link from their page to the page mentioning them.
```
