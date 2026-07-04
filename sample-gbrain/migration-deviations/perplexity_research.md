# Deviation: perplexity_research.meri

- Original: `perplexity-research/SKILL.md`
- Ported: `perplexity_research.meri`
- Tier: 1 (near-verbatim)
- Similarity: 90%
- Lines: 200 -> 200 (+21 / -21)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added

## Metrics
- Sections: 15/15 inert (100% inert ratio)
- Operational inert: 5
- Unclassified inert: 0
- Inert categories: normative-contract=1, operational-content=4, reference-documentation=8, template=2
- Judgment: 0 blocks, 0 lines

### Inert section details
- L13 `What this does`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L25 `When to use this vs other tools`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L35 `Output structure`: template — Template/output shape is metadata unless explicit output assertions are authored.
- L73 `Invocation`: operational-content — Body contains command, table, checklist, or explicit AI-routing surface.
- L103 `Models`: operational-content — Body contains command, table, checklist, or explicit AI-routing surface.
- L113 `Integration patterns`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L115 `Entity enrichment`: operational-content — Body contains command, table, checklist, or explicit AI-routing surface.
- L126 `Deal / company monitoring (cron)`: operational-content — Body contains command, table, checklist, or explicit AI-routing surface.
- L134 `Morning briefing`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L139 `Recency filter`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L144 `Anti-Patterns`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L153 `Environment`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L159 `Related skills`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L169 `Contract`: normative-contract — Normative invariants prose needs mining into assertions or explicit AI routing.
- L180 `Output Format`: template — Template/output shape is metadata unless explicit output assertions are authored.

## Unified diff

```diff
--- original-skills/perplexity-research/SKILL.md
+++ skills/perplexity_research.meri
@@ -27,7 +27,7 @@
 > context as part of the Perplexity prompt — the web search focuses on
 > the delta between brain knowledge and current web state.
 
-## What this does
+## What this does (( inert ))
 
 Combines existing brain knowledge with Perplexity's web search. The
 agent sends brain context about a topic into a Perplexity query;
@@ -39,7 +39,7 @@
 instructions, it knows what you already know, so it surfaces the delta
 instead of repeating settled fact.
 
-## When to use this vs other tools
+## When to use this vs other tools (( inert ))
 
 | Need | Use |
 |------|-----|
@@ -49,7 +49,7 @@
 | Real-time social monitoring | external X / social-media collectors |
 | Structured data lookup against a tracker | `skills/data-research/SKILL.md` |
 
-## Output structure
+## Output structure (( inert, role: template ))
 
 The research output lands as a brain page under `research/<slug>.md` with
 this structure:
@@ -68,26 +68,26 @@
 > Executive summary: 2-3 sentences on the delta between brain knowledge
 > and current web state.
 
-## Key New Developments
+## Key New Developments (( inert ))
 What's changed since the brain was last updated on this topic.
 
-## Confirming Signals
+## Confirming Signals (( inert ))
 Web evidence validating existing brain knowledge.
 
-## Contradictions or Updates
+## Contradictions or Updates (( inert ))
 Things that conflict with the brain — these need a closer look.
 
-## Recommended Brain Updates
+## Recommended Brain Updates (( inert ))
 Specific page updates the user might want to make based on this research.
 Each item: which page, what to add or change, source URL.
 
-## Citations
+## Citations (( inert ))
 - [Source title](URL) — accessed YYYY-MM-DD
 - [Source title](URL) — accessed YYYY-MM-DD
 - ...
 ```
 
-## Invocation
+## Invocation (( inert ))
 
 The skill is markdown agent instructions; the agent uses Perplexity's
 API directly (or a host-provided `perplexity` CLI if installed):
@@ -117,7 +117,7 @@
 # 5. Cross-link entities mentioned (people, companies) per Iron Law.
 ```
 
-## Models
+## Models (( inert ))
 
 | Model | Cost / query | Use when |
 |-------|-------------|----------|
@@ -127,9 +127,9 @@
 Default to sonar-pro. Drop to sonar for bulk / cron contexts where cost
 matters more than depth.
 
-## Integration patterns
-
-### Entity enrichment
+## Integration patterns (( inert ))
+
+### Entity enrichment (( inert ))
 
 Called by `skills/enrich/SKILL.md` when an entity page (person, company)
 needs current web context:
@@ -140,7 +140,7 @@
 # news / role / context, then update the brain page with what's new.
 ```
 
-### Deal / company monitoring (cron)
+### Deal / company monitoring (cron) (( inert ))
 
 For each active item under `deals/` or `companies/`:
 
@@ -148,17 +148,17 @@
 # Weekly: pull recent news per company; flag changes for review.
 ```
 
-### Morning briefing
+### Morning briefing (( inert ))
 
 Replace raw `web_fetch` calls in briefing pipelines with this skill so
 the agent doesn't re-narrate already-known facts.
 
-## Recency filter
+## Recency filter (( inert ))
 
 Pass `recency_filter` to Perplexity: `hour | day | week | month`. Useful
 for news-cycle topics; omit for evergreen research.
 
-## Anti-Patterns
+## Anti-Patterns (( inert, role: prohibitions ))
 
 - ❌ Sending NO brain context. Then it's just a search — use `web_fetch`
   instead.
@@ -167,13 +167,13 @@
 - ❌ Discarding citations. Every claim in the output must have a URL.
 - ❌ Skipping the cross-link step when entities are mentioned. Iron Law.
 
-## Environment
+## Environment (( inert ))
 
 - `PERPLEXITY_API_KEY` set in the agent's environment (or in
   `~/.gbrain/.env`).
 - Optional: install Perplexity's official CLI for richer streaming output.
 
-## Related skills
+## Related skills (( inert ))
 
 - `skills/academic-verify/SKILL.md` — wraps perplexity-research for
   citation-verified academic claim checking
@@ -183,7 +183,7 @@
   shape: parameterized YAML recipes, not free-form research)
 
 
-## Contract
+## Contract (( inert, role: invariants ))
 
 This skill guarantees:
 
@@ -194,7 +194,7 @@
 
 The full behavior contract is documented in the body sections above; this section exists for the conformance test.
 
-## Output Format
+## Output Format (( inert, role: template ))
 
 The skill's output shape is documented inline in the body sections above (see "Output", "Brain page format", or equivalent). The literal section header here exists for the conformance test (`test/skills-conformance.test.ts`).
 
```
