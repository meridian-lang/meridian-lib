# Deviation: smoke_test.meri

- Original: `smoke-test/SKILL.md`
- Ported: `smoke_test.meri`
- Tier: 2 (light edits)
- Similarity: 50%
- Lines: 161 -> 164 (+82 / -79)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- shell-block-routed

## Metrics
- Sections: 7/16 inert (44% inert ratio)
- Operational inert: 0
- Unclassified inert: 0
- Inert categories: reference-documentation=6, template=1
- Judgment: 5 blocks, 48 lines

### Inert section details
- L29 `Usage`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L48 `From an agent`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L89 `Design rules:`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L107 `Known Issues & Their Auto-Fixes`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L109 `Codex Zod core.cjs Missing (discovered 2026-04-23)`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L116 `GBrain Worker Auth Failure`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L138 `Output Format`: template — Template/output shape is metadata unless explicit output assertions are authored.

## Unified diff

```diff
--- original-skills/smoke-test/SKILL.md
+++ skills/smoke_test.meri
@@ -21,88 +21,90 @@
 
 > Run `gbrain smoke-test` or `bash scripts/smoke-test.sh` after any container restart.
 
-## Contract
+## Contract (( role: procedure ))
 
-This skill guarantees:
-- 8 core tests verify gbrain + OpenClaw health after restart
-- Known failures are auto-fixed before reporting
-- User-extensible via `~/.gbrain/smoke-tests.d/*.sh` drop-in scripts
-- Results logged to `/tmp/gbrain-smoke-test.log`
-- Exit code = number of unfixed failures (0 = all pass)
+> This skill guarantees:
+!!! checklist (( ai-autonomy ))
+- [ ] 8 core tests verify gbrain + OpenClaw health after restart
+- [ ] Known failures are auto-fixed before reporting
+- [ ] User-extensible via `~/.gbrain/smoke-tests.d/*.sh` drop-in scripts
+- [ ] Results logged to `/tmp/gbrain-smoke-test.log`
+- [ ] Exit code = number of unfixed failures (0 = all pass)
 
-## Built-in Tests
+## Built-in Tests (( role: procedure ))
 
-| # | Test | Auto-Fix |
-|---|------|----------|
-| 1 | Bun runtime | Install from bun.sh |
-| 2 | GBrain CLI loads | Reinstall deps |
-| 3 | GBrain database (doctor) | — |
-| 4 | GBrain worker process | Start worker |
-| 5 | OpenClaw Codex plugin (Zod CJS) | `npm install zod@4 --force` |
-| 6 | OpenClaw gateway | — (may not be started yet) |
-| 7 | Embedding API key | — (check .env) |
-| 8 | Brain repo exists | — |
+use judgment to follow the Built-in Tests guidance:
+  | # | Test | Auto-Fix |
+  |---|------|----------|
+  | 1 | Bun runtime | Install from bun.sh |
+  | 2 | GBrain CLI loads | Reinstall deps |
+  | 3 | GBrain database (doctor) | — |
+  | 4 | GBrain worker process | Start worker |
+  | 5 | OpenClaw Codex plugin (Zod CJS) | `npm install zod@4 --force` |
+  | 6 | OpenClaw gateway | — (may not be started yet) |
+  | 7 | Embedding API key | — (check .env) |
+  | 8 | Brain repo exists | — |
+## Usage (( inert ))
 
-## Usage
-
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
-Add to your `ensure-services.sh` or equivalent:
-```bash
-bash /path/to/gbrain/scripts/smoke-test.sh >> /tmp/bootstrap.log 2>&1
-```
+### From OpenClaw bootstrap (( role: procedure ))
 
-### From an agent
+use judgment to follow the From OpenClaw bootstrap guidance:
+  Add to your `ensure-services.sh` or equivalent:
+  ```bash
+  bash /path/to/gbrain/scripts/smoke-test.sh >> /tmp/bootstrap.log 2>&1
+  ```
+### From an agent (( inert ))
 ```
 exec: bash /data/gbrain/scripts/smoke-test.sh
 ```
 
-## Adding Custom Tests
+## Adding Custom Tests (( role: procedure ))
 
-Create executable scripts in `~/.gbrain/smoke-tests.d/`:
+use judgment to follow the Adding Custom Tests guidance:
+  Create executable scripts in `~/.gbrain/smoke-tests.d/`:
+  
+  ```bash
+  # ~/.gbrain/smoke-tests.d/check-redis.sh
+  #!/bin/bash
+  redis-cli ping | grep -q PONG
+  ```
+  
+  Rules:
+  item: Exit 0 = pass, non-zero = fail
+  item: Filename becomes the test name (e.g. `check-redis` from `check-redis.sh`)
+  item: Keep tests fast (< 10s each)
+  item: Tests run in alphabetical order
+## Adding Built-in Tests (( role: procedure ))
 
-```bash
-# ~/.gbrain/smoke-tests.d/check-redis.sh
-#!/bin/bash
-redis-cli ping | grep -q PONG
-```
-
-Rules:
-- Exit 0 = pass, non-zero = fail
-- Filename becomes the test name (e.g. `check-redis` from `check-redis.sh`)
-- Keep tests fast (< 10s each)
-- Tests run in alphabetical order
-
-## Adding Built-in Tests
-
-Edit `scripts/smoke-test.sh`. Follow this pattern:
-
-```bash
-# ── N. [Service Name] ──────────────────────────────────────
-if [test condition]; then
-  pass "[Service Name]"
-else
-  # Auto-fix attempt
-  [fix command]
-  if [re-test condition]; then
-    fixed "[What was fixed]"
-    pass "[Service Name] (after fix)"
+use judgment to follow the Adding Built-in Tests guidance:
+  Edit `scripts/smoke-test.sh`. Follow this pattern:
+  
+  ```bash
+  # ── N. [Service Name] ──────────────────────────────────────
+  if [test condition]; then
+    pass "[Service Name]"
   else
-    fail "[Service Name] — [error detail]"
+    # Auto-fix attempt
+    [fix command]
+    if [re-test condition]; then
+      fixed "[What was fixed]"
+      pass "[Service Name] (after fix)"
+    else
+      fail "[Service Name] — [error detail]"
+    fi
   fi
-fi
-```
-
-### Design rules:
+  ```
+### Design rules: (( inert ))
 1. **Test first** — never fix without confirming broken
 2. **Re-test after fix** — verify the fix worked
 3. **Timeout everything** — `timeout N` on any command that could hang
@@ -110,43 +112,44 @@
 5. **Idempotent fixes** — safe to run repeatedly
 6. **Skip gracefully** — `skip()` when a prerequisite is missing, don't fail
 
-## Environment Variables
+## Environment Variables (( role: procedure ))
 
-| Var | Default | Description |
-|-----|---------|-------------|
-| `GBRAIN_SMOKE_LOG` | `/tmp/gbrain-smoke-test.log` | Log file path |
-| `GBRAIN_DIR_OVERRIDE` | (auto-detect) | Force gbrain install path |
-| `GBRAIN_DATABASE_URL` | (from .env) | Database connection URL |
-| `OPENCLAW_GATEWAY_PORT` | `18789` | Gateway port to test |
-| `GBRAIN_BRAIN_PATH` | `/data/brain` | Brain repo path |
+use judgment to follow the Environment Variables guidance:
+  | Var | Default | Description |
+  |-----|---------|-------------|
+  | `GBRAIN_SMOKE_LOG` | `/tmp/gbrain-smoke-test.log` | Log file path |
+  | `GBRAIN_DIR_OVERRIDE` | (auto-detect) | Force gbrain install path |
+  | `GBRAIN_DATABASE_URL` | (from .env) | Database connection URL |
+  | `OPENCLAW_GATEWAY_PORT` | `18789` | Gateway port to test |
+  | `GBRAIN_BRAIN_PATH` | `/data/brain` | Brain repo path |
+## Known Issues & Their Auto-Fixes (( inert ))
 
-## Known Issues & Their Auto-Fixes
-
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
+## Anti-Patterns (( role: procedure ))
 
-- ❌ Running smoke tests on every chat turn. Once per container restart (or
+!!! checklist (( ai-autonomy ))
+- [ ] ❌ Running smoke tests on every chat turn. Once per container restart (or
   on user request) is plenty. The script is cheap but it's not free.
-- ❌ Writing a user drop-in without `timeout N` around any command that
+- [ ] ❌ Writing a user drop-in without `timeout N` around any command that
   could hang. A single hung drop-in stalls every subsequent run.
-- ❌ Auto-fixing without confirming the check is actually broken first.
+- [ ] ❌ Auto-fixing without confirming the check is actually broken first.
   The `pass → fail-detected → fix → re-test` loop is the contract; fixes
   that skip the re-test can report success on a still-broken state.
-- ❌ Treating `skip` as `fail`. Missing prerequisites (no OpenClaw installed,
+- [ ] ❌ Treating `skip` as `fail`. Missing prerequisites (no OpenClaw installed,
   no brain repo configured) are skips, not failures. Exit code = count of
   real failures, not skipped checks.
-- ❌ Hardcoding paths in a user drop-in. Read env vars
+- [ ] ❌ Hardcoding paths in a user drop-in. Read env vars
   (`GBRAIN_DATABASE_URL`, `HOME`, etc.) so the script travels across
   container rebuilds.
 
```
