# Deviation: testing.meri

- Original: `testing/SKILL.md`
- Ported: `testing.meri`
- Tier: 1 (near-verbatim)
- Similarity: 91%
- Lines: 257 -> 257 (+22 / -22)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added

## Metrics
- Sections: 21/21 inert (100% inert ratio)
- Operational inert: 10
- Unclassified inert: 0
- Inert categories: normative-contract=1, operational-content=7, operational-procedure=2, reference-documentation=9, template=2
- Judgment: 0 blocks, 0 lines

### Inert section details
- L8 `Two modes`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L24 `Mode 1: Skill conformance validation`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L26 `Contract`: operational-content — Body contains command, table, checklist, or explicit AI-routing surface.
- L39 `Phases`: operational-procedure — Marked or derived as procedure, but inert suppresses execution.
- L49 `Automation`: operational-content — Body contains command, table, checklist, or explicit AI-routing surface.
- L57 `Output format`: template — Template/output shape is metadata unless explicit output assertions are authored.
- L73 `Mode 2: Project test-suite health (v0.25.1)`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L75 `When to use`: operational-procedure — Marked or derived as applicability, but inert suppresses execution.
- L83 `Test tiers`: operational-content — Body contains command, table, checklist, or explicit AI-routing surface.
- L92 `Daily run protocol`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L96 `1. Run unit tests`: operational-content — Body contains command, table, checklist, or explicit AI-routing surface.
- L104 `2. Run evals (if the project has an evals config)`: operational-content — Body contains command, table, checklist, or explicit AI-routing surface.
- L114 `3. Run system health checks`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L121 `4. Git diff analysis (CRITICAL — regression intelligence)`: operational-content — Body contains command, table, checklist, or explicit AI-routing surface.
- L137 `5. Classify each failure`: operational-content — Body contains command, table, checklist, or explicit AI-routing surface.
- L147 `6. Report format`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L168 `7. Auto-fix protocol`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L187 `State (regression history)`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L209 `Anti-Patterns`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L220 `Contract`: normative-contract — Normative invariants prose needs mining into assertions or explicit AI routing.
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
 
@@ -44,9 +44,9 @@
 
 Pick the mode by trigger.
 
-## Mode 1: Skill conformance validation
-
-### Contract
+## Mode 1: Skill conformance validation (( inert ))
+
+### Contract (( inert, role: invariants ))
 
 This mode guarantees:
 
@@ -59,7 +59,7 @@
 - `openclaw.plugin.json` `skills[]` round-trips with both
 - No MECE violations (duplicate triggers across skills)
 
-### Phases
+### Phases (( inert, role: procedure ))
 
 1. **Walk skills directory.** List all subdirs containing `SKILL.md`.
 2. **Validate frontmatter.** Parse YAML, check required fields.
@@ -69,7 +69,7 @@
 6. **Check round-trip.** RESOLVER trigger ↔ frontmatter triggers.
 7. **Report results.**
 
-### Automation
+### Automation (( inert ))
 
 ```bash
 bun test test/skills-conformance.test.ts test/resolver.test.ts
@@ -93,9 +93,9 @@
 - <skill>: <issue>
 ```
 
-## Mode 2: Project test-suite health (v0.25.1)
-
-### When to use
+## Mode 2: Project test-suite health (v0.25.1) (( inert ))
+
+### When to use (( inert, role: applicability ))
 
 - Daily test cron fires
 - User asks "run the tests" / "how are the tests" / "what's broken"
@@ -103,7 +103,7 @@
 - After container restart (bootstrap)
 - When something seems off and you want to verify system health
 
-### Test tiers
+### Test tiers (( inert ))
 
 | Tier | What it runs | Wall time | Gates |
 |------|--------------|-----------|-------|
@@ -112,11 +112,11 @@
 | **Integration** | E2E tests against real Postgres | ~5m | Pre-ship + nightly |
 | **System health** | Disk / memory / CPU / service liveness | <10s | Daily |
 
-### Daily run protocol
+### Daily run protocol (( inert ))
 
 When the cron fires (or the user asks), do ALL of this:
 
-#### 1. Run unit tests
+#### 1. Run unit tests (( inert ))
 
 ```bash
 bun test 2>&1
@@ -124,7 +124,7 @@
 
 Parse: total passed, total failed, total skipped, file-level results.
 
-#### 2. Run evals (if the project has an evals config)
+#### 2. Run evals (if the project has an evals config) (( inert ))
 
 ```bash
 # Adapt to the project's eval config
@@ -134,14 +134,14 @@
 Parse: same format. Note any flakes (tests that fail due to API
 timeouts, not code bugs).
 
-#### 3. Run system health checks
+#### 3. Run system health checks (( inert ))
 
 - Disk / memory / CPU
 - gbrain: `gbrain doctor --fast --json`
 - Database connection (if applicable)
 - Critical files exist (CLAUDE.md, AGENTS.md, etc.)
 
-#### 4. Git diff analysis (CRITICAL — regression intelligence)
+#### 4. Git diff analysis (CRITICAL — regression intelligence) (( inert ))
 
 ```bash
 # What changed since last test run?
@@ -157,7 +157,7 @@
 3. Check if it's a known flake (API timeout, service down).
 4. Check if a dependency was updated (gbrain, bun, etc.).
 
-#### 5. Classify each failure
+#### 5. Classify each failure (( inert ))
 
 | Classification | Marker | Action |
 |---------------|--------|--------|
@@ -167,7 +167,7 @@
 | **NEW** — test was just added and isn't passing yet | 🟢 | Check if intentional |
 | **INFRA** — container restart wiped state | 🛠 | Run bootstrap, retest |
 
-#### 6. Report format
+#### 6. Report format (( inert ))
 
 ```
 🧪 Daily Tests — YYYY-MM-DD
@@ -188,7 +188,7 @@
 ✅ ALL CLEAR  (when applicable)
 ```
 
-#### 7. Auto-fix protocol
+#### 7. Auto-fix protocol (( inert ))
 
 **DO auto-fix:**
 
@@ -207,7 +207,7 @@
 When uncertain: check the commit message that changed the code, check
 if there's a related PR or conversation, ask the user if still unclear.
 
-### State (regression history)
+### State (regression history) (( inert ))
 
 Track results in `~/.gbrain/test-state.json` for trend tracking:
 
@@ -229,7 +229,7 @@
 - Flake detection (same test fails intermittently)
 - Regression velocity (how fast do we break things after changes?)
 
-## Anti-Patterns
+## Anti-Patterns (( inert, role: prohibitions ))
 
 - ❌ Skipping conformance validation after adding a new skill
 - ❌ Adding skills to `manifest.json` without adding to RESOLVER.md
@@ -240,7 +240,7 @@
 - ❌ Reporting "all clear" without actually running system health checks
 
 
-## Contract
+## Contract (( inert, role: invariants ))
 
 This skill guarantees:
 
@@ -251,7 +251,7 @@
 
 The full behavior contract is documented in the body sections above; this section exists for the conformance test.
 
-## Output Format
+## Output Format (( inert, role: template ))
 
 The skill's output shape is documented inline in the body sections above (see "Output", "Brain page format", or equivalent). The literal section header here exists for the conformance test (`test/skills-conformance.test.ts`).
 
```
