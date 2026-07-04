# Deviation: academic_verify.meri

- Original: `academic-verify/SKILL.md`
- Ported: `academic_verify.meri`
- Tier: 1 (near-verbatim)
- Similarity: 92%
- Lines: 226 -> 240 (+25 / -11)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- shell-block-routed
- inert-section-added

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L12 `What this is`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L57 `How it works (D7/α: pure routing through perplexity-research)`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L101 `Output: brain page format`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L221 `Output Format`: template - Template/output shape is metadata unless explicit output assertions are authored.

## Metrics
- Sections inert total: 5/9 (56% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert categories: reference-documentation=4, template=1
- Judgment: 4 blocks, 0 lines

### Inert section details
- L12 `What this is`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L47 `What this skill is NOT`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L57 `How it works (D7/α: pure routing through perplexity-research)`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L101 `Output: brain page format`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L221 `Output Format`: template — Template/output shape is metadata unless explicit output assertions are authored.

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
@@ -48,7 +48,8 @@
 the claim, the trace, and the verdict — so future references to the
 same claim can re-use the verified analysis.
 
-## When to use this
+## When to use this (( role: procedure ))
+use judgment to follow the When to use this guidance:
 
 - A book quotes a study and you want to confirm it's real and not
   miscited
@@ -59,14 +60,17 @@
 - You're updating a brain page that cites a research claim and you want
   to record the verification status alongside
 
-## What this skill is NOT
+## What this skill is NOT (( inert ))
 
 - Not adversarial / oppo work. The point is rigor, not takedown.
+
+### What this skill is NOT — steps
+
 - Not generic web research — use `perplexity-research` directly for
   open-ended topic exploration.
 - Not a brain-only lookup — that's `gbrain query`.
 
-## How it works (D7/α: pure routing through perplexity-research)
+## How it works (D7/α: pure routing through perplexity-research) (( inert ))
 
 academic-verify is a thin orchestrator. The actual web search is done
 by [perplexity-research](../perplexity-research/SKILL.md). academic-verify's
@@ -110,7 +114,7 @@
   one if notable. Iron Law per conventions/quality.md.
 ```
 
-## Output: brain page format
+## Output: brain page format (( inert ))
 
 ```markdown
 ---
@@ -156,8 +160,12 @@
 - Related claims (verified or otherwise): [...]
 ```
 
-## Useful databases (the agent uses these via perplexity-research)
-
+## Useful databases (the agent uses these via perplexity-research) (( inert ))
+
+
+### Useful databases (the agent uses these via perplexity-research) — steps
+
+!!! table (( ai-discretion ))
 | Database | What it has | URL pattern |
 |----------|-------------|-------------|
 | Retraction Watch | Retractions, corrections, expressions of concern | retractionwatch.com/?s=NAME |
@@ -168,6 +176,7 @@
 | Many Labs | Replication results for social psychology | osf.io/wx7ck/ |
 
 ## Standards (the rigor bar)
+use judgment to follow the Standards (the rigor bar) guidance:
 
 - **Verified** — only when the underlying paper exists, raw data is
   public OR an independent lab has confirmed the result, and the citing
@@ -188,7 +197,8 @@
 itself is the artifact — if the claim holds up, say so plainly. If it
 doesn't, the trace speaks for itself.
 
-## Anti-Patterns
+## Anti-Patterns (( role: procedure ))
+use judgment to follow the Anti-Patterns guidance:
 
 - ❌ Skipping the brain-first lookup. Re-doing verification we've
   already done is wasted Perplexity spend.
@@ -200,7 +210,10 @@
 - ❌ Stating "Unverifiable" when you simply didn't look hard enough.
   The verdict is on the source, not on your search effort.
 
-## Related skills
+## Related skills (( inert, role: procedure ))
+
+
+### Related skills — steps
 
 - `skills/perplexity-research/SKILL.md` — the actual web-search engine
   this skill routes through (D7/α: pure routing, no new infrastructure)
@@ -209,7 +222,8 @@
 - `skills/conventions/quality.md` — citation + back-link rules
 
 
-## Contract
+## Contract (( role: procedure ))
+use judgment to follow the Contract guidance:
 
 This skill guarantees:
 
@@ -220,7 +234,7 @@
 
 The full behavior contract is documented in the body sections above; this section exists for the conformance test.
 
-## Output Format
+## Output Format (( inert, role: template ))
 
 The skill's output shape is documented inline in the body sections above (see "Output", "Brain page format", or equivalent). The literal section header here exists for the conformance test (`test/skills-conformance.test.ts`).
 
```
