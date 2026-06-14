# Deviation: testing.meri

- Original: `testing/SKILL.md`
- Ported: `testing.meri`
- Tier: 3 (structural rewrite)
- Similarity: 40%
- Lines: 257 -> 257 (+155 / -155)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- shell-block-routed

## Metrics
- Sections: 10/21 inert (48% inert ratio)
- Operational inert: 0
- Unclassified inert: 0
- Inert categories: reference-documentation=8, template=2
- Judgment: 9 blocks, 58 lines

### Inert section details
- L8 `Two modes`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L24 `Mode 1: Skill conformance validation`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L55 `Output format`: template — Template/output shape is metadata unless explicit output assertions are authored.
- L71 `Mode 2: Project test-suite health (v0.25.1)`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L90 `Daily run protocol`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L112 `3. Run system health checks`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L145 `6. Report format`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L166 `7. Auto-fix protocol`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L185 `State (regression history)`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L231 `Output Format`: template — Template/output shape is metadata unless explicit output assertions are authored.

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
 
@@ -44,41 +44,39 @@
 
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
-- `skills/manifest.json` lists every skill directory
-- `skills/RESOLVER.md` references every skill in the manifest
-- `openclaw.plugin.json` `skills[]` round-trips with both
-- No MECE violations (duplicate triggers across skills)
-
+## Mode 1: Skill conformance validation (( inert ))
+
+### Contract (( role: procedure ))
+
+use judgment to follow the Contract guidance:
+  This mode guarantees:
+  
+  item: Every skill directory has a `SKILL.md` file
+  item: Every `SKILL.md` has valid YAML frontmatter (`name`, `description`)
+  item: Every `SKILL.md` has required sections per
+    `test/skills-conformance.test.ts`
+  item: `skills/manifest.json` lists every skill directory
+  item: `skills/RESOLVER.md` references every skill in the manifest
+  item: `openclaw.plugin.json` `skills[]` round-trips with both
+  item: No MECE violations (duplicate triggers across skills)
 ### Phases
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
-
-```bash
-bun test test/skills-conformance.test.ts test/resolver.test.ts
-```
-
-The CI-gated check is the package.json `test` script.
-
+  
+use judgment to validate skill conformance:
+  Walk the skills directory and list every subdirectory containing a SKILL.md.
+  Validate each file's frontmatter fields and required sections.
+  Check that the manifest lists every skill directory and the resolver references every manifest skill.
+  Check the resolver-to-frontmatter trigger round-trip and report results.
+  
+### Automation (( role: procedure ))
+  
+use judgment to follow the Automation guidance:
+  ```bash
+  bun test test/skills-conformance.test.ts test/resolver.test.ts
+  ```
+  
+  The CI-gated check is the package.json `test` script.
 ### Output format
