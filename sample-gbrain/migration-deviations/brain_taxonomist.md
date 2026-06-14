# Deviation: brain_taxonomist.meri

- Original: `brain-taxonomist/SKILL.md`
- Ported: `brain_taxonomist.meri`
- Tier: 2 (light edits)
- Similarity: 68%
- Lines: 196 -> 198 (+65 / -63)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- shell-block-routed

## Metrics
- Sections: 12/17 inert (71% inert ratio)
- Operational inert: 0
- Unclassified inert: 0
- Inert categories: reference-documentation=11, template=1
- Judgment: 3 blocks, 22 lines

### Inert section details
- L4 `Purpose`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L20 `Critical: this skill reads the ACTIVE schema pack as data`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L35 `When to Consult (MANDATORY)`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L48 `Decision Protocol`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L50 `Step 1: Identify primary subject type`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L72 `Step 3: For books — determine sub-category`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L80 `Step 4: Construct the slug`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L97 `Integration with Other Skills`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L117 `Output Format`: template — Template/output shape is metadata unless explicit output assertions are authored.
- L158 `Hard Rules`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L168 `Changelog`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L170 `v1.0.0 — gbrain v0.39.0.0`: reference-documentation — Reference documentation, rationale, examples, or changelog.

## Unified diff

```diff
--- original-skills/brain-taxonomist/SKILL.md
+++ skills/brain_taxonomist.meri
@@ -21,22 +21,23 @@
 
 # brain-taxonomist
 
-## Purpose
+## Purpose (( inert ))
 
 **Gate function:** Before creating ANY new brain page, consult this skill to determine the correct filing path. This prevents misfiling at write time rather than cleaning up drift after the fact.
 
 **Drift function:** Periodic scan for pages that have outgrown their current location.
 
-## Contract
+## Contract (( role: procedure ))
 
-This skill guarantees:
-- Every new page is filed at the path determined by the ACTIVE schema pack — never against a hardcoded directory table baked into this skill.
-- The decision is reproducible: invoking brain-taxonomist twice on the same content produces the same recommended path.
-- Ambiguous cases surface to the user via `skills/ask-user/` rather than silently picking a default.
-- Per-source overrides via `--source <id>` are honored — multi-brain users (Persona B) get a different recommendation per source if their packs diverge.
-- When no matching `page_types[]` entry exists in the active pack, the skill signals to EIIRP Phase 3 (SCHEMA CHECK) rather than picking the closest-fitting fallback.
+> This skill guarantees:
+!!! checklist (( ai-autonomy ))
+- [ ] Every new page is filed at the path determined by the ACTIVE schema pack — never against a hardcoded directory table baked into this skill.
+- [ ] The decision is reproducible: invoking brain-taxonomist twice on the same content produces the same recommended path.
+- [ ] Ambiguous cases surface to the user via `skills/ask-user/` rather than silently picking a default.
+- [ ] Per-source overrides via `--source <id>` are honored — multi-brain users (Persona B) get a different recommendation per source if their packs diverge.
+- [ ] When no matching `page_types[]` entry exists in the active pack, the skill signals to EIIRP Phase 3 (SCHEMA CHECK) rather than picking the closest-fitting fallback.
 
-## Critical: this skill reads the ACTIVE schema pack as data
+## Critical: this skill reads the ACTIVE schema pack as data (( inert ))
 
 `brain-taxonomist` has NO hardcoded directory table. Every decision is
 driven by `gbrain schema show --json`. This means:
@@ -51,7 +52,7 @@
 
 This is the single-source-of-truth principle (D9 from the v0.39 plan-eng-review).
 
-## When to Consult (MANDATORY)
+## When to Consult (MANDATORY) (( inert ))
 
 Run the taxonomist check before writing to the brain in these cases:
 
@@ -64,9 +65,9 @@
 - Appending to a Timeline section
 - Meeting entity propagation to existing pages
 
-## Decision Protocol
+## Decision Protocol (( inert ))
 
-### Step 1: Identify primary subject type
+### Step 1: Identify primary subject type (( inert ))
 
 Walk these questions in order:
 1. Is the primary subject a NAMED PERSON? → person-typed directory
@@ -77,62 +78,62 @@
 6. Is it BULK SOURCE DATA? → source-typed directory
 7. None of the above → consult EIIRP Phase 3 for schema-pack candidate creation.
 
-### Step 2: Look up the directory for that type in the active pack
+### Step 2: Look up the directory for that type in the active pack (( role: procedure ))
 
-```bash
-gbrain schema show --json | jq '.page_types[] | select(.primitive == "entity")'
-```
-
-Each `page_types[]` entry has a `path_prefixes:` array. The first prefix
-is the canonical path. If multiple types match (e.g. both `person` and
-`founder` exist in the pack with `expert_routing: true`), prefer the more
-specific one (the one with the more specific path prefix).
-
-### Step 3: For books — determine sub-category
-
+use judgment to follow the Step 2: Look up the directory for that type in the active pack guidance:
+  ```bash
+  gbrain schema show --json | jq '.page_types[] | select(.primitive == "entity")'
+  ```
+  
+  Each `page_types[]` entry has a `path_prefixes:` array. The first prefix
+  is the canonical path. If multiple types match (e.g. both `person` and
+  `founder` exist in the pack with `expert_routing: true`), prefer the more
+  specific one (the one with the more specific path prefix).
+### Step 3: For books — determine sub-category (( inert ))
+  
 The `gbrain-recommended` pack treats books as `media/books/<category>/<slug>.md`
 where category is one of: psychology, philosophy, spirituality, business,
 media-and-society, family-and-divorce, heritage, science, fiction,
 biography, arts-and-design. If your active pack has a different scheme,
 walk it from `gbrain schema show --json` instead of hardcoding here.
-
-### Step 4: Construct the slug
-
-- kebab-case, descriptive
-- no author name unless disambiguation is needed
-- match the canonical path prefix exactly (no leading slash)
-
-### Step 5: Validate before writing
-
-- [ ] Path follows the active pack's `page_types[].path_prefixes`
-- [ ] Slug is kebab-case, descriptive
-- [ ] Frontmatter includes `type:` matching one of the pack's `page_types[].name`
-- [ ] Cross-links to related pages are included
-
-If the active pack doesn't have a type for what you're trying to file,
-DON'T pick the closest-fitting one. Instead, signal to EIIRP that a new
-type is needed and let the schema-pack cathedral handle the proposal flow.
-
-## Integration with Other Skills
+  
+### Step 4: Construct the slug (( inert ))
+  
+  item: kebab-case, descriptive
+  item: no author name unless disambiguation is needed
+  item: match the canonical path prefix exactly (no leading slash)
+  
+### Step 5: Validate before writing (( role: procedure ))
+  
+use judgment to follow the Step 5: Validate before writing guidance:
+  item: [ ] Path follows the active pack's `page_types[].path_prefixes`
+  item: [ ] Slug is kebab-case, descriptive
+  item: [ ] Frontmatter includes `type:` matching one of the pack's `page_types[].name`
+  item: [ ] Cross-links to related pages are included
+  
+  If the active pack doesn't have a type for what you're trying to file,
+  DON'T pick the closest-fitting one. Instead, signal to EIIRP that a new
+  type is needed and let the schema-pack cathedral handle the proposal flow.
+## Integration with Other Skills (( inert ))
 
 - `eiirp` — calls this skill as Phase 2 TAXONOMY for every output in its inventory.
 - `ingest` — article/media ingestion consults brain-taxonomist for filing.
 - `repo-architecture` — delegates the filing decision to this skill.
 - `book-mirror` — after generating a mirror, files it via brain-taxonomist.
 
-## Periodic Drift Detection
+## Periodic Drift Detection (( role: procedure ))
 
-```bash
-# What pages have no type matching the active pack?
-gbrain schema review-orphans --json
-
-# What's the overall health?
-gbrain doctor --json | jq '.checks[] | select(.name == "schema_pack_consistency")'
-```
-
-When `schema_pack_consistency` warns at >10% untyped, run the EIIRP
-Phase 3 SCHEMA CHECK flow to surface candidate types via `schema detect`.
-
+use judgment to follow the Periodic Drift Detection guidance:
+  ```bash
+  # What pages have no type matching the active pack?
+  gbrain schema review-orphans --json
+  
+  # What's the overall health?
+  gbrain doctor --json | jq '.checks[] | select(.name == "schema_pack_consistency")'
+  ```
+  
+  When `schema_pack_consistency` warns at >10% untyped, run the EIIRP
+  Phase 3 SCHEMA CHECK flow to surface candidate types via `schema detect`.
 ## Output Format
 
 Advisory: a single recommendation block plus a one-line reasoning trail.
@@ -158,22 +159,23 @@
 `gbrain schema review-candidates`.
 ```
 
