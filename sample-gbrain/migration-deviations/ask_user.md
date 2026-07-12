# Deviation: ask_user.meri

- Original: `ask-user/SKILL.md`
- Ported: `ask_user.meri`
- Tier: 2 (light edits)
- Similarity: 79%
- Lines: 254 -> 288 (+75 / -41)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- doc-section-marked

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L20 `What This Is`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L32 `When To Use`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L53 `Platform-agnostic format (works everywhere)`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L68 `With inline buttons (Telegram, Discord, Slack)`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L83 `With the `clarify` tool (OpenClaw agents)`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L128 `How To Handle The Response`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L137 `Handling text responses`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L147 `Question line emoji prefix`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L175 `Cold-start phase gate`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L188 `Filing decision`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L201 `Destructive operation`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L255 `Output Format`: template - Template/output shape is metadata unless explicit output assertions are authored.

## Metrics
- generated_loc: 190 non-blank ported lines
- Sections inert total: 18/19 (95% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert markers (`(( inert ))`, target 0 — the migrator never emits these): 0
- Inert categories: reference-documentation=17, template=1
- Judgment: 3 blocks, 0 lines
- canonical_drift: synonym=8, structure=0, desugar=0, meaning=188

### Inert section details
- L4 `Contract`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L20 `What This Is`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L32 `When To Use`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L41 `When NOT To Use`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L53 `Platform-agnostic format (works everywhere)`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L68 `With inline buttons (Telegram, Discord, Slack)`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L83 `With the `clarify` tool (OpenClaw agents)`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L99 `Constraints`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L109 `How To Gate (CRITICAL)`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L128 `How To Handle The Response`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L137 `Handling text responses`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L147 `Question line emoji prefix`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L175 `Cold-start phase gate`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L188 `Filing decision`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L201 `Destructive operation`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L214 `Integration With Other Skills`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L230 `Anti-Patterns`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L255 `Output Format`: template — Template/output shape is metadata unless explicit output assertions are authored.

## Unified diff

```diff
--- original-skills/ask-user/SKILL.md
+++ skills/ask_user.meri
@@ -16,17 +16,23 @@
 
 # Ask User — Choice Gate Pattern
 
-## Contract
+## Contract (( role: reference ))
 
 - Present 2-4 options (no more — decision paralysis kicks in past 4).
-- Always include an escape hatch (Skip, Cancel, or "none of these").
 - Stop the turn immediately after presenting choices. No follow-up tool calls,
   no preemptive action, no default-and-proceed.
 - The user's response triggers the next turn. Acknowledge briefly, then branch.
+- Self-explanatory option labels: action verb plus brief qualifier, not "Option 1".
+
+
+### Contract — steps (( role: reference ))
+
+- Always include an escape hatch (Skip, Cancel, or "none of these").
+
+### Contract — steps 2 (( role: reference ))
+
 - One question per message — never stack multiple choice gates.
-- Self-explanatory option labels: action verb plus brief qualifier, not "Option 1".
-
-## What This Is
+## What This Is (( role: reference ))
 
 A **formalized pattern** for presenting users with 2-4 options and **stopping
 execution** until they respond. This is the canonical way to gate on user input
@@ -38,7 +44,7 @@
 3. The user's response triggers the next turn
 4. Read the response and branch accordingly
 
-## When To Use
+## When To Use (( role: reference ))
 
 - Ambiguous requests with multiple valid interpretations
 - Destructive operations (bulk deletes, overwrites)
@@ -47,16 +53,19 @@
 - Cold-start phase gates ("ready for the next import source?")
 - Any fork where the wrong default wastes significant work
 
-## When NOT To Use
+## When NOT To Use (( role: reference ))
 
 - Clear, unambiguous instructions → just do it
 - Low-stakes decisions → pick the best option and mention it
+- When the user has already expressed a preference
+
+
+### When NOT To Use — steps
+
 - Time-critical operations where delay costs more than a wrong choice
-- When the user has already expressed a preference
-
-## How To Present Choices
-
-### Platform-agnostic format (works everywhere)
+## How To Present Choices (( role: reference ))
+
+### Platform-agnostic format (works everywhere) (( role: reference ))
 
 Present choices as a clear question with numbered or labeled options:
 
@@ -71,7 +80,7 @@
 4. **Skip** — do nothing for now
 ```
 
-### With inline buttons (Telegram, Discord, Slack)
+### With inline buttons (Telegram, Discord, Slack) (( role: reference ))
 
 If the platform supports interactive buttons, use them:
 
@@ -86,7 +95,7 @@
 }
 ```
 
-### With the `clarify` tool (OpenClaw agents)
+### With the `clarify` tool (OpenClaw agents) (( role: reference ))
 
 Some OpenClaw agents have a built-in `clarify` tool that presents choices natively:
 
@@ -102,17 +111,18 @@
 )
 ```
 
-## Constraints
+## Constraints (( role: reference ))
 
 - **2-4 options max.** More than 4 creates decision paralysis.
 - **Labels must be self-explanatory.** The user shouldn't need to re-read context.
 - **Always include an escape hatch.** At minimum: "Skip" or "Cancel" as the last option.
