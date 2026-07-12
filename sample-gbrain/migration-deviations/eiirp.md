# Deviation: eiirp.meri

- Original: `eiirp/SKILL.md`
- Ported: `eiirp.meri`
- Tier: 2 (light edits)
- Similarity: 78%
- Lines: 395 -> 436 (+111 / -70)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- doc-section-marked

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L6 `Contract`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L33 `Phase 1: INVENTORY — What did we produce?`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L37 `Knowledge outputs`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L46 `Capability outputs`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L287 `Output Format`: template - Template/output shape is metadata unless explicit output assertions are authored.
- L346 `Capability domain`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.

## Metrics
- generated_loc: 264 non-blank ported lines
- Sections inert total: 15/21 (71% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert markers (`(( inert ))`, target 0 — the migrator never emits these): 0
- Inert categories: reference-documentation=14, template=1
- Judgment: 1 blocks, 0 lines
- canonical_drift: synonym=15, structure=0, desugar=0, meaning=290

### Inert section details
- L6 `Contract`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L33 `Phase 1: INVENTORY — What did we produce?`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L37 `Knowledge outputs`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L46 `Capability outputs`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L66 `Phase 2: TAXONOMY — Where does each piece go?`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L104 `Phase 3: SCHEMA CHECK — Does the active pack cover this content?`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L144 `4a. Primary research page`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L173 `5a. New pattern identification`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L202 `5b. Existing skill audit`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L213 `5c. Present the plan`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L287 `Output Format`: template — Template/output shape is metadata unless explicit output assertions are authored.
- L317 `Anti-Patterns`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L336 `Knowledge domain`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L346 `Capability domain`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L358 `v1.0.0 — gbrain v0.39.0.0`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.

## Unified diff

```diff
--- original-skills/eiirp/SKILL.md
+++ skills/eiirp.meri
@@ -68,22 +68,22 @@
 
 > *"Everything in its right place"* — Radiohead, Kid A
 
-## Contract
+## Contract (( role: reference ))
 
 After any significant work, EIIRP organizes ALL outputs across two domains:
 
-**Knowledge domain (brain):**
+Knowledge domain (brain):
 1. Every piece of knowledge lands in the correct brain location.
 2. All sources are cited and linked.
 3. The active schema pack is updated if a new content type emerged.
 4. Entity pages created/updated with cross-links.
 
-**Capability domain (skills):**
+Capability domain (skills):
 5. Every reusable pattern becomes a composable skill.
 6. Existing skills are audited for DRY violations.
 7. Skill graph is MECE — no gaps, no overlaps, no ambiguous routing.
 
-**The meta-guarantee:** Nothing produced during significant work lives only in chat.
+The meta-guarantee: Nothing produced during significant work lives only in chat.
 Knowledge → brain. Patterns → skills. Everything in its right place.
 
 ## When to Use
@@ -95,11 +95,11 @@
 - When a work session produced both knowledge AND new capabilities.
 - When you notice skill overlap, duplication, or gaps.
 
-## Phase 1: INVENTORY — What did we produce?
+## Phase 1: INVENTORY — What did we produce? (( role: reference ))
 
 Scan the current session/thread and identify ALL outputs across both domains.
 
-### Knowledge outputs
+### Knowledge outputs (( role: reference ))
 ```
 □ Primary findings (the synthesis)
 □ Source documents (URLs, PDFs, articles, tweets)
@@ -108,7 +108,7 @@
 □ Data artifacts (structured data, timelines, statistics)
 ```
 
-### Capability outputs
+### Capability outputs (( role: reference ))
 ```
 □ New skills created or modified
 □ Scripts/code written (should they be in lib/ or scripts/?)
@@ -128,24 +128,11 @@
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
+## Phase 2: TAXONOMY — Where does each piece go? (( role: reference ))
 
 The pack's `page_types[]` lists every directory the brain accepts plus
 the primitive each maps to. Walk it for each output and pick the directory
 whose `path_prefixes` matches the content's primary subject.
-
-If `brain-taxonomist` is installed, INVOKE IT for ambiguous cases. It runs
-the same decision protocol against the active pack and gives you a single
-recommended filing path with reasoning.
-
-Output: a filing plan table:
 
 ```
 | Content | Brain path | Action |
@@ -156,42 +143,70 @@
 | ... | ... | ... |
 ```
 
-## Phase 3: SCHEMA CHECK — Does the active pack cover this content?
-
-This is where EIIRP closes the schema-derivation loop. If the work
-produced content that doesn't fit any existing `page_types`, propose
-adding a new type via the v0.39 cathedral:
+
+### Phase 2: TAXONOMY — Where does each piece go? — steps
+
+> **Read the active schema pack first** (the single source of truth for
+> filing decisions in v0.39+):
 
 ```bash
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
+gbrain schema show --json
+```
+
+
+### Phase 2: TAXONOMY — Where does each piece go? — steps 2
+
+use judgment to follow the Phase 2: TAXONOMY — Where does each piece go? — steps 2 guidance:
+If `brain-taxonomist` is installed, INVOKE IT for ambiguous cases. It runs
+the same decision protocol against the active pack and gives you a single
+recommended filing path with reasoning.
+
+
+### Phase 2: TAXONOMY — Where does each piece go? — steps 3
+
+Output: a filing plan table:
+
+## Phase 3: SCHEMA CHECK — Does the active pack cover this content? (( role: reference ))
 
 **Confidence floor (codex finding #9):** when `gbrain schema suggest`
 returns confidence < 0.6 on a proposed type, DO NOT auto-apply. Surface
 the suggestion to the user and let them choose. The schema-cathedral
 ships the primitives; EIIRP enforces the human-in-the-loop gate.
 
-If schema needs change:
-- Propose the addition to the user before running `review-candidates --apply`.
 - Document the change in the commit message of the next sync.
 - The schema-pack engine writes the delta to
   `~/.gbrain/schema-pack-deltas/` — review and merge into the active
   pack via `gbrain schema edit` (or hand-edit the YAML).
 
+
+### Phase 3: SCHEMA CHECK — Does the active pack cover this content? — steps
+
+> This is where EIIRP closes the schema-derivation loop. If the work
+> produced content that doesn't fit any existing `page_types`, propose
+> adding a new type via the v0.39 cathedral:
+
+```bash
+# What's emerging in the brain that the active pack doesn't cover?
+gbrain schema detect --json
+
+# LLM-refined suggestions (heuristic when no API key set).
+gbrain schema suggest --json
+
+# Review what's pending; promote or ignore each candidate.
+gbrain schema review-candidates --json
+gbrain schema review-candidates --apply <prefix-or-type-name>
+```
+
+
+### Phase 3: SCHEMA CHECK — Does the active pack cover this content? — steps 2
+
+If schema needs change:
+- Propose the addition to the user before running `review-candidates --apply`.
 ## Phase 4: FILE — Create enriched brain pages
 
 For each item in the filing plan:
 
-### 4a. Primary research page
-Use the brain page template. MUST include:
+### 4a. Primary research page (( role: reference ))
 - Proper frontmatter (`type`, `title`, `date`, `tags`, sources)
 - **State** section — current status/key findings
 - **Sources** section — every source with URL, author, date, language
@@ -199,6 +214,10 @@
 - **Entity links** — backlinks to all related brain pages
 - **See Also** — related concepts, reference pages
 
+
+### 4a. Primary research page — steps
+
+Use the brain page template. MUST include:
 ### 4b. Entity pages (people, companies)
 For each entity mentioned:
 - Check if a brain page exists (`gbrain search "<name>"` or `gbrain get_page people/<slug>`).
@@ -206,6 +225,9 @@
 - If not: create with enrichment.
 
 ### 4c. Commit and verify
+
+### 4c. Commit and verify — steps
+
 After ALL pages are written, run `gbrain sync` (or commit + push in the
 brain repo). Verify every link resolves.
 
@@ -213,7 +235,7 @@
 
 This phase operates on the SKILL graph, not just the research.
 
-### 5a. New pattern identification
+### 5a. New pattern identification (( role: reference ))
 
 Ask: did this work reveal REPEATABLE patterns that will recur?
 
@@ -224,27 +246,36 @@
 - The output format is generalizable.
 - The user is likely to ask for similar work on a different topic.
 
-**For each identified pattern:**
-1. Identify the composable pieces (DRY, MECE):
-   - Shared logic → `lib/` (not copy-pasted into skills)
    - Search methodology → skill or lib function
    - Output template → brain template or skill phase
    - Filing logic → already covered by brain-taxonomist + active pack
-2. DRY check via the v0.19 resolver:
+   Look for overlapping triggers or unreachable skills.
+
+
+### 5a. New pattern identification — steps
+
+For each identified pattern:
+> 1. Identify the composable pieces (DRY, MECE):
+   - Shared logic → `lib/` (not copy-pasted into skills)
+
+### 5a. New pattern identification — steps 2
+
+> 2. DRY check via the v0.19 resolver:
    ```bash
    gbrain check-resolvable
    ```
-   Look for overlapping triggers or unreachable skills.
-
-### 5b. Existing skill audit
+### 5b. Existing skill audit (( role: reference ))
 For ALL skills used or touched during this work, check:
 1. Were any skills BYPASSED? (did you do something manually that a skill should handle?)
 2. Are there skills that OVERLAP with what you just did? (merge candidates)
+**The MECE question:** If someone asked for this exact work again tomorrow on a different topic, which skills would they invoke? Is the path clear and unambiguous? If not, fix the routing.
+
+
+### 5b. Existing skill audit — steps
+
 3. Is shared code copy-pasted between skills? (extract to `lib/`)
 
-**The MECE question:** If someone asked for this exact work again tomorrow on a different topic, which skills would they invoke? Is the path clear and unambiguous? If not, fix the routing.
-
-### 5c. Present the plan
+### 5c. Present the plan (( role: reference ))
 ```
 ## Skill Graph Changes
 
@@ -263,11 +294,17 @@
 1. **[skill-A] + [skill-B]** → [merged-skill] — [why]
 ```
 
+
+### 5c. Present the plan — steps
+
 On approval: invoke `/skillify` for each new/modified skill.
 
 ## Phase 6: CHECK_RESOLVABLE — Verify everything routes
 
-After all filing and skillification:
+
+### Phase 6: CHECK_RESOLVABLE — Verify everything routes — steps
+
+> After all filing and skillification:
 
 ```bash
 gbrain check-resolvable                         # routing-table reachability
@@ -276,7 +313,7 @@
 gbrain orphans                                  # any pages without inbound links?
 ```
 
-Confirm:
+> Confirm:
 - [ ] All brain pages have proper frontmatter against active schema pack
 - [ ] All entity pages are cross-linked
 - [ ] Any new skills have routing entries in `skills/RESOLVER.md`
@@ -312,7 +349,7 @@
 - schema_pack_consistency: [ok / warn — pct untyped]
 ```
 
-## Output Format
+## Output Format (( role: template ))
 
 EIIRP produces a single Phase 7 report block. Plain markdown:
 
@@ -342,15 +379,8 @@
 report doubles as a sync checkpoint for downstream skills (skillpack-check
 reads it; doctor cross-references the pack version).
 
-## Anti-Patterns
-
-- **Hardcoding directory tables in EIIRP's logic.** Every filing decision
-  reads `gbrain schema show --json`. Users on `gbrain-recommended` AND
-  custom packs MUST get the right behavior automatically. Pinned by D9
-  from /plan-eng-review.
-- **Auto-applying low-confidence schema suggestions.** Confidence < 0.6
-  from `gbrain schema suggest` is "manual review required" per codex
-  finding #9. EIIRP surfaces it; the user accepts.
+## Anti-Patterns (( role: reference ))
+
 - **Skipping Phase 5 SKILL GRAPH AUDIT because "this was a one-off."**
   If the work took >10 minutes, the methodology is probably reusable.
   Audit anyway; defer the skillify decision to the user.
@@ -361,16 +391,24 @@
 - **Treating non-English sources as secondary citations.** Multilingual
   sources are first-class.
 
+
+### Anti-Patterns — steps (( role: reference ))
+
+- Hardcoding directory tables in EIIRP's logic. Every filing decision reads `gbrain schema show --json`. Users on `gbrain-recommended` AND custom packs MUST get the right behavior automatically. Pinned by D9 from /plan-eng-review.
+- Auto-applying low-confidence schema suggestions. Confidence < 0.6 from `gbrain schema suggest` is "manual review required" per codex finding #9. EIIRP surfaces it; the user accepts.
 ## Hard Rules
 
-### Knowledge domain
+### Knowledge domain (( role: reference ))
 - **Never leave research only in chat.** If it took >10 minutes to produce, it gets a brain page.
 - **Every source gets a citation.** No "according to reports" without a URL.
 - **Entity pages get updated, not just created.** If a brain page exists, UPDATE it.
 - **Schema changes require confirmation.** The active pack is load-bearing.
-- **Multilingual sources are first-class.** Never treat non-English sources as secondary.
-
-### Capability domain
+
+### Knowledge domain — steps
+
+- Never treat non-English sources as secondary.
+
+### Capability domain (( role: reference ))
 - **DRY is sacred.** If the same logic appears in two skills, extract it to `lib/`.
 - **MECE is sacred.** Every trigger phrase routes to exactly one skill.
 - **Composability over monoliths.** Small skills that compose > one giant skill that does everything.
@@ -380,9 +418,9 @@
 - **EIIRP is idempotent.** Running it twice on the same work should produce no changes the second time.
 - **EIIRP consumes the active schema pack as data.** Never hard-code directory tables in EIIRP's logic — read from `gbrain schema show --json` so users who picked `gbrain-recommended` OR custom packs get the right behavior automatically.
 
-## Changelog
-
-### v1.0.0 — gbrain v0.39.0.0
+## Changelog (( role: reference ))
+
+### v1.0.0 — gbrain v0.39.0.0 (( role: reference ))
 - Initial port from upstream OpenClaw. Genericized — no references to
   private fork names per CLAUDE.md privacy rules.
 - Phase 3 SCHEMA CHECK rewritten to consume the v0.39 cathedral CLI
@@ -390,6 +428,9 @@
   `brain/schema.md`.
 - Phase 5 SKILL GRAPH AUDIT calls `gbrain check-resolvable` instead of
   upstream `scripts/skill-dry-check.mjs`.
+
+### v1.0.0 — gbrain v0.39.0.0 — steps
+
 - Phase 6 verification uses `gbrain doctor`'s schema_pack_consistency
   check (T7) for the persistent surface.
 
```
