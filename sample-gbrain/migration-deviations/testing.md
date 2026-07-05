# Deviation: testing.meri

- Original: `testing/SKILL.md`
- Ported: `testing.meri`
- Tier: 2 (light edits)
- Similarity: 69%
- Lines: 257 -> 293 (+102 / -66)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- doc-section-marked

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L8 `Two modes`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L42 `Phases`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L63 `Output format`: template - Template/output shape is metadata unless explicit output assertions are authored.
- L81 `When to use`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L102 `Daily run protocol`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L169 `6. Report format`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L267 `Output Format`: template - Template/output shape is metadata unless explicit output assertions are authored.

## Metrics
- Sections inert total: 16/17 (94% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert markers (`(( inert ))`, target 0 — the migrator never emits these): 0
- Inert categories: reference-documentation=14, template=2
- Judgment: 2 blocks, 0 lines

### Inert section details
- L8 `Two modes`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L26 `Contract`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L42 `Phases`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L52 `Automation`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L63 `Output format`: template — Template/output shape is metadata unless explicit output assertions are authored.
- L81 `When to use`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L102 `Daily run protocol`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L106 `1. Run unit tests`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L117 `2. Run evals (if the project has an evals config)`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L137 `4. Git diff analysis (CRITICAL — regression intelligence)`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L169 `6. Report format`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L190 `7. Auto-fix protocol`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L216 `State (regression history)`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L241 `Anti-Patterns`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L256 `Contract`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L267 `Output Format`: template — Template/output shape is metadata unless explicit output assertions are authored.

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
 
@@ -44,38 +44,44 @@
 
 Pick the mode by trigger.
 
-## Mode 1: Skill conformance validation
-
-### Contract
-
-This mode guarantees:
+## Mode 1: Skill conformance validation (( role: reference ))
+
+### Contract (( role: reference ))
+
+- `skills/manifest.json` lists every skill directory
+- `skills/RESOLVER.md` references every skill in the manifest
+- `openclaw.plugin.json` `skills[]` round-trips with both
+- No MECE violations (duplicate triggers across skills)
+
+
+### Contract — steps (( role: reference ))
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
 
@@ -93,9 +99,9 @@
 - <skill>: <issue>
 ```
 
-## Mode 2: Project test-suite health (v0.25.1)
-
-### When to use
+## Mode 2: Project test-suite health (v0.25.1) (( role: reference ))
+
+### When to use (( role: reference ))
 
 - Daily test cron fires
 - User asks "run the tests" / "how are the tests" / "what's broken"
@@ -105,34 +111,44 @@
 
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
-
-### Daily run protocol
+| Unit | `bun test` (deterministic, zero external calls) | <2s | Every commit |
+| Evals | LLM-judge or quality evals | ~60s | Daily |
+| Integration | E2E tests against real Postgres | ~5m | Pre-ship + nightly |
+| System health | Disk / memory / CPU / service liveness | <10s | Daily |
+
+### Daily run protocol (( role: reference ))
 
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
 
@@ -141,14 +157,7 @@
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
@@ -157,17 +166,30 @@
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
@@ -188,7 +210,7 @@
 ✅ ALL CLEAR  (when applicable)
 ```
 
-#### 7. Auto-fix protocol
+#### 7. Auto-fix protocol (( role: reference ))
 
 **DO auto-fix:**
 
@@ -201,15 +223,20 @@
 
 - Test expects behavior A but code now does B → ASK first. Maybe the
   test is right and the code has a bug.
-- Security test failing → ALWAYS escalate, never auto-fix.
-- Test was skipped with a TODO → don't un-skip without understanding why.
-
 When uncertain: check the commit message that changed the code, check
 if there's a related PR or conversation, ask the user if still unclear.
 
-### State (regression history)
-
-Track results in `~/.gbrain/test-state.json` for trend tracking:
+
+#### 7. Auto-fix protocol — steps
+
+- Security test failing → ALWAYS escalate, never auto-fix.
+
+#### 7. Auto-fix protocol — steps 2
+
+use judgment to follow the 7. Auto-fix protocol — steps 2 guidance:
+- Test was skipped with a TODO → don't un-skip without understanding why.
+
+### State (regression history) (( role: reference ))
 
 ```json
 {
@@ -229,18 +256,27 @@
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
 
@@ -251,7 +287,7 @@
 
 The full behavior contract is documented in the body sections above; this section exists for the conformance test.
 
-## Output Format
+## Output Format (( role: template ))
 
 The skill's output shape is documented inline in the body sections above (see "Output", "Brain page format", or equivalent). The literal section header here exists for the conformance test (`test/skills-conformance.test.ts`).
 
```
