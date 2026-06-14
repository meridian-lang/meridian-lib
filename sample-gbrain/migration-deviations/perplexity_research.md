# Deviation: perplexity_research.meri

- Original: `perplexity-research/SKILL.md`
- Ported: `perplexity_research.meri`
- Tier: 2 (light edits)
- Similarity: 52%
- Lines: 200 -> 202 (+97 / -95)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- shell-block-routed

## Metrics
- Sections: 8/15 inert (53% inert ratio)
- Operational inert: 0
- Unclassified inert: 0
- Inert categories: reference-documentation=6, template=2
- Judgment: 5 blocks, 42 lines

### Inert section details
- L13 `What this does`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L25 `When to use this vs other tools`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L35 `Output structure`: template — Template/output shape is metadata unless explicit output assertions are authored.
- L113 `Integration patterns`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L134 `Morning briefing`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L139 `Recency filter`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L160 `Related skills`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L182 `Output Format`: template — Template/output shape is metadata unless explicit output assertions are authored.

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
@@ -68,112 +68,113 @@
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
-
-The skill is markdown agent instructions; the agent uses Perplexity's
-API directly (or a host-provided `perplexity` CLI if installed):
-
-```bash
-# 1. Pull brain context
-gbrain get <slug>                    # or
-gbrain query "<topic keywords>"
-
-# 2. Compose the Perplexity query with brain context inline:
-#    """
-#    Topic: <topic>
-#    Brain context (what we already know): <embedded gbrain content>
-#    Find: what's NEW since 2026-MM-DD that the brain doesn't reflect.
-#    Cite every claim.
-#    """
-
-# 3. Call Perplexity API or the host's perplexity binary:
-#    curl https://api.perplexity.ai/chat/completions \
-#      -H "Authorization: Bearer $PERPLEXITY_API_KEY" \
-#      -H "Content-Type: application/json" \
-#      -d '{"model": "sonar-pro", "messages": [{"role":"user","content":"..."}]}'
-
-# 4. Write the structured research page via put_page:
-gbrain put_page research/<slug>      # via the put_page operation
-
-# 5. Cross-link entities mentioned (people, companies) per Iron Law.
-```
-
-## Models
-
-| Model | Cost / query | Use when |
-|-------|-------------|----------|
-| Perplexity sonar-pro | ~\$0.04 | Deep analysis, entity enrichment, deal research |
-| Perplexity sonar | ~\$0.007 | Quick lookups, bulk monitoring, briefing pipelines |
-
-Default to sonar-pro. Drop to sonar for bulk / cron contexts where cost
-matters more than depth.
-
-## Integration patterns
-
-### Entity enrichment
-
-Called by `skills/enrich/SKILL.md` when an entity page (person, company)
-needs current web context:
-
-```bash
-BRAIN=$(gbrain get people/<slug> 2>/dev/null)
-# Send <slug>'s page content as brain_context to Perplexity, get current
-# news / role / context, then update the brain page with what's new.
-```
-
-### Deal / company monitoring (cron)
-
-For each active item under `deals/` or `companies/`:
-
-```bash
-# Weekly: pull recent news per company; flag changes for review.
-```
-
-### Morning briefing
-
+## Invocation (( role: procedure ))
+
+use judgment to follow the Invocation guidance:
+  The skill is markdown agent instructions; the agent uses Perplexity's
+  API directly (or a host-provided `perplexity` CLI if installed):
+  
+  ```bash
+  # 1. Pull brain context
+  gbrain get <slug>                    # or
+  gbrain query "<topic keywords>"
+  
+  # 2. Compose the Perplexity query with brain context inline:
+  #    """
+  #    Topic: <topic>
+  #    Brain context (what we already know): <embedded gbrain content>
+  #    Find: what's NEW since 2026-MM-DD that the brain doesn't reflect.
+  #    Cite every claim.
+  #    """
+  
+  # 3. Call Perplexity API or the host's perplexity binary:
+  #    curl https://api.perplexity.ai/chat/completions \
+  #      -H "Authorization: Bearer $PERPLEXITY_API_KEY" \
+  #      -H "Content-Type: application/json" \
+  #      -d '{"model": "sonar-pro", "messages": [{"role":"user","content":"..."}]}'
+  
+  # 4. Write the structured research page via put_page:
+  gbrain put_page research/<slug>      # via the put_page operation
+  
+  # 5. Cross-link entities mentioned (people, companies) per Iron Law.
+  ```
+## Models (( role: procedure ))
+
+use judgment to follow the Models guidance:
+  | Model | Cost / query | Use when |
+  |-------|-------------|----------|
+  | Perplexity sonar-pro | ~\$0.04 | Deep analysis, entity enrichment, deal research |
+  | Perplexity sonar | ~\$0.007 | Quick lookups, bulk monitoring, briefing pipelines |
+  
+  Default to sonar-pro. Drop to sonar for bulk / cron contexts where cost
+  matters more than depth.
+## Integration patterns (( inert ))
+
+### Entity enrichment (( role: procedure ))
+
+use judgment to follow the Entity enrichment guidance:
+  Called by `skills/enrich/SKILL.md` when an entity page (person, company)
+  needs current web context:
+  
+  ```bash
+  BRAIN=$(gbrain get people/<slug> 2>/dev/null)
+  # Send <slug>'s page content as brain_context to Perplexity, get current
+  # news / role / context, then update the brain page with what's new.
+  ```
+### Deal / company monitoring (cron) (( role: procedure ))
+  
+use judgment to follow the Deal / company monitoring (cron) guidance:
+  For each active item under `deals/` or `companies/`:
+  
+  ```bash
+  # Weekly: pull recent news per company; flag changes for review.
+  ```
+### Morning briefing (( inert ))
+  
 Replace raw `web_fetch` calls in briefing pipelines with this skill so
 the agent doesn't re-narrate already-known facts.
 
