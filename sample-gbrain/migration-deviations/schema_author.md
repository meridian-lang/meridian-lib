# Deviation: schema_author.meri

- Original: `schema-author/SKILL.md`
- Ported: `schema_author.meri`
- Tier: 1 (near-verbatim)
- Similarity: 95%
- Lines: 306 -> 306 (+15 / -15)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added

## Metrics
- Sections: 16/17 inert (94% inert ratio)
- Judgment: 0 blocks, 0 lines

## Unified diff

```diff
--- original-skills/schema-author/SKILL.md
+++ schema_author.meri
@@ -57,7 +57,7 @@
 
 # schema-author — evolve your schema pack
 
-## Non-goals (use these other skills instead)
+## Non-goals (use these other skills instead) (( inert ))
 
 This skill AUTHORS the schema pack (adds page types, link verbs, prefixes,
 flags). For these adjacent jobs, route elsewhere:
@@ -73,13 +73,13 @@
   `gbrain whoknows` directly). schema-author makes a type expert-routable;
   it does not run the query.
 
-## Convention
+## Convention (( inert ))
 
 > **Convention:** see [conventions/brain-first.md](../conventions/brain-first.md) for the lookup chain (search → query → get_page → external).
 
 > **Convention:** see [conventions/schema-evolution.md](../conventions/schema-evolution.md) for "when to add a type vs alias vs prefix" — the heuristic.
 
-## When to invoke
+## When to invoke (( inert, role: applicability ))
 
 Invoke when the user (or a sibling skill) says any of:
 - "Add a `researcher` type to my schema"
@@ -92,14 +92,14 @@
 DON'T invoke for "where does THIS note go" (use brain-taxonomist) or
 "who knows about X" (use expert-routing / `gbrain whoknows`).
 
-## Tutorial + vision
+## Tutorial + vision (( inert ))
 
 - **Why this matters:** [`docs/what-schemas-unlock.md`](../../docs/what-schemas-unlock.md) — 7 killer use cases (4000 invisible meetings made queryable, founder ops brain, research brain, legal brain, team brain, agent-as-co-curator) plus the structural argument for why types matter at query time. Read this before pitching schema authoring to a user — it's the doc that explains the difference between a pile of notes and a brain with structure.
 - **5-minute walkthrough:** [`docs/schema-author-tutorial.md`](../../docs/schema-author-tutorial.md) — fork the bundled pack, add a researcher type, sync, prove the T1.5 wiring via `gbrain whoknows`. Use placeholder pages so it runs against any brain without affecting real content.
 
 ## Workflow
 
-### Phase 1 — Brain (know which pack is active)
+### Phase 1 — Brain (know which pack is active) (( inert, role: procedure ))
 
 ```
 gbrain schema active --json
@@ -109,7 +109,7 @@
 If `source_tier === "default"`, the user is on bundled `gbrain-base` and any
 mutation will need a fork first (Phase 4).
 
-### Phase 2 — Assess (what does the current pack cover?)
+### Phase 2 — Assess (what does the current pack cover?) (( inert, role: procedure ))
 
 ```
 gbrain schema stats --json
@@ -126,7 +126,7 @@
 Untyped pages drilldown. Look for shared path prefixes (e.g. "12 of these
 are under `research/papers/`") — those are candidates for a new type.
 
-### Phase 3 — Propose (what types should the pack add?)
+### Phase 3 — Propose (what types should the pack add?) (( inert, role: procedure ))
 
 ```
 gbrain schema detect --json
@@ -142,7 +142,7 @@
 LLM-refined candidates with confidence scores. Use the top-3 hit rate as
 the signal for which to promote.
 
-### Phase 4 — Apply (mutate the pack)
+### Phase 4 — Apply (mutate the pack) (( inert, role: procedure ))
 
 If the active pack is bundled (`gbrain-base` or `gbrain-recommended`),
 fork it first:
