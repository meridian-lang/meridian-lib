# Deviation: citation_fixer.meri

- Original: `citation-fixer/SKILL.md`
- Ported: `citation_fixer.meri`
- Tier: 1 (near-verbatim)
- Similarity: 88%
- Lines: 209 -> 202 (+21 / -28)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- shell-block-routed

## Metrics
- Sections: 15/17 inert (88% inert ratio)
- Judgment: 1 blocks, 5 lines

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
 
@@ -42,28 +42,21 @@
 
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
 
@@ -74,7 +67,7 @@
 - Has `[Source: ... X/Twitter ...]` without an `x.com` URL
 - References engagement metrics (likes, impressions) without a link
 
-### Step 2: Extract searchable content
+### Step 2: Extract searchable content (( inert ))
 
 From each broken reference, extract:
 
@@ -82,7 +75,7 @@
 - The **quoted text** (if available)
 - The **approximate date** (often present in surrounding timeline entries)
 
-### Step 3: Search for the actual tweet
+### Step 3: Search for the actual tweet (( inert ))
 
 Use the host's X API integration. Query patterns:
 
@@ -97,7 +90,7 @@
 "<exact quote>" -is:retweet
 ```
 
-### Step 4: Verify and extract metadata
+### Step 4: Verify and extract metadata (( inert ))
 
 Once a candidate is found:
 
@@ -106,7 +99,7 @@
   impressions).
 - Construct the URL: `https://x.com/<handle>/status/<tweet_id>`.
 
-### Step 5: Patch the brain page
+### Step 5: Patch the brain page (( inert ))
 
 Replace the broken citation with a proper one:
 
@@ -123,11 +116,11 @@
 [Source: [X/<handle>, YYYY-MM-DD](https://x.com/<handle>/status/<tweet_id>)]
 ```
 
-## Batch mode
+## Batch mode (( inert ))
 
 When sweeping many pages:
 
-### Find candidate pages
+### Find candidate pages (( role: procedure ))
 
 ```bash
 # Pages mentioning tweets but with no x.com links
@@ -140,14 +133,14 @@
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
@@ -167,7 +160,7 @@
 Remaining gaps:       N (pages with uncitable facts)
 ```
 
-## Anti-Patterns
+## Anti-Patterns (( inert, role: prohibitions ))
 
 - ❌ Inventing citations for facts that have no source. Flag them.
 - ❌ Removing facts that lack citations (flag them; don't delete).
@@ -177,7 +170,7 @@
 - ❌ Composing tweet URLs by guessing the tweet id. Always go through
   the X API; deterministic links only.
 
-## Integration
+## Integration (( inert ))
 
 This skill can be called:
 
@@ -186,7 +179,7 @@
 - **By other skills** — `enrich` or `media-ingest` can call citation-fixer
   before commit to validate output
 
-## Metrics
+## Metrics (( inert ))
 
 If running as a recurring batch, track state in a small JSON file under
 `~/.gbrain/citation-fixer-state.json`:
```
