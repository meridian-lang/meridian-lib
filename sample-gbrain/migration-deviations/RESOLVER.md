# Deviation: RESOLVER.meri

- Original: `RESOLVER.md`
- Ported: `RESOLVER.meri`
- Tier: 2 (light edits)
- Similarity: 80%
- Lines: 136 -> 173 (+50 / -13)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- preamble-blockquoted

## Metrics
- Sections inert total: 2/2 (100% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert categories: reference-documentation=2
- Judgment: 0 blocks, 0 lines

### Inert section details
- L124 `Disambiguation rules`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L136 `Conventions (cross-cutting)`: reference-documentation — Reference documentation, rationale, examples, or changelog.

## Unified diff

```diff
--- original-skills/RESOLVER.md
+++ RESOLVER.meri
@@ -1,16 +1,23 @@
 # GBrain Skill Resolver
 
-This is the dispatcher. Skills are the implementation. **Read the skill file before acting.** If two skills could match, read both. They are designed to chain (e.g., ingest then enrich for each entity).
+> This is the dispatcher. Skills are the implementation. **Read the skill file before acting.** If two skills could match, read both. They are designed to chain (e.g., ingest then enrich for each entity).
 
-## Always-on (every message)
+## Always-on (every message) (( inert ))
+
+
+### Always-on (every message) — steps
 
 | Trigger | Skill |
 |---------|-------|
 | Every inbound message (spawn parallel, don't block) | `skills/signal-detector/SKILL.md` |
 | Any brain read/write/lookup/citation | `skills/brain-ops/SKILL.md` |
 
-## Brain operations
+## Brain operations (( inert ))
 
+
+### Brain operations — steps
+
+!!! table (( ai-discretion ))
 | Trigger | Skill |
 |---------|-------|
 | "What do we know about", "tell me about", "search for", "who is", "background on", "notes on" | `skills/query/SKILL.md` |
@@ -27,8 +34,12 @@
 | "what search mode", "is my cache hot", "tune my retrieval", "compare search modes", "clear search overrides" | `gbrain search modes/stats/tune` directly. See `skills/conventions/search-modes.md` |
 | "eval results", "search benchmark", "haters-immune methodology", "regression check on retrieval" | `gbrain eval run-all` / `gbrain eval compare`. See `docs/eval/SEARCH_MODE_METHODOLOGY.md` |
 
-## Content & media ingestion
+## Content & media ingestion (( inert ))
 
+
+### Content & media ingestion — steps
+
+!!! table (( ai-discretion ))
 | Trigger | Skill |
 |---------|-------|
 | "capture this", "save this thought", "remember this", "drop this in the inbox", "save to brain" | `skills/capture/SKILL.md` |
@@ -37,8 +48,12 @@
 | Meeting transcript received | `skills/meeting-ingestion/SKILL.md` |
 | Generic "ingest this" (auto-routes to above) | `skills/ingest/SKILL.md` |
 
-## Thinking skills (from GStack)
+## Thinking skills (from GStack) (( inert ))
 
+
+### Thinking skills (from GStack) — steps
+
+!!! table (( ai-discretion ))
 | Trigger | Skill |
 |---------|-------|
 | "Brainstorm", "I have an idea", "office hours" | GStack: office-hours |
@@ -49,7 +64,10 @@
 > These skills come from GStack. If GStack is installed, the agent reads them directly.
 > If not, brain-only mode still works (brain skills function without thinking skills).
 
-## Operational
+## Operational (( inert ))
+
+
+### Operational — steps
 
 | Trigger | Skill |
 |---------|-------|
@@ -70,8 +88,12 @@
 | "Spawn agent", "background task", "parallel tasks", "steer agent", "pause/resume agent", "gbrain jobs submit", "submit a gbrain job", "submit a shell job", "shell job" | `skills/minion-orchestrator/SKILL.md` |
 | "present options", "ask before proceeding", "choice gate", "user decision" | `skills/ask-user/SKILL.md` |
 
-## Setup & migration
+## Setup & migration (( inert ))
 
+
+### Setup & migration — steps
+
+!!! table (( ai-discretion ))
 | Trigger | Skill |
 |---------|-------|
 | "Set up GBrain", first boot | `skills/setup/SKILL.md` |
@@ -87,7 +109,10 @@
 | "Populate links", "extract links", "backfill graph" | `skills/maintain/SKILL.md` (graph population phase) |
 | "Populate timeline", "extract timeline entries" | `skills/maintain/SKILL.md` (graph population phase) |
 
-## Identity & access (always-on)
+## Identity & access (always-on) (( inert ))
+
+
+### Identity & access (always-on) — steps
 
 | Trigger | Skill |
 |---------|-------|
@@ -96,28 +121,40 @@
 | Agent needs user context | Read `USER.md` |
 | Operational cadence (what to check and when) | Read `HEARTBEAT.md` |
 
-## Disambiguation rules
+## Disambiguation rules (( inert ))
 
 When multiple skills could match:
 1. Prefer the most specific skill (meeting-ingestion over ingest)
 2. If the user mentions a URL, route by content type (link → idea-ingest, video → media-ingest)
 3. If the user mentions a person/company, check if enrich or query fits better
+
+### Disambiguation rules — steps (( inert ))
+
 4. Chaining is explicit in each skill's Phases section
 5. When in doubt, ask the user (see `skills/ask-user/SKILL.md` for the choice-gate pattern)
 
-## Conventions (cross-cutting)
+## Conventions (cross-cutting) (( inert ))
 
-These apply to ALL brain-writing skills:
+- `skills/conventions/schema-evolution.md` — when to add a type vs alias vs prefix (read before `schema-author`)
+
+### Conventions (cross-cutting) — steps
+
+> These apply to ALL brain-writing skills:
 - `skills/conventions/quality.md` — citations, back-links, notability gate
 - `skills/conventions/brain-first.md` — check brain before external APIs
 - `skills/conventions/brain-routing.md` — which brain (DB) and which source (repo) to target; cross-brain federation is latent-space only
-- `skills/conventions/schema-evolution.md` — when to add a type vs alias vs prefix (read before `schema-author`)
+
+### Conventions (cross-cutting) — steps 2
+
 - `skills/conventions/subagent-routing.md` — when to use Minions vs inline work
 - `skills/ask-user/SKILL.md` — choice-gate pattern for human input at decision points
 - `skills/_brain-filing-rules.md` — where files go
 - `skills/_output-rules.md` — output quality standards
 
-## Uncategorized
+## Uncategorized (( inert ))
+
+
+### Uncategorized — steps
 
 | Trigger | Skill |
 |---------|-------|
```
