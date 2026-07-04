# Deviation: academic_verify.meri

- Original: `academic-verify/SKILL.md`
- Ported: `academic_verify.meri`
- Tier: 1 (near-verbatim)
- Similarity: 93%
- Lines: 226 -> 226 (+16 / -16)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- inert-section-added

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L12 `What this is`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L35 `When to use this`: operational-procedure - Marked or derived as applicability, but inert suppresses execution.
- L46 `What this skill is NOT`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L53 `How it works (D7/α: pure routing through perplexity-research)`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L97 `Output: brain page format`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L143 `Useful databases (the agent uses these via perplexity-research)`: operational-content - Body contains command, table, checklist, or explicit AI-routing surface.
- L154 `Standards (the rigor bar)`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L175 `Anti-Patterns`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L187 `Related skills`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L196 `Contract`: normative-contract - Normative invariants prose needs mining into assertions or explicit AI routing.
- L207 `Output Format`: template - Template/output shape is metadata unless explicit output assertions are authored.

## Metrics
- Sections: 11/11 inert (100% inert ratio)
- Operational inert: 3
- Unclassified inert: 0
- Inert categories: normative-contract=1, operational-content=1, operational-procedure=1, reference-documentation=7, template=1
- Judgment: 0 blocks, 0 lines

### Inert section details
- L12 `What this is`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L35 `When to use this`: operational-procedure — Marked or derived as applicability, but inert suppresses execution.
- L46 `What this skill is NOT`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L53 `How it works (D7/α: pure routing through perplexity-research)`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L97 `Output: brain page format`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L143 `Useful databases (the agent uses these via perplexity-research)`: operational-content — Body contains command, table, checklist, or explicit AI-routing surface.
- L154 `Standards (the rigor bar)`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L175 `Anti-Patterns`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L187 `Related skills`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L196 `Contract`: normative-contract — Normative invariants prose needs mining into assertions or explicit AI routing.
- L207 `Output Format`: template — Template/output shape is metadata unless explicit output assertions are authored.

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
@@ -48,7 +48,7 @@
 the claim, the trace, and the verdict — so future references to the
 same claim can re-use the verified analysis.
 
-## When to use this
+## When to use this (( inert, role: applicability ))
 
 - A book quotes a study and you want to confirm it's real and not
   miscited
@@ -59,14 +59,14 @@
 - You're updating a brain page that cites a research claim and you want
   to record the verification status alongside
 
-## What this skill is NOT
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
@@ -139,24 +139,24 @@
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
+## Useful databases (the agent uses these via perplexity-research) (( inert ))
 
 | Database | What it has | URL pattern |
 |----------|-------------|-------------|
@@ -167,7 +167,7 @@
 | OpenAlex | Open citation data, institutional affiliations | api.openalex.org |
 | Many Labs | Replication results for social psychology | osf.io/wx7ck/ |
 
-## Standards (the rigor bar)
+## Standards (the rigor bar) (( inert ))
 
 - **Verified** — only when the underlying paper exists, raw data is
   public OR an independent lab has confirmed the result, and the citing
@@ -188,7 +188,7 @@
 itself is the artifact — if the claim holds up, say so plainly. If it
 doesn't, the trace speaks for itself.
 
-## Anti-Patterns
+## Anti-Patterns (( inert, role: prohibitions ))
 
 - ❌ Skipping the brain-first lookup. Re-doing verification we've
   already done is wasted Perplexity spend.
@@ -200,7 +200,7 @@
 - ❌ Stating "Unverifiable" when you simply didn't look hard enough.
   The verdict is on the source, not on your search effort.
 
-## Related skills
+## Related skills (( inert ))
 
 - `skills/perplexity-research/SKILL.md` — the actual web-search engine
   this skill routes through (D7/α: pure routing, no new infrastructure)
@@ -209,7 +209,7 @@
 - `skills/conventions/quality.md` — citation + back-link rules
 
 
-## Contract
+## Contract (( inert, role: invariants ))
 
 This skill guarantees:
 
@@ -220,7 +220,7 @@
 
 The full behavior contract is documented in the body sections above; this section exists for the conformance test.
 
-## Output Format
+## Output Format (( inert, role: template ))
 
 The skill's output shape is documented inline in the body sections above (see "Output", "Brain page format", or equivalent). The literal section header here exists for the conformance test (`test/skills-conformance.test.ts`).
 
```
