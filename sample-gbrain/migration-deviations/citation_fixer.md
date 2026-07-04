# Deviation: citation_fixer.meri

- Original: `citation-fixer/SKILL.md`
- Ported: `citation_fixer.meri`
- Tier: 1 (near-verbatim)
- Similarity: 85%
- Lines: 209 -> 227 (+41 / -23)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- shell-block-routed
- inert-section-added

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L56 `Step 1: Identify broken references`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L67 `Step 2: Extract searchable content`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L75 `Step 3: Search for the actual tweet`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L102 `Step 5: Patch the brain page`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L119 `Batch mode`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L136 `Priority order`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L143 `Rate limiting`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L151 `Output format`: template - Template/output shape is metadata unless explicit output assertions are authored.
- L174 `Integration`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L203 `Output Format`: template - Template/output shape is metadata unless explicit output assertions are authored.

## Metrics
- Sections inert total: 12/16 (75% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert categories: reference-documentation=10, template=2
- Judgment: 3 blocks, 0 lines

### Inert section details
- L56 `Step 1: Identify broken references`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L67 `Step 2: Extract searchable content`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L75 `Step 3: Search for the actual tweet`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L90 `Step 4: Verify and extract metadata`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L102 `Step 5: Patch the brain page`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L119 `Batch mode`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L136 `Priority order`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L143 `Rate limiting`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L151 `Output format`: template — Template/output shape is metadata unless explicit output assertions are authored.
- L174 `Integration`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L183 `Metrics`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L203 `Output Format`: template — Template/output shape is metadata unless explicit output assertions are authored.

## Unified diff

```diff
--- original-skills/citation-fixer/SKILL.md
+++ skills/citation_fixer.meri
@@ -28,7 +28,8 @@
 > **Output rule:** all links MUST be deterministic (built from API data,
 > not composed by LLM). See [_output-rules.md](../_output-rules.md).
 
-## Contract
+## Contract (( role: procedure ))
+use judgment to follow the Contract guidance:
 
 This skill guarantees:
 
@@ -41,29 +42,39 @@
 - Results reported with counts (scanned, fixed, remaining).
 
 ## Phases
-
-1. **Scan pages.** List pages and read each one, checking for inline
-   `[Source: ...]` citations.
+use judgment to follow the Phases guidance:
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
 
-## Tweet resolution pipeline (v0.25.1 extension)
+
+### Phases — steps
+
+1. List pages and read each one, checking for inline
+   `[Source: ...]` citations.
+
+### Phases — steps 2
+
+   - (v0.25.1) Tweet references without `x.com` URLs
+3. Rewrite malformed citations to match
+   `conventions/quality.md`.
+## Tweet resolution pipeline (v0.25.1 extension) (( inert ))
+
+
+### Tweet resolution pipeline (v0.25.1 extension) — steps
 
 For each broken tweet reference, follow this chain. The actual API call
 goes through whatever X integration the host has configured (typical
 shape: a recipe under `recipes/x-api/` with handle / search-all
 endpoints).
 
-### Step 1: Identify broken references
+### Step 1: Identify broken references (( inert ))
 
 Scan the page for patterns that indicate tweet references without URLs:
 
@@ -74,7 +85,7 @@
 - Has `[Source: ... X/Twitter ...]` without an `x.com` URL
 - References engagement metrics (likes, impressions) without a link
 
-### Step 2: Extract searchable content
+### Step 2: Extract searchable content (( inert ))
 
 From each broken reference, extract:
 
@@ -82,7 +93,7 @@
 - The **quoted text** (if available)
 - The **approximate date** (often present in surrounding timeline entries)
 
-### Step 3: Search for the actual tweet
+### Step 3: Search for the actual tweet (( inert ))
 
 Use the host's X API integration. Query patterns:
 
@@ -97,16 +108,19 @@
 "<exact quote>" -is:retweet
 ```
 
-### Step 4: Verify and extract metadata
+### Step 4: Verify and extract metadata (( inert ))
 
 Once a candidate is found:
 
 - Confirm the text matches the quoted fragment.
 - Pull the tweet id, author handle, engagement metrics (likes / RTs /
   impressions).
+
+#### Step 4: Verify and extract metadata — steps
+
 - Construct the URL: `https://x.com/<handle>/status/<tweet_id>`.
 
-### Step 5: Patch the brain page
+### Step 5: Patch the brain page (( inert ))
 
 Replace the broken citation with a proper one:
 
@@ -123,7 +137,7 @@
 [Source: [X/<handle>, YYYY-MM-DD](https://x.com/<handle>/status/<tweet_id>)]
 ```
 
-## Batch mode
+## Batch mode (( inert ))
 
 When sweeping many pages:
 
@@ -140,14 +154,14 @@
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
@@ -167,7 +181,8 @@
 Remaining gaps:       N (pages with uncitable facts)
 ```
 
-## Anti-Patterns
+## Anti-Patterns (( role: procedure ))
+use judgment to follow the Anti-Patterns guidance:
 
 - ❌ Inventing citations for facts that have no source. Flag them.
 - ❌ Removing facts that lack citations (flag them; don't delete).
@@ -177,7 +192,7 @@
 - ❌ Composing tweet URLs by guessing the tweet id. Always go through
   the X API; deterministic links only.
 
-## Integration
+## Integration (( inert ))
 
 This skill can be called:
 
@@ -186,10 +201,7 @@
 - **By other skills** — `enrich` or `media-ingest` can call citation-fixer
   before commit to validate output
 
-## Metrics
-
-If running as a recurring batch, track state in a small JSON file under
-`~/.gbrain/citation-fixer-state.json`:
+## Metrics (( inert ))
 
 ```json
 {
@@ -203,7 +215,13 @@
 ```
 
 
-## Output Format
+
+### Metrics — steps
+
+If running as a recurring batch, track state in a small JSON file under
+`~/.gbrain/citation-fixer-state.json`:
+
+## Output Format (( inert, role: template ))
 
 The skill's output shape is documented inline in the body sections above (see "Output", "Brain page format", or equivalent). The literal section header here exists for the conformance test (`test/skills-conformance.test.ts`).
 
```
