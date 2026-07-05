# Deviation: schema_unify.meri

- Original: `schema-unify/SKILL.md`
- Ported: `schema_unify.meri`
- Tier: 2 (light edits)
- Similarity: 69%
- Lines: 252 -> 297 (+108 / -63)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- preamble-blockquoted
- doc-section-marked

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L8 `brain_first: exempt`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L12 `When this skill fires`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L19 `Mental model (one paragraph)`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L175 `Decision tree`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L198 `Contract`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L236 `Output Format`: template - Template/output shape is metadata unless explicit output assertions are authored.
- L264 `Reference`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.

## Metrics
- Sections inert total: 15/15 (100% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert markers (`(( inert ))`, target 0 — the migrator never emits these): 0
- Inert categories: reference-documentation=14, template=1
- Judgment: 0 blocks, 0 lines

### Inert section details
- L8 `brain_first: exempt`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L12 `When this skill fires`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L19 `Mental model (one paragraph)`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L25 `Phase 1: Discovery`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L49 `Phase 2: Preview`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L68 `Phase 3: Apply`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L106 `Phase 4: Verify`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L125 `Phase 5: Post-migration`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L134 `Rollback`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L161 `Anti-patterns`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L175 `Decision tree`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L198 `Contract`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L221 `Anti-Patterns`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L236 `Output Format`: template — Template/output shape is metadata unless explicit output assertions are authored.
- L264 `Reference`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.

## Unified diff

```diff
--- original-skills/schema-unify/SKILL.md
+++ skills/schema_unify.meri
@@ -28,28 +28,35 @@
 
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
+## brain_first: exempt (( role: reference ))
 
 This skill is ABOUT the brain's shape — it can't depend on the brain it's reshaping. No `gbrain search` lookup first; jump straight to onboard.
 
-## When this skill fires
+## When this skill fires (( role: reference ))
 
 - Agent runs `gbrain onboard --check` and sees `pack_upgrade_available` or `type_proliferation` warnings
 - User asks "what is the canonical taxonomy / how do I clean up my page types / migrate to v2"
 - A `dangling_aliases` finding surfaces (post-unify GC)
 - An agent ingesting from a custom pack wants to consult the v2 taxonomy as a reference
 
-## Mental model (one paragraph)
+## Mental model (one paragraph) (( role: reference ))
 
 A production gbrain brain accreted **94 distinct `pages.type` values** over years of ingestion: tweet / tweet-thread / tweet-bundle / tweet-single / media/x-tweet/bundle / tweet-stub all coexisting; 5.5K concept-redirect pages; atom-partner-link pages that should be links; civic / framework / insight / memo / anecdote one-offs. The cure: collapse to **15 canonical types** (person, company, media, tweet, social-digest, analysis, atom, concept, source, deal, email, slack, writing, project, note) with subtypes/format/origin pushed to frontmatter, alias-rows for redirects, real link-rows for edge-shaped pages, and a catch-all that bins long-tail unknowns to `note` with `frontmatter.legacy_type = <original>` for rollback.
 
 ## Workflow
 
-### Phase 1: Discovery
+### Phase 1: Discovery (( role: reference ))
+
+Expected: `gbrain-base@1.0.0+<sha>`. If you see `gbrain-base-v2@...`, the brain is already on v2 — skip the migration.
+
+Look for the `pack_upgrade_available` finding. If it's `ok`, there's no successor declared for the active pack — done.
+
+
+### Phase 1: Discovery — steps
 
 Confirm the brain is actually on `gbrain-base` (not already on v2).
 
@@ -57,25 +64,17 @@
 gbrain schema active --json | jq -r '.identity'
 ```
 
-Expected: `gbrain-base@1.0.0+<sha>`. If you see `gbrain-base-v2@...`, the brain is already on v2 — skip the migration.
-
-Then run onboard to see what would change:
+
+### Phase 1: Discovery — steps 2
+
+> Then run onboard to see what would change:
 
 ```bash
 gbrain onboard --check
 ```
 
-Look for the `pack_upgrade_available` finding. If it's `ok`, there's no successor declared for the active pack — done.
-
-### Phase 2: Preview
-
-Run the per-cluster narrative:
-
-```bash
-gbrain onboard --check --explain
-```
-
-This invokes the `unify-types` handler in dry-run mode and prints:
+### Phase 2: Preview (( role: reference ))
+
 - How many pages would retype per cluster (tweets, articles, companies, etc.)
 - How many concept-redirect pages would become alias rows
 - How many edge-shaped pages would convert to real links
@@ -83,26 +82,21 @@
 
 Review the output. If the proposed changes look wrong, **don't** proceed — file an issue or write a custom pack with adjusted mapping_rules.
 
-### Phase 3: Apply
-
-The handler is PROTECTED (manual_only per D17) — autopilot will never auto-fire it. Submit explicitly:
-
-```bash
-gbrain jobs submit unify-types \
-  --allow-protected \
-  --params '{"target_pack":"gbrain-base-v2"}'
-```
-
-Watch progress per phase:
-
-```bash
-gbrain jobs follow <job_id>
-```
+
+### Phase 2: Preview — steps
+
+> Run the per-cluster narrative:
+
+```bash
+gbrain onboard --check --explain
+```
+
+This invokes the `unify-types` handler in dry-run mode and prints:
+### Phase 3: Apply (( role: reference ))
 
 On a 186K-page brain expect ~10 minutes. The handler runs:
 1. Preflight (validate target pack has `mapping_rules:`)
 2. Stats snapshot (pre-state for celebration summary)
-3. Acquire `gbrain-unify` db-lock (60min TTL)
 4. Apply phases:
    - Explicit retype rules (tweets, articles, companies, etc.)
    - Catch-all retype (unknown types → note with legacy_type)
@@ -110,57 +104,102 @@
    - Page-to-alias rules (concept-redirect)
 5. Final sync (untyped rows by path-prefix)
 6. **Flip active pack** to gbrain-base-v2 (D13)
+
+### Phase 3: Apply — steps (( role: reference ))
+
+The handler is PROTECTED (manual_only per D17) — autopilot will never auto-fire it. Submit explicitly:
+
+```bash
+gbrain jobs submit unify-types \
+  --allow-protected \
+  --params '{"target_pack":"gbrain-base-v2"}'
+```
+
+> Watch progress per phase:
+
+```bash
+gbrain jobs follow <job_id>
+```
+
+
+### Phase 3: Apply — steps 2
+
+3. Acquire `gbrain-unify` db-lock (60min TTL)
+
+### Phase 3: Apply — steps 3
+
 7. Verify + celebration summary
 
-### Phase 4: Verify
-
-```bash
-gbrain onboard --check
-gbrain schema stats
-```
+### Phase 4: Verify (( role: reference ))
 
 Expected:
 - `pack_upgrade_available` → `ok` (active pack is now v2)
 - `type_proliferation` → `ok` (≤16 distinct typed values)
 - `dangling_aliases` → `ok` (slug_aliases all point at active canonicals)
+
+### Phase 4: Verify — steps
+
+```bash
+gbrain onboard --check
+gbrain schema stats
+```
+
+
+### Phase 4: Verify — steps 2
+
 - `gbrain schema stats` shows ≤16 distinct types
 
-### Phase 5: Post-migration
+### Phase 5: Post-migration (( role: reference ))
 
 Anything that used `--type article` keeps working post-unify if your CLI calls go through the `expandTypeFilter` helper (it expands `article` to `media+subtype=article` automatically). Direct SQL against `pages.type` needs updating to the canonical types.
 
+
+### Phase 5: Post-migration — steps
+
 Search queries get a small ranking signal: pages reached via `slug_aliases` (canonicals of one or more aliases) get a 1.05x boost. Visible via `gbrain search --explain`.
 
-## Rollback
-
-Every retyped page preserves `frontmatter.legacy_type = <original>` per D8. Restore types via:
+## Rollback (( role: reference ))
 
 ```sql
 UPDATE pages SET type = frontmatter->>'legacy_type'
 WHERE source_id = 'default' AND frontmatter->>'legacy_type' IS NOT NULL;
 ```
 
-Page-to-alias and page-to-link source pages soft-delete with 72h TTL. Restore within that window:
+
+### Rollback — steps
+
+Every retyped page preserves `frontmatter.legacy_type = <original>` per D8. Restore types via:
+
+
+### Rollback — steps 2
+
+> Page-to-alias and page-to-link source pages soft-delete with 72h TTL. Restore within that window:
 
 ```bash
 gbrain pages restore <slug>
 ```
 
-Revert the active pack flip:
+> Revert the active pack flip:
 
 ```bash
 gbrain schema use gbrain-base
 ```
 
-## Anti-patterns
-
-- **Don't run unify-types under autopilot.** It's manual_only by design. Autopilot remediation should never silently change your taxonomy.
+## Anti-patterns (( role: reference ))
+
 - **Don't expect mapping_rules to cover every legacy type explicitly.** Use the catch-all (`*unknown*`) for the long tail. Pages get retyped to `note` with `legacy_type` preserved.
 - **Don't rewrite body-text wikilinks.** D15: the slug_aliases table IS the resolver. `[[old-redirect-slug]]` keeps working via `engine.resolveSlugWithAlias` short-circuit.
-- **Don't bypass the dry-run.** Always run `--explain` before applying. The trust delta is real.
 - **Don't run two unify jobs concurrently.** The `gbrain-unify` db-lock serializes them; the second submission rejects with "already in progress."
 
-## Decision tree
+
+### Anti-patterns — steps (( role: reference ))
+
+- It's manual_only by design. Autopilot remediation should never silently change your taxonomy.
+
+### Anti-patterns — steps 2 (( role: reference ))
+
+- Don't bypass the dry-run. Always run `--explain` before applying. The trust delta is real.
+## Decision tree (( role: reference ))
 
 ```
 Active pack already gbrain-base-v2?
@@ -183,7 +222,7 @@
     edit mapping_rules in your fork, then target the fork.
 ```
 
-## Contract
+## Contract (( role: reference ))
 
 Inputs:
 - A brain on `gbrain-base` (or any pack with `migration_from: gbrain-base-v2`).
@@ -206,16 +245,22 @@
 - Catch-all retype excludes `page_to_link` + `page_to_alias` source types (caught in E2E pre-merge).
 - Phase failures abort the run before `active_pack_flipped`; partial state restorable via op_checkpoint resume.
 
-## Anti-Patterns
-
-DON'T:
-- Submit `unify-types` directly via the MCP `submit_job` op without `--allow-protected`. PROTECTED handlers require trusted local callers; remote MCP rejection is the intentional trust boundary.
+## Anti-Patterns (( role: reference ))
+
 - Edit `mapping_rules` in `gbrain-base-v2.yaml` to skip clusters you don't trust. Fork the pack instead (`gbrain schema fork`) so the source-of-truth migration stays consistent across brains.
-- Run `unify-types` from inside an autopilot tick. The check is `manual_only` per D17 — autopilot deliberately never auto-fires it because pack upgrades are one-time consenting taxonomy decisions.
 - Hard-delete soft-deleted source pages before the 72h restore window. Use `gbrain pages restore <slug>` first if rollback is needed.
 - Assume `frontmatter.legacy_type` survives every roundtrip. The marker is canonical for the immediate post-migration window; downstream re-imports may overwrite it.
 
-## Output Format
+
+### Anti-Patterns — steps (( role: reference ))
+
+> DON'T:
+- Submit `unify-types` directly via the MCP `submit_job` op without `--allow-protected`. PROTECTED handlers require trusted local callers; remote MCP rejection is the intentional trust boundary.
+
+### Anti-Patterns — steps 2 (( role: reference ))
+
+- Run `unify-types` from inside an autopilot tick. The check is `manual_only` per D17 — autopilot deliberately never auto-fires it because pack upgrades are one-time consenting taxonomy decisions.
+## Output Format (( role: template ))
 
 Per phase, the handler emits to stderr:
 ```
@@ -243,7 +288,7 @@
 
 JSON output (`gbrain jobs follow <id> --json`) returns the structured `UnifyTypesResult` shape with `per_phase`, `pack_identity_after`, `active_pack_flipped`.
 
-## Reference
+## Reference (( role: reference ))
 
 - Plan + decisions: `~/.claude/plans/system-instruction-you-are-working-transient-elephant.md`
 - Architecture: `docs/architecture/type-taxonomy.md`
```