-## Anti-Patterns
+## Anti-Patterns (( role: procedure ))
 
-- **Hardcoded directory table in this skill.** Every decision goes through
+!!! checklist (( ai-autonomy ))
+- [ ] **Hardcoded directory table in this skill.** Every decision goes through
   `gbrain schema show --json`. v0.39+ broke the old hardcoded table on
   purpose so users on `gbrain-recommended` or custom packs get the right
   routing automatically.
-- **Picking the closest-fitting type when no type matches.** Closest-fit
+- [ ] **Picking the closest-fitting type when no type matches.** Closest-fit
   silently degrades user filing. Surface to EIIRP Phase 3 instead.
-- **Ignoring `--source <id>` on multi-brain setups.** Per-source overrides
+- [ ] **Ignoring `--source <id>` on multi-brain setups.** Per-source overrides
   are tier-3 in the 7-tier resolution chain; missing the flag silently
   uses the brain-wide active pack.
-- **Auto-applying a `gbrain schema review-candidates --apply` decision.**
+- [ ] **Auto-applying a `gbrain schema review-candidates --apply` decision.**
   Even high-confidence suggestions need user approval — this skill is a
   GATE, not an automator.
 
-## Hard Rules
+## Hard Rules (( inert ))
 
 - **Never hardcode a directory table in this skill.** Every decision goes
   through `gbrain schema show --json`. The active pack is canonical.
@@ -183,9 +185,9 @@
   confidence < 0.6 that brain-taxonomist must surface to the user rather
   than auto-apply. Don't silently promote a low-confidence schema delta.
 
-## Changelog
+## Changelog (( inert ))
 
-### v1.0.0 — gbrain v0.39.0.0
+### v1.0.0 — gbrain v0.39.0.0 (( inert ))
 - Initial port from upstream OpenClaw. Genericized — no references to
   private fork names per CLAUDE.md privacy rules.
 - Hardcoded directory table REMOVED. Every decision now reads the active
```
