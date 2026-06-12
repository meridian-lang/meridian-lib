# Deviation: eiirp.meri

- Original: `eiirp/SKILL.md`
- Ported: `eiirp.meri`
- Tier: 1 (near-verbatim)
- Similarity: 89%
- Lines: 395 -> 397 (+46 / -44)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added

## Metrics
- Sections: 22/26 inert (85% inert ratio)
- Judgment: 0 blocks, 0 lines

## Unified diff

```diff
--- original-skills/eiirp/SKILL.md
+++ skills/eiirp.meri
@@ -68,7 +68,7 @@
 
 > *"Everything in its right place"* — Radiohead, Kid A
 
-## Contract
+## Contract (( inert, role: invariants ))
 
 After any significant work, EIIRP organizes ALL outputs across two domains:
 
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
@@ -128,7 +128,7 @@
 - Reusable methodology: [yes/no — describe if yes]
 ```
 
-## Phase 2: TAXONOMY — Where does each piece go?
+## Phase 2: TAXONOMY — Where does each piece go? (( inert, role: procedure ))
 
 **Read the active schema pack first** (the single source of truth for
 filing decisions in v0.39+):
@@ -156,7 +156,7 @@
 | ... | ... | ... |
 ```
 
-## Phase 3: SCHEMA CHECK — Does the active pack cover this content?
+## Phase 3: SCHEMA CHECK — Does the active pack cover this content? (( inert, role: procedure ))
 
 This is where EIIRP closes the schema-derivation loop. If the work
 produced content that doesn't fit any existing `page_types`, propose
@@ -190,7 +190,7 @@
 
 For each item in the filing plan:
 
-### 4a. Primary research page
+### 4a. Primary research page (( inert ))
 Use the brain page template. MUST include:
 - Proper frontmatter (`type`, `title`, `date`, `tags`, sources)
 - **State** section — current status/key findings
@@ -199,21 +199,21 @@
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
+## Phase 5: SKILL GRAPH AUDIT — DRY + MECE on capabilities (( inert, role: procedure ))
 
 This phase operates on the SKILL graph, not just the research.
 
-### 5a. New pattern identification
+### 5a. New pattern identification (( inert ))
 
 Ask: did this work reveal REPEATABLE patterns that will recur?
 
@@ -236,7 +236,7 @@
    ```
    Look for overlapping triggers or unreachable skills.
 
-### 5b. Existing skill audit
+### 5b. Existing skill audit (( inert ))
 For ALL skills used or touched during this work, check:
 1. Were any skills BYPASSED? (did you do something manually that a skill should handle?)
 2. Are there skills that OVERLAP with what you just did? (merge candidates)
@@ -244,22 +244,22 @@
 
 **The MECE question:** If someone asked for this exact work again tomorrow on a different topic, which skills would they invoke? Is the path clear and unambiguous? If not, fix the routing.
 
-### 5c. Present the plan
-```
-## Skill Graph Changes
-
-### New skills to create
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
 
@@ -275,6 +275,8 @@
 gbrain search "<topic keywords>"                # brain pages findable
 gbrain orphans                                  # any pages without inbound links?
 ```
+
+### Confirm (( inert ))
 
 Confirm:
 - [ ] All brain pages have proper frontmatter against active schema pack
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
@@ -342,7 +344,7 @@
 report doubles as a sync checkpoint for downstream skills (skillpack-check
 reads it; doctor cross-references the pack version).
 
-## Anti-Patterns
+## Anti-Patterns (( inert, role: prohibitions ))
 
 - **Hardcoding directory tables in EIIRP's logic.** Every filing decision
   reads `gbrain schema show --json`. Users on `gbrain-recommended` AND
@@ -361,28 +363,28 @@
 - **Treating non-English sources as secondary citations.** Multilingual
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
+## Changelog (( inert ))
+
+### v1.0.0 — gbrain v0.39.0.0 (( inert ))
 - Initial port from upstream OpenClaw. Genericized — no references to
   private fork names per CLAUDE.md privacy rules.
 - Phase 3 SCHEMA CHECK rewritten to consume the v0.39 cathedral CLI
```
