# Deviation: eiirp.meri

- Original: `eiirp/SKILL.md`
- Ported: `eiirp.meri`
- Tier: 2 (light edits)
- Similarity: 59%
- Lines: 395 -> 400 (+165 / -160)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- shell-block-routed

## Metrics
- Sections: 14/26 inert (54% inert ratio)
- Operational inert: 0
- Unclassified inert: 0
- Inert categories: reference-documentation=13, template=1
- Judgment: 5 blocks, 70 lines

### Inert section details
- L33 `Phase 1: INVENTORY — What did we produce?`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L37 `Knowledge outputs`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L46 `Capability outputs`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L128 `4a. Primary research page`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L137 `4b. Entity pages (people, companies)`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L143 `4c. Commit and verify`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L174 `5b. Existing skill audit`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L182 `5c. Present the plan`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L252 `Output Format`: template — Template/output shape is metadata unless explicit output assertions are authored.
- L302 `Hard Rules`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L304 `Knowledge domain`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L311 `Capability domain`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L317 `Meta`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L321 `Changelog`: reference-documentation — Reference documentation, rationale, examples, or changelog.

## Unified diff

```diff
--- original-skills/eiirp/SKILL.md
+++ skills/eiirp.meri
@@ -68,23 +68,23 @@
 
 > *"Everything in its right place"* — Radiohead, Kid A
 
-## Contract
-
-After any significant work, EIIRP organizes ALL outputs across two domains:
-
-**Knowledge domain (brain):**
-1. Every piece of knowledge lands in the correct brain location.
-2. All sources are cited and linked.
-3. The active schema pack is updated if a new content type emerged.
-4. Entity pages created/updated with cross-links.
-
-**Capability domain (skills):**
-5. Every reusable pattern becomes a composable skill.
-6. Existing skills are audited for DRY violations.
-7. Skill graph is MECE — no gaps, no overlaps, no ambiguous routing.
-
-**The meta-guarantee:** Nothing produced during significant work lives only in chat.
-Knowledge → brain. Patterns → skills. Everything in its right place.
+## Contract (( role: procedure ))
+
+> After any significant work, EIIRP organizes ALL outputs across two domains:
+
+> **Knowledge domain (brain):**
+> 1. Every piece of knowledge lands in the correct brain location.
+> 2. All sources are cited and linked.
+> 3. The active schema pack is updated if a new content type emerged.
+> 4. Entity pages created/updated with cross-links.
+
+> **Capability domain (skills):**
+> 5. Every reusable pattern becomes a composable skill.
+> 6. Existing skills are audited for DRY violations.
+> 7. Skill graph is MECE — no gaps, no overlaps, no ambiguous routing.
+
+> **The meta-guarantee:** Nothing produced during significant work lives only in chat.
+> Knowledge → brain. Patterns → skills. Everything in its right place.
 
 ## When to Use
 
@@ -95,11 +95,11 @@
 - When a work session produced both knowledge AND new capabilities.
 - When you notice skill overlap, duplication, or gaps.
 
-## Phase 1: INVENTORY — What did we produce?
+## Phase 1: INVENTORY — What did we produce? (( inert, role: procedure ))
 
 Scan the current session/thread and identify ALL outputs across both domains.
 
-### Knowledge outputs
+### Knowledge outputs (( inert ))
 ```
 □ Primary findings (the synthesis)
 □ Source documents (URLs, PDFs, articles, tweets)
@@ -108,7 +108,7 @@
 □ Data artifacts (structured data, timelines, statistics)
 ```
 
-### Capability outputs
+### Capability outputs (( inert ))
 ```
 □ New skills created or modified
 □ Scripts/code written (should they be in lib/ or scripts/?)
@@ -120,7 +120,7 @@
 Produce a manifest:
 
 ```markdown
-## EIIRP Manifest
+## EIIRP Manifest (( inert ))
 - Topic: [topic]
 - Date: [date]
 - Knowledge outputs: [count] (sources, entities, concepts)
@@ -128,69 +128,69 @@
 - Reusable methodology: [yes/no — describe if yes]
 ```
 
