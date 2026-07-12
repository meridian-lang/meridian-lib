# Deviation: setup.meri

- Original: `setup/SKILL.md`
- Ported: `setup.meri`
- Tier: 2 (light edits)
- Similarity: 65%
- Lines: 580 -> 693 (+278 / -165)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- preamble-blockquoted
- doc-section-marked

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L6 `Contract`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L36 `Why Supabase`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L90 `If the user picks 1 (single brain) — proceed to Phase A`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L348 `Phase D: Brain-First Lookup Protocol`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L644 `Output Format`: template - Template/output shape is metadata unless explicit output assertions are authored.
- L666 `Tools Used`: tools-metadata - Tools sections are metadata-mining, not workflow execution.

## Metrics
- generated_loc: 469 non-blank ported lines
- Sections inert total: 26/28 (93% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert markers (`(( inert ))`, target 0 — the migrator never emits these): 0
- Inert categories: reference-documentation=24, template=1, tools-metadata=1
- Judgment: 0 blocks, 0 lines
- canonical_drift: synonym=10, structure=0, desugar=1, meaning=477

### Inert section details
- L6 `Contract`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L20 `How GBrain connects`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L36 `Why Supabase`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L90 `If the user picks 1 (single brain) — proceed to Phase A`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L94 `If the user picks 2 (cross-machine thin client)`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L153 `If the user picks 3 (split-engine per-worktree)`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L173 `Phase A: Supabase Setup (recommended)`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L199 `Phase B: BYO Postgres (alternative)`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L214 `Phase C: First Import`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L305 `Phase C.5: One-step autopilot + Minions install (v0.11.1+)`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L348 `Phase D: Brain-First Lookup Protocol`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L366 `Lookup sequence (MANDATORY for every entity question)`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L378 `Sync-after-write rule`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L396 `gbrain vs memory_search`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L410 `Self-upgrade marker protocol (inject into AGENTS.md)`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L438 `Phase E: Load the Production Agent Guide`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L462 `Phase F: Health Check`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L470 `Error Recovery`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L487 `Phase G: Auto-Update Check (if not already configured)`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L505 `Phase H: Live Sync Setup (MUST ADD)`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L554 `Phase I: Full Verification`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L575 `Phase J: Cold Start — Populate Your Brain (AUTOMATIC)`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L613 `Schema State Tracking`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L632 `Anti-Patterns`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L644 `Output Format`: template — Template/output shape is metadata unless explicit output assertions are authored.
- L666 `Tools Used`: tools-metadata — Tools sections are metadata-mining, not workflow execution.

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
+## Contract (( role: reference ))
 
 - Setup completes with a working brain verified by `gbrain doctor --json` (all checks OK).
 - The brain-first lookup protocol is injected into the project's AGENTS.md or equivalent.
@@ -31,11 +31,7 @@
 bun add github:garrytan/gbrain
 ```
 
-## How GBrain connects
-
-GBrain connects directly to Postgres over the wire protocol. NOT through the
-Supabase REST API. You need the **database connection string** (a `postgresql://` URI),
-not the project URL or anon key. The password is embedded in the connection string.
+## How GBrain connects (( role: reference ))
 
 Use the **Transaction pooler** connection string (port 6543), not the direct
 connection (port 5432). The direct hostname resolves to IPv6 only, which many
@@ -44,7 +40,14 @@
 
 **Do NOT ask for the Supabase anon key.** GBrain doesn't use it.
 
-## Why Supabase
+
+### How GBrain connects — steps (( role: reference ))
+
+GBrain connects directly to Postgres over the wire protocol. NOT through the
+Supabase REST API. You need the database connection string (a `postgresql://` URI),
+not the project URL or anon key. The password is embedded in the connection string.
+
+## Why Supabase (( role: reference ))
 
 Supabase gives you managed Postgres + pgvector (vector search built in) for $25/mo:
 - 8GB database + 100GB storage on Pro tier
@@ -60,6 +63,9 @@
 
 ## Available init options
 
+
+### Available init options — steps (( role: reference ))
+
 - `gbrain init --supabase` -- interactive wizard (prompts for connection string)
 - `gbrain init --url <connection_string>` -- direct, no prompts
 - `gbrain init --non-interactive --url <connection_string>` -- for scripts/agents
@@ -69,6 +75,9 @@
 (local PGLite or remote Supabase / self-hosted).
 
 ## Phase A.5: Choose Topology (run BEFORE Phase A)
+
+
+### Phase A.5: Choose Topology (run BEFORE Phase A) — steps (( role: reference ))
 
 GBrain supports three deployment shapes. Pick the right one before installing,
 because picking wrong creates contention or duplicate work that's painful to
@@ -92,19 +101,38 @@
 >
 >  Which fits?"
 
-### If the user picks 1 (single brain) — proceed to Phase A
+### If the user picks 1 (single brain) — proceed to Phase A (( role: reference ))
 
 Continue with the existing `gbrain init --supabase` / `--pglite` setup below.
 
-### If the user picks 2 (cross-machine thin client)
+### If the user picks 2 (cross-machine thin client) (( role: reference ))
 
 1. **Confirm a host already exists.** Ask: "Is the remote `gbrain serve --http`
    already running on the host machine?" If no, the user needs to set up the
    host first (Phases A-C on the host, then `gbrain serve --http`). Don't try
    to run init on this machine until the host is up.
 
-2. **Get OAuth credentials from the host operator.** Ask the user to run
-   on the host:
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
+
+### If the user picks 2 (cross-machine thin client) — steps
+
+> 2. **Get OAuth credentials from the host operator.** Ask the user to run
+> on the host:
    ```bash
    gbrain auth register-client <name> \
      --grant-types client_credentials \
@@ -114,7 +142,7 @@
    `gbrain remote doctor` (Tier B convenience commands) call MCP ops with
    `admin` scope. `read,write` alone breaks ping/doctor.
 
-3. **Run thin-client init on this machine:**
+> 3. **Run thin-client init on this machine:**
    ```bash
    gbrain init --mcp-only \
      --issuer-url https://<host>:<port> \
@@ -122,45 +150,41 @@
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
+### If the user picks 2 (cross-machine thin client) — steps 2 (( role: reference ))
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
+
+### If the user picks 2 (cross-machine thin client) — steps 3 (( role: reference ))
 
 If init reports "thin-client config already present", a previous setup
 already configured this machine. Refusing without `--force` is the correct
 behavior; either accept the existing config or pass `--force` to refresh.
 
-### If the user picks 3 (split-engine per-worktree)
-
-This shape requires per-worktree wiring that gstack handles, not gbrain
-directly. gbrain's role is just to run a local engine when `GBRAIN_HOME` is
-set — that already works.
+### If the user picks 3 (split-engine per-worktree) (( role: reference ))
 
 Point the user at `docs/architecture/topologies.md` (the Topology 3 section)
 for the wiring recipe, then continue with Phase A as normal — `gbrain init`
 on this machine sets up the artifact brain (the "default" home). The
 per-worktree code engines are configured per-worktree as gstack creates them.
 
+
+### If the user picks 3 (split-engine per-worktree) — steps (( role: reference ))
+
+This shape requires per-worktree wiring that gstack handles, not gbrain
+directly. gbrain's role is just to run a local engine when `GBRAIN_HOME` is
+set — that already works.
+
+
+### If the user picks 3 (split-engine per-worktree) — steps 2 (( role: reference ))
+
 If the user has a remote artifact brain (Topology 2 + 3 combined), follow
 the thin-client setup above for the artifact brain instead of Phase A.
 
-## Phase A: Supabase Setup (recommended)
+## Phase A: Supabase Setup (recommended) (( role: reference ))
 
 Guide the user through creating a Supabase project:
 
@@ -173,31 +197,59 @@
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
 
-## Phase B: BYO Postgres (alternative)
+
+### Phase A: Supabase Setup (recommended) — steps
+
+> 5. Initialize gbrain:
+   ```bash
+   gbrain init --non-interactive --url "postgresql://postgres.[ref]:[password]@aws-0-[region].pooler.supabase.com:6543/postgres"
+   ```
+6. Verify: `gbrain doctor --json`
+
+## Phase B: BYO Postgres (alternative) (( role: reference ))
 
 If the user already has Postgres with pgvector:
 
 1. Get the connection string from the user.
-2. Run: `gbrain init --non-interactive --url "<connection_string>"`
-3. Verify: `gbrain doctor --json`
-
 If the connection fails with ECONNREFUSED and the URL contains `supabase.co`,
 the user probably pasted the direct connection (IPv6 only). Guide them to the
 Transaction pooler string instead (see Phase A step 4).
 
-## Phase C: First Import
+
+### Phase B: BYO Postgres (alternative) — steps
+
+2. Run: `gbrain init --non-interactive --url "<connection_string>"`
+3. Verify: `gbrain doctor --json`
+
+## Phase C: First Import (( role: reference ))
 
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
@@ -213,30 +265,24 @@
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
@@ -249,12 +295,8 @@
    well-connected entities higher. Idempotent — safe to re-run anytime.
    Supports `--since YYYY-MM-DD` for incremental runs on huge brains.
 
-   Skip if Phase C imported zero pages (auto-link handles new writes).
-
-6. **Offer file migration.** If the repo has binary files (.raw/ directories with
-   images, PDFs, audio):
-   > "You have N binary files (X GB) in your brain repo. Want to move them to cloud
-   > storage? Your git repo will drop from X GB to Y MB. All links keep working."
+
+### Phase C: First Import — steps 3
 
    If the user agrees, configure storage and run migration:
    ```bash
@@ -274,33 +316,13 @@
    small text/PDFs stay in git, large/media files go to cloud with `.redirect.yaml`
    pointers. Files >= 100 MB use TUS resumable upload for reliability.
 
-If no markdown repos are found, create a starter brain with a few template pages
-(a person page, a company page, a concept page) from docs/GBRAIN_RECOMMENDED_SCHEMA.md.
-
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
+## Phase C.5: One-step autopilot + Minions install (v0.11.1+) (( role: reference ))
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
@@ -311,13 +333,43 @@
 register host-specific handlers. Re-run `apply-migrations` after each
 batch.
 
-## Phase D: Brain-First Lookup Protocol
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
+### Phase C.5: One-step autopilot + Minions install (v0.11.1+) — steps 2 (( role: reference ))
+
+- On ephemeral containers (Render / Railway / Fly / Docker): writes
+  `~/.gbrain/start-autopilot.sh` and prints the one-line your agent's
+  bootstrap should source to launch autopilot on every container start.
+
+### Phase C.5: One-step autopilot + Minions install (v0.11.1+) — steps 3 (( role: reference ))
+
+Autopilot then supervises the Minions worker as a child process. Users get
+sync + extract + embed + backlinks + durable Postgres-backed job processing
+from ONE install step. No separate `gbrain jobs work` daemon to manage.
+
+## Phase D: Brain-First Lookup Protocol (( role: reference ))
 
 Inject the brain-first lookup protocol into the project's AGENTS.md (or equivalent).
 This replaces grep-based knowledge lookups with structured gbrain queries.
 
 ### BEFORE (grep) vs AFTER (gbrain)
 
+
+### BEFORE (grep) vs AFTER (gbrain) — steps
+
+!!! table (( ai-discretion ))
 | Task | Before (grep) | After (gbrain) |
 |------|---------------|-----------------|
 | Find a person | `grep -r "Pedro" brain/` | `gbrain search "Pedro"` |
@@ -325,42 +377,55 @@
 | Read a known page | `cat brain/people/pedro.md` | `gbrain get people/pedro` |
 | Find connections | `grep -rl "Brex" brain/ \| xargs grep "Pedro"` | `gbrain query "Pedro Brex relationship"` |
 
-### Lookup sequence (MANDATORY for every entity question)
+### Lookup sequence (MANDATORY for every entity question) (( role: reference ))
+
+4. `grep` fallback -- only if gbrain returns zero results AND the file may exist outside the indexed brain
+
+Stop at the first step that gives you what you need. Most lookups resolve at step 1.
+
+
+### Lookup sequence (MANDATORY for every entity question) — steps
 
 1. `gbrain search "name"` -- keyword match, fast, works without embeddings
 2. `gbrain query "what do we know about name"` -- hybrid search, needs embeddings
 3. `gbrain get <slug>` -- direct page read when you know the slug from steps 1-2
-4. `grep` fallback -- only if gbrain returns zero results AND the file may exist outside the indexed brain
-
-Stop at the first step that gives you what you need. Most lookups resolve at step 1.
-
-### Sync-after-write rule
-
-After creating or updating any brain page in the repo, sync immediately so the
-index stays current:
+### Sync-after-write rule (( role: reference ))
+
+This indexes new/changed files without pulling from git or regenerating embeddings.
+
+### Sync-after-write rule — steps
+
+> After creating or updating any brain page in the repo, sync immediately so the
+> index stays current:
 
 ```bash
 gbrain sync --no-pull --no-embed
 ```
 
-This indexes new/changed files without pulling from git or regenerating embeddings.
+
+### Sync-after-write rule — steps 2
+
 Embeddings can be refreshed later in batch (`gbrain embed --stale`).
 
-### gbrain vs memory_search
-
+### gbrain vs memory_search (( role: reference ))
+
+Both should be checked. gbrain for facts about the world. memory_search for how
+the agent should behave.
+
+
+### gbrain vs memory_search — steps
+
+!!! table (( ai-discretion ))
 | Layer | What it stores | When to use |
 |-------|---------------|-------------|
-| **gbrain** | World knowledge: people, companies, deals, meetings, concepts, media | "Who is Pedro?", "What happened at the board meeting?" |
-| **memory_search** | Agent operational state: preferences, decisions, session context | "How does the user like formatting?", "What did we decide about X?" |
-
-Both should be checked. gbrain for facts about the world. memory_search for how
-the agent should behave.
-
-### Self-upgrade marker protocol (inject into AGENTS.md)
+| gbrain | World knowledge: people, companies, deals, meetings, concepts, media | "Who is Pedro?", "What happened at the board meeting?" |
+| memory_search | Agent operational state: preferences, decisions, session context | "How does the user like formatting?", "What did we decide about X?" |
+
+### Self-upgrade marker protocol (inject into AGENTS.md) (( role: reference ))
 
 gbrain keeps itself current by riding invocation frequency: any `gbrain` command
-may print `UPGRADE_AVAILABLE <old> <new>` (or a one-time `JUST_UPGRADED <old>
-<new>`) on **stderr**. That marker does nothing unless the agent is told to act
+may print `UPGRADE_AVAILABLE <old> <new>` (or a one-time ``JUST_UPGRADED <old>
+<new>``) on **stderr**. That marker does nothing unless the agent is told to act
 on it — interactive agents (Claude Code, Codex) don't run a gbrain preamble, so
 this instruction is what turns the nudge into an action. Inject this block into
 the project's AGENTS.md (or equivalent system context):
@@ -376,38 +441,53 @@
 upgrade command is `gbrain self-upgrade`.
 ```
 
+
+### Self-upgrade marker protocol (inject into AGENTS.md) — steps (( role: reference ))
+
 For always-on agents (OpenClaw / Hermes daemons), the daily HEARTBEAT.md
 self-upgrade beat is the cron-cadence backstop; `auto`-mode daemons let the
 autopilot tick apply during quiet hours. Interactive agents rely on the stderr
 marker + this protocol.
 
-## Phase E: Load the Production Agent Guide
-
-Read `docs/GBRAIN_SKILLPACK.md`. This is the reference architecture for how a
-production agent uses gbrain: the brain-agent loop, entity detection, enrichment
-pipeline, meeting ingestion, cron schedules, and the five operational disciplines.
+## Phase E: Load the Production Agent Guide (( role: reference ))
 
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
 
-## Phase F: Health Check
+
+### Phase E: Load the Production Agent Guide — steps (( role: reference ))
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
+## Phase F: Health Check (( role: reference ))
+
+If any check fails, the doctor output tells you exactly what's wrong and how to fix it.
+
+
+### Phase F: Health Check — steps
 
 Run `gbrain doctor --json` and report the results. Every check should be OK.
-If any check fails, the doctor output tells you exactly what's wrong and how to fix it.
-
-## Error Recovery
+## Error Recovery (( role: reference ))
 
 **If any gbrain command fails, run `gbrain doctor --json` first.** Report the full
 output. It checks connection, pgvector, RLS, schema version, and embeddings.
+
+
+### Error Recovery — steps (( role: reference ))
 
 | What You See | Why | Fix |
 |---|---|---|
@@ -418,7 +498,7 @@
 | No pages found | Query before import | Import files into gbrain first |
 | RLS not enabled | Security gap | Run `gbrain init` again (auto-enables RLS) |
 
-## Phase G: Auto-Update Check (if not already configured)
+## Phase G: Auto-Update Check (if not already configured) (( role: reference ))
 
 If the user's install did NOT include setting up auto-update checks (e.g., they
 used the manual install path or an older version of the OpenClaw/Hermes paste), offer it:
