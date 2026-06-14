# Deviation: setup.meri

- Original: `setup/SKILL.md`
- Ported: `setup.meri`
- Tier: 2 (light edits)
- Similarity: 53%
- Lines: 580 -> 582 (+273 / -271)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- shell-block-routed
- preamble-blockquoted

## Metrics
- Sections: 18/31 inert (58% inert ratio)
- Operational inert: 0
- Unclassified inert: 0
- Inert categories: reference-documentation=16, template=1, tools-metadata=1
- Judgment: 10 blocks, 150 lines

### Inert section details
- L21 `How GBrain connects`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L34 `Why Supabase`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L42 `Prerequisites`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L48 `Available init options`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L58 `Phase A.5: Choose Topology (run BEFORE Phase A)`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L82 `If the user picks 1 (single brain) — proceed to Phase A`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L136 `If the user picks 3 (split-engine per-worktree)`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L185 `Phase C: First Import`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L306 `BEFORE (grep) vs AFTER (gbrain)`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L315 `Lookup sequence (MANDATORY for every entity question)`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L336 `gbrain vs memory_search`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L346 `Self-upgrade marker protocol (inject into AGENTS.md)`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L371 `Phase E: Load the Production Agent Guide`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L408 `Phase G: Auto-Update Check (if not already configured)`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L478 `Phase J: Cold Start — Populate Your Brain (AUTOMATIC)`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L510 `Schema State Tracking`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L533 `Output Format`: template — Template/output shape is metadata unless explicit output assertions are authored.
- L555 `Tools Used`: tools-metadata — Tools sections are metadata-mining, not workflow execution.

## Unified diff

```diff
--- original-skills/setup/SKILL.md
+++ skills/setup.meri
@@ -15,23 +15,24 @@
 
 # Setup GBrain
 
-Set up GBrain from scratch. Target: working brain in under 5 minutes.
-
-## Contract
-
-- Setup completes with a working brain verified by `gbrain doctor --json` (all checks OK).
-- The brain-first lookup protocol is injected into the project's AGENTS.md or equivalent.
-- Live sync is configured and verified (a test change pushed and found via search).
-- Schema state is tracked in `~/.gbrain/update-state.json` so future upgrades know what the user adopted or declined.
-- No Supabase anon key is requested; GBrain uses only the database connection string.
-
-## Install (if not already installed)
+> Set up GBrain from scratch. Target: working brain in under 5 minutes.
+
+## Contract (( role: procedure ))
+
+!!! checklist (( ai-autonomy ))
+- [ ] Setup completes with a working brain verified by `gbrain doctor --json` (all checks OK).
+- [ ] The brain-first lookup protocol is injected into the project's AGENTS.md or equivalent.
+- [ ] Live sync is configured and verified (a test change pushed and found via search).
+- [ ] Schema state is tracked in `~/.gbrain/update-state.json` so future upgrades know what the user adopted or declined.
+- [ ] No Supabase anon key is requested; GBrain uses only the database connection string.
+
+## Install (if not already installed) (( role: procedure ))
 
 ```bash
 bun add github:garrytan/gbrain
 ```
 
-## How GBrain connects
+## How GBrain connects (( inert ))
 
 GBrain connects directly to Postgres over the wire protocol. NOT through the
 Supabase REST API. You need the **database connection string** (a `postgresql://` URI),
@@ -44,7 +45,7 @@
 
 **Do NOT ask for the Supabase anon key.** GBrain doesn't use it.
 
-## Why Supabase
+## Why Supabase (( inert ))
 
 Supabase gives you managed Postgres + pgvector (vector search built in) for $25/mo:
 - 8GB database + 100GB storage on Pro tier
@@ -52,13 +53,13 @@
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
@@ -68,7 +69,7 @@
 There is no `--local`, `--sqlite`, or offline mode. GBrain requires Postgres + pgvector
 (local PGLite or remote Supabase / self-hosted).
 
-## Phase A.5: Choose Topology (run BEFORE Phase A)
+## Phase A.5: Choose Topology (run BEFORE Phase A) (( inert, role: procedure ))
 
 GBrain supports three deployment shapes. Pick the right one before installing,
 because picking wrong creates contention or duplicate work that's painful to
@@ -92,110 +93,110 @@
 >
 >  Which fits?"
 
-### If the user picks 1 (single brain) — proceed to Phase A
+### If the user picks 1 (single brain) — proceed to Phase A (( inert ))
 
 Continue with the existing `gbrain init --supabase` / `--pglite` setup below.
 