-
+  
 ```
 Skill Validation Report
 ========================
@@ -88,129 +86,129 @@
 Resolver coverage:   N/N
 Round-trip:          N/N
 MECE violations:     N
-
+  
 Issues:
-- <skill>: <issue>
-```
-
-## Mode 2: Project test-suite health (v0.25.1)
+  item: <skill>: <issue>
+```
+
+## Mode 2: Project test-suite health (v0.25.1) (( inert ))
 
 ### When to use
 
 - Daily test cron fires
-- User asks "run the tests" / "how are the tests" / "what's broken"
+- the user asks to run the tests or check test health
 - After significant code changes (often via cross-modal-review)
 - After container restart (bootstrap)
 - When something seems off and you want to verify system health
 
-### Test tiers
-
-| Tier | What it runs | Wall time | Gates |
-|------|--------------|-----------|-------|
-| **Unit** | `bun test` (deterministic, zero external calls) | <2s | Every commit |
-| **Evals** | LLM-judge or quality evals | ~60s | Daily |
-| **Integration** | E2E tests against real Postgres | ~5m | Pre-ship + nightly |
-| **System health** | Disk / memory / CPU / service liveness | <10s | Daily |
-
-### Daily run protocol
-
+### Test tiers (( role: procedure ))
+
+use judgment to follow the Test tiers guidance:
+  | Tier | What it runs | Wall time | Gates |
+  |------|--------------|-----------|-------|
+  | **Unit** | `bun test` (deterministic, zero external calls) | <2s | Every commit |
+  | **Evals** | LLM-judge or quality evals | ~60s | Daily |
+  | **Integration** | E2E tests against real Postgres | ~5m | Pre-ship + nightly |
+  | **System health** | Disk / memory / CPU / service liveness | <10s | Daily |
+### Daily run protocol (( inert ))
+  
 When the cron fires (or the user asks), do ALL of this:
-
-#### 1. Run unit tests
-
-```bash
-bun test 2>&1
-```
-
-Parse: total passed, total failed, total skipped, file-level results.
-
-#### 2. Run evals (if the project has an evals config)
-
-```bash
-# Adapt to the project's eval config
-bun test --filter eval 2>&1
-```
-
-Parse: same format. Note any flakes (tests that fail due to API
-timeouts, not code bugs).
-
-#### 3. Run system health checks
-
-- Disk / memory / CPU
-- gbrain: `gbrain doctor --fast --json`
-- Database connection (if applicable)
-- Critical files exist (CLAUDE.md, AGENTS.md, etc.)
-
-#### 4. Git diff analysis (CRITICAL — regression intelligence)
-
-```bash
-# What changed since last test run?
-git log --oneline --since="24 hours ago"
-```
-
-For each failing test:
-
-1. Check if the test itself was modified recently (test change, not
-   regression).
-2. Check if the code it tests was modified recently (possible
-   regression).
-3. Check if it's a known flake (API timeout, service down).
-4. Check if a dependency was updated (gbrain, bun, etc.).
-
-#### 5. Classify each failure
-
-| Classification | Marker | Action |
-|---------------|--------|--------|
-| **REGRESSION** — code changed, test broke | 🔴 | Flag with the commit that broke it |
-| **STALE** — test expects old behavior; code is correct | 🟡 | Fix the test, not the code |
-| **FLAKE** — API timeout, service down, LLM variance | ⚠️ | Note, don't alarm; retry once |
-| **NEW** — test was just added and isn't passing yet | 🟢 | Check if intentional |
-| **INFRA** — container restart wiped state | 🛠 | Run bootstrap, retest |
-
-#### 6. Report format
-
+  
+#### 1. Run unit tests (( role: procedure ))
+  
+use judgment to follow the 1. Run unit tests guidance:
+  ```bash
+  bun test 2>&1
+  ```
+  
+  Parse: total passed, total failed, total skipped, file-level results.
+#### 2. Run evals (if the project has an evals config) (( role: procedure ))
+  
+use judgment to follow the 2. Run evals (if the project has an evals config) guidance:
+  ```bash
+  # Adapt to the project's eval config
+  bun test --filter eval 2>&1
+  ```
+  
+  Parse: same format. Note any flakes (tests that fail due to API
+  timeouts, not code bugs).
+#### 3. Run system health checks (( inert ))
+  
+  item: Disk / memory / CPU
+  item: gbrain: `gbrain doctor --fast --json`
+  item: Database connection (if applicable)
+  item: Critical files exist (CLAUDE.md, AGENTS.md, etc.)
+  
+#### 4. Git diff analysis (CRITICAL — regression intelligence) (( role: procedure ))
+  
+use judgment to follow the 4. Git diff analysis (CRITICAL — regression intelligence) guidance:
+  ```bash
+  # What changed since last test run?
+  git log --oneline --since="24 hours ago"
+  ```
+  
+  For each failing test:
+  
+  1. Check if the test itself was modified recently (test change, not
+     regression).
+  2. Check if the code it tests was modified recently (possible
+     regression).
+  3. Check if it's a known flake (API timeout, service down).
+  4. Check if a dependency was updated (gbrain, bun, etc.).
+#### 5. Classify each failure (( role: procedure ))
+  
+use judgment to follow the 5. Classify each failure guidance:
+  | Classification | Marker | Action |
+  |---------------|--------|--------|
+  | **REGRESSION** — code changed, test broke | 🔴 | Flag with the commit that broke it |
+  | **STALE** — test expects old behavior; code is correct | 🟡 | Fix the test, not the code |
+  | **FLAKE** — API timeout, service down, LLM variance | ⚠️ | Note, don't alarm; retry once |
+  | **NEW** — test was just added and isn't passing yet | 🟢 | Check if intentional |
+  | **INFRA** — container restart wiped state | 🛠 | Run bootstrap, retest |
+#### 6. Report format (( inert ))
+  
 ```
 🧪 Daily Tests — YYYY-MM-DD
-
+  
 Unit:   X/Y passed (Z skipped)
 Evals:  X/Y passed
 System: [health summary]
-
+  
 REGRESSIONS:
   🔴 <test-name>: broke by commit <sha> "<commit message>"
