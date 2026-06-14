# Deviation: citation_fixer.meri

- Original: `citation-fixer/SKILL.md`
- Ported: `citation_fixer.meri`
- Tier: 2 (light edits)
- Similarity: 73%
- Lines: 209 -> 203 (+52 / -58)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- shell-block-routed

## Metrics
- Sections: 12/17 inert (71% inert ratio)
- Operational inert: 0
- Unclassified inert: 0
- Inert categories: reference-documentation=10, template=2
- Judgment: 2 blocks, 17 lines

### Inert section details
- L32 `Tweet resolution pipeline (v0.25.1 extension)`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L39 `Step 1: Identify broken references`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L50 `Step 2: Extract searchable content`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L58 `Step 3: Search for the actual tweet`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L73 `Step 4: Verify and extract metadata`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L82 `Step 5: Patch the brain page`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L99 `Batch mode`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L116 `Priority order`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L123 `Rate limiting`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L131 `Output format`: template — Template/output shape is metadata unless explicit output assertions are authored.
- L154 `Integration`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L179 `Output Format`: template — Template/output shape is metadata unless explicit output assertions are authored.

## Unified diff

```diff
--- original-skills/citation-fixer/SKILL.md
+++ skills/citation_fixer.meri
@@ -28,42 +28,36 @@
 > **Output rule:** all links MUST be deterministic (built from API data,
 > not composed by LLM). See [_output-rules.md](../_output-rules.md).
 
-## Contract
-
-This skill guarantees:
-
-- Every brain page is scanned for citation compliance.
-- Missing citations are flagged with specific location.
-- Malformed citations are fixed to match the standard format.
-- **(v0.25.1)** Tweet / post references without URLs are resolved via
+## Contract (( role: procedure ))
+
+> This skill guarantees:
+
+!!! checklist (( ai-autonomy ))
+- [ ] Every brain page is scanned for citation compliance.
+- [ ] Missing citations are flagged with specific location.
+- [ ] Malformed citations are fixed to match the standard format.
+- [ ] **(v0.25.1)** Tweet / post references without URLs are resolved via
   X API and patched with deterministic `https://x.com/<handle>/status/<id>`
   links.
-- Results reported with counts (scanned, fixed, remaining).
+- [ ] Results reported with counts (scanned, fixed, remaining).
 
 ## Phases
 
-1. **Scan pages.** List pages and read each one, checking for inline
-   `[Source: ...]` citations.
-2. **Identify issues:**
-   - Facts without any citation
-   - Citations missing date
-   - Citations missing source type
-   - Citations with wrong format
-   - **(v0.25.1)** Tweet references without `x.com` URLs
-3. **Fix format issues.** Rewrite malformed citations to match
-   `conventions/quality.md`.
-4. **(v0.25.1) Resolve tweet references** via the X API integration.
-5. **Report results.** Count: pages scanned, citations found, issues
-   fixed, tweets resolved, remaining gaps.
-
-## Tweet resolution pipeline (v0.25.1 extension)
+use judgment to scan pages and repair their citations:
+  List pages and read each one, checking for inline [Source: ...] citations.
+  Identify facts without a citation, citations missing a date or source type, and citations with the wrong format.
+  Rewrite malformed citations to match the quality convention.
+  Resolve tweet references via the X API integration.
+  Report counts of pages scanned, citations found, issues fixed, and remaining gaps.
+
+## Tweet resolution pipeline (v0.25.1 extension) (( inert ))
 
 For each broken tweet reference, follow this chain. The actual API call
 goes through whatever X integration the host has configured (typical
 shape: a recipe under `recipes/x-api/` with handle / search-all
 endpoints).
 
-### Step 1: Identify broken references
+### Step 1: Identify broken references (( inert ))
 
 Scan the page for patterns that indicate tweet references without URLs:
 
