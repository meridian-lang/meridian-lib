# Deviation: brain_taxonomist.meri

- Original: `brain-taxonomist/SKILL.md`
- Ported: `brain_taxonomist.meri`
- Tier: 2 (light edits)
- Similarity: 73%
- Lines: 196 -> 222 (+70 / -44)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- shell-block-routed
- inert-section-added

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L4 `Purpose`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L38 `When to Consult (MANDATORY)`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L82 `Step 3: For books — determine sub-category`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L134 `Output Format`: template - Template/output shape is metadata unless explicit output assertions are authored.

## Metrics
- Sections inert total: 10/15 (67% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert categories: reference-documentation=9, template=1
- Judgment: 4 blocks, 6 lines

### Inert section details
- L4 `Purpose`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L20 `Critical: this skill reads the ACTIVE schema pack as data`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L38 `When to Consult (MANDATORY)`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L53 `Step 1: Identify primary subject type`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L68 `Step 2: Look up the directory for that type in the active pack`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L82 `Step 3: For books — determine sub-category`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L96 `Step 5: Validate before writing`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L118 `Periodic Drift Detection`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L134 `Output Format`: template — Template/output shape is metadata unless explicit output assertions are authored.
- L188 `v1.0.0 — gbrain v0.39.0.0`: reference-documentation — Reference documentation, rationale, examples, or changelog.

## Unified diff

```diff
--- original-skills/brain-taxonomist/SKILL.md
+++ skills/brain_taxonomist.meri
@@ -21,13 +21,14 @@
 
 # brain-taxonomist
 
-## Purpose
+## Purpose (( inert ))
 
 **Gate function:** Before creating ANY new brain page, consult this skill to determine the correct filing path. This prevents misfiling at write time rather than cleaning up drift after the fact.
 
 **Drift function:** Periodic scan for pages that have outgrown their current location.
 
-## Contract
+## Contract (( role: procedure ))
+use judgment to follow the Contract guidance:
 
 This skill guarantees:
 - Every new page is filed at the path determined by the ACTIVE schema pack — never against a hardcoded directory table baked into this skill.
@@ -36,10 +37,15 @@
 - Per-source overrides via `--source <id>` are honored — multi-brain users (Persona B) get a different recommendation per source if their packs diverge.
 - When no matching `page_types[]` entry exists in the active pack, the skill signals to EIIRP Phase 3 (SCHEMA CHECK) rather than picking the closest-fitting fallback.
 
-## Critical: this skill reads the ACTIVE schema pack as data
-
-`brain-taxonomist` has NO hardcoded directory table. Every decision is
-driven by `gbrain schema show --json`. This means:
+## Critical: this skill reads the ACTIVE schema pack as data (( inert ))
+
+This is the single-source-of-truth principle (D9 from the v0.39 plan-eng-review).
+
+
+### Critical: this skill reads the ACTIVE schema pack as data — steps
+
+> `brain-taxonomist` has NO hardcoded directory table. Every decision is
+> driven by `gbrain schema show --json`. This means:
 - A user who runs `gbrain schema use gbrain-recommended` gets the full
   recommended directory set (deal, meeting, concept, project, source,
   daily, personal, civic, original, place, trip, conversation, writing,
@@ -49,9 +55,7 @@
 - Per-source overrides (tier 3 in the 7-tier resolution chain) are honored
   when `--source <id>` is passed to brain-taxonomist.
 
-This is the single-source-of-truth principle (D9 from the v0.39 plan-eng-review).
-
-## When to Consult (MANDATORY)
+## When to Consult (MANDATORY) (( inert ))
 
 Run the taxonomist check before writing to the brain in these cases:
 
@@ -64,31 +68,38 @@
 - Appending to a Timeline section
 - Meeting entity propagation to existing pages
 
-## Decision Protocol
-
-### Step 1: Identify primary subject type
-
-Walk these questions in order:
-1. Is the primary subject a NAMED PERSON? → person-typed directory
-2. Is the primary subject a NAMED ORGANIZATION? → company-typed directory
-3. Is it about a TIME-BOUNDED EVENT (meeting, deal, trip)? → temporal-typed directory
-4. Is it a REUSABLE MENTAL MODEL? → concept-typed directory
-5. Is it RAW MEDIA (article, video, book, PDF)? → media-typed directory
-6. Is it BULK SOURCE DATA? → source-typed directory
+## Decision Protocol (( inert ))
+
+### Step 1: Identify primary subject type (( inert ))
+
 7. None of the above → consult EIIRP Phase 3 for schema-pack candidate creation.
 
-### Step 2: Look up the directory for that type in the active pack
-
-```bash
-gbrain schema show --json | jq '.page_types[] | select(.primitive == "entity")'
-```
+
+#### Step 1: Identify primary subject type — steps
+
+> Walk these questions in order:
+use judgment to weigh each question below:
+  1. Is the primary subject a NAMED PERSON? → person-typed directory
+  2. Is the primary subject a NAMED ORGANIZATION? → company-typed directory
+  3. Is it about a TIME-BOUNDED EVENT (meeting, deal, trip)? → temporal-typed directory
+  4. Is it a REUSABLE MENTAL MODEL? → concept-typed directory
+  5. Is it RAW MEDIA (article, video, book, PDF)? → media-typed directory
+  6. Is it BULK SOURCE DATA? → source-typed directory
+### Step 2: Look up the directory for that type in the active pack (( inert ))
 
 Each `page_types[]` entry has a `path_prefixes:` array. The first prefix
 is the canonical path. If multiple types match (e.g. both `person` and
 `founder` exist in the pack with `expert_routing: true`), prefer the more
 specific one (the one with the more specific path prefix).
 
-### Step 3: For books — determine sub-category
+
+#### Step 2: Look up the directory for that type in the active pack — steps
+
+```bash
+gbrain schema show --json | jq '.page_types[] | select(.primitive == "entity")'
+```
+
+### Step 3: For books — determine sub-category (( inert ))
 
 The `gbrain-recommended` pack treats books as `media/books/<category>/<slug>.md`
 where category is one of: psychology, philosophy, spirituality, business,
@@ -102,17 +113,21 @@
 - no author name unless disambiguation is needed
 - match the canonical path prefix exactly (no leading slash)
 
-### Step 5: Validate before writing
-
+### Step 5: Validate before writing (( inert ))
+
+If the active pack doesn't have a type for what you're trying to file,
+DON'T pick the closest-fitting one. Instead, signal to EIIRP that a new
+type is needed and let the schema-pack cathedral handle the proposal flow.
+
+
+#### Step 5: Validate before writing — steps
+
+!!! checklist (( ai-autonomy ))
 - [ ] Path follows the active pack's `page_types[].path_prefixes`
 - [ ] Slug is kebab-case, descriptive
 - [ ] Frontmatter includes `type:` matching one of the pack's `page_types[].name`
 - [ ] Cross-links to related pages are included
 
-If the active pack doesn't have a type for what you're trying to file,
-DON'T pick the closest-fitting one. Instead, signal to EIIRP that a new
-type is needed and let the schema-pack cathedral handle the proposal flow.
-
 ## Integration with Other Skills
 
 - `eiirp` — calls this skill as Phase 2 TAXONOMY for every output in its inventory.
@@ -120,7 +135,13 @@
 - `repo-architecture` — delegates the filing decision to this skill.
 - `book-mirror` — after generating a mirror, files it via brain-taxonomist.
 
-## Periodic Drift Detection
+## Periodic Drift Detection (( inert ))
+
+When `schema_pack_consistency` warns at >10% untyped, run the EIIRP
+Phase 3 SCHEMA CHECK flow to surface candidate types via `schema detect`.
+
+
+### Periodic Drift Detection — steps
 
 ```bash
 # What pages have no type matching the active pack?
@@ -130,10 +151,7 @@
 gbrain doctor --json | jq '.checks[] | select(.name == "schema_pack_consistency")'
 ```
 
-When `schema_pack_consistency` warns at >10% untyped, run the EIIRP
-Phase 3 SCHEMA CHECK flow to surface candidate types via `schema detect`.
-
-## Output Format
+## Output Format (( inert, role: template ))
 
 Advisory: a single recommendation block plus a one-line reasoning trail.
 
@@ -158,7 +176,8 @@
 `gbrain schema review-candidates`.
 ```
 
-## Anti-Patterns
+## Anti-Patterns (( role: procedure ))
+use judgment to follow the Anti-Patterns guidance:
 
 - **Hardcoded directory table in this skill.** Every decision goes through
   `gbrain schema show --json`. v0.39+ broke the old hardcoded table on
@@ -173,7 +192,8 @@
   Even high-confidence suggestions need user approval — this skill is a
   GATE, not an automator.
 
-## Hard Rules
+## Hard Rules (( role: procedure ))
+use judgment to follow the Hard Rules guidance:
 
 - **Never hardcode a directory table in this skill.** Every decision goes
   through `gbrain schema show --json`. The active pack is canonical.
@@ -183,14 +203,20 @@
   confidence < 0.6 that brain-taxonomist must surface to the user rather
   than auto-apply. Don't silently promote a low-confidence schema delta.
 
-## Changelog
-
-### v1.0.0 — gbrain v0.39.0.0
+## Changelog (( inert ))
+
+### v1.0.0 — gbrain v0.39.0.0 (( inert ))
 - Initial port from upstream OpenClaw. Genericized — no references to
   private fork names per CLAUDE.md privacy rules.
+- Book taxonomy moved from skill-text to the `gbrain-recommended` pack's
+  media/books/ branch (see `src/core/schema-pack/base/gbrain-recommended.yaml`).
+
+#### v1.0.0 — gbrain v0.39.0.0 — steps
+
 - Hardcoded directory table REMOVED. Every decision now reads the active
   schema pack via `gbrain schema show --json`. Single source of truth.
-- Book taxonomy moved from skill-text to the `gbrain-recommended` pack's
-  media/books/ branch (see `src/core/schema-pack/base/gbrain-recommended.yaml`).
+
+#### v1.0.0 — gbrain v0.39.0.0 — steps 2
+
 - `--source <id>` propagation documented for multi-brain users (Persona B).
 
```
