# Deviation: setup.meri

- Original: `setup/SKILL.md`
- Ported: `setup.meri`
- Tier: 2 (light edits)
- Similarity: 66%
- Lines: 580 -> 696 (+276 / -160)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- shell-block-routed
- preamble-blockquoted
- inert-section-added

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L93 `If the user picks 1 (single brain) — proceed to Phase A`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L647 `Output Format`: template - Template/output shape is metadata unless explicit output assertions are authored.
- L669 `Tools Used`: tools-metadata - Tools sections are metadata-mining, not workflow execution.

## Metrics
- Sections inert total: 11/29 (38% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert categories: reference-documentation=9, template=1, tools-metadata=1
- Judgment: 17 blocks, 0 lines

### Inert section details
- L21 `How GBrain connects`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L53 `Available init options`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L93 `If the user picks 1 (single brain) — proceed to Phase A`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L97 `If the user picks 2 (cross-machine thin client)`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L156 `If the user picks 3 (split-engine per-worktree)`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L374 `Lookup sequence (MANDATORY for every entity question)`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L405 `gbrain vs memory_search`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L479 `Error Recovery`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L618 `Schema State Tracking`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L647 `Output Format`: template — Template/output shape is metadata unless explicit output assertions are authored.
- L669 `Tools Used`: tools-metadata — Tools sections are metadata-mining, not workflow execution.

## Unified diff

```diff
--- original-skills/setup/SKILL.md
+++ skills/setup.meri
@@ -15,9 +15,10 @@
 
 # Setup GBrain
 
-Set up GBrain from scratch. Target: working brain in under 5 minutes.
-
-## Contract
+> Set up GBrain from scratch. Target: working brain in under 5 minutes.
+
+## Contract (( role: procedure ))
+use judgment to follow the Contract guidance:
 
 - Setup completes with a working brain verified by `gbrain doctor --json` (all checks OK).
 - The brain-first lookup protocol is injected into the project's AGENTS.md or equivalent.
@@ -31,11 +32,7 @@
 bun add github:garrytan/gbrain
 ```
 
-## How GBrain connects
-
-GBrain connects directly to Postgres over the wire protocol. NOT through the
-Supabase REST API. You need the **database connection string** (a `postgresql://` URI),
-not the project URL or anon key. The password is embedded in the connection string.
+## How GBrain connects (( inert ))
 
 Use the **Transaction pooler** connection string (port 6543), not the direct
 connection (port 5432). The direct hostname resolves to IPv6 only, which many
@@ -44,7 +41,15 @@
 
 **Do NOT ask for the Supabase anon key.** GBrain doesn't use it.
 
+
+### How GBrain connects — steps
+
+GBrain connects directly to Postgres over the wire protocol. NOT through the
+Supabase REST API. You need the database connection string (a `postgresql://` URI),
+not the project URL or anon key. The password is embedded in the connection string.
+
 ## Why Supabase
+use judgment to follow the Why Supabase guidance:
 
 Supabase gives you managed Postgres + pgvector (vector search built in) for $25/mo:
 - 8GB database + 100GB storage on Pro tier
@@ -52,23 +57,30 @@
 - pgvector pre-installed, just works
 - Alternative: any Postgres with pgvector extension (self-hosted, Neon, Railway, etc.)
 
-## Prerequisites
+## Prerequisites (( role: procedure ))
+use judgment to follow the Prerequisites guidance:
 
 - A Supabase account (Pro tier recommended, $25/mo) OR any Postgres with pgvector
 - An OpenAI API key (for semantic search embeddings, ~$4-5 for 7,500 pages)
 - A git-backed markdown knowledge base (or start fresh)
 
-## Available init options
+## Available init options (( inert ))
+
+There is no `--local`, `--sqlite`, or offline mode. GBrain requires Postgres + pgvector
+(local PGLite or remote Supabase / self-hosted).
+
+
+### Available init options — steps
 
 - `gbrain init --supabase` -- interactive wizard (prompts for connection string)
 - `gbrain init --url <connection_string>` -- direct, no prompts
 - `gbrain init --non-interactive --url <connection_string>` -- for scripts/agents
 - `gbrain doctor --json` -- health check after init
 
-There is no `--local`, `--sqlite`, or offline mode. GBrain requires Postgres + pgvector
-(local PGLite or remote Supabase / self-hosted).
-
-## Phase A.5: Choose Topology (run BEFORE Phase A)
+## Phase A.5: Choose Topology (run BEFORE Phase A) (( inert, role: procedure ))
+
+
+### Phase A.5: Choose Topology (run BEFORE Phase A) — steps
 
 GBrain supports three deployment shapes. Pick the right one before installing,
 because picking wrong creates contention or duplicate work that's painful to
@@ -92,29 +104,55 @@
 >
 >  Which fits?"
 
-### If the user picks 1 (single brain) — proceed to Phase A
+### If the user picks 1 (single brain) — proceed to Phase A (( inert ))
 
 Continue with the existing `gbrain init --supabase` / `--pglite` setup below.
 
-### If the user picks 2 (cross-machine thin client)
+### If the user picks 2 (cross-machine thin client) (( inert ))
 
 1. **Confirm a host already exists.** Ask: "Is the remote `gbrain serve --http`
    already running on the host machine?" If no, the user needs to set up the
    host first (Phases A-C on the host, then `gbrain serve --http`). Don't try
    to run init on this machine until the host is up.
 
-2. **Get OAuth credentials from the host operator.** Ask the user to run
-   on the host:
+   The `admin` scope is required because `gbrain remote ping` and
+   `gbrain remote doctor` (Tier B convenience commands) call MCP ops with
+   `admin` scope. `read,write` alone breaks ping/doctor.
+
+   Or set `GBRAIN_REMOTE_CLIENT_SECRET` env var instead of the flag (preferred
+   for headless / scripted setup). Pre-flight runs three smoke probes; any
+   failure surfaces an actionable error.
+
+4. **Configure your agent's MCP client.** Add a server entry pointing at
+   `<mcp_url>` with the bearer token. See `docs/mcp/CLAUDE_DESKTOP.md`,
+   `docs/mcp/CLAUDE_CODE.md`, etc. for per-client snippets.
+
+6. **Skip Phases B, C, C.5, and H entirely.** They're for local engines.
+   The host's autopilot handles sync/extract/embed. Thin clients consume
+   only.
+
+7. **Continue to Phase D (brain-first lookup).** It works identically over
+   MCP — the agent uses the same brain-ops skill to query/search/get_page,
+   they just round-trip through the host's `gbrain serve --http`.
+
+If init reports "thin-client config already present", a previous setup
+already configured this machine. Refusing without `--force` is the correct
+behavior; either accept the existing config or pass `--force` to refresh.
+
+
+#### If the user picks 2 (cross-machine thin client) — steps
+
+> 2. **Get OAuth credentials from the host operator.** Ask the user to run
+> on the host:
    ```bash
    gbrain auth register-client <name> \
      --grant-types client_credentials \
      --scopes read,write,admin
    ```
-   The `admin` scope is required because `gbrain remote ping` and
-   `gbrain remote doctor` (Tier B convenience commands) call MCP ops with
-   `admin` scope. `read,write` alone breaks ping/doctor.
-
-3. **Run thin-client init on this machine:**
+
+#### If the user picks 2 (cross-machine thin client) — steps 2
+
+> 3. **Run thin-client init on this machine:**
    ```bash
    gbrain init --mcp-only \
      --issuer-url https://<host>:<port> \
@@ -122,45 +160,35 @@
      --oauth-client-id <id> \
      --oauth-client-secret <secret>
    ```
-   Or set `GBRAIN_REMOTE_CLIENT_SECRET` env var instead of the flag (preferred
-   for headless / scripted setup). Pre-flight runs three smoke probes; any
-   failure surfaces an actionable error.
-
-4. **Configure your agent's MCP client.** Add a server entry pointing at
-   `<mcp_url>` with the bearer token. See `docs/mcp/CLAUDE_DESKTOP.md`,
-   `docs/mcp/CLAUDE_CODE.md`, etc. for per-client snippets.
-
-5. **Verify with `gbrain doctor`.** Thin-client doctor runs OAuth discovery,
+
+#### If the user picks 2 (cross-machine thin client) — steps 3
+
+5. Thin-client doctor runs OAuth discovery,
    token round-trip, and MCP smoke against the host. Should report
    `mode: thin-client` with all checks green.
 
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
-This shape requires per-worktree wiring that gstack handles, not gbrain
-directly. gbrain's role is just to run a local engine when `GBRAIN_HOME` is
-set — that already works.
+### If the user picks 3 (split-engine per-worktree) (( inert ))
 
 Point the user at `docs/architecture/topologies.md` (the Topology 3 section)
 for the wiring recipe, then continue with Phase A as normal — `gbrain init`
 on this machine sets up the artifact brain (the "default" home). The
 per-worktree code engines are configured per-worktree as gstack creates them.
 
+
+#### If the user picks 3 (split-engine per-worktree) — steps
+
+This shape requires per-worktree wiring that gstack handles, not gbrain
+directly. gbrain's role is just to run a local engine when `GBRAIN_HOME` is
+set — that already works.
+
+
+#### If the user picks 3 (split-engine per-worktree) — steps 2
+
 If the user has a remote artifact brain (Topology 2 + 3 combined), follow
 the thin-client setup above for the artifact brain instead of Phase A.
 
 ## Phase A: Supabase Setup (recommended)
+use judgment to follow the Phase A: Supabase Setup (recommended) guidance:
 
 Guide the user through creating a Supabase project:
 
@@ -173,31 +201,61 @@
 4. "Find the connection string: click **Connect** in the top navigation bar,
    then **Connection String** > **Transaction pooler**, and copy the string
    (port 6543)."
-5. Initialize gbrain:
-   ```bash
-   gbrain init --non-interactive --url "postgresql://postgres.[ref]:[password]@aws-0-[region].pooler.supabase.com:6543/postgres"
-   ```
-6. Verify: `gbrain doctor --json`
-
 **OpenClaw/Hermes agent instructions:** Store the Supabase access token in your persistent
 env as `SUPABASE_ACCESS_TOKEN`. gbrain doesn't store it, you need it for future
 `gbrain doctor` runs. Generate at: https://supabase.com/dashboard/account/tokens
 
+
+### Phase A: Supabase Setup (recommended) — steps
+
+> 5. Initialize gbrain:
+   ```bash
+   gbrain init --non-interactive --url "postgresql://postgres.[ref]:[password]@aws-0-[region].pooler.supabase.com:6543/postgres"
+   ```
+6. Verify: `gbrain doctor --json`
+
 ## Phase B: BYO Postgres (alternative)
+use judgment to follow the Phase B: BYO Postgres (alternative) guidance:
 
 If the user already has Postgres with pgvector:
 
 1. Get the connection string from the user.
-2. Run: `gbrain init --non-interactive --url "<connection_string>"`
-3. Verify: `gbrain doctor --json`
-
 If the connection fails with ECONNREFUSED and the URL contains `supabase.co`,
 the user probably pasted the direct connection (IPv6 only). Guide them to the
 Transaction pooler string instead (see Phase A step 4).
 
+
+### Phase B: BYO Postgres (alternative) — steps
+
+2. Run: `gbrain init --non-interactive --url "<connection_string>"`
+3. Verify: `gbrain doctor --json`
+
 ## Phase C: First Import
+use judgment to follow the Phase C: First Import guidance:
 
 1. **Discover markdown repos.** Scan the environment for git repos with markdown content.
+
+   This is the magical moment: the user sees search finding things grep couldn't.
+
+4. **Start embeddings.** Refresh stale embeddings (runs in background). Keyword
+   search works NOW, semantic search improves as embeddings complete.
+
+5. **Backfill the knowledge graph.** Populate typed links and structured timeline
+   from the imported pages. Auto-link maintains both going forward, but historical
+   pages need a one-time backfill.
+
+   Skip if Phase C imported zero pages (auto-link handles new writes).
+
+6. **Offer file migration.** If the repo has binary files (.raw/ directories with
+   images, PDFs, audio):
+   > "You have N binary files (X GB) in your brain repo. Want to move them to cloud
+   > storage? Your git repo will drop from X GB to Y MB. All links keep working."
+
+If no markdown repos are found, create a starter brain with a few template pages
+(a person page, a company page, a concept page) from docs/GBRAIN_RECOMMENDED_SCHEMA.md.
+
+
+### Phase C: First Import — steps
 
 ```bash
 echo "=== GBrain Environment Discovery ==="
@@ -213,30 +271,24 @@
 echo "=== Discovery Complete ==="
 ```
 
-2. **Import the best candidate.** For large imports (>1000 files), use nohup to
-   survive session timeouts:
+> 2. **Import the best candidate.** For large imports (>1000 files), use nohup to
+> survive session timeouts:
    ```bash
    nohup gbrain import <dir> --no-embed --workers 4 > /tmp/gbrain-import.log 2>&1 &
    ```
    Then check progress: `tail -1 /tmp/gbrain-import.log`
 
-   For smaller imports, run directly:
+> For smaller imports, run directly:
    ```bash
    gbrain import <dir> --no-embed
    ```
 
-3. **Prove search works.** Pick a semantic query based on what you imported:
+> 3. **Prove search works.** Pick a semantic query based on what you imported:
    ```bash
    gbrain search "<topic from the imported data>"
    ```
-   This is the magical moment: the user sees search finding things grep couldn't.
-
-4. **Start embeddings.** Refresh stale embeddings (runs in background). Keyword
-   search works NOW, semantic search improves as embeddings complete.
-
-5. **Backfill the knowledge graph.** Populate typed links and structured timeline
-   from the imported pages. Auto-link maintains both going forward, but historical
-   pages need a one-time backfill.
+
+### Phase C: First Import — steps 2
 
    ```bash
    gbrain extract links --source db --dry-run | head -20    # preview
@@ -249,14 +301,10 @@
    well-connected entities higher. Idempotent — safe to re-run anytime.
    Supports `--since YYYY-MM-DD` for incremental runs on huge brains.
 
-   Skip if Phase C imported zero pages (auto-link handles new writes).
-
-6. **Offer file migration.** If the repo has binary files (.raw/ directories with
-   images, PDFs, audio):
-   > "You have N binary files (X GB) in your brain repo. Want to move them to cloud
-   > storage? Your git repo will drop from X GB to Y MB. All links keep working."
-
-   If the user agrees, configure storage and run migration:
+
+### Phase C: First Import — steps 3
+
+> If the user agrees, configure storage and run migration:
    ```bash
    # Configure storage backend (Supabase Storage recommended)
    gbrain config set storage.backend supabase
@@ -274,33 +322,14 @@
    small text/PDFs stay in git, large/media files go to cloud with `.redirect.yaml`
    pointers. Files >= 100 MB use TUS resumable upload for reliability.
 
-If no markdown repos are found, create a starter brain with a few template pages
-(a person page, a company page, a concept page) from docs/GBRAIN_RECOMMENDED_SCHEMA.md.
-
 ## Phase C.5: One-step autopilot + Minions install (v0.11.1+)
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
+use judgment to follow the Phase C.5: One-step autopilot + Minions install (v0.11.1+) guidance:
+
 - On **Linux with systemd**: writes `~/.config/systemd/user/gbrain-autopilot.service`
   with `Restart=on-failure`.
-- On **ephemeral containers** (Render / Railway / Fly / Docker): writes
-  `~/.gbrain/start-autopilot.sh` and prints the one-line your agent's
-  bootstrap should source to launch autopilot on every container start.
   Auto-injects into OpenClaw's `hooks/bootstrap/ensure-services.sh` if
   detected (use `--no-inject` to opt out).
 - On **Linux without systemd**: installs a crontab entry (every 5 min).
-
-Autopilot then supervises the Minions worker as a child process. Users get
-sync + extract + embed + backlinks + durable Postgres-backed job processing
-from ONE install step. No separate `gbrain jobs work` daemon to manage.
 
 On PGLite, autopilot runs inline (PGLite's exclusive file lock blocks a
 separate worker process). Everything else still works.
@@ -311,13 +340,44 @@
 register host-specific handlers. Re-run `apply-migrations` after each
 batch.
 
+
+### Phase C.5: One-step autopilot + Minions install (v0.11.1+) — steps
+
+> Run the migration runner once, then install autopilot. Two commands, done:
+
+```bash
+gbrain apply-migrations --yes       # applies any pending migrations; idempotent on healthy installs
+gbrain autopilot --install          # supervises itself + forks the Minions worker; env-aware
+```
+
+What `gbrain autopilot --install` does:
+
+- On macOS: writes a launchd plist at `~/Library/LaunchAgents/com.gbrain.autopilot.plist`.
+
+### Phase C.5: One-step autopilot + Minions install (v0.11.1+) — steps 2
+
+- On ephemeral containers (Render / Railway / Fly / Docker): writes
+  `~/.gbrain/start-autopilot.sh` and prints the one-line your agent's
+  bootstrap should source to launch autopilot on every container start.
+
+### Phase C.5: One-step autopilot + Minions install (v0.11.1+) — steps 3
+
+Autopilot then supervises the Minions worker as a child process. Users get
+sync + extract + embed + backlinks + durable Postgres-backed job processing
+from ONE install step. No separate `gbrain jobs work` daemon to manage.
+
 ## Phase D: Brain-First Lookup Protocol
+use judgment to follow the Phase D: Brain-First Lookup Protocol guidance:
 
 Inject the brain-first lookup protocol into the project's AGENTS.md (or equivalent).
 This replaces grep-based knowledge lookups with structured gbrain queries.
 
-### BEFORE (grep) vs AFTER (gbrain)
-
+### BEFORE (grep) vs AFTER (gbrain) (( inert ))
+
+
+#### BEFORE (grep) vs AFTER (gbrain) — steps
+
+!!! table (( ai-discretion ))
 | Task | Before (grep) | After (gbrain) |
 |------|---------------|-----------------|
 | Find a person | `grep -r "Pedro" brain/` | `gbrain search "Pedro"` |
@@ -325,42 +385,57 @@
 | Read a known page | `cat brain/people/pedro.md` | `gbrain get people/pedro` |
 | Find connections | `grep -rl "Brex" brain/ \| xargs grep "Pedro"` | `gbrain query "Pedro Brex relationship"` |
 
-### Lookup sequence (MANDATORY for every entity question)
+### Lookup sequence (MANDATORY for every entity question) (( inert ))
+
+4. `grep` fallback -- only if gbrain returns zero results AND the file may exist outside the indexed brain
+
+Stop at the first step that gives you what you need. Most lookups resolve at step 1.
+
+
+#### Lookup sequence (MANDATORY for every entity question) — steps
 
 1. `gbrain search "name"` -- keyword match, fast, works without embeddings
 2. `gbrain query "what do we know about name"` -- hybrid search, needs embeddings
 3. `gbrain get <slug>` -- direct page read when you know the slug from steps 1-2
-4. `grep` fallback -- only if gbrain returns zero results AND the file may exist outside the indexed brain
-
-Stop at the first step that gives you what you need. Most lookups resolve at step 1.
-
 ### Sync-after-write rule
-
-After creating or updating any brain page in the repo, sync immediately so the
-index stays current:
+use judgment to follow the Sync-after-write rule guidance:
+
+This indexes new/changed files without pulling from git or regenerating embeddings.
+
+#### Sync-after-write rule — steps
+
+> After creating or updating any brain page in the repo, sync immediately so the
+> index stays current:
 
 ```bash
 gbrain sync --no-pull --no-embed
 ```
 
-This indexes new/changed files without pulling from git or regenerating embeddings.
+
+#### Sync-after-write rule — steps 2
+
 Embeddings can be refreshed later in batch (`gbrain embed --stale`).
 
-### gbrain vs memory_search
-
+### gbrain vs memory_search (( inert ))
+
+Both should be checked. gbrain for facts about the world. memory_search for how
+the agent should behave.
+
+
+#### gbrain vs memory_search — steps
+
+!!! table (( ai-discretion ))
 | Layer | What it stores | When to use |
 |-------|---------------|-------------|
-| **gbrain** | World knowledge: people, companies, deals, meetings, concepts, media | "Who is Pedro?", "What happened at the board meeting?" |
-| **memory_search** | Agent operational state: preferences, decisions, session context | "How does the user like formatting?", "What did we decide about X?" |
-
-Both should be checked. gbrain for facts about the world. memory_search for how
-the agent should behave.
+| gbrain | World knowledge: people, companies, deals, meetings, concepts, media | "Who is Pedro?", "What happened at the board meeting?" |
+| memory_search | Agent operational state: preferences, decisions, session context | "How does the user like formatting?", "What did we decide about X?" |
 
 ### Self-upgrade marker protocol (inject into AGENTS.md)
+use judgment to follow the Self-upgrade marker protocol (inject into AGENTS.md) guidance:
 
 gbrain keeps itself current by riding invocation frequency: any `gbrain` command
-may print `UPGRADE_AVAILABLE <old> <new>` (or a one-time `JUST_UPGRADED <old>
-<new>`) on **stderr**. That marker does nothing unless the agent is told to act
+may print `UPGRADE_AVAILABLE <old> <new>` (or a one-time ``JUST_UPGRADED <old>
+<new>``) on **stderr**. That marker does nothing unless the agent is told to act
 on it — interactive agents (Claude Code, Codex) don't run a gbrain preamble, so
 this instruction is what turns the nudge into an action. Inject this block into
 the project's AGENTS.md (or equivalent system context):
@@ -382,33 +457,48 @@
 marker + this protocol.
 
 ## Phase E: Load the Production Agent Guide
-
-Read `docs/GBRAIN_SKILLPACK.md`. This is the reference architecture for how a
-production agent uses gbrain: the brain-agent loop, entity detection, enrichment
-pipeline, meeting ingestion, cron schedules, and the five operational disciplines.
+use judgment to follow the Phase E: Load the Production Agent Guide guidance:
 
 Inject the key patterns into the agent's system context or AGENTS.md:
 
 1. **Brain-agent loop** (Section 2): read before responding, write after learning
 2. **Entity detection** (Section 3): spawn on every message, capture people/companies/ideas
-3. **Source attribution** (Section 7): every fact needs `[Source: ...]`
-> **Convention:** See `skills/conventions/quality.md` for Iron Law back-linking.
-
 Tell the user: "The production agent guide is at docs/GBRAIN_SKILLPACK.md. It covers
 the brain-agent loop, entity detection, enrichment, meeting ingestion, and cron
 schedules. Read it when you're ready to go from 'search works' to 'the brain
 maintains itself.'"
 
+
+### Phase E: Load the Production Agent Guide — steps
+
+Read `docs/GBRAIN_SKILLPACK.md`. This is the reference architecture for how a
+production agent uses gbrain: the brain-agent loop, entity detection, enrichment
+pipeline, meeting ingestion, cron schedules, and the five operational disciplines.
+
+
+### Phase E: Load the Production Agent Guide — steps 2
+
+3. Source attribution (Section 7): every fact needs `[Source: ...]`
+> **Convention:** See `skills/conventions/quality.md` for Iron Law back-linking.
+
 ## Phase F: Health Check
+use judgment to follow the Phase F: Health Check guidance:
+
+If any check fails, the doctor output tells you exactly what's wrong and how to fix it.
+
+
+### Phase F: Health Check — steps
 
 Run `gbrain doctor --json` and report the results. Every check should be OK.
-If any check fails, the doctor output tells you exactly what's wrong and how to fix it.
-
-## Error Recovery
+## Error Recovery (( inert ))
 
 **If any gbrain command fails, run `gbrain doctor --json` first.** Report the full
 output. It checks connection, pgvector, RLS, schema version, and embeddings.
 
+
+### Error Recovery — steps
+
+!!! table (( ai-discretion ))
 | What You See | Why | Fix |
 |---|---|---|
 | Connection refused | Supabase project paused, IPv6, or wrong URL | Use Transaction pooler (port 6543), or supabase.com/dashboard > Restore |
@@ -419,6 +509,7 @@
 | RLS not enabled | Security gap | Run `gbrain init` again (auto-enables RLS) |
 
 ## Phase G: Auto-Update Check (if not already configured)
+use judgment to follow the Phase G: Auto-Update Check (if not already configured) guidance:
 
 If the user's install did NOT include setting up auto-update checks (e.g., they
 used the manual install path or an older version of the OpenClaw/Hermes paste), offer it:
