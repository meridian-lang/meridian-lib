# Deviation: brain_ops.meri

- Original: `brain-ops/SKILL.md`
- Ported: `brain_ops.meri`
- Tier: 3 (structural rewrite)
- Similarity: 48%
- Lines: 164 -> 166 (+86 / -84)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- shell-block-routed
- preamble-blockquoted

## Metrics
- Sections: 4/12 inert (33% inert ratio)
- Operational inert: 0
- Unclassified inert: 0
- Inert categories: reference-documentation=2, template=1, tools-metadata=1
- Judgment: 5 blocks, 42 lines

### Inert section details
- L21 `Iron Law: Back-Linking (MANDATORY)`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L95 `Output Format`: template — Template/output shape is metadata unless explicit output assertions are authored.
- L100 `Cross-source citation format (v0.18.0+)`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L129 `Tools Used`: tools-metadata — Tools sections are metadata-mining, not workflow execution.

## Unified diff

```diff
--- original-skills/brain-ops/SKILL.md
+++ skills/brain_ops.meri
@@ -28,23 +28,24 @@
 
 # Brain Operations — The Ambient Context Layer
 
-The brain is not an archive. It is a live context membrane that every interaction
-flows through in both directions.
+> The brain is not an archive. It is a live context membrane that every interaction
+> flows through in both directions.
 
 > **Convention:** See `skills/conventions/brain-first.md` for the 5-step lookup protocol.
 > **Convention:** See `skills/conventions/quality.md` for citation and back-link rules.
 
-## Contract
+## Contract (( role: procedure ))
 
-This skill guarantees:
-- Brain is checked BEFORE any external API call (brain-first lookup)
-- Every inbound signal triggers the READ → ENRICH → WRITE loop
-- Every outbound response checks brain for relevant context
-- Source attribution on every fact written (inline `[Source: ...]` citations)
-- User's direct statements are highest-authority data
-- Back-links maintained on every brain write (Iron Law)
+> This skill guarantees:
+!!! checklist (( ai-autonomy ))
+- [ ] Brain is checked BEFORE any external API call (brain-first lookup)
+- [ ] Every inbound signal triggers the READ → ENRICH → WRITE loop
+- [ ] Every outbound response checks brain for relevant context
+- [ ] Source attribution on every fact written (inline `[Source: ...]` citations)
+- [ ] User's direct statements are highest-authority data
+- [ ] Back-links maintained on every brain write (Iron Law)
 
-## Iron Law: Back-Linking (MANDATORY)
+## Iron Law: Back-Linking (MANDATORY) (( inert ))
 
 Every mention of a person or company with a brain page MUST create a back-link
 FROM that entity's page TO the page mentioning them. An unlinked mention is a
@@ -52,78 +53,78 @@
 
 ## Phases
 
-### Phase 1: Brain-First Lookup (MANDATORY)
+### Phase 1: Brain-First Lookup (MANDATORY) (( role: procedure ))
 
-Before using ANY external API to research a person, company, or topic:
-
-1. `gbrain search "name"` — keyword search for existing pages
-2. `gbrain query "natural question about name"` — hybrid search for context
-3. `gbrain get <slug>` — if you know the slug, read the full page
-4. Check backlinks: who references this entity?
-5. Check timeline: recent events involving this entity
-
-The brain almost always has something. External APIs fill gaps, not start from scratch.
-
-### Phase 2: On Every Inbound Signal (READ → ENRICH → WRITE)
-
-Every message, meeting, email, or conversation that references a person or company:
-
-1. **Detect entities** — people, companies, deals mentioned
-2. **Load brain pages** — read existing pages for context before responding
-3. **Identify new information** — what does this signal tell us that the page doesn't know?
-4. **Write it back** — update the brain page with new info + timeline entry + source citation
-5. **Create if missing** — if notable and no page exists, create via enrich skill
-
-**User's direct statements are the highest-value data source.** Write them to brain
-pages immediately with attribution `[Source: User, YYYY-MM-DD]`.
-
-### Phase 2.5: Structured Graph Updates (automatic)
-
-Every `put_page` call automatically extracts entity references and writes them
-to the graph (`links` table) with inferred relationship types. Stale links
-(refs no longer in the page text) are removed in the same call. This is
-"auto-link" reconciliation.
-
-- No manual `add_link` calls needed for ordinary page writes.
-- Inferred link types: `attended` (meeting -> person), `works_at`, `invested_in`,
-  `founded`, `advises`, `source` (frontmatter), `mentions` (default).
-- The `put_page` MCP response includes `auto_links: { created, removed, errors }`
-  so the agent can verify outcomes.
-- To disable: `gbrain config set auto_link false`. Default is on.
-- Timeline entries with specific dates still need explicit `gbrain timeline-add`
-  (or batch via `gbrain extract timeline --source db`).
-
-### Phase 3: On Every Outbound Response (READ → PULL → RESPOND)
-
-Before answering any question about a person, company, or topic:
-
-1. **Check the brain** — read relevant pages
-2. **Pull context** — use compiled truth + recent timeline
-3. **Respond with context** — the brain makes every answer better
-
-Don't answer from general knowledge when a brain page exists.
-
-### Phase 4: Ambient Enrichment
-
-This is not a special mode. This is the default. Everything the user says is an
-ingest event.
-
-- Person mentioned → check brain, create/enrich if needed (spawn background)
-- Company mentioned → same
-- Link shared → ingest it (delegate to idea-ingest)
-- Data shared → delegate to appropriate skill
-
-**Rules:**
-- Never interrupt the conversation to do enrichment
-- Spawn sub-agents for anything that would slow down the response
-- Never announce "I'm enriching the brain" — just do it silently
-
+use judgment to follow the Phase 1: Brain-First Lookup (MANDATORY) guidance:
+  Before using ANY external API to research a person, company, or topic:
+  
+  1. `gbrain search "name"` — keyword search for existing pages
+  2. `gbrain query "natural question about name"` — hybrid search for context
+  3. `gbrain get <slug>` — if you know the slug, read the full page
+  4. Check backlinks: who references this entity?
+  5. Check timeline: recent events involving this entity
+  
+  The brain almost always has something. External APIs fill gaps, not start from scratch.
+### Phase 2: On Every Inbound Signal (READ → ENRICH → WRITE) (( role: procedure ))
+  
+use judgment to follow the Phase 2: On Every Inbound Signal (READ → ENRICH → WRITE) guidance:
+  Every message, meeting, email, or conversation that references a person or company:
+  
+  1. **Detect entities** — people, companies, deals mentioned
+  2. **Load brain pages** — read existing pages for context before responding
+  3. **Identify new information** — what does this signal tell us that the page doesn't know?
+  4. **Write it back** — update the brain page with new info + timeline entry + source citation
+  5. **Create if missing** — if notable and no page exists, create via enrich skill
+  
+  **User's direct statements are the highest-value data source.** Write them to brain
+  pages immediately with attribution `[Source: User, YYYY-MM-DD]`.
+### Phase 2.5: Structured Graph Updates (automatic) (( role: procedure ))
+  
+use judgment to follow the Phase 2.5: Structured Graph Updates (automatic) guidance:
+  Every `put_page` call automatically extracts entity references and writes them
+  to the graph (`links` table) with inferred relationship types. Stale links
+  (refs no longer in the page text) are removed in the same call. This is
+  "auto-link" reconciliation.
+  
+  item: No manual `add_link` calls needed for ordinary page writes.
+  item: Inferred link types: `attended` (meeting -> person), `works_at`, `invested_in`,
+    `founded`, `advises`, `source` (frontmatter), `mentions` (default).
+  item: The `put_page` MCP response includes `auto_links: { created, removed, errors }`
+    so the agent can verify outcomes.
+  item: To disable: `gbrain config set auto_link false`. Default is on.
+  item: Timeline entries with specific dates still need explicit `gbrain timeline-add`
+    (or batch via `gbrain extract timeline --source db`).
+### Phase 3: On Every Outbound Response (READ → PULL → RESPOND) (( role: procedure ))
+  
+use judgment to follow the Phase 3: On Every Outbound Response (READ → PULL → RESPOND) guidance:
+  Before answering any question about a person, company, or topic:
+  
+  1. **Check the brain** — read relevant pages
+  2. **Pull context** — use compiled truth + recent timeline
+  3. **Respond with context** — the brain makes every answer better
+  
+  Don't answer from general knowledge when a brain page exists.
+### Phase 4: Ambient Enrichment (( role: procedure ))
+  
+use judgment to follow the Phase 4: Ambient Enrichment guidance:
+  This is not a special mode. This is the default. Everything the user says is an
+  ingest event.
+  
+  item: Person mentioned → check brain, create/enrich if needed (spawn background)
+  item: Company mentioned → same
+  item: Link shared → ingest it (delegate to idea-ingest)
+  item: Data shared → delegate to appropriate skill
+  
+  **Rules:**
+  item: Never interrupt the conversation to do enrichment
+  item: Spawn sub-agents for anything that would slow down the response
+  item: Never announce "I'm enriching the brain" — just do it silently
 ## Output Format
 
 No separate output. Brain-ops is an always-on behavior layer, not a report generator.
 The output is updated brain pages and enriched responses.
 
-## Cross-source citation format (v0.18.0+)
+## Cross-source citation format (v0.18.0+) (( inert ))
 
 When a brain has multiple sources (wiki, gstack, yc-media, etc.), every
 citation MUST include the source id: `[source-id:slug]`. Example:
@@ -142,14 +143,15 @@
 If a search result has `source_id: "gstack"` and `slug: "plans/foo"`,
 the citation is `[gstack:plans/foo]`. That's the whole rule.
 
-## Anti-Patterns
+## Anti-Patterns (( role: procedure ))
 
-- Answering questions about people/companies without checking the brain first
-- Using external APIs before checking the brain
-- Writing facts without inline `[Source: ...]` citations
-- Blocking the response to do enrichment
-- Overwriting user's direct statements with lower-authority sources
-- Creating brain pages for non-notable entities
+!!! checklist (( ai-autonomy ))
+- [ ] Answering questions about people/companies without checking the brain first
+- [ ] Using external APIs before checking the brain
+- [ ] Writing facts without inline `[Source: ...]` citations
+- [ ] Blocking the response to do enrichment
+- [ ] Overwriting user's direct statements with lower-authority sources
+- [ ] Creating brain pages for non-notable entities
 
 ## Tools Used
 
```