-- **One question per message.** Never stack multiple choice gates.
-
-## How To Gate (CRITICAL)
-
-After presenting choices, **you MUST stop your turn.** Do not:
-- ❌ Continue with "while you decide, I'll start on..."
+
+### Constraints — steps (( role: reference ))
+
+- Never stack multiple choice gates.
+
+## How To Gate (CRITICAL) (( role: reference ))
+
 - ❌ Pick a default and proceed
 - ❌ Send follow-up messages before the user responds
 - ❌ Make assumptions about which option they'll pick
@@ -121,7 +131,16 @@
 - ✅ End your message with a brief note that you're waiting
 - ✅ Stop. Full stop. No more tool calls.
 
-## How To Handle The Response
+
+### How To Gate (CRITICAL) — steps (( role: reference ))
+
+After presenting choices, you MUST stop your turn. Do not:
+
+### How To Gate (CRITICAL) — steps 2
+
+use judgment to follow the How To Gate (CRITICAL) — steps 2 guidance:
+- ❌ Continue with "while you decide, I'll start on..."
+## How To Handle The Response (( role: reference ))
 
 When the user responds:
 
@@ -130,7 +149,7 @@
 3. **Branch and execute** the chosen path
 4. If unclear, ask again
 
-### Handling text responses
+### Handling text responses (( role: reference ))
 
 Users sometimes type instead of clicking. Handle gracefully:
 - "the first one" / "A" / "1" → map to first option
@@ -138,9 +157,9 @@
 - "actually, none of those" → present alternatives or ask what they want
 - Unrelated message → the user moved on; drop the gate
 
-## Formatting Guidelines
-
-### Question line emoji prefix
+## Formatting Guidelines (( role: reference ))
+
+### Question line emoji prefix (( role: reference ))
 
 Signal the decision type:
 - 🔀 Routing/filing decisions
@@ -152,6 +171,10 @@
 
 ### Context block
 
+
+### Context block — steps
+
+use judgment to follow the Context block — steps guidance:
 1-3 lines maximum. The user should understand the decision in under 5 seconds.
 
 ### Button/option labels
@@ -162,9 +185,9 @@
 - ❌ "Option 1"
 - ❌ "Click here to merge the content into the existing brain page"
 
-## Examples
-
-### Cold-start phase gate
+## Examples (( role: reference ))
+
+### Cold-start phase gate (( role: reference ))
 ```
 📋 **Phase 2: Google Contacts**
 
@@ -177,7 +200,7 @@
 4. **Skip** — move to the next phase
 ```
 
-### Filing decision
+### Filing decision (( role: reference ))
 ```
 🔀 **Where should this go?**
 
@@ -190,7 +213,7 @@
 4. **Skip** — don't file this
 ```
 
-### Destructive operation
+### Destructive operation (( role: reference ))
 ```
 ⚠️ **About to delete 847 stale cache files (2.3 GB)**
 
@@ -203,7 +226,7 @@
 4. **Show me the list** — let me review before deciding
 ```
 
-## Integration With Other Skills
+## Integration With Other Skills (( role: reference ))
 
 This pattern is used by:
 - **cold-start** — phase gates for each import source
@@ -213,27 +236,38 @@
 - **meeting-ingestion** — where to file meeting notes
 - **archive-crawler** — scan vs full ingestion gate
 
+
+### Integration With Other Skills — steps
+
 When building a new skill that needs user input at a decision point,
 reference this pattern rather than inventing a new one.
 
-## Anti-Patterns
-
-- **Continuing the turn after presenting choices.** "While you decide, I'll start on..."
-  defeats the gate. Stop. Wait. The whole point is that the user controls what happens next.
+## Anti-Patterns (( role: reference ))
+
 - **Picking a default and proceeding silently.** If the question matters enough to ask,
   it matters enough to wait. Silent defaults erode trust the next time you do ask.
 - **More than 4 options.** Decision paralysis is real. Group, summarize, or split into
   staged questions instead.
-- **No escape hatch.** Every choice gate must let the user decline. "None of these"
-  / "Skip" / "Cancel" is mandatory.
 - **Stacking multiple choice gates in one message.** The user can only answer one
   question per turn. Multi-question gates either get half-answered or dropped entirely.
-- **Cryptic option labels.** "Option 1" forces re-reading the context. "Merge into
-  existing page" is self-explanatory.
 - **Asking about low-stakes decisions.** If the wrong answer costs nothing, just pick
   the best option and mention it. Reserve gates for forks where rework is expensive.
 
-## Output Format
+
+### Anti-Patterns — steps (( role: reference ))
+
+use judgment to follow the Anti-Patterns — steps guidance:
+- **Continuing the turn after presenting choices.** "While you decide, I'll start on..."
+  defeats the gate. Stop. Wait. The whole point is that the user controls what happens next.
+
+### Anti-Patterns — steps 2
+
+- Every choice gate must let the user decline. "None of these" / "Skip" / "Cancel" is mandatory.
+
+### Anti-Patterns — steps 3
+
+- "Option 1" forces re-reading the context. "Merge into existing page" is self-explanatory.
+## Output Format (( role: template ))
 
 The skill's "output" is the choice-gate message itself, structured as:
 
```
