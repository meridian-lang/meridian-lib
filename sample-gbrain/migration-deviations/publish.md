# Deviation: publish.meri

- Original: `publish/SKILL.md`
- Ported: `publish.meri`
- Tier: 2 (light edits)
- Similarity: 81%
- Lines: 173 -> 189 (+42 / -26)

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
- L28 `Default: ALWAYS ENCRYPT`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L105 `Option C: Static hosting (Render, Netlify, S3)`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L144 `Revoking Access`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L157 `Output Format`: template - Template/output shape is metadata unless explicit output assertions are authored.
- L172 `Tools Used`: tools-metadata - Tools sections are metadata-mining, not workflow execution.

## Metrics
- Sections inert total: 8/14 (57% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert categories: reference-documentation=6, template=1, tools-metadata=1
- Judgment: 3 blocks, 0 lines

### Inert section details
- L28 `Default: ALWAYS ENCRYPT`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L76 `Option A: Local file (simplest)`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L87 `Option B: Upload to cloud storage`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L105 `Option C: Static hosting (Render, Netlify, S3)`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L132 `Updating a Published Page`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L144 `Revoking Access`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L157 `Output Format`: template — Template/output shape is metadata unless explicit output assertions are authored.
- L172 `Tools Used`: tools-metadata — Tools sections are metadata-mining, not workflow execution.

## Unified diff

```diff
--- original-skills/publish/SKILL.md
+++ skills/publish.meri
@@ -13,15 +13,16 @@
 
 # Publish Skill
 
-Share brain pages as beautiful, self-contained HTML documents. Optionally
-password-protected with client-side AES-256-GCM encryption. No server needed.
+> Share brain pages as beautiful, self-contained HTML documents. Optionally
+> password-protected with client-side AES-256-GCM encryption. No server needed.
 
-This is a **code + skill pair**: the deterministic code (`gbrain publish`) does
-the stripping, encrypting, and HTML generation. This skill tells you when and
-how to use it. See [Thin Harness, Fat Skills](https://x.com/garrytan/status/2042925773300908103)
-for the architecture philosophy.
+> This is a **code + skill pair**: the deterministic code (`gbrain publish`) does
+> the stripping, encrypting, and HTML generation. This skill tells you when and
+> how to use it. See [Thin Harness, Fat Skills](https://x.com/garrytan/status/2042925773300908103)
+> for the architecture philosophy.
 
-## Contract
+## Contract (( role: procedure ))
+use judgment to follow the Contract guidance:
 
 - Published HTML is fully self-contained: no external dependencies, no server needed.
 - All private metadata (frontmatter, source citations, confirmation numbers, brain cross-links, timeline) is stripped before publishing.
@@ -36,7 +37,7 @@
 - User asks to publish a data room analysis or trip plan
 - Any time brain content needs to leave the brain without exposing the whole system
 
-## Default: ALWAYS ENCRYPT
+## Default: ALWAYS ENCRYPT (( inert ))
 
 Brain content is private. Default to password-protected unless the user explicitly
 says "open", "no password", or "public".
@@ -63,32 +64,44 @@
 gbrain publish brain/companies/acme.md --out /tmp/acme-share.html
 ```
 
-## What Gets Stripped
+## What Gets Stripped (( inert ))
 
-The publish command automatically removes all private/internal data:
 
+### What Gets Stripped — steps
+
+> The publish command automatically removes all private/internal data:
+
+!!! table (( ai-discretion ))
 | Stripped | Example | Why |
 |---------|---------|-----|
 | YAML frontmatter | `title:`, `type:`, `tags:` | Internal metadata |
 | `[Source: ...]` citations | All formats | Provenance is internal |
 | Confirmation numbers | `ABC123DEF` -> "on file" | PII/booking data |
-| Brain cross-links | `[Jane](../people/jane.md)` -> `Jane` | Internal paths |
+| Brain cross-links | `Jane` -> `Jane` | Internal paths |
 | Timeline section | Everything below `---` / `## Timeline` | Raw evidence log |
 | "See also" lines | Internal references | Brain navigation |
 
-**Preserved:** external URLs (`https://...`), all other content.
+Preserved: external URLs (`https://...`), all other content.
 
-## Sharing Workflows
+## Sharing Workflows (( inert ))
 
-### Option A: Local file (simplest)
+### Option A: Local file (simplest) (( inert ))
+
+Share the HTML file via email, Slack, Airdrop. Share the password separately.
+
+
+#### Option A: Local file (simplest) — steps
 
 ```bash
 gbrain publish brain/people/jane-doe.md --password --out ~/Desktop/jane-briefing.html
 ```
 
-Share the HTML file via email, Slack, Airdrop. Share the password separately.
+### Option B: Upload to cloud storage (( inert ))
 
-### Option B: Upload to cloud storage
+Share the signed URL + password. URL expires in 1 hour. Re-generate as needed.
+
+
+#### Option B: Upload to cloud storage — steps
 
 ```bash
 # Publish locally first
@@ -101,9 +114,7 @@
 gbrain files signed-url shares/acme/acme.html
 ```
 
-Share the signed URL + password. URL expires in 1 hour. Re-generate as needed.
-
-### Option C: Static hosting (Render, Netlify, S3)
+### Option C: Static hosting (Render, Netlify, S3) (( inert ))
 
 Upload the HTML file to any static hosting service. The file is self-contained,
 no server logic needed. Password-protected files work entirely client-side via
@@ -117,6 +128,7 @@
 ```
 
 ## Password Protection Details
+use judgment to follow the Password Protection Details guidance:
 
 - **Algorithm:** AES-256-GCM
 - **Key derivation:** PBKDF2 with 100K iterations, SHA-256
@@ -129,21 +141,25 @@
 When encrypted, the published HTML contains ONLY ciphertext. The plaintext is
 not present anywhere in the file.
 
-## Updating a Published Page
+## Updating a Published Page (( inert ))
 
-Re-run the publish command with the same output path:
+Same file, same URL (if hosted), updated content.
+
+
+### Updating a Published Page — steps
+
+> Re-run the publish command with the same output path:
 ```bash
 gbrain publish brain/companies/acme.md --password "same-password" --out shares/acme.html
 ```
 
-Same file, same URL (if hosted), updated content.
-
-## Revoking Access
+## Revoking Access (( inert ))
 
 Delete the file. If using signed URLs, the URL expires automatically (1 hour).
 If using static hosting, remove the file from the host.
 
-## Anti-Patterns
+## Anti-Patterns (( role: procedure ))
+use judgment to follow the Anti-Patterns guidance:
 
 - **Publishing without encryption.** Brain content is private. Default to password-protected unless the user explicitly says "open", "no password", or "public".
 - **Sharing password and URL in the same channel.** Always share the password via a different channel than the URL for security.
@@ -165,7 +181,7 @@
 Share the password via: [a different channel]
 ```
 
-## Tools Used
+## Tools Used (( inert, role: tools ))
 
 - `gbrain publish` -- deterministic HTML generation (no LLM calls)
 - `gbrain files upload` -- upload to cloud storage (optional)
```
