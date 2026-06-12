# Deviation: setup.meri

- Original: `setup/SKILL.md`
- Ported: `setup.meri`
- Tier: 1 (near-verbatim)
- Similarity: 94%
- Lines: 580 -> 580 (+33 / -33)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- shell-block-routed
- preamble-blockquoted

## Metrics
- Sections: 30/31 inert (97% inert ratio)
- Judgment: 0 blocks, 0 lines

## Unified diff

```diff
--- original-skills/setup/SKILL.md
+++ skills/setup.meri
@@ -15,9 +15,9 @@
 
 # Setup GBrain
 
-Set up GBrain from scratch. Target: working brain in under 5 minutes.
-
-## Contract
+> Set up GBrain from scratch. Target: working brain in under 5 minutes.
+
+## Contract (( inert, role: invariants ))
 
 - Setup completes with a working brain verified by `gbrain doctor --json` (all checks OK).
 - The brain-first lookup protocol is injected into the project's AGENTS.md or equivalent.
@@ -25,13 +25,13 @@
 - Schema state is tracked in `~/.gbrain/update-state.json` so future upgrades know what the user adopted or declined.
 - No Supabase anon key is requested; GBrain uses only the database connection string.
 
-## Install (if not already installed)
+## Install (if not already installed) (( role: procedure ))
 
 ```bash
 bun add github:garrytan/gbrain
 ```
 
-## How GBrain connects
+## How GBrain connects (( inert ))
 
 GBrain connects directly to Postgres over the wire protocol. NOT through the
 Supabase REST API. You need the **database connection string** (a `postgresql://` URI),
@@ -44,7 +44,7 @@
 
 **Do NOT ask for the Supabase anon key.** GBrain doesn't use it.
 
-## Why Supabase
+## Why Supabase (( inert ))
 
 Supabase gives you managed Postgres + pgvector (vector search built in) for $25/mo:
 - 8GB database + 100GB storage on Pro tier
@@ -52,13 +52,13 @@
 - pgvector pre-installed, just works
 - Alternative: any Postgres with pgvector extension (self-hosted, Neon, Railway, etc.)
 
-## Prerequisites
+## Prerequisites (( inert ))
 
 - A Supabase account (Pro tier recommended, $25/mo) OR any Postgres with pgvector
 - An OpenAI API key (for semantic search embeddings, ~$4-5 for 7,500 pages)
 - A git-backed markdown knowledge base (or start fresh)
 
-## Available init options
+## Available init options (( inert ))
 
 - `gbrain init --supabase` -- interactive wizard (prompts for connection string)
 - `gbrain init --url <connection_string>` -- direct, no prompts
@@ -68,7 +68,7 @@
 There is no `--local`, `--sqlite`, or offline mode. GBrain requires Postgres + pgvector
 (local PGLite or remote Supabase / self-hosted).
 
-## Phase A.5: Choose Topology (run BEFORE Phase A)
+## Phase A.5: Choose Topology (run BEFORE Phase A) (( inert, role: procedure ))
 
 GBrain supports three deployment shapes. Pick the right one before installing,
 because picking wrong creates contention or duplicate work that's painful to
@@ -92,11 +92,11 @@
 >
 >  Which fits?"
 
-### If the user picks 1 (single brain) — proceed to Phase A
+### If the user picks 1 (single brain) — proceed to Phase A (( inert ))
 
 Continue with the existing `gbrain init --supabase` / `--pglite` setup below.
 
-### If the user picks 2 (cross-machine thin client)
+### If the user picks 2 (cross-machine thin client) (( inert ))
 
 1. **Confirm a host already exists.** Ask: "Is the remote `gbrain serve --http`
    already running on the host machine?" If no, the user needs to set up the
@@ -146,7 +146,7 @@
 already configured this machine. Refusing without `--force` is the correct
 behavior; either accept the existing config or pass `--force` to refresh.
 
-### If the user picks 3 (split-engine per-worktree)
+### If the user picks 3 (split-engine per-worktree) (( inert ))
 
 This shape requires per-worktree wiring that gstack handles, not gbrain
 directly. gbrain's role is just to run a local engine when `GBRAIN_HOME` is
