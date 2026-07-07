# Deviation: cold_start.meri

- Original: `cold-start/SKILL.md`
- Ported: `cold_start.meri`
- Tier: 2 (light edits)
- Similarity: 75%
- Lines: 507 -> 568 (+166 / -105)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- preamble-blockquoted
- doc-section-marked

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L24 `Prerequisites`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L106 `If the user declines ClawVisor`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L179 `Via ClawVisor`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L218 `Quality gate`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L230 `Fetch events`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L245 `Brain structure`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L272 `Strategy: Smart sampling, not bulk import`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L348 `Quality rule`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L357 `Data sources`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L364 `Brain structure`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L500 `Output Format`: template - Template/output shape is metadata unless explicit output assertions are authored.
- L520 `Tools Used`: tools-metadata - Tools sections are metadata-mining, not workflow execution.

## Metrics
- Sections inert total: 23/36 (64% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert markers (`(( inert ))`, target 0 — the migrator never emits these): 0
- Inert categories: reference-documentation=21, template=1, tools-metadata=1
- Judgment: 2 blocks, 0 lines

### Inert section details
- L11 `Contract`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L24 `Prerequisites`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L48 `Phase 0: ClawVisor Setup (Required for API Access)`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L106 `If the user declines ClawVisor`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L179 `Via ClawVisor`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L196 `Processing rules`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L218 `Quality gate`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L230 `Fetch events`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L245 `Brain structure`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L256 `Entity enrichment`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L272 `Strategy: Smart sampling, not bulk import`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L281 `Processing`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L292 `Filtering rules`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L323 `Processing`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L348 `Quality rule`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L357 `Data sources`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L364 `Brain structure`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L406 `Phase 8: Meeting Transcripts`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L420 `Post-Bootstrap Checklist`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L471 `Anti-Patterns`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L488 `Resume Protocol`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L500 `Output Format`: template — Template/output shape is metadata unless explicit output assertions are authored.
- L520 `Tools Used`: tools-metadata — Tools sections are metadata-mining, not workflow execution.

## Unified diff

```diff
--- original-skills/cold-start/SKILL.md
+++ skills/cold_start.meri
@@ -40,28 +40,27 @@
 
 # Cold Start — Day-One Brain Bootstrapping
 
-You have a working brain. Search works. Now what?
-
-An empty brain is a static database. A brain with your email history, calendar,
-contacts, conversations, and social media is a **live context membrane** that makes
-every future interaction smarter. This skill sequences the highest-leverage data
-sources to get you from zero to useful in one session.
-
-## Contract
+> You have a working brain. Search works. Now what?
+
+> An empty brain is a static database. A brain with your email history, calendar,
+> contacts, conversations, and social media is a **live context membrane** that makes
+> every future interaction smarter. This skill sequences the highest-leverage data
+> sources to get you from zero to useful in one session.
+
+## Contract (( role: reference ))
 
 - Every import phase is gated on user consent (ask-user pattern) before proceeding.
-- **Google/social API access goes through ClawVisor.** The agent never holds raw OAuth
-  tokens or API keys. This is a safety requirement, not a preference. ClawVisor vaults
-  credentials, enforces task-scoped authorization, logs every API call, and requires
-  human approval for destructive operations. If the user doesn't want ClawVisor, the
-  only safe alternative is offline file exports (Google Takeout, Twitter archive download).
 - Each phase is independently valuable — the user can stop after any phase and still
   have a useful brain.
 - Progress is tracked in `~/.gbrain/cold-start-state.json` so interrupted sessions
   can resume.
 - Entity detection and cross-linking run on every import, not as a separate pass.
 
-## Prerequisites
+
+### Contract — steps (( role: reference ))
+
+- The agent never holds raw OAuth tokens or API keys. This is a safety requirement, not a preference. ClawVisor vaults credentials, enforces task-scoped authorization, logs every API call, and requires human approval for destructive operations. If the user doesn't want ClawVisor, the only safe alternative is offline file exports (Google Takeout, Twitter archive download).
+## Prerequisites (( role: reference ))
 
 - GBrain installed and initialized (`gbrain doctor --json` all green)
 - Brain repo cloned and synced
@@ -69,7 +68,10 @@
 
 ## The Priority Stack
 
-Data sources ranked by **information density × ease of import**:
+
+### The Priority Stack — steps (( role: reference ))
+
+> Data sources ranked by **information density × ease of import**:
 
 | Priority | Source | Why | Time | Pages Created |
 |----------|--------|-----|------|---------------|
@@ -82,49 +84,65 @@
 | 7 | File archives (Dropbox/Drive/local) | Historical documents, old writing, photos | 30+ min | varies |
 | 8 | Meeting transcripts (Circleback/etc.) | Deep relationship context from recorded calls | 20 min | 10-50 |
 
-## Phase 0: ClawVisor Setup (Required for API Access)
+## Phase 0: ClawVisor Setup (Required for API Access) (( role: reference ))
 
 > **Safety boundary:** An AI agent with raw OAuth tokens to your Gmail, Calendar,
 > and Contacts is an uncontrolled attack surface. One prompt injection, one
 > malicious tool call, and your entire Google account is exposed. ClawVisor
 > eliminates this risk class entirely.
 
-[ClawVisor](https://clawvisor.com) is a credential gateway that sits between the
-agent and your APIs. The agent never sees your credentials — ClawVisor injects
-them at request time, enforces policies, and logs everything.
-
-**What ClawVisor gives you:**
-- **Credential vaulting** — agent sees shadow tokens, never real secrets
 - **Task-scoped authorization** — each workflow declares exactly what it needs
 - **Audit trail** — every API call logged with metadata (who, what, when)
-- **Human approval gates** — destructive operations (send email, modify calendar)
-  require your explicit approval
 - **Multi-service** — Gmail, Calendar, Contacts, Drive, GitHub, iMessage from one gateway
 - **Revocation** — disable the agent's access in one click, no token rotation needed
 
 **Setup (15 min):**
 1. Sign up at [app.clawvisor.com](https://app.clawvisor.com)
 2. Create an agent in the dashboard, copy the agent token
-3. Set environment variables:
+4. Activate Google services (Gmail, Calendar, Contacts) in the dashboard
+5. Create a standing task with expansive scope:
+   > "Full brain bootstrapping: read emails, calendar events, and contacts to
+   > populate knowledge base. List, read, and search across all connected accounts."
+
+### Phase 0: ClawVisor Setup (Required for API Access) — steps (( role: reference ))
+
+ClawVisor is a credential gateway that sits between the
+agent and your APIs. The agent never sees your credentials — ClawVisor injects
+them at request time, enforces policies, and logs everything.
+
+> **What ClawVisor gives you:**
+- Credential vaulting — agent sees shadow tokens, never real secrets
+
+### Phase 0: ClawVisor Setup (Required for API Access) — steps 2 (( role: reference ))
+
+- Human approval gates — destructive operations (send email, modify calendar)
+  require your explicit approval
+
+### Phase 0: ClawVisor Setup (Required for API Access) — steps 3
+
+> 3. Set environment variables:
    ```bash
    gbrain config set clawvisor_url "https://app.clawvisor.com"
    gbrain config set clawvisor_agent_token "<token>"
    ```
-4. Activate Google services (Gmail, Calendar, Contacts) in the dashboard
-5. Create a standing task with expansive scope:
-   > "Full brain bootstrapping: read emails, calendar events, and contacts to
-   > populate knowledge base. List, read, and search across all connected accounts."
-6. Save the standing task ID:
+
+### Phase 0: ClawVisor Setup (Required for API Access) — steps 4
+
+> 6. Save the standing task ID:
    ```bash
    gbrain config set clawvisor_task_id "<task_id>"
    ```
 
+
+### Phase 0: ClawVisor Setup (Required for API Access) — steps 5
+
+use judgment to follow the Phase 0: ClawVisor Setup (Required for API Access) — steps 5 guidance:
 **Critical scoping rule:** Be expansive in task purposes. "Email triage" gets
 rejected by intent verification. "Full executive assistant email management
 including inbox triage, searching by any criteria, reading emails, tracking
 threads" works. The intent model uses the purpose to judge each request.
 
-### If the user declines ClawVisor
+### If the user declines ClawVisor (( role: reference ))
 
 Do NOT fall back to direct OAuth. Instead, skip Phases 2-4 (Contacts, Calendar,
 Gmail) and proceed with offline-only imports:
@@ -146,7 +164,7 @@
 
 ## Phase 1: Existing Markdown / Obsidian Import
 
-**The highest-leverage first import.** If the user already has a notes system, this
+If the user already has a notes system, this
 is hundreds or thousands of structured pages ready to go.
 
 ### Discovery
@@ -186,18 +204,18 @@
 - Start embeddings: `gbrain embed --stale` (runs in background)
 
 > **Track progress:**
-> ```bash
+> ````bash
 > echo '{"phase_1_complete": true, "pages_imported": N}' > ~/.gbrain/cold-start-state.json
-> ```
+> ````
 
 ## Phase 2: Google Contacts → People Pages
 
-**Seeds the people/ directory.** Every person in your contacts becomes a brain page
+Every person in your contacts becomes a brain page
 with name, email, phone, company, and notes. This is the foundation that all other
 imports build on — when Gmail references "john@acme.com", the brain already knows
 who John is.
 
-### Via ClawVisor
+### Via ClawVisor (( role: reference ))
 
 ```javascript
 // Fetch all contacts
@@ -214,20 +232,29 @@
   "https://people.googleapis.com/v1/people/me/connections?personFields=names,emailAddresses,phoneNumbers,organizations,biographies&pageSize=1000"
 ```
 
-### Processing rules
-
-For each contact:
+### Processing rules (( role: reference ))
+
 1. **Filter out noise** — skip contacts with no name, no email, or that are clearly
    automated (noreply@, no-reply@, support@, notifications@)
-2. **Check brain first** — `gbrain search "name"` to avoid duplicates
 3. **Create people/ page** with:
    - Name, email(s), phone(s), company, title
-   - Source attribution: `[Source: Google Contacts, YYYY-MM-DD]`
    - Any notes from the contact as initial context
 4. **Link to company** — if the contact has an organization, create/update the
    company page and link the person to it
 
-### Quality gate
+
+### Processing rules — steps
+
+For each contact:
+
+### Processing rules — steps 2
+
+2. Check brain first — `gbrain search "name"` to avoid duplicates
+
+### Processing rules — steps 3
+
+   - Source attribution: `[Source: Google Contacts, YYYY-MM-DD]`
+### Quality gate (( role: reference ))
 
 After importing 5 contacts, pause and show the user a sample page. Ask:
 > "Here's what a contact page looks like. Want me to continue with the rest, or
@@ -235,11 +262,11 @@
 
 ## Phase 3: Google Calendar (Last 90 Days)
 
-**Meeting history with attendee context.** Calendar events reveal who the user meets
+Calendar events reveal who the user meets
 with, how often, and in what context. Combined with contacts, this builds a rich
 relationship map.
 
-### Fetch events
+### Fetch events (( role: reference ))
 
 ```javascript
 // Via ClawVisor — query ALL calendar accounts
@@ -254,7 +281,7 @@
 }
 ```
 
-### Brain structure
+### Brain structure (( role: reference ))
 
 Follow the three-tier calendar architecture:
 ```
