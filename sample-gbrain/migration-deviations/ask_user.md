# Deviation: ask_user.meri

- Original: `ask-user/SKILL.md`
- Ported: `ask_user.meri`
- Tier: 1 (near-verbatim)
- Similarity: 87%
- Lines: 254 -> 254 (+32 / -32)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- inert-section-added

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L4 `Contract`: normative-contract - Normative invariants prose needs mining into assertions or explicit AI routing.
- L14 `What This Is`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L26 `When To Use`: operational-procedure - Marked or derived as applicability, but inert suppresses execution.
- L35 `When NOT To Use`: operational-procedure - Marked or derived as negative-applicability, but inert suppresses execution.
- L42 `How To Present Choices`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L44 `Platform-agnostic format (works everywhere)`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L59 `With inline buttons (Telegram, Discord, Slack)`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L74 `With the `clarify` tool (OpenClaw agents)`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L90 `Constraints`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L97 `How To Gate (CRITICAL)`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L109 `How To Handle The Response`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L118 `Handling text responses`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L126 `Formatting Guidelines`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L128 `Question line emoji prefix`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L138 `Context block`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L142 `Button/option labels`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L150 `Examples`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L152 `Cold-start phase gate`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L165 `Filing decision`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L178 `Destructive operation`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L191 `Integration With Other Skills`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L204 `Anti-Patterns`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L221 `Output Format`: template - Template/output shape is metadata unless explicit output assertions are authored.

## Metrics
- Sections: 23/23 inert (100% inert ratio)
- Operational inert: 3
- Unclassified inert: 0
- Inert categories: normative-contract=1, operational-procedure=2, reference-documentation=19, template=1
- Judgment: 0 blocks, 0 lines

### Inert section details
- L4 `Contract`: normative-contract — Normative invariants prose needs mining into assertions or explicit AI routing.
- L14 `What This Is`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L26 `When To Use`: operational-procedure — Marked or derived as applicability, but inert suppresses execution.
- L35 `When NOT To Use`: operational-procedure — Marked or derived as negative-applicability, but inert suppresses execution.
- L42 `How To Present Choices`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L44 `Platform-agnostic format (works everywhere)`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L59 `With inline buttons (Telegram, Discord, Slack)`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L74 `With the `clarify` tool (OpenClaw agents)`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L90 `Constraints`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L97 `How To Gate (CRITICAL)`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L109 `How To Handle The Response`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L118 `Handling text responses`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L126 `Formatting Guidelines`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L128 `Question line emoji prefix`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L138 `Context block`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L142 `Button/option labels`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L150 `Examples`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L152 `Cold-start phase gate`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L165 `Filing decision`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L178 `Destructive operation`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L191 `Integration With Other Skills`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L204 `Anti-Patterns`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L221 `Output Format`: template — Template/output shape is metadata unless explicit output assertions are authored.

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
@@ -26,7 +26,7 @@
 - One question per message — never stack multiple choice gates.
 - Self-explanatory option labels: action verb plus brief qualifier, not "Option 1".
 
-## What This Is
+## What This Is (( inert ))
 
 A **formalized pattern** for presenting users with 2-4 options and **stopping
 execution** until they respond. This is the canonical way to gate on user input
@@ -38,7 +38,7 @@
 3. The user's response triggers the next turn
 4. Read the response and branch accordingly
 
-## When To Use
+## When To Use (( inert, role: applicability ))
 
 - Ambiguous requests with multiple valid interpretations
 - Destructive operations (bulk deletes, overwrites)
@@ -47,16 +47,16 @@
 - Cold-start phase gates ("ready for the next import source?")
 - Any fork where the wrong default wastes significant work
 
-## When NOT To Use
+## When NOT To Use (( inert, role: negative-applicability ))
 
 - Clear, unambiguous instructions → just do it
 - Low-stakes decisions → pick the best option and mention it
 - Time-critical operations where delay costs more than a wrong choice
 - When the user has already expressed a preference
 
-## How To Present Choices
-
-### Platform-agnostic format (works everywhere)
+## How To Present Choices (( inert ))
+
+### Platform-agnostic format (works everywhere) (( inert ))
 
 Present choices as a clear question with numbered or labeled options:
 