-## Recency filter
+## Recency filter (( inert ))
 
 Pass `recency_filter` to Perplexity: `hour | day | week | month`. Useful
 for news-cycle topics; omit for evergreen research.
 
-## Anti-Patterns
-
-- ❌ Sending NO brain context. Then it's just a search — use `web_fetch`
+## Anti-Patterns (( role: procedure ))
+
+!!! checklist (( ai-autonomy ))
+- [ ] ❌ Sending NO brain context. Then it's just a search — use `web_fetch`
   instead.
-- ❌ Truncating the brain context. The whole point is "knows what you
+- [ ] ❌ Truncating the brain context. The whole point is "knows what you
   know." Send dense context.
-- ❌ Discarding citations. Every claim in the output must have a URL.
-- ❌ Skipping the cross-link step when entities are mentioned. Iron Law.
-
-## Environment
-
-- `PERPLEXITY_API_KEY` set in the agent's environment (or in
-  `~/.gbrain/.env`).
-- Optional: install Perplexity's official CLI for richer streaming output.
-
-## Related skills
+- [ ] ❌ Discarding citations. Every claim in the output must have a URL.
+- [ ] ❌ Skipping the cross-link step when entities are mentioned. Iron Law.
+
+## Environment (( role: procedure ))
+
+use judgment to follow the Environment guidance:
+  item: `PERPLEXITY_API_KEY` set in the agent's environment (or in
+    `~/.gbrain/.env`).
+  item: Optional: install Perplexity's official CLI for richer streaming output.
+## Related skills (( inert ))
 
 - `skills/academic-verify/SKILL.md` — wraps perplexity-research for
   citation-verified academic claim checking
@@ -183,16 +184,17 @@
   shape: parameterized YAML recipes, not free-form research)
 
 
-## Contract
-
-This skill guarantees:
-
-- Routing matches the canonical triggers in the frontmatter.
-- Output written under the directories listed in `writes_to:` (when applicable).
-- Conventions referenced (`quality.md`, `brain-first.md`, `_brain-filing-rules.md`) are followed.
-- Privacy contract preserved: no real names, no fork-specific filesystem path literals, no upstream-fork references.
-
-The full behavior contract is documented in the body sections above; this section exists for the conformance test.
+## Contract (( role: procedure ))
+
+> This skill guarantees:
+
+!!! checklist (( ai-autonomy ))
+- [ ] Routing matches the canonical triggers in the frontmatter.
+- [ ] Output written under the directories listed in `writes_to:` (when applicable).
+- [ ] Conventions referenced (`quality.md`, `brain-first.md`, `_brain-filing-rules.md`) are followed.
+- [ ] Privacy contract preserved: no real names, no fork-specific filesystem path literals, no upstream-fork references.
+
+> The full behavior contract is documented in the body sections above; this section exists for the conformance test.
 
 ## Output Format
 
```
