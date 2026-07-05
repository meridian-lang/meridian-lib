# Deviation: schema_author.meri

- Original: `schema-author/SKILL.md`
- Ported: `schema_author.meri`
- Tier: 2 (light edits)
- Similarity: 83%
- Lines: 306 -> 330 (+66 / -42)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- doc-section-marked

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L23 `Convention`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L29 `When to invoke`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L42 `Tutorial + vision`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L82 `Phase 3 — Propose (what types should the pack add?)`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L98 `Phase 4 — Apply (mutate the pack)`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L159 `Phase 6 — Verify`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L176 `Phase 7 — Commit (preserve the change)`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L202 `Contract`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L230 `Output Format`: template - Template/output shape is metadata unless explicit output assertions are authored.
- L261 `Failure modes`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.

## Metrics
- Sections inert total: 16/16 (100% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert markers (`(( inert ))`, target 0 — the migrator never emits these): 0
- Inert categories: reference-documentation=15, template=1
- Judgment: 0 blocks, 0 lines

### Inert section details
- L4 `Non-goals (use these other skills instead)`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L23 `Convention`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L29 `When to invoke`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L42 `Tutorial + vision`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L49 `Phase 1 — Brain (know which pack is active)`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L62 `Phase 2 — Assess (what does the current pack cover?)`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L82 `Phase 3 — Propose (what types should the pack add?)`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L98 `Phase 4 — Apply (mutate the pack)`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L138 `Phase 5 — Sync (backfill existing pages with the new types)`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L159 `Phase 6 — Verify`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L176 `Phase 7 — Commit (preserve the change)`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L191 `Outputs`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L202 `Contract`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L211 `Anti-Patterns`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L230 `Output Format`: template — Template/output shape is metadata unless explicit output assertions are authored.
- L261 `Failure modes`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.

## Unified diff

```diff
--- original-skills/schema-author/SKILL.md
+++ skills/schema_author.meri
@@ -57,29 +57,32 @@
 
 # schema-author — evolve your schema pack
 
-## Non-goals (use these other skills instead)
-
-This skill AUTHORS the schema pack (adds page types, link verbs, prefixes,
-flags). For these adjacent jobs, route elsewhere:
-
-- **Filing one specific page** → `skills/brain-taxonomist/SKILL.md`. Brain-
-  taxonomist routes at WRITE TIME ("where does this note go?"). schema-author
-  changes the rules at AUTHORING TIME ("what types and prefixes exist?").
-- **Schema-check as part of EIIRP iteration** → `skills/eiirp/SKILL.md`
-  already has a schema-check phase. Don't duplicate.
+## Non-goals (use these other skills instead) (( role: reference ))
+
 - **Just looking up a type's settings** → `gbrain schema explain <type>`
   directly. This skill is for CHANGING the pack, not READING from it.
 - **Querying who knows about X** → `skills/expert-routing/SKILL.md` (or
   `gbrain whoknows` directly). schema-author makes a type expert-routable;
   it does not run the query.
 
-## Convention
+
+### Non-goals (use these other skills instead) — steps (( role: reference ))
+
+> This skill AUTHORS the schema pack (adds page types, link verbs, prefixes,
+> flags). For these adjacent jobs, route elsewhere:
+
+- Filing one specific page → `skills/brain-taxonomist/SKILL.md`. Brain-
+  taxonomist routes at WRITE TIME ("where does this note go?"). schema-author
+  changes the rules at AUTHORING TIME ("what types and prefixes exist?").
+- Schema-check as part of EIIRP iteration → `skills/eiirp/SKILL.md`
+  already has a schema-check phase. Don't duplicate.
+## Convention (( role: reference ))
 
 > **Convention:** see [conventions/brain-first.md](../conventions/brain-first.md) for the lookup chain (search → query → get_page → external).
 
 > **Convention:** see [conventions/schema-evolution.md](../conventions/schema-evolution.md) for "when to add a type vs alias vs prefix" — the heuristic.
 
-## When to invoke
+## When to invoke (( role: reference ))
 
 Invoke when the user (or a sibling skill) says any of:
 - "Add a `researcher` type to my schema"
@@ -92,24 +95,27 @@
 DON'T invoke for "where does THIS note go" (use brain-taxonomist) or
 "who knows about X" (use expert-routing / `gbrain whoknows`).
 
-## Tutorial + vision
+## Tutorial + vision (( role: reference ))
 
 - **Why this matters:** [`docs/what-schemas-unlock.md`](../../docs/what-schemas-unlock.md) — 7 killer use cases (4000 invisible meetings made queryable, founder ops brain, research brain, legal brain, team brain, agent-as-co-curator) plus the structural argument for why types matter at query time. Read this before pitching schema authoring to a user — it's the doc that explains the difference between a pile of notes and a brain with structure.
 - **5-minute walkthrough:** [`docs/schema-author-tutorial.md`](../../docs/schema-author-tutorial.md) — fork the bundled pack, add a researcher type, sync, prove the T1.5 wiring via `gbrain whoknows`. Use placeholder pages so it runs against any brain without affecting real content.
 
 ## Workflow
 
-### Phase 1 — Brain (know which pack is active)
+### Phase 1 — Brain (know which pack is active) (( role: reference ))
 
 ```
 gbrain schema active --json
 ```
 
 Output gives you `pack_name`, `version`, `sha8`, `page_types_count`, `source_tier`.
+
+### Phase 1 — Brain (know which pack is active) — steps (( role: reference ))
+
 If `source_tier === "default"`, the user is on bundled `gbrain-base` and any
 mutation will need a fork first (Phase 4).
 
-### Phase 2 — Assess (what does the current pack cover?)
+### Phase 2 — Assess (what does the current pack cover?) (( role: reference ))
 
 ```
 gbrain schema stats --json
@@ -123,10 +129,13 @@
 gbrain schema review-orphans --limit 50 --json
 ```
 
+
+### Phase 2 — Assess (what does the current pack cover?) — steps (( role: reference ))
+
 Untyped pages drilldown. Look for shared path prefixes (e.g. "12 of these
 are under `research/papers/`") — those are candidates for a new type.
 
-### Phase 3 — Propose (what types should the pack add?)
+### Phase 3 — Propose (what types should the pack add?) (( role: reference ))
 
 ```
 gbrain schema detect --json
@@ -142,7 +151,7 @@
 LLM-refined candidates with confidence scores. Use the top-3 hit rate as
 the signal for which to promote.
 
-### Phase 4 — Apply (mutate the pack)
+### Phase 4 — Apply (mutate the pack) (( role: reference ))
 
 If the active pack is bundled (`gbrain-base` or `gbrain-recommended`),
 fork it first:
@@ -182,7 +191,7 @@
 (`extractable_empty_corpus`, `mutation_count_anomaly`) that detect
 mis-declared types you'd otherwise discover only at runtime.
 
-### Phase 5 — Sync (backfill existing pages with the new types)
+### Phase 5 — Sync (backfill existing pages with the new types) (( role: reference ))
 
 Dry-run first:
 
@@ -197,10 +206,13 @@
 gbrain schema sync --apply
 ```
 
+
+### Phase 5 — Sync (backfill existing pages with the new types) — steps (( role: reference ))
+
 Chunked UPDATE in 1000-row batches; never wedges concurrent writers.
 Idempotent on re-run (second `--apply` finds nothing to backfill).
 
-### Phase 6 — Verify
+### Phase 6 — Verify (( role: reference ))
 
 ```
 gbrain schema stats --json
@@ -217,7 +229,7 @@
 added in v0.40.6.0 — pre-v0.40.6 brains silently ignored custom
 expert-routed types.)
 