@@ -265,20 +292,23 @@
 │   └── YYYY-MM-DD.md            ← daily event log
 ```
 
-### Entity enrichment
-
-For each event with attendees:
+### Entity enrichment (( role: reference ))
+
 1. Look up each attendee in the brain (they should exist from Phase 2)
 2. Add a timeline entry to their page: met at [event title] on [date]
 3. If an attendee has no brain page and appears in 3+ events, create one
 4. Link attendees who appear in the same meeting
 
+
+### Entity enrichment — steps
+
+For each event with attendees:
 ## Phase 4: Gmail (Recent Threads)
 
-**Relationship context and active threads.** Email reveals organizational
+Email reveals organizational
 relationships, ongoing conversations, and communication patterns.
 
-### Strategy: Smart sampling, not bulk import
+### Strategy: Smart sampling, not bulk import (( role: reference ))
 
 Don't import every email. Import the **signal**:
 
@@ -287,30 +317,39 @@
 3. **Threads with 3+ replies** — active conversations worth tracking
 4. **Emails from people already in the brain** — enrichment, not cold import
 
-### Processing
-
-For each email thread:
+### Processing (( role: reference ))
+
 1. **Entity detection** — extract people, companies mentioned
 2. **Update people pages** — add communication context to timeline
 3. **Create meeting pages** — if the email is a meeting summary or follow-up
 4. **Skip noise** — newsletters, automated notifications, marketing
 
-### Filtering rules
-
-**Auto-skip (never import):**
+
+### Processing — steps
+
+For each email thread:
+### Filtering rules (( role: reference ))
+
 - noreply@, no-reply@, notifications@, support@, mailer-daemon@
 - Unsubscribe-heavy senders (marketing)
 - GitHub/Jira/Linear notification emails
 - Calendar invites (already captured in Phase 3)
 
-**Always import:**
 - Direct emails from people in the brain
 - Starred/flagged emails
 - Emails the user sent (their words are highest-value signal)
 
+
+### Filtering rules — steps
+
+Auto-skip (never import):
+
+### Filtering rules — steps 2
+
+Always import:
 ## Phase 5: Conversation Exports (ChatGPT / Claude / Perplexity)
 
-**Your thinking, captured.** AI conversation exports reveal what the user
+AI conversation exports reveal what the user
 was researching, building, and thinking about. This is original thinking
 preserved in dialog form.
 
@@ -320,38 +359,48 @@
 - **Claude:** Download from claude.ai conversation history
 - **Perplexity:** Export from settings
 
-### Processing
-
-For each conversation:
-1. **Assess significance** (1-5 scale):
+### Processing (( role: reference ))
+
    - 1 = Pure utility (how-tos, quick lookups) → skip or minimal page
    - 2 = Minor context → 1-paragraph note
    - 3 = Notable (reveals interests, building something) → full page
    - 4 = Important (deep personal processing, strategic thinking) → rich page
    - 5 = Defining (identity work, breakthrough insights) → full treatment
 2. **Extract entities** — people, companies, concepts discussed
-3. **Capture original thinking** — the user's exact phrasing is the signal.
-   Never paraphrase.
 4. **File by primary subject** — not in a "conversations/" dump. A conversation
    about a person goes to people/, about a concept goes to concepts/, etc.
 
-### Quality rule
+
+### Processing — steps
+
+For each conversation:
+
+### Processing — steps 2
+
+use judgment to follow the Processing — steps 2 guidance:
+1. **Assess significance** (1-5 scale):
+
+### Processing — steps 3
+
+3. Capture original thinking — the user's exact phrasing is the signal.
+   Never paraphrase.
+### Quality rule (( role: reference ))
 
 Only import conversations rated 3+. The brain is for signal, not noise.
 
 ## Phase 6: X/Twitter Archive
 
-**Your public positions and engagement patterns.** Twitter reveals what the user
+Twitter reveals what the user
 thinks, who they engage with, and what ideas they're developing publicly.
 
-### Data sources
+### Data sources (( role: reference ))
 
 1. **Twitter data export** (Settings → Your Account → Download Archive)
    - Contains all tweets, likes, DMs, bookmarks
 2. **Live API** (if available) — recent tweets and engagement
 3. **Bookmarks** — curated signal, high value
 
-### Brain structure
+### Brain structure (( role: reference ))
 
 ```
 brain/media/x/{handle}/
