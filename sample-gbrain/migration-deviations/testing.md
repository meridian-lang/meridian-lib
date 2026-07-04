# Deviation: testing.meri

- Original: `testing/SKILL.md`
- Ported: `testing.meri`
- Tier: 2 (light edits)
- Similarity: 73%
- Lines: 257 -> 286 (+89 / -60)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- shell-block-routed
- inert-section-added

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L8 `Two modes`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L64 `Output format`: template - Template/output shape is metadata unless explicit output assertions are authored.
- L104 `Daily run protocol`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L172 `6. Report format`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L260 `Output Format`: template - Template/output shape is metadata unless explicit output assertions are authored.

## Metrics
- Sections inert total: 9/17 (53% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert categories: reference-documentation=7, template=2
- Judgment: 6 blocks, 0 lines

### Inert section details
- L8 `Two modes`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L53 `Automation`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L64 `Output format`: template — Template/output shape is metadata unless explicit output assertions are authored.
- L104 `Daily run protocol`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L108 `1. Run unit tests`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L119 `2. Run evals (if the project has an evals config)`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L139 `4. Git diff analysis (CRITICAL — regression intelligence)`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L172 `6. Report format`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L260 `Output Format`: template — Template/output shape is metadata unless explicit output assertions are authored.

## Unified diff

```diff
--- original-skills/testing/SKILL.md
+++ skills/testing.meri
@@ -28,7 +28,7 @@
 > the test-before-bulk pattern; this skill enforces it across the project's
 > own test suite.
 
-## Two modes
+## Two modes (( inert ))
 
 This skill has two related but distinct modes:
 
@@ -44,38 +44,45 @@
 
 Pick the mode by trigger.
 
-## Mode 1: Skill conformance validation
-
-### Contract
-
-This mode guarantees:
+## Mode 1: Skill conformance validation (( inert ))
+
+### Contract (( role: procedure ))
+use judgment to follow the Contract guidance:
+
+- `skills/manifest.json` lists every skill directory
+- `skills/RESOLVER.md` references every skill in the manifest
+- `openclaw.plugin.json` `skills[]` round-trips with both
+- No MECE violations (duplicate triggers across skills)
+
+
+#### Contract — steps
+
+> This mode guarantees:
 
 - Every skill directory has a `SKILL.md` file
 - Every `SKILL.md` has valid YAML frontmatter (`name`, `description`)
 - Every `SKILL.md` has required sections per
   `test/skills-conformance.test.ts`
-- `skills/manifest.json` lists every skill directory
-- `skills/RESOLVER.md` references every skill in the manifest
-- `openclaw.plugin.json` `skills[]` round-trips with both
-- No MECE violations (duplicate triggers across skills)
-
 ### Phases
 
-1. **Walk skills directory.** List all subdirs containing `SKILL.md`.
-2. **Validate frontmatter.** Parse YAML, check required fields.
-3. **Validate sections.** Check for the required headings.
-4. **Check manifest.** Every skill dir must be in `manifest.json`.
-5. **Check resolver.** Every manifest skill must have a RESOLVER row.
-6. **Check round-trip.** RESOLVER trigger ↔ frontmatter triggers.
-7. **Report results.**
-
-### Automation
+1. Walk skills directory. List all subdirs containing `SKILL.md`.
+2. Parse YAML, check required fields.
+3. Check for the required headings.
+4. Check manifest. Every skill dir must be in `manifest.json`.
+5. Every manifest skill must have a RESOLVER row.
+6. RESOLVER trigger ↔ frontmatter triggers.
+7. Report results.
+
+### Automation (( inert ))
+
+The CI-gated check is the package.json `test` script.
+
+
+#### Automation — steps
 
 ```bash
 bun test test/skills-conformance.test.ts test/resolver.test.ts
 ```
-
-The CI-gated check is the package.json `test` script.
 
 ### Output format
 
@@ -93,9 +100,10 @@
 - <skill>: <issue>
 ```
 
-## Mode 2: Project test-suite health (v0.25.1)
-
-### When to use
+## Mode 2: Project test-suite health (v0.25.1) (( inert ))
+
+### When to use (( role: procedure ))
+use judgment to follow the When to use guidance:
 
 - Daily test cron fires
 - User asks "run the tests" / "how are the tests" / "what's broken"
@@ -103,36 +111,46 @@
 - After container restart (bootstrap)
 - When something seems off and you want to verify system health
 
-### Test tiers
-
+### Test tiers (( inert ))
+
+
+#### Test tiers — steps
+
+!!! table (( ai-discretion ))
 | Tier | What it runs | Wall time | Gates |
 |------|--------------|-----------|-------|
-| **Unit** | `bun test` (deterministic, zero external calls) | <2s | Every commit |
-| **Evals** | LLM-judge or quality evals | ~60s | Daily |
-| **Integration** | E2E tests against real Postgres | ~5m | Pre-ship + nightly |
-| **System health** | Disk / memory / CPU / service liveness | <10s | Daily |
-
-### Daily run protocol
+| Unit | `bun test` (deterministic, zero external calls) | <2s | Every commit |
+| Evals | LLM-judge or quality evals | ~60s | Daily |
+| Integration | E2E tests against real Postgres | ~5m | Pre-ship + nightly |
+| System health | Disk / memory / CPU / service liveness | <10s | Daily |
+
+### Daily run protocol (( inert ))
 
 When the cron fires (or the user asks), do ALL of this:
 
-#### 1. Run unit tests
+#### 1. Run unit tests (( inert ))
+
+Parse: total passed, total failed, total skipped, file-level results.
+
+
+##### 1. Run unit tests — steps
 
 ```bash
 bun test 2>&1
 ```
 
-Parse: total passed, total failed, total skipped, file-level results.
-
-#### 2. Run evals (if the project has an evals config)
+#### 2. Run evals (if the project has an evals config) (( inert ))
+
+Parse: same format. Note any flakes (tests that fail due to API
+timeouts, not code bugs).
+
+
+##### 2. Run evals (if the project has an evals config) — steps
 
 ```bash
 # Adapt to the project's eval config
 bun test --filter eval 2>&1
 ```
-
-Parse: same format. Note any flakes (tests that fail due to API
-timeouts, not code bugs).
 
 #### 3. Run system health checks
 
@@ -141,14 +159,7 @@
 - Database connection (if applicable)
 - Critical files exist (CLAUDE.md, AGENTS.md, etc.)
 
-#### 4. Git diff analysis (CRITICAL — regression intelligence)
-
-```bash
-# What changed since last test run?
-git log --oneline --since="24 hours ago"
-```
-
-For each failing test:
+#### 4. Git diff analysis (CRITICAL — regression intelligence) (( inert ))
 
 1. Check if the test itself was modified recently (test change, not
    regression).
@@ -157,17 +168,31 @@
 3. Check if it's a known flake (API timeout, service down).
 4. Check if a dependency was updated (gbrain, bun, etc.).
 
-#### 5. Classify each failure
-
+
+##### 4. Git diff analysis (CRITICAL — regression intelligence) — steps
+
+```bash
+# What changed since last test run?
+git log --oneline --since="24 hours ago"
+```
+
+For each failing test:
+
+#### 5. Classify each failure (( inert ))
+
+
+##### 5. Classify each failure — steps
+
+!!! table (( ai-discretion ))
 | Classification | Marker | Action |
 |---------------|--------|--------|
-| **REGRESSION** — code changed, test broke | 🔴 | Flag with the commit that broke it |
-| **STALE** — test expects old behavior; code is correct | 🟡 | Fix the test, not the code |
-| **FLAKE** — API timeout, service down, LLM variance | ⚠️ | Note, don't alarm; retry once |
-| **NEW** — test was just added and isn't passing yet | 🟢 | Check if intentional |
-| **INFRA** — container restart wiped state | 🛠 | Run bootstrap, retest |
-
-#### 6. Report format
+| REGRESSION — code changed, test broke | 🔴 | Flag with the commit that broke it |
+| STALE — test expects old behavior; code is correct | 🟡 | Fix the test, not the code |
+| FLAKE — API timeout, service down, LLM variance | ⚠️ | Note, don't alarm; retry once |
+| NEW — test was just added and isn't passing yet | 🟢 | Check if intentional |
+| INFRA — container restart wiped state | 🛠 | Run bootstrap, retest |
+
+#### 6. Report format (( inert ))
 
 ```
 🧪 Daily Tests — YYYY-MM-DD
@@ -189,6 +214,7 @@
 ```
 
 #### 7. Auto-fix protocol
+use judgment to follow the 7. Auto-fix protocol guidance:
 
 **DO auto-fix:**
 
@@ -208,6 +234,7 @@
 if there's a related PR or conversation, ask the user if still unclear.
 
 ### State (regression history)
+use judgment to follow the State (regression history) guidance:
 
 Track results in `~/.gbrain/test-state.json` for trend tracking:
 
@@ -229,7 +256,8 @@
 - Flake detection (same test fails intermittently)
 - Regression velocity (how fast do we break things after changes?)
 
-## Anti-Patterns
+## Anti-Patterns (( role: procedure ))
+use judgment to follow the Anti-Patterns guidance:
 
 - ❌ Skipping conformance validation after adding a new skill
 - ❌ Adding skills to `manifest.json` without adding to RESOLVER.md
@@ -240,7 +268,8 @@
 - ❌ Reporting "all clear" without actually running system health checks
 
 
-## Contract
+## Contract (( role: procedure ))
+use judgment to follow the Contract guidance:
 
 This skill guarantees:
 
@@ -251,7 +280,7 @@
 
 The full behavior contract is documented in the body sections above; this section exists for the conformance test.
 
-## Output Format
+## Output Format (( inert, role: template ))
 
 The skill's output shape is documented inline in the body sections above (see "Output", "Brain page format", or equivalent). The literal section header here exists for the conformance test (`test/skills-conformance.test.ts`).
 
```
