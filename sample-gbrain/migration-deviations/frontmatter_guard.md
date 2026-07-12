# Deviation: frontmatter_guard.meri

- Original: `frontmatter-guard/SKILL.md`
- Ported: `frontmatter_guard.meri`
- Tier: 2 (light edits)
- Similarity: 69%
- Lines: 233 -> 288 (+109 / -54)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- doc-section-marked

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L160 `Output Format`: template - Template/output shape is metadata unless explicit output assertions are authored.
- L202 `Prevention — Writing Valid Frontmatter`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L206 `YAML arrays (the historical #1 error source)`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L233 `Quoted scalars`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L259 `Anti-Patterns`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.

## Metrics
- generated_loc: 168 non-blank ported lines
- Sections inert total: 15/15 (100% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert markers (`(( inert ))`, target 0 — the migrator never emits these): 0
- Inert categories: reference-documentation=14, template=1
- Judgment: 1 blocks, 0 lines
- canonical_drift: synonym=11, structure=0, desugar=0, meaning=165

### Inert section details
- L6 `Contract`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L17 `Why This Exists`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L52 `Phase 1: Audit`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L78 `Phase 2: Validate one path`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L91 `Phase 3: Fix`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L109 `Phase 4: Pre-commit hook (optional)`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L122 `Trigger words`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L134 `Output rules`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L151 `Chains with`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L160 `Output Format`: template — Template/output shape is metadata unless explicit output assertions are authored.
- L202 `Prevention — Writing Valid Frontmatter`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L206 `YAML arrays (the historical #1 error source)`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L233 `Quoted scalars`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L246 `When to quote at all`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L259 `Anti-Patterns`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.

## Unified diff

```diff
--- original-skills/frontmatter-guard/SKILL.md
+++ skills/frontmatter_guard.meri
@@ -21,26 +21,38 @@
 
 > **Convention:** see `skills/conventions/quality.md` for citation rules; this skill is structural validation, not citation auditing.
 
-## Contract
+## Contract (( role: reference ))
 
 This skill guarantees:
 - Every brain page is scanned against the eight canonical frontmatter validation classes
 - Mechanical errors (nested quotes, missing closing `---`, null bytes, slug mismatch) are auto-repairable on demand with `.bak` backups
+
+### Contract — steps (( role: reference ))
+
 - Validation logic is shared with `gbrain doctor`'s `frontmatter_integrity` subcheck — single source of truth
 - Reports per source (gbrain is multi-source since v0.18.0); never silently audits the wrong root
 
-## Why This Exists
-
-Brain pages pile up over months. Agents write them with malformed frontmatter:
-- Missing closing `---` (entity detector bugs)
+## Why This Exists (( role: reference ))
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
 
 ## Validation classes
+
+
+### Validation classes — steps (( role: reference ))
 
 | Code | Meaning | Auto-fixable? |
 |------|---------|---------------|
@@ -55,23 +67,38 @@
 
 ## Phases
 
-### Phase 1: Audit
-
-Run a read-only scan across all registered sources (or one with `--source <id>`).
-
-```bash
-gbrain frontmatter audit --json
-```
+### Phase 1: Audit (( role: reference ))
 
 Reports:
 - Per-source counts grouped by error code
-- Sample of up to 20 affected pages per source
 - Total count
 - Scan timestamp
 
+
+### Phase 1: Audit — steps
+
+Run a read-only scan across all registered sources (or one with `--source <id>`).
+
+```bash
+gbrain frontmatter audit --json
+```
+
+
+### Phase 1: Audit — steps 2 (( role: reference ))
+
+- Sample of up to 20 affected pages per source
+
+### Phase 1: Audit — steps 3
+
+use judgment to follow the Phase 1: Audit — steps 3 guidance:
 Output is JSON; agents parse `errors_by_code` and `per_source` to decide next steps.
 
-### Phase 2: Validate one path
+### Phase 2: Validate one path (( role: reference ))
+
+Exit code 0 = clean; 1 = errors found. Use this in CI pipelines or pre-commit hooks.
+
+
+### Phase 2: Validate one path — steps
 
 Validate a single file or directory (does not require source registration):
 
@@ -79,54 +106,76 @@
 gbrain frontmatter validate <path> --json
 ```
 
-Exit code 0 = clean; 1 = errors found. Use this in CI pipelines or pre-commit hooks.
-
-### Phase 3: Fix
-
-When issues are found:
+### Phase 3: Fix (( role: reference ))
+
+`--fix` writes `<file>.bak` for every modified file before mutating. The backup is the safety contract — works whether the brain is a git repo or a plain directory.
+
+
+### Phase 3: Fix — steps
+
+> When issues are found:
 
 ```bash
 gbrain frontmatter validate <path> --fix
 ```
 
-`--fix` writes `<file>.bak` for every modified file before mutating. The backup is the safety contract — works whether the brain is a git repo or a plain directory.
+
+### Phase 3: Fix — steps 2
 
 `--dry-run` previews without writing. Use this before applying fixes in batch.
 
-### Phase 4: Pre-commit hook (optional)
-
-For brain repos that ARE git repos, install the pre-commit hook to block malformed pages from being committed in the first place:
+### Phase 4: Pre-commit hook (optional) (( role: reference ))
+
+The hook runs `gbrain frontmatter validate` against staged `.md`/`.mdx` files. Bypass with `git commit --no-verify`.
+
+
+### Phase 4: Pre-commit hook (optional) — steps
+
+> For brain repos that ARE git repos, install the pre-commit hook to block malformed pages from being committed in the first place:
 
 ```bash
 gbrain frontmatter install-hook [--source <id>]
 ```
 
-The hook runs `gbrain frontmatter validate` against staged `.md`/`.mdx` files. Bypass with `git commit --no-verify`.
-
-## Trigger words
-
-When the user says any of these, route here:
+## Trigger words (( role: reference ))
+
 - "validate frontmatter"
 - "check frontmatter"
 - "fix frontmatter"
 - "frontmatter audit"
 - "brain lint"
 
-## Output rules
+
+### Trigger words — steps (( role: reference ))
+
+When the user says any of these, route here:
+## Output rules (( role: reference ))
+
+- Surface counts to the user in plain language; do not dump raw JSON.
+- `SLUG_MISMATCH` fixes remove the frontmatter `slug:` field — gbrain derives slug from path. Mention this when the user's title is intentionally renamed.
+
+### Output rules — steps
 
 - Always run `gbrain frontmatter audit --json` first; never assume a brain is clean.
-- Surface counts to the user in plain language; do not dump raw JSON.
+
+### Output rules — steps 2
+
 - For `--fix` operations: state how many files will be modified BEFORE running, then confirm.
-- `SLUG_MISMATCH` fixes remove the frontmatter `slug:` field — gbrain derives slug from path. Mention this when the user's title is intentionally renamed.
+
+### Output rules — steps 3
+
 - Never auto-fix `MISSING_OPEN` or `EMPTY_FRONTMATTER` without explicit user input — these usually mean a human author started a page and didn't finish.
 
-## Chains with
+## Chains with (( role: reference ))
 
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
+## Output Format (( role: template ))
 
 Audit summary (terse, agent-friendly):
 
@@ -168,11 +217,11 @@
 
 `gbrain frontmatter validate <path> --json` returns a similar envelope keyed on per-file results instead of per-source.
 
-## Prevention — Writing Valid Frontmatter
+## Prevention — Writing Valid Frontmatter (( role: reference ))
 
 **This is the most important section.** Fixing broken frontmatter is good. Not writing broken frontmatter in the first place is better.
 
-### YAML arrays (the historical #1 error source)
+### YAML arrays (the historical #1 error source) (( role: reference ))
 
 ```yaml
 # Correct: single-quoted YAML flow (canonical form gbrain emits)
@@ -199,7 +248,7 @@
 
 **The classic LLM trap:** code like `tags: [${items.map(t => JSON.stringify(t)).join(', ')}]` produces `tags: ["yc", "w2025"]`. Use single quotes with an apostrophe fallback: `tags: [${items.map(t => t.includes("'") ? JSON.stringify(t) : "'" + t + "'").join(', ')}]`. Or use a YAML library that knows how to emit canonical YAML.
 
-### Quoted scalars
+### Quoted scalars (( role: reference ))
 
 ```yaml
 # Correct: single quotes for values with special chars
@@ -212,22 +261,28 @@
 title: "My "Quoted" Title"
 ```
 
-### When to quote at all
+### When to quote at all (( role: reference ))
 
 - **Unquoted** is fine for simple values: `type: person`, `batch: w2025`
-- **Quote** when the value contains `: " ' # [ ] { } | > & * ! ? ,` or starts with `@`
 - **Single quotes** are the default safe choice
-- **Double quotes** only when the value itself contains apostrophes
-
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
+
+### When to quote at all — steps
+
+- Quote when the value contains `: " ' # [ ] { } | > & * ! ? ,` or starts with `@`
+
+### When to quote at all — steps 2
+
+- Double quotes only when the value itself contains apostrophes
+
+## Anti-Patterns (( role: reference ))
+
+Don't auto-fix `MISSING_OPEN` or `EMPTY_FRONTMATTER` without user input. These usually mean a human author started a page and didn't finish — silently inserting `---` markers around an unfinished draft is wrong.
+
+SLUG_MISMATCH cases are surfaced for manual review specifically because gbrain derives the slug from path. A mismatch usually means the user renamed a file intentionally; auto-removing the slug field is the right outcome only when you've confirmed the rename was deliberate.
+
+Don't skip the `.bak` backups. The `.bak` is the safety contract for non-git brain repos. If `.bak` files accumulate after a fix run, that's a feature, not a bug — the user can review the diffs and delete the backups when satisfied.
+
+Don't run `audit` on a brain where sources aren't registered. The CLI returns "no registered sources to audit" gracefully, but the migration emits a `skipped: no_sources` phase result. Don't paper over this with a manual path-walk; the right fix is to register the source via `gbrain sources add`.
+
+Don't install the pre-commit hook on non-git brain dirs. The install-hook command skips them automatically with a one-line note. If you see "skipped — not a git repo" and want validation at write time anyway, use the `audit` command on a cron schedule.
+
```
