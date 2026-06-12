# Deviation: testing.meri

- Original: `testing/SKILL.md`
- Ported: `testing.meri`
- Tier: 1 (near-verbatim)
- Similarity: 90%
- Lines: 257 -> 255 (+25 / -27)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added

## Metrics
- Sections: 19/21 inert (90% inert ratio)
- Judgment: 1 blocks, 4 lines

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
 
@@ -61,15 +61,13 @@
 
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
+use judgment to validate skill conformance:
+  Walk the skills directory and list every subdirectory containing a SKILL.md.
+  Validate each file's frontmatter fields and required sections.
+  Check that the manifest lists every skill directory and the resolver references every manifest skill.
+  Check the resolver-to-frontmatter trigger round-trip and report results.
+
+### Automation (( inert ))
 
 ```bash
 bun test test/skills-conformance.test.ts test/resolver.test.ts
@@ -93,17 +91,17 @@
 - <skill>: <issue>
 ```
 
-## Mode 2: Project test-suite health (v0.25.1)
+## Mode 2: Project test-suite health (v0.25.1) (( inert ))
 
 ### When to use
 
 - Daily test cron fires
-- User asks "run the tests" / "how are the tests" / "what's broken"
+- the user asks to run the tests or check test health
 - After significant code changes (often via cross-modal-review)
 - After container restart (bootstrap)
 - When something seems off and you want to verify system health
 
-### Test tiers
+### Test tiers (( inert ))
 
 | Tier | What it runs | Wall time | Gates |
 |------|--------------|-----------|-------|
@@ -112,11 +110,11 @@
 | **Integration** | E2E tests against real Postgres | ~5m | Pre-ship + nightly |
 | **System health** | Disk / memory / CPU / service liveness | <10s | Daily |
 
-### Daily run protocol
+### Daily run protocol (( inert ))
 
 When the cron fires (or the user asks), do ALL of this:
 
-#### 1. Run unit tests
+#### 1. Run unit tests (( inert ))
 
 ```bash
 bun test 2>&1
@@ -124,7 +122,7 @@
 
 Parse: total passed, total failed, total skipped, file-level results.
 
-#### 2. Run evals (if the project has an evals config)
+#### 2. Run evals (if the project has an evals config) (( inert ))
 
 ```bash
 # Adapt to the project's eval config
@@ -134,14 +132,14 @@
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
@@ -157,7 +155,7 @@
 3. Check if it's a known flake (API timeout, service down).
 4. Check if a dependency was updated (gbrain, bun, etc.).
 
-#### 5. Classify each failure
+#### 5. Classify each failure (( inert ))
 
 | Classification | Marker | Action |
 |---------------|--------|--------|
@@ -167,7 +165,7 @@
 | **NEW** — test was just added and isn't passing yet | 🟢 | Check if intentional |
 | **INFRA** — container restart wiped state | 🛠 | Run bootstrap, retest |
 
-#### 6. Report format
+#### 6. Report format (( inert ))
 
 ```
 🧪 Daily Tests — YYYY-MM-DD
@@ -188,7 +186,7 @@
 ✅ ALL CLEAR  (when applicable)
 ```
 
-#### 7. Auto-fix protocol
+#### 7. Auto-fix protocol (( inert ))
 
 **DO auto-fix:**
 
@@ -207,7 +205,7 @@
 When uncertain: check the commit message that changed the code, check
 if there's a related PR or conversation, ask the user if still unclear.
 
-### State (regression history)
+### State (regression history) (( inert ))
 
 Track results in `~/.gbrain/test-state.json` for trend tracking:
 
@@ -229,7 +227,7 @@
 - Flake detection (same test fails intermittently)
 - Regression velocity (how fast do we break things after changes?)
 
-## Anti-Patterns
+## Anti-Patterns (( inert, role: prohibitions ))
 
 - ❌ Skipping conformance validation after adding a new skill
 - ❌ Adding skills to `manifest.json` without adding to RESOLVER.md
@@ -240,7 +238,7 @@
 - ❌ Reporting "all clear" without actually running system health checks
 
 
-## Contract
+## Contract (( inert, role: invariants ))
 
 This skill guarantees:
 
```
