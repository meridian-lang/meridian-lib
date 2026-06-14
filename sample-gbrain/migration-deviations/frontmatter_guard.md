# Deviation: frontmatter_guard.meri

- Original: `frontmatter-guard/SKILL.md`
- Ported: `frontmatter_guard.meri`
- Tier: 2 (light edits)
- Similarity: 62%
- Lines: 233 -> 234 (+90 / -89)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- shell-block-routed

## Metrics
- Sections: 9/17 inert (53% inert ratio)
- Operational inert: 0
- Unclassified inert: 0
- Inert categories: reference-documentation=8, template=1
- Judgment: 5 blocks, 36 lines

### Inert section details
- L15 `Why This Exists`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L89 `Trigger words`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L98 `Output rules`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L106 `Chains with`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L112 `Output Format`: template — Template/output shape is metadata unless explicit output assertions are authored.
- L154 `Prevention — Writing Valid Frontmatter`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L158 `YAML arrays (the historical #1 error source)`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L185 `Quoted scalars`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L198 `When to quote at all`: reference-documentation — Reference documentation, rationale, examples, or changelog.

## Unified diff

```diff
--- original-skills/frontmatter-guard/SKILL.md
+++ skills/frontmatter_guard.meri
@@ -21,15 +21,16 @@
 
 > **Convention:** see `skills/conventions/quality.md` for citation rules; this skill is structural validation, not citation auditing.
 
-## Contract
-
-This skill guarantees:
-- Every brain page is scanned against the eight canonical frontmatter validation classes
-- Mechanical errors (nested quotes, missing closing `---`, null bytes, slug mismatch) are auto-repairable on demand with `.bak` backups
-- Validation logic is shared with `gbrain doctor`'s `frontmatter_integrity` subcheck — single source of truth
-- Reports per source (gbrain is multi-source since v0.18.0); never silently audits the wrong root
-
-## Why This Exists
+## Contract (( role: procedure ))
+
+> This skill guarantees:
+!!! checklist (( ai-autonomy ))
+- [ ] Every brain page is scanned against the eight canonical frontmatter validation classes
+- [ ] Mechanical errors (nested quotes, missing closing `---`, null bytes, slug mismatch) are auto-repairable on demand with `.bak` backups
+- [ ] Validation logic is shared with `gbrain doctor`'s `frontmatter_integrity` subcheck — single source of truth
+- [ ] Reports per source (gbrain is multi-source since v0.18.0); never silently audits the wrong root
+
+## Why This Exists (( inert ))
 
 Brain pages pile up over months. Agents write them with malformed frontmatter:
 - Missing closing `---` (entity detector bugs)
@@ -40,70 +41,70 @@
 
 Without a guard, these accumulate silently until `gbrain sync` chokes or search returns garbage. The guard makes the failure visible at audit time and trivially fixable.
 
-## Validation classes
-
-| Code | Meaning | Auto-fixable? |
-|------|---------|---------------|
-| `MISSING_OPEN` | File doesn't start with `---` | No (needs human) |
-| `MISSING_CLOSE` | No closing `---` before first heading | Yes |
-| `YAML_PARSE` | YAML failed to parse | Sometimes (depends on cause) |
-| `SLUG_MISMATCH` | Frontmatter `slug:` differs from path-derived slug | Yes (removes the field) |
-| `NULL_BYTES` | Binary corruption (`\x00`) | Yes |
-| `NESTED_QUOTES` | `title: "outer "inner" outer"` shape | Yes |
-| `NON_STRING_FIELD` | `title`/`type`/`slug` is an unquoted non-string scalar (e.g. `title: 123`, `slug: 2024-06-01`) | No (quote the value) |
-| `EMPTY_FRONTMATTER` | Open + close present but nothing between | No (needs human) |
-
+## Validation classes (( role: procedure ))
+
+use judgment to follow the Validation classes guidance:
+  | Code | Meaning | Auto-fixable? |
+  |------|---------|---------------|
+  | `MISSING_OPEN` | File doesn't start with `---` | No (needs human) |
+  | `MISSING_CLOSE` | No closing `---` before first heading | Yes |
+  | `YAML_PARSE` | YAML failed to parse | Sometimes (depends on cause) |
+  | `SLUG_MISMATCH` | Frontmatter `slug:` differs from path-derived slug | Yes (removes the field) |
+  | `NULL_BYTES` | Binary corruption (`\x00`) | Yes |
+  | `NESTED_QUOTES` | `title: "outer "inner" outer"` shape | Yes |
+  | `NON_STRING_FIELD` | `title`/`type`/`slug` is an unquoted non-string scalar (e.g. `title: 123`, `slug: 2024-06-01`) | No (quote the value) |
+  | `EMPTY_FRONTMATTER` | Open + close present but nothing between | No (needs human) |
 ## Phases
 
-### Phase 1: Audit
-
-Run a read-only scan across all registered sources (or one with `--source <id>`).
-
-```bash
-gbrain frontmatter audit --json
-```
-
-Reports:
-- Per-source counts grouped by error code
-- Sample of up to 20 affected pages per source
-- Total count
-- Scan timestamp
-
-Output is JSON; agents parse `errors_by_code` and `per_source` to decide next steps.
-
-### Phase 2: Validate one path
-
-Validate a single file or directory (does not require source registration):
-
-```bash
-gbrain frontmatter validate <path> --json
-```
-
-Exit code 0 = clean; 1 = errors found. Use this in CI pipelines or pre-commit hooks.
-
-### Phase 3: Fix
-
-When issues are found:
-
-```bash
-gbrain frontmatter validate <path> --fix
-```
-
-`--fix` writes `<file>.bak` for every modified file before mutating. The backup is the safety contract — works whether the brain is a git repo or a plain directory.
-
-`--dry-run` previews without writing. Use this before applying fixes in batch.
-
-### Phase 4: Pre-commit hook (optional)
-
-For brain repos that ARE git repos, install the pre-commit hook to block malformed pages from being committed in the first place:
-
-```bash
-gbrain frontmatter install-hook [--source <id>]
-```
-
-The hook runs `gbrain frontmatter validate` against staged `.md`/`.mdx` files. Bypass with `git commit --no-verify`.
-
-## Trigger words
+### Phase 1: Audit (( role: procedure ))
+
+use judgment to follow the Phase 1: Audit guidance:
+  Run a read-only scan across all registered sources (or one with `--source <id>`).
+  
+  ```bash
+  gbrain frontmatter audit --json
+  ```
+  
+  Reports:
+  item: Per-source counts grouped by error code
+  item: Sample of up to 20 affected pages per source
+  item: Total count
+  item: Scan timestamp
+  
+  Output is JSON; agents parse `errors_by_code` and `per_source` to decide next steps.
+### Phase 2: Validate one path (( role: procedure ))
+  
+use judgment to follow the Phase 2: Validate one path guidance:
+  Validate a single file or directory (does not require source registration):
+  
+  ```bash
+  gbrain frontmatter validate <path> --json
+  ```
+  
+  Exit code 0 = clean; 1 = errors found. Use this in CI pipelines or pre-commit hooks.
+### Phase 3: Fix (( role: procedure ))
+  
+use judgment to follow the Phase 3: Fix guidance:
+  When issues are found:
+  
+  ```bash
+  gbrain frontmatter validate <path> --fix
+  ```
+  
+  `--fix` writes `<file>.bak` for every modified file before mutating. The backup is the safety contract — works whether the brain is a git repo or a plain directory.
+  
+  `--dry-run` previews without writing. Use this before applying fixes in batch.
+### Phase 4: Pre-commit hook (optional) (( role: procedure ))
+  
+use judgment to follow the Phase 4: Pre-commit hook (optional) guidance:
+  For brain repos that ARE git repos, install the pre-commit hook to block malformed pages from being committed in the first place:
+  
+  ```bash
+  gbrain frontmatter install-hook [--source <id>]
+  ```
+  
+  The hook runs `gbrain frontmatter validate` against staged `.md`/`.mdx` files. Bypass with `git commit --no-verify`.
+## Trigger words (( inert ))
 
 When the user says any of these, route here:
 - "validate frontmatter"
@@ -112,7 +113,7 @@
 - "frontmatter audit"
 - "brain lint"
 
-## Output rules
+## Output rules (( inert ))
 
 - Always run `gbrain frontmatter audit --json` first; never assume a brain is clean.
 - Surface counts to the user in plain language; do not dump raw JSON.
@@ -120,7 +121,7 @@
 - `SLUG_MISMATCH` fixes remove the frontmatter `slug:` field — gbrain derives slug from path. Mention this when the user's title is intentionally renamed.
 - Never auto-fix `MISSING_OPEN` or `EMPTY_FRONTMATTER` without explicit user input — these usually mean a human author started a page and didn't finish.
 
-## Chains with
+## Chains with (( inert ))
 
 - `gbrain doctor` — the `frontmatter_integrity` subcheck reports the same counts as `audit`.
 - `skills/maintain/SKILL.md` — broader brain health audit; chain after this skill if other classes of issue are suspected.
@@ -168,11 +169,11 @@
 
 `gbrain frontmatter validate <path> --json` returns a similar envelope keyed on per-file results instead of per-source.
 
-## Prevention — Writing Valid Frontmatter
+## Prevention — Writing Valid Frontmatter (( inert ))
 
 **This is the most important section.** Fixing broken frontmatter is good. Not writing broken frontmatter in the first place is better.
 
-### YAML arrays (the historical #1 error source)
+### YAML arrays (the historical #1 error source) (( inert ))
 
 ```yaml
 # Correct: single-quoted YAML flow (canonical form gbrain emits)
