# Deviation: skillpack_check.meri

- Original: `skillpack-check/SKILL.md`
- Ported: `skillpack_check.meri`
- Tier: 1 (near-verbatim)
- Similarity: 94%
- Lines: 133 -> 133 (+8 / -8)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added

## Metrics
- Sections: 10/10 inert (100% inert ratio)
- Judgment: 0 blocks, 0 lines

## Unified diff

```diff
--- original-skills/skillpack-check/SKILL.md
+++ skillpack_check.meri
@@ -23,7 +23,7 @@
 
 # Skillpack Check
 
-## Contract
+## Contract (( inert, role: invariants ))
 
 Running `gbrain skillpack-check` returns a JSON report with:
 
@@ -38,7 +38,7 @@
 - `1` — action needed. Read `actions[]` and execute.
 - `2` — could not determine (binary crash or missing subcommand). Investigate.
 
-## When to run
+## When to run (( inert, role: applicability ))
 
 - **Daily cron** (e.g. your OpenClaw's `morning-briefing`): `gbrain skillpack-check --quiet`.
   Exit code alone tells you if anything is wrong; surface a one-liner in the
@@ -46,13 +46,13 @@
 - **On demand**: `gbrain skillpack-check` for the full JSON when debugging.
 - **In a CI pipeline**: same pattern — exit code gates, JSON is the evidence.
 
-## What to do with the output
+## What to do with the output (( inert ))
 
-### Happy path (`healthy: true`)
+### Happy path (`healthy: true`) (( inert ))
 
 Surface the summary in the agent's output only if asked. Nothing else.
 
-### Action needed (`healthy: false`)
+### Action needed (`healthy: false`) (( inert ))
 
 The `actions[]` array contains the commands to run, in order. Execute them:
 
@@ -73,7 +73,7 @@
 - Free-text action (no `Run:` prefix in the source message) — agent judgment
   needed. Quote it in the report for the user.
 
-### Determine failure (`exit 2`)
+### Determine failure (`exit 2`) (( inert ))
 
 Treat as urgent. Probably means the gbrain binary is missing from `$PATH` or
 a required subcommand crashed. Check:
@@ -106,7 +106,7 @@
 }
 ```
 
-## Anti-Patterns
+## Anti-Patterns (( inert, role: prohibitions ))
 
 - ❌ Running without `--quiet` in a cron that emails its output — you'll get
   the full JSON blob in every daily email. Use `--quiet` in crons.
@@ -122,7 +122,7 @@
 the user (or to the agent's briefing pipeline). One-line summary first,
 then the action list, then (only if relevant) the full JSON for debugging.
 
-## Related
+## Related (( inert ))
 
 - `gbrain doctor` — the underlying filesystem + DB check. skillpack-check
   composes this.
```
