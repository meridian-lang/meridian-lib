# Deviation: archive_crawler.meri

- Original: `archive-crawler/SKILL.md`
- Ported: `archive_crawler.meri`
- Tier: 1 (near-verbatim)
- Similarity: 90%
- Lines: 321 -> 321 (+33 / -33)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added

## Metrics
- Sections: 20/22 inert (91% inert ratio)
- Operational inert: 7
- Unclassified inert: 0
- Inert categories: normative-contract=1, operational-content=2, operational-procedure=4, reference-documentation=12, template=1
- Judgment: 0 blocks, 0 lines

### Inert section details
- L12 `Safety gate (REQUIRED, no exceptions)`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L43 `What this is`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L52 `Concepts`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L54 `Source`: operational-content — Body contains command, table, checklist, or explicit AI-routing surface.
- L63 `Manifest`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L75 `Gold filter`: operational-content — Body contains command, table, checklist, or explicit AI-routing surface.
- L89 `Protocol`: operational-procedure — Marked or derived as procedure, but inert suppresses execution.
- L91 `Phase 1: Inventory`: operational-procedure — Marked or derived as procedure, but inert suppresses execution.
- L105 `Phase 2: Crawl`: operational-procedure — Marked or derived as procedure, but inert suppresses execution.
- L118 `Phase 3: Ingest`: operational-procedure — Marked or derived as procedure, but inert suppresses execution.
- L163 `File-type handlers`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L165 `Plain text / HTML / Markdown`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L168 ``.mbox` (email archives)`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L212 ``.zip` / `.tar` / `.tar.gz``: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L216 `Images`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L221 `Manifest template`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L268 `Anti-Patterns`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L281 `Related skills`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L290 `Contract`: normative-contract — Normative invariants prose needs mining into assertions or explicit AI routing.
- L301 `Output Format`: template — Template/output shape is metadata unless explicit output assertions are authored.

## Unified diff

```diff
--- original-skills/archive-crawler/SKILL.md
+++ skills/archive_crawler.meri
@@ -26,7 +26,7 @@
 > this skill is **schema-generic**: it reads the user's filing rules from
 > the rules JSON instead of hardcoding any specific era / archive layout.
 
-## Safety gate (REQUIRED, no exceptions)
+## Safety gate (REQUIRED, no exceptions) (( inert ))
 
 archive-crawler refuses to run unless `archive-crawler.scan_paths:` is
 explicitly set in `gbrain.yml`. This is a deliberate safety fence against
@@ -57,7 +57,7 @@
 This contract is enforced by `src/core/storage-config.ts` (mirrors the
 `db_tracked` / `db_only` allow-list pattern from v0.22.11 storage tiering).
 
-## What this is
+## What this is (( inert ))
 
 Generic engine for exploring any tree of personal content within an
 explicit allow-list. Works on local mounts, Dropbox API targets,
@@ -66,9 +66,9 @@
 it interactively for review. Skips noise (system files, configs, binary
 blobs).
 
-## Concepts
-
-### Source
+## Concepts (( inert ))
+
+### Source (( inert ))
 
 A source is any tree of files to explore. Sources have:
 
@@ -77,7 +77,7 @@
 - **manifest**: a brain page tracking progress at
   `projects/<archive-slug>/STATUS.md`
 
-### Manifest
+### Manifest (( inert ))
 
 Every archive exploration gets a manifest brain page that tracks:
 
@@ -89,7 +89,7 @@
 4. **Priority queue** — what to explore next, ranked
 5. **Session log** — timestamped record of what was shown per session
 
-### Gold filter
+### Gold filter (( inert ))
 
 Before showing anything to the user, apply the gold filter:
 
@@ -103,9 +103,9 @@
 | Origin stories (first versions of things that became important) | |
 | Emotional content (anger, love, grief, discovery) | |
 
-## Protocol
-
-### Phase 1: Inventory
+## Protocol (( inert, role: procedure ))
+
+### Phase 1: Inventory (( inert, role: procedure ))
 
 When pointed at a new source:
 
@@ -119,7 +119,7 @@
 6. **Present to user** — show the map and proposed order. Let them
    override.
 
-### Phase 2: Crawl
+### Phase 2: Crawl (( inert, role: procedure ))
 
 Work through folders in priority order:
 
@@ -132,7 +132,7 @@
 5. **Update manifest** — mark item status after each interaction.
 6. **Never re-show** — check the manifest before presenting anything.
 
-### Phase 3: Ingest
+### Phase 3: Ingest (( inert, role: procedure ))
 
 When an item is worth keeping, file it by **primary subject** per
 `_brain-filing-rules.md`:
@@ -168,7 +168,7 @@
 
 **User's reaction:** [exact quote, no paraphrasing]
 
-## Context
+## Context (( inert ))
 
 [Cross-links to people, concepts, projects.]
 
@@ -177,12 +177,12 @@
 [Raw source material below the line — full text]
 ```
 