@@ -199,7 +200,7 @@
 
 **The classic LLM trap:** code like `tags: [${items.map(t => JSON.stringify(t)).join(', ')}]` produces `tags: ["yc", "w2025"]`. Use single quotes with an apostrophe fallback: `tags: [${items.map(t => t.includes("'") ? JSON.stringify(t) : "'" + t + "'").join(', ')}]`. Or use a YAML library that knows how to emit canonical YAML.
 
-### Quoted scalars
+### Quoted scalars (( inert ))
 
 ```yaml
 # Correct: single quotes for values with special chars
@@ -212,22 +213,22 @@
 title: "My "Quoted" Title"
 ```
 
-### When to quote at all
+### When to quote at all (( inert ))
 
 - **Unquoted** is fine for simple values: `type: person`, `batch: w2025`
 - **Quote** when the value contains `: " ' # [ ] { } | > & * ! ? ,` or starts with `@`
 - **Single quotes** are the default safe choice
 - **Double quotes** only when the value itself contains apostrophes
 
-## Anti-Patterns
-
-**Don't auto-fix `MISSING_OPEN` or `EMPTY_FRONTMATTER` without user input.** These usually mean a human author started a page and didn't finish — silently inserting `---` markers around an unfinished draft is wrong.
-
-**Don't use `--fix` to "make doctor green" without reading the audit first.** SLUG_MISMATCH cases are surfaced for manual review specifically because gbrain derives the slug from path. A mismatch usually means the user renamed a file intentionally; auto-removing the slug field is the right outcome only when you've confirmed the rename was deliberate.
-
-**Don't skip the `.bak` backups.** The `.bak` is the safety contract for non-git brain repos. If `.bak` files accumulate after a fix run, that's a feature, not a bug — the user can review the diffs and delete the backups when satisfied.
-
-**Don't run `audit` on a brain where sources aren't registered.** The CLI returns "no registered sources to audit" gracefully, but the migration emits a `skipped: no_sources` phase result. Don't paper over this with a manual path-walk; the right fix is to register the source via `gbrain sources add`.
-
-**Don't install the pre-commit hook on non-git brain dirs.** The install-hook command skips them automatically with a one-line note. If you see "skipped — not a git repo" and want validation at write time anyway, use the `audit` command on a cron schedule.
-
+## Anti-Patterns (( role: procedure ))
+
+> **Don't auto-fix `MISSING_OPEN` or `EMPTY_FRONTMATTER` without user input.** These usually mean a human author started a page and didn't finish — silently inserting `---` markers around an unfinished draft is wrong.
+
+> **Don't use `--fix` to "make doctor green" without reading the audit first.** SLUG_MISMATCH cases are surfaced for manual review specifically because gbrain derives the slug from path. A mismatch usually means the user renamed a file intentionally; auto-removing the slug field is the right outcome only when you've confirmed the rename was deliberate.
+
+> **Don't skip the `.bak` backups.** The `.bak` is the safety contract for non-git brain repos. If `.bak` files accumulate after a fix run, that's a feature, not a bug — the user can review the diffs and delete the backups when satisfied.
+
+> **Don't run `audit` on a brain where sources aren't registered.** The CLI returns "no registered sources to audit" gracefully, but the migration emits a `skipped: no_sources` phase result. Don't paper over this with a manual path-walk; the right fix is to register the source via `gbrain sources add`.
+
+> **Don't install the pre-commit hook on non-git brain dirs.** The install-hook command skips them automatically with a one-line note. If you see "skipped — not a git repo" and want validation at write time anyway, use the `audit` command on a cron schedule.
+
```