-### If the user picks 2 (cross-machine thin client)
-
-1. **Confirm a host already exists.** Ask: "Is the remote `gbrain serve --http`
-   already running on the host machine?" If no, the user needs to set up the
-   host first (Phases A-C on the host, then `gbrain serve --http`). Don't try
-   to run init on this machine until the host is up.
-
-2. **Get OAuth credentials from the host operator.** Ask the user to run
-   on the host:
-   ```bash
-   gbrain auth register-client <name> \
-     --grant-types client_credentials \
-     --scopes read,write,admin
-   ```
-   The `admin` scope is required because `gbrain remote ping` and
-   `gbrain remote doctor` (Tier B convenience commands) call MCP ops with
-   `admin` scope. `read,write` alone breaks ping/doctor.
-
-3. **Run thin-client init on this machine:**
-   ```bash
-   gbrain init --mcp-only \
-     --issuer-url https://<host>:<port> \
-     --mcp-url https://<host>:<port>/mcp \
-     --oauth-client-id <id> \
-     --oauth-client-secret <secret>
-   ```
-   Or set `GBRAIN_REMOTE_CLIENT_SECRET` env var instead of the flag (preferred
-   for headless / scripted setup). Pre-flight runs three smoke probes; any
-   failure surfaces an actionable error.
-
-4. **Configure your agent's MCP client.** Add a server entry pointing at
-   `<mcp_url>` with the bearer token. See `docs/mcp/CLAUDE_DESKTOP.md`,
-   `docs/mcp/CLAUDE_CODE.md`, etc. for per-client snippets.
-
-5. **Verify with `gbrain doctor`.** Thin-client doctor runs OAuth discovery,
-   token round-trip, and MCP smoke against the host. Should report
-   `mode: thin-client` with all checks green.
-
-6. **Skip Phases B, C, C.5, and H entirely.** They're for local engines.
-   The host's autopilot handles sync/extract/embed. Thin clients consume
-   only.
-
-7. **Continue to Phase D (brain-first lookup).** It works identically over
-   MCP — the agent uses the same brain-ops skill to query/search/get_page,
-   they just round-trip through the host's `gbrain serve --http`.
-
-If init reports "thin-client config already present", a previous setup
-already configured this machine. Refusing without `--force` is the correct
-behavior; either accept the existing config or pass `--force` to refresh.
-
-### If the user picks 3 (split-engine per-worktree)
-
+### If the user picks 2 (cross-machine thin client) (( role: procedure ))
+
+use judgment to follow the If the user picks 2 (cross-machine thin client) guidance:
+  1. **Confirm a host already exists.** Ask: "Is the remote `gbrain serve --http`
+     already running on the host machine?" If no, the user needs to set up the
+     host first (Phases A-C on the host, then `gbrain serve --http`). Don't try
+     to run init on this machine until the host is up.
+  
+  2. **Get OAuth credentials from the host operator.** Ask the user to run
+     on the host:
+     ```bash
+     gbrain auth register-client <name> \
+       --grant-types client_credentials \
+       --scopes read,write,admin
+     ```
+     The `admin` scope is required because `gbrain remote ping` and
+     `gbrain remote doctor` (Tier B convenience commands) call MCP ops with
+     `admin` scope. `read,write` alone breaks ping/doctor.
+  
+  3. **Run thin-client init on this machine:**
+     ```bash
+     gbrain init --mcp-only \
+       --issuer-url https://<host>:<port> \
+       --mcp-url https://<host>:<port>/mcp \
+       --oauth-client-id <id> \
+       --oauth-client-secret <secret>
+     ```
+     Or set `GBRAIN_REMOTE_CLIENT_SECRET` env var instead of the flag (preferred
+     for headless / scripted setup). Pre-flight runs three smoke probes; any
+     failure surfaces an actionable error.
+  
+  4. **Configure your agent's MCP client.** Add a server entry pointing at
+     `<mcp_url>` with the bearer token. See `docs/mcp/CLAUDE_DESKTOP.md`,
+     `docs/mcp/CLAUDE_CODE.md`, etc. for per-client snippets.
+  
+  5. **Verify with `gbrain doctor`.** Thin-client doctor runs OAuth discovery,
+     token round-trip, and MCP smoke against the host. Should report
+     `mode: thin-client` with all checks green.
+  
+  6. **Skip Phases B, C, C.5, and H entirely.** They're for local engines.
+     The host's autopilot handles sync/extract/embed. Thin clients consume
+     only.
+  
+  7. **Continue to Phase D (brain-first lookup).** It works identically over
+     MCP — the agent uses the same brain-ops skill to query/search/get_page,
+     they just round-trip through the host's `gbrain serve --http`.
+  
+  If init reports "thin-client config already present", a previous setup
+  already configured this machine. Refusing without `--force` is the correct
+  behavior; either accept the existing config or pass `--force` to refresh.
+### If the user picks 3 (split-engine per-worktree) (( inert ))
+  
 This shape requires per-worktree wiring that gstack handles, not gbrain
 directly. gbrain's role is just to run a local engine when `GBRAIN_HOME` is
 set — that already works.
