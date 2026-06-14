# Deviation: archive_crawler.meri

- Original: `archive-crawler/SKILL.md`
- Ported: `archive_crawler.meri`
- Tier: 2 (light edits)
- Similarity: 54%
- Lines: 321 -> 324 (+149 / -146)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- shell-block-routed

## Metrics
- Sections: 11/22 inert (50% inert ratio)
- Operational inert: 0
- Unclassified inert: 0
- Inert categories: reference-documentation=10, template=1
- Judgment: 6 blocks, 68 lines

### Inert section details
- L12 `Safety gate (REQUIRED, no exceptions)`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L43 `What this is`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L52 `Concepts`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L163 `File-type handlers`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L165 `Plain text / HTML / Markdown`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L168 ``.mbox` (email archives)`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L212 ``.zip` / `.tar` / `.tar.gz``: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L216 `Images`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L221 `Manifest template`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L283 `Related skills`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L304 `Output Format`: template — Template/output shape is metadata unless explicit output assertions are authored.

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
@@ -66,109 +66,109 @@
 it interactively for review. Skips noise (system files, configs, binary
 blobs).
 
-## Concepts
-
-### Source
-
-A source is any tree of files to explore. Sources have:
-
-- **type**: `local` | `dropbox` | `backblaze` | `gmail-takeout` | `mbox` | `pst`
-- **root**: filesystem path, Dropbox path, B2 prefix, mbox path
-- **manifest**: a brain page tracking progress at
-  `projects/<archive-slug>/STATUS.md`
-
-### Manifest
-
-Every archive exploration gets a manifest brain page that tracks:
-
-1. **Tree inventory** — folders / files / sizes / types
-2. **Triage status** — each item: `⬜ unseen` / `👀 reviewed` /
-   `✅ ingested` / `⏭️ skip` / `🔥 high-signal`
-3. **User reactions** — exact quotes when they react (per
-   conventions/quality.md exact-phrasing rule)
-4. **Priority queue** — what to explore next, ranked
-5. **Session log** — timestamped record of what was shown per session
-
-### Gold filter
-
-Before showing anything to the user, apply the gold filter:
-
-| Keep (show) | Skip (note existence, don't show) |
-|-------------|-----------------------------------|
-| Personal writing (journals, letters, reflections, essays) | System files, configs, package.json, node_modules |
-| Conversations (IM logs, email threads with substance) | Binary blobs (images / video) |
-| Ideas, theses, frameworks | Receipts, invoices, tax docs |
-| Relationship material (letters to / from people who matter) | Spam, newsletters, mailing-list bulk |
-| Creative work (poetry, stories, code with soul) | Corrupted / null files |
-| Origin stories (first versions of things that became important) | |
-| Emotional content (anger, love, grief, discovery) | |
-
+## Concepts (( inert ))
+
+### Source (( role: procedure ))
+
+use judgment to follow the Source guidance:
+  A source is any tree of files to explore. Sources have:
+  
+  item: **type**: `local` | `dropbox` | `backblaze` | `gmail-takeout` | `mbox` | `pst`
+  item: **root**: filesystem path, Dropbox path, B2 prefix, mbox path
+  item: **manifest**: a brain page tracking progress at
+    `projects/<archive-slug>/STATUS.md`
+### Manifest (( role: procedure ))
+  
+use judgment to follow the Manifest guidance:
+  Every archive exploration gets a manifest brain page that tracks:
+  
+  1. **Tree inventory** — folders / files / sizes / types
+  2. **Triage status** — each item: `⬜ unseen` / `👀 reviewed` /
+     `✅ ingested` / `⏭️ skip` / `🔥 high-signal`
+  3. **User reactions** — exact quotes when they react (per
+     conventions/quality.md exact-phrasing rule)
+  4. **Priority queue** — what to explore next, ranked
+  5. **Session log** — timestamped record of what was shown per session
+### Gold filter (( role: procedure ))
+  
+use judgment to follow the Gold filter guidance:
+  Before showing anything to the user, apply the gold filter:
+  
+  | Keep (show) | Skip (note existence, don't show) |
+  |-------------|-----------------------------------|
+  | Personal writing (journals, letters, reflections, essays) | System files, configs, package.json, node_modules |
+  | Conversations (IM logs, email threads with substance) | Binary blobs (images / video) |
+  | Ideas, theses, frameworks | Receipts, invoices, tax docs |
+  | Relationship material (letters to / from people who matter) | Spam, newsletters, mailing-list bulk |
+  | Creative work (poetry, stories, code with soul) | Corrupted / null files |
+  | Origin stories (first versions of things that became important) | |
+  | Emotional content (anger, love, grief, discovery) | |
 ## Protocol
 
-### Phase 1: Inventory
-
-When pointed at a new source:
-
-1. **Confirm scan_paths is set** (safety gate). Exit if not.
-2. **Map the tree** — list folders + files + sizes + date ranges.
-3. **Classify folders** — group by likely content type (writing, email,
-   code, photos, docs, system).
-4. **Create manifest** — write `projects/<archive-slug>/STATUS.md` with
-   the full inventory.
-5. **Propose priority queue** — rank folders by likely gold density.
-6. **Present to user** — show the map and proposed order. Let them
-   override.
-
-### Phase 2: Crawl
-
-Work through folders in priority order:
-
-1. **Read before showing** — open each candidate file, apply the gold
-   filter, skip noise.
-2. **Show one at a time** — present gold items individually for review.
-3. **Capture exact reaction** — track the user's response in the
-   manifest using their exact words (per conventions/quality.md).
-4. **Ingest if worth keeping** — create a brain page immediately.
-5. **Update manifest** — mark item status after each interaction.
-6. **Never re-show** — check the manifest before presenting anything.
-
-### Phase 3: Ingest
-
-When an item is worth keeping, file it by **primary subject** per
-`_brain-filing-rules.md`:
-
-- User's own writing / ideas / origin-story content → `originals/<slug>.md`
-- Reflections / personal-life content → `personal/<slug>.md`
-- Product / business ideas → `ideas/<slug>.md`
-- Letters or threads about a specific person → `people/<person>/timeline`
-  back-link plus the letter at `personal/<slug>.md` or `originals/<slug>.md`
-
-**The skill is schema-generic.** It does NOT bake in any specific
-era-folder structure (e.g., `originals/archive/` for pre-2003,
-`originals/yc-era/` for post-2019, etc.). The user's filing rules from
-`_brain-filing-rules.json` are read at runtime; the agent decides per-page
-where content lands within those sanctioned directories.
-
-Brain page format:
-
-```markdown
----
-title: "[Title or first line]"
-type: original
-source_type: "[local|dropbox|backblaze|gmail-takeout|mbox|pst]"
-source_path: "[path within the allow-listed scan_paths]"
-date: "YYYY-MM-DD"  # date from the file metadata or content
-people: ["person-1", "person-2"]
-tags: ["tag-1", "tag-2"]
----
-
-# [Title]
-
-[Summary: what it is, when it's from, why it matters]
-
-**User's reaction:** [exact quote, no paraphrasing]
-
-## Context
+### Phase 1: Inventory (( role: procedure ))
+
+use judgment to follow the Phase 1: Inventory guidance:
+  When pointed at a new source:
+  
+  1. **Confirm scan_paths is set** (safety gate). Exit if not.
+  2. **Map the tree** — list folders + files + sizes + date ranges.
+  3. **Classify folders** — group by likely content type (writing, email,
+     code, photos, docs, system).
+  4. **Create manifest** — write `projects/<archive-slug>/STATUS.md` with
+     the full inventory.
+  5. **Propose priority queue** — rank folders by likely gold density.
+  6. **Present to user** — show the map and proposed order. Let them
+     override.
+### Phase 2: Crawl (( role: procedure ))
+  
+use judgment to follow the Phase 2: Crawl guidance:
+  Work through folders in priority order:
+  
+  1. **Read before showing** — open each candidate file, apply the gold
+     filter, skip noise.
+  2. **Show one at a time** — present gold items individually for review.
+  3. **Capture exact reaction** — track the user's response in the
+     manifest using their exact words (per conventions/quality.md).
+  4. **Ingest if worth keeping** — create a brain page immediately.
+  5. **Update manifest** — mark item status after each interaction.
+  6. **Never re-show** — check the manifest before presenting anything.
+### Phase 3: Ingest (( role: procedure ))
+  
+use judgment to follow the Phase 3: Ingest guidance:
+  When an item is worth keeping, file it by **primary subject** per
+  `_brain-filing-rules.md`:
+  
+  item: User's own writing / ideas / origin-story content → `originals/<slug>.md`
+  item: Reflections / personal-life content → `personal/<slug>.md`
+  item: Product / business ideas → `ideas/<slug>.md`
+  item: Letters or threads about a specific person → `people/<person>/timeline`
+    back-link plus the letter at `personal/<slug>.md` or `originals/<slug>.md`
+  
+  **The skill is schema-generic.** It does NOT bake in any specific
+  era-folder structure (e.g., `originals/archive/` for pre-2003,
+  `originals/yc-era/` for post-2019, etc.). The user's filing rules from
+  `_brain-filing-rules.json` are read at runtime; the agent decides per-page
+  where content lands within those sanctioned directories.
+  
+  Brain page format:
+  
+  ```markdown
+  ---
+  title: "[Title or first line]"
+  type: original
+  source_type: "[local|dropbox|backblaze|gmail-takeout|mbox|pst]"
+  source_path: "[path within the allow-listed scan_paths]"
+  date: "YYYY-MM-DD"  # date from the file metadata or content
+  people: ["person-1", "person-2"]
+  tags: ["tag-1", "tag-2"]
+  ---
+  
+  # [Title]
+  
+  [Summary: what it is, when it's from, why it matters]
+  
+  **User's reaction:** [exact quote, no paraphrasing]
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
@@ -199,7 +199,7 @@
     # Apply gold filter
 ```
 
-### `.doc` / `.docx`
+### `.doc` / `.docx` (( role: procedure ))
 
 ```bash
 # .docx (modern)
@@ -214,7 +214,7 @@
 antiword /path/to/file.doc 2>/dev/null || catdoc /path/to/file.doc 2>/dev/null
 ```
 
-### `.pst` (Outlook archives)
+### `.pst` (Outlook archives) (( role: procedure ))
 
 ```bash
 # Validate first; many PSTs are null bytes
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
@@ -249,53 +249,55 @@
 
 # [Archive Name] — Ingestion Status
 
-## Source
-- **Type:** [local|dropbox|...]
-- **Allow-listed paths:** [from gbrain.yml]
-- **Total files:** [N]
-- **Total size:** [X GB]
-- **Date range:** [earliest] — [latest]
-
-## Inventory
-
-### [Folder 1]
+## Source (( role: procedure ))
+
+use judgment to follow the Source guidance:
+  item: **Type:** [local|dropbox|...]
+  item: **Allow-listed paths:** [from gbrain.yml]
+  item: **Total files:** [N]
+  item: **Total size:** [X GB]
+  item: **Date range:** [earliest] — [latest]
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
-
-- ❌ Running without `archive-crawler.scan_paths:` set. Hard refusal.
+## Anti-Patterns (( role: procedure ))
+
+!!! checklist (( ai-autonomy ))
+- [ ] ❌ Running without `archive-crawler.scan_paths:` set. Hard refusal.
   This is the safety contract — never bypass.
-- ❌ Hardcoding era-specific filing paths (e.g., `originals/archive/`,
+- [ ] ❌ Hardcoding era-specific filing paths (e.g., `originals/archive/`,
   `originals/yc-era/`). Read filing rules at runtime instead.
-- ❌ Re-showing items already marked in the manifest. The user's time
+- [ ] ❌ Re-showing items already marked in the manifest. The user's time
   is the scarcest resource.
-- ❌ Paraphrasing reactions. Exact words only.
-- ❌ Wrapping found content in lessons or takeaways. Let stories breathe.
-- ❌ Skipping back-links when content references people / companies who
+- [ ] ❌ Paraphrasing reactions. Exact words only.
+- [ ] ❌ Wrapping found content in lessons or takeaways. Let stories breathe.
+- [ ] ❌ Skipping back-links when content references people / companies who
   have brain pages. Iron Law per conventions/quality.md.
 
-## Related skills
+## Related skills (( inert ))
 
 - `skills/voice-note-ingest/SKILL.md` — same exact-phrasing pattern for
   audio capture
@@ -304,16 +306,17 @@
 - `skills/conventions/quality.md` — citations, back-links, voice
 
 
-## Contract
-
-This skill guarantees:
-
-- Routing matches the canonical triggers in the frontmatter.
-- Output written under the directories listed in `writes_to:` (when applicable).
-- Conventions referenced (`quality.md`, `brain-first.md`, `_brain-filing-rules.md`) are followed.
-- Privacy contract preserved: no real names, no fork-specific filesystem path literals, no upstream-fork references.
-
-The full behavior contract is documented in the body sections above; this section exists for the conformance test.
+## Contract (( role: procedure ))
+
+> This skill guarantees:
+
+!!! checklist (( ai-autonomy ))
+- [ ] Routing matches the canonical triggers in the frontmatter.
+- [ ] Output written under the directories listed in `writes_to:` (when applicable).
+- [ ] Conventions referenced (`quality.md`, `brain-first.md`, `_brain-filing-rules.md`) are followed.
+- [ ] Privacy contract preserved: no real names, no fork-specific filesystem path literals, no upstream-fork references.
+
+> The full behavior contract is documented in the body sections above; this section exists for the conformance test.
 
 ## Output Format
 
```