@@ -427,18 +507,19 @@
 > new version worth upgrading to — including new skills and schema recommendations.
 > You'll always be asked before anything is installed."
 
+2. Register daily cron (see GBRAIN_SKILLPACK.md Section 17)
+
+If already configured or user declines, skip.
+
+
+### Phase G: Auto-Update Check (if not already configured) — steps (( role: reference ))
+
 If they agree:
 1. Test: `gbrain check-update --json`
-2. Register daily cron (see GBRAIN_SKILLPACK.md Section 17)
-
-If already configured or user declines, skip.
-
-## Phase H: Live Sync Setup (MUST ADD)
+## Phase H: Live Sync Setup (MUST ADD) (( role: reference ))
 
 The brain repo is the source of truth. If sync doesn't run automatically, the
 vector DB falls behind and gbrain returns stale answers. This phase is not optional.
-
-Read `docs/GBRAIN_SKILLPACK.md` Section 18 for the full reference. Key points:
 
 1. **Check the connection first.** GBrain is tuned for the Supabase **Transaction
    pooler** (port 6543): it auto-disables prepared statements there and routes
@@ -450,31 +531,44 @@
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
-   embed --stale`. For small syncs, embeddings are generated inline. The `embed
-   --stale` is a safety net for any stale chunks.
-
 Tell the user: "Live sync is configured. The brain will stay current automatically.
 I'll verify it's working in the next phase."
 
-## Phase I: Full Verification
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
+
+### Phase H: Live Sync Setup (MUST ADD) — steps 4 (( role: reference ))
+
+4. Chain sync + embed. Always run both: ``gbrain sync --repo <path> && gbrain
+   embed --stale`. For small syncs, embeddings are generated inline. The `embed
+   --stale`` is a safety net for any stale chunks.
+
+## Phase I: Full Verification (( role: reference ))
 
 Run the full verification runbook to confirm the entire installation is working.
 
-1. Read `docs/GBRAIN_VERIFY.md`
 2. Execute each check in order
 3. Report results to the user
 4. Fix any failures before declaring setup complete
@@ -488,15 +582,15 @@
 
 If already configured or user declines, skip.
 
-## Phase J: Cold Start — Populate Your Brain (AUTOMATIC)
+
+### Phase I: Full Verification — steps
+
+1. Read `docs/GBRAIN_VERIFY.md`
+## Phase J: Cold Start — Populate Your Brain (AUTOMATIC) (( role: reference ))
 
 Setup is done. The brain works. But it's empty. **This is the most important
 moment** — an empty brain is useless. Transition directly to the cold-start
 skill to fill it with the user's actual data.
-
-**Do not end setup without offering cold-start.** The user just invested 15+
-minutes in setup. The payoff is seeing their brain come alive with their own
-data. Stopping here is like installing a phone and never adding contacts.
 
 Present this immediately after verification passes:
 
@@ -508,41 +602,60 @@
 >
 > **Ready to populate your brain?**"
 
+```json
+{"deferred": true, "deferred_at": "ISO-timestamp", "phases_completed": []}
+```
+→ Tell them: "You can run cold-start anytime by asking me to 'fill my brain'
+or 'cold start'."
+
+
+### Phase J: Cold Start — Populate Your Brain (AUTOMATIC) — steps (( role: reference ))
+
+The user just invested 15+
+minutes in setup. The payoff is seeing their brain come alive with their own
+data. Stopping here is like installing a phone and never adding contacts.
+
+
+### Phase J: Cold Start — Populate Your Brain (AUTOMATIC) — steps 2 (( role: reference ))
+
 If the user says yes (or anything affirmative):
-→ **Load and execute `skills/cold-start/SKILL.md`** immediately. Do not
+→ Load and execute `skills/cold-start/SKILL.md` immediately. Do not
 just print a reference — actually run the cold-start skill.
 
 If the user says no or wants to stop:
 → Record in `~/.gbrain/cold-start-state.json`:
-```json
-{"deferred": true, "deferred_at": "ISO-timestamp", "phases_completed": []}
-```
-→ Tell them: "You can run cold-start anytime by asking me to 'fill my brain'
-or 'cold start'."
-
-## Schema State Tracking
+## Schema State Tracking (( role: reference ))
+
+- `schema_version_applied`: current gbrain version
+- `skillpack_version_applied`: current gbrain version
+This file enables future upgrades to suggest new schema additions without
+re-suggesting things the user already declined.
+
+
+### Schema State Tracking — steps (( role: reference ))
 
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
-
-- **Ending setup without offering cold-start.** An empty brain is useless. Phase J (cold-start) is where setup pays off. Always present the "Ready to populate?" prompt after verification. Skipping this is like installing an app and never logging in.
+## Anti-Patterns (( role: reference ))
+
 - **Asking for the Supabase anon key.** GBrain connects directly to Postgres over the wire protocol, not through the REST API. Only the database connection string is needed.
 - **Skipping live sync setup.** If sync doesn't run automatically, the vector DB falls behind and search returns stale answers. Phase H is not optional.
 - **Declaring setup complete without verification.** "The command ran" is not the same as "it worked." Push a test change, wait for sync, search for the corrected text.
 - **Leaving the direct connection unreachable on IPv4.** GBrain uses the Transaction pooler (port 6543) for reads and a derived direct connection (`db.<ref>.supabase.co:5432`, IPv6-only) for migrations, DDL, and sync transactions. On an IPv4-only host, reads work but sync silently skips pages. Set `GBRAIN_DIRECT_DATABASE_URL` to the Session pooler string (port 5432, IPv4), or enable the IPv4 add-on.
 - **Importing without proving search.** The magical moment is the user seeing search find things grep couldn't. Don't skip it.
 
-## Output Format
+
+### Anti-Patterns — steps (( role: reference ))
+
+- An empty brain is useless. Phase J (cold-start) is where setup pays off. Always present the "Ready to populate?" prompt after verification. Skipping this is like installing an app and never logging in.
+## Output Format (( role: template ))
 
 ```
 GBRAIN SETUP COMPLETE
@@ -564,7 +677,7 @@
 **The output should transition directly into cold-start (Phase J), not end
 with a bullet list.** The bullet list is for when the user defers cold-start.
 
-## Tools Used
+## Tools Used (( role: tools ))
 
 - `gbrain init --non-interactive --url ...` -- create brain
 - `gbrain import <dir> --no-embed [--workers N]` -- import files
```