-### Phase 7 — Commit (preserve the change)
+### Phase 7 — Commit (preserve the change) (( role: reference ))
 
 If the pack is in source control, commit:
 
@@ -232,34 +244,46 @@
 pick up the change within 1 second (stat-mtime TTL gate in
 loadActivePack — v0.40.6.0 closed the cross-process invalidation gap).
 
-## Outputs
+## Outputs (( role: reference ))
+
+- Query paths (`whoknows`, `find_experts`) now route through the new
+  expert types.
+
+
+### Outputs — steps
 
 - Mutated pack file at `~/.gbrain/schema-packs/<name>/pack.{json,yaml}`.
 - Audit row in `~/.gbrain/audit/schema-mutations-YYYY-Www.jsonl` per mutation.
 - `pages.type` backfilled on matching rows after `sync --apply`.
-- Query paths (`whoknows`, `find_experts`) now route through the new
-  expert types.
-
-## Contract
-
-- **Inputs:** a natural-language request that names a type / prefix / link verb / flag change, OR the result of `gbrain schema review-orphans` showing untyped pages that need a new type.
-- **Outputs:** mutated pack file at `~/.gbrain/schema-packs/<name>/pack.{json,yaml}` + an audit row in `~/.gbrain/audit/schema-mutations-YYYY-Www.jsonl` + (if `sync --apply` ran) backfilled `pages.type` on matching rows.
-- **Side effects:** invalidates the in-process pack cache + the query cache for the source. Other processes pick up the change within 1 second (stat-mtime TTL).
-- **Idempotency:** every primitive is idempotent. `add-alias`/`add-prefix` no-op on duplicate; `sync --apply` finds nothing to update on second run.
-- **Trust:** CLI = local trust (no scope check). MCP = OAuth `admin` scope (write ops). Audit log captures `actor: mcp:<clientId8>` per mutation.
-- **Atomicity:** every mutation is wrapped in `withMutation`'s atomic write (`.tmp + fsync + rename`) + per-pack `O_CREAT|O_EXCL` lock. Crash mid-write leaves the original file untouched.
-
-## Anti-Patterns
-
-- **Don't mutate `gbrain-base` or `gbrain-recommended`.** Fork first (`gbrain schema fork gbrain-base mine`). These are bundled packs; edits would be lost on upgrade. The mutation primitives refuse with `PACK_READONLY`.
+## Contract (( role: reference ))
+
+- Inputs: a natural-language request that names a type / prefix / link verb / flag change, OR the result of `gbrain schema review-orphans` showing untyped pages that need a new type.
+- Outputs: mutated pack file at `~/.gbrain/schema-packs/<name>/pack.{json,yaml}` + an audit row in `~/.gbrain/audit/schema-mutations-YYYY-Www.jsonl` + (if `sync --apply` ran) backfilled `pages.type` on matching rows.
+- Side effects: invalidates the in-process pack cache + the query cache for the source. Other processes pick up the change within 1 second (stat-mtime TTL).
+- Idempotency: every primitive is idempotent. `add-alias`/`add-prefix` no-op on duplicate; `sync --apply` finds nothing to update on second run.
+- Trust: CLI = local trust (no scope check). MCP = OAuth `admin` scope (write ops). Audit log captures `actor: mcp:<clientId8>` per mutation.
+- Atomicity: every mutation is wrapped in `withMutation`'s atomic write (`.tmp + fsync + rename`) + per-pack `O_CREAT|O_EXCL` lock. Crash mid-write leaves the original file untouched.
+
+## Anti-Patterns (( role: reference ))
+
 - **Don't add a type for a directory you imported once for triage.** Pack types are permanent decisions; one-time imports are not. See `skills/conventions/schema-evolution.md` for the <20-pages-don't-pack-codify heuristic.
