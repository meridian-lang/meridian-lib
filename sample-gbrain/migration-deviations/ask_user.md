# Deviation: ask_user.meri

- Original: `ask-user/SKILL.md`
- Ported: `ask_user.meri`
- Tier: 2 (light edits)
- Similarity: 83%
- Lines: 254 -> 260 (+47 / -41)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- shell-block-routed

## Metrics
- Sections: 19/24 inert (79% inert ratio)
- Operational inert: 0
- Unclassified inert: 0
- Inert categories: reference-documentation=18, template=1
- Judgment: 0 blocks, 0 lines

### Inert section details
- L19 `What This Is`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L47 `How To Present Choices`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L49 `Platform-agnostic format (works everywhere)`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L64 `With inline buttons (Telegram, Discord, Slack)`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L79 `With the `clarify` tool (OpenClaw agents)`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L95 `Constraints`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L102 `How To Gate (CRITICAL)`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L114 `How To Handle The Response`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L123 `Handling text responses`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L131 `Formatting Guidelines`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L133 `Question line emoji prefix`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L143 `Context block`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L147 `Button/option labels`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L155 `Examples`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L157 `Cold-start phase gate`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L170 `Filing decision`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L183 `Destructive operation`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L196 `Integration With Other Skills`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L227 `Output Format`: template — Template/output shape is metadata unless explicit output assertions are authored.

## Unified diff

```diff
--- original-skills/ask-user/SKILL.md
+++ skills/ask_user.meri
@@ -16,17 +16,22 @@
 
 # Ask User — Choice Gate Pattern
 
-## Contract
-
-- Present 2-4 options (no more — decision paralysis kicks in past 4).
-- Always include an escape hatch (Skip, Cancel, or "none of these").
-- Stop the turn immediately after presenting choices. No follow-up tool calls,
+## Contract (( role: procedure ))
+
+!!! checklist (( ai-autonomy ))
+- [ ] Present 2-4 options (no more — decision paralysis kicks in past 4).
+- [ ] Always include an escape hatch (Skip, Cancel, or "none of these").
+- [ ] Stop the turn immediately after presenting choices. No follow-up tool calls,
   no preemptive action, no default-and-proceed.
-- The user's response triggers the next turn. Acknowledge briefly, then branch.
-- One question per message — never stack multiple choice gates.
-- Self-explanatory option labels: action verb plus brief qualifier, not "Option 1".
-
-## What This Is
+- [ ] The user's response triggers the next turn. Acknowledge briefly, then branch.
+- [ ] One question per message — never stack multiple choice gates.
+- [ ] Self-explanatory option labels: action verb plus brief qualifier, not "Option 1".
+
+## Phases
+
+ask the user to choose between "Proceed", "Adjust", or "Skip".
+
+## What This Is (( inert ))
 
 A **formalized pattern** for presenting users with 2-4 options and **stopping
 execution** until they respond. This is the canonical way to gate on user input
@@ -52,11 +57,11 @@
 - Clear, unambiguous instructions → just do it
 - Low-stakes decisions → pick the best option and mention it
 - Time-critical operations where delay costs more than a wrong choice
-- When the user has already expressed a preference
-
-## How To Present Choices
-
-### Platform-agnostic format (works everywhere)
+- the user already stated a preference
+
+## How To Present Choices (( inert ))
+
+### Platform-agnostic format (works everywhere) (( inert ))
 
 Present choices as a clear question with numbered or labeled options:
 
@@ -71,7 +76,7 @@
 4. **Skip** — do nothing for now
 ```
 
-### With inline buttons (Telegram, Discord, Slack)
+### With inline buttons (Telegram, Discord, Slack) (( inert ))
 
 If the platform supports interactive buttons, use them:
 
@@ -86,7 +91,7 @@
 }
 ```
 
-### With the `clarify` tool (OpenClaw agents)
+### With the `clarify` tool (OpenClaw agents) (( inert ))
 
 Some OpenClaw agents have a built-in `clarify` tool that presents choices natively:
 
@@ -102,14 +107,14 @@
 )
 ```
 
-## Constraints
+## Constraints (( inert ))
 
 - **2-4 options max.** More than 4 creates decision paralysis.
 - **Labels must be self-explanatory.** The user shouldn't need to re-read context.
 - **Always include an escape hatch.** At minimum: "Skip" or "Cancel" as the last option.
 - **One question per message.** Never stack multiple choice gates.
 