-
+  
 Point the user at `docs/architecture/topologies.md` (the Topology 3 section)
 for the wiring recipe, then continue with Phase A as normal — `gbrain init`
 on this machine sets up the artifact brain (the "default" home). The
 per-worktree code engines are configured per-worktree as gstack creates them.
-
+  
 If the user has a remote artifact brain (Topology 2 + 3 combined), follow
 the thin-client setup above for the artifact brain instead of Phase A.
 
-## Phase A: Supabase Setup (recommended)
-
-Guide the user through creating a Supabase project:
-
-1. "Go to https://supabase.com and sign up or log in."
-2. "Click 'New Project' in the top left."
-   - Name: `gbrain`
-   - Region: pick the one closest to you
-   - Database password: generate a strong one and save it
-3. "Wait about 2 minutes for the project to initialize."
-4. "Find the connection string: click **Connect** in the top navigation bar,
-   then **Connection String** > **Transaction pooler**, and copy the string
-   (port 6543)."
-5. Initialize gbrain:
-   ```bash
-   gbrain init --non-interactive --url "postgresql://postgres.[ref]:[password]@aws-0-[region].pooler.supabase.com:6543/postgres"
-   ```
-6. Verify: `gbrain doctor --json`
-
-**OpenClaw/Hermes agent instructions:** Store the Supabase access token in your persistent
-env as `SUPABASE_ACCESS_TOKEN`. gbrain doesn't store it, you need it for future
-`gbrain doctor` runs. Generate at: https://supabase.com/dashboard/account/tokens
-
-## Phase B: BYO Postgres (alternative)
-
-If the user already has Postgres with pgvector:
-
-1. Get the connection string from the user.
-2. Run: `gbrain init --non-interactive --url "<connection_string>"`
-3. Verify: `gbrain doctor --json`
-
-If the connection fails with ECONNREFUSED and the URL contains `supabase.co`,
-the user probably pasted the direct connection (IPv6 only). Guide them to the
-Transaction pooler string instead (see Phase A step 4).
-
-## Phase C: First Import
+## Phase A: Supabase Setup (recommended) (( role: procedure ))
+
+use judgment to follow the Phase A: Supabase Setup (recommended) guidance:
+  Guide the user through creating a Supabase project:
+  
+  1. "Go to https://supabase.com and sign up or log in."
+  2. "Click 'New Project' in the top left."
+  item: Name: `gbrain`
+  item: Region: pick the one closest to you
+  item: Database password: generate a strong one and save it
+  3. "Wait about 2 minutes for the project to initialize."
+  4. "Find the connection string: click **Connect** in the top navigation bar,
+     then **Connection String** > **Transaction pooler**, and copy the string
+     (port 6543)."
+  5. Initialize gbrain:
+     ```bash
+     gbrain init --non-interactive --url "postgresql://postgres.[ref]:[password]@aws-0-[region].pooler.supabase.com:6543/postgres"
+     ```
+  6. Verify: `gbrain doctor --json`
+  
+  **OpenClaw/Hermes agent instructions:** Store the Supabase access token in your persistent
+  env as `SUPABASE_ACCESS_TOKEN`. gbrain doesn't store it, you need it for future
+  `gbrain doctor` runs. Generate at: https://supabase.com/dashboard/account/tokens
+## Phase B: BYO Postgres (alternative) (( role: procedure ))
+
+use judgment to follow the Phase B: BYO Postgres (alternative) guidance:
+  If the user already has Postgres with pgvector:
+  
+  1. Get the connection string from the user.
+  2. Run: `gbrain init --non-interactive --url "<connection_string>"`
+  3. Verify: `gbrain doctor --json`
+  
+  If the connection fails with ECONNREFUSED and the URL contains `supabase.co`,
+  the user probably pasted the direct connection (IPv6 only). Guide them to the
+  Transaction pooler string instead (see Phase A step 4).
+## Phase C: First Import (( inert, role: procedure ))
 
 1. **Discover markdown repos.** Scan the environment for git repos with markdown content.
 
