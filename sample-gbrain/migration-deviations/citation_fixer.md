# Deviation: citation_fixer.meri

- Original: `citation-fixer/SKILL.md`
- Ported: `citation_fixer.meri`
- Tier: 2 (light edits)
- Similarity: 84%
- Lines: 209 -> 226 (+44 / -27)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- doc-section-marked

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L10 `Contract`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L54 `Step 1: Identify broken references`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L65 `Step 2: Extract searchable content`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L73 `Step 3: Search for the actual tweet`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L100 `Step 5: Patch the brain page`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L117 `Batch mode`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L134 `Priority order`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L141 `Rate limiting`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L149 `Output format`: template - Template/output shape is metadata unless explicit output assertions are authored.
- L173 `Integration`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L202 `Output Format`: template - Template/output shape is metadata unless explicit output assertions are authored.

## Metrics
- Sections inert total: 15/16 (94% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert markers (`(( inert ))`, target 0 — the migrator never emits these): 0
- Inert categories: reference-documentation=13, template=2
- Judgment: 0 blocks, 0 lines

### Inert section details
- L10 `Contract`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L22 `Phases`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L54 `Step 1: Identify broken references`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L65 `Step 2: Extract searchable content`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L73 `Step 3: Search for the actual tweet`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L88 `Step 4: Verify and extract metadata`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L100 `Step 5: Patch the brain page`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L117 `Batch mode`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L134 `Priority order`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L141 `Rate limiting`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L149 `Output format`: template — Template/output shape is metadata unless explicit output assertions are authored.
- L161 `Anti-Patterns`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L173 `Integration`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L182 `Metrics`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L202 `Output Format`: template — Template/output shape is metadata unless explicit output assertions are authored.

## Unified diff

```diff
--- original-skills/citation-fixer/SKILL.md
+++ skills/citation_fixer.meri
@@ -28,42 +28,51 @@
 > **Output rule:** all links MUST be deterministic (built from API data,
 > not composed by LLM). See [_output-rules.md](../_output-rules.md).
 
-## Contract
+## Contract (( role: reference ))
 
 This skill guarantees:
 
 - Every brain page is scanned for citation compliance.
 - Missing citations are flagged with specific location.
 - Malformed citations are fixed to match the standard format.
-- **(v0.25.1)** Tweet / post references without URLs are resolved via
+- (v0.25.1) Tweet / post references without URLs are resolved via
   X API and patched with deterministic `https://x.com/<handle>/status/<id>`
   links.
 - Results reported with counts (scanned, fixed, remaining).
 
-## Phases
-
-1. **Scan pages.** List pages and read each one, checking for inline
-   `[Source: ...]` citations.
+## Phases (( role: reference ))
+
 2. **Identify issues:**
    - Facts without any citation
    - Citations missing date
    - Citations missing source type
    - Citations with wrong format
-   - **(v0.25.1)** Tweet references without `x.com` URLs
-3. **Fix format issues.** Rewrite malformed citations to match
-   `conventions/quality.md`.
 4. **(v0.25.1) Resolve tweet references** via the X API integration.
 5. **Report results.** Count: pages scanned, citations found, issues
    fixed, tweets resolved, remaining gaps.
 
+
+### Phases — steps
+
+1. List pages and read each one, checking for inline
+   `[Source: ...]` citations.
+
+### Phases — steps 2 (( role: reference ))
+
+   - (v0.25.1) Tweet references without `x.com` URLs
+3. Rewrite malformed citations to match
+   `conventions/quality.md`.
 ## Tweet resolution pipeline (v0.25.1 extension)
+
+
+### Tweet resolution pipeline (v0.25.1 extension) — steps (( role: reference ))
 
 For each broken tweet reference, follow this chain. The actual API call
 goes through whatever X integration the host has configured (typical
 shape: a recipe under `recipes/x-api/` with handle / search-all
 endpoints).
 
-### Step 1: Identify broken references
+### Step 1: Identify broken references (( role: reference ))
 
 Scan the page for patterns that indicate tweet references without URLs:
 
@@ -74,7 +83,7 @@
 - Has `[Source: ... X/Twitter ...]` without an `x.com` URL
 - References engagement metrics (likes, impressions) without a link
 
-### Step 2: Extract searchable content
+### Step 2: Extract searchable content (( role: reference ))
 
 From each broken reference, extract:
 
@@ -82,7 +91,7 @@
 - The **quoted text** (if available)
 - The **approximate date** (often present in surrounding timeline entries)
 
-### Step 3: Search for the actual tweet
+### Step 3: Search for the actual tweet (( role: reference ))
 
 Use the host's X API integration. Query patterns:
 
@@ -97,16 +106,19 @@
 "<exact quote>" -is:retweet
 ```
 
-### Step 4: Verify and extract metadata
+### Step 4: Verify and extract metadata (( role: reference ))
 
 Once a candidate is found:
 
 - Confirm the text matches the quoted fragment.
 - Pull the tweet id, author handle, engagement metrics (likes / RTs /
   impressions).
+
+### Step 4: Verify and extract metadata — steps
+
 - Construct the URL: `https://x.com/<handle>/status/<tweet_id>`.
 
-### Step 5: Patch the brain page
+### Step 5: Patch the brain page (( role: reference ))
 
 Replace the broken citation with a proper one:
 
@@ -123,7 +135,7 @@
 [Source: [X/<handle>, YYYY-MM-DD](https://x.com/<handle>/status/<tweet_id>)]
 ```
 
-## Batch mode
+## Batch mode (( role: reference ))
 
 When sweeping many pages:
 
@@ -140,14 +152,14 @@
 done
 ```
 
-### Priority order
+### Priority order (( role: reference ))
 
 1. Recently created / updated pages — fresh broken refs are easiest to
    resolve while context is fresh.
 2. High-traffic pages (frequent reads / writes from other skills).
 3. Everything else — bulk cleanup over time.
 
-### Rate limiting
+### Rate limiting (( role: reference ))
 
 - X API: respect the host's tier limits; don't hammer.
 - Target ~50 pages per batch run.
@@ -167,17 +179,19 @@
 Remaining gaps:       N (pages with uncitable facts)
 ```
 
-## Anti-Patterns
+## Anti-Patterns (( role: reference ))
 
 - ❌ Inventing citations for facts that have no source. Flag them.
 - ❌ Removing facts that lack citations (flag them; don't delete).
 - ❌ Fixing citations without reading the full page context.
 - ❌ Batch-fixing without checking quality on a sample first
   (see `conventions/test-before-bulk.md`).
-- ❌ Composing tweet URLs by guessing the tweet id. Always go through
-  the X API; deterministic links only.
-
-## Integration
+
+### Anti-Patterns — steps (( role: reference ))
+
+- ❌ Composing tweet URLs by guessing the tweet id. Always go through the X API; deterministic links only.
+
+## Integration (( role: reference ))
 
 This skill can be called:
 
@@ -186,10 +200,7 @@
 - **By other skills** — `enrich` or `media-ingest` can call citation-fixer
   before commit to validate output
 
-## Metrics
-
-If running as a recurring batch, track state in a small JSON file under
-`~/.gbrain/citation-fixer-state.json`:
+## Metrics (( role: reference ))
 
 ```json
 {
@@ -203,7 +214,13 @@
 ```
 
 
-## Output Format
+
+### Metrics — steps (( role: reference ))
+
+If running as a recurring batch, track state in a small JSON file under
+`~/.gbrain/citation-fixer-state.json`:
+
+## Output Format (( role: template ))
 
 The skill's output shape is documented inline in the body sections above (see "Output", "Brain page format", or equivalent). The literal section header here exists for the conformance test (`test/skills-conformance.test.ts`).
 
```
