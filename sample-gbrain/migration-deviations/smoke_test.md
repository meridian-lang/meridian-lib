# Deviation: smoke_test.meri

- Original: `smoke-test/SKILL.md`
- Ported: `smoke_test.meri`
- Tier: 1 (near-verbatim)
- Similarity: 91%
- Lines: 161 -> 161 (+15 / -15)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- shell-block-routed

## Metrics
- Sections: 14/16 inert (88% inert ratio)
- Judgment: 0 blocks, 0 lines

## Unified diff

```diff
--- original-skills/smoke-test/SKILL.md
+++ skills/smoke_test.meri
@@ -21,7 +21,7 @@
 
 > Run `gbrain smoke-test` or `bash scripts/smoke-test.sh` after any container restart.
 
-## Contract
+## Contract (( inert, role: invariants ))
 
 This skill guarantees:
 - 8 core tests verify gbrain + OpenClaw health after restart
@@ -30,7 +30,7 @@
 - Results logged to `/tmp/gbrain-smoke-test.log`
 - Exit code = number of unfixed failures (0 = all pass)
 
-## Built-in Tests
+## Built-in Tests (( inert ))
 
 | # | Test | Auto-Fix |
 |---|------|----------|
@@ -43,30 +43,30 @@
 | 7 | Embedding API key | — (check .env) |
 | 8 | Brain repo exists | — |
 
-## Usage
+## Usage (( inert ))
 
-### CLI
+### CLI (( role: procedure ))
 ```bash
 gbrain smoke-test
 ```
 
-### Direct
+### Direct (( role: procedure ))
 ```bash
 bash scripts/smoke-test.sh
 ```
 
-### From OpenClaw bootstrap
+### From OpenClaw bootstrap (( inert ))
 Add to your `ensure-services.sh` or equivalent:
 ```bash
 bash /path/to/gbrain/scripts/smoke-test.sh >> /tmp/bootstrap.log 2>&1
 ```
 
-### From an agent
+### From an agent (( inert ))
 ```
 exec: bash /data/gbrain/scripts/smoke-test.sh
 ```
 
-## Adding Custom Tests
+## Adding Custom Tests (( inert ))
 
 Create executable scripts in `~/.gbrain/smoke-tests.d/`:
 
@@ -82,7 +82,7 @@
 - Keep tests fast (< 10s each)
 - Tests run in alphabetical order
 
-## Adding Built-in Tests
+## Adding Built-in Tests (( inert ))
 
 Edit `scripts/smoke-test.sh`. Follow this pattern:
 
@@ -102,7 +102,7 @@
 fi
 ```
 
-### Design rules:
+### Design rules: (( inert ))
 1. **Test first** — never fix without confirming broken
 2. **Re-test after fix** — verify the fix worked
 3. **Timeout everything** — `timeout N` on any command that could hang
@@ -110,7 +110,7 @@
 5. **Idempotent fixes** — safe to run repeatedly
 6. **Skip gracefully** — `skip()` when a prerequisite is missing, don't fail
 
-## Environment Variables
+## Environment Variables (( inert ))
 
 | Var | Default | Description |
 |-----|---------|-------------|
@@ -120,21 +120,21 @@
 | `OPENCLAW_GATEWAY_PORT` | `18789` | Gateway port to test |
 | `GBRAIN_BRAIN_PATH` | `/data/brain` | Brain repo path |
 
-## Known Issues & Their Auto-Fixes
+## Known Issues & Their Auto-Fixes (( inert ))
 
-### Codex Zod core.cjs Missing (discovered 2026-04-23)
+### Codex Zod core.cjs Missing (discovered 2026-04-23) (( inert ))
 - **Symptom:** `Cannot find module './core.cjs'` → all Codex ACP sessions fail
 - **Cause:** Zod v4 npm package ships without `core.cjs` in some installs
 - **Auto-fix:** `npm install zod@4 --force` in the codex extension's zod dir
 - **Persistence:** Does NOT survive container restart (gateway reinstalls deps)
 - This is why smoke tests must run on every restart
 
-### GBrain Worker Auth Failure
+### GBrain Worker Auth Failure (( inert ))
 - **Symptom:** Worker can't connect to DB
 - **Cause:** `GBRAIN_DATABASE_URL` not propagated to worker subprocess
 - **Auto-fix:** Script explicitly passes both `DATABASE_URL` and `GBRAIN_DATABASE_URL`
 
-## Anti-Patterns
+## Anti-Patterns (( inert, role: prohibitions ))
 
 - ❌ Running smoke tests on every chat turn. Once per container restart (or
   on user request) is plenty. The script is cheap but it's not free.
```
