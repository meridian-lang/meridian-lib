# Deviation: eiirp.meri

- Original: `eiirp/SKILL.md`
- Ported: `eiirp.meri`
- Tier: 1 (near-verbatim)
- Similarity: 90%
- Lines: 395 -> 395 (+39 / -39)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- inert-section-added

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L6 `Contract`: normative-contract - Normative invariants prose needs mining into assertions or explicit AI routing.
- L24 `When to Use`: operational-procedure - Marked or derived as applicability, but inert suppresses execution.
- L33 `Phase 1: INVENTORY — What did we produce?`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L37 `Knowledge outputs`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L46 `Capability outputs`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L66 `Phase 2: TAXONOMY — Where does each piece go?`: operational-procedure - Marked or derived as procedure, but inert suppresses execution.
- L94 `Phase 3: SCHEMA CHECK — Does the active pack cover this content?`: operational-procedure - Marked or derived as procedure, but inert suppresses execution.
- L124 `Phase 4: FILE — Create enriched brain pages`: operational-procedure - Marked or derived as procedure, but inert suppresses execution.
- L128 `4a. Primary research page`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L137 `4b. Entity pages (people, companies)`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L143 `4c. Commit and verify`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L147 `Phase 5: SKILL GRAPH AUDIT — DRY + MECE on capabilities`: operational-procedure - Marked or derived as procedure, but inert suppresses execution.
- L151 `5a. New pattern identification`: operational-content - Body contains command, table, checklist, or explicit AI-routing surface.
- L174 `5b. Existing skill audit`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L182 `5c. Present the plan`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L203 `Phase 6: CHECK_RESOLVABLE — Verify everything routes`: operational-procedure - Marked or derived as procedure, but inert suppresses execution.
- L223 `Phase 7: REPORT — Summary`: operational-procedure - Marked or derived as procedure, but inert suppresses execution.
- L250 `Output Format`: template - Template/output shape is metadata unless explicit output assertions are authored.
- L280 `Anti-Patterns`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L299 `Hard Rules`: normative-contract - Normative invariants prose needs mining into assertions or explicit AI routing.
- L301 `Knowledge domain`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L308 `Capability domain`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L314 `Meta`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L318 `Changelog`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L320 `v1.0.0 — gbrain v0.39.0.0`: reference-documentation - Reference documentation, rationale, examples, or changelog.

## Metrics
- Sections: 25/25 inert (100% inert ratio)
- Operational inert: 10
- Unclassified inert: 0
- Inert categories: normative-contract=2, operational-content=1, operational-procedure=7, reference-documentation=14, template=1
- Judgment: 0 blocks, 0 lines

### Inert section details
- L6 `Contract`: normative-contract — Normative invariants prose needs mining into assertions or explicit AI routing.
- L24 `When to Use`: operational-procedure — Marked or derived as applicability, but inert suppresses execution.
- L33 `Phase 1: INVENTORY — What did we produce?`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L37 `Knowledge outputs`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L46 `Capability outputs`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L66 `Phase 2: TAXONOMY — Where does each piece go?`: operational-procedure — Marked or derived as procedure, but inert suppresses execution.
- L94 `Phase 3: SCHEMA CHECK — Does the active pack cover this content?`: operational-procedure — Marked or derived as procedure, but inert suppresses execution.
- L124 `Phase 4: FILE — Create enriched brain pages`: operational-procedure — Marked or derived as procedure, but inert suppresses execution.
- L128 `4a. Primary research page`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L137 `4b. Entity pages (people, companies)`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L143 `4c. Commit and verify`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L147 `Phase 5: SKILL GRAPH AUDIT — DRY + MECE on capabilities`: operational-procedure — Marked or derived as procedure, but inert suppresses execution.
- L151 `5a. New pattern identification`: operational-content — Body contains command, table, checklist, or explicit AI-routing surface.
- L174 `5b. Existing skill audit`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L182 `5c. Present the plan`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L203 `Phase 6: CHECK_RESOLVABLE — Verify everything routes`: operational-procedure — Marked or derived as procedure, but inert suppresses execution.
- L223 `Phase 7: REPORT — Summary`: operational-procedure — Marked or derived as procedure, but inert suppresses execution.
- L250 `Output Format`: template — Template/output shape is metadata unless explicit output assertions are authored.
- L280 `Anti-Patterns`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L299 `Hard Rules`: normative-contract — Normative invariants prose needs mining into assertions or explicit AI routing.
- L301 `Knowledge domain`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L308 `Capability domain`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L314 `Meta`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L318 `Changelog`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L320 `v1.0.0 — gbrain v0.39.0.0`: reference-documentation — Reference documentation, rationale, examples, or changelog.

