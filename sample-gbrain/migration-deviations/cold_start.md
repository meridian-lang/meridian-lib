# Deviation: cold_start.meri

- Original: `cold-start/SKILL.md`
- Ported: `cold_start.meri`
- Tier: 1 (near-verbatim)
- Similarity: 92%
- Lines: 507 -> 507 (+43 / -43)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- shell-block-routed
- preamble-blockquoted

## Unified diff

```diff
--- original-skills/cold-start/SKILL.md
+++ skills/cold_start.meri
@@ -40,14 +40,14 @@
 
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
+## Contract (( inert, role: invariants ))
 
 - Every import phase is gated on user consent (ask-user pattern) before proceeding.
 - **Google/social API access goes through ClawVisor.** The agent never holds raw OAuth
@@ -61,13 +61,13 @@
   can resume.
 - Entity detection and cross-linking run on every import, not as a separate pass.
 
-## Prerequisites
+## Prerequisites (( inert ))
 
 - GBrain installed and initialized (`gbrain doctor --json` all green)
 - Brain repo cloned and synced
 - Agent has terminal access and can run `gbrain` CLI commands
 
-## The Priority Stack
+## The Priority Stack (( inert ))
 
 Data sources ranked by **information density × ease of import**:
 
@@ -82,7 +82,7 @@
 | 7 | File archives (Dropbox/Drive/local) | Historical documents, old writing, photos | 30+ min | varies |
 | 8 | Meeting transcripts (Circleback/etc.) | Deep relationship context from recorded calls | 20 min | 10-50 |
 
-## Phase 0: ClawVisor Setup (Required for API Access)
+## Phase 0: ClawVisor Setup (Required for API Access) (( inert, role: procedure ))
 
 > **Safety boundary:** An AI agent with raw OAuth tokens to your Gmail, Calendar,
 > and Contacts is an uncontrolled attack surface. One prompt injection, one
@@ -124,7 +124,7 @@
 including inbox triage, searching by any criteria, reading emails, tracking
 threads" works. The intent model uses the purpose to judge each request.
 
-### If the user declines ClawVisor
+### If the user declines ClawVisor (( inert ))
 
 Do NOT fall back to direct OAuth. Instead, skip Phases 2-4 (Contacts, Calendar,
 Gmail) and proceed with offline-only imports:
@@ -144,12 +144,12 @@
 tokens is a security liability. The skill should not teach agents to store
 credentials they shouldn't have.
 
-## Phase 1: Existing Markdown / Obsidian Import
+## Phase 1: Existing Markdown / Obsidian Import (( inert, role: procedure ))
 
 **The highest-leverage first import.** If the user already has a notes system, this
 is hundreds or thousands of structured pages ready to go.
 
-### Discovery
+### Discovery (( role: procedure ))
 
 ```bash
 echo "=== Markdown Repository Discovery ==="
@@ -165,7 +165,7 @@
 done
 ```
 
-### Import
+### Import (( role: procedure ))
 
 ```bash
 # For Obsidian vaults, use the migrate skill for proper wikilink handling
@@ -179,7 +179,7 @@
 gbrain search "<topic from the imported data>"
 ```
 
-### Post-import
+### Post-import (( inert ))
 
 - Run link extraction: `gbrain extract links --source db`
 - Run timeline extraction: `gbrain extract timeline --source db`
@@ -190,14 +190,14 @@
 > echo '{"phase_1_complete": true, "pages_imported": N}' > ~/.gbrain/cold-start-state.json
 > ```
 
-## Phase 2: Google Contacts → People Pages
+## Phase 2: Google Contacts → People Pages (( inert, role: procedure ))
 
 **Seeds the people/ directory.** Every person in your contacts becomes a brain page
 with name, email, phone, company, and notes. This is the foundation that all other
 imports build on — when Gmail references "john@acme.com", the brain already knows
 who John is.
 
-### Via ClawVisor
+### Via ClawVisor (( inert ))
 
 ```javascript
 // Fetch all contacts
@@ -207,14 +207,14 @@
 });
 ```
 
-### Via direct Google People API
+### Via direct Google People API (( role: procedure ))
 
 ```bash
 curl -s -H "Authorization: Bearer $GOOGLE_TOKEN" \
   "https://people.googleapis.com/v1/people/me/connections?personFields=names,emailAddresses,phoneNumbers,organizations,biographies&pageSize=1000"
 ```
 
-### Processing rules
+### Processing rules (( inert ))
 
 For each contact:
 1. **Filter out noise** — skip contacts with no name, no email, or that are clearly
@@ -227,19 +227,19 @@
 4. **Link to company** — if the contact has an organization, create/update the
    company page and link the person to it
 
-### Quality gate
+### Quality gate (( inert ))
 
 After importing 5 contacts, pause and show the user a sample page. Ask:
 > "Here's what a contact page looks like. Want me to continue with the rest, or
 > adjust the format first?"
 
-## Phase 3: Google Calendar (Last 90 Days)
+## Phase 3: Google Calendar (Last 90 Days) (( inert, role: procedure ))
 
 **Meeting history with attendee context.** Calendar events reveal who the user meets
 with, how often, and in what context. Combined with contacts, this builds a rich
 relationship map.
 
-### Fetch events
+### Fetch events (( inert ))
 
 ```javascript
 // Via ClawVisor — query ALL calendar accounts
@@ -254,7 +254,7 @@
 }
 ```
 