@@ -427,18 +518,20 @@
 > new version worth upgrading to — including new skills and schema recommendations.
 > You'll always be asked before anything is installed."
 
-If they agree:
+2. Register daily cron (see GBRAIN_SKILLPACK.md Section 17)
+
+If already configured or user declines, skip.
+
+
+### Phase G: Auto-Update Check (if not already configured) — steps
+
+> If they agree:
 1. Test: `gbrain check-update --json`
-2. Register daily cron (see GBRAIN_SKILLPACK.md Section 17)
-
-If already configured or user declines, skip.
-
 ## Phase H: Live Sync Setup (MUST ADD)
+use judgment to follow the Phase H: Live Sync Setup (MUST ADD) guidance:
 
 The brain repo is the source of truth. If sync doesn't run automatically, the
 vector DB falls behind and gbrain returns stale answers. This phase is not optional.
-
-Read `docs/GBRAIN_SKILLPACK.md` Section 18 for the full reference. Key points:
 
 1. **Check the connection first.** GBrain is tuned for the Supabase **Transaction
    pooler** (port 6543): it auto-disables prepared statements there and routes
@@ -450,27 +543,39 @@
    Supabase's IPv4 add-on.
 
 2. **Set up automatic sync.** Choose the approach that fits your environment:
-   - **Cron** (recommended for agents): register a cron every 5-30 minutes:
-     `gbrain sync --repo /data/brain && gbrain embed --stale`
-   - **Watch mode**: `gbrain sync --watch --repo /data/brain` under a process
-     manager. Pair with a cron fallback (watch exits after 5 consecutive failures).
    - **Webhook or git hook**: if available in your environment.
 
