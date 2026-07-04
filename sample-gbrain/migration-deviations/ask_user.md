# Deviation: ask_user.meri

- Original: `ask-user/SKILL.md`
- Ported: `ask_user.meri`
- Tier: 1 (near-verbatim)
- Similarity: 89%
- Lines: 254 -> 264 (+34 / -24)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- shell-block-routed
- inert-section-added

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L15 `What This Is`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L50 `Platform-agnostic format (works everywhere)`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L65 `With inline buttons (Telegram, Discord, Slack)`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L80 `With the `clarify` tool (OpenClaw agents)`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L117 `How To Handle The Response`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L126 `Handling text responses`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L136 `Question line emoji prefix`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L146 `Context block`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L160 `Cold-start phase gate`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L173 `Filing decision`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L186 `Destructive operation`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L231 `Output Format`: template - Template/output shape is metadata unless explicit output assertions are authored.

## Metrics
- Sections inert total: 12/20 (60% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert categories: reference-documentation=11, template=1
- Judgment: 7 blocks, 0 lines

### Inert section details
- L15 `What This Is`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L50 `Platform-agnostic format (works everywhere)`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L65 `With inline buttons (Telegram, Discord, Slack)`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L80 `With the `clarify` tool (OpenClaw agents)`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L117 `How To Handle The Response`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L126 `Handling text responses`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L136 `Question line emoji prefix`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L146 `Context block`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L160 `Cold-start phase gate`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L173 `Filing decision`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L186 `Destructive operation`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L231 `Output Format`: template — Template/output shape is metadata unless explicit output assertions are authored.

## Unified diff

```diff
--- original-skills/ask-user/SKILL.md
+++ skills/ask_user.meri
@@ -16,7 +16,8 @@
 
 # Ask User — Choice Gate Pattern
 
-## Contract
+## Contract (( role: procedure ))
+use judgment to follow the Contract guidance:
 
 - Present 2-4 options (no more — decision paralysis kicks in past 4).
 - Always include an escape hatch (Skip, Cancel, or "none of these").
@@ -26,7 +27,7 @@
 - One question per message — never stack multiple choice gates.
 - Self-explanatory option labels: action verb plus brief qualifier, not "Option 1".
 
-## What This Is
+## What This Is (( inert ))
 
 A **formalized pattern** for presenting users with 2-4 options and **stopping
 execution** until they respond. This is the canonical way to gate on user input
@@ -38,7 +39,8 @@
 3. The user's response triggers the next turn
 4. Read the response and branch accordingly
 
-## When To Use
+## When To Use (( role: procedure ))
+use judgment to follow the When To Use guidance:
 
 - Ambiguous requests with multiple valid interpretations
 - Destructive operations (bulk deletes, overwrites)
@@ -47,16 +49,20 @@
 - Cold-start phase gates ("ready for the next import source?")
 - Any fork where the wrong default wastes significant work
 
-## When NOT To Use
+## When NOT To Use (( role: procedure ))
+use judgment to follow the When NOT To Use guidance:
 
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
+## How To Present Choices (( inert ))
+
+### Platform-agnostic format (works everywhere) (( inert ))
 
 Present choices as a clear question with numbered or labeled options:
 
@@ -71,7 +77,7 @@
 4. **Skip** — do nothing for now
 ```
 
-### With inline buttons (Telegram, Discord, Slack)
+### With inline buttons (Telegram, Discord, Slack) (( inert ))
 
 If the platform supports interactive buttons, use them:
 
@@ -86,7 +92,7 @@
 }
 ```
 
-### With the `clarify` tool (OpenClaw agents)
+### With the `clarify` tool (OpenClaw agents) (( inert ))
 
 Some OpenClaw agents have a built-in `clarify` tool that presents choices natively:
 
@@ -103,6 +109,7 @@
 ```
 
 ## Constraints
+use judgment to follow the Constraints guidance:
 
 - **2-4 options max.** More than 4 creates decision paralysis.
 - **Labels must be self-explanatory.** The user shouldn't need to re-read context.
@@ -110,6 +117,7 @@
 - **One question per message.** Never stack multiple choice gates.
 
 ## How To Gate (CRITICAL)
+use judgment to follow the How To Gate (CRITICAL) guidance:
 
 After presenting choices, **you MUST stop your turn.** Do not:
 - ❌ Continue with "while you decide, I'll start on..."
@@ -121,7 +129,7 @@
 - ✅ End your message with a brief note that you're waiting
 - ✅ Stop. Full stop. No more tool calls.
 
-## How To Handle The Response
+## How To Handle The Response (( inert ))
 
 When the user responds:
 
@@ -130,7 +138,7 @@
 3. **Branch and execute** the chosen path
 4. If unclear, ask again
 
-### Handling text responses
+### Handling text responses (( inert ))
 
 Users sometimes type instead of clicking. Handle gracefully:
 - "the first one" / "A" / "1" → map to first option
@@ -138,9 +146,9 @@
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
@@ -150,7 +158,7 @@
 - 📋 Workflow/process choices
 - 🔐 Credential/security decisions
 
-### Context block
+### Context block (( inert ))
 
 1-3 lines maximum. The user should understand the decision in under 5 seconds.
 
@@ -162,9 +170,9 @@
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
 
@@ -177,7 +185,7 @@
 4. **Skip** — move to the next phase
 ```
 
-### Filing decision
+### Filing decision (( inert ))
 ```
 🔀 **Where should this go?**
 
@@ -190,7 +198,7 @@
 4. **Skip** — don't file this
 ```
 
-### Destructive operation
+### Destructive operation (( inert ))
 ```
 ⚠️ **About to delete 847 stale cache files (2.3 GB)**
 
@@ -204,6 +212,7 @@
 ```
 
 ## Integration With Other Skills
+use judgment to follow the Integration With Other Skills guidance:
 
 This pattern is used by:
 - **cold-start** — phase gates for each import source
@@ -216,7 +225,8 @@
 When building a new skill that needs user input at a decision point,
 reference this pattern rather than inventing a new one.
 
-## Anti-Patterns
+## Anti-Patterns (( role: procedure ))
+use judgment to follow the Anti-Patterns guidance:
 
 - **Continuing the turn after presenting choices.** "While you decide, I'll start on..."
   defeats the gate. Stop. Wait. The whole point is that the user controls what happens next.
@@ -233,7 +243,7 @@
 - **Asking about low-stakes decisions.** If the wrong answer costs nothing, just pick
   the best option and mention it. Reserve gates for forks where rework is expensive.
 
-## Output Format
+## Output Format (( inert, role: template ))
 
 The skill's "output" is the choice-gate message itself, structured as:
 
```