@@ -371,7 +420,7 @@
 
 ## Phase 7: File Archives
 
-**Historical documents, old writing, photos with metadata.** This is the long tail —
+This is the long tail —
 less structured but potentially very high value (old journals, letters, early writing).
 
 Delegate to the `archive-crawler` skill. It handles:
@@ -382,51 +431,39 @@
 
 > **Safety gate:** Archive crawling can be slow and create many pages. Always start
 > with a scan-only pass:
-> ```bash
+> ````bash
 > gbrain archive-crawler --scan-only --path /path/to/archive
-> ```
+> ````
 > Show the user the manifest before proceeding with full ingestion.
 
-**Supported sources:**
+Supported sources:
 - Local directories (Dropbox sync folder, Google Drive, old hard drives)
 - Cloud storage (Backblaze B2, S3) via mounted paths
 - Email archives (PST, mbox, EML, Google Takeout)
 - Data exports (LinkedIn, Facebook, etc.)
 
-## Phase 8: Meeting Transcripts
-
-**Deep relationship context from recorded calls.** If the user has a meeting
+## Phase 8: Meeting Transcripts (( role: reference ))
+
+- A meeting is NOT fully ingested until all entity pages are updated
+
+
+### Phase 8: Meeting Transcripts — steps
+
+If the user has a meeting
 recording service (Circleback, Otter, Fireflies, Read.ai), import recent
 transcripts.
 
 Delegate to `meeting-ingestion` skill. Key rules:
