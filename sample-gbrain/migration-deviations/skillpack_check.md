# Deviation: skillpack_check.meri

- Original: `skillpack-check/SKILL.md`
- Ported: `skillpack_check.meri`
- Tier: 2 (light edits)
- Similarity: 62%
- Lines: 133 -> 136 (+52 / -49)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- shell-block-routed

## Metrics
- Sections: 6/10 inert (60% inert ratio)
- Operational inert: 0
- Unclassified inert: 0
- Inert categories: reference-documentation=4, template=2
- Judgment: 2 blocks, 20 lines

### Inert section details
- L29 `What to do with the output`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L31 `Happy path (`healthy: true`)`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L56 `Determine failure (`exit 2`)`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L65 `Output format`: template — Template/output shape is metadata unless explicit output assertions are authored.
- L100 `Output Format`: template — Template/output shape is metadata unless explicit output assertions are authored.
- L106 `Related`: reference-documentation — Reference documentation, rationale, examples, or changelog.

## Unified diff

```diff
--- original-skills/skillpack-check/SKILL.md
+++ skills/skillpack_check.meri
@@ -23,61 +23,63 @@
 
 # Skillpack Check
 
-## Contract
+## Contract (( role: procedure ))
 
-Running `gbrain skillpack-check` returns a JSON report with:
+> Running `gbrain skillpack-check` returns a JSON report with:
 
-- **`healthy`** (bool): true if no action needed.
-- **`summary`** (string): one-line summary safe to quote in a briefing.
-- **`actions`** (string[]): every remediation command. If non-empty, run them.
-- **`doctor`**: full `gbrain doctor --fast --json` output (filesystem checks).
-- **`migrations`**: applied/pending/partial counts from `apply-migrations --list`.
+!!! checklist (( ai-autonomy ))
+- [ ] **`healthy`** (bool): true if no action needed.
+- [ ] **`summary`** (string): one-line summary safe to quote in a briefing.
+- [ ] **`actions`** (string[]): every remediation command. If non-empty, run them.
+- [ ] **`doctor`**: full `gbrain doctor --fast --json` output (filesystem checks).
+- [ ] **`migrations`**: applied/pending/partial counts from `apply-migrations --list`.
 
-Exit code:
-- `0` — healthy, nothing to do.
-- `1` — action needed. Read `actions[]` and execute.
-- `2` — could not determine (binary crash or missing subcommand). Investigate.
+> Exit code:
+!!! checklist (( ai-autonomy ))
+- [ ] `0` — healthy, nothing to do.
+- [ ] `1` — action needed. Read `actions[]` and execute.
+- [ ] `2` — could not determine (binary crash or missing subcommand). Investigate.
 
-## When to run
+## When to run (( role: procedure ))
 
-- **Daily cron** (e.g. your OpenClaw's `morning-briefing`): `gbrain skillpack-check --quiet`.
-  Exit code alone tells you if anything is wrong; surface a one-liner in the
-  briefing only when exit != 0. No JSON noise in happy-path briefings.
-- **On demand**: `gbrain skillpack-check` for the full JSON when debugging.
-- **In a CI pipeline**: same pattern — exit code gates, JSON is the evidence.
+use judgment to follow the When to run guidance:
+  item: **Daily cron** (e.g. your OpenClaw's `morning-briefing`): `gbrain skillpack-check --quiet`.
+    Exit code alone tells you if anything is wrong; surface a one-liner in the
+    briefing only when exit != 0. No JSON noise in happy-path briefings.
+  item: **On demand**: `gbrain skillpack-check` for the full JSON when debugging.
+  item: **In a CI pipeline**: same pattern — exit code gates, JSON is the evidence.
+## What to do with the output (( inert ))
 
-## What to do with the output
-
-### Happy path (`healthy: true`)
+### Happy path (`healthy: true`) (( inert ))
 
 Surface the summary in the agent's output only if asked. Nothing else.
 
-### Action needed (`healthy: false`)
+### Action needed (`healthy: false`) (( role: procedure ))
 
-The `actions[]` array contains the commands to run, in order. Execute them:
-
-```bash
-for cmd in $(echo "$REPORT" | jq -r '.actions[]'); do
-  eval "$cmd"
-done
-```
-
-Common `actions[]` entries and what they mean:
-
-- `gbrain apply-migrations --yes` — A migration is pending or half-finished.
-  Run this (it's idempotent). If it exits `status: "partial"`, the host has
-  non-builtin cron handlers that need plugin registration — follow
-  `skills/migrations/v0.11.0.md`.
-- `gbrain embed --stale` — Embeddings are stale.
-- `gbrain check-backlinks --fix` — Dead links or missing back-links.
-- Free-text action (no `Run:` prefix in the source message) — agent judgment
-  needed. Quote it in the report for the user.
-
-### Determine failure (`exit 2`)
-
+use judgment to follow the Action needed (`healthy: false`) guidance:
+  The `actions[]` array contains the commands to run, in order. Execute them:
+  
+  ```bash
+  for cmd in $(echo "$REPORT" | jq -r '.actions[]'); do
+    eval "$cmd"
+  done
+  ```
+  
+  Common `actions[]` entries and what they mean:
+  
+  item: `gbrain apply-migrations --yes` — A migration is pending or half-finished.
+    Run this (it's idempotent). If it exits `status: "partial"`, the host has
+    non-builtin cron handlers that need plugin registration — follow
+    `skills/migrations/v0.11.0.md`.
+  item: `gbrain embed --stale` — Embeddings are stale.
+  item: `gbrain check-backlinks --fix` — Dead links or missing back-links.
+  item: Free-text action (no `Run:` prefix in the source message) — agent judgment
+    needed. Quote it in the report for the user.
+### Determine failure (`exit 2`) (( inert ))
+  
 Treat as urgent. Probably means the gbrain binary is missing from `$PATH` or
 a required subcommand crashed. Check:
-
+  
 1. `which gbrain` returns a path
 2. `gbrain --version` exits 0
 3. `~/.gbrain/` is accessible
@@ -106,14 +108,15 @@
 }
 ```
 
-## Anti-Patterns
+## Anti-Patterns (( role: procedure ))
 
-- ❌ Running without `--quiet` in a cron that emails its output — you'll get
+!!! checklist (( ai-autonomy ))
+- [ ] ❌ Running without `--quiet` in a cron that emails its output — you'll get
   the full JSON blob in every daily email. Use `--quiet` in crons.
-- ❌ Ignoring exit code 2. A crashed doctor is worse than a failing check
+- [ ] ❌ Ignoring exit code 2. A crashed doctor is worse than a failing check
   because you don't even know what's wrong.
-- ❌ Running on every chat turn. Once per hour (or on user request) is plenty.
-- ❌ Treating warnings as failures. Only `fail` status needs action;
+- [ ] ❌ Running on every chat turn. Once per hour (or on user request) is plenty.
+- [ ] ❌ Treating warnings as failures. Only `fail` status needs action;
   `warn` is informational.
 
 ## Output Format
@@ -122,7 +125,7 @@
 the user (or to the agent's briefing pipeline). One-line summary first,
 then the action list, then (only if relevant) the full JSON for debugging.
 
-## Related
+## Related (( inert ))
 
 - `gbrain doctor` — the underlying filesystem + DB check. skillpack-check
   composes this.
```
