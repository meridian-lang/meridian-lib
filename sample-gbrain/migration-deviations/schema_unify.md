# Deviation: schema_unify.meri

- Original: `schema-unify/SKILL.md`
- Ported: `schema_unify.meri`
- Tier: 1 (near-verbatim)
- Similarity: 93%
- Lines: 252 -> 252 (+18 / -18)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- preamble-blockquoted

## Metrics
- Sections: 15/16 inert (94% inert ratio)
- Judgment: 0 blocks, 0 lines

## Unified diff

```diff
--- original-skills/schema-unify/SKILL.md
+++ schema_unify.meri
@@ -28,28 +28,28 @@
 
 # Schema Unification (gbrain-base → gbrain-base-v2)
 
-v0.41.22 ships **gbrain-base-v2** — a 15-type DRY/MECE taxonomy (14 canonical + `note` catch-all) — as the install default for new brains. Existing brains on `gbrain-base` can opt in via the `pack_upgrade_available` onboard finding + the `unify-types` PROTECTED Minion handler.
-
-This skill is the playbook for that migration.
-
-## brain_first: exempt
+> v0.41.22 ships **gbrain-base-v2** — a 15-type DRY/MECE taxonomy (14 canonical + `note` catch-all) — as the install default for new brains. Existing brains on `gbrain-base` can opt in via the `pack_upgrade_available` onboard finding + the `unify-types` PROTECTED Minion handler.
+
+> This skill is the playbook for that migration.
+
+## brain_first: exempt (( inert ))
 
 This skill is ABOUT the brain's shape — it can't depend on the brain it's reshaping. No `gbrain search` lookup first; jump straight to onboard.
 
-## When this skill fires
+## When this skill fires (( inert ))
 
 - Agent runs `gbrain onboard --check` and sees `pack_upgrade_available` or `type_proliferation` warnings
 - User asks "what is the canonical taxonomy / how do I clean up my page types / migrate to v2"
 - A `dangling_aliases` finding surfaces (post-unify GC)
 - An agent ingesting from a custom pack wants to consult the v2 taxonomy as a reference
 
-## Mental model (one paragraph)
+## Mental model (one paragraph) (( inert ))
 
 A production gbrain brain accreted **94 distinct `pages.type` values** over years of ingestion: tweet / tweet-thread / tweet-bundle / tweet-single / media/x-tweet/bundle / tweet-stub all coexisting; 5.5K concept-redirect pages; atom-partner-link pages that should be links; civic / framework / insight / memo / anecdote one-offs. The cure: collapse to **15 canonical types** (person, company, media, tweet, social-digest, analysis, atom, concept, source, deal, email, slack, writing, project, note) with subtypes/format/origin pushed to frontmatter, alias-rows for redirects, real link-rows for edge-shaped pages, and a catch-all that bins long-tail unknowns to `note` with `frontmatter.legacy_type = <original>` for rollback.
 
 ## Workflow
 
-### Phase 1: Discovery
+### Phase 1: Discovery (( inert, role: procedure ))
 
 Confirm the brain is actually on `gbrain-base` (not already on v2).
 
@@ -67,7 +67,7 @@
 
 Look for the `pack_upgrade_available` finding. If it's `ok`, there's no successor declared for the active pack — done.
 
-### Phase 2: Preview
+### Phase 2: Preview (( inert, role: procedure ))
 
 Run the per-cluster narrative:
 
@@ -83,7 +83,7 @@
 
 Review the output. If the proposed changes look wrong, **don't** proceed — file an issue or write a custom pack with adjusted mapping_rules.
 
-### Phase 3: Apply
+### Phase 3: Apply (( inert, role: procedure ))
 
 The handler is PROTECTED (manual_only per D17) — autopilot will never auto-fire it. Submit explicitly:
 
@@ -112,7 +112,7 @@
 6. **Flip active pack** to gbrain-base-v2 (D13)
 7. Verify + celebration summary
 
-### Phase 4: Verify
+### Phase 4: Verify (( inert, role: procedure ))
 
 ```bash
 gbrain onboard --check
@@ -125,13 +125,13 @@
 - `dangling_aliases` → `ok` (slug_aliases all point at active canonicals)
 - `gbrain schema stats` shows ≤16 distinct types
 
-### Phase 5: Post-migration
+### Phase 5: Post-migration (( inert, role: procedure ))
 
 Anything that used `--type article` keeps working post-unify if your CLI calls go through the `expandTypeFilter` helper (it expands `article` to `media+subtype=article` automatically). Direct SQL against `pages.type` needs updating to the canonical types.
 
 Search queries get a small ranking signal: pages reached via `slug_aliases` (canonicals of one or more aliases) get a 1.05x boost. Visible via `gbrain search --explain`.
 
-## Rollback
+## Rollback (( inert ))
 
 Every retyped page preserves `frontmatter.legacy_type = <original>` per D8. Restore types via:
 
@@ -152,7 +152,7 @@
 gbrain schema use gbrain-base
 ```
 
-## Anti-patterns
+## Anti-patterns (( inert, role: prohibitions ))
 
 - **Don't run unify-types under autopilot.** It's manual_only by design. Autopilot remediation should never silently change your taxonomy.
 - **Don't expect mapping_rules to cover every legacy type explicitly.** Use the catch-all (`*unknown*`) for the long tail. Pages get retyped to `note` with `legacy_type` preserved.
@@ -160,7 +160,7 @@
 - **Don't bypass the dry-run.** Always run `--explain` before applying. The trust delta is real.
 - **Don't run two unify jobs concurrently.** The `gbrain-unify` db-lock serializes them; the second submission rejects with "already in progress."
 
-## Decision tree
+## Decision tree (( inert ))
 
 ```
 Active pack already gbrain-base-v2?
@@ -183,7 +183,7 @@
     edit mapping_rules in your fork, then target the fork.
 ```
 
-## Contract
+## Contract (( inert, role: invariants ))
 
 Inputs:
 - A brain on `gbrain-base` (or any pack with `migration_from: gbrain-base-v2`).
@@ -206,7 +206,7 @@
 - Catch-all retype excludes `page_to_link` + `page_to_alias` source types (caught in E2E pre-merge).
 - Phase failures abort the run before `active_pack_flipped`; partial state restorable via op_checkpoint resume.
 
-## Anti-Patterns
+## Anti-Patterns (( inert, role: prohibitions ))
 
 DON'T:
 - Submit `unify-types` directly via the MCP `submit_job` op without `--allow-protected`. PROTECTED handlers require trusted local callers; remote MCP rejection is the intentional trust boundary.
@@ -243,7 +243,7 @@
 
 JSON output (`gbrain jobs follow <id> --json`) returns the structured `UnifyTypesResult` shape with `per_phase`, `pack_identity_after`, `active_pack_flipped`.
 
-## Reference
+## Reference (( inert ))
 
 - Plan + decisions: `~/.claude/plans/system-instruction-you-are-working-transient-elephant.md`
 - Architecture: `docs/architecture/type-taxonomy.md`
```
