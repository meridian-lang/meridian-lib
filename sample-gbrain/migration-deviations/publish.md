# Deviation: publish.meri

- Original: `publish/SKILL.md`
- Ported: `publish.meri`
- Tier: 2 (light edits)
- Similarity: 77%
- Lines: 173 -> 197 (+55 / -31)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- preamble-blockquoted
- doc-section-marked

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L23 `When to Publish`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L30 `Default: ALWAYS ENCRYPT`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L106 `Option C: Static hosting (Render, Netlify, S3)`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L147 `Revoking Access`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L165 `Output Format`: template - Template/output shape is metadata unless explicit output assertions are authored.
- L180 `Tools Used`: tools-metadata - Tools sections are metadata-mining, not workflow execution.

## Metrics
- Sections inert total: 12/14 (86% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert markers (`(( inert ))`, target 0 — the migrator never emits these): 0
- Inert categories: reference-documentation=10, template=1, tools-metadata=1
- Judgment: 0 blocks, 0 lines

### Inert section details
- L12 `Contract`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L23 `When to Publish`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L30 `Default: ALWAYS ENCRYPT`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L77 `Option A: Local file (simplest)`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L88 `Option B: Upload to cloud storage`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L106 `Option C: Static hosting (Render, Netlify, S3)`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L119 `Password Protection Details`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L135 `Updating a Published Page`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L147 `Revoking Access`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L152 `Anti-Patterns`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L165 `Output Format`: template — Template/output shape is metadata unless explicit output assertions are authored.
- L180 `Tools Used`: tools-metadata — Tools sections are metadata-mining, not workflow execution.

## Unified diff

```diff
--- original-skills/publish/SKILL.md
+++ skills/publish.meri
@@ -13,30 +13,33 @@
 
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
+## Contract (( role: reference ))
 
 - Published HTML is fully self-contained: no external dependencies, no server needed.
 - All private metadata (frontmatter, source citations, confirmation numbers, brain cross-links, timeline) is stripped before publishing.
+- External URLs (`https://...`) are preserved; only internal brain paths are stripped.
+
+
+### Contract — steps (( role: reference ))
+
 - Password protection uses AES-256-GCM with PBKDF2 key derivation; plaintext never appears in the encrypted HTML file.
 - Default is always encrypted unless the user explicitly requests "open", "no password", or "public".
-- External URLs (`https://...`) are preserved; only internal brain paths are stripped.
-
-## When to Publish
+## When to Publish (( role: reference ))
 
 - User asks to share a brain page, create a shareable link, or says "give me a page"
 - User wants to send a deal memo, person briefing, or research to someone external
 - User asks to publish a data room analysis or trip plan
 - Any time brain content needs to leave the brain without exposing the whole system
 
-## Default: ALWAYS ENCRYPT
+## Default: ALWAYS ENCRYPT (( role: reference ))
 
 Brain content is private. Default to password-protected unless the user explicitly
 says "open", "no password", or "public".
@@ -65,30 +68,41 @@
 
 ## What Gets Stripped
 
-The publish command automatically removes all private/internal data:
+
+### What Gets Stripped — steps (( role: reference ))
+
+> The publish command automatically removes all private/internal data:
 
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
+## Sharing Workflows (( role: reference ))
 
-### Option A: Local file (simplest)
+### Option A: Local file (simplest) (( role: reference ))
+
+Share the HTML file via email, Slack, Airdrop. Share the password separately.
+
+
+### Option A: Local file (simplest) — steps
 
 ```bash
 gbrain publish brain/people/jane-doe.md --password --out ~/Desktop/jane-briefing.html
 ```
 
-Share the HTML file via email, Slack, Airdrop. Share the password separately.
+### Option B: Upload to cloud storage (( role: reference ))
 
-### Option B: Upload to cloud storage
+Share the signed URL + password. URL expires in 1 hour. Re-generate as needed.
+
+
+### Option B: Upload to cloud storage — steps
 
 ```bash
 # Publish locally first
@@ -101,9 +115,7 @@
 gbrain files signed-url shares/acme/acme.html
 ```
 
-Share the signed URL + password. URL expires in 1 hour. Re-generate as needed.
-
-### Option C: Static hosting (Render, Netlify, S3)
+### Option C: Static hosting (Render, Netlify, S3) (( role: reference ))
 
 Upload the HTML file to any static hosting service. The file is self-contained,
 no server logic needed. Password-protected files work entirely client-side via
@@ -116,7 +128,7 @@
 # Upload to a GitHub Gist or Pages repo
 ```
 
-## Password Protection Details
+## Password Protection Details (( role: reference ))
 
 - **Algorithm:** AES-256-GCM
 - **Key derivation:** PBKDF2 with 100K iterations, SHA-256
@@ -126,29 +138,41 @@
 - **No server auth needed** -- the HTML file is self-contained
 - **"Remember on this device"** -- saves password in localStorage
 
+
+### Password Protection Details — steps (( role: reference ))
+
 When encrypted, the published HTML contains ONLY ciphertext. The plaintext is
 not present anywhere in the file.
 
-## Updating a Published Page
+## Updating a Published Page (( role: reference ))
 
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
+## Revoking Access (( role: reference ))
 
 Delete the file. If using signed URLs, the URL expires automatically (1 hour).
 If using static hosting, remove the file from the host.
 
-## Anti-Patterns
+## Anti-Patterns (( role: reference ))
 
 - **Publishing without encryption.** Brain content is private. Default to password-protected unless the user explicitly says "open", "no password", or "public".
-- **Sharing password and URL in the same channel.** Always share the password via a different channel than the URL for security.
 - **Assuming the user wants raw markdown.** The publish command produces beautiful HTML. Don't copy-paste markdown when `gbrain publish` exists.
-- **Including internal metadata.** Never manually share content that contains frontmatter, source citations, or timeline sections. Let the publish command strip it.
+
+### Anti-Patterns — steps (( role: reference ))
+
+- Always share the password via a different channel than the URL for security.
+
+### Anti-Patterns — steps 2 (( role: reference ))
+
+- Never manually share content that contains frontmatter, source citations, or timeline sections. Let the publish command strip it.
 
 ## Output Format
 
@@ -165,7 +189,7 @@
 Share the password via: [a different channel]
 ```
 
-## Tools Used
+## Tools Used (( role: tools ))
 
 - `gbrain publish` -- deterministic HTML generation (no LLM calls)
 - `gbrain files upload` -- upload to cloud storage (optional)
```
