# Deviation: RESOLVER.meri

- Original: `RESOLVER.md`
- Ported: `RESOLVER.meri`
- Tier: 1 (near-verbatim)
- Similarity: 86%
- Lines: 136 -> 170 (+39 / -5)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- preamble-blockquoted

## Metrics
- Sections inert total: 2/2 (100% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert markers (`(( inert ))`, target 0 — the migrator never emits these): 0
- Inert categories: reference-documentation=2
- Judgment: 0 blocks, 0 lines
- canonical_drift: synonym=34, structure=0, desugar=0, meaning=115

### Inert section details
- L121 `Disambiguation rules`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L133 `Conventions (cross-cutting)`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.

## Unified diff

```diff
--- original-skills/RESOLVER.md
+++ RESOLVER.meri
@@ -1,8 +1,11 @@
 # GBrain Skill Resolver
 
-This is the dispatcher. Skills are the implementation. **Read the skill file before acting.** If two skills could match, read both. They are designed to chain (e.g., ingest then enrich for each entity).
+> This is the dispatcher. Skills are the implementation. **Read the skill file before acting.** If two skills could match, read both. They are designed to chain (e.g., ingest then enrich for each entity).
 
 ## Always-on (every message)
+
+
+### Always-on (every message) — steps
 
 | Trigger | Skill |
 |---------|-------|
@@ -10,6 +13,9 @@
 | Any brain read/write/lookup/citation | `skills/brain-ops/SKILL.md` |
 
 ## Brain operations
+
+
+### Brain operations — steps (( role: reference ))
 
 | Trigger | Skill |
 |---------|-------|
@@ -29,6 +35,9 @@
 
 ## Content & media ingestion
 
+
+### Content & media ingestion — steps (( role: reference ))
+
 | Trigger | Skill |
 |---------|-------|
 | "capture this", "save this thought", "remember this", "drop this in the inbox", "save to brain" | `skills/capture/SKILL.md` |
@@ -38,6 +47,9 @@
 | Generic "ingest this" (auto-routes to above) | `skills/ingest/SKILL.md` |
 
 ## Thinking skills (from GStack)
+
+
+### Thinking skills (from GStack) — steps (( role: reference ))
 
 | Trigger | Skill |
 |---------|-------|
@@ -50,6 +62,9 @@
 > If not, brain-only mode still works (brain skills function without thinking skills).
 
 ## Operational
+
+
+### Operational — steps
 
 | Trigger | Skill |
 |---------|-------|
@@ -72,6 +87,10 @@
 
 ## Setup & migration
 
+
+### Setup & migration — steps
+
+!!! table (( ai-discretion ))
 | Trigger | Skill |
 |---------|-------|
 | "Set up GBrain", first boot | `skills/setup/SKILL.md` |
@@ -89,6 +108,9 @@
 
 ## Identity & access (always-on)
 
+
+### Identity & access (always-on) — steps
+
 | Trigger | Skill |
 |---------|-------|
 | Non-owner sends a message | Check `ACCESS_POLICY.md` before responding |
@@ -96,28 +118,40 @@
 | Agent needs user context | Read `USER.md` |
 | Operational cadence (what to check and when) | Read `HEARTBEAT.md` |
 
-## Disambiguation rules
+## Disambiguation rules (( role: reference ))
 
 When multiple skills could match:
 1. Prefer the most specific skill (meeting-ingestion over ingest)
 2. If the user mentions a URL, route by content type (link → idea-ingest, video → media-ingest)
 3. If the user mentions a person/company, check if enrich or query fits better
+
+### Disambiguation rules — steps (( role: reference ))
+
 4. Chaining is explicit in each skill's Phases section
 5. When in doubt, ask the user (see `skills/ask-user/SKILL.md` for the choice-gate pattern)
 
-## Conventions (cross-cutting)
+## Conventions (cross-cutting) (( role: reference ))
 
-These apply to ALL brain-writing skills:
+- `skills/conventions/schema-evolution.md` — when to add a type vs alias vs prefix (read before `schema-author`)
+
+### Conventions (cross-cutting) — steps
+
+> These apply to ALL brain-writing skills:
 - `skills/conventions/quality.md` — citations, back-links, notability gate
 - `skills/conventions/brain-first.md` — check brain before external APIs
 - `skills/conventions/brain-routing.md` — which brain (DB) and which source (repo) to target; cross-brain federation is latent-space only
-- `skills/conventions/schema-evolution.md` — when to add a type vs alias vs prefix (read before `schema-author`)
+
+### Conventions (cross-cutting) — steps 2
+
 - `skills/conventions/subagent-routing.md` — when to use Minions vs inline work
 - `skills/ask-user/SKILL.md` — choice-gate pattern for human input at decision points
 - `skills/_brain-filing-rules.md` — where files go
 - `skills/_output-rules.md` — output quality standards
 
 ## Uncategorized
+
+
+### Uncategorized — steps
 
 | Trigger | Skill |
 |---------|-------|
```
