# Deviation: academic_verify.meri

- Original: `academic-verify/SKILL.md`
- Ported: `academic_verify.meri`
- Tier: 2 (light edits)
- Similarity: 78%
- Lines: 226 -> 228 (+51 / -49)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- shell-block-routed

## Metrics
- Sections: 7/11 inert (64% inert ratio)
- Operational inert: 0
- Unclassified inert: 0
- Inert categories: reference-documentation=6, template=1
- Judgment: 2 blocks, 16 lines

### Inert section details
- L12 `What this is`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L46 `What this skill is NOT`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L53 `How it works (D7/α: pure routing through perplexity-research)`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L97 `Output: brain page format`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L154 `Standards (the rigor bar)`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L188 `Related skills`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L209 `Output Format`: template — Template/output shape is metadata unless explicit output assertions are authored.

## Unified diff

```diff
--- original-skills/academic-verify/SKILL.md
+++ skills/academic_verify.meri
@@ -25,7 +25,7 @@
 > for the lookup chain. This skill enforces brain-first by checking
 > existing brain pages before issuing a fresh web search.
 
-## What this is
+## What this is (( inert ))
 
 A claim-verification flow for academic / research statements. When a
 book, article, or speaker cites a study or quotes a number, this skill
@@ -48,25 +48,25 @@
 the claim, the trace, and the verdict — so future references to the
 same claim can re-use the verified analysis.
 
-## When to use this
-
-- A book quotes a study and you want to confirm it's real and not
-  miscited
-- An article makes a quantified claim ("X reduced Y by 40%") that you
-  want traced to the source data
-- You're writing something that depends on a piece of research and you
-  want to verify the underlying paper holds up
-- You're updating a brain page that cites a research claim and you want
-  to record the verification status alongside
-
-## What this skill is NOT
+## When to use this (( role: procedure ))
+
+use judgment to follow the When to use this guidance:
+  item: A book quotes a study and you want to confirm it's real and not
+    miscited
+  item: An article makes a quantified claim ("X reduced Y by 40%") that you
+    want traced to the source data
+  item: You're writing something that depends on a piece of research and you
+    want to verify the underlying paper holds up
+  item: You're updating a brain page that cites a research claim and you want
+    to record the verification status alongside
+## What this skill is NOT (( inert ))
 
 - Not adversarial / oppo work. The point is rigor, not takedown.
 - Not generic web research — use `perplexity-research` directly for
   open-ended topic exploration.
 - Not a brain-only lookup — that's `gbrain query`.
 
-## How it works (D7/α: pure routing through perplexity-research)
+## How it works (D7/α: pure routing through perplexity-research) (( inert ))
 
 academic-verify is a thin orchestrator. The actual web search is done
 by [perplexity-research](../perplexity-research/SKILL.md). academic-verify's
@@ -110,7 +110,7 @@
   one if notable. Iron Law per conventions/quality.md.
 ```
 
-## Output: brain page format
+## Output: brain page format (( inert ))
 
 ```markdown
 ---
@@ -125,11 +125,11 @@
 
 > One-line: the verdict + the bottom-line reason.
 
-## The Claim
+## The Claim (( inert ))
 
 > Exact quote, exactly as stated, with source attribution.
 
-## Trace
+## Trace (( inert ))
 
 | Step | Finding | Source |
 |------|---------|--------|
@@ -139,35 +139,35 @@
 | Independent replication | [Replication studies and their results] | [URL] |
 | Critical citations | [Papers that critique this work] | [URL] |
 
-## Verdict
+## Verdict (( inert ))
 
 [Verified / Partially verified / Unverifiable / Misattributed / Retracted]
 
 [1-2 paragraphs explaining WHY the verdict, with specific evidence.]
 
-## Caveats
+## Caveats (( inert ))
 
 [Honest limits: what we couldn't verify, what would change the verdict.]
 
-## See Also
+## See Also (( inert ))
 
 - Original paper: [Title](DOI URL)
 - Authors' brain pages: [Author 1](people/author-1.md), ...
 - Related claims (verified or otherwise): [...]
 ```
 
-## Useful databases (the agent uses these via perplexity-research)
-
-| Database | What it has | URL pattern |
-|----------|-------------|-------------|
-| Retraction Watch | Retractions, corrections, expressions of concern | retractionwatch.com/?s=NAME |
-| PubPeer | Anonymous post-publication peer review | pubpeer.com/search?q=NAME |
-| OSF | Pre-registrations, open data, open materials | osf.io/search/?q=QUERY |
-| Semantic Scholar | Citation analysis, paper metadata | api.semanticscholar.org |
-| OpenAlex | Open citation data, institutional affiliations | api.openalex.org |
-| Many Labs | Replication results for social psychology | osf.io/wx7ck/ |
-
-## Standards (the rigor bar)
+## Useful databases (the agent uses these via perplexity-research) (( role: procedure ))
+
+use judgment to follow the Useful databases (the agent uses these via perplexity-research) guidance:
+  | Database | What it has | URL pattern |
+  |----------|-------------|-------------|
+  | Retraction Watch | Retractions, corrections, expressions of concern | retractionwatch.com/?s=NAME |
+  | PubPeer | Anonymous post-publication peer review | pubpeer.com/search?q=NAME |
+  | OSF | Pre-registrations, open data, open materials | osf.io/search/?q=QUERY |
+  | Semantic Scholar | Citation analysis, paper metadata | api.semanticscholar.org |
+  | OpenAlex | Open citation data, institutional affiliations | api.openalex.org |
+  | Many Labs | Replication results for social psychology | osf.io/wx7ck/ |
+## Standards (the rigor bar) (( inert ))
 
 - **Verified** — only when the underlying paper exists, raw data is
   public OR an independent lab has confirmed the result, and the citing
@@ -188,19 +188,20 @@
 itself is the artifact — if the claim holds up, say so plainly. If it
 doesn't, the trace speaks for itself.
 
-## Anti-Patterns
-
-- ❌ Skipping the brain-first lookup. Re-doing verification we've
+## Anti-Patterns (( role: procedure ))
+
+!!! checklist (( ai-autonomy ))
+- [ ] ❌ Skipping the brain-first lookup. Re-doing verification we've
   already done is wasted Perplexity spend.
-- ❌ Bypassing perplexity-research and inventing the lookup. The
+- [ ] ❌ Bypassing perplexity-research and inventing the lookup. The
   citations from Perplexity are the evidence — without them, the
   verdict is just opinion.
-- ❌ Stating "Verified" without confirming raw data availability.
+- [ ] ❌ Stating "Verified" without confirming raw data availability.
   Replication trumps any single paper.
-- ❌ Stating "Unverifiable" when you simply didn't look hard enough.
+- [ ] ❌ Stating "Unverifiable" when you simply didn't look hard enough.
   The verdict is on the source, not on your search effort.
 
-## Related skills
+## Related skills (( inert ))
 
 - `skills/perplexity-research/SKILL.md` — the actual web-search engine
   this skill routes through (D7/α: pure routing, no new infrastructure)
@@ -209,16 +210,17 @@
 - `skills/conventions/quality.md` — citation + back-link rules
 
 
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
