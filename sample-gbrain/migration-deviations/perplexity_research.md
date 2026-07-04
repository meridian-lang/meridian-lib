# Deviation: perplexity_research.meri

- Original: `perplexity-research/SKILL.md`
- Ported: `perplexity_research.meri`
- Tier: 1 (near-verbatim)
- Similarity: 86%
- Lines: 200 -> 224 (+42 / -18)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- shell-block-routed
- inert-section-added

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L40 `Output structure`: template - Template/output shape is metadata unless explicit output assertions are authored.
- L150 `Morning briefing`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L155 `Recency filter`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L204 `Output Format`: template - Template/output shape is metadata unless explicit output assertions are authored.

## Metrics
- Sections inert total: 4/9 (44% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert categories: reference-documentation=2, template=2
- Judgment: 4 blocks, 0 lines

### Inert section details
- L40 `Output structure`: template — Template/output shape is metadata unless explicit output assertions are authored.
- L150 `Morning briefing`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L155 `Recency filter`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L204 `Output Format`: template — Template/output shape is metadata unless explicit output assertions are authored.

## Unified diff

```diff
--- original-skills/perplexity-research/SKILL.md
+++ skills/perplexity_research.meri
@@ -28,6 +28,7 @@
 > the delta between brain knowledge and current web state.
 
 ## What this does
+use judgment to follow the What this does guidance:
 
 Combines existing brain knowledge with Perplexity's web search. The
 agent sends brain context about a topic into a Perplexity query;
@@ -39,17 +40,21 @@
 instructions, it knows what you already know, so it surfaces the delta
 instead of repeating settled fact.
 
-## When to use this vs other tools
-
+## When to use this vs other tools (( inert ))
+
+
+### When to use this vs other tools — steps
+
+!!! table (( ai-discretion ))
 | Need | Use |
 |------|-----|
-| Deep research with citations | **This skill** — Perplexity + Opus |
+| Deep research with citations | This skill — Perplexity + Opus |
 | Quick URL content | `web_fetch` |
 | Brain-only lookup | `gbrain query` / `gbrain search` |
 | Real-time social monitoring | external X / social-media collectors |
 | Structured data lookup against a tracker | `skills/data-research/SKILL.md` |
 
-## Output structure
+## Output structure (( inert, role: template ))
 
 The research output lands as a brain page under `research/<slug>.md` with
 this structure:
@@ -87,7 +92,10 @@
 - ...
 ```
 
-## Invocation
+## Invocation (( inert ))
+
+
+### Invocation — steps
 
 The skill is markdown agent instructions; the agent uses Perplexity's
 API directly (or a host-provided `perplexity` CLI if installed):
@@ -117,8 +125,12 @@
 # 5. Cross-link entities mentioned (people, companies) per Iron Law.
 ```
 
-## Models
-
+## Models (( inert ))
+
+
+### Models — steps
+
+!!! table (( ai-discretion ))
 | Model | Cost / query | Use when |
 |-------|-------------|----------|
 | Perplexity sonar-pro | ~\$0.04 | Deep analysis, entity enrichment, deal research |
@@ -127,9 +139,12 @@
 Default to sonar-pro. Drop to sonar for bulk / cron contexts where cost
 matters more than depth.
 
-## Integration patterns
-
-### Entity enrichment
+## Integration patterns (( inert ))
+
+### Entity enrichment (( inert, role: procedure ))
+
+
+#### Entity enrichment — steps
 
 Called by `skills/enrich/SKILL.md` when an entity page (person, company)
 needs current web context:
@@ -141,6 +156,7 @@
 ```
 
 ### Deal / company monitoring (cron)
+use judgment to follow the Deal / company monitoring (cron) guidance:
 
 For each active item under `deals/` or `companies/`:
 
@@ -148,32 +164,39 @@
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
+## Anti-Patterns (( role: procedure ))
+use judgment to follow the Anti-Patterns guidance:
 
 - ❌ Sending NO brain context. Then it's just a search — use `web_fetch`
   instead.
 - ❌ Truncating the brain context. The whole point is "knows what you
   know." Send dense context.
+- ❌ Skipping the cross-link step when entities are mentioned. Iron Law.
+
+
+### Anti-Patterns — steps
+
 - ❌ Discarding citations. Every claim in the output must have a URL.
-- ❌ Skipping the cross-link step when entities are mentioned. Iron Law.
-
 ## Environment
 
 - `PERPLEXITY_API_KEY` set in the agent's environment (or in
   `~/.gbrain/.env`).
 - Optional: install Perplexity's official CLI for richer streaming output.
 
-## Related skills
+## Related skills (( inert, role: procedure ))
+
+
+### Related skills — steps
 
 - `skills/academic-verify/SKILL.md` — wraps perplexity-research for
   citation-verified academic claim checking
@@ -183,7 +206,8 @@
   shape: parameterized YAML recipes, not free-form research)
 
 
-## Contract
+## Contract (( role: procedure ))
+use judgment to follow the Contract guidance:
 
 This skill guarantees:
 
@@ -194,7 +218,7 @@
 
 The full behavior contract is documented in the body sections above; this section exists for the conformance test.
 
-## Output Format
+## Output Format (( inert, role: template ))
 
 The skill's output shape is documented inline in the body sections above (see "Output", "Brain page format", or equivalent). The literal section header here exists for the conformance test (`test/skills-conformance.test.ts`).
 
```