-## Phase 2: TAXONOMY — Where does each piece go?
-
-**Read the active schema pack first** (the single source of truth for
-filing decisions in v0.39+):
-
-```bash
-gbrain schema show --json
-```
-
-The pack's `page_types[]` lists every directory the brain accepts plus
-the primitive each maps to. Walk it for each output and pick the directory
-whose `path_prefixes` matches the content's primary subject.
-
-If `brain-taxonomist` is installed, INVOKE IT for ambiguous cases. It runs
-the same decision protocol against the active pack and gives you a single
-recommended filing path with reasoning.
-
-Output: a filing plan table:
-
-```
-| Content | Brain path | Action |
-|---------|-----------|--------|
-| Primary research | reference/.../page.md | CREATE |
-| Person X | people/x-slug.md | CREATE |
-| Person Y | people/y-slug.md | UPDATE (already exists) |
-| ... | ... | ... |
-```
-
-## Phase 3: SCHEMA CHECK — Does the active pack cover this content?
-
-This is where EIIRP closes the schema-derivation loop. If the work
-produced content that doesn't fit any existing `page_types`, propose
-adding a new type via the v0.39 cathedral:
-
-```bash
-# What's emerging in the brain that the active pack doesn't cover?
-gbrain schema detect --json
-
-# LLM-refined suggestions (heuristic when no API key set).
-gbrain schema suggest --json
-
-# Review what's pending; promote or ignore each candidate.
-gbrain schema review-candidates --json
-gbrain schema review-candidates --apply <prefix-or-type-name>
-```
-
-**Confidence floor (codex finding #9):** when `gbrain schema suggest`
-returns confidence < 0.6 on a proposed type, DO NOT auto-apply. Surface
-the suggestion to the user and let them choose. The schema-cathedral
-ships the primitives; EIIRP enforces the human-in-the-loop gate.
-
-If schema needs change:
-- Propose the addition to the user before running `review-candidates --apply`.
-- Document the change in the commit message of the next sync.
-- The schema-pack engine writes the delta to
-  `~/.gbrain/schema-pack-deltas/` — review and merge into the active
-  pack via `gbrain schema edit` (or hand-edit the YAML).
-
+## Phase 2: TAXONOMY — Where does each piece go? (( role: procedure ))
+
+use judgment to follow the Phase 2: TAXONOMY — Where does each piece go? guidance:
+  **Read the active schema pack first** (the single source of truth for
+  filing decisions in v0.39+):
+  
+  ```bash
+  gbrain schema show --json
+  ```
+  
+  The pack's `page_types[]` lists every directory the brain accepts plus
+  the primitive each maps to. Walk it for each output and pick the directory
+  whose `path_prefixes` matches the content's primary subject.
+  
+  If `brain-taxonomist` is installed, INVOKE IT for ambiguous cases. It runs
+  the same decision protocol against the active pack and gives you a single
+  recommended filing path with reasoning.
+  
+  Output: a filing plan table:
+  
+  ```
+  | Content | Brain path | Action |
+  |---------|-----------|--------|
+  | Primary research | reference/.../page.md | CREATE |
+  | Person X | people/x-slug.md | CREATE |
+  | Person Y | people/y-slug.md | UPDATE (already exists) |
+  | ... | ... | ... |
+  ```
+## Phase 3: SCHEMA CHECK — Does the active pack cover this content? (( role: procedure ))
+
+use judgment to follow the Phase 3: SCHEMA CHECK — Does the active pack cover this content? guidance:
+  This is where EIIRP closes the schema-derivation loop. If the work
+  produced content that doesn't fit any existing `page_types`, propose
+  adding a new type via the v0.39 cathedral:
+  
+  ```bash
+  # What's emerging in the brain that the active pack doesn't cover?
+  gbrain schema detect --json
+  
+  # LLM-refined suggestions (heuristic when no API key set).
+  gbrain schema suggest --json
+  
+  # Review what's pending; promote or ignore each candidate.
+  gbrain schema review-candidates --json
+  gbrain schema review-candidates --apply <prefix-or-type-name>
+  ```
+  
+  **Confidence floor (codex finding #9):** when `gbrain schema suggest`
+  returns confidence < 0.6 on a proposed type, DO NOT auto-apply. Surface
+  the suggestion to the user and let them choose. The schema-cathedral
+  ships the primitives; EIIRP enforces the human-in-the-loop gate.
+  
+  If schema needs change:
+  item: Propose the addition to the user before running `review-candidates --apply`.
+  item: Document the change in the commit message of the next sync.
+  item: The schema-pack engine writes the delta to
+    `~/.gbrain/schema-pack-deltas/` — review and merge into the active
+    pack via `gbrain schema edit` (or hand-edit the YAML).
 ## Phase 4: FILE — Create enriched brain pages
 
 For each item in the filing plan:
 
-### 4a. Primary research page
+### 4a. Primary research page (( inert ))
 Use the brain page template. MUST include:
 - Proper frontmatter (`type`, `title`, `date`, `tags`, sources)
 - **State** section — current status/key findings
@@ -199,67 +199,67 @@
 - **Entity links** — backlinks to all related brain pages
 - **See Also** — related concepts, reference pages
 
-### 4b. Entity pages (people, companies)
+### 4b. Entity pages (people, companies) (( inert ))
 For each entity mentioned:
 - Check if a brain page exists (`gbrain search "<name>"` or `gbrain get_page people/<slug>`).
 - If exists: update State, append Timeline entry citing this research.
 - If not: create with enrichment.
 
-### 4c. Commit and verify
+### 4c. Commit and verify (( inert ))
 After ALL pages are written, run `gbrain sync` (or commit + push in the
 brain repo). Verify every link resolves.
 
-## Phase 5: SKILL GRAPH AUDIT — DRY + MECE on capabilities
-
-This phase operates on the SKILL graph, not just the research.
-
-### 5a. New pattern identification
-
-Ask: did this work reveal REPEATABLE patterns that will recur?
-
-**Indicators of a reusable pattern:**
-- You used a specific sequence of searches across multiple sources.
-- You followed a specific verification/cross-referencing methodology.
-- You wrote code that could be parameterized for different inputs.
-- The output format is generalizable.
-- The user is likely to ask for similar work on a different topic.
-
-**For each identified pattern:**
-1. Identify the composable pieces (DRY, MECE):
-   - Shared logic → `lib/` (not copy-pasted into skills)
-   - Search methodology → skill or lib function
-   - Output template → brain template or skill phase
-   - Filing logic → already covered by brain-taxonomist + active pack
-2. DRY check via the v0.19 resolver:
-   ```bash
-   gbrain check-resolvable
-   ```
-   Look for overlapping triggers or unreachable skills.
-
-### 5b. Existing skill audit
+## Phase 5: SKILL GRAPH AUDIT — DRY + MECE on capabilities (( role: procedure ))
+
+use judgment to follow the Phase 5: SKILL GRAPH AUDIT — DRY + MECE on capabilities guidance:
+  This phase operates on the SKILL graph, not just the research.
+### 5a. New pattern identification (( role: procedure ))
+  
+use judgment to follow the 5a. New pattern identification guidance:
+  Ask: did this work reveal REPEATABLE patterns that will recur?
+  
+  **Indicators of a reusable pattern:**
+  item: You used a specific sequence of searches across multiple sources.
+  item: You followed a specific verification/cross-referencing methodology.
+  item: You wrote code that could be parameterized for different inputs.
+  item: The output format is generalizable.
+  item: The user is likely to ask for similar work on a different topic.
+  
+  **For each identified pattern:**
+  1. Identify the composable pieces (DRY, MECE):
+  item: Shared logic → `lib/` (not copy-pasted into skills)
+  item: Search methodology → skill or lib function
+  item: Output template → brain template or skill phase
+  item: Filing logic → already covered by brain-taxonomist + active pack
+  2. DRY check via the v0.19 resolver:
+     ```bash
+     gbrain check-resolvable
+     ```
+     Look for overlapping triggers or unreachable skills.
+### 5b. Existing skill audit (( inert ))
 For ALL skills used or touched during this work, check:
 1. Were any skills BYPASSED? (did you do something manually that a skill should handle?)
 2. Are there skills that OVERLAP with what you just did? (merge candidates)
 3. Is shared code copy-pasted between skills? (extract to `lib/`)
-
+  
 **The MECE question:** If someone asked for this exact work again tomorrow on a different topic, which skills would they invoke? Is the path clear and unambiguous? If not, fix the routing.
-
-### 5c. Present the plan
-```
-## Skill Graph Changes
-
-### New skills to create
+  
+### 5c. Present the plan (( inert ))
+```
+## Skill Graph Changes (( inert ))
+
+### New skills to create (( inert ))
 1. **[skill-name]** — [what it does]
    - DRY check: [clean / overlaps with X]
    - Recommendation: [create / merge into X]
 
-### Existing skills to update
+### Existing skills to update (( inert ))
 1. **[skill-name]** — [what changed, why]
 
-### Code to extract to lib/
+### Code to extract to lib/ (( inert ))
 1. **lib/[name].ts** — [what it does, which skills use it]
 
-### Skills to merge or deprecate
+### Skills to merge or deprecate (( inert ))
 1. **[skill-A] + [skill-B]** → [merged-skill] — [why]
 ```
 
@@ -276,7 +276,9 @@
 gbrain orphans                                  # any pages without inbound links?
 ```
 
-Confirm:
+### Confirm
+
+!!! checklist (( ai-autonomy ))
 - [ ] All brain pages have proper frontmatter against active schema pack
 - [ ] All entity pages are cross-linked
 - [ ] Any new skills have routing entries in `skills/RESOLVER.md`
@@ -288,24 +290,24 @@
 ## Phase 7: REPORT — Summary
 
 ```markdown
-## EIIRP Complete: [Topic]
-
-### Brain pages created/updated
+## EIIRP Complete: [Topic] (( inert ))
+
+### Brain pages created/updated (( inert ))
 - [path] — [description]
 - ...
 
-### Entity pages
+### Entity pages (( inert ))
 - [path] — [created/updated]
 - ...
 
-### Schema changes
+### Schema changes (( inert ))
 - [none / description of changes + which pack delta file]
 
-### Skills identified
+### Skills identified (( inert ))
 - [skill-name] — [status: created / merged / deferred]
 - ...
 
-### Resolver status
+### Resolver status (( inert ))
 - DRY check: [clean]
 - MECE audit: [clean]
 - Active pack: [name] v[version]
@@ -317,21 +319,21 @@
 EIIRP produces a single Phase 7 report block. Plain markdown:
 
 ```markdown
-## EIIRP Complete: [topic]
-
-### Brain pages created/updated
+## EIIRP Complete: [topic] (( inert ))
+
+### Brain pages created/updated (( inert ))
 - [path] — [description]
 
-### Entity pages
+### Entity pages (( inert ))
 - [path] — [created|updated]
 
-### Schema changes
+### Schema changes (( inert ))
 - [none | description of changes + which pack delta file]
 
-### Skills identified
+### Skills identified (( inert ))
 - [skill-name] — [status: created|merged|deferred]
 
-### Resolver status
+### Resolver status (( inert ))
 - DRY check: [clean|N violations]
 - MECE audit: [clean|N overlaps]
 - Active pack: [name] v[version]
@@ -342,54 +344,57 @@
 report doubles as a sync checkpoint for downstream skills (skillpack-check
 reads it; doctor cross-references the pack version).
 
-## Anti-Patterns
-
-- **Hardcoding directory tables in EIIRP's logic.** Every filing decision
+## Anti-Patterns (( role: procedure ))
+
+!!! checklist (( ai-autonomy ))
+- [ ] **Hardcoding directory tables in EIIRP's logic.** Every filing decision
   reads `gbrain schema show --json`. Users on `gbrain-recommended` AND
   custom packs MUST get the right behavior automatically. Pinned by D9
   from /plan-eng-review.
-- **Auto-applying low-confidence schema suggestions.** Confidence < 0.6
+- [ ] **Auto-applying low-confidence schema suggestions.** Confidence < 0.6
   from `gbrain schema suggest` is "manual review required" per codex
   finding #9. EIIRP surfaces it; the user accepts.
-- **Skipping Phase 5 SKILL GRAPH AUDIT because "this was a one-off."**
+- [ ] **Skipping Phase 5 SKILL GRAPH AUDIT because "this was a one-off."**
   If the work took >10 minutes, the methodology is probably reusable.
   Audit anyway; defer the skillify decision to the user.
-- **Filing synthesis output by topic alone.** Synthesis pages tied to a
+- [ ] **Filing synthesis output by topic alone.** Synthesis pages tied to a
   single source + reader are sui generis; they file under
   `media/<format>/<slug>-personalized.md`. See _brain-filing-rules.md
   "Sanctioned exception" section.
-- **Treating non-English sources as secondary citations.** Multilingual
+- [ ] **Treating non-English sources as secondary citations.** Multilingual
   sources are first-class.
 
-## Hard Rules
-
-### Knowledge domain
+## Hard Rules (( inert ))
+
+### Knowledge domain (( inert ))
 - **Never leave research only in chat.** If it took >10 minutes to produce, it gets a brain page.
 - **Every source gets a citation.** No "according to reports" without a URL.
 - **Entity pages get updated, not just created.** If a brain page exists, UPDATE it.
 - **Schema changes require confirmation.** The active pack is load-bearing.
 - **Multilingual sources are first-class.** Never treat non-English sources as secondary.
 
-### Capability domain
+### Capability domain (( inert ))
 - **DRY is sacred.** If the same logic appears in two skills, extract it to `lib/`.
 - **MECE is sacred.** Every trigger phrase routes to exactly one skill.
 - **Composability over monoliths.** Small skills that compose > one giant skill that does everything.
 - **Skillify only what recurs.** One-off work doesn't need a skill. Patterns that repeat 2+ times do.
 
-### Meta
+### Meta (( inert ))
 - **EIIRP is idempotent.** Running it twice on the same work should produce no changes the second time.
 - **EIIRP consumes the active schema pack as data.** Never hard-code directory tables in EIIRP's logic — read from `gbrain schema show --json` so users who picked `gbrain-recommended` OR custom packs get the right behavior automatically.
 
-## Changelog
-
-### v1.0.0 — gbrain v0.39.0.0
-- Initial port from upstream OpenClaw. Genericized — no references to
-  private fork names per CLAUDE.md privacy rules.
-- Phase 3 SCHEMA CHECK rewritten to consume the v0.39 cathedral CLI
-  (`detect | suggest | review-candidates`) instead of a private
-  `brain/schema.md`.
-- Phase 5 SKILL GRAPH AUDIT calls `gbrain check-resolvable` instead of
-  upstream `scripts/skill-dry-check.mjs`.
-- Phase 6 verification uses `gbrain doctor`'s schema_pack_consistency
-  check (T7) for the persistent surface.
-
+## Changelog (( inert ))
+
+### v1.0.0 — gbrain v0.39.0.0 (( role: procedure ))
+
+use judgment to follow the v1.0.0 — gbrain v0.39.0.0 guidance:
+  item: Initial port from upstream OpenClaw. Genericized — no references to
+    private fork names per CLAUDE.md privacy rules.
+  item: Phase 3 SCHEMA CHECK rewritten to consume the v0.39 cathedral CLI
+    (`detect | suggest | review-candidates`) instead of a private
+    `brain/schema.md`.
+  item: Phase 5 SKILL GRAPH AUDIT calls `gbrain check-resolvable` instead of
+    upstream `scripts/skill-dry-check.mjs`.
+  item: Phase 6 verification uses `gbrain doctor`'s schema_pack_consistency
+    check (T7) for the persistent surface.
+
```
