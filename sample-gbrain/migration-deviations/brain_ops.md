# Deviation: brain_ops.meri

- Original: `brain-ops/SKILL.md`
- Ported: `brain_ops.meri`
- Tier: 1 (near-verbatim)
- Similarity: 93%
- Lines: 164 -> 164 (+12 / -12)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- preamble-blockquoted

## Unified diff

```diff
--- original-skills/brain-ops/SKILL.md
+++ skills/brain_ops.meri
@@ -28,13 +28,13 @@
 
 # Brain Operations — The Ambient Context Layer
 
-The brain is not an archive. It is a live context membrane that every interaction
-flows through in both directions.
+> The brain is not an archive. It is a live context membrane that every interaction
+> flows through in both directions.
 
 > **Convention:** See `skills/conventions/brain-first.md` for the 5-step lookup protocol.
 > **Convention:** See `skills/conventions/quality.md` for citation and back-link rules.
 
-## Contract
+## Contract (( inert, role: invariants ))
 
 This skill guarantees:
 - Brain is checked BEFORE any external API call (brain-first lookup)
@@ -44,7 +44,7 @@
 - User's direct statements are highest-authority data
 - Back-links maintained on every brain write (Iron Law)
 
-## Iron Law: Back-Linking (MANDATORY)
+## Iron Law: Back-Linking (MANDATORY) (( inert ))
 
 Every mention of a person or company with a brain page MUST create a back-link
 FROM that entity's page TO the page mentioning them. An unlinked mention is a
@@ -52,7 +52,7 @@
 
 ## Phases
 
-### Phase 1: Brain-First Lookup (MANDATORY)
+### Phase 1: Brain-First Lookup (MANDATORY) (( inert, role: procedure ))
 
 Before using ANY external API to research a person, company, or topic:
 
@@ -64,7 +64,7 @@
 
 The brain almost always has something. External APIs fill gaps, not start from scratch.
 
-### Phase 2: On Every Inbound Signal (READ → ENRICH → WRITE)
+### Phase 2: On Every Inbound Signal (READ → ENRICH → WRITE) (( inert, role: procedure ))
 
 Every message, meeting, email, or conversation that references a person or company:
 
@@ -77,7 +77,7 @@
 **User's direct statements are the highest-value data source.** Write them to brain
 pages immediately with attribution `[Source: User, YYYY-MM-DD]`.
 
-### Phase 2.5: Structured Graph Updates (automatic)
+### Phase 2.5: Structured Graph Updates (automatic) (( inert, role: procedure ))
 
 Every `put_page` call automatically extracts entity references and writes them
 to the graph (`links` table) with inferred relationship types. Stale links
@@ -93,7 +93,7 @@
 - Timeline entries with specific dates still need explicit `gbrain timeline-add`
   (or batch via `gbrain extract timeline --source db`).
 
-### Phase 3: On Every Outbound Response (READ → PULL → RESPOND)
+### Phase 3: On Every Outbound Response (READ → PULL → RESPOND) (( inert, role: procedure ))
 
 Before answering any question about a person, company, or topic:
 
@@ -103,7 +103,7 @@
 
 Don't answer from general knowledge when a brain page exists.
 
-### Phase 4: Ambient Enrichment
+### Phase 4: Ambient Enrichment (( inert, role: procedure ))
 
 This is not a special mode. This is the default. Everything the user says is an
 ingest event.
@@ -123,7 +123,7 @@
 No separate output. Brain-ops is an always-on behavior layer, not a report generator.
 The output is updated brain pages and enriched responses.
 
-## Cross-source citation format (v0.18.0+)
+## Cross-source citation format (v0.18.0+) (( inert ))
 
 When a brain has multiple sources (wiki, gstack, yc-media, etc.), every
 citation MUST include the source id: `[source-id:slug]`. Example:
@@ -142,7 +142,7 @@
 If a search result has `source_id: "gstack"` and `slug: "plans/foo"`,
 the citation is `[gstack:plans/foo]`. That's the whole rule.
 
-## Anti-Patterns
+## Anti-Patterns (( inert, role: prohibitions ))
 
 - Answering questions about people/companies without checking the brain first
 - Using external APIs before checking the brain
@@ -151,7 +151,7 @@
 - Overwriting user's direct statements with lower-authority sources
 - Creating brain pages for non-notable entities
 
-## Tools Used
+## Tools Used (( inert ))
 
 - `search` — keyword search
 - `query` — hybrid vector+keyword search
```