-3. **Verify sync works.** Don't just check that the command ran. Check that it
-   worked:
-   - `gbrain stats` should show page count close to syncable file count in the repo.
    - If page count is way too low, the direct connection is unreachable on IPv4 and
      sync is silently skipping pages (see point 1).
    - Push a test change and confirm it appears in `gbrain search`.
 
-4. **Chain sync + embed.** Always run both: `gbrain sync --repo <path> && gbrain
+4. **Chain sync + embed.** Always run both: ``gbrain sync --repo <path> && gbrain
    embed --stale`. For small syncs, embeddings are generated inline. The `embed
-   --stale` is a safety net for any stale chunks.
+   --stale`` is a safety net for any stale chunks.
 
 Tell the user: "Live sync is configured. The brain will stay current automatically.
 I'll verify it's working in the next phase."
 
+
+### Phase H: Live Sync Setup (MUST ADD) — steps
+
+Read `docs/GBRAIN_SKILLPACK.md` Section 18 for the full reference. Key points:
+
+
+### Phase H: Live Sync Setup (MUST ADD) — steps 2
+
+> - **Cron** (recommended for agents): register a cron every 5-30 minutes:
+     `gbrain sync --repo /data/brain && gbrain embed --stale`
+   - Watch mode: `gbrain sync --watch --repo /data/brain` under a process
+     manager. Pair with a cron fallback (watch exits after 5 consecutive failures).
+
+### Phase H: Live Sync Setup (MUST ADD) — steps 3
+
+> 3. **Verify sync works.** Don't just check that the command ran. Check that it
+> worked:
+   - `gbrain stats` should show page count close to syncable file count in the repo.
 ## Phase I: Full Verification
