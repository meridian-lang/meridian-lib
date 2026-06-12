# Deviation: ask_user.meri

- Original: `ask-user/SKILL.md`
- Ported: `ask_user.meri`
- Tier: 1 (near-verbatim)
- Similarity: 89%
- Lines: 254 -> 258 (+29 / -25)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added

## Unified diff

```diff
--- original-skills/ask-user/SKILL.md
+++ skills/ask_user.meri
@@ -16,7 +16,7 @@
 
 # Ask User — Choice Gate Pattern
 
-## Contract
+## Contract (( inert, role: invariants ))
 
 - Present 2-4 options (no more — decision paralysis kicks in past 4).
 - Always include an escape hatch (Skip, Cancel, or "none of these").
@@ -26,7 +26,11 @@
 - One question per message — never stack multiple choice gates.
 - Self-explanatory option labels: action verb plus brief qualifier, not "Option 1".
 
-## What This Is
+## Phases
+
+ask the user to choose between "Proceed", "Adjust", or "Skip".
+
+## What This Is (( inert ))
 
 A **formalized pattern** for presenting users with 2-4 options and **stopping
 execution** until they respond. This is the canonical way to gate on user input
@@ -52,11 +56,11 @@
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
 
@@ -71,7 +75,7 @@
 4. **Skip** — do nothing for now
 ```
 
-### With inline buttons (Telegram, Discord, Slack)
+### With inline buttons (Telegram, Discord, Slack) (( inert ))
 
 If the platform supports interactive buttons, use them:
 
@@ -86,7 +90,7 @@
 }
 ```
 
-### With the `clarify` tool (OpenClaw agents)
+### With the `clarify` tool (OpenClaw agents) (( inert ))
 
 Some OpenClaw agents have a built-in `clarify` tool that presents choices natively:
 
@@ -102,14 +106,14 @@
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
@@ -121,7 +125,7 @@
 - ✅ End your message with a brief note that you're waiting
 - ✅ Stop. Full stop. No more tool calls.
 
-## How To Handle The Response
+## How To Handle The Response (( inert ))
 
 When the user responds:
 
@@ -130,7 +134,7 @@
 3. **Branch and execute** the chosen path
 4. If unclear, ask again
 
-### Handling text responses
+### Handling text responses (( inert ))
 
 Users sometimes type instead of clicking. Handle gracefully:
 - "the first one" / "A" / "1" → map to first option
@@ -138,9 +142,9 @@
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
@@ -150,11 +154,11 @@
 - 📋 Workflow/process choices
 - 🔐 Credential/security decisions
 
-### Context block
+### Context block (( inert ))
 
 1-3 lines maximum. The user should understand the decision in under 5 seconds.
 
-### Button/option labels
+### Button/option labels (( inert ))
 
 Format: `Action verb — brief qualifier`
 - ✅ "Merge — combine with existing page"
@@ -162,9 +166,9 @@
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
 
@@ -177,7 +181,7 @@
 4. **Skip** — move to the next phase
 ```
 
-### Filing decision
+### Filing decision (( inert ))
 ```
 🔀 **Where should this go?**
 
@@ -190,7 +194,7 @@
 4. **Skip** — don't file this
 ```
 
-### Destructive operation
+### Destructive operation (( inert ))
 ```
 ⚠️ **About to delete 847 stale cache files (2.3 GB)**
 
@@ -203,7 +207,7 @@
 4. **Show me the list** — let me review before deciding
 ```
 
-## Integration With Other Skills
+## Integration With Other Skills (( inert ))
 
 This pattern is used by:
 - **cold-start** — phase gates for each import source
@@ -216,7 +220,7 @@
 When building a new skill that needs user input at a decision point,
 reference this pattern rather than inventing a new one.
 
-## Anti-Patterns
+## Anti-Patterns (( inert, role: prohibitions ))
 
 - **Continuing the turn after presenting choices.** "While you decide, I'll start on..."
   defeats the gate. Stop. Wait. The whole point is that the user controls what happens next.
```
