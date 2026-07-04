# Deviation: cold_start.meri

- Original: `cold-start/SKILL.md`
- Ported: `cold_start.meri`
- Tier: 2 (light edits)
- Similarity: 82%
- Lines: 507 -> 556 (+118 / -69)

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
- L101 `If the user declines ClawVisor`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L176 `Via ClawVisor`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L229 `Fetch events`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L244 `Brain structure`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L270 `Strategy: Smart sampling, not bulk import`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L331 `Quality rule`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L341 `Data sources`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L348 `Brain structure`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L488 `Output Format`: template - Template/output shape is metadata unless explicit output assertions are authored.
- L508 `Tools Used`: tools-metadata - Tools sections are metadata-mining, not workflow execution.

## Metrics
- Sections inert total: 12/36 (33% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert categories: reference-documentation=10, template=1, tools-metadata=1
- Judgment: 18 blocks, 0 lines

### Inert section details
- L101 `If the user declines ClawVisor`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L176 `Via ClawVisor`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L193 `Processing rules`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L229 `Fetch events`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L244 `Brain structure`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L270 `Strategy: Smart sampling, not bulk import`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L331 `Quality rule`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L341 `Data sources`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L348 `Brain structure`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L406 `Post-Bootstrap Checklist`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L488 `Output Format`: template — Template/output shape is metadata unless explicit output assertions are authored.
- L508 `Tools Used`: tools-metadata — Tools sections are metadata-mining, not workflow execution.

## Unified diff

```diff
--- original-skills/cold-start/SKILL.md
+++ skills/cold_start.meri
@@ -40,14 +40,15 @@
 
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
+## Contract (( role: procedure ))
+use judgment to follow the Contract guidance:
 
 - Every import phase is gated on user consent (ask-user pattern) before proceeding.
 - **Google/social API access goes through ClawVisor.** The agent never holds raw OAuth
@@ -61,16 +62,21 @@
   can resume.
 - Entity detection and cross-linking run on every import, not as a separate pass.
 
-## Prerequisites
+## Prerequisites (( role: procedure ))
+use judgment to follow the Prerequisites guidance:
 
 - GBrain installed and initialized (`gbrain doctor --json` all green)
 - Brain repo cloned and synced
 - Agent has terminal access and can run `gbrain` CLI commands
 
-## The Priority Stack
-
-Data sources ranked by **information density × ease of import**:
-
+## The Priority Stack (( inert ))
+
+
+### The Priority Stack — steps
+
+> Data sources ranked by **information density × ease of import**:
+
+!!! table (( ai-discretion ))
 | Priority | Source | Why | Time | Pages Created |
 |----------|--------|-----|------|---------------|
 | 1 | Existing markdown/Obsidian | Highest density — it's already structured | 5 min | 100s-1000s |
@@ -83,6 +89,7 @@
 | 8 | Meeting transcripts (Circleback/etc.) | Deep relationship context from recorded calls | 20 min | 10-50 |
 
 ## Phase 0: ClawVisor Setup (Required for API Access)
+use judgment to follow the Phase 0: ClawVisor Setup (Required for API Access) guidance:
 
 > **Safety boundary:** An AI agent with raw OAuth tokens to your Gmail, Calendar,
 > and Contacts is an uncontrolled attack surface. One prompt injection, one
@@ -105,26 +112,32 @@
 **Setup (15 min):**
 1. Sign up at [app.clawvisor.com](https://app.clawvisor.com)
 2. Create an agent in the dashboard, copy the agent token
-3. Set environment variables:
+4. Activate Google services (Gmail, Calendar, Contacts) in the dashboard
+5. Create a standing task with expansive scope:
+   > "Full brain bootstrapping: read emails, calendar events, and contacts to
+   > populate knowledge base. List, read, and search across all connected accounts."
+**Critical scoping rule:** Be expansive in task purposes. "Email triage" gets
+rejected by intent verification. "Full executive assistant email management
+including inbox triage, searching by any criteria, reading emails, tracking
+threads" works. The intent model uses the purpose to judge each request.
+
+
+### Phase 0: ClawVisor Setup (Required for API Access) — steps
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
+### Phase 0: ClawVisor Setup (Required for API Access) — steps 2
+
+> 6. Save the standing task ID:
    ```bash
    gbrain config set clawvisor_task_id "<task_id>"
    ```
 
-**Critical scoping rule:** Be expansive in task purposes. "Email triage" gets
-rejected by intent verification. "Full executive assistant email management
-including inbox triage, searching by any criteria, reading emails, tracking
-threads" works. The intent model uses the purpose to judge each request.
-
-### If the user declines ClawVisor
+### If the user declines ClawVisor (( inert ))
 
 Do NOT fall back to direct OAuth. Instead, skip Phases 2-4 (Contacts, Calendar,
 Gmail) and proceed with offline-only imports:
@@ -145,6 +158,7 @@
 credentials they shouldn't have.
 
 ## Phase 1: Existing Markdown / Obsidian Import
+use judgment to follow the Phase 1: Existing Markdown / Obsidian Import guidance:
 
 **The highest-leverage first import.** If the user already has a notes system, this
 is hundreds or thousands of structured pages ready to go.
@@ -186,18 +200,19 @@
 - Start embeddings: `gbrain embed --stale` (runs in background)
 
 > **Track progress:**
-> ```bash
+> ````bash
 > echo '{"phase_1_complete": true, "pages_imported": N}' > ~/.gbrain/cold-start-state.json
-> ```
+> ````
 
 ## Phase 2: Google Contacts → People Pages
+use judgment to follow the Phase 2: Google Contacts → People Pages guidance:
 
 **Seeds the people/ directory.** Every person in your contacts becomes a brain page
 with name, email, phone, company, and notes. This is the foundation that all other
 imports build on — when Gmail references "john@acme.com", the brain already knows
 who John is.
 
-### Via ClawVisor
+### Via ClawVisor (( inert ))
 
 ```javascript
 // Fetch all contacts
@@ -214,32 +229,43 @@
   "https://people.googleapis.com/v1/people/me/connections?personFields=names,emailAddresses,phoneNumbers,organizations,biographies&pageSize=1000"
 ```
 
-### Processing rules
-
-For each contact:
+### Processing rules (( inert ))
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
+#### Processing rules — steps
+
+For each contact:
+
+#### Processing rules — steps 2
+
+2. Check brain first — `gbrain search "name"` to avoid duplicates
+
+#### Processing rules — steps 3
+
+   - Source attribution: `[Source: Google Contacts, YYYY-MM-DD]`
+### Quality gate (( role: procedure ))
+use judgment to follow the Quality gate guidance:
 
 After importing 5 contacts, pause and show the user a sample page. Ask:
 > "Here's what a contact page looks like. Want me to continue with the rest, or
 > adjust the format first?"
 
 ## Phase 3: Google Calendar (Last 90 Days)
+use judgment to follow the Phase 3: Google Calendar (Last 90 Days) guidance:
 
 **Meeting history with attendee context.** Calendar events reveal who the user meets
 with, how often, and in what context. Combined with contacts, this builds a rich
 relationship map.
 
-### Fetch events
+### Fetch events (( inert ))
 
 ```javascript
 // Via ClawVisor — query ALL calendar accounts
@@ -254,7 +280,7 @@
 }
 ```
 
-### Brain structure
+### Brain structure (( inert ))
 
 Follow the three-tier calendar architecture:
 ```