+use judgment to follow the Phase I: Full Verification guidance:
 
 Run the full verification runbook to confirm the entire installation is working.
 
@@ -489,6 +594,7 @@
 If already configured or user declines, skip.
 
 ## Phase J: Cold Start — Populate Your Brain (AUTOMATIC)
+use judgment to follow the Phase J: Cold Start — Populate Your Brain (AUTOMATIC) guidance:
 
 Setup is done. The brain works. But it's empty. **This is the most important
 moment** — an empty brain is useless. Transition directly to the cold-start
@@ -508,32 +614,42 @@
 >
 > **Ready to populate your brain?**"
 
-If the user says yes (or anything affirmative):
-→ **Load and execute `skills/cold-start/SKILL.md`** immediately. Do not
-just print a reference — actually run the cold-start skill.
-
-If the user says no or wants to stop:
-→ Record in `~/.gbrain/cold-start-state.json`:
 ```json
 {"deferred": true, "deferred_at": "ISO-timestamp", "phases_completed": []}
 ```
 → Tell them: "You can run cold-start anytime by asking me to 'fill my brain'
 or 'cold start'."
 
-## Schema State Tracking
+
+### Phase J: Cold Start — Populate Your Brain (AUTOMATIC) — steps
+
+> If the user says yes (or anything affirmative):
+→ Load and execute `skills/cold-start/SKILL.md` immediately. Do not
+just print a reference — actually run the cold-start skill.
+
+> If the user says no or wants to stop:
+→ Record in `~/.gbrain/cold-start-state.json`:
+## Schema State Tracking (( inert ))
+
+- `schema_version_applied`: current gbrain version
+- `skillpack_version_applied`: current gbrain version
+This file enables future upgrades to suggest new schema additions without
+re-suggesting things the user already declined.
+
+
+### Schema State Tracking — steps
 
 After presenting the recommended directories (Phase C/E) and the user selects which
 ones to create, write `~/.gbrain/update-state.json` recording:
