# Deviation: publish.meri

- Original: `publish/SKILL.md`
- Ported: `publish.meri`
- Tier: 1 (near-verbatim)
- Similarity: 89%
- Lines: 173 -> 173 (+19 / -19)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- preamble-blockquoted
- inert-section-added

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L12 `Contract`: normative-contract - Normative invariants prose needs mining into assertions or explicit AI routing.
- L20 `When to Publish`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L27 `Default: ALWAYS ENCRYPT`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L54 `What Gets Stripped`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L69 `Sharing Workflows`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L71 `Option A: Local file (simplest)`: operational-content - Body contains command, table, checklist, or explicit AI-routing surface.
- L79 `Option B: Upload to cloud storage`: operational-content - Body contains command, table, checklist, or explicit AI-routing surface.
- L94 `Option C: Static hosting (Render, Netlify, S3)`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L107 `Password Protection Details`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L120 `Updating a Published Page`: operational-content - Body contains command, table, checklist, or explicit AI-routing surface.
- L129 `Revoking Access`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L134 `Anti-Patterns`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L141 `Output Format`: template - Template/output shape is metadata unless explicit output assertions are authored.
- L156 `Tools Used`: tools-metadata - Tools sections are metadata-mining, not workflow execution.

## Metrics
- Sections: 14/16 inert (88% inert ratio)
- Operational inert: 4
- Unclassified inert: 0
- Inert categories: normative-contract=1, operational-content=3, reference-documentation=8, template=1, tools-metadata=1
- Judgment: 0 blocks, 0 lines

### Inert section details
- L12 `Contract`: normative-contract — Normative invariants prose needs mining into assertions or explicit AI routing.
- L20 `When to Publish`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L27 `Default: ALWAYS ENCRYPT`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L54 `What Gets Stripped`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L69 `Sharing Workflows`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L71 `Option A: Local file (simplest)`: operational-content — Body contains command, table, checklist, or explicit AI-routing surface.
- L79 `Option B: Upload to cloud storage`: operational-content — Body contains command, table, checklist, or explicit AI-routing surface.
- L94 `Option C: Static hosting (Render, Netlify, S3)`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L107 `Password Protection Details`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L120 `Updating a Published Page`: operational-content — Body contains command, table, checklist, or explicit AI-routing surface.
- L129 `Revoking Access`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L134 `Anti-Patterns`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L141 `Output Format`: template — Template/output shape is metadata unless explicit output assertions are authored.
- L156 `Tools Used`: tools-metadata — Tools sections are metadata-mining, not workflow execution.

## Unified diff

```diff
--- original-skills/publish/SKILL.md
+++ skills/publish.meri
@@ -13,15 +13,15 @@
 
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
+## Contract (( inert, role: invariants ))
 
 - Published HTML is fully self-contained: no external dependencies, no server needed.
 - All private metadata (frontmatter, source citations, confirmation numbers, brain cross-links, timeline) is stripped before publishing.
@@ -29,14 +29,14 @@
 - Default is always encrypted unless the user explicitly requests "open", "no password", or "public".
 - External URLs (`https://...`) are preserved; only internal brain paths are stripped.
 
-## When to Publish
+## When to Publish (( inert ))
 
 - User asks to share a brain page, create a shareable link, or says "give me a page"
 - User wants to send a deal memo, person briefing, or research to someone external
 - User asks to publish a data room analysis or trip plan
 - Any time brain content needs to leave the brain without exposing the whole system
 
-## Default: ALWAYS ENCRYPT
+## Default: ALWAYS ENCRYPT (( inert ))
 
 Brain content is private. Default to password-protected unless the user explicitly
 says "open", "no password", or "public".
@@ -63,7 +63,7 @@
 gbrain publish brain/companies/acme.md --out /tmp/acme-share.html
 ```
 
-## What Gets Stripped
+## What Gets Stripped (( inert ))
 
 The publish command automatically removes all private/internal data:
 
@@ -78,9 +78,9 @@
 
 **Preserved:** external URLs (`https://...`), all other content.
 
-## Sharing Workflows
+## Sharing Workflows (( inert ))
 
-### Option A: Local file (simplest)
+### Option A: Local file (simplest) (( inert ))
 
 ```bash
 gbrain publish brain/people/jane-doe.md --password --out ~/Desktop/jane-briefing.html
@@ -88,7 +88,7 @@
 
 Share the HTML file via email, Slack, Airdrop. Share the password separately.
 
-### Option B: Upload to cloud storage
+### Option B: Upload to cloud storage (( inert ))
 
 ```bash
 # Publish locally first
@@ -103,7 +103,7 @@
 
 Share the signed URL + password. URL expires in 1 hour. Re-generate as needed.
 
-### Option C: Static hosting (Render, Netlify, S3)
+### Option C: Static hosting (Render, Netlify, S3) (( inert ))
 
 Upload the HTML file to any static hosting service. The file is self-contained,
 no server logic needed. Password-protected files work entirely client-side via
@@ -116,7 +116,7 @@
 # Upload to a GitHub Gist or Pages repo
 ```
 
-## Password Protection Details
+## Password Protection Details (( inert ))
 
 - **Algorithm:** AES-256-GCM
 - **Key derivation:** PBKDF2 with 100K iterations, SHA-256
@@ -129,7 +129,7 @@
 When encrypted, the published HTML contains ONLY ciphertext. The plaintext is
 not present anywhere in the file.
 
-## Updating a Published Page
+## Updating a Published Page (( inert ))
 
 Re-run the publish command with the same output path:
 ```bash
@@ -138,12 +138,12 @@
 
 Same file, same URL (if hosted), updated content.
 
-## Revoking Access
+## Revoking Access (( inert ))
 
 Delete the file. If using signed URLs, the URL expires automatically (1 hour).
 If using static hosting, remove the file from the host.
 
-## Anti-Patterns
+## Anti-Patterns (( inert, role: prohibitions ))
 
 - **Publishing without encryption.** Brain content is private. Default to password-protected unless the user explicitly says "open", "no password", or "public".
 - **Sharing password and URL in the same channel.** Always share the password via a different channel than the URL for security.
@@ -165,7 +165,7 @@
 Share the password via: [a different channel]
 ```
 
-## Tools Used
+## Tools Used (( inert, role: tools ))
 
 - `gbrain publish` -- deterministic HTML generation (no LLM calls)
 - `gbrain files upload` -- upload to cloud storage (optional)
```