@@ -160,7 +160,7 @@
 If the user has a remote artifact brain (Topology 2 + 3 combined), follow
 the thin-client setup above for the artifact brain instead of Phase A.
 
-## Phase A: Supabase Setup (recommended)
+## Phase A: Supabase Setup (recommended) (( inert, role: procedure ))
 
 Guide the user through creating a Supabase project:
 
@@ -183,7 +183,7 @@
 env as `SUPABASE_ACCESS_TOKEN`. gbrain doesn't store it, you need it for future
 `gbrain doctor` runs. Generate at: https://supabase.com/dashboard/account/tokens
 
-## Phase B: BYO Postgres (alternative)
+## Phase B: BYO Postgres (alternative) (( inert, role: procedure ))
 
 If the user already has Postgres with pgvector:
 
@@ -195,7 +195,7 @@
 the user probably pasted the direct connection (IPv6 only). Guide them to the
 Transaction pooler string instead (see Phase A step 4).
 
-## Phase C: First Import
+## Phase C: First Import (( inert, role: procedure ))
 
 1. **Discover markdown repos.** Scan the environment for git repos with markdown content.
 
@@ -277,7 +277,7 @@
 If no markdown repos are found, create a starter brain with a few template pages
 (a person page, a company page, a concept page) from docs/GBRAIN_RECOMMENDED_SCHEMA.md.
 
-## Phase C.5: One-step autopilot + Minions install (v0.11.1+)
+## Phase C.5: One-step autopilot + Minions install (v0.11.1+) (( inert, role: procedure ))
 
 Run the migration runner once, then install autopilot. Two commands, done:
 
@@ -311,12 +311,12 @@
 register host-specific handlers. Re-run `apply-migrations` after each
 batch.
 
-## Phase D: Brain-First Lookup Protocol
+## Phase D: Brain-First Lookup Protocol (( inert, role: procedure ))
 
 Inject the brain-first lookup protocol into the project's AGENTS.md (or equivalent).
 This replaces grep-based knowledge lookups with structured gbrain queries.
 
-### BEFORE (grep) vs AFTER (gbrain)
+### BEFORE (grep) vs AFTER (gbrain) (( inert ))
 
 | Task | Before (grep) | After (gbrain) |
 |------|---------------|-----------------|
@@ -325,7 +325,7 @@
 | Read a known page | `cat brain/people/pedro.md` | `gbrain get people/pedro` |
 | Find connections | `grep -rl "Brex" brain/ \| xargs grep "Pedro"` | `gbrain query "Pedro Brex relationship"` |
 
-### Lookup sequence (MANDATORY for every entity question)
+### Lookup sequence (MANDATORY for every entity question) (( inert ))
 
 1. `gbrain search "name"` -- keyword match, fast, works without embeddings
 2. `gbrain query "what do we know about name"` -- hybrid search, needs embeddings
@@ -334,7 +334,7 @@
 
 Stop at the first step that gives you what you need. Most lookups resolve at step 1.
 
-### Sync-after-write rule
+### Sync-after-write rule (( inert ))
 
 After creating or updating any brain page in the repo, sync immediately so the
 index stays current:
@@ -346,7 +346,7 @@
 This indexes new/changed files without pulling from git or regenerating embeddings.
 Embeddings can be refreshed later in batch (`gbrain embed --stale`).
 
-### gbrain vs memory_search
+### gbrain vs memory_search (( inert ))
 
 | Layer | What it stores | When to use |
 |-------|---------------|-------------|
@@ -356,7 +356,7 @@
 Both should be checked. gbrain for facts about the world. memory_search for how
 the agent should behave.
 