@@ -71,7 +71,7 @@
 4. **Skip** — do nothing for now
 ```
 
-### With inline buttons (Telegram, Discord, Slack)
+### With inline buttons (Telegram, Discord, Slack) (( inert ))
 
 If the platform supports interactive buttons, use them:
 
@@ -86,7 +86,7 @@
 }
 ```
 
-### With the `clarify` tool (OpenClaw agents)
+### With the `clarify` tool (OpenClaw agents) (( inert ))
 
 Some OpenClaw agents have a built-in `clarify` tool that presents choices natively:
 
@@ -102,14 +102,14 @@
 )
 ```
 
-## Constraints
-
-- **2-4 options max.** More than 4 creates decision paralysis.
-- **Labels must be self-explanatory.** The user shouldn't need to re-read context.
-- **Always include an escape hatch.** At minimum: "Skip" or "Cancel" as the last option.
-- **One question per message.** Never stack multiple choice gates.
-
-## How To Gate (CRITICAL)
+## Constraints (( inert ))
+
+- 2-4 options max. More than 4 creates decision paralysis.
+- Labels must be self-explanatory. The user shouldn't need to re-read context.
+- Always include an escape hatch. At minimum: "Skip" or "Cancel" as the last option.
+- One question per message. Never stack multiple choice gates.
+
+## How To Gate (CRITICAL) (( inert ))
 
 After presenting choices, **you MUST stop your turn.** Do not:
 - ❌ Continue with "while you decide, I'll start on..."
@@ -121,7 +121,7 @@
 - ✅ End your message with a brief note that you're waiting
 - ✅ Stop. Full stop. No more tool calls.
 
-## How To Handle The Response
+## How To Handle The Response (( inert ))
 
 When the user responds:
 
@@ -130,7 +130,7 @@
 3. **Branch and execute** the chosen path
 4. If unclear, ask again
 
-### Handling text responses
+### Handling text responses (( inert ))
 
 Users sometimes type instead of clicking. Handle gracefully:
 - "the first one" / "A" / "1" → map to first option
@@ -138,9 +138,9 @@
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
@@ -150,11 +150,11 @@
 - 📋 Workflow/process choices
 - 🔐 Credential/security decisions
 
-### Context block
+### Context block (( inert ))
 
 1-3 lines maximum. The user should understand the decision in under 5 seconds.
 
-### Button/option labels
+### Button/option labels (( inert ))
 
 Format: `Action verb — brief qualifier`
 - ✅ "Merge — combine with existing page"
@@ -162,9 +162,9 @@
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
 
@@ -177,7 +177,7 @@
 4. **Skip** — move to the next phase
 ```
 
-### Filing decision
+### Filing decision (( inert ))
 ```
 🔀 **Where should this go?**
 
@@ -190,7 +190,7 @@
 4. **Skip** — don't file this
 ```
 
-### Destructive operation
+### Destructive operation (( inert ))
 ```
 ⚠️ **About to delete 847 stale cache files (2.3 GB)**
 
@@ -203,7 +203,7 @@
 4. **Show me the list** — let me review before deciding
 ```
 
-## Integration With Other Skills
+## Integration With Other Skills (( inert ))
 
 This pattern is used by:
 - **cold-start** — phase gates for each import source
@@ -216,7 +216,7 @@
 When building a new skill that needs user input at a decision point,
 reference this pattern rather than inventing a new one.
 
-## Anti-Patterns
+## Anti-Patterns (( inert, role: prohibitions ))
 
 - **Continuing the turn after presenting choices.** "While you decide, I'll start on..."
   defeats the gate. Stop. Wait. The whole point is that the user controls what happens next.
@@ -233,7 +233,7 @@
 - **Asking about low-stakes decisions.** If the wrong answer costs nothing, just pick
   the best option and mention it. Reserve gates for forks where rework is expensive.
 
-## Output Format
+## Output Format (( inert, role: template ))
 
 The skill's "output" is the choice-gate message itself, structured as:
 
```