-- `schema_version_applied`: current gbrain version
-- `skillpack_version_applied`: current gbrain version
+
+### Schema State Tracking — steps 2
+
 - `schema_choices.adopted`: directories the user created
 - `schema_choices.declined`: directories the user explicitly skipped
 - `schema_choices.custom`: directories the user added that aren't in the recommended schema
 
-This file enables future upgrades to suggest new schema additions without
-re-suggesting things the user already declined.
-
-## Anti-Patterns
+## Anti-Patterns (( role: procedure ))
+use judgment to follow the Anti-Patterns guidance:
 
 - **Ending setup without offering cold-start.** An empty brain is useless. Phase J (cold-start) is where setup pays off. Always present the "Ready to populate?" prompt after verification. Skipping this is like installing an app and never logging in.
 - **Asking for the Supabase anon key.** GBrain connects directly to Postgres over the wire protocol, not through the REST API. Only the database connection string is needed.
@@ -542,7 +658,7 @@
 - **Leaving the direct connection unreachable on IPv4.** GBrain uses the Transaction pooler (port 6543) for reads and a derived direct connection (`db.<ref>.supabase.co:5432`, IPv6-only) for migrations, DDL, and sync transactions. On an IPv4-only host, reads work but sync silently skips pages. Set `GBRAIN_DIRECT_DATABASE_URL` to the Session pooler string (port 5432, IPv4), or enable the IPv4 add-on.
 - **Importing without proving search.** The magical moment is the user seeing search find things grep couldn't. Don't skip it.
 
-## Output Format
+## Output Format (( inert, role: template ))
 
 ```
 GBRAIN SETUP COMPLETE
@@ -564,7 +680,7 @@
 **The output should transition directly into cold-start (Phase J), not end
 with a bullet list.** The bullet list is for when the user defers cold-start.
 
-## Tools Used
+## Tools Used (( inert, role: tools ))
 
 - `gbrain init --non-interactive --url ...` -- create brain
 - `gbrain import <dir> --no-embed [--workers N]` -- import files
```
