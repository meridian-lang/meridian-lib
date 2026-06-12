# Deviation: brain_taxonomist.meri

- Original: `brain-taxonomist/SKILL.md`
- Ported: `brain_taxonomist.meri`
- Tier: 1 (near-verbatim)
- Similarity: 92%
- Lines: 196 -> 196 (+16 / -16)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added

## Metrics
- Sections: 17/17 inert (100% inert ratio)
- Judgment: 0 blocks, 0 lines

## Unified diff

```diff
--- original-skills/brain-taxonomist/SKILL.md
+++ skills/brain_taxonomist.meri
@@ -21,13 +21,13 @@
 
 # brain-taxonomist
 
-## Purpose
+## Purpose (( inert ))
 
 **Gate function:** Before creating ANY new brain page, consult this skill to determine the correct filing path. This prevents misfiling at write time rather than cleaning up drift after the fact.
 
 **Drift function:** Periodic scan for pages that have outgrown their current location.
 
-## Contract
+## Contract (( inert, role: invariants ))
 
 This skill guarantees:
 - Every new page is filed at the path determined by the ACTIVE schema pack — never against a hardcoded directory table baked into this skill.
@@ -36,7 +36,7 @@
 - Per-source overrides via `--source <id>` are honored — multi-brain users (Persona B) get a different recommendation per source if their packs diverge.
 - When no matching `page_types[]` entry exists in the active pack, the skill signals to EIIRP Phase 3 (SCHEMA CHECK) rather than picking the closest-fitting fallback.
 
-## Critical: this skill reads the ACTIVE schema pack as data
+## Critical: this skill reads the ACTIVE schema pack as data (( inert ))
 
 `brain-taxonomist` has NO hardcoded directory table. Every decision is
 driven by `gbrain schema show --json`. This means:
@@ -51,7 +51,7 @@
 
 This is the single-source-of-truth principle (D9 from the v0.39 plan-eng-review).
 
-## When to Consult (MANDATORY)
+## When to Consult (MANDATORY) (( inert ))
 
 Run the taxonomist check before writing to the brain in these cases:
 
@@ -64,9 +64,9 @@
 - Appending to a Timeline section
 - Meeting entity propagation to existing pages
 
-## Decision Protocol
+## Decision Protocol (( inert ))
 
-### Step 1: Identify primary subject type
+### Step 1: Identify primary subject type (( inert ))
 
 Walk these questions in order:
 1. Is the primary subject a NAMED PERSON? → person-typed directory
@@ -77,7 +77,7 @@
 6. Is it BULK SOURCE DATA? → source-typed directory
 7. None of the above → consult EIIRP Phase 3 for schema-pack candidate creation.
 
-### Step 2: Look up the directory for that type in the active pack
+### Step 2: Look up the directory for that type in the active pack (( inert ))
 
 ```bash
 gbrain schema show --json | jq '.page_types[] | select(.primitive == "entity")'
@@ -88,7 +88,7 @@
 `founder` exist in the pack with `expert_routing: true`), prefer the more
 specific one (the one with the more specific path prefix).
 
-### Step 3: For books — determine sub-category
+### Step 3: For books — determine sub-category (( inert ))
 
 The `gbrain-recommended` pack treats books as `media/books/<category>/<slug>.md`
 where category is one of: psychology, philosophy, spirituality, business,
@@ -96,13 +96,13 @@
 biography, arts-and-design. If your active pack has a different scheme,
 walk it from `gbrain schema show --json` instead of hardcoding here.
 
-### Step 4: Construct the slug
+### Step 4: Construct the slug (( inert ))
 
 - kebab-case, descriptive
 - no author name unless disambiguation is needed
 - match the canonical path prefix exactly (no leading slash)
 
-### Step 5: Validate before writing
+### Step 5: Validate before writing (( inert ))
 
 - [ ] Path follows the active pack's `page_types[].path_prefixes`
 - [ ] Slug is kebab-case, descriptive
@@ -113,14 +113,14 @@
 DON'T pick the closest-fitting one. Instead, signal to EIIRP that a new
 type is needed and let the schema-pack cathedral handle the proposal flow.
 
-## Integration with Other Skills
+## Integration with Other Skills (( inert ))
 
 - `eiirp` — calls this skill as Phase 2 TAXONOMY for every output in its inventory.
 - `ingest` — article/media ingestion consults brain-taxonomist for filing.
 - `repo-architecture` — delegates the filing decision to this skill.
 - `book-mirror` — after generating a mirror, files it via brain-taxonomist.
 
-## Periodic Drift Detection
+## Periodic Drift Detection (( inert ))
 
 ```bash
 # What pages have no type matching the active pack?
@@ -158,7 +158,7 @@
 `gbrain schema review-candidates`.
 ```
 
-## Anti-Patterns
+## Anti-Patterns (( inert, role: prohibitions ))
 
 - **Hardcoded directory table in this skill.** Every decision goes through
   `gbrain schema show --json`. v0.39+ broke the old hardcoded table on
@@ -173,7 +173,7 @@
   Even high-confidence suggestions need user approval — this skill is a
   GATE, not an automator.
 
-## Hard Rules
+## Hard Rules (( inert ))
 
 - **Never hardcode a directory table in this skill.** Every decision goes
   through `gbrain schema show --json`. The active pack is canonical.
@@ -183,9 +183,9 @@
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
