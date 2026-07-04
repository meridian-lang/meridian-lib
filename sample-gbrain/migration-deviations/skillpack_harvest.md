# Deviation: skillpack_harvest.meri

- Original: `skillpack-harvest/SKILL.md`
- Ported: `skillpack_harvest.meri`
- Tier: 2 (light edits)
- Similarity: 69%
- Lines: 270 -> 312 (+110 / -68)

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
- L33 `Output Format`: template - Template/output shape is metadata unless explicit output assertions are authored.
- L263 `What harvest does NOT do`: reference-documentation - Reference documentation, rationale, examples, or changelog.

## Metrics
- Sections inert total: 3/15 (20% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert categories: reference-documentation=2, template=1
- Judgment: 12 blocks, 0 lines

### Inert section details
- L33 `Output Format`: template — Template/output shape is metadata unless explicit output assertions are authored.
- L263 `What harvest does NOT do`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L274 `Files this skill touches`: reference-documentation — Reference documentation, rationale, examples, or changelog.

## Unified diff

```diff
--- original-skills/skillpack-harvest/SKILL.md
+++ skills/skillpack_harvest.meri
@@ -31,12 +31,13 @@
 > file placement rules. This skill writes into gbrain's own tree, not the
 > brain repo's notes.
 
-This skill is the inverse of `gbrain skillpack scaffold`. Scaffold ships
-skills downstream (gbrain → host). Harvest lifts proven patterns
-upstream (host → gbrain) so they become references every other client
-can scaffold.
-
-## Contract
+> This skill is the inverse of `gbrain skillpack scaffold`. Scaffold ships
+> skills downstream (gbrain → host). Harvest lifts proven patterns
+> upstream (host → gbrain) so they become references every other client
+> can scaffold.
+
+## Contract (( role: procedure ))
+use judgment to follow the Contract guidance:
 
 A harvest is "properly done" when:
 
@@ -55,7 +56,7 @@
 If any of these is incomplete, the skill is NOT yet harvested — the
 files may sit in gbrain's working tree, but they're not landed.
 
-## Output Format
+## Output Format (( inert, role: template ))
 
 This skill produces three artifacts in gbrain's working tree:
 
@@ -71,7 +72,8 @@
 a list of files written. JSON mode (`--json`) returns the full
 `HarvestResult` shape for machine consumption.
 
-## Anti-Patterns
+## Anti-Patterns (( role: procedure ))
+use judgment to follow the Anti-Patterns guidance:
 
 - **Skipping the dry-run.** Always preview first. Files land in
   gbrain's working tree; cleanup is a `git checkout` away, but you
@@ -89,7 +91,8 @@
 - **Harvesting batch (multiple skills at once).** Not supported, and
   for good reason — the editorial review per skill is real work.
 
-## When to invoke
+## When to invoke (( role: procedure ))
+use judgment to follow the When to invoke guidance:
 
 - The user developed a skill in their host fork (Wintermute, Neuromancer,
   Zion, etc.) and wants other gbrain clients to be able to use it
@@ -101,12 +104,8 @@
 - The skill references private content that can't be generalized
 - The user just wants to share a one-off draft (use a gist instead)
 
-## Preconditions
-
-Before running this skill, confirm:
-
-1. **The skill is mature.** Recent `routing-eval.jsonl` cases pass; the
-   skill has been used in production at least a few times.
+## Preconditions (( role: procedure ))
+use judgment to follow the Preconditions guidance:
 
 2. **The skill is generalizable.** Strip-test in your head: replace
    every fork-specific name. Does it still make sense as a skill?
@@ -115,9 +114,19 @@
    gbrain's working tree. They'll review and commit. Don't harvest
    into a checkout the user doesn't intend to commit from.
 
+
+### Preconditions — steps (( inert ))
+
+> Before running this skill, confirm:
+
+1. The skill is mature. Recent `routing-eval.jsonl` cases pass; the
+   skill has been used in production at least a few times.
+
 ## Workflow
+use judgment to follow the Workflow guidance:
 
 ### Phase 1 — Plan
+use judgment to follow the Phase 1 — Plan guidance:
 
 Ask the user:
 - What slug should the harvested skill have? (Slugs must be kebab-case,
@@ -128,12 +137,7 @@
   frontmatter `sources:` array.)
 
 ### Phase 2 — Dry-run + privacy-lint preview
-
-Run the CLI with `--dry-run`:
-
-```bash
-gbrain skillpack harvest <slug> --from <host-repo-root> --dry-run
-```
+use judgment to follow the Phase 2 — Dry-run + privacy-lint preview guidance:
 
 The output shows:
 - Which files would land in gbrain's tree
@@ -146,11 +150,17 @@
 land. Spot-check the SKILL.md and any paired source for things the
 linter might miss (proper nouns, internal project names, etc.).
 
+
+#### Phase 2 — Dry-run + privacy-lint preview — steps
+
+Run the CLI with `--dry-run`:
+
+```bash
+gbrain skillpack harvest <slug> --from <host-repo-root> --dry-run
+```
+
 ### Phase 3 — Genericization checklist (the editorial pass)
-
-Before running the real harvest, walk the host's `skills/<slug>/`
-files and apply this checklist. If anything matches, edit the host
-file FIRST, then run harvest.
+use judgment to follow the Phase 3 — Genericization checklist (the editorial pass) guidance:
 
 1. **Fork-specific names → generic phrasing**
    - `Wintermute` → `your OpenClaw` (or `OpenClaw deployment`)
@@ -161,46 +171,52 @@
 2. **Real entities → placeholders**
    - Real people, companies, deals, funds → placeholder slugs
      (`alice-example`, `acme-example`, `fund-a`, etc.)
+   - Specific tracker IDs / Linear ticket numbers → strip
+
+3. **Fork-specific conventions → references**
+4. **Triggers array generalizes**
+   - Read every entry in frontmatter `triggers:`. None should
+     reference the user's name, fork name, or internal tools.
+   - "Have garry sign off on it" → "have the user sign off on it"
+
+5. **routing-eval.jsonl examples are scrubbed**
+   - Open `skills/<slug>/routing-eval.jsonl`. Every `intent` field
+     gets the same scrub as `triggers:`.
+
+6. **Code comments + log strings**
+   - If a paired source is going to be harvested, walk it for the
+     same private-pattern leaks. Comments are the most common
+     hiding spot.
+
+
+#### Phase 3 — Genericization checklist (the editorial pass) — steps
+
+Before running the real harvest, walk the host's `skills/<slug>/`
+files and apply this checklist. If anything matches, edit the host
+file FIRST, then run harvest.
+
+
+#### Phase 3 — Genericization checklist (the editorial pass) — steps 2
+
    - Email addresses → strip entirely OR use `example@example.com`
    - Internal Slack channels → `#some-channel` or strip
-   - Specific tracker IDs / Linear ticket numbers → strip
-
-3. **Fork-specific conventions → references**
+
+#### Phase 3 — Genericization checklist (the editorial pass) — steps 3
+
    - Mentions of `<host-repo>/docs/...` files → either lift the doc
      into gbrain OR replace with a generic placeholder explanation
    - Mentions of `<host-repo>/skills/<other-fork-only-skill>` → either
      decide to harvest that one too, or replace with a generic
      pattern reference
 
-4. **Triggers array generalizes**
-   - Read every entry in frontmatter `triggers:`. None should
-     reference the user's name, fork name, or internal tools.
-   - "Have garry sign off on it" → "have the user sign off on it"
-
-5. **routing-eval.jsonl examples are scrubbed**
-   - Open `skills/<slug>/routing-eval.jsonl`. Every `intent` field
-     gets the same scrub as `triggers:`.
-
-6. **Code comments + log strings**
-   - If a paired source is going to be harvested, walk it for the
-     same private-pattern leaks. Comments are the most common
-     hiding spot.
-
 ### Phase 4 — Real harvest
-
-Once Phase 3 is complete, run the real harvest:
-
-```bash
-gbrain skillpack harvest <slug> --from <host-repo-root>
-```
+use judgment to follow the Phase 4 — Real harvest guidance:
 
 Default behavior:
 - Path-confinement + symlink rejection at file copy
 - Privacy linter runs against `~/.gbrain/harvest-private-patterns.txt`
   (plus built-in defaults: `\bWintermute\b`, email, Slack channels)
 - On any match → rollback (delete the harvested files) + exit non-zero
-- `openclaw.plugin.json` updated to add the slug, sorted
-
 Outcomes:
 - `harvested` — success, manifest updated, files in gbrain's tree
 - `lint_failed` — privacy linter caught something. Go back to Phase 3,
@@ -209,9 +225,30 @@
   use a different slug, or pass `--overwrite-local` if you really
   mean to replace.
 
+
+#### Phase 4 — Real harvest — steps
+
+> Once Phase 3 is complete, run the real harvest:
+
+```bash
+gbrain skillpack harvest <slug> --from <host-repo-root>
+```
+
+
+#### Phase 4 — Real harvest — steps 2
+
+- `openclaw.plugin.json` updated to add the slug, sorted
+
 ### Phase 5 — Verify in gbrain
-
-After a successful harvest:
+use judgment to follow the Phase 5 — Verify in gbrain guidance:
+
+5. Commit the additions in gbrain (do NOT commit any leftover files
+   in the host repo — harvest is a copy, not a move).
+
+
+#### Phase 5 — Verify in gbrain — steps
+
+> After a successful harvest:
 
 1. `bun test test/skills-conformance.test.ts` — confirms the new
    SKILL.md meets the frontmatter contract.
@@ -219,10 +256,8 @@
    bundle and gbrain's own checkout.
 3. `gbrain skillpack list` — confirms the slug shows up in the bundle.
 4. Review the diff: `cd <gbrainRoot> && git diff -- skills/<slug>/`
-5. Commit the additions in gbrain (do NOT commit any leftover files
-   in the host repo — harvest is a copy, not a move).
-
 ### Phase 6 — Downstream announcement (optional)
+use judgment to follow the Phase 6 — Downstream announcement (optional) guidance:
 
 If other gbrain clients should pick up the new skill:
 - Note it in `CHANGELOG.md` under "Skills added" for the next release
@@ -230,6 +265,18 @@
   someone outside the core team
 
 ## Bypass: `--no-lint`
+use judgment to follow the Bypass: `--no-lint` guidance:
+
+**Document the bypass in the commit message.** Future maintainers
+should be able to see WHY the lint was bypassed (e.g. "Wintermute
+appears in a citation, not a real reference — verified manually").
+
+Never bypass the linter on a casual basis. The whole point of the
+default-on lint is that real names occasionally slip through the
+editorial pass.
+
+
+### Bypass: `--no-lint` — steps
 
 The privacy linter is the safety net. The editorial pass is the
 primary defense. If you've completed Phase 3 thoroughly and the
@@ -239,15 +286,7 @@
 gbrain skillpack harvest <slug> --from <host-repo-root> --no-lint
 ```
 
-**Document the bypass in the commit message.** Future maintainers
-should be able to see WHY the lint was bypassed (e.g. "Wintermute
-appears in a citation, not a real reference — verified manually").
-
-Never bypass the linter on a casual basis. The whole point of the
-default-on lint is that real names occasionally slip through the
-editorial pass.
-
-## What harvest does NOT do
+## What harvest does NOT do (( inert ))
 
 - It does NOT move files (it copies). The host's `skills/<slug>/`
   stays in place.
@@ -258,13 +297,16 @@
 - It does NOT support `--all` (no batch harvest). One skill at a
   time keeps the editorial review tractable.
 
-## Files this skill touches
-
-- gbrain's `skills/<slug>/` — every file in the host skill dir
-  (copy)
+## Files this skill touches (( inert ))
+
 - gbrain's mirror path for declared paired sources
   (e.g. `src/commands/<slug>.ts` if the host SKILL.md declares it
   in frontmatter)
 - gbrain's `openclaw.plugin.json` — adds the slug to `skills:`
   array, sorted alphabetically
 
+
+### Files this skill touches — steps
+
+- gbrain's `skills/<slug>/` — every file in the host skill dir
+  (copy)
```