-- **Don't add `--expert` to a type with no `path_prefixes`.** The `expert_routing_without_prefix` lint warns about this — expert-routed types with no prefix never match a put_page inference, so `whoknows` silently never surfaces them.
 - **Don't promote a `schema suggest` candidate without verifying the prefix matches real content.** Run `lint --with-db` before `add-type` to catch prefix collisions pre-write.
 - **Don't conflate "filing one page" with "evolving the schema."** Filing routes via `brain-taxonomist`; schema-author is for authoring the type taxonomy itself. The Non-goals section above names the boundary.
-- **Don't skip the dry-run before `sync --apply`.** Always run `sync` first to see `would_apply` counts + sample slugs. A pack prefix that matches 50,000 pages is recoverable but slow; verifying first is cheap.
-- **Don't remove a type without checking references.** `remove-type` refuses with `STILL_REFERENCED` if another type's `aliases` / `enrichable_types` / `link_types` / `frontmatter_links` references it. Break the references first; don't add `--force`.
-
-## Output Format
+
+### Anti-Patterns — steps (( role: reference ))
+
+- Don't mutate `gbrain-base` or `gbrain-recommended`. Fork first (`gbrain schema fork gbrain-base mine`). These are bundled packs; edits would be lost on upgrade. The mutation primitives refuse with `PACK_READONLY`.
+
+### Anti-Patterns — steps 2 (( role: reference ))
+
+- Don't add `--expert` to a type with no `path_prefixes`. The `expert_routing_without_prefix` lint warns about this — expert-routed types with no prefix never match a put_page inference, so `whoknows` silently never surfaces them.
+
+### Anti-Patterns — steps 3 (( role: reference ))
+
+- Don't skip the dry-run before `sync --apply`. Always run `sync` first to see `would_apply` counts + sample slugs. A pack prefix that matches 50,000 pages is recoverable but slow; verifying first is cheap.
+- Don't remove a type without checking references. `remove-type` refuses with `STILL_REFERENCED` if another type's `aliases` / `enrichable_types` / `link_types` / `frontmatter_links` references it. Break the references first; don't add `--force`.
+
+## Output Format (( role: template ))
 
 When invoked, this skill produces structured output suitable for both human + JSON consumption:
 
@@ -290,7 +314,7 @@
 
 On failure, the error envelope follows the standard `StructuredAgentError` shape from `src/core/errors.ts`: `{error, code, message, details?}`. Codes from the mutation primitives: `PACK_NOT_FOUND`, `PACK_READONLY`, `PACK_CORRUPT`, `TYPE_EXISTS`, `TYPE_NOT_FOUND`, `INVALID_PRIMITIVE`, `INVALID_RESULT`, `IO_ERROR`, `STILL_REFERENCED`, `LOCK_BUSY`.
 
-## Failure modes
+## Failure modes (( role: reference ))
 
 - `PACK_READONLY` → you tried to mutate `gbrain-base` or `gbrain-recommended`. Fork first.
 - `INVALID_RESULT` → the mutation would create a dangling reference or
```
