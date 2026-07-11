# Deviation: smoke_test.meri

- Original: `smoke-test/SKILL.md`
- Ported: `smoke_test.meri`
- Tier: 2 (light edits)
- Similarity: 82%
- Lines: 161 -> 182 (+41 / -20)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- doc-section-marked

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L6 `Contract`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L49 `From an agent`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L135 `GBrain Worker Auth Failure`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L140 `Anti-Patterns`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L156 `Output Format`: template - Template/output shape is metadata unless explicit output assertions are authored.

## Metrics
- Sections inert total: 8/12 (67% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert markers (`(( inert ))`, target 0 — the migrator never emits these): 0
- Inert categories: reference-documentation=7, template=1
- Judgment: 0 blocks, 0 lines
- canonical_drift: synonym=0, structure=0, desugar=0, meaning=130

### Inert section details
- L6 `Contract`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L49 `From an agent`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L54 `Adding Custom Tests`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L93 `Design rules:`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L122 `Codex Zod core.cjs Missing (discovered 2026-04-23)`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L135 `GBrain Worker Auth Failure`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L140 `Anti-Patterns`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L156 `Output Format`: template — Template/output shape is metadata unless explicit output assertions are authored.

## Unified diff

```diff
--- original-skills/smoke-test/SKILL.md
+++ skills/smoke_test.meri
@@ -21,7 +21,7 @@
 
 > Run `gbrain smoke-test` or `bash scripts/smoke-test.sh` after any container restart.
 
-## Contract
+## Contract (( role: reference ))
 
 This skill guarantees:
 - 8 core tests verify gbrain + OpenClaw health after restart
@@ -31,6 +31,9 @@
 - Exit code = number of unfixed failures (0 = all pass)
 
 ## Built-in Tests
+
+
+### Built-in Tests — steps (( role: reference ))
 
 | # | Test | Auto-Fix |
 |---|------|----------|
@@ -61,12 +64,21 @@
 bash /path/to/gbrain/scripts/smoke-test.sh >> /tmp/bootstrap.log 2>&1
 ```
 
-### From an agent
+### From an agent (( role: reference ))
 ```
 exec: bash /data/gbrain/scripts/smoke-test.sh
 ```
 
-## Adding Custom Tests
+## Adding Custom Tests (( role: reference ))
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
 
@@ -75,12 +87,6 @@
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
 
@@ -102,15 +108,24 @@
 fi
 ```
 
-### Design rules:
-1. **Test first** — never fix without confirming broken
+### Design rules: (( role: reference ))
 2. **Re-test after fix** — verify the fix worked
-3. **Timeout everything** — `timeout N` on any command that could hang
 4. **Use helpers** — `pass()`, `fail()`, `fixed()`, `skip()`
 5. **Idempotent fixes** — safe to run repeatedly
 6. **Skip gracefully** — `skip()` when a prerequisite is missing, don't fail
 
+
+### Design rules: — steps (( role: reference ))
+
+1. Test first — never fix without confirming broken
+
+### Design rules: — steps 2
+
+3. Timeout everything — `timeout N` on any command that could hang
 ## Environment Variables
+
+
+### Environment Variables — steps (( role: reference ))
 
 | Var | Default | Description |
 |-----|---------|-------------|
@@ -120,21 +135,27 @@
 | `OPENCLAW_GATEWAY_PORT` | `18789` | Gateway port to test |
 | `GBRAIN_BRAIN_PATH` | `/data/brain` | Brain repo path |
 
-## Known Issues & Their Auto-Fixes
+## Known Issues & Their Auto-Fixes (( role: reference ))
 
-### Codex Zod core.cjs Missing (discovered 2026-04-23)
-- **Symptom:** `Cannot find module './core.cjs'` → all Codex ACP sessions fail
-- **Cause:** Zod v4 npm package ships without `core.cjs` in some installs
-- **Auto-fix:** `npm install zod@4 --force` in the codex extension's zod dir
+### Codex Zod core.cjs Missing (discovered 2026-04-23) (( role: reference ))
 - **Persistence:** Does NOT survive container restart (gateway reinstalls deps)
+
+### Codex Zod core.cjs Missing (discovered 2026-04-23) — steps
+
+- Symptom: `Cannot find module './core.cjs'` → all Codex ACP sessions fail
+- Cause: Zod v4 npm package ships without `core.cjs` in some installs
+- Auto-fix: `npm install zod@4 --force` in the codex extension's zod dir
+
+### Codex Zod core.cjs Missing (discovered 2026-04-23) — steps 2 (( role: reference ))
+
 - This is why smoke tests must run on every restart
 
-### GBrain Worker Auth Failure
+### GBrain Worker Auth Failure (( role: reference ))
 - **Symptom:** Worker can't connect to DB
 - **Cause:** `GBRAIN_DATABASE_URL` not propagated to worker subprocess
 - **Auto-fix:** Script explicitly passes both `DATABASE_URL` and `GBRAIN_DATABASE_URL`
 
-## Anti-Patterns
+## Anti-Patterns (( role: reference ))
 
 - ❌ Running smoke tests on every chat turn. Once per container restart (or
   on user request) is plenty. The script is cheap but it's not free.
@@ -150,7 +171,7 @@
   (`GBRAIN_DATABASE_URL`, `HOME`, etc.) so the script travels across
   container rebuilds.
 
-## Output Format
+## Output Format (( role: template ))
 
 The script writes a one-line status per check to stdout (✅/❌/🔧/⏭️) plus a
 final summary line: `Results: N/M passed, F auto-fixed, S skipped`. A
```