-
+  
 STALE TESTS:
   🟡 <test-name>: expects X but code now does Y (commit <sha>)
-
+  
 FLAKES:
   ⚠️ <test-name>: timeout (retry passed)
-
+  
 ✅ ALL CLEAR  (when applicable)
 ```
-
-#### 7. Auto-fix protocol
-
+  
+#### 7. Auto-fix protocol (( inert ))
+  
 **DO auto-fix:**
-
-- Test expects an old file path after a rename → update the test
-- Test expects an old version string → update
-- Test expects a file that was intentionally deleted → remove the test
-- Import path broke because file moved → fix the import
-
+  
+  item: Test expects an old file path after a rename → update the test
+  item: Test expects an old version string → update
+  item: Test expects a file that was intentionally deleted → remove the test
+  item: Import path broke because file moved → fix the import
+  
 **DO NOT auto-fix:**
-
-- Test expects behavior A but code now does B → ASK first. Maybe the
+  
+  item: Test expects behavior A but code now does B → ASK first. Maybe the
   test is right and the code has a bug.
-- Security test failing → ALWAYS escalate, never auto-fix.
-- Test was skipped with a TODO → don't un-skip without understanding why.
-
+  item: Security test failing → ALWAYS escalate, never auto-fix.
+  item: Test was skipped with a TODO → don't un-skip without understanding why.
+  
 When uncertain: check the commit message that changed the code, check
 if there's a related PR or conversation, ask the user if still unclear.
-
-### State (regression history)
-
+  
+### State (regression history) (( inert ))
+  
 Track results in `~/.gbrain/test-state.json` for trend tracking:
-
+  
 ```json
 {
   "lastRun": "2026-04-16T13:37:00Z",
@@ -222,35 +220,37 @@
   ]
 }
 ```
-
+  
 This enables:
-
-- Trend tracking (are we getting better or worse?)
-- Flake detection (same test fails intermittently)
-- Regression velocity (how fast do we break things after changes?)
-
-## Anti-Patterns
-
-- ❌ Skipping conformance validation after adding a new skill
-- ❌ Adding skills to `manifest.json` without adding to RESOLVER.md
-- ❌ Treating every red test as a regression. Classify first; many are
+  
+  item: Trend tracking (are we getting better or worse?)
+  item: Flake detection (same test fails intermittently)
+  item: Regression velocity (how fast do we break things after changes?)
+
+## Anti-Patterns (( role: procedure ))
+
+!!! checklist (( ai-autonomy ))
+- [ ] ❌ Skipping conformance validation after adding a new skill
+- [ ] ❌ Adding skills to `manifest.json` without adding to RESOLVER.md
+- [ ] ❌ Treating every red test as a regression. Classify first; many are
   stale or flaky.
-- ❌ Auto-un-skipping a test without understanding why it was skipped
-- ❌ Auto-"fixing" a security test failure
-- ❌ Reporting "all clear" without actually running system health checks
-
-
-## Contract
-
-This skill guarantees:
-
-- Routing matches the canonical triggers in the frontmatter.
-- Output written under the directories listed in `writes_to:` (when applicable).
-- Conventions referenced (`quality.md`, `brain-first.md`, `_brain-filing-rules.md`) are followed.
-- Privacy contract preserved: no real names, no fork-specific filesystem path literals, no upstream-fork references.
-
-The full behavior contract is documented in the body sections above; this section exists for the conformance test.
-
+- [ ] ❌ Auto-un-skipping a test without understanding why it was skipped
+- [ ] ❌ Auto-"fixing" a security test failure
+- [ ] ❌ Reporting "all clear" without actually running system health checks
+
+
+## Contract (( role: procedure ))
+
+use judgment to follow the Contract guidance:
+  > This skill guarantees:
+  
+  !!! checklist (( ai-autonomy ))
+  item: [ ] Routing matches the canonical triggers in the frontmatter.
+  item: [ ] Output written under the directories listed in `writes_to:` (when applicable).
+  item: [ ] Conventions referenced (`quality.md`, `brain-first.md`, `_brain-filing-rules.md`) are followed.
+  item: [ ] Privacy contract preserved: no real names, no fork-specific filesystem path literals, no upstream-fork references.
+  
+  > The full behavior contract is documented in the body sections above; this section exists for the conformance test.
 ## Output Format
 
 The skill's output shape is documented inline in the body sections above (see "Output", "Brain page format", or equivalent). The literal section header here exists for the conformance test (`test/skills-conformance.test.ts`).
```
