# Deviation: frontmatter_guard.meri

- Original: `frontmatter-guard/SKILL.md`
- Ported: `frontmatter_guard.meri`
- Tier: 2 (light edits)
- Similarity: 74%
- Lines: 233 -> 284 (+92 / -41)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- shell-block-routed
- inert-section-added

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L122 `Trigger words`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L155 `Output Format`: template - Template/output shape is metadata unless explicit output assertions are authored.
- L197 `Prevention — Writing Valid Frontmatter`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L201 `YAML arrays (the historical #1 error source)`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L228 `Quoted scalars`: reference-documentation - Reference documentation, rationale, examples, or changelog.

## Metrics
- Sections inert total: 8/16 (50% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert categories: reference-documentation=7, template=1
- Judgment: 8 blocks, 0 lines

### Inert section details
- L15 `Why This Exists`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L122 `Trigger words`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L146 `Chains with`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L155 `Output Format`: template — Template/output shape is metadata unless explicit output assertions are authored.
- L197 `Prevention — Writing Valid Frontmatter`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L201 `YAML arrays (the historical #1 error source)`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L228 `Quoted scalars`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L241 `When to quote at all`: reference-documentation — Reference documentation, rationale, examples, or changelog.

## Unified diff

```diff
--- original-skills/frontmatter-guard/SKILL.md
+++ skills/frontmatter_guard.meri
@@ -21,7 +21,8 @@
 
 > **Convention:** see `skills/conventions/quality.md` for citation rules; this skill is structural validation, not citation auditing.
 
-## Contract
+## Contract (( role: procedure ))
+use judgment to follow the Contract guidance:
 
 This skill guarantees:
 - Every brain page is scanned against the eight canonical frontmatter validation classes
@@ -29,19 +30,29 @@
 - Validation logic is shared with `gbrain doctor`'s `frontmatter_integrity` subcheck — single source of truth
 - Reports per source (gbrain is multi-source since v0.18.0); never silently audits the wrong root
 
-## Why This Exists
-
-Brain pages pile up over months. Agents write them with malformed frontmatter:
-- Missing closing `---` (entity detector bugs)
+## Why This Exists (( inert ))
+
 - Unstructured YAML in meeting pages (ingestion bugs)
 - Slug mismatches (path renames not propagated)
 - Null bytes (binary corruption from copy-paste accidents)
+
+### Why This Exists — steps
+
+> Brain pages pile up over months. Agents write them with malformed frontmatter:
+- Missing closing `---` (entity detector bugs)
+
+### Why This Exists — steps 2
+
 - Nested double quotes in titles (`title: "Phil "Nick" Last"`)
 
 Without a guard, these accumulate silently until `gbrain sync` chokes or search returns garbage. The guard makes the failure visible at audit time and trivially fixable.
 
-## Validation classes
-
+## Validation classes (( inert ))
+
+
+### Validation classes — steps
+
+!!! table (( ai-discretion ))
 | Code | Meaning | Auto-fixable? |
 |------|---------|---------------|
 | `MISSING_OPEN` | File doesn't start with `---` | No (needs human) |
@@ -54,56 +65,79 @@
 | `EMPTY_FRONTMATTER` | Open + close present but nothing between | No (needs human) |
 
 ## Phases
+use judgment to follow the Phases guidance:
 
 ### Phase 1: Audit
-
-Run a read-only scan across all registered sources (or one with `--source <id>`).
-
-```bash
-gbrain frontmatter audit --json
-```
+use judgment to follow the Phase 1: Audit guidance:
 
 Reports:
 - Per-source counts grouped by error code
-- Sample of up to 20 affected pages per source
 - Total count
 - Scan timestamp
 
 Output is JSON; agents parse `errors_by_code` and `per_source` to decide next steps.
 
+
+#### Phase 1: Audit — steps
+
+Run a read-only scan across all registered sources (or one with `--source <id>`).
+
+```bash
+gbrain frontmatter audit --json
+```
+
+
+#### Phase 1: Audit — steps 2
+
+- Sample of up to 20 affected pages per source
 ### Phase 2: Validate one path
-
-Validate a single file or directory (does not require source registration):
+use judgment to follow the Phase 2: Validate one path guidance:
+
+Exit code 0 = clean; 1 = errors found. Use this in CI pipelines or pre-commit hooks.
+
+
+#### Phase 2: Validate one path — steps
+
+> Validate a single file or directory (does not require source registration):
 
 ```bash
 gbrain frontmatter validate <path> --json
 ```
 
-Exit code 0 = clean; 1 = errors found. Use this in CI pipelines or pre-commit hooks.
-
 ### Phase 3: Fix
-
-When issues are found:
+use judgment to follow the Phase 3: Fix guidance:
+
+`--fix` writes `<file>.bak` for every modified file before mutating. The backup is the safety contract — works whether the brain is a git repo or a plain directory.
+
+
+#### Phase 3: Fix — steps
+
+> When issues are found:
 
 ```bash
 gbrain frontmatter validate <path> --fix
 ```
 
-`--fix` writes `<file>.bak` for every modified file before mutating. The backup is the safety contract — works whether the brain is a git repo or a plain directory.
+
+#### Phase 3: Fix — steps 2
 
 `--dry-run` previews without writing. Use this before applying fixes in batch.
 
 ### Phase 4: Pre-commit hook (optional)
-
-For brain repos that ARE git repos, install the pre-commit hook to block malformed pages from being committed in the first place:
+use judgment to follow the Phase 4: Pre-commit hook (optional) guidance:
+
+The hook runs `gbrain frontmatter validate` against staged `.md`/`.mdx` files. Bypass with `git commit --no-verify`.
+
+
+#### Phase 4: Pre-commit hook (optional) — steps
+
+> For brain repos that ARE git repos, install the pre-commit hook to block malformed pages from being committed in the first place:
 
 ```bash
 gbrain frontmatter install-hook [--source <id>]
 ```
 
-The hook runs `gbrain frontmatter validate` against staged `.md`/`.mdx` files. Bypass with `git commit --no-verify`.
-
-## Trigger words
+## Trigger words (( inert ))
 
 When the user says any of these, route here:
 - "validate frontmatter"
@@ -113,20 +147,30 @@
 - "brain lint"
 
 ## Output rules
-
-- Always run `gbrain frontmatter audit --json` first; never assume a brain is clean.
+use judgment to follow the Output rules guidance:
+
 - Surface counts to the user in plain language; do not dump raw JSON.
-- For `--fix` operations: state how many files will be modified BEFORE running, then confirm.
 - `SLUG_MISMATCH` fixes remove the frontmatter `slug:` field — gbrain derives slug from path. Mention this when the user's title is intentionally renamed.
 - Never auto-fix `MISSING_OPEN` or `EMPTY_FRONTMATTER` without explicit user input — these usually mean a human author started a page and didn't finish.
 
-## Chains with
+
+### Output rules — steps
+
+- Always run `gbrain frontmatter audit --json` first; never assume a brain is clean.
+
+### Output rules — steps 2
+
+- For `--fix` operations: state how many files will be modified BEFORE running, then confirm.
+## Chains with (( inert ))
 
 - `gbrain doctor` — the `frontmatter_integrity` subcheck reports the same counts as `audit`.
+- `skills/lint/SKILL.md` (via `gbrain lint`) — overlapping rules for skill-file lint; the `frontmatter-*` rule names in lint output come from this skill's validation surface.
+
+
+### Chains with — steps
+
 - `skills/maintain/SKILL.md` — broader brain health audit; chain after this skill if other classes of issue are suspected.
-- `skills/lint/SKILL.md` (via `gbrain lint`) — overlapping rules for skill-file lint; the `frontmatter-*` rule names in lint output come from this skill's validation surface.
-
-## Output Format
+## Output Format (( inert, role: template ))
 
 Audit summary (terse, agent-friendly):
 
@@ -168,11 +212,11 @@
 
 `gbrain frontmatter validate <path> --json` returns a similar envelope keyed on per-file results instead of per-source.
 
-## Prevention — Writing Valid Frontmatter
+## Prevention — Writing Valid Frontmatter (( inert ))
 
 **This is the most important section.** Fixing broken frontmatter is good. Not writing broken frontmatter in the first place is better.
 
-### YAML arrays (the historical #1 error source)
+### YAML arrays (the historical #1 error source) (( inert ))
 
 ```yaml
 # Correct: single-quoted YAML flow (canonical form gbrain emits)
@@ -199,7 +243,7 @@
 
 **The classic LLM trap:** code like `tags: [${items.map(t => JSON.stringify(t)).join(', ')}]` produces `tags: ["yc", "w2025"]`. Use single quotes with an apostrophe fallback: `tags: [${items.map(t => t.includes("'") ? JSON.stringify(t) : "'" + t + "'").join(', ')}]`. Or use a YAML library that knows how to emit canonical YAML.
 
-### Quoted scalars
+### Quoted scalars (( inert ))
 
 ```yaml
 # Correct: single quotes for values with special chars
@@ -212,14 +256,21 @@
 title: "My "Quoted" Title"
 ```
 
-### When to quote at all
+### When to quote at all (( inert ))
 
 - **Unquoted** is fine for simple values: `type: person`, `batch: w2025`
-- **Quote** when the value contains `: " ' # [ ] { } | > & * ! ? ,` or starts with `@`
 - **Single quotes** are the default safe choice
-- **Double quotes** only when the value itself contains apostrophes
-
-## Anti-Patterns
+
+#### When to quote at all — steps
+
+- Quote when the value contains `: " ' # [ ] { } | > & * ! ? ,` or starts with `@`
+
+#### When to quote at all — steps 2
+
+- Double quotes only when the value itself contains apostrophes
+
+## Anti-Patterns (( role: procedure ))
+use judgment to follow the Anti-Patterns guidance:
 
 **Don't auto-fix `MISSING_OPEN` or `EMPTY_FRONTMATTER` without user input.** These usually mean a human author started a page and didn't finish — silently inserting `---` markers around an unfinished draft is wrong.
 
```