@@ -266,6 +292,7 @@
 ```
 
 ### Entity enrichment
+use judgment to follow the Entity enrichment guidance:
 
 For each event with attendees:
 1. Look up each attendee in the brain (they should exist from Phase 2)
@@ -274,11 +301,12 @@
 4. Link attendees who appear in the same meeting
 
 ## Phase 4: Gmail (Recent Threads)
+use judgment to follow the Phase 4: Gmail (Recent Threads) guidance:
 
 **Relationship context and active threads.** Email reveals organizational
 relationships, ongoing conversations, and communication patterns.
 
-### Strategy: Smart sampling, not bulk import
+### Strategy: Smart sampling, not bulk import (( inert ))
 
 Don't import every email. Import the **signal**:
 
@@ -288,6 +316,7 @@
 4. **Emails from people already in the brain** — enrichment, not cold import
 
 ### Processing
+use judgment to follow the Processing guidance:
 
 For each email thread:
 1. **Entity detection** — extract people, companies mentioned
@@ -296,6 +325,7 @@
 4. **Skip noise** — newsletters, automated notifications, marketing
 
 ### Filtering rules
+use judgment to follow the Filtering rules guidance:
 
 **Auto-skip (never import):**
 - noreply@, no-reply@, notifications@, support@, mailer-daemon@
@@ -309,6 +339,7 @@
 - Emails the user sent (their words are highest-value signal)
 
 ## Phase 5: Conversation Exports (ChatGPT / Claude / Perplexity)
+use judgment to follow the Phase 5: Conversation Exports (ChatGPT / Claude / Perplexity) guidance:
 
 **Your thinking, captured.** AI conversation exports reveal what the user
 was researching, building, and thinking about. This is original thinking
@@ -321,6 +352,7 @@
 - **Perplexity:** Export from settings
 
 ### Processing
+use judgment to follow the Processing guidance:
 
 For each conversation:
 1. **Assess significance** (1-5 scale):
@@ -335,23 +367,24 @@
 4. **File by primary subject** — not in a "conversations/" dump. A conversation
    about a person goes to people/, about a concept goes to concepts/, etc.
 
-### Quality rule
+### Quality rule (( inert ))
 
 Only import conversations rated 3+. The brain is for signal, not noise.
 
 ## Phase 6: X/Twitter Archive
+use judgment to follow the Phase 6: X/Twitter Archive guidance:
 
 **Your public positions and engagement patterns.** Twitter reveals what the user
 thinks, who they engage with, and what ideas they're developing publicly.
 
-### Data sources
+### Data sources (( inert ))
 
 1. **Twitter data export** (Settings → Your Account → Download Archive)
    - Contains all tweets, likes, DMs, bookmarks
 2. **Live API** (if available) — recent tweets and engagement
 3. **Bookmarks** — curated signal, high value
 
-### Brain structure
+### Brain structure (( inert ))
 
 ```
 brain/media/x/{handle}/