@@ -277,96 +278,96 @@
 If no markdown repos are found, create a starter brain with a few template pages
 (a person page, a company page, a concept page) from docs/GBRAIN_RECOMMENDED_SCHEMA.md.
 
-## Phase C.5: One-step autopilot + Minions install (v0.11.1+)
-
-Run the migration runner once, then install autopilot. Two commands, done:
-
-```bash
-gbrain apply-migrations --yes       # applies any pending migrations; idempotent on healthy installs
-gbrain autopilot --install          # supervises itself + forks the Minions worker; env-aware
-```
-
-What `gbrain autopilot --install` does:
-
-- On **macOS**: writes a launchd plist at `~/Library/LaunchAgents/com.gbrain.autopilot.plist`.
-- On **Linux with systemd**: writes `~/.config/systemd/user/gbrain-autopilot.service`
-  with `Restart=on-failure`.
-- On **ephemeral containers** (Render / Railway / Fly / Docker): writes
-  `~/.gbrain/start-autopilot.sh` and prints the one-line your agent's
-  bootstrap should source to launch autopilot on every container start.
-  Auto-injects into OpenClaw's `hooks/bootstrap/ensure-services.sh` if
-  detected (use `--no-inject` to opt out).
-- On **Linux without systemd**: installs a crontab entry (every 5 min).
-
-Autopilot then supervises the Minions worker as a child process. Users get
-sync + extract + embed + backlinks + durable Postgres-backed job processing
-from ONE install step. No separate `gbrain jobs work` daemon to manage.
-
-On PGLite, autopilot runs inline (PGLite's exclusive file lock blocks a
-separate worker process). Everything else still works.
-
-If `apply-migrations` prints "N host-specific items need your agent's
-attention," read `~/.gbrain/migrations/pending-host-work.jsonl` + walk
-`skills/migrations/v0.11.0.md` + `docs/guides/plugin-handlers.md` to
-register host-specific handlers. Re-run `apply-migrations` after each
-batch.
-
-## Phase D: Brain-First Lookup Protocol
-
-Inject the brain-first lookup protocol into the project's AGENTS.md (or equivalent).
-This replaces grep-based knowledge lookups with structured gbrain queries.
-
-### BEFORE (grep) vs AFTER (gbrain)
-
+## Phase C.5: One-step autopilot + Minions install (v0.11.1+) (( role: procedure ))
+
+use judgment to follow the Phase C.5: One-step autopilot + Minions install (v0.11.1+) guidance:
+  Run the migration runner once, then install autopilot. Two commands, done:
+  
+  ```bash
+  gbrain apply-migrations --yes       # applies any pending migrations; idempotent on healthy installs
+  gbrain autopilot --install          # supervises itself + forks the Minions worker; env-aware
+  ```
+  
+  What `gbrain autopilot --install` does:
+  
+  item: On **macOS**: writes a launchd plist at `~/Library/LaunchAgents/com.gbrain.autopilot.plist`.
+  item: On **Linux with systemd**: writes `~/.config/systemd/user/gbrain-autopilot.service`
+    with `Restart=on-failure`.
+  item: On **ephemeral containers** (Render / Railway / Fly / Docker): writes
+    `~/.gbrain/start-autopilot.sh` and prints the one-line your agent's
+    bootstrap should source to launch autopilot on every container start.
+    Auto-injects into OpenClaw's `hooks/bootstrap/ensure-services.sh` if
+    detected (use `--no-inject` to opt out).
+  item: On **Linux without systemd**: installs a crontab entry (every 5 min).
+  
+  Autopilot then supervises the Minions worker as a child process. Users get
+  sync + extract + embed + backlinks + durable Postgres-backed job processing
+  from ONE install step. No separate `gbrain jobs work` daemon to manage.
+  
+  On PGLite, autopilot runs inline (PGLite's exclusive file lock blocks a
+  separate worker process). Everything else still works.
+  
+  If `apply-migrations` prints "N host-specific items need your agent's
+  attention," read `~/.gbrain/migrations/pending-host-work.jsonl` + walk
+  `skills/migrations/v0.11.0.md` + `docs/guides/plugin-handlers.md` to
+  register host-specific handlers. Re-run `apply-migrations` after each
+  batch.
+## Phase D: Brain-First Lookup Protocol (( role: procedure ))
+
+use judgment to follow the Phase D: Brain-First Lookup Protocol guidance:
+  Inject the brain-first lookup protocol into the project's AGENTS.md (or equivalent).
+  This replaces grep-based knowledge lookups with structured gbrain queries.
+### BEFORE (grep) vs AFTER (gbrain) (( inert ))
+  
 | Task | Before (grep) | After (gbrain) |
 |------|---------------|-----------------|
 | Find a person | `grep -r "Pedro" brain/` | `gbrain search "Pedro"` |
 | Understand a topic | `grep -rl "deal" brain/ \| head -5 && cat ...` | `gbrain query "what's the status of the deal"` |
 | Read a known page | `cat brain/people/pedro.md` | `gbrain get people/pedro` |
 | Find connections | `grep -rl "Brex" brain/ \| xargs grep "Pedro"` | `gbrain query "Pedro Brex relationship"` |
