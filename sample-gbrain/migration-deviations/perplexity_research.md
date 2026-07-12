# Deviation: perplexity_research.meri

- Original: `perplexity-research/SKILL.md`
- Ported: `perplexity_research.meri`
- Tier: 1 (near-verbatim)
- Similarity: 89%
- Lines: 200 -> 225 (+35 / -10)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- doc-section-marked

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L42 `Output structure`: template - Template/output shape is metadata unless explicit output assertions are authored.
- L153 `Morning briefing`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L158 `Recency filter`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L194 `Contract`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L205 `Output Format`: template - Template/output shape is metadata unless explicit output assertions are authored.

## Metrics
- generated_loc: 140 non-blank ported lines
- Sections inert total: 6/7 (86% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert markers (`(( inert ))`, target 0 — the migrator never emits these): 0
- Inert categories: reference-documentation=4, template=2
- Judgment: 1 blocks, 0 lines
- canonical_drift: synonym=8, structure=0, desugar=0, meaning=145

### Inert section details
- L42 `Output structure`: template — Template/output shape is metadata unless explicit output assertions are authored.
- L153 `Morning briefing`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L158 `Recency filter`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L163 `Anti-Patterns`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L194 `Contract`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L205 `Output Format`: template — Template/output shape is metadata unless explicit output assertions are authored.

## Unified diff

```diff
--- original-skills/perplexity-research/SKILL.md
+++ skills/perplexity_research.meri
@@ -29,6 +29,10 @@
 
 ## What this does
 
+
+### What this does — steps
+
+use judgment to follow the What this does — steps guidance:
 Combines existing brain knowledge with Perplexity's web search. The
 agent sends brain context about a topic into a Perplexity query;
 Perplexity searches + reads + synthesizes multiple pages with citations,
@@ -41,15 +45,18 @@
 
 ## When to use this vs other tools
 
+
+### When to use this vs other tools — steps
+
 | Need | Use |
 |------|-----|
-| Deep research with citations | **This skill** — Perplexity + Opus |
+| Deep research with citations | This skill — Perplexity + Opus |
 | Quick URL content | `web_fetch` |
 | Brain-only lookup | `gbrain query` / `gbrain search` |
 | Real-time social monitoring | external X / social-media collectors |
 | Structured data lookup against a tracker | `skills/data-research/SKILL.md` |
 
-## Output structure
+## Output structure (( role: template ))
 
 The research output lands as a brain page under `research/<slug>.md` with
 this structure:
@@ -88,6 +95,9 @@
 ```
 
 ## Invocation
+
+
+### Invocation — steps
 
 The skill is markdown agent instructions; the agent uses Perplexity's
 API directly (or a host-provided `perplexity` CLI if installed):
@@ -119,6 +129,9 @@
 
 ## Models
 
+
+### Models — steps
+
 | Model | Cost / query | Use when |
 |-------|-------------|----------|
 | Perplexity sonar-pro | ~\$0.04 | Deep analysis, entity enrichment, deal research |
@@ -127,9 +140,12 @@
 Default to sonar-pro. Drop to sonar for bulk / cron contexts where cost
 matters more than depth.
 
-## Integration patterns
+## Integration patterns (( role: reference ))
 
 ### Entity enrichment
+
+
+### Entity enrichment — steps
 
 Called by `skills/enrich/SKILL.md` when an entity page (person, company)
 needs current web context:
@@ -142,31 +158,37 @@
 
 ### Deal / company monitoring (cron)
 
+
+### Deal / company monitoring (cron) — steps
+
 For each active item under `deals/` or `companies/`:
 
 ```bash
 # Weekly: pull recent news per company; flag changes for review.
 ```
 
-### Morning briefing
+### Morning briefing (( role: reference ))
 
 Replace raw `web_fetch` calls in briefing pipelines with this skill so
 the agent doesn't re-narrate already-known facts.
 
-## Recency filter
+## Recency filter (( role: reference ))
 
 Pass `recency_filter` to Perplexity: `hour | day | week | month`. Useful
 for news-cycle topics; omit for evergreen research.
 
-## Anti-Patterns
+## Anti-Patterns (( role: reference ))
 
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
@@ -174,6 +196,9 @@
 - Optional: install Perplexity's official CLI for richer streaming output.
 
 ## Related skills
+
+
+### Related skills — steps
 
 - `skills/academic-verify/SKILL.md` — wraps perplexity-research for
   citation-verified academic claim checking
@@ -183,7 +208,7 @@
   shape: parameterized YAML recipes, not free-form research)
 
 
-## Contract
+## Contract (( role: reference ))
 
 This skill guarantees:
 
@@ -194,7 +219,7 @@
 
 The full behavior contract is documented in the body sections above; this section exists for the conformance test.
 
-## Output Format
+## Output Format (( role: template ))
 
 The skill's output shape is documented inline in the body sections above (see "Output", "Brain page format", or equivalent). The literal section header here exists for the conformance test (`test/skills-conformance.test.ts`).
 
```
