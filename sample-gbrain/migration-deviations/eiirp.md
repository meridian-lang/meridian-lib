# Deviation: eiirp.meri

- Original: `eiirp/SKILL.md`
- Ported: `eiirp.meri`
- Tier: 2 (light edits)
- Similarity: 83%
- Lines: 395 -> 438 (+94 / -51)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- shell-block-routed
- inert-section-added

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L40 `Knowledge outputs`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L49 `Capability outputs`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L287 `Output Format`: template - Template/output shape is metadata unless explicit output assertions are authored.
- L348 `Capability domain`: reference-documentation - Reference documentation, rationale, examples, or changelog.

## Metrics
- Sections inert total: 7/22 (32% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert categories: reference-documentation=6, template=1
- Judgment: 12 blocks, 0 lines

### Inert section details
- L40 `Knowledge outputs`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L49 `Capability outputs`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L173 `5a. New pattern identification`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L211 `5c. Present the plan`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L287 `Output Format`: template — Template/output shape is metadata unless explicit output assertions are authored.
- L348 `Capability domain`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L360 `v1.0.0 — gbrain v0.39.0.0`: reference-documentation — Reference documentation, rationale, examples, or changelog.

## Unified diff

```diff
--- original-skills/eiirp/SKILL.md
+++ skills/eiirp.meri
@@ -68,7 +68,8 @@
 
 > *"Everything in its right place"* — Radiohead, Kid A
 
-## Contract
+## Contract (( role: procedure ))
+use judgment to follow the Contract guidance:
 
 After any significant work, EIIRP organizes ALL outputs across two domains:
 
@@ -86,7 +87,8 @@
 **The meta-guarantee:** Nothing produced during significant work lives only in chat.
 Knowledge → brain. Patterns → skills. Everything in its right place.
 
-## When to Use
+## When to Use (( role: procedure ))
+use judgment to follow the When to Use guidance:
 
 - After completing a deep research thread.
 - After building something new (code, pipeline, workflow).
@@ -96,10 +98,11 @@
 - When you notice skill overlap, duplication, or gaps.
 
 ## Phase 1: INVENTORY — What did we produce?
+use judgment to follow the Phase 1: INVENTORY — What did we produce? guidance:
 
 Scan the current session/thread and identify ALL outputs across both domains.
 
-### Knowledge outputs
+### Knowledge outputs (( inert ))
 ```
 □ Primary findings (the synthesis)
 □ Source documents (URLs, PDFs, articles, tweets)
@@ -108,7 +111,7 @@
 □ Data artifacts (structured data, timelines, statistics)
 ```
 
-### Capability outputs
+### Capability outputs (( inert ))
 ```
 □ New skills created or modified
 □ Scripts/code written (should they be in lib/ or scripts/?)
@@ -129,13 +132,7 @@
 ```
 
 ## Phase 2: TAXONOMY — Where does each piece go?
-
-**Read the active schema pack first** (the single source of truth for
-filing decisions in v0.39+):
-
-```bash
-gbrain schema show --json
-```
+use judgment to follow the Phase 2: TAXONOMY — Where does each piece go? guidance:
 
 The pack's `page_types[]` lists every directory the brain accepts plus
 the primitive each maps to. Walk it for each output and pick the directory
@@ -144,8 +141,6 @@
 If `brain-taxonomist` is installed, INVOKE IT for ambiguous cases. It runs
 the same decision protocol against the active pack and gives you a single
 recommended filing path with reasoning.
-
-Output: a filing plan table:
 
 ```
 | Content | Brain path | Action |
@@ -156,41 +151,64 @@
 | ... | ... | ... |
 ```
 
+
+### Phase 2: TAXONOMY — Where does each piece go? — steps
+
+> **Read the active schema pack first** (the single source of truth for
+> filing decisions in v0.39+):
+
+```bash
+gbrain schema show --json
+```
+
+
+### Phase 2: TAXONOMY — Where does each piece go? — steps 2
+
+Output: a filing plan table:
+
 ## Phase 3: SCHEMA CHECK — Does the active pack cover this content?
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
+use judgment to follow the Phase 3: SCHEMA CHECK — Does the active pack cover this content? guidance:
 
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
+> If schema needs change:
+- Propose the addition to the user before running `review-candidates --apply`.
 ## Phase 4: FILE — Create enriched brain pages
 
 For each item in the filing plan:
 
 ### 4a. Primary research page
+use judgment to follow the 4a. Primary research page guidance:
 Use the brain page template. MUST include:
 - Proper frontmatter (`type`, `title`, `date`, `tags`, sources)
 - **State** section — current status/key findings
@@ -205,15 +223,19 @@
 - If exists: update State, append Timeline entry citing this research.
 - If not: create with enrichment.
 
-### 4c. Commit and verify
+### 4c. Commit and verify (( inert ))
+
+#### 4c. Commit and verify — steps
+
 After ALL pages are written, run `gbrain sync` (or commit + push in the
 brain repo). Verify every link resolves.
 
 ## Phase 5: SKILL GRAPH AUDIT — DRY + MECE on capabilities
+use judgment to follow the Phase 5: SKILL GRAPH AUDIT — DRY + MECE on capabilities guidance:
 
 This phase operates on the SKILL graph, not just the research.
 
-### 5a. New pattern identification
+### 5a. New pattern identification (( inert ))
 
 Ask: did this work reveal REPEATABLE patterns that will recur?
 
@@ -224,19 +246,26 @@
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
+#### 5a. New pattern identification — steps
+
+For each identified pattern:
+> 1. Identify the composable pieces (DRY, MECE):
+   - Shared logic → `lib/` (not copy-pasted into skills)
+
+#### 5a. New pattern identification — steps 2
+
+> 2. DRY check via the v0.19 resolver:
    ```bash
    gbrain check-resolvable
    ```
-   Look for overlapping triggers or unreachable skills.
-
 ### 5b. Existing skill audit
+use judgment to follow the 5b. Existing skill audit guidance:
 For ALL skills used or touched during this work, check:
 1. Were any skills BYPASSED? (did you do something manually that a skill should handle?)
 2. Are there skills that OVERLAP with what you just did? (merge candidates)
@@ -244,7 +273,7 @@
 
 **The MECE question:** If someone asked for this exact work again tomorrow on a different topic, which skills would they invoke? Is the path clear and unambiguous? If not, fix the routing.
 
-### 5c. Present the plan
+### 5c. Present the plan (( inert ))
 ```
 ## Skill Graph Changes
 
@@ -263,11 +292,17 @@
 1. **[skill-A] + [skill-B]** → [merged-skill] — [why]
 ```
 
+
+#### 5c. Present the plan — steps
+
 On approval: invoke `/skillify` for each new/modified skill.
 
-## Phase 6: CHECK_RESOLVABLE — Verify everything routes
-
-After all filing and skillification:
+## Phase 6: CHECK_RESOLVABLE — Verify everything routes (( inert, role: procedure ))
+
+
+### Phase 6: CHECK_RESOLVABLE — Verify everything routes — steps
+
+> After all filing and skillification:
 
 ```bash
 gbrain check-resolvable                         # routing-table reachability
@@ -276,7 +311,8 @@
 gbrain orphans                                  # any pages without inbound links?
 ```
 
-Confirm:
+> Confirm:
+!!! checklist (( ai-autonomy ))
 - [ ] All brain pages have proper frontmatter against active schema pack
 - [ ] All entity pages are cross-linked
 - [ ] Any new skills have routing entries in `skills/RESOLVER.md`
@@ -286,6 +322,7 @@
 - [ ] `gbrain doctor` reports `schema_pack_consistency: ok`
 
 ## Phase 7: REPORT — Summary
+use judgment to follow the Phase 7: REPORT — Summary guidance:
 
 ```markdown
 ## EIIRP Complete: [Topic]
@@ -312,7 +349,7 @@
 - schema_pack_consistency: [ok / warn — pct untyped]
 ```
 
-## Output Format
+## Output Format (( inert, role: template ))
 
 EIIRP produces a single Phase 7 report block. Plain markdown:
 
@@ -342,7 +379,8 @@
 report doubles as a sync checkpoint for downstream skills (skillpack-check
 reads it; doctor cross-references the pack version).
 
-## Anti-Patterns
+## Anti-Patterns (( role: procedure ))
+use judgment to follow the Anti-Patterns guidance:
 
 - **Hardcoding directory tables in EIIRP's logic.** Every filing decision
   reads `gbrain schema show --json`. Users on `gbrain-recommended` AND
@@ -361,16 +399,18 @@
 - **Treating non-English sources as secondary citations.** Multilingual
   sources are first-class.
 
-## Hard Rules
+## Hard Rules (( role: procedure ))
+use judgment to follow the Hard Rules guidance:
 
 ### Knowledge domain
+use judgment to follow the Knowledge domain guidance:
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
@@ -380,9 +420,9 @@
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
@@ -390,6 +430,9 @@
   `brain/schema.md`.
 - Phase 5 SKILL GRAPH AUDIT calls `gbrain check-resolvable` instead of
   upstream `scripts/skill-dry-check.mjs`.
+
+#### v1.0.0 — gbrain v0.39.0.0 — steps
+
 - Phase 6 verification uses `gbrain doctor`'s schema_pack_consistency
   check (T7) for the persistent surface.
 
```
