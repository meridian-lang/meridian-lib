# Deviation: citation_fixer.meri

- Original: `citation-fixer/SKILL.md`
- Ported: `citation_fixer.meri`
- Tier: 1 (near-verbatim)
- Similarity: 93%
- Lines: 209 -> 209 (+15 / -15)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- inert-section-added

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L10 `Contract`: normative-contract - Normative invariants prose needs mining into assertions or explicit AI routing.
- L22 `Phases`: operational-procedure - Marked or derived as procedure, but inert suppresses execution.
- L38 `Tweet resolution pipeline (v0.25.1 extension)`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L45 `Step 1: Identify broken references`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L56 `Step 2: Extract searchable content`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L64 `Step 3: Search for the actual tweet`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L79 `Step 4: Verify and extract metadata`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L88 `Step 5: Patch the brain page`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L105 `Batch mode`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L122 `Priority order`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L129 `Rate limiting`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L137 `Output format`: template - Template/output shape is metadata unless explicit output assertions are authored.
- L149 `Anti-Patterns`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L159 `Integration`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L168 `Metrics`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L185 `Output Format`: template - Template/output shape is metadata unless explicit output assertions are authored.

## Metrics
- Sections: 16/17 inert (94% inert ratio)
- Operational inert: 2
- Unclassified inert: 0
- Inert categories: normative-contract=1, operational-procedure=1, reference-documentation=12, template=2
- Judgment: 0 blocks, 0 lines

### Inert section details
- L10 `Contract`: normative-contract — Normative invariants prose needs mining into assertions or explicit AI routing.
- L22 `Phases`: operational-procedure — Marked or derived as procedure, but inert suppresses execution.
- L38 `Tweet resolution pipeline (v0.25.1 extension)`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L45 `Step 1: Identify broken references`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L56 `Step 2: Extract searchable content`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L64 `Step 3: Search for the actual tweet`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L79 `Step 4: Verify and extract metadata`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L88 `Step 5: Patch the brain page`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L105 `Batch mode`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L122 `Priority order`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L129 `Rate limiting`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L137 `Output format`: template — Template/output shape is metadata unless explicit output assertions are authored.
- L149 `Anti-Patterns`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L159 `Integration`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L168 `Metrics`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L185 `Output Format`: template — Template/output shape is metadata unless explicit output assertions are authored.

## Unified diff

```diff
--- original-skills/citation-fixer/SKILL.md
+++ skills/citation_fixer.meri
@@ -28,7 +28,7 @@
 > **Output rule:** all links MUST be deterministic (built from API data,
 > not composed by LLM). See [_output-rules.md](../_output-rules.md).
 
-## Contract
+## Contract (( inert, role: invariants ))
 
 This skill guarantees:
 
@@ -40,7 +40,7 @@
   links.
 - Results reported with counts (scanned, fixed, remaining).
 
-## Phases
+## Phases (( inert, role: procedure ))
 
 1. **Scan pages.** List pages and read each one, checking for inline
    `[Source: ...]` citations.
@@ -56,14 +56,14 @@
 5. **Report results.** Count: pages scanned, citations found, issues
    fixed, tweets resolved, remaining gaps.
 
-## Tweet resolution pipeline (v0.25.1 extension)
+## Tweet resolution pipeline (v0.25.1 extension) (( inert ))
 
 For each broken tweet reference, follow this chain. The actual API call
 goes through whatever X integration the host has configured (typical
 shape: a recipe under `recipes/x-api/` with handle / search-all
 endpoints).
 
-### Step 1: Identify broken references
+### Step 1: Identify broken references (( inert ))
 
 Scan the page for patterns that indicate tweet references without URLs:
 
@@ -74,7 +74,7 @@
 - Has `[Source: ... X/Twitter ...]` without an `x.com` URL
 - References engagement metrics (likes, impressions) without a link
 
-### Step 2: Extract searchable content
+### Step 2: Extract searchable content (( inert ))
 
 From each broken reference, extract:
 
@@ -82,7 +82,7 @@
 - The **quoted text** (if available)
 - The **approximate date** (often present in surrounding timeline entries)
 
-### Step 3: Search for the actual tweet
+### Step 3: Search for the actual tweet (( inert ))
 
 Use the host's X API integration. Query patterns:
 
@@ -97,7 +97,7 @@
 "<exact quote>" -is:retweet
 ```
 
-### Step 4: Verify and extract metadata
+### Step 4: Verify and extract metadata (( inert ))
 
 Once a candidate is found:
 
@@ -106,7 +106,7 @@
   impressions).
 - Construct the URL: `https://x.com/<handle>/status/<tweet_id>`.
 
-### Step 5: Patch the brain page
+### Step 5: Patch the brain page (( inert ))
 
 Replace the broken citation with a proper one:
 
@@ -123,7 +123,7 @@
 [Source: [X/<handle>, YYYY-MM-DD](https://x.com/<handle>/status/<tweet_id>)]
 ```
 
-## Batch mode
+## Batch mode (( inert ))
 
 When sweeping many pages:
 
@@ -140,14 +140,14 @@
 done
 ```
 
-### Priority order
+### Priority order (( inert ))
 
 1. Recently created / updated pages — fresh broken refs are easiest to
    resolve while context is fresh.
 2. High-traffic pages (frequent reads / writes from other skills).
 3. Everything else — bulk cleanup over time.
 
-### Rate limiting
+### Rate limiting (( inert ))
 
 - X API: respect the host's tier limits; don't hammer.
 - Target ~50 pages per batch run.
@@ -167,7 +167,7 @@
 Remaining gaps:       N (pages with uncitable facts)
 ```
 
-## Anti-Patterns
+## Anti-Patterns (( inert, role: prohibitions ))
 
 - ❌ Inventing citations for facts that have no source. Flag them.
 - ❌ Removing facts that lack citations (flag them; don't delete).
@@ -177,7 +177,7 @@
 - ❌ Composing tweet URLs by guessing the tweet id. Always go through
   the X API; deterministic links only.
 
-## Integration
+## Integration (( inert ))
 
 This skill can be called:
 
@@ -186,7 +186,7 @@
 - **By other skills** — `enrich` or `media-ingest` can call citation-fixer
   before commit to validate output
 
-## Metrics
+## Metrics (( inert ))
 
 If running as a recurring batch, track state in a small JSON file under
 `~/.gbrain/citation-fixer-state.json`:
@@ -203,7 +203,7 @@
 ```
 
 
-## Output Format
+## Output Format (( inert, role: template ))
 
 The skill's output shape is documented inline in the body sections above (see "Output", "Brain page format", or equivalent). The literal section header here exists for the conformance test (`test/skills-conformance.test.ts`).
 
```