@@ -182,7 +182,7 @@
 (`extractable_empty_corpus`, `mutation_count_anomaly`) that detect
 mis-declared types you'd otherwise discover only at runtime.
 
-### Phase 5 — Sync (backfill existing pages with the new types)
+### Phase 5 — Sync (backfill existing pages with the new types) (( inert, role: procedure ))
 
 Dry-run first:
 
@@ -200,7 +200,7 @@
 Chunked UPDATE in 1000-row batches; never wedges concurrent writers.
 Idempotent on re-run (second `--apply` finds nothing to backfill).
 
-### Phase 6 — Verify
+### Phase 6 — Verify (( inert, role: procedure ))
 
 ```
 gbrain schema stats --json
@@ -217,7 +217,7 @@
 added in v0.40.6.0 — pre-v0.40.6 brains silently ignored custom
 expert-routed types.)
 
-### Phase 7 — Commit (preserve the change)
+### Phase 7 — Commit (preserve the change) (( inert, role: procedure ))
 
 If the pack is in source control, commit:
 
@@ -232,7 +232,7 @@
 pick up the change within 1 second (stat-mtime TTL gate in
 loadActivePack — v0.40.6.0 closed the cross-process invalidation gap).
 
-## Outputs
+## Outputs (( inert ))
 
 - Mutated pack file at `~/.gbrain/schema-packs/<name>/pack.{json,yaml}`.
 - Audit row in `~/.gbrain/audit/schema-mutations-YYYY-Www.jsonl` per mutation.
@@ -240,7 +240,7 @@
 - Query paths (`whoknows`, `find_experts`) now route through the new
   expert types.
 
-## Contract
+## Contract (( inert, role: invariants ))
 
 - **Inputs:** a natural-language request that names a type / prefix / link verb / flag change, OR the result of `gbrain schema review-orphans` showing untyped pages that need a new type.
 - **Outputs:** mutated pack file at `~/.gbrain/schema-packs/<name>/pack.{json,yaml}` + an audit row in `~/.gbrain/audit/schema-mutations-YYYY-Www.jsonl` + (if `sync --apply` ran) backfilled `pages.type` on matching rows.
@@ -249,7 +249,7 @@
 - **Trust:** CLI = local trust (no scope check). MCP = OAuth `admin` scope (write ops). Audit log captures `actor: mcp:<clientId8>` per mutation.
 - **Atomicity:** every mutation is wrapped in `withMutation`'s atomic write (`.tmp + fsync + rename`) + per-pack `O_CREAT|O_EXCL` lock. Crash mid-write leaves the original file untouched.
 
-## Anti-Patterns
+## Anti-Patterns (( inert, role: prohibitions ))
 
 - **Don't mutate `gbrain-base` or `gbrain-recommended`.** Fork first (`gbrain schema fork gbrain-base mine`). These are bundled packs; edits would be lost on upgrade. The mutation primitives refuse with `PACK_READONLY`.
 - **Don't add a type for a directory you imported once for triage.** Pack types are permanent decisions; one-time imports are not. See `skills/conventions/schema-evolution.md` for the <20-pages-don't-pack-codify heuristic.
@@ -290,7 +290,7 @@
 
 On failure, the error envelope follows the standard `StructuredAgentError` shape from `src/core/errors.ts`: `{error, code, message, details?}`. Codes from the mutation primitives: `PACK_NOT_FOUND`, `PACK_READONLY`, `PACK_CORRUPT`, `TYPE_EXISTS`, `TYPE_NOT_FOUND`, `INVALID_PRIMITIVE`, `INVALID_RESULT`, `IO_ERROR`, `STILL_REFERENCED`, `LOCK_BUSY`.
 
-## Failure modes
+## Failure modes (( inert ))
 
 - `PACK_READONLY` → you tried to mutate `gbrain-base` or `gbrain-recommended`. Fork first.
 - `INVALID_RESULT` → the mutation would create a dangling reference or
```
