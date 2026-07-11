# Deviation: testing.meri

- Original: `testing/SKILL.md`
- Ported: `testing.meri`
- Tier: 2 (light edits)
- Similarity: 71%
- Lines: 257 -> 298 (+100 / -59)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- doc-section-marked

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L8 `Two modes`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L41 `Phases`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L62 `Output format`: template - Template/output shape is metadata unless explicit output assertions are authored.
- L171 `6. Report format`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L272 `Output Format`: template - Template/output shape is metadata unless explicit output assertions are authored.

## Metrics
- Sections inert total: 14/16 (88% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert markers (`(( inert ))`, target 0 — the migrator never emits these): 0
- Inert categories: reference-documentation=12, template=2
- Judgment: 2 blocks, 0 lines
- canonical_drift: synonym=2, structure=0, desugar=0, meaning=185

### Inert section details
- L8 `Two modes`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L26 `Contract`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L41 `Phases`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L51 `Automation`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L62 `Output format`: template — Template/output shape is metadata unless explicit output assertions are authored.
- L108 `1. Run unit tests`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L119 `2. Run evals (if the project has an evals config)`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L139 `4. Git diff analysis (CRITICAL — regression intelligence)`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L171 `6. Report format`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L192 `7. Auto-fix protocol`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L221 `State (regression history)`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L246 `Anti-Patterns`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L261 `Contract`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L272 `Output Format`: template — Template/output shape is metadata unless explicit output assertions are authored.

## Unified diff

```diff
--- original-skills/testing/SKILL.md
+++ skills/testing.meri
@@ -28,7 +28,7 @@
 > the test-before-bulk pattern; this skill enforces it across the project's
 > own test suite.
 
-## Two modes
+## Two modes (( role: reference ))
 
 This skill has two related but distinct modes:
 
@@ -44,38 +44,43 @@
 
 Pick the mode by trigger.
 
-## Mode 1: Skill conformance validation
-
-### Contract
-
-This mode guarantees:
-
-- Every skill directory has a `SKILL.md` file
-- Every `SKILL.md` has valid YAML frontmatter (`name`, `description`)
-- Every `SKILL.md` has required sections per
-  `test/skills-conformance.test.ts`
+## Mode 1: Skill conformance validation (( role: reference ))
+
+### Contract (( role: reference ))
+
 - `skills/manifest.json` lists every skill directory
 - `skills/RESOLVER.md` references every skill in the manifest
 - `openclaw.plugin.json` `skills[]` round-trips with both
 - No MECE violations (duplicate triggers across skills)
 
-### Phases
-
-1. **Walk skills directory.** List all subdirs containing `SKILL.md`.
-2. **Validate frontmatter.** Parse YAML, check required fields.
-3. **Validate sections.** Check for the required headings.
-4. **Check manifest.** Every skill dir must be in `manifest.json`.
-5. **Check resolver.** Every manifest skill must have a RESOLVER row.
-6. **Check round-trip.** RESOLVER trigger ↔ frontmatter triggers.
-7. **Report results.**
-
-### Automation
+
+### Contract — steps
+
+> This mode guarantees:
+
+- Every skill directory has a `SKILL.md` file
+- Every `SKILL.md` has valid YAML frontmatter (`name`, `description`)
+- Every `SKILL.md` has required sections per `test/skills-conformance.test.ts`
+### Phases (( role: reference ))
+
+1. Walk skills directory. List all subdirs containing `SKILL.md`.
+2. Parse YAML, check required fields.
+3. Check for the required headings.
+4. Check manifest. Every skill dir must be in `manifest.json`.
+5. Every manifest skill must have a RESOLVER row.
+6. RESOLVER trigger ↔ frontmatter triggers.
+7. Report results.
+
+### Automation (( role: reference ))
+
+The CI-gated check is the package.json `test` script.
+
+
+### Automation — steps
 
 ```bash
 bun test test/skills-conformance.test.ts test/resolver.test.ts
 ```
-
-The CI-gated check is the package.json `test` script.
 
 ### Output format
 
@@ -93,7 +98,7 @@
 - <skill>: <issue>
 ```
 
-## Mode 2: Project test-suite health (v0.25.1)
+## Mode 2: Project test-suite health (v0.25.1) (( role: reference ))
 
 ### When to use
 
@@ -105,34 +110,47 @@
 
 ### Test tiers
 
+
+### Test tiers — steps
+
+!!! table (( ai-discretion ))
 | Tier | What it runs | Wall time | Gates |
 |------|--------------|-----------|-------|
-| **Unit** | `bun test` (deterministic, zero external calls) | <2s | Every commit |
-| **Evals** | LLM-judge or quality evals | ~60s | Daily |
-| **Integration** | E2E tests against real Postgres | ~5m | Pre-ship + nightly |
-| **System health** | Disk / memory / CPU / service liveness | <10s | Daily |
+| Unit | `bun test` (deterministic, zero external calls) | <2s | Every commit |
+| Evals | LLM-judge or quality evals | ~60s | Daily |
+| Integration | E2E tests against real Postgres | ~5m | Pre-ship + nightly |
+| System health | Disk / memory / CPU / service liveness | <10s | Daily |
 
 ### Daily run protocol
 
+
+### Daily run protocol — steps (( role: reference ))
+
 When the cron fires (or the user asks), do ALL of this:
 
-#### 1. Run unit tests
+#### 1. Run unit tests (( role: reference ))
+
+Parse: total passed, total failed, total skipped, file-level results.
+
+
+#### 1. Run unit tests — steps
 
 ```bash
 bun test 2>&1
 ```
 
-Parse: total passed, total failed, total skipped, file-level results.
-
-#### 2. Run evals (if the project has an evals config)
+#### 2. Run evals (if the project has an evals config) (( role: reference ))
+
+Parse: same format. Note any flakes (tests that fail due to API
+timeouts, not code bugs).
+
+
+#### 2. Run evals (if the project has an evals config) — steps
 
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
+#### 4. Git diff analysis (CRITICAL — regression intelligence) (( role: reference ))
 
 1. Check if the test itself was modified recently (test change, not
    regression).
@@ -157,17 +168,30 @@
 3. Check if it's a known flake (API timeout, service down).
 4. Check if a dependency was updated (gbrain, bun, etc.).
 
+
+#### 4. Git diff analysis (CRITICAL — regression intelligence) — steps
+
+```bash
+# What changed since last test run?
+git log --oneline --since="24 hours ago"
+```
+
+For each failing test:
+
 #### 5. Classify each failure
+
+
+#### 5. Classify each failure — steps
 
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
+#### 6. Report format (( role: reference ))
 
 ```
 🧪 Daily Tests — YYYY-MM-DD
@@ -188,7 +212,7 @@
 ✅ ALL CLEAR  (when applicable)
 ```
 
-#### 7. Auto-fix protocol
+#### 7. Auto-fix protocol (( role: reference ))
 
 **DO auto-fix:**
 
@@ -201,15 +225,23 @@
 
 - Test expects behavior A but code now does B → ASK first. Maybe the
   test is right and the code has a bug.
+
+#### 7. Auto-fix protocol — steps
+
 - Security test failing → ALWAYS escalate, never auto-fix.
+
+#### 7. Auto-fix protocol — steps 2
+
+use judgment to follow the 7. Auto-fix protocol — steps 2 guidance:
 - Test was skipped with a TODO → don't un-skip without understanding why.
+
+
+#### 7. Auto-fix protocol — steps 3
 
 When uncertain: check the commit message that changed the code, check
 if there's a related PR or conversation, ask the user if still unclear.
 
-### State (regression history)
-
-Track results in `~/.gbrain/test-state.json` for trend tracking:
+### State (regression history) (( role: reference ))
 
 ```json
 {
@@ -229,18 +261,27 @@
 - Flake detection (same test fails intermittently)
 - Regression velocity (how fast do we break things after changes?)
 
-## Anti-Patterns
+
+### State (regression history) — steps
+
+Track results in `~/.gbrain/test-state.json` for trend tracking:
+
+## Anti-Patterns (( role: reference ))
 
 - ❌ Skipping conformance validation after adding a new skill
 - ❌ Adding skills to `manifest.json` without adding to RESOLVER.md
 - ❌ Treating every red test as a regression. Classify first; many are
   stale or flaky.
-- ❌ Auto-un-skipping a test without understanding why it was skipped
 - ❌ Auto-"fixing" a security test failure
 - ❌ Reporting "all clear" without actually running system health checks
 
 
-## Contract
+
+### Anti-Patterns — steps (( role: reference ))
+
+use judgment to follow the Anti-Patterns — steps guidance:
+- ❌ Auto-un-skipping a test without understanding why it was skipped
+## Contract (( role: reference ))
 
 This skill guarantees:
 
@@ -251,7 +292,7 @@
 
 The full behavior contract is documented in the body sections above; this section exists for the conformance test.
 
-## Output Format
+## Output Format (( role: template ))
 
 The skill's output shape is documented inline in the body sections above (see "Output", "Brain page format", or equivalent). The literal section header here exists for the conformance test (`test/skills-conformance.test.ts`).
 
```