@@ -370,6 +403,7 @@
 - **Likes** — low signal, skip unless the user wants them
 
 ## Phase 7: File Archives
+use judgment to follow the Phase 7: File Archives guidance:
 
 **Historical documents, old writing, photos with metadata.** This is the long tail —
 less structured but potentially very high value (old journals, letters, early writing).
@@ -382,9 +416,9 @@
 
 > **Safety gate:** Archive crawling can be slow and create many pages. Always start
 > with a scan-only pass:
-> ```bash
+> ````bash
 > gbrain archive-crawler --scan-only --path /path/to/archive
-> ```
+> ````
 > Show the user the manifest before proceeding with full ingestion.
 
 **Supported sources:**
@@ -394,39 +428,28 @@
 - Data exports (LinkedIn, Facebook, etc.)
 
 ## Phase 8: Meeting Transcripts
-
-**Deep relationship context from recorded calls.** If the user has a meeting
-recording service (Circleback, Otter, Fireflies, Read.ai), import recent
-transcripts.
-
-Delegate to `meeting-ingestion` skill. Key rules:
+use judgment to follow the Phase 8: Meeting Transcripts guidance:
+
 - Always pull the **complete transcript**, not just the AI summary
 - Entity propagation is MANDATORY — every attendee gets a timeline update
 - A meeting is NOT fully ingested until all entity pages are updated
 
-## Post-Bootstrap Checklist
+
+### Phase 8: Meeting Transcripts — steps
+
+If the user has a meeting
+recording service (Circleback, Otter, Fireflies, Read.ai), import recent
+transcripts.
+
+Delegate to `meeting-ingestion` skill. Key rules:
+## Post-Bootstrap Checklist (( inert ))
 
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
@@ -449,7 +472,29 @@
    > - The **executive-assistant** pattern handles email triage
    > - Say 'enrich [person]' to deep-dive any contact"
 
-## Anti-Patterns
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
+## Anti-Patterns (( role: procedure ))
+use judgment to follow the Anti-Patterns guidance:
 
 - **Giving the agent raw OAuth tokens.** This is the #1 anti-pattern. An agent with
   raw Gmail/Calendar tokens is an uncontrolled attack surface — one prompt injection
@@ -467,14 +512,18 @@
   newsletter platforms are not people. Filter by the rules in Phase 4.
 
 ## Resume Protocol
-
-If the session is interrupted:
-
-1. Read `~/.gbrain/cold-start-state.json`
+use judgment to follow the Resume Protocol guidance:
+
 2. Skip completed phases
 3. Resume from `next_phase`
 4. The user doesn't have to repeat credential setup or re-import completed sources
 
+
+### Resume Protocol — steps
+
+> If the session is interrupted:
+
+1. Read `~/.gbrain/cold-start-state.json`
 ## Output Format
 
 After each phase:
```
