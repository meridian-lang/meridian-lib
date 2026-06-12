# Deviation: frontmatter_guard.meri

- Original: `frontmatter-guard/SKILL.md`
- Ported: `frontmatter_guard.meri`
- Tier: 1 (near-verbatim)
- Similarity: 94%
- Lines: 233 -> 233 (+15 / -15)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added

## Metrics
- Sections: 16/17 inert (94% inert ratio)
- Judgment: 0 blocks, 0 lines

## Unified diff

```diff
--- original-skills/frontmatter-guard/SKILL.md
+++ skills/frontmatter_guard.meri
@@ -21,7 +21,7 @@
 
 > **Convention:** see `skills/conventions/quality.md` for citation rules; this skill is structural validation, not citation auditing.
 
-## Contract
+## Contract (( inert, role: invariants ))
 
 This skill guarantees:
 - Every brain page is scanned against the eight canonical frontmatter validation classes
@@ -29,7 +29,7 @@
 - Validation logic is shared with `gbrain doctor`'s `frontmatter_integrity` subcheck — single source of truth
 - Reports per source (gbrain is multi-source since v0.18.0); never silently audits the wrong root
 
-## Why This Exists
+## Why This Exists (( inert ))
 
 Brain pages pile up over months. Agents write them with malformed frontmatter:
 - Missing closing `---` (entity detector bugs)
@@ -40,7 +40,7 @@
 
 Without a guard, these accumulate silently until `gbrain sync` chokes or search returns garbage. The guard makes the failure visible at audit time and trivially fixable.
 
-## Validation classes
+## Validation classes (( inert ))
 
 | Code | Meaning | Auto-fixable? |
 |------|---------|---------------|
@@ -55,7 +55,7 @@
 
 ## Phases
 
-### Phase 1: Audit
+### Phase 1: Audit (( inert, role: procedure ))
 
 Run a read-only scan across all registered sources (or one with `--source <id>`).
 
@@ -71,7 +71,7 @@
 
 Output is JSON; agents parse `errors_by_code` and `per_source` to decide next steps.
 
-### Phase 2: Validate one path
+### Phase 2: Validate one path (( inert, role: procedure ))
 
 Validate a single file or directory (does not require source registration):
 
@@ -81,7 +81,7 @@
 
 Exit code 0 = clean; 1 = errors found. Use this in CI pipelines or pre-commit hooks.
 
-### Phase 3: Fix
+### Phase 3: Fix (( inert, role: procedure ))
 
 When issues are found:
 
@@ -93,7 +93,7 @@
 
 `--dry-run` previews without writing. Use this before applying fixes in batch.
 
-### Phase 4: Pre-commit hook (optional)
+### Phase 4: Pre-commit hook (optional) (( inert, role: procedure ))
 
 For brain repos that ARE git repos, install the pre-commit hook to block malformed pages from being committed in the first place:
 
@@ -103,7 +103,7 @@
 
 The hook runs `gbrain frontmatter validate` against staged `.md`/`.mdx` files. Bypass with `git commit --no-verify`.
 
-## Trigger words
+## Trigger words (( inert ))
 
 When the user says any of these, route here:
 - "validate frontmatter"
@@ -112,7 +112,7 @@
 - "frontmatter audit"
 - "brain lint"
 
-## Output rules
+## Output rules (( inert ))
 
 - Always run `gbrain frontmatter audit --json` first; never assume a brain is clean.
 - Surface counts to the user in plain language; do not dump raw JSON.
@@ -120,7 +120,7 @@
 - `SLUG_MISMATCH` fixes remove the frontmatter `slug:` field — gbrain derives slug from path. Mention this when the user's title is intentionally renamed.
 - Never auto-fix `MISSING_OPEN` or `EMPTY_FRONTMATTER` without explicit user input — these usually mean a human author started a page and didn't finish.
 
-## Chains with
+## Chains with (( inert ))
 
 - `gbrain doctor` — the `frontmatter_integrity` subcheck reports the same counts as `audit`.
 - `skills/maintain/SKILL.md` — broader brain health audit; chain after this skill if other classes of issue are suspected.
@@ -168,11 +168,11 @@
 
 `gbrain frontmatter validate <path> --json` returns a similar envelope keyed on per-file results instead of per-source.
 
-## Prevention — Writing Valid Frontmatter
+## Prevention — Writing Valid Frontmatter (( inert ))
 
 **This is the most important section.** Fixing broken frontmatter is good. Not writing broken frontmatter in the first place is better.
 
-### YAML arrays (the historical #1 error source)
+### YAML arrays (the historical #1 error source) (( inert ))
 
 ```yaml
 # Correct: single-quoted YAML flow (canonical form gbrain emits)
@@ -199,7 +199,7 @@
 
 **The classic LLM trap:** code like `tags: [${items.map(t => JSON.stringify(t)).join(', ')}]` produces `tags: ["yc", "w2025"]`. Use single quotes with an apostrophe fallback: `tags: [${items.map(t => t.includes("'") ? JSON.stringify(t) : "'" + t + "'").join(', ')}]`. Or use a YAML library that knows how to emit canonical YAML.
 
-### Quoted scalars
+### Quoted scalars (( inert ))
 
 ```yaml
 # Correct: single quotes for values with special chars
@@ -212,14 +212,14 @@
 title: "My "Quoted" Title"
 ```
 
-### When to quote at all
+### When to quote at all (( inert ))
 
 - **Unquoted** is fine for simple values: `type: person`, `batch: w2025`
 - **Quote** when the value contains `: " ' # [ ] { } | > & * ! ? ,` or starts with `@`
 - **Single quotes** are the default safe choice
 - **Double quotes** only when the value itself contains apostrophes
 
-## Anti-Patterns
+## Anti-Patterns (( inert, role: prohibitions ))
 
 **Don't auto-fix `MISSING_OPEN` or `EMPTY_FRONTMATTER` without user input.** These usually mean a human author started a page and didn't finish — silently inserting `---` markers around an unfinished draft is wrong.
 
```