-## File-type handlers
-
-### Plain text / HTML / Markdown
+## File-type handlers (( inert ))
+
+### Plain text / HTML / Markdown (( inert ))
 Read directly. Strip HTML tags for display.
 
-### `.mbox` (email archives)
+### `.mbox` (email archives) (( inert ))
 
 ```python
 import mailbox
@@ -226,16 +226,16 @@
 readpst -o /tmp/pst-output /path/to/file.pst
 ```
 
-### `.zip` / `.tar` / `.tar.gz`
+### `.zip` / `.tar` / `.tar.gz` (( inert ))
 
 Extract to a temp dir, then recurse through the extracted tree.
 
-### Images
+### Images (( inert ))
 
 Note existence + metadata (filename, size, date). Don't show unless the
 user asks. Flag scans / portraits as potentially personal.
 
-## Manifest template
+## Manifest template (( inert ))
 
 ```markdown
 ---
@@ -249,40 +249,40 @@
 
 # [Archive Name] — Ingestion Status
 
-## Source
+## Source (( inert ))
 - **Type:** [local|dropbox|...]
 - **Allow-listed paths:** [from gbrain.yml]
 - **Total files:** [N]
 - **Total size:** [X GB]
 - **Date range:** [earliest] — [latest]
 
-## Inventory
-
-### [Folder 1]
+## Inventory (( inert ))
+
+### [Folder 1] (( inert ))
 | Item | Type | Size | Status | Reaction |
 |------|------|------|--------|----------|
 | file1.txt | text | 2KB | ✅ ingested | 🔥 "exact quote" |
 | file2.doc | doc | 15KB | ⏭️ skip | — |
 | file3.html | html | 4KB | ⬜ unseen | — |
 
-### [Folder 2]
+### [Folder 2] (( inert ))
 ...
 
-## Priority Queue
+## Priority Queue (( inert ))
 1. [Highest priority — why]
 2. [Next — why]
 ...
 
-## Session Log
-
-### YYYY-MM-DD — [Session topic]
+## Session Log (( inert ))
+
+### YYYY-MM-DD — [Session topic] (( inert ))
 - Reviewed: [list]
 - Reactions: [exact quotes]
 - Ingested: [brain pages created]
 - Next: [what's queued]
 ```
 
-## Anti-Patterns
+## Anti-Patterns (( inert, role: prohibitions ))
 
 - ❌ Running without `archive-crawler.scan_paths:` set. Hard refusal.
   This is the safety contract — never bypass.
@@ -295,7 +295,7 @@
 - ❌ Skipping back-links when content references people / companies who
   have brain pages. Iron Law per conventions/quality.md.
 
-## Related skills
+## Related skills (( inert ))
 
 - `skills/voice-note-ingest/SKILL.md` — same exact-phrasing pattern for
   audio capture
@@ -304,7 +304,7 @@
 - `skills/conventions/quality.md` — citations, back-links, voice
 
 
-## Contract
+## Contract (( inert, role: invariants ))
 
 This skill guarantees:
 
@@ -315,7 +315,7 @@
 
 The full behavior contract is documented in the body sections above; this section exists for the conformance test.
 
-## Output Format
+## Output Format (( inert, role: template ))
 
 The skill's output shape is documented inline in the body sections above (see "Output", "Brain page format", or equivalent). The literal section header here exists for the conformance test (`test/skills-conformance.test.ts`).
 
```