-## How To Gate (CRITICAL)
+## How To Gate (CRITICAL) (( inert ))
 
 After presenting choices, **you MUST stop your turn.** Do not:
 - ❌ Continue with "while you decide, I'll start on..."
@@ -121,7 +126,7 @@
 - ✅ End your message with a brief note that you're waiting
 - ✅ Stop. Full stop. No more tool calls.
 
-## How To Handle The Response
+## How To Handle The Response (( inert ))
 
 When the user responds:
 
@@ -130,7 +135,7 @@
 3. **Branch and execute** the chosen path
 4. If unclear, ask again
 
-### Handling text responses
+### Handling text responses (( inert ))
 
 Users sometimes type instead of clicking. Handle gracefully:
 - "the first one" / "A" / "1" → map to first option
@@ -138,9 +143,9 @@
 - "actually, none of those" → present alternatives or ask what they want
 - Unrelated message → the user moved on; drop the gate
 
-## Formatting Guidelines
-
-### Question line emoji prefix
+## Formatting Guidelines (( inert ))
+
+### Question line emoji prefix (( inert ))
 
 Signal the decision type:
 - 🔀 Routing/filing decisions
@@ -150,11 +155,11 @@
 - 📋 Workflow/process choices
 - 🔐 Credential/security decisions
 
-### Context block
+### Context block (( inert ))
 
 1-3 lines maximum. The user should understand the decision in under 5 seconds.
 
-### Button/option labels
+### Button/option labels (( inert ))
 
 Format: `Action verb — brief qualifier`
 - ✅ "Merge — combine with existing page"
@@ -162,9 +167,9 @@
 - ❌ "Option 1"
 - ❌ "Click here to merge the content into the existing brain page"
 
-## Examples
-
-### Cold-start phase gate
+## Examples (( inert ))
+
+### Cold-start phase gate (( inert ))
 ```
 📋 **Phase 2: Google Contacts**
 
@@ -177,7 +182,7 @@
 4. **Skip** — move to the next phase
 ```
 
-### Filing decision
+### Filing decision (( inert ))
 ```
 🔀 **Where should this go?**
 
@@ -190,7 +195,7 @@
 4. **Skip** — don't file this
 ```
 
-### Destructive operation
+### Destructive operation (( inert ))
 ```
 ⚠️ **About to delete 847 stale cache files (2.3 GB)**
 
@@ -203,7 +208,7 @@
 4. **Show me the list** — let me review before deciding
 ```
 
-## Integration With Other Skills
+## Integration With Other Skills (( inert ))
 
 This pattern is used by:
 - **cold-start** — phase gates for each import source
@@ -216,21 +221,22 @@
 When building a new skill that needs user input at a decision point,
 reference this pattern rather than inventing a new one.
 
-## Anti-Patterns
-
-- **Continuing the turn after presenting choices.** "While you decide, I'll start on..."
+## Anti-Patterns (( role: procedure ))
+
+!!! checklist (( ai-autonomy ))
+- [ ] **Continuing the turn after presenting choices.** "While you decide, I'll start on..."
   defeats the gate. Stop. Wait. The whole point is that the user controls what happens next.
-- **Picking a default and proceeding silently.** If the question matters enough to ask,
+- [ ] **Picking a default and proceeding silently.** If the question matters enough to ask,
   it matters enough to wait. Silent defaults erode trust the next time you do ask.
-- **More than 4 options.** Decision paralysis is real. Group, summarize, or split into
+- [ ] **More than 4 options.** Decision paralysis is real. Group, summarize, or split into
   staged questions instead.
-- **No escape hatch.** Every choice gate must let the user decline. "None of these"
+- [ ] **No escape hatch.** Every choice gate must let the user decline. "None of these"
   / "Skip" / "Cancel" is mandatory.
-- **Stacking multiple choice gates in one message.** The user can only answer one
+- [ ] **Stacking multiple choice gates in one message.** The user can only answer one
   question per turn. Multi-question gates either get half-answered or dropped entirely.
-- **Cryptic option labels.** "Option 1" forces re-reading the context. "Merge into
+- [ ] **Cryptic option labels.** "Option 1" forces re-reading the context. "Merge into
   existing page" is self-explanatory.
-- **Asking about low-stakes decisions.** If the wrong answer costs nothing, just pick
+- [ ] **Asking about low-stakes decisions.** If the wrong answer costs nothing, just pick
   the best option and mention it. Reserve gates for forks where rework is expensive.
 
 ## Output Format
```
