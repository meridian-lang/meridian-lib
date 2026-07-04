# Deviation: brain_ops.meri

- Original: `brain-ops/SKILL.md`
- Ported: `brain_ops.meri`
- Tier: 2 (light edits)
- Similarity: 83%
- Lines: 164 -> 186 (+41 / -19)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- shell-block-routed
- preamble-blockquoted
- inert-section-added

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L108 `Output Format`: template - Template/output shape is metadata unless explicit output assertions are authored.
- L149 `Tools Used`: tools-metadata - Tools sections are metadata-mining, not workflow execution.

## Metrics
- Sections inert total: 2/12 (17% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert categories: template=1, tools-metadata=1
- Judgment: 10 blocks, 0 lines

### Inert section details
- L108 `Output Format`: template — Template/output shape is metadata unless explicit output assertions are authored.
- L149 `Tools Used`: tools-metadata — Tools sections are metadata-mining, not workflow execution.

## Unified diff

```diff
--- original-skills/brain-ops/SKILL.md
+++ skills/brain_ops.meri
@@ -28,13 +28,14 @@
 
 # Brain Operations — The Ambient Context Layer
 
-The brain is not an archive. It is a live context membrane that every interaction
-flows through in both directions.
+> The brain is not an archive. It is a live context membrane that every interaction
+> flows through in both directions.
 
 > **Convention:** See `skills/conventions/brain-first.md` for the 5-step lookup protocol.
 > **Convention:** See `skills/conventions/quality.md` for citation and back-link rules.
 
-## Contract
+## Contract (( role: procedure ))
+use judgment to follow the Contract guidance:
 
 This skill guarantees:
 - Brain is checked BEFORE any external API call (brain-first lookup)
@@ -45,26 +46,33 @@
 - Back-links maintained on every brain write (Iron Law)
 
 ## Iron Law: Back-Linking (MANDATORY)
+use judgment to follow the Iron Law: Back-Linking (MANDATORY) guidance:
 
 Every mention of a person or company with a brain page MUST create a back-link
 FROM that entity's page TO the page mentioning them. An unlinked mention is a
 broken brain. See `skills/conventions/quality.md` for format.
 
 ## Phases
+use judgment to follow the Phases guidance:
 
 ### Phase 1: Brain-First Lookup (MANDATORY)
+use judgment to follow the Phase 1: Brain-First Lookup (MANDATORY) guidance:
 
-Before using ANY external API to research a person, company, or topic:
-
-1. `gbrain search "name"` — keyword search for existing pages
-2. `gbrain query "natural question about name"` — hybrid search for context
-3. `gbrain get <slug>` — if you know the slug, read the full page
 4. Check backlinks: who references this entity?
 5. Check timeline: recent events involving this entity
 
 The brain almost always has something. External APIs fill gaps, not start from scratch.
 
+
+#### Phase 1: Brain-First Lookup (MANDATORY) — steps
+
+> Before using ANY external API to research a person, company, or topic:
+
+1. `gbrain search "name"` — keyword search for existing pages
+2. `gbrain query "natural question about name"` — hybrid search for context
+3. `gbrain get <slug>` — if you know the slug, read the full page
 ### Phase 2: On Every Inbound Signal (READ → ENRICH → WRITE)
+use judgment to follow the Phase 2: On Every Inbound Signal (READ → ENRICH → WRITE) guidance:
 
 Every message, meeting, email, or conversation that references a person or company:
 
@@ -78,6 +86,7 @@
 pages immediately with attribution `[Source: User, YYYY-MM-DD]`.
 
 ### Phase 2.5: Structured Graph Updates (automatic)
+use judgment to follow the Phase 2.5: Structured Graph Updates (automatic) guidance:
 
 Every `put_page` call automatically extracts entity references and writes them
 to the graph (`links` table) with inferred relationship types. Stale links
@@ -94,16 +103,21 @@
   (or batch via `gbrain extract timeline --source db`).
 
 ### Phase 3: On Every Outbound Response (READ → PULL → RESPOND)
+use judgment to follow the Phase 3: On Every Outbound Response (READ → PULL → RESPOND) guidance:
 
-Before answering any question about a person, company, or topic:
-
-1. **Check the brain** — read relevant pages
 2. **Pull context** — use compiled truth + recent timeline
 3. **Respond with context** — the brain makes every answer better
 
 Don't answer from general knowledge when a brain page exists.
 
+
+#### Phase 3: On Every Outbound Response (READ → PULL → RESPOND) — steps
+
+> Before answering any question about a person, company, or topic:
+
+1. Check the brain — read relevant pages
 ### Phase 4: Ambient Enrichment
+use judgment to follow the Phase 4: Ambient Enrichment guidance:
 
 This is not a special mode. This is the default. Everything the user says is an
 ingest event.
@@ -118,12 +132,23 @@
 - Spawn sub-agents for anything that would slow down the response
 - Never announce "I'm enriching the brain" — just do it silently
 
-## Output Format
+## Output Format (( inert, role: template ))
 
 No separate output. Brain-ops is an always-on behavior layer, not a report generator.
 The output is updated brain pages and enriched responses.
 
 ## Cross-source citation format (v0.18.0+)
+use judgment to follow the Cross-source citation format (v0.18.0+) guidance:
+
+Rules:
+- The key is `sources.id` (immutable), never `sources.name` (mutable display).
+- Single-source brains still write `[default:slug]` OR may omit the prefix
+  for backward compat.
+- Every page payload returned by `search`, `query`, `get_page`, `list_pages`
+  carries `source_id` — always use it when citing, never guess.
+
+
+### Cross-source citation format (v0.18.0+) — steps
 
 When a brain has multiple sources (wiki, gstack, yc-media, etc.), every
 citation MUST include the source id: `[source-id:slug]`. Example:
@@ -132,17 +157,14 @@
 > [wiki:topics/resilience] and [gstack:plans/retry-policy] for where
 > this came from.
 
-Rules:
-- The key is `sources.id` (immutable), never `sources.name` (mutable display).
-- Single-source brains still write `[default:slug]` OR may omit the prefix
-  for backward compat.
-- Every page payload returned by `search`, `query`, `get_page`, `list_pages`
-  carries `source_id` — always use it when citing, never guess.
+
+### Cross-source citation format (v0.18.0+) — steps 2
 
 If a search result has `source_id: "gstack"` and `slug: "plans/foo"`,
 the citation is `[gstack:plans/foo]`. That's the whole rule.
 
-## Anti-Patterns
+## Anti-Patterns (( role: procedure ))
+use judgment to follow the Anti-Patterns guidance:
 
 - Answering questions about people/companies without checking the brain first
 - Using external APIs before checking the brain
```
