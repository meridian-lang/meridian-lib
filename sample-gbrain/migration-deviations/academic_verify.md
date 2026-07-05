# Deviation: academic_verify.meri

- Original: `academic-verify/SKILL.md`
- Ported: `academic_verify.meri`
- Tier: 1 (near-verbatim)
- Similarity: 93%
- Lines: 226 -> 242 (+25 / -9)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- doc-section-marked

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L12 `What this is`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L35 `When to use this`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L56 `How it works (D7/α: pure routing through perplexity-research)`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L100 `Output: brain page format`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L188 `Anti-Patterns`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L212 `Contract`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L223 `Output Format`: template - Template/output shape is metadata unless explicit output assertions are authored.

## Metrics
- Sections inert total: 9/9 (100% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert markers (`(( inert ))`, target 0 — the migrator never emits these): 0
- Inert categories: reference-documentation=8, template=1
- Judgment: 1 blocks, 0 lines

### Inert section details
- L12 `What this is`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L35 `When to use this`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L46 `What this skill is NOT`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L56 `How it works (D7/α: pure routing through perplexity-research)`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L100 `Output: brain page format`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L160 `Standards (the rigor bar)`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L188 `Anti-Patterns`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L212 `Contract`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L223 `Output Format`: template — Template/output shape is metadata unless explicit output assertions are authored.

## Unified diff

```diff
--- original-skills/academic-verify/SKILL.md
+++ skills/academic_verify.meri
@@ -25,7 +25,7 @@
 > for the lookup chain. This skill enforces brain-first by checking
 > existing brain pages before issuing a fresh web search.
 
-## What this is
+## What this is (( role: reference ))
 
 A claim-verification flow for academic / research statements. When a
 book, article, or speaker cites a study or quotes a number, this skill
@@ -48,7 +48,7 @@
 the claim, the trace, and the verdict — so future references to the
 same claim can re-use the verified analysis.
 
-## When to use this
+## When to use this (( role: reference ))
 
 - A book quotes a study and you want to confirm it's real and not
   miscited
@@ -59,14 +59,17 @@
 - You're updating a brain page that cites a research claim and you want
   to record the verification status alongside
 
-## What this skill is NOT
+## What this skill is NOT (( role: reference ))
 
 - Not adversarial / oppo work. The point is rigor, not takedown.
+
+### What this skill is NOT — steps (( role: reference ))
+
 - Not generic web research — use `perplexity-research` directly for
   open-ended topic exploration.
 - Not a brain-only lookup — that's `gbrain query`.
 
-## How it works (D7/α: pure routing through perplexity-research)
+## How it works (D7/α: pure routing through perplexity-research) (( role: reference ))
 
 academic-verify is a thin orchestrator. The actual web search is done
 by [perplexity-research](../perplexity-research/SKILL.md). academic-verify's
@@ -110,7 +113,7 @@
   one if notable. Iron Law per conventions/quality.md.
 ```
 
-## Output: brain page format
+## Output: brain page format (( role: reference ))
 
 ```markdown
 ---
@@ -157,6 +160,9 @@
 ```
 
 ## Useful databases (the agent uses these via perplexity-research)
+
+
+### Useful databases (the agent uses these via perplexity-research) — steps (( role: reference ))
 
 | Database | What it has | URL pattern |
 |----------|-------------|-------------|
@@ -167,7 +173,7 @@
 | OpenAlex | Open citation data, institutional affiliations | api.openalex.org |
 | Many Labs | Replication results for social psychology | osf.io/wx7ck/ |
 
-## Standards (the rigor bar)
+## Standards (the rigor bar) (( role: reference ))
 
 - **Verified** — only when the underlying paper exists, raw data is
   public OR an independent lab has confirmed the result, and the citing
@@ -180,15 +186,22 @@
   exists. Not the same as "wrong" — say "we couldn't verify."
 - **Misattributed** — the citation points to a paper, but the paper
   doesn't actually say what the citation claims. Common in policy briefs.
+
+### Standards (the rigor bar) — steps
+
+use judgment to follow the Standards (the rigor bar) — steps guidance:
 - **Retracted / disputed** — paper has been retracted, has a major
   expression-of-concern, or has well-documented critique that
   contradicts the headline finding.
 
+
+### Standards (the rigor bar) — steps 2
+
 Never claim a problem without evidence. The verification document
 itself is the artifact — if the claim holds up, say so plainly. If it
 doesn't, the trace speaks for itself.
 
-## Anti-Patterns
+## Anti-Patterns (( role: reference ))
 
 - ❌ Skipping the brain-first lookup. Re-doing verification we've
   already done is wasted Perplexity spend.
@@ -202,6 +215,9 @@
 
 ## Related skills
 
+
+### Related skills — steps
+
 - `skills/perplexity-research/SKILL.md` — the actual web-search engine
   this skill routes through (D7/α: pure routing, no new infrastructure)
 - `skills/citation-fixer/SKILL.md` — fixes citation FORMATTING; this
@@ -209,7 +225,7 @@
 - `skills/conventions/quality.md` — citation + back-link rules
 
 
-## Contract
+## Contract (( role: reference ))
 
 This skill guarantees:
 
@@ -220,7 +236,7 @@
 
 The full behavior contract is documented in the body sections above; this section exists for the conformance test.
 
-## Output Format
+## Output Format (( role: template ))
 
 The skill's output shape is documented inline in the body sections above (see "Output", "Brain page format", or equivalent). The literal section header here exists for the conformance test (`test/skills-conformance.test.ts`).
 
```