-- Always pull the **complete transcript**, not just the AI summary
+- Always pull the complete transcript, not just the AI summary
 - Entity propagation is MANDATORY — every attendee gets a timeline update
-- A meeting is NOT fully ingested until all entity pages are updated
-
-## Post-Bootstrap Checklist
+## Post-Bootstrap Checklist (( role: reference ))
 
 After completing available phases:
-
-1. **Verify brain health:**
-   ```bash
-   gbrain doctor --json
-   gbrain stats
-   ```
-
-2. **Test retrieval:**
-   ```bash
-   gbrain query "who do I meet with most often?"
-   gbrain query "what am I working on?"
-   gbrain search "<person from contacts>"
-   ```
 
 3. **Set up live sync** (if not already):
    - Calendar: daily cron
    - Email: periodic sweep (4-8 hours)
    - X: daily ingest
-   - Brain repo: `gbrain sync --repo <path>` every 5-30 minutes
-
 4. **Track state:**
    ```json
    // ~/.gbrain/cold-start-state.json
@@ -449,12 +486,29 @@
    > - The **executive-assistant** pattern handles email triage
    > - Say 'enrich [person]' to deep-dive any contact"
 
-## Anti-Patterns
-
-- **Giving the agent raw OAuth tokens.** This is the #1 anti-pattern. An agent with
-  raw Gmail/Calendar tokens is an uncontrolled attack surface — one prompt injection
-  and your entire Google account is exposed. Use ClawVisor. If the user declines
-  ClawVisor, skip to offline imports. Never offer direct OAuth as a fallback.
+
+### Post-Bootstrap Checklist — steps
+
+> 1. **Verify brain health:**
+   ```bash
+   gbrain doctor --json
+   gbrain stats
+   ```
+
+> 2. **Test retrieval:**
+   ```bash
+   gbrain query "who do I meet with most often?"
+   gbrain query "what am I working on?"
+   gbrain search "<person from contacts>"
+   ```
+
+
+### Post-Bootstrap Checklist — steps 2
+
+   - Brain repo: `gbrain sync --repo <path>` every 5-30 minutes
+
+## Anti-Patterns (( role: reference ))
+
 - **Bulk importing everything without filtering.** The brain is for signal, not noise.
   Filter out automated senders, marketing emails, utility conversations.
 - **Importing without entity cross-linking.** Every import should detect entities and
@@ -466,15 +520,22 @@
 - **Creating people pages for automated senders.** Sentry, GitHub notifications,
   newsletter platforms are not people. Filter by the rules in Phase 4.
 
-## Resume Protocol
-
-If the session is interrupted:
-
-1. Read `~/.gbrain/cold-start-state.json`
+
+### Anti-Patterns — steps (( role: reference ))
+
+- This is the #1 anti-pattern. An agent with raw Gmail/Calendar tokens is an uncontrolled attack surface — one prompt injection and your entire Google account is exposed. Use ClawVisor. If the user declines ClawVisor, skip to offline imports. Never offer direct OAuth as a fallback.
+## Resume Protocol (( role: reference ))
+
 2. Skip completed phases
 3. Resume from `next_phase`
 4. The user doesn't have to repeat credential setup or re-import completed sources
 
+
+### Resume Protocol — steps
+
+If the session is interrupted:
+
+1. Read `~/.gbrain/cold-start-state.json`
 ## Output Format
 
 After each phase:
```