-### Brain structure
+### Brain structure (( inert ))
 
 Follow the three-tier calendar architecture:
 ```
@@ -265,7 +265,7 @@
 │   └── YYYY-MM-DD.md            ← daily event log
 ```
 
-### Entity enrichment
+### Entity enrichment (( inert ))
 
 For each event with attendees:
 1. Look up each attendee in the brain (they should exist from Phase 2)
@@ -273,12 +273,12 @@
 3. If an attendee has no brain page and appears in 3+ events, create one
 4. Link attendees who appear in the same meeting
 
-## Phase 4: Gmail (Recent Threads)
+## Phase 4: Gmail (Recent Threads) (( inert, role: procedure ))
 
 **Relationship context and active threads.** Email reveals organizational
 relationships, ongoing conversations, and communication patterns.
 
-### Strategy: Smart sampling, not bulk import
+### Strategy: Smart sampling, not bulk import (( inert ))
 
 Don't import every email. Import the **signal**:
 
@@ -287,7 +287,7 @@
 3. **Threads with 3+ replies** — active conversations worth tracking
 4. **Emails from people already in the brain** — enrichment, not cold import
 
-### Processing
+### Processing (( inert ))
 
 For each email thread:
 1. **Entity detection** — extract people, companies mentioned
@@ -295,7 +295,7 @@
 3. **Create meeting pages** — if the email is a meeting summary or follow-up
 4. **Skip noise** — newsletters, automated notifications, marketing
 
-### Filtering rules
+### Filtering rules (( inert ))
 
 **Auto-skip (never import):**
 - noreply@, no-reply@, notifications@, support@, mailer-daemon@
@@ -308,19 +308,19 @@
 - Starred/flagged emails
 - Emails the user sent (their words are highest-value signal)
 
-## Phase 5: Conversation Exports (ChatGPT / Claude / Perplexity)
+## Phase 5: Conversation Exports (ChatGPT / Claude / Perplexity) (( inert, role: procedure ))
 
 **Your thinking, captured.** AI conversation exports reveal what the user
 was researching, building, and thinking about. This is original thinking
 preserved in dialog form.
 
-### Supported formats
+### Supported formats (( inert ))
 
 - **ChatGPT:** Settings → Data Controls → Export → `conversations.json`
 - **Claude:** Download from claude.ai conversation history
 - **Perplexity:** Export from settings
 
-### Processing
+### Processing (( inert ))
 
 For each conversation:
 1. **Assess significance** (1-5 scale):
@@ -335,23 +335,23 @@
 4. **File by primary subject** — not in a "conversations/" dump. A conversation
    about a person goes to people/, about a concept goes to concepts/, etc.
 
-### Quality rule
+### Quality rule (( inert ))
 
 Only import conversations rated 3+. The brain is for signal, not noise.
 
-## Phase 6: X/Twitter Archive
+## Phase 6: X/Twitter Archive (( inert, role: procedure ))
 
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
@@ -361,7 +361,7 @@
 └── bookmarks/                   ← saved/bookmarked content
 ```
 
-### Processing
+### Processing (( inert ))
 
 - **Original tweets** → capture with full context, extract entities
 - **Quote tweets** → capture the user's commentary + the source tweet
@@ -369,7 +369,7 @@
 - **Bookmarks** → high-signal curation, import with tags
 - **Likes** — low signal, skip unless the user wants them
 
-## Phase 7: File Archives
+## Phase 7: File Archives (( inert, role: procedure ))
 
 **Historical documents, old writing, photos with metadata.** This is the long tail —
 less structured but potentially very high value (old journals, letters, early writing).
@@ -393,7 +393,7 @@
 - Email archives (PST, mbox, EML, Google Takeout)
 - Data exports (LinkedIn, Facebook, etc.)
 
-## Phase 8: Meeting Transcripts
+## Phase 8: Meeting Transcripts (( inert, role: procedure ))
 
 **Deep relationship context from recorded calls.** If the user has a meeting
 recording service (Circleback, Otter, Fireflies, Read.ai), import recent
@@ -404,7 +404,7 @@
 - Entity propagation is MANDATORY — every attendee gets a timeline update
 - A meeting is NOT fully ingested until all entity pages are updated
 
-## Post-Bootstrap Checklist
+## Post-Bootstrap Checklist (( inert ))
 
 After completing available phases:
 
@@ -449,7 +449,7 @@
    > - The **executive-assistant** pattern handles email triage
    > - Say 'enrich [person]' to deep-dive any contact"
 
-## Anti-Patterns
+## Anti-Patterns (( inert, role: prohibitions ))
 
 - **Giving the agent raw OAuth tokens.** This is the #1 anti-pattern. An agent with
   raw Gmail/Calendar tokens is an uncontrolled attack surface — one prompt injection
@@ -466,7 +466,7 @@
 - **Creating people pages for automated senders.** Sentry, GitHub notifications,
   newsletter platforms are not people. Filter by the rules in Phase 4.
 
-## Resume Protocol
+## Resume Protocol (( inert ))
 
 If the session is interrupted:
 
@@ -495,7 +495,7 @@
 Next: Phase N+1 — [description]. Ready to proceed?
 ```
 
-## Tools Used
+## Tools Used (( inert ))
 
 - `search` — check for existing pages before creating
 - `query` — hybrid search for entity deduplication
```
