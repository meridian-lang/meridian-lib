# Deviation: smoke_test.meri

- Original: `smoke-test/SKILL.md`
- Ported: `smoke_test.meri`
- Tier: 2 (light edits)
- Similarity: 84%
- Lines: 161 -> 180 (+37 / -18)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- shell-block-routed
- inert-section-added

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L52 `From an agent`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L132 `GBrain Worker Auth Failure`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L154 `Output Format`: template - Template/output shape is metadata unless explicit output assertions are authored.

## Metrics
- Sections inert total: 4/13 (31% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert categories: reference-documentation=3, template=1
- Judgment: 5 blocks, 0 lines

### Inert section details
- L52 `From an agent`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L57 `Adding Custom Tests`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L132 `GBrain Worker Auth Failure`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L154 `Output Format`: template — Template/output shape is metadata unless explicit output assertions are authored.

## Unified diff

```diff
--- original-skills/smoke-test/SKILL.md
+++ skills/smoke_test.meri
@@ -21,7 +21,8 @@
 
 > Run `gbrain smoke-test` or `bash scripts/smoke-test.sh` after any container restart.
 
-## Contract
+## Contract (( role: procedure ))
+use judgment to follow the Contract guidance:
 
 This skill guarantees:
 - 8 core tests verify gbrain + OpenClaw health after restart
@@ -30,8 +31,12 @@
 - Results logged to `/tmp/gbrain-smoke-test.log`
 - Exit code = number of unfixed failures (0 = all pass)
 
-## Built-in Tests
+## Built-in Tests (( inert ))
 
+
+### Built-in Tests — steps
+
+!!! table (( ai-discretion ))
 | # | Test | Auto-Fix |
 |---|------|----------|
 | 1 | Bun runtime | Install from bun.sh |
@@ -44,6 +49,7 @@
 | 8 | Brain repo exists | — |
 
 ## Usage
+use judgment to follow the Usage guidance:
 
 ### CLI
 ```bash
@@ -61,12 +67,21 @@
 bash /path/to/gbrain/scripts/smoke-test.sh >> /tmp/bootstrap.log 2>&1
 ```
 
-### From an agent
+### From an agent (( inert ))
 ```
 exec: bash /data/gbrain/scripts/smoke-test.sh
 ```
 
-## Adding Custom Tests
+## Adding Custom Tests (( inert ))
+
+Rules:
+- Exit 0 = pass, non-zero = fail
+- Filename becomes the test name (e.g. `check-redis` from `check-redis.sh`)
+- Keep tests fast (< 10s each)
+- Tests run in alphabetical order
+
+
+### Adding Custom Tests — steps
 
 Create executable scripts in `~/.gbrain/smoke-tests.d/`:
 
@@ -75,12 +90,6 @@
 #!/bin/bash
 redis-cli ping | grep -q PONG
 ```
-
-Rules:
-- Exit 0 = pass, non-zero = fail
-- Filename becomes the test name (e.g. `check-redis` from `check-redis.sh`)
-- Keep tests fast (< 10s each)
-- Tests run in alphabetical order
 
 ## Adding Built-in Tests
 
@@ -103,6 +112,7 @@
 ```
 
 ### Design rules:
+use judgment to follow the Design rules: guidance:
 1. **Test first** — never fix without confirming broken
 2. **Re-test after fix** — verify the fix worked
 3. **Timeout everything** — `timeout N` on any command that could hang
@@ -110,8 +120,12 @@
 5. **Idempotent fixes** — safe to run repeatedly
 6. **Skip gracefully** — `skip()` when a prerequisite is missing, don't fail
 
-## Environment Variables
+## Environment Variables (( inert ))
 
+
+### Environment Variables — steps
+
+!!! table (( ai-discretion ))
 | Var | Default | Description |
 |-----|---------|-------------|
 | `GBRAIN_SMOKE_LOG` | `/tmp/gbrain-smoke-test.log` | Log file path |
@@ -120,21 +134,26 @@
 | `OPENCLAW_GATEWAY_PORT` | `18789` | Gateway port to test |
 | `GBRAIN_BRAIN_PATH` | `/data/brain` | Brain repo path |
 
-## Known Issues & Their Auto-Fixes
+## Known Issues & Their Auto-Fixes (( inert ))
 
 ### Codex Zod core.cjs Missing (discovered 2026-04-23)
-- **Symptom:** `Cannot find module './core.cjs'` → all Codex ACP sessions fail
-- **Cause:** Zod v4 npm package ships without `core.cjs` in some installs
-- **Auto-fix:** `npm install zod@4 --force` in the codex extension's zod dir
+use judgment to follow the Codex Zod core.cjs Missing (discovered 2026-04-23) guidance:
 - **Persistence:** Does NOT survive container restart (gateway reinstalls deps)
 - This is why smoke tests must run on every restart
 
-### GBrain Worker Auth Failure
+
+#### Codex Zod core.cjs Missing (discovered 2026-04-23) — steps
+
+- Symptom: `Cannot find module './core.cjs'` → all Codex ACP sessions fail
+- Cause: Zod v4 npm package ships without `core.cjs` in some installs
+- Auto-fix: `npm install zod@4 --force` in the codex extension's zod dir
+### GBrain Worker Auth Failure (( inert ))
 - **Symptom:** Worker can't connect to DB
 - **Cause:** `GBRAIN_DATABASE_URL` not propagated to worker subprocess
 - **Auto-fix:** Script explicitly passes both `DATABASE_URL` and `GBRAIN_DATABASE_URL`
 
-## Anti-Patterns
+## Anti-Patterns (( role: procedure ))
+use judgment to follow the Anti-Patterns guidance:
 
 - ❌ Running smoke tests on every chat turn. Once per container restart (or
   on user request) is plenty. The script is cheap but it's not free.
@@ -150,7 +169,7 @@
   (`GBRAIN_DATABASE_URL`, `HOME`, etc.) so the script travels across
   container rebuilds.
 
-## Output Format
+## Output Format (( inert, role: template ))
 
 The script writes a one-line status per check to stdout (✅/❌/🔧/⏭️) plus a
 final summary line: `Results: N/M passed, F auto-fixed, S skipped`. A
```