-### Self-upgrade marker protocol (inject into AGENTS.md)
+### Self-upgrade marker protocol (inject into AGENTS.md) (( inert ))
 
 gbrain keeps itself current by riding invocation frequency: any `gbrain` command
 may print `UPGRADE_AVAILABLE <old> <new>` (or a one-time `JUST_UPGRADED <old>
@@ -366,7 +366,7 @@
 the project's AGENTS.md (or equivalent system context):
 
 ```markdown
-## gbrain self-upgrade
+## gbrain self-upgrade (( inert ))
 
 When any `gbrain` command prints `UPGRADE_AVAILABLE <old> <new>` on stderr, read
 `skills/gbrain-upgrade/SKILL.md` and follow it. It honors `self_upgrade.mode`:
@@ -381,7 +381,7 @@
 autopilot tick apply during quiet hours. Interactive agents rely on the stderr
 marker + this protocol.
 
-## Phase E: Load the Production Agent Guide
+## Phase E: Load the Production Agent Guide (( inert, role: procedure ))
 
 Read `docs/GBRAIN_SKILLPACK.md`. This is the reference architecture for how a
 production agent uses gbrain: the brain-agent loop, entity detection, enrichment
@@ -399,12 +399,12 @@
 schedules. Read it when you're ready to go from 'search works' to 'the brain
 maintains itself.'"
 
-## Phase F: Health Check
+## Phase F: Health Check (( inert, role: procedure ))
 
 Run `gbrain doctor --json` and report the results. Every check should be OK.
 If any check fails, the doctor output tells you exactly what's wrong and how to fix it.
 
-## Error Recovery
+## Error Recovery (( inert ))
 
 **If any gbrain command fails, run `gbrain doctor --json` first.** Report the full
 output. It checks connection, pgvector, RLS, schema version, and embeddings.
@@ -418,7 +418,7 @@
 | No pages found | Query before import | Import files into gbrain first |
 | RLS not enabled | Security gap | Run `gbrain init` again (auto-enables RLS) |
 
-## Phase G: Auto-Update Check (if not already configured)
+## Phase G: Auto-Update Check (if not already configured) (( inert, role: procedure ))
 
 If the user's install did NOT include setting up auto-update checks (e.g., they
 used the manual install path or an older version of the OpenClaw/Hermes paste), offer it:
@@ -433,7 +433,7 @@
 
 If already configured or user declines, skip.
 
-## Phase H: Live Sync Setup (MUST ADD)
+## Phase H: Live Sync Setup (MUST ADD) (( inert, role: procedure ))
 
 The brain repo is the source of truth. If sync doesn't run automatically, the
 vector DB falls behind and gbrain returns stale answers. This phase is not optional.
@@ -470,7 +470,7 @@
 Tell the user: "Live sync is configured. The brain will stay current automatically.
 I'll verify it's working in the next phase."
 
-## Phase I: Full Verification
+## Phase I: Full Verification (( inert, role: procedure ))
 
 Run the full verification runbook to confirm the entire installation is working.
 
@@ -488,7 +488,7 @@
 
 If already configured or user declines, skip.
 
-## Phase J: Cold Start — Populate Your Brain (AUTOMATIC)
+## Phase J: Cold Start — Populate Your Brain (AUTOMATIC) (( inert, role: procedure ))
 
 Setup is done. The brain works. But it's empty. **This is the most important
 moment** — an empty brain is useless. Transition directly to the cold-start
@@ -520,7 +520,7 @@
 → Tell them: "You can run cold-start anytime by asking me to 'fill my brain'
 or 'cold start'."
 
-## Schema State Tracking
+## Schema State Tracking (( inert ))
 
 After presenting the recommended directories (Phase C/E) and the user selects which
 ones to create, write `~/.gbrain/update-state.json` recording:
@@ -533,7 +533,7 @@
 This file enables future upgrades to suggest new schema additions without
 re-suggesting things the user already declined.
 
-## Anti-Patterns
+## Anti-Patterns (( inert, role: prohibitions ))
 
 - **Ending setup without offering cold-start.** An empty brain is useless. Phase J (cold-start) is where setup pays off. Always present the "Ready to populate?" prompt after verification. Skipping this is like installing an app and never logging in.
 - **Asking for the Supabase anon key.** GBrain connects directly to Postgres over the wire protocol, not through the REST API. Only the database connection string is needed.
@@ -564,7 +564,7 @@
 **The output should transition directly into cold-start (Phase J), not end
 with a bullet list.** The bullet list is for when the user defers cold-start.
 
-## Tools Used
+## Tools Used (( inert ))
 
 - `gbrain init --non-interactive --url ...` -- create brain
 - `gbrain import <dir> --no-embed [--workers N]` -- import files
```
