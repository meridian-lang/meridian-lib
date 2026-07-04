# Deviation: schema_author.meri

- Original: `schema-author/SKILL.md`
- Ported: `schema_author.meri`
- Tier: 1 (near-verbatim)
- Similarity: 91%
- Lines: 306 -> 326 (+40 / -20)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- shell-block-routed
- inert-section-added

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L23 `Convention`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L226 `Output Format`: template - Template/output shape is metadata unless explicit output assertions are authored.
- L257 `Failure modes`: reference-documentation - Reference documentation, rationale, examples, or changelog.

## Metrics
- Sections inert total: 5/17 (29% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert categories: reference-documentation=4, template=1
- Judgment: 11 blocks, 0 lines

### Inert section details
- L4 `Non-goals (use these other skills instead)`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L23 `Convention`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L194 `Outputs`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L226 `Output Format`: template — Template/output shape is metadata unless explicit output assertions are authored.
- L257 `Failure modes`: reference-documentation — Reference documentation, rationale, examples, or changelog.

## Unified diff

```diff
--- original-skills/schema-author/SKILL.md
+++ skills/schema_author.meri
@@ -57,29 +57,33 @@
 
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
+## Non-goals (use these other skills instead) (( inert ))
+
 - **Just looking up a type's settings** → `gbrain schema explain <type>`
   directly. This skill is for CHANGING the pack, not READING from it.
 - **Querying who knows about X** → `skills/expert-routing/SKILL.md` (or
   `gbrain whoknows` directly). schema-author makes a type expert-routable;
   it does not run the query.
 
-## Convention
+
+### Non-goals (use these other skills instead) — steps (( inert ))
+
+> This skill AUTHORS the schema pack (adds page types, link verbs, prefixes,
+> flags). For these adjacent jobs, route elsewhere:
+
+- Filing one specific page → `skills/brain-taxonomist/SKILL.md`. Brain-
+  taxonomist routes at WRITE TIME ("where does this note go?"). schema-author
+  changes the rules at AUTHORING TIME ("what types and prefixes exist?").
+- Schema-check as part of EIIRP iteration → `skills/eiirp/SKILL.md`
+  already has a schema-check phase. Don't duplicate.
+## Convention (( inert ))
 
 > **Convention:** see [conventions/brain-first.md](../conventions/brain-first.md) for the lookup chain (search → query → get_page → external).
 
 > **Convention:** see [conventions/schema-evolution.md](../conventions/schema-evolution.md) for "when to add a type vs alias vs prefix" — the heuristic.
 
-## When to invoke
+## When to invoke (( role: procedure ))
+use judgment to follow the When to invoke guidance:
 
 Invoke when the user (or a sibling skill) says any of:
 - "Add a `researcher` type to my schema"
@@ -98,18 +102,24 @@
 - **5-minute walkthrough:** [`docs/schema-author-tutorial.md`](../../docs/schema-author-tutorial.md) — fork the bundled pack, add a researcher type, sync, prove the T1.5 wiring via `gbrain whoknows`. Use placeholder pages so it runs against any brain without affecting real content.
 
 ## Workflow
+use judgment to follow the Workflow guidance:
 
 ### Phase 1 — Brain (know which pack is active)
+use judgment to follow the Phase 1 — Brain (know which pack is active) guidance:
 
 ```
 gbrain schema active --json
 ```
 
 Output gives you `pack_name`, `version`, `sha8`, `page_types_count`, `source_tier`.
+
+#### Phase 1 — Brain (know which pack is active) — steps
+
 If `source_tier === "default"`, the user is on bundled `gbrain-base` and any
 mutation will need a fork first (Phase 4).
 
 ### Phase 2 — Assess (what does the current pack cover?)
+use judgment to follow the Phase 2 — Assess (what does the current pack cover?) guidance:
 
 ```
 gbrain schema stats --json
@@ -127,6 +137,7 @@
 are under `research/papers/`") — those are candidates for a new type.
 
 ### Phase 3 — Propose (what types should the pack add?)
+use judgment to follow the Phase 3 — Propose (what types should the pack add?) guidance:
 
 ```
 gbrain schema detect --json
@@ -143,6 +154,7 @@
 the signal for which to promote.
 
 ### Phase 4 — Apply (mutate the pack)
+use judgment to follow the Phase 4 — Apply (mutate the pack) guidance:
 
 If the active pack is bundled (`gbrain-base` or `gbrain-recommended`),
 fork it first:
@@ -183,6 +195,7 @@
 mis-declared types you'd otherwise discover only at runtime.
 
 ### Phase 5 — Sync (backfill existing pages with the new types)
+use judgment to follow the Phase 5 — Sync (backfill existing pages with the new types) guidance:
 
 Dry-run first:
 
@@ -201,6 +214,7 @@
 Idempotent on re-run (second `--apply` finds nothing to backfill).
 
 ### Phase 6 — Verify
+use judgment to follow the Phase 6 — Verify guidance:
 
 ```
 gbrain schema stats --json
@@ -218,6 +232,7 @@
 expert-routed types.)
 
 ### Phase 7 — Commit (preserve the change)