-
-### Lookup sequence (MANDATORY for every entity question)
-
+  
+### Lookup sequence (MANDATORY for every entity question) (( inert ))
+  
 1. `gbrain search "name"` -- keyword match, fast, works without embeddings
 2. `gbrain query "what do we know about name"` -- hybrid search, needs embeddings
 3. `gbrain get <slug>` -- direct page read when you know the slug from steps 1-2
 4. `grep` fallback -- only if gbrain returns zero results AND the file may exist outside the indexed brain
-
+  
 Stop at the first step that gives you what you need. Most lookups resolve at step 1.
-
-### Sync-after-write rule
-
-After creating or updating any brain page in the repo, sync immediately so the
-index stays current:
-
-```bash
-gbrain sync --no-pull --no-embed
-```
-
-This indexes new/changed files without pulling from git or regenerating embeddings.
-Embeddings can be refreshed later in batch (`gbrain embed --stale`).
-
-### gbrain vs memory_search
-
+  
+### Sync-after-write rule (( role: procedure ))
+  
+use judgment to follow the Sync-after-write rule guidance:
+  After creating or updating any brain page in the repo, sync immediately so the
+  index stays current:
+  
+  ```bash
+  gbrain sync --no-pull --no-embed
+  ```
+  
+  This indexes new/changed files without pulling from git or regenerating embeddings.
+  Embeddings can be refreshed later in batch (`gbrain embed --stale`).
+### gbrain vs memory_search (( inert ))
+  
 | Layer | What it stores | When to use |
 |-------|---------------|-------------|
 | **gbrain** | World knowledge: people, companies, deals, meetings, concepts, media | "Who is Pedro?", "What happened at the board meeting?" |
 | **memory_search** | Agent operational state: preferences, decisions, session context | "How does the user like formatting?", "What did we decide about X?" |
-
+  
 Both should be checked. gbrain for facts about the world. memory_search for how
 the agent should behave.
-
-### Self-upgrade marker protocol (inject into AGENTS.md)
-
+  
+### Self-upgrade marker protocol (inject into AGENTS.md) (( inert ))
+  
 gbrain keeps itself current by riding invocation frequency: any `gbrain` command
 may print `UPGRADE_AVAILABLE <old> <new>` (or a one-time `JUST_UPGRADED <old>
 <new>`) on **stderr**. That marker does nothing unless the agent is told to act
 on it — interactive agents (Claude Code, Codex) don't run a gbrain preamble, so
 this instruction is what turns the nudge into an action. Inject this block into
 the project's AGENTS.md (or equivalent system context):
