# Deviation: skillpack_harvest.meri

- Original: `skillpack-harvest/SKILL.md`
- Ported: `skillpack_harvest.meri`
- Tier: 2 (light edits)
- Similarity: 64%
- Lines: 270 -> 316 (+129 / -83)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- preamble-blockquoted
- doc-section-marked

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L34 `Output Format`: template - Template/output shape is metadata unless explicit output assertions are authored.
- L77 `When to invoke`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L236 `Phase 6 — Downstream announcement (optional)`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L267 `What harvest does NOT do`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.

## Metrics
- Sections inert total: 14/14 (100% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert markers (`(( inert ))`, target 0 — the migrator never emits these): 0
- Inert categories: reference-documentation=13, template=1
- Judgment: 2 blocks, 0 lines

### Inert section details
- L13 `Contract`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L34 `Output Format`: template — Template/output shape is metadata unless explicit output assertions are authored.
- L50 `Anti-Patterns`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L77 `When to invoke`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L89 `Preconditions`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L107 `Phase 1 — Plan`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L120 `Phase 2 — Dry-run + privacy-lint preview`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L142 `Phase 3 — Genericization checklist (the editorial pass)`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L191 `Phase 4 — Real harvest`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L220 `Phase 5 — Verify in gbrain`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L236 `Phase 6 — Downstream announcement (optional)`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L243 `Bypass: `--no-lint``: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L267 `What harvest does NOT do`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L278 `Files this skill touches`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.

## Unified diff

```diff
--- original-skills/skillpack-harvest/SKILL.md
+++ skills/skillpack_harvest.meri
@@ -31,12 +31,12 @@
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
+## Contract (( role: reference ))
 
 A harvest is "properly done" when:
 
@@ -52,10 +52,12 @@
 6. The user has reviewed the diff in gbrain and explicitly approved
    the commit.
 
-If any of these is incomplete, the skill is NOT yet harvested — the
-files may sit in gbrain's working tree, but they're not landed.
-
-## Output Format
+
+### Contract — steps
+
+If any of these is incomplete, the skill is NOT yet harvested — the files may sit in gbrain's working tree, but they're not landed.
+
+## Output Format (( role: template ))
 
 This skill produces three artifacts in gbrain's working tree:
 
@@ -71,25 +73,34 @@
 a list of files written. JSON mode (`--json`) returns the full
 `HarvestResult` shape for machine consumption.
 
-## Anti-Patterns
-
-- **Skipping the dry-run.** Always preview first. Files land in
-  gbrain's working tree; cleanup is a `git checkout` away, but you
-  shouldn't need to.
+## Anti-Patterns (( role: reference ))
+
 - **Trusting the linter alone.** The default regex set catches the
   common cases. It doesn't catch every proper noun. Phase 3 (the
   editorial pass) is the primary defense.
-- **Harvesting `--no-lint` without justification.** The lint exists
-  for a reason. If you bypass it, document why in the commit.
 - **Harvesting a skill that's still in flux.** Wait until the host
   version stabilizes. Otherwise you'll harvest, then re-harvest,
   then re-harvest, and that churns gbrain's bundle for no benefit.
 - **Moving files instead of copying.** Harvest is a copy. The host
   retains its skill. Don't `rm -rf` the source after harvesting.
+
+### Anti-Patterns — steps
+
+- Skipping the dry-run. Always preview first. Files land in gbrain's working tree; cleanup is a `git checkout` away, but you shouldn't need to.
+
+### Anti-Patterns — steps 2 (( role: reference ))
+
+use judgment to follow the Anti-Patterns — steps 2 guidance:
+- **Harvesting `--no-lint` without justification.** The lint exists
+  for a reason. If you bypass it, document why in the commit.
+
+### Anti-Patterns — steps 3 (( role: reference ))
+
+use judgment to follow the Anti-Patterns — steps 3 guidance:
 - **Harvesting batch (multiple skills at once).** Not supported, and
   for good reason — the editorial review per skill is real work.
 
-## When to invoke
+## When to invoke (( role: reference ))
 
 - The user developed a skill in their host fork (Wintermute, Neuromancer,
   Zion, etc.) and wants other gbrain clients to be able to use it
@@ -101,12 +112,7 @@
 - The skill references private content that can't be generalized
 - The user just wants to share a one-off draft (use a gist instead)
 
-## Preconditions
-
-Before running this skill, confirm:
-
-1. **The skill is mature.** Recent `routing-eval.jsonl` cases pass; the
-   skill has been used in production at least a few times.
+## Preconditions (( role: reference ))
 
 2. **The skill is generalizable.** Strip-test in your head: replace
    every fork-specific name. Does it still make sense as a skill?
@@ -115,25 +121,29 @@
    gbrain's working tree. They'll review and commit. Don't harvest
    into a checkout the user doesn't intend to commit from.
 
+
+### Preconditions — steps
+
+> Before running this skill, confirm:
+
+1. The skill is mature. Recent `routing-eval.jsonl` cases pass; the skill has been used in production at least a few times.
+
 ## Workflow
 
-### Phase 1 — Plan
-
-Ask the user:
-- What slug should the harvested skill have? (Slugs must be kebab-case,
-  globally unique in the gbrain bundle.)
+### Phase 1 — Plan (( role: reference ))
+
 - Which host repo is the source? (Path to repo root, not to the skill
   directory — e.g. `~/git/wintermute`, not `~/git/wintermute/skills/foo`.)
 - Should paired source files come along? (Check the host SKILL.md's
   frontmatter `sources:` array.)
 
-### Phase 2 — Dry-run + privacy-lint preview
-
-Run the CLI with `--dry-run`:
-
-```bash
-gbrain skillpack harvest <slug> --from <host-repo-root> --dry-run
-```
+
+### Phase 1 — Plan — steps (( role: reference ))
+
+> Ask the user:
+- What slug should the harvested skill have? (Slugs must be kebab-case,
+  globally unique in the gbrain bundle.)
+### Phase 2 — Dry-run + privacy-lint preview (( role: reference ))
 
 The output shows:
 - Which files would land in gbrain's tree
@@ -146,11 +156,16 @@
 land. Spot-check the SKILL.md and any paired source for things the
 linter might miss (proper nouns, internal project names, etc.).
 
-### Phase 3 — Genericization checklist (the editorial pass)
-
-Before running the real harvest, walk the host's `skills/<slug>/`
-files and apply this checklist. If anything matches, edit the host
-file FIRST, then run harvest.
+
+### Phase 2 — Dry-run + privacy-lint preview — steps
+
+Run the CLI with `--dry-run`:
+
+```bash
+gbrain skillpack harvest <slug> --from <host-repo-root> --dry-run
+```
+
+### Phase 3 — Genericization checklist (the editorial pass) (( role: reference ))
 
 1. **Fork-specific names → generic phrasing**
    - `Wintermute` → `your OpenClaw` (or `OpenClaw deployment`)
@@ -161,46 +176,51 @@
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
+### Phase 3 — Genericization checklist (the editorial pass) — steps (( role: reference ))
+
+Before running the real harvest, walk the host's `skills/<slug>/`
+files and apply this checklist. If anything matches, edit the host
+file FIRST, then run harvest.
+
+
+### Phase 3 — Genericization checklist (the editorial pass) — steps 2
+
    - Email addresses → strip entirely OR use `example@example.com`
    - Internal Slack channels → `#some-channel` or strip
-   - Specific tracker IDs / Linear ticket numbers → strip
-
-3. **Fork-specific conventions → references**
+
+### Phase 3 — Genericization checklist (the editorial pass) — steps 3
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
-### Phase 4 — Real harvest
-
-Once Phase 3 is complete, run the real harvest:
-
-```bash
-gbrain skillpack harvest <slug> --from <host-repo-root>
-```
+### Phase 4 — Real harvest (( role: reference ))
 
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
@@ -209,9 +229,29 @@
   use a different slug, or pass `--overwrite-local` if you really
   mean to replace.
 
-### Phase 5 — Verify in gbrain
-
-After a successful harvest:
+
+### Phase 4 — Real harvest — steps
+
+> Once Phase 3 is complete, run the real harvest:
+
+```bash
+gbrain skillpack harvest <slug> --from <host-repo-root>
+```
+
+
+### Phase 4 — Real harvest — steps 2
+
+- `openclaw.plugin.json` updated to add the slug, sorted
+
+### Phase 5 — Verify in gbrain (( role: reference ))
+
+5. Commit the additions in gbrain (do NOT commit any leftover files
+   in the host repo — harvest is a copy, not a move).
+
+
+### Phase 5 — Verify in gbrain — steps (( role: reference ))
+
+> After a successful harvest:
 
 1. `bun test test/skills-conformance.test.ts` — confirms the new
    SKILL.md meets the frontmatter contract.
@@ -219,17 +259,21 @@
    bundle and gbrain's own checkout.
 3. `gbrain skillpack list` — confirms the slug shows up in the bundle.
 4. Review the diff: `cd <gbrainRoot> && git diff -- skills/<slug>/`
-5. Commit the additions in gbrain (do NOT commit any leftover files
-   in the host repo — harvest is a copy, not a move).
-
-### Phase 6 — Downstream announcement (optional)
+### Phase 6 — Downstream announcement (optional) (( role: reference ))
 
 If other gbrain clients should pick up the new skill:
 - Note it in `CHANGELOG.md` under "Skills added" for the next release
 - Tag the user / contributor in the PR if the skill came from
   someone outside the core team
 
-## Bypass: `--no-lint`
+## Bypass: `--no-lint` (( role: reference ))
+
+**Document the bypass in the commit message.** Future maintainers
+should be able to see WHY the lint was bypassed (e.g. "Wintermute
+appears in a citation, not a real reference — verified manually").
+
+
+### Bypass: `--no-lint` — steps (( role: reference ))
 
 The privacy linter is the safety net. The editorial pass is the
 primary defense. If you've completed Phase 3 thoroughly and the
@@ -239,15 +283,14 @@
 gbrain skillpack harvest <slug> --from <host-repo-root> --no-lint
 ```
 
-**Document the bypass in the commit message.** Future maintainers
-should be able to see WHY the lint was bypassed (e.g. "Wintermute
-appears in a citation, not a real reference — verified manually").
+
+### Bypass: `--no-lint` — steps 2 (( role: reference ))
 
 Never bypass the linter on a casual basis. The whole point of the
 default-on lint is that real names occasionally slip through the
 editorial pass.
 
-## What harvest does NOT do
+## What harvest does NOT do (( role: reference ))
 
 - It does NOT move files (it copies). The host's `skills/<slug>/`
   stays in place.
@@ -258,13 +301,16 @@
 - It does NOT support `--all` (no batch harvest). One skill at a
   time keeps the editorial review tractable.
 
-## Files this skill touches
-
-- gbrain's `skills/<slug>/` — every file in the host skill dir
-  (copy)
+## Files this skill touches (( role: reference ))
+
 - gbrain's mirror path for declared paired sources
   (e.g. `src/commands/<slug>.ts` if the host SKILL.md declares it
   in frontmatter)
 - gbrain's `openclaw.plugin.json` — adds the slug to `skills:`
   array, sorted alphabetically
 
+
+### Files this skill touches — steps (( role: reference ))
+
+- gbrain's `skills/<slug>/` — every file in the host skill dir
+  (copy)
```