## Unified diff

```diff
--- original-skills/eiirp/SKILL.md
+++ skills/eiirp.meri
@@ -68,7 +68,7 @@
 
 > *"Everything in its right place"* — Radiohead, Kid A
 
-## Contract
+## Contract (( inert, role: invariants ))
 
 After any significant work, EIIRP organizes ALL outputs across two domains:
 
@@ -86,7 +86,7 @@
 **The meta-guarantee:** Nothing produced during significant work lives only in chat.
 Knowledge → brain. Patterns → skills. Everything in its right place.
 
-## When to Use
+## When to Use (( inert, role: applicability ))
 
 - After completing a deep research thread.
 - After building something new (code, pipeline, workflow).
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
@@ -186,11 +186,11 @@
   `~/.gbrain/schema-pack-deltas/` — review and merge into the active
   pack via `gbrain schema edit` (or hand-edit the YAML).
 
-## Phase 4: FILE — Create enriched brain pages
+## Phase 4: FILE — Create enriched brain pages (( inert, role: procedure ))
 
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
@@ -244,28 +244,28 @@
 
 **The MECE question:** If someone asked for this exact work again tomorrow on a different topic, which skills would they invoke? Is the path clear and unambiguous? If not, fix the routing.
 
-### 5c. Present the plan
-```
-## Skill Graph Changes
+### 5c. Present the plan (( inert ))
+```
+## Skill Graph Changes (( inert ))
 
 ### New skills to create
-1. **[skill-name]** — [what it does]
+1. [skill-name] — [what it does]
    - DRY check: [clean / overlaps with X]
    - Recommendation: [create / merge into X]
 
 ### Existing skills to update
-1. **[skill-name]** — [what changed, why]
+1. [skill-name] — [what changed, why]
 
 ### Code to extract to lib/
-1. **lib/[name].ts** — [what it does, which skills use it]
-
-### Skills to merge or deprecate
+1. lib/[name].ts — [what it does, which skills use it]
+
+### Skills to merge or deprecate (( inert ))
 1. **[skill-A] + [skill-B]** → [merged-skill] — [why]
 ```
 
 On approval: invoke `/skillify` for each new/modified skill.
 
-## Phase 6: CHECK_RESOLVABLE — Verify everything routes
+## Phase 6: CHECK_RESOLVABLE — Verify everything routes (( inert, role: procedure ))
 
 After all filing and skillification:
 
@@ -285,10 +285,10 @@
 - [ ] Active schema pack updated if new content types emerged
 - [ ] `gbrain doctor` reports `schema_pack_consistency: ok`
 
-## Phase 7: REPORT — Summary
+## Phase 7: REPORT — Summary (( inert, role: procedure ))
 
 ```markdown
-## EIIRP Complete: [Topic]
+## EIIRP Complete: [Topic] (( inert ))
 
 ### Brain pages created/updated
 - [path] — [description]
@@ -305,19 +305,19 @@
 - [skill-name] — [status: created / merged / deferred]
 - ...
 
-### Resolver status
+### Resolver status (( inert ))
 - DRY check: [clean]
 - MECE audit: [clean]
 - Active pack: [name] v[version]
 - schema_pack_consistency: [ok / warn — pct untyped]
 ```
 
-## Output Format
+## Output Format (( inert, role: template ))
 
 EIIRP produces a single Phase 7 report block. Plain markdown:
 
 ```markdown
-## EIIRP Complete: [topic]
+## EIIRP Complete: [topic] (( inert ))
 
 ### Brain pages created/updated
 - [path] — [description]
@@ -331,7 +331,7 @@
 ### Skills identified
 - [skill-name] — [status: created|merged|deferred]
 
-### Resolver status
+### Resolver status (( inert ))
 - DRY check: [clean|N violations]
 - MECE audit: [clean|N overlaps]
 - Active pack: [name] v[version]
@@ -342,7 +342,7 @@
 report doubles as a sync checkpoint for downstream skills (skillpack-check
 reads it; doctor cross-references the pack version).
 
-## Anti-Patterns
+## Anti-Patterns (( inert, role: prohibitions ))
 
 - **Hardcoding directory tables in EIIRP's logic.** Every filing decision
   reads `gbrain schema show --json`. Users on `gbrain-recommended` AND
@@ -361,28 +361,28 @@
 - **Treating non-English sources as secondary citations.** Multilingual
   sources are first-class.
 
-## Hard Rules
-
-### Knowledge domain
+## Hard Rules (( inert, role: invariants ))
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