-
+  
 ```markdown
-## gbrain self-upgrade
+## gbrain self-upgrade (( inert ))
 
 When any `gbrain` command prints `UPGRADE_AVAILABLE <old> <new>` on stderr, read
 `skills/gbrain-upgrade/SKILL.md` and follow it. It honors `self_upgrade.mode`:
@@ -381,7 +382,7 @@
 autopilot tick apply during quiet hours. Interactive agents rely on the stderr
 marker + this protocol.
 
-## Phase E: Load the Production Agent Guide
+## Phase E: Load the Production Agent Guide (( inert, role: procedure ))
 
 Read `docs/GBRAIN_SKILLPACK.md`. This is the reference architecture for how a
 production agent uses gbrain: the brain-agent loop, entity detection, enrichment
@@ -399,26 +400,26 @@
 schedules. Read it when you're ready to go from 'search works' to 'the brain
 maintains itself.'"
 
-## Phase F: Health Check
-
-Run `gbrain doctor --json` and report the results. Every check should be OK.
-If any check fails, the doctor output tells you exactly what's wrong and how to fix it.
-
-## Error Recovery
-
-**If any gbrain command fails, run `gbrain doctor --json` first.** Report the full
-output. It checks connection, pgvector, RLS, schema version, and embeddings.
-
-| What You See | Why | Fix |
-|---|---|---|
-| Connection refused | Supabase project paused, IPv6, or wrong URL | Use Transaction pooler (port 6543), or supabase.com/dashboard > Restore |
-| Password authentication failed | Wrong password | Project Settings > Database > Reset password |
-| pgvector not available | Extension not enabled | Run `CREATE EXTENSION vector;` in SQL Editor |
-| OpenAI key invalid | Expired or wrong key | platform.openai.com/api-keys > Create new |
-| No pages found | Query before import | Import files into gbrain first |
-| RLS not enabled | Security gap | Run `gbrain init` again (auto-enables RLS) |
-
-## Phase G: Auto-Update Check (if not already configured)
+## Phase F: Health Check (( role: procedure ))
+
+use judgment to follow the Phase F: Health Check guidance:
+  Run `gbrain doctor --json` and report the results. Every check should be OK.
+  If any check fails, the doctor output tells you exactly what's wrong and how to fix it.
+## Error Recovery (( role: procedure ))
+
+use judgment to follow the Error Recovery guidance:
+  **If any gbrain command fails, run `gbrain doctor --json` first.** Report the full
+  output. It checks connection, pgvector, RLS, schema version, and embeddings.
+  
+  | What You See | Why | Fix |
+  |---|---|---|
+  | Connection refused | Supabase project paused, IPv6, or wrong URL | Use Transaction pooler (port 6543), or supabase.com/dashboard > Restore |
+  | Password authentication failed | Wrong password | Project Settings > Database > Reset password |
+  | pgvector not available | Extension not enabled | Run `CREATE EXTENSION vector;` in SQL Editor |
+  | OpenAI key invalid | Expired or wrong key | platform.openai.com/api-keys > Create new |
+  | No pages found | Query before import | Import files into gbrain first |
+  | RLS not enabled | Security gap | Run `gbrain init` again (auto-enables RLS) |
+## Phase G: Auto-Update Check (if not already configured) (( inert, role: procedure ))
 
 If the user's install did NOT include setting up auto-update checks (e.g., they
 used the manual install path or an older version of the OpenClaw/Hermes paste), offer it:
@@ -433,62 +434,62 @@
 
 If already configured or user declines, skip.
 
-## Phase H: Live Sync Setup (MUST ADD)
-
-The brain repo is the source of truth. If sync doesn't run automatically, the
-vector DB falls behind and gbrain returns stale answers. This phase is not optional.
-
-Read `docs/GBRAIN_SKILLPACK.md` Section 18 for the full reference. Key points:
-
-1. **Check the connection first.** GBrain is tuned for the Supabase **Transaction
-   pooler** (port 6543): it auto-disables prepared statements there and routes
-   migrations, DDL, and sync transactions to a separate direct connection. That
-   derived direct connection (`db.<ref>.supabase.co:5432`) is IPv6-only, so on an
-   IPv4-only host, reads work but sync silently skips pages. Fix by making the
-   direct connection reachable: set `GBRAIN_DIRECT_DATABASE_URL` to the **Session
-   pooler** string (port 5432 on the `pooler.supabase.com` host, IPv4), or enable
-   Supabase's IPv4 add-on.
-
-2. **Set up automatic sync.** Choose the approach that fits your environment:
-   - **Cron** (recommended for agents): register a cron every 5-30 minutes:
-     `gbrain sync --repo /data/brain && gbrain embed --stale`
-   - **Watch mode**: `gbrain sync --watch --repo /data/brain` under a process
-     manager. Pair with a cron fallback (watch exits after 5 consecutive failures).
-   - **Webhook or git hook**: if available in your environment.
-
-3. **Verify sync works.** Don't just check that the command ran. Check that it
-   worked:
-   - `gbrain stats` should show page count close to syncable file count in the repo.
-   - If page count is way too low, the direct connection is unreachable on IPv4 and
-     sync is silently skipping pages (see point 1).
-   - Push a test change and confirm it appears in `gbrain search`.
-
-4. **Chain sync + embed.** Always run both: `gbrain sync --repo <path> && gbrain
-   embed --stale`. For small syncs, embeddings are generated inline. The `embed
-   --stale` is a safety net for any stale chunks.
-
-Tell the user: "Live sync is configured. The brain will stay current automatically.
-I'll verify it's working in the next phase."
-
-## Phase I: Full Verification
-
-Run the full verification runbook to confirm the entire installation is working.
-
-1. Read `docs/GBRAIN_VERIFY.md`
-2. Execute each check in order
-3. Report results to the user
-4. Fix any failures before declaring setup complete
-
-Every check in the runbook should pass. The most important one is check 4 (live
-sync actually works): push a change, wait for sync, search for the corrected text.
-"Sync ran" is not the same as "sync worked."
-
-Tell the user: "I've verified the full GBrain installation. Here's the status of
-each check: [list results]. Everything is working / [specific item] needs attention."
-
-If already configured or user declines, skip.
-
-## Phase J: Cold Start — Populate Your Brain (AUTOMATIC)
+## Phase H: Live Sync Setup (MUST ADD) (( role: procedure ))
+
+use judgment to follow the Phase H: Live Sync Setup (MUST ADD) guidance:
+  The brain repo is the source of truth. If sync doesn't run automatically, the
+  vector DB falls behind and gbrain returns stale answers. This phase is not optional.
+  
+  Read `docs/GBRAIN_SKILLPACK.md` Section 18 for the full reference. Key points:
+  
+  1. **Check the connection first.** GBrain is tuned for the Supabase **Transaction
+     pooler** (port 6543): it auto-disables prepared statements there and routes
+     migrations, DDL, and sync transactions to a separate direct connection. That
+     derived direct connection (`db.<ref>.supabase.co:5432`) is IPv6-only, so on an
+     IPv4-only host, reads work but sync silently skips pages. Fix by making the
+     direct connection reachable: set `GBRAIN_DIRECT_DATABASE_URL` to the **Session
+     pooler** string (port 5432 on the `pooler.supabase.com` host, IPv4), or enable
+     Supabase's IPv4 add-on.
+  
+  2. **Set up automatic sync.** Choose the approach that fits your environment:
+  item: **Cron** (recommended for agents): register a cron every 5-30 minutes:
+       `gbrain sync --repo /data/brain && gbrain embed --stale`
+  item: **Watch mode**: `gbrain sync --watch --repo /data/brain` under a process
+       manager. Pair with a cron fallback (watch exits after 5 consecutive failures).
+  item: **Webhook or git hook**: if available in your environment.
+  
+  3. **Verify sync works.** Don't just check that the command ran. Check that it
+     worked:
+  item: `gbrain stats` should show page count close to syncable file count in the repo.
+  item: If page count is way too low, the direct connection is unreachable on IPv4 and
+       sync is silently skipping pages (see point 1).
+  item: Push a test change and confirm it appears in `gbrain search`.
+  
+  4. **Chain sync + embed.** Always run both: `gbrain sync --repo <path> && gbrain
+     embed --stale`. For small syncs, embeddings are generated inline. The `embed
+     --stale` is a safety net for any stale chunks.
+  
+  Tell the user: "Live sync is configured. The brain will stay current automatically.
+  I'll verify it's working in the next phase."
+## Phase I: Full Verification (( role: procedure ))
+
+use judgment to follow the Phase I: Full Verification guidance:
+  Run the full verification runbook to confirm the entire installation is working.
+  
+  1. Read `docs/GBRAIN_VERIFY.md`
+  2. Execute each check in order
+  3. Report results to the user
+  4. Fix any failures before declaring setup complete
+  
+  Every check in the runbook should pass. The most important one is check 4 (live
+  sync actually works): push a change, wait for sync, search for the corrected text.
+  "Sync ran" is not the same as "sync worked."
+  
+  Tell the user: "I've verified the full GBrain installation. Here's the status of
+  each check: [list results]. Everything is working / [specific item] needs attention."
+  
+  If already configured or user declines, skip.
+## Phase J: Cold Start — Populate Your Brain (AUTOMATIC) (( inert, role: procedure ))
 
 Setup is done. The brain works. But it's empty. **This is the most important
 moment** — an empty brain is useless. Transition directly to the cold-start
@@ -520,7 +521,7 @@
 → Tell them: "You can run cold-start anytime by asking me to 'fill my brain'
 or 'cold start'."
 
-## Schema State Tracking
+## Schema State Tracking (( inert ))
 
 After presenting the recommended directories (Phase C/E) and the user selects which
 ones to create, write `~/.gbrain/update-state.json` recording:
@@ -533,14 +534,15 @@
 This file enables future upgrades to suggest new schema additions without
 re-suggesting things the user already declined.
 
-## Anti-Patterns
-
-- **Ending setup without offering cold-start.** An empty brain is useless. Phase J (cold-start) is where setup pays off. Always present the "Ready to populate?" prompt after verification. Skipping this is like installing an app and never logging in.
-- **Asking for the Supabase anon key.** GBrain connects directly to Postgres over the wire protocol, not through the REST API. Only the database connection string is needed.
-- **Skipping live sync setup.** If sync doesn't run automatically, the vector DB falls behind and search returns stale answers. Phase H is not optional.
-- **Declaring setup complete without verification.** "The command ran" is not the same as "it worked." Push a test change, wait for sync, search for the corrected text.
-- **Leaving the direct connection unreachable on IPv4.** GBrain uses the Transaction pooler (port 6543) for reads and a derived direct connection (`db.<ref>.supabase.co:5432`, IPv6-only) for migrations, DDL, and sync transactions. On an IPv4-only host, reads work but sync silently skips pages. Set `GBRAIN_DIRECT_DATABASE_URL` to the Session pooler string (port 5432, IPv4), or enable the IPv4 add-on.
-- **Importing without proving search.** The magical moment is the user seeing search find things grep couldn't. Don't skip it.
+## Anti-Patterns (( role: procedure ))
+
+!!! checklist (( ai-autonomy ))
+- [ ] **Ending setup without offering cold-start.** An empty brain is useless. Phase J (cold-start) is where setup pays off. Always present the "Ready to populate?" prompt after verification. Skipping this is like installing an app and never logging in.
+- [ ] **Asking for the Supabase anon key.** GBrain connects directly to Postgres over the wire protocol, not through the REST API. Only the database connection string is needed.
+- [ ] **Skipping live sync setup.** If sync doesn't run automatically, the vector DB falls behind and search returns stale answers. Phase H is not optional.
+- [ ] **Declaring setup complete without verification.** "The command ran" is not the same as "it worked." Push a test change, wait for sync, search for the corrected text.
+- [ ] **Leaving the direct connection unreachable on IPv4.** GBrain uses the Transaction pooler (port 6543) for reads and a derived direct connection (`db.<ref>.supabase.co:5432`, IPv6-only) for migrations, DDL, and sync transactions. On an IPv4-only host, reads work but sync silently skips pages. Set `GBRAIN_DIRECT_DATABASE_URL` to the Session pooler string (port 5432, IPv4), or enable the IPv4 add-on.
+- [ ] **Importing without proving search.** The magical moment is the user seeing search find things grep couldn't. Don't skip it.
 
 ## Output Format
 
@@ -566,15 +568,15 @@
 
 ## Tools Used
 
-- `gbrain init --non-interactive --url ...` -- create brain
-- `gbrain import <dir> --no-embed [--workers N]` -- import files
-- `gbrain search <query>` -- search brain
-- `gbrain doctor --json` -- health check
-- `gbrain check-update --json` -- check for updates
-- `gbrain embed refresh` -- generate embeddings
-- `gbrain embed --stale` -- backfill missing embeddings
-- `gbrain sync --repo <path>` -- one-shot sync from brain repo
-- `gbrain sync --watch --repo <path>` -- continuous sync polling
-- `gbrain config get sync.last_run` -- check last sync timestamp
-- `gbrain stats` -- page count + embed coverage
-
+- Create brain with `gbrain init --non-interactive --url ...` (shell.run)
+- Import files with `gbrain import <dir> --no-embed [--workers N]` (shell.run)
+- Search brain with `gbrain search <query>` (shell.run)
+- Health check with `gbrain doctor --json` (shell.run)
+- Check updates with `gbrain check-update --json` (shell.run)
+- Generate embeddings with `gbrain embed refresh` (shell.run)
+- Backfill missing embeddings with `gbrain embed --stale` (shell.run)
+- One-shot repo sync with `gbrain sync --repo <path>` (shell.run)
+- Continuous sync polling with `gbrain sync --watch --repo <path>` (shell.run)
+- Check last sync timestamp with `gbrain config get sync.last_run` (shell.run)
+- Page count and embed coverage with `gbrain stats` (shell.run)
+
```