@@ -74,7 +68,7 @@
 - Has `[Source: ... X/Twitter ...]` without an `x.com` URL
 - References engagement metrics (likes, impressions) without a link
 
-### Step 2: Extract searchable content
+### Step 2: Extract searchable content (( inert ))
 
 From each broken reference, extract:
 
@@ -82,7 +76,7 @@
 - The **quoted text** (if available)
 - The **approximate date** (often present in surrounding timeline entries)
 
-### Step 3: Search for the actual tweet
+### Step 3: Search for the actual tweet (( inert ))
 
 Use the host's X API integration. Query patterns:
 
@@ -97,7 +91,7 @@
 "<exact quote>" -is:retweet
 ```
 
-### Step 4: Verify and extract metadata
+### Step 4: Verify and extract metadata (( inert ))
 
 Once a candidate is found:
 
@@ -106,7 +100,7 @@
   impressions).
 - Construct the URL: `https://x.com/<handle>/status/<tweet_id>`.
 
-### Step 5: Patch the brain page
+### Step 5: Patch the brain page (( inert ))
 
 Replace the broken citation with a proper one:
 
@@ -123,11 +117,11 @@
 [Source: [X/<handle>, YYYY-MM-DD](https://x.com/<handle>/status/<tweet_id>)]
 ```
 
-## Batch mode
+## Batch mode (( inert ))
 
 When sweeping many pages:
 
-### Find candidate pages
+### Find candidate pages (( role: procedure ))
 
 ```bash
 # Pages mentioning tweets but with no x.com links
@@ -140,14 +134,14 @@
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
@@ -167,17 +161,18 @@
 Remaining gaps:       N (pages with uncitable facts)
 ```
 
-## Anti-Patterns
-
-- ❌ Inventing citations for facts that have no source. Flag them.
-- ❌ Removing facts that lack citations (flag them; don't delete).
-- ❌ Fixing citations without reading the full page context.
-- ❌ Batch-fixing without checking quality on a sample first
+## Anti-Patterns (( role: procedure ))
+
+!!! checklist (( ai-autonomy ))
+- [ ] ❌ Inventing citations for facts that have no source. Flag them.
+- [ ] ❌ Removing facts that lack citations (flag them; don't delete).
+- [ ] ❌ Fixing citations without reading the full page context.
+- [ ] ❌ Batch-fixing without checking quality on a sample first
   (see `conventions/test-before-bulk.md`).
-- ❌ Composing tweet URLs by guessing the tweet id. Always go through
+- [ ] ❌ Composing tweet URLs by guessing the tweet id. Always go through
   the X API; deterministic links only.
 
-## Integration
+## Integration (( inert ))
 
 This skill can be called:
 
@@ -186,23 +181,22 @@
 - **By other skills** — `enrich` or `media-ingest` can call citation-fixer
   before commit to validate output
 
-## Metrics
-
-If running as a recurring batch, track state in a small JSON file under
-`~/.gbrain/citation-fixer-state.json`:
-
-```json
-{
-  "last_run": "2026-04-15T...",
-  "pages_scanned": 0,
-  "citations_fixed": 0,
-  "tweet_links_resolved": 0,
-  "citations_unresolvable": 0,
-  "pages_remaining": 1424
-}
-```
-
-
+## Metrics (( role: procedure ))
+
+use judgment to follow the Metrics guidance:
+  If running as a recurring batch, track state in a small JSON file under
+  `~/.gbrain/citation-fixer-state.json`:
+  
+  ```json
+  {
+    "last_run": "2026-04-15T...",
+    "pages_scanned": 0,
+    "citations_fixed": 0,
+    "tweet_links_resolved": 0,
+    "citations_unresolvable": 0,
+    "pages_remaining": 1424
+  }
+  ```
 ## Output Format
 
 The skill's output shape is documented inline in the body sections above (see "Output", "Brain page format", or equivalent). The literal section header here exists for the conformance test (`test/skills-conformance.test.ts`).
```
