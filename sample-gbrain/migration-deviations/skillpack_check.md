# Deviation: skillpack_check.meri

- Original: `skillpack-check/SKILL.md`
- Ported: `skillpack_check.meri`
- Tier: 2 (light edits)
- Similarity: 76%
- Lines: 133 -> 154 (+45 / -24)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- shell-block-routed
- inert-section-added

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L31 `Happy path (`healthy: true`)`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L74 `Output format`: template - Template/output shape is metadata unless explicit output assertions are authored.
- L112 `Output Format`: template - Template/output shape is metadata unless explicit output assertions are authored.

## Metrics
- Sections inert total: 5/8 (62% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert categories: reference-documentation=3, template=2
- Judgment: 3 blocks, 0 lines

### Inert section details
- L31 `Happy path (`healthy: true`)`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L35 `Action needed (`healthy: false`)`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L74 `Output format`: template — Template/output shape is metadata unless explicit output assertions are authored.
- L112 `Output Format`: template — Template/output shape is metadata unless explicit output assertions are authored.
- L118 `Related`: reference-documentation — Reference documentation, rationale, examples, or changelog.

## Unified diff

```diff
--- original-skills/skillpack-check/SKILL.md
+++ skills/skillpack_check.meri
@@ -3,8 +3,8 @@
 version: 1.0.0
 description: |
   Run `gbrain skillpack-check` to produce an agent-readable JSON health report
-  for the gbrain install. Wraps `gbrain doctor` + `gbrain apply-migrations
-  --list` so a host agent (your OpenClaw's morning-briefing, any OpenClaw cron)
+  for the gbrain install. Wraps `gbrain doctor` + ``gbrain apply-migrations
+  --list`` so a host agent (your OpenClaw's morning-briefing, any OpenClaw cron)
   can see at a glance whether the skillpack needs attention.
 
   Use when the user asks "is gbrain healthy?", when a cron fires a morning
@@ -23,7 +23,8 @@
 
 # Skillpack Check
 
-## Contract
+## Contract (( role: procedure ))
+use judgment to follow the Contract guidance:
 
 Running `gbrain skillpack-check` returns a JSON report with:
 
@@ -38,7 +39,8 @@
 - `1` — action needed. Read `actions[]` and execute.
 - `2` — could not determine (binary crash or missing subcommand). Investigate.
 
-## When to run
+## When to run (( role: procedure ))
+use judgment to follow the When to run guidance:
 
 - **Daily cron** (e.g. your OpenClaw's `morning-briefing`): `gbrain skillpack-check --quiet`.
   Exit code alone tells you if anything is wrong; surface a one-liner in the
@@ -46,15 +48,24 @@
 - **On demand**: `gbrain skillpack-check` for the full JSON when debugging.
 - **In a CI pipeline**: same pattern — exit code gates, JSON is the evidence.
 
-## What to do with the output
+## What to do with the output (( inert ))
 
-### Happy path (`healthy: true`)
+### Happy path (`healthy: true`) (( inert ))
 
 Surface the summary in the agent's output only if asked. Nothing else.
 
-### Action needed (`healthy: false`)
+### Action needed (`healthy: false`) (( inert ))
 
-The `actions[]` array contains the commands to run, in order. Execute them:
+  Run this (it's idempotent). If it exits `status: "partial"`, the host has
+  non-builtin cron handlers that need plugin registration — follow
+  `skills/migrations/v0.11.0.md`.
+- Free-text action (no `Run:` prefix in the source message) — agent judgment
+  needed. Quote it in the report for the user.
+
+
+#### Action needed (`healthy: false`) — steps
+
+> The `actions[]` array contains the commands to run, in order. Execute them:
 
 ```bash
 for cmd in $(echo "$REPORT" | jq -r '.actions[]'); do
@@ -62,21 +73,21 @@
 done
 ```
 
-Common `actions[]` entries and what they mean:
+> Common `actions[]` entries and what they mean:
 
 - `gbrain apply-migrations --yes` — A migration is pending or half-finished.
-  Run this (it's idempotent). If it exits `status: "partial"`, the host has
-  non-builtin cron handlers that need plugin registration — follow
-  `skills/migrations/v0.11.0.md`.
+
+#### Action needed (`healthy: false`) — steps 2
+
 - `gbrain embed --stale` — Embeddings are stale.
 - `gbrain check-backlinks --fix` — Dead links or missing back-links.
-- Free-text action (no `Run:` prefix in the source message) — agent judgment
-  needed. Quote it in the report for the user.
+### Determine failure (`exit 2`) (( inert ))
 
-### Determine failure (`exit 2`)
 
-Treat as urgent. Probably means the gbrain binary is missing from `$PATH` or
-a required subcommand crashed. Check:
+#### Determine failure (`exit 2`) — steps
+
+> Treat as urgent. Probably means the gbrain binary is missing from `$PATH` or
+> a required subcommand crashed. Check:
 
 1. `which gbrain` returns a path
 2. `gbrain --version` exits 0
@@ -106,28 +117,38 @@
 }
 ```
 
-## Anti-Patterns
+## Anti-Patterns (( role: procedure ))
+use judgment to follow the Anti-Patterns guidance:
 
 - ❌ Running without `--quiet` in a cron that emails its output — you'll get
   the full JSON blob in every daily email. Use `--quiet` in crons.
-- ❌ Ignoring exit code 2. A crashed doctor is worse than a failing check
-  because you don't even know what's wrong.
 - ❌ Running on every chat turn. Once per hour (or on user request) is plenty.
 - ❌ Treating warnings as failures. Only `fail` status needs action;
   `warn` is informational.
 
-## Output Format
+
+### Anti-Patterns — steps (( inert ))
+
+- ❌ Ignoring exit code 2. A crashed doctor is worse than a failing check
+  because you don't even know what's wrong.
+## Output Format (( inert, role: template ))
 
 The skill itself doesn't write files; it reports the CLI output verbatim to
 the user (or to the agent's briefing pipeline). One-line summary first,
 then the action list, then (only if relevant) the full JSON for debugging.
 
-## Related
+## Related (( inert ))
+
+- `skills/migrations/v0.11.0.md` — the host-agent instruction manual for
+  resolving `pending-host-work.jsonl` items.
+
+### Related — steps
 
 - `gbrain doctor` — the underlying filesystem + DB check. skillpack-check
   composes this.
 - `gbrain apply-migrations --list` — the migration status view.
-- `skills/migrations/v0.11.0.md` — the host-agent instruction manual for
-  resolving `pending-host-work.jsonl` items.
+
+### Related — steps 2
+
 - `docs/guides/minions-fix.md` — troubleshooting a half-migrated install.
 
```
