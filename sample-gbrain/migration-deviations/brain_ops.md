# Deviation: brain_ops.meri

- Original: `brain-ops/SKILL.md`
- Ported: `brain_ops.meri`
- Tier: 1 (near-verbatim)
- Similarity: 92%
- Lines: 164 -> 164 (+13 / -13)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- preamble-blockquoted

## Metrics
- Sections: 12/12 inert (100% inert ratio)
- Operational inert: 7
- Unclassified inert: 0
- Inert categories: normative-contract=1, operational-procedure=6, reference-documentation=3, template=1, tools-metadata=1
- Judgment: 0 blocks, 0 lines

### Inert section details
- L10 `Contract`: normative-contract — Normative invariants prose needs mining into assertions or explicit AI routing.
- L20 `Iron Law: Back-Linking (MANDATORY)`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L26 `Phases`: operational-procedure — Marked or derived as procedure, but inert suppresses execution.
- L28 `Phase 1: Brain-First Lookup (MANDATORY)`: operational-procedure — Marked or derived as procedure, but inert suppresses execution.
- L40 `Phase 2: On Every Inbound Signal (READ → ENRICH → WRITE)`: operational-procedure — Marked or derived as procedure, but inert suppresses execution.
- L53 `Phase 2.5: Structured Graph Updates (automatic)`: operational-procedure — Marked or derived as procedure, but inert suppresses execution.
- L69 `Phase 3: On Every Outbound Response (READ → PULL → RESPOND)`: operational-procedure — Marked or derived as procedure, but inert suppresses execution.
- L79 `Phase 4: Ambient Enrichment`: operational-procedure — Marked or derived as procedure, but inert suppresses execution.
- L94 `Output Format`: template — Template/output shape is metadata unless explicit output assertions are authored.
- L99 `Cross-source citation format (v0.18.0+)`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L118 `Anti-Patterns`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L127 `Tools Used`: tools-metadata — Tools sections are metadata-mining, not workflow execution.

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
@@ -44,15 +44,15 @@
 - User's direct statements are highest-authority data
 - Back-links maintained on every brain write (Iron Law)
 
-## Iron Law: Back-Linking (MANDATORY)
+## Iron Law: Back-Linking (MANDATORY) (( inert ))
 
 Every mention of a person or company with a brain page MUST create a back-link
 FROM that entity's page TO the page mentioning them. An unlinked mention is a
 broken brain. See `skills/conventions/quality.md` for format.
 
-## Phases
+## Phases (( inert, role: procedure ))
 
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
@@ -118,12 +118,12 @@
 - Spawn sub-agents for anything that would slow down the response
 - Never announce "I'm enriching the brain" — just do it silently
 
-## Output Format
+## Output Format (( inert, role: template ))
 
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
```
