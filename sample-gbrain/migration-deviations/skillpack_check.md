# Deviation: skillpack_check.meri

- Original: `skillpack-check/SKILL.md`
- Ported: `skillpack_check.meri`
- Tier: 2 (light edits)
- Similarity: 75%
- Lines: 133 -> 155 (+47 / -25)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- doc-section-marked

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L23 `When to run`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L33 `Happy path (`healthy: true`)`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L76 `Output format`: template - Template/output shape is metadata unless explicit output assertions are authored.
- L113 `Output Format`: template - Template/output shape is metadata unless explicit output assertions are authored.

## Metrics
- Sections inert total: 8/8 (100% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert markers (`(( inert ))`, target 0 — the migrator never emits these): 0
- Inert categories: reference-documentation=6, template=2
- Judgment: 1 blocks, 0 lines

### Inert section details
- L4 `Contract`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L23 `When to run`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L33 `Happy path (`healthy: true`)`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L37 `Action needed (`healthy: false`)`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L76 `Output format`: template — Template/output shape is metadata unless explicit output assertions are authored.
- L100 `Anti-Patterns`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L113 `Output Format`: template — Template/output shape is metadata unless explicit output assertions are authored.
- L119 `Related`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.

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
@@ -23,7 +23,7 @@
 
 # Skillpack Check
 
-## Contract
+## Contract (( role: reference ))
 
 Running `gbrain skillpack-check` returns a JSON report with:
 
@@ -36,25 +36,38 @@
 Exit code:
 - `0` — healthy, nothing to do.
 - `1` — action needed. Read `actions[]` and execute.
+
+### Contract — steps (( role: reference ))
+
+use judgment to follow the Contract — steps guidance:
 - `2` — could not determine (binary crash or missing subcommand). Investigate.
 
-## When to run
+## When to run (( role: reference ))
 
-- **Daily cron** (e.g. your OpenClaw's `morning-briefing`): `gbrain skillpack-check --quiet`.
+- Daily cron (e.g. your OpenClaw's `morning-briefing`): `gbrain skillpack-check --quiet`.
   Exit code alone tells you if anything is wrong; surface a one-liner in the
   briefing only when exit != 0. No JSON noise in happy-path briefings.
-- **On demand**: `gbrain skillpack-check` for the full JSON when debugging.
-- **In a CI pipeline**: same pattern — exit code gates, JSON is the evidence.
+- On demand: `gbrain skillpack-check` for the full JSON when debugging.
+- In a CI pipeline: same pattern — exit code gates, JSON is the evidence.
 
-## What to do with the output
+## What to do with the output (( role: reference ))
 
-### Happy path (`healthy: true`)
+### Happy path (`healthy: true`) (( role: reference ))
 
 Surface the summary in the agent's output only if asked. Nothing else.
 
-### Action needed (`healthy: false`)
+### Action needed (`healthy: false`) (( role: reference ))
 
-The `actions[]` array contains the commands to run, in order. Execute them:
+  Run this (it's idempotent). If it exits `status: "partial"`, the host has
+  non-builtin cron handlers that need plugin registration — follow
+  `skills/migrations/v0.11.0.md`.
+- Free-text action (no `Run:` prefix in the source message) — agent judgment
+  needed. Quote it in the report for the user.
+
+
+### Action needed (`healthy: false`) — steps
+
+> The `actions[]` array contains the commands to run, in order. Execute them:
 
 ```bash
 for cmd in $(echo "$REPORT" | jq -r '.actions[]'); do
@@ -62,18 +75,18 @@
 done
 ```
 
-Common `actions[]` entries and what they mean:
+> Common `actions[]` entries and what they mean:
 
 - `gbrain apply-migrations --yes` — A migration is pending or half-finished.
-  Run this (it's idempotent). If it exits `status: "partial"`, the host has
-  non-builtin cron handlers that need plugin registration — follow
-  `skills/migrations/v0.11.0.md`.
+
+### Action needed (`healthy: false`) — steps 2
+
 - `gbrain embed --stale` — Embeddings are stale.
 - `gbrain check-backlinks --fix` — Dead links or missing back-links.
-- Free-text action (no `Run:` prefix in the source message) — agent judgment
-  needed. Quote it in the report for the user.
+### Determine failure (`exit 2`)
 
-### Determine failure (`exit 2`)
+
+### Determine failure (`exit 2`) — steps (( role: reference ))
 
 Treat as urgent. Probably means the gbrain binary is missing from `$PATH` or
 a required subcommand crashed. Check:
@@ -106,28 +119,37 @@
 }
 ```
 
-## Anti-Patterns
+## Anti-Patterns (( role: reference ))
 
 - ❌ Running without `--quiet` in a cron that emails its output — you'll get
   the full JSON blob in every daily email. Use `--quiet` in crons.
-- ❌ Ignoring exit code 2. A crashed doctor is worse than a failing check
-  because you don't even know what's wrong.
 - ❌ Running on every chat turn. Once per hour (or on user request) is plenty.
 - ❌ Treating warnings as failures. Only `fail` status needs action;
   `warn` is informational.
 
-## Output Format
+
+### Anti-Patterns — steps (( role: reference ))
+
+- ❌ Ignoring exit code 2. A crashed doctor is worse than a failing check
+  because you don't even know what's wrong.
+## Output Format (( role: template ))
 
 The skill itself doesn't write files; it reports the CLI output verbatim to
 the user (or to the agent's briefing pipeline). One-line summary first,
 then the action list, then (only if relevant) the full JSON for debugging.
 
-## Related
+## Related (( role: reference ))
+
+- `skills/migrations/v0.11.0.md` — the host-agent instruction manual for
+  resolving `pending-host-work.jsonl` items.
+
+### Related — steps (( role: reference ))
 
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