+use judgment to follow the Phase 7 — Commit (preserve the change) guidance:
 
 If the pack is in source control, commit:
 
@@ -232,15 +247,19 @@
 pick up the change within 1 second (stat-mtime TTL gate in
 loadActivePack — v0.40.6.0 closed the cross-process invalidation gap).
 
-## Outputs
+## Outputs (( inert ))
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
+## Contract (( role: procedure ))
+use judgment to follow the Contract guidance:
 
 - **Inputs:** a natural-language request that names a type / prefix / link verb / flag change, OR the result of `gbrain schema review-orphans` showing untyped pages that need a new type.
 - **Outputs:** mutated pack file at `~/.gbrain/schema-packs/<name>/pack.{json,yaml}` + an audit row in `~/.gbrain/audit/schema-mutations-YYYY-Www.jsonl` + (if `sync --apply` ran) backfilled `pages.type` on matching rows.
@@ -249,7 +268,8 @@
 - **Trust:** CLI = local trust (no scope check). MCP = OAuth `admin` scope (write ops). Audit log captures `actor: mcp:<clientId8>` per mutation.
 - **Atomicity:** every mutation is wrapped in `withMutation`'s atomic write (`.tmp + fsync + rename`) + per-pack `O_CREAT|O_EXCL` lock. Crash mid-write leaves the original file untouched.
 
-## Anti-Patterns
+## Anti-Patterns (( role: procedure ))
+use judgment to follow the Anti-Patterns guidance:
 
 - **Don't mutate `gbrain-base` or `gbrain-recommended`.** Fork first (`gbrain schema fork gbrain-base mine`). These are bundled packs; edits would be lost on upgrade. The mutation primitives refuse with `PACK_READONLY`.
 - **Don't add a type for a directory you imported once for triage.** Pack types are permanent decisions; one-time imports are not. See `skills/conventions/schema-evolution.md` for the <20-pages-don't-pack-codify heuristic.
@@ -259,7 +279,7 @@
 - **Don't skip the dry-run before `sync --apply`.** Always run `sync` first to see `would_apply` counts + sample slugs. A pack prefix that matches 50,000 pages is recoverable but slow; verifying first is cheap.
 - **Don't remove a type without checking references.** `remove-type` refuses with `STILL_REFERENCED` if another type's `aliases` / `enrichable_types` / `link_types` / `frontmatter_links` references it. Break the references first; don't add `--force`.
 
-## Output Format
+## Output Format (( inert, role: template ))
 
 When invoked, this skill produces structured output suitable for both human + JSON consumption:
 
@@ -290,7 +310,7 @@
 
 On failure, the error envelope follows the standard `StructuredAgentError` shape from `src/core/errors.ts`: `{error, code, message, details?}`. Codes from the mutation primitives: `PACK_NOT_FOUND`, `PACK_READONLY`, `PACK_CORRUPT`, `TYPE_EXISTS`, `TYPE_NOT_FOUND`, `INVALID_PRIMITIVE`, `INVALID_RESULT`, `IO_ERROR`, `STILL_REFERENCED`, `LOCK_BUSY`.
 
-## Failure modes
+## Failure modes (( inert ))
 
 - `PACK_READONLY` → you tried to mutate `gbrain-base` or `gbrain-recommended`. Fork first.
 - `INVALID_RESULT` → the mutation would create a dangling reference or
```
