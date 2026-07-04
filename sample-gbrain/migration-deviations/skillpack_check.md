# Deviation: skillpack_check.meri

- Original: `skillpack-check/SKILL.md`
- Ported: `skillpack_check.meri`
- Tier: 1 (near-verbatim)
- Similarity: 92%
- Lines: 133 -> 133 (+11 / -11)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- inert-section-added

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L4 `Contract`: normative-contract - Normative invariants prose needs mining into assertions or explicit AI routing.
- L19 `When to run`: operational-procedure - Marked or derived as applicability, but inert suppresses execution.
- L27 `What to do with the output`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L29 `Happy path (`healthy: true`)`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L33 `Action needed (`healthy: false`)`: operational-content - Body contains command, table, checklist, or explicit AI-routing surface.
- L54 `Determine failure (`exit 2`)`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L63 `Output format`: template - Template/output shape is metadata unless explicit output assertions are authored.
- L87 `Anti-Patterns`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L97 `Output Format`: template - Template/output shape is metadata unless explicit output assertions are authored.
- L103 `Related`: reference-documentation - Reference documentation, rationale, examples, or changelog.

## Metrics
- Sections: 10/10 inert (100% inert ratio)
- Operational inert: 3
- Unclassified inert: 0
- Inert categories: normative-contract=1, operational-content=1, operational-procedure=1, reference-documentation=5, template=2
- Judgment: 0 blocks, 0 lines

### Inert section details
- L4 `Contract`: normative-contract — Normative invariants prose needs mining into assertions or explicit AI routing.
- L19 `When to run`: operational-procedure — Marked or derived as applicability, but inert suppresses execution.
- L27 `What to do with the output`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L29 `Happy path (`healthy: true`)`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L33 `Action needed (`healthy: false`)`: operational-content — Body contains command, table, checklist, or explicit AI-routing surface.
- L54 `Determine failure (`exit 2`)`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L63 `Output format`: template — Template/output shape is metadata unless explicit output assertions are authored.
- L87 `Anti-Patterns`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L97 `Output Format`: template — Template/output shape is metadata unless explicit output assertions are authored.
- L103 `Related`: reference-documentation — Reference documentation, rationale, examples, or changelog.

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
@@ -116,13 +116,13 @@
 - ❌ Treating warnings as failures. Only `fail` status needs action;
   `warn` is informational.
 
-## Output Format
+## Output Format (( inert, role: template ))
 
 The skill itself doesn't write files; it reports the CLI output verbatim to
 the user (or to the agent's briefing pipeline). One-line summary first,
 then the action list, then (only if relevant) the full JSON for debugging.
 
-## Related
+## Related (( inert ))
 
 - `gbrain doctor` — the underlying filesystem + DB check. skillpack-check
   composes this.
```
