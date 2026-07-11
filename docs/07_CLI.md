# Meridian — CLI Reference

The `meridian` executable has a thin `Sources/MeridianCLI/` entry point; command
implementations live in the testable `Sources/MeridianCLIKit/` module.

---

## Global usage

```
meridian <subcommand> [options]
meridian --help
meridian --version
```

---

## `meridian compile`

Compile one `.meridian` file (with its associated `.merconfig` vocabularies)
to Swift source and a companion manifest.

```
meridian compile <source> [options]
```

### Positional arguments

| Argument | Description |
|---|---|
| `<source>` | Path to the `.meridian` source file |

### Options

| Flag | Default | Description |
|---|---|---|
| `--merconfig <path>` | auto-detected | Path to a `.merconfig` file. **Repeatable** — pass once per vocabulary. If omitted, all `.merconfig` files in the same directory as `<source>` are loaded (sorted alphabetically). Falls back to the parent directory if none are found there. |
| `--rulebook <path>` | auto-detected | Path to a `.merrules` rulebook. **Repeatable**. If omitted, all `.merrules` files in the same directory as `<source>` are loaded (sorted alphabetically), falling back to the parent directory. Required for skill files that reference `rulebook:` in frontmatter. |
| `-o, --output <dir>` | `build` | Directory to write the generated `.swift` and `.meridian.manifest.json`. Created with intermediate directories if needed. |
| `--timestamp` | false | Include a generation timestamp in the generated file header. |
| `--no-line-comments` | false | Suppress `// L{n}` source-line comments in generated code. |
| `--namespace <auto\|none>` | `auto` | Wrap generated declarations in `public enum <Stem> { … }` by default. Use `none` for flat output. |
| `--no-format` | false | Skip `swift-format` post-processing. |
| `--trace <categories>` | (none) | Enable `ParserTrace` output. Comma or space-separated. Examples: `phrase`, `phrase.match`, `lowering`, `timing`, `all`. Also read from `MERIDIAN_TRACE` env var. |
| `--trace-file <path>` | stderr | Write trace output to a file instead of stderr. |
| `--diagnostics-format <human\|json>` | `human` | `human` is the snippet + caret form; `json` is the stable machine schema for editors/CI (includes the `decision` id). |
| `--fix` | false | Preview unambiguous quick-fixes (a diagnostic with one ranged suggestion). **Dry-run** unless `--write`. The fixer narrows to the single misspelled token and only applies an unambiguous best match, so it can't corrupt a line. |
| `--write` | false | With `--fix`, apply the previewed fixes to the source files in place. |

### Output files

Two files are written to the output directory:
- `{stem}.swift` — the generated Swift source (domain types, constants, instances, workflow structs)
- `{stem}.meridian.manifest.json` — the **complete** companion manifest:
  parameters, event IDs, tool IDs, source-map entries, frontmatter metadata,
  the heading `outline`, and (for sectioned documents) `meridian_skill.sections`
  recording every section verbatim with its resolved role and `executes` flag.
  The CLI writes the full `ManifestEmitter.Input` assembled by
  `Compiler.compileWithManifest`, not a thin stub.

### Successful output

On success, prints `✓ <output-path>` and exits with code 0.

### Exit codes

| Code | Meaning |
|---|---|
| 0 | Success |
| 1 | Parse, compile, or I/O error |

Trace setup errors use the same exit path. An unknown `--trace` token is a
coded `MER2010` hard error with did-you-mean guidance; an unwritable
`--trace-file` path is `MER5011`. Both render before the command does its main
work and exit 1.

---

## Quick examples

```bash
# Basic compile, output to ./build/
meridian compile examples/order_processing.meridian

# Specify output dir
meridian compile examples/order_processing.meridian --output build/

# Explicit merconfig path
meridian compile examples/order_processing.meridian \
    --merconfig examples/ecommerce.merconfig

# Multiple vocabularies
meridian compile examples/order_processing.meridian \
    --merconfig examples/ecommerce.merconfig \
    --merconfig examples/payments.merconfig

# Compile without swift-format (useful in CI for speed)
meridian compile examples/order_processing.meridian --no-format

# Suppress source-line comments
meridian compile examples/order_processing.meridian --no-line-comments

# Enable phrase-matching trace to stderr
meridian compile examples/order_processing.meridian --trace phrase.match

# Enable all phrase tracing and write to a log file
meridian compile examples/order_processing.meridian \
    --trace phrase \
    --trace-file /tmp/meridian-trace.log

# Enable everything
meridian compile examples/order_processing.meridian --trace all
```

---

## `meridian check` / `meridian verify`

Parse, lower, and type-check a `.meridian` file without writing generated
Swift. Useful in CI pipelines to verify a source compiles before any
downstream build step.

`verify` shares `check`'s diagnostics and trace behavior.

```bash
meridian check examples/order_processing.meridian \
    --merconfig examples/ecommerce.merconfig

meridian verify examples/order_processing.meridian \
    --merconfig examples/ecommerce.merconfig \
    --trace phrase.match
```

Both commands:
- Accept a repeatable `--merconfig` flag (same auto-detection logic as `compile`).
- Accept `--trace <categories>` and `--trace-file <path>` (full parity with `compile`).
- Accept `--diagnostics-format <human|json>`, `--fix`, and `--write` (same
  semantics as `compile`).
- Render diagnostics with source snippets + carets (rulebooks beside the source
  are auto-loaded so their diagnostics resolve too).
- Print a success summary (vocabulary count) on exit 0.
- Print all collected compiler diagnostics to stderr and exit 1 on failure.

```bash
# Machine-readable diagnostics for an editor / CI
meridian check order.meridian --diagnostics-format json

# Preview a did-you-mean fix, then apply it
meridian check order.meridian --fix
meridian check order.meridian --fix --write
```

---

## `meridian bench-parse`

Benchmark parser infrastructure over newline-delimited expression/sentence
files. Reports two timings for the (sole) per-production `ExpressionParser`
dispatcher: unscreened (every `clause`/`atom` alternative tried
unconditionally) vs `NonterminalScreen`-gated (the live pre-filter used in
normal compilation) — the speedup the screen buys on top of dispatch.

```bash
meridian bench-parse parser-fixtures.txt
```

Output:

```text
sentences: 42
unscreened: 0.002345 s
screened:   0.002100 s
screened candidates: 57
```

---

## `meridian run`

Compile and execute a workflow end-to-end: generates Swift, writes it plus a
manifest to the output directory, scaffolds a temporary SwiftPM package,
builds it, and runs the generated workflow with `MeridianRuntime`.

Blueprint built-ins from `MeridianTools.registerBuiltins()` are available
automatically; tool stubs override them.

```bash
meridian run <source> [options]
```

### Options

| Flag | Default | Description |
|---|---|---|
| `--merconfig <path>` | auto-detected | Repeatable vocabulary input |
| `-o, --output <dir>` | current directory | Where to write generated `.swift` and `.meridian.manifest.json` before building |
| `--workflow <StructName>` | first workflow | Workflow to run (by struct name or natural name) |
| `--input-json <name=JSON>` | (none) | Repeatable workflow parameter as `name={"key":"value"}` |
| `--tool-stub <toolID=JSON>` | (none) | Repeatable tool stub; returns the given JSON for every invocation |
| `--run-id <id>` | `cli-run` | Run ID passed to the runtime |
| `--checkpoint-root <dir>` | (none) | Use `FilesystemCheckpointer` rooted at this directory |
| `--keep-temp` | false | Keep the temporary SwiftPM package and print its path to stderr |
| `--trace <categories>` | (none) | Enable `ParserTrace` output for the compile step (same categories as `compile`) |
| `--trace-file <path>` | stderr | Write trace output to a file instead of stderr |

### Notes

- `--run-id` defaults to `cli-run`; set it explicitly for replay-safe resumable runs.
- `--checkpoint-root` enables `FilesystemCheckpointer`; omitting it uses `InMemoryCheckpointer`.
- The temporary SwiftPM package is removed after the run unless `--keep-temp` is set.
- Requires the `meridian` repository `Package.swift` to be reachable from the working
  directory (searches up to 12 parent directories). If not found, the command exits with
  "could not locate Meridian Package.swift".

### Example

```bash
meridian run examples/order_processing.meridian \
    --merconfig examples/ecommerce.merconfig \
    --workflow ProcessOrder \
    --input-json 'order={"id":"o-001","status":"submitted","totalAmount":6000}' \
    --input-json 'customer={"id":"c-001","tier":"enterprise"}' \
    --tool-stub 'validateOrder={"verdict":"valid","issues":[]}' \
    --run-id my-run-001 \
    --checkpoint-root .checkpoints
```

---

## `meridian resume`

Load the latest checkpoint for a run ID and print the restored runtime context
as JSON. Useful to inspect what state a crashed or interrupted workflow had
reached.

```bash
meridian resume <run-id> [--checkpoint-root <dir>]
```

| Flag | Default | Description |
|---|---|---|
| `--checkpoint-root <dir>` | `~/Library/Caches/meridian-checkpoints` | Directory that holds run checkpoints |

Output is JSON:

```json
{
  "bindings": { "order": "…", "result": "…" },
  "last_checkpoint_label": "progress:0.2:L85:C0",
  "run_id": "my-run-001"
}
```

To resume execution from the checkpoint, use `meridian run` with the same
`--run-id` and `--checkpoint-root`. Generated workflows with `commit`
statements automatically restore state and skip already-executed steps.

---

## `meridian format`

Canonicalise the whitespace of `.meridian` and `.merconfig` source files.
The formatter is conservative — it only adjusts indentation and trailing
punctuation, never changes semantics.

```bash
meridian format <files…>
```

| Flag | Default | Description |
|---|---|---|
| `--check` | false | Don't write; exit 1 if any file would be reformatted. CI mode. |
| `--stdout` | false | Write formatted result to stdout instead of in-place. |

Passing `-` or omitting the file list reads from stdin and writes to stdout.

```bash
# Format in-place
meridian format examples/order_processing.meridian

# CI gate — exit 1 if any file is not already formatted
meridian format --check examples/order_processing.meridian

# Pipe
cat order_processing.meridian | meridian format -
```

---

## `meridian docs`

Render one or more `.merconfig` files to a static HTML reference document.
The output is a single self-contained file (inline CSS, no JavaScript) that
can be opened directly from disk or published from CI.

```bash
meridian docs <merconfig-files…> [--output <file>] [--title <text>]
```

| Flag | Default | Description |
|---|---|---|
| `--output <file>` | stdout | Output HTML file path |
| `--title <text>` | `Meridian vocabulary` | Page title |

At least one `.merconfig` path is required. Multiple files are each rendered
into their own labelled `<article>` section.

```bash
# Write HTML to file
meridian docs examples/ecommerce.merconfig --output docs/ecommerce.html

# Multiple vocabularies
meridian docs examples/ecommerce.merconfig examples/payments.merconfig \
    --output docs/full-vocab.html \
    --title "Ecommerce vocabulary"

# Preview to stdout
meridian docs examples/ecommerce.merconfig | open -f -a Safari
```

Rendered sections: kinds, properties, relations, phrases, constants, instances, tools.

---

## `meridian lint`

Report Meridian authoring diagnostics without compiling or lowering the file.
This is a lightweight preflight for editor integrations and quick local checks.

```bash
meridian lint <input> [--format human|json]
```

| Flag | Default | Description |
|---|---|---|
| `--format <human\|json>` / `--diagnostics-format <human\|json>` | `human` | Render through the shared `DiagnosticRenderer`; `json` is the stable editor/CI schema. |

Human output uses the same snippet + caret renderer as compiler diagnostics:

```text
warning[MER6001]: polite command wording
  --> path/to/file.meri:12:3
     |
  12 |   please fetch orders.
     |   ^^^^^^
```

The command exits non-zero when any diagnostic has severity `error`.

---

## `meridian preview-skill`

Preview a `SKILL.md` file as Meridian surface syntax using
`SkillMarkdownImporter`. This is a read-only preview; use `migrate-skill` for
strict compilation and deterministic marking.

```bash
meridian preview-skill <SKILL.md> [--name <frontmatter-name>]
```

| Flag | Default | Description |
|---|---|---|
| `--name <text>` | `imported skill` | Name to place in generated frontmatter |
| `--trace <categories>` | (none) | Enable `ParserTrace` output; logs under the `skill` category |
| `--trace-file <path>` | stderr | Write trace output to a file instead of stderr |

---

## `meridian test`

Discover and run `.meridian.test` spec files. Each spec is compiled in-process
and assertions are evaluated against the compiler output and (optionally) a
runtime execution.

```bash
meridian test <paths…> [options]
```

| Flag | Default | Description |
|---|---|---|
| `--verbose` | false | Print fuller diffs on golden mismatches and runtime failures |
| `--update-golden` | false | Overwrite golden files with current output instead of failing |
| `--quiet` | false | Suppress individual success lines; print only the summary |
| `--tag <tag>` | (none) | Run only specs that carry this tag. **Repeatable.** |
| `--filter <name>` | (none) | Run only specs whose display name contains this string |

Paths can be individual `.meridian.test` files or directories to scan recursively.

```bash
# Run all specs
swift run meridian test Tests/MeridianCoreTests/MeridianTestSpecs

# Run only runtime specs
swift run meridian test Tests/MeridianCoreTests/MeridianTestSpecs --tag runtime

# Update goldens after intentional codegen drift
swift run meridian test Tests/MeridianCoreTests/MeridianTestSpecs --update-golden

# Run a single spec verbosely
swift run meridian test Tests/MeridianCoreTests/MeridianTestSpecs/runtime_happy.meridian.test --verbose
```

See [09_MERIDIAN_TESTS.md](09_MERIDIAN_TESTS.md) for the full spec format reference.

---

## `meridian trace render`

Read a JSONL event stream and print it as an indented tree. Useful for making
a dense `events.jsonl` digestible when triaging a failed CI run.

```bash
meridian trace render [<file.jsonl>] [options]
```

Reads stdin when no file is given. Malformed lines are silently skipped.

| Flag | Default | Description |
|---|---|---|
| `--ascii` | false | Use ASCII glyphs instead of Unicode box-drawing characters |
| `--no-timings` | false | Hide the invoke/wait timing column |
| `--no-sources` | false | Hide `@file:line` source-range suffixes |

```bash
# Render from file
meridian trace render build/events.jsonl

# Pipe from a run
meridian run examples/order_processing.meridian | meridian trace render

# Render with ASCII glyphs (for terminals without Unicode)
meridian trace render build/events.jsonl --ascii

# Clean view without timings or source ranges
meridian trace render build/events.jsonl --no-timings --no-sources
```

---

## `meridian trace categories`

List every compile-time trace category (the tokens accepted by `--trace`) with
a one-line description. Discoverability companion to `--trace`.

```bash
meridian trace categories
```

---

## `meridian explain`

Compile a `.meridian` / `.meri` file to a `VerbalizerModel` and print the
Canonical English form of the lowered IR. This is Wave 7's "what did the
compiler understand?" command; diagnostic explanations live under
`explain-diag`.

```bash
meridian explain <source> [options]
```

| Flag | Default | Description |
|---|---|---|
| `--merconfig <path>` | auto-detected | Path to a `.merconfig` file. Repeatable; same auto-detection as `compile`. |
| `--rulebook <path>` | auto-detected | Path to a `.merrules` rulebook. Repeatable; same auto-detection as `compile`. |
| `--trace <categories>` | (none) | Enable `ParserTrace`; canonical emission logs under `verbalizer`. |
| `--trace-file <path>` | stderr | Write trace output to a file instead of stderr. |

Example:

```bash
meridian explain corpora/erp/skills/placeorder.meri \
    --merconfig corpora/erp/erp.merconfig \
    --rulebook corpora/erp/erp.merrules
```

The output is intended for audit and review. It normalizes accepted synonyms and
rulebook sugar to one stable spelling, and it omits documentation/reference
sections that do not lower to IR. The SEM-8-03 gate recompiles this output and
checks IR structural equality. See [18_VERBALIZER.md](18_VERBALIZER.md).

---

## `meridian drift`

Compare authored source against its Canonical English form. The command compiles
the input, verbalizes the lowered model, then reports line-level drift hunks.

```bash
meridian drift <source> [options]
```

| Flag | Default | Description |
|---|---|---|
| `--merconfig <path>` | auto-detected | Path to a `.merconfig` file. Repeatable. |
| `--rulebook <path>` | auto-detected | Path to a `.merrules` rulebook. Repeatable. |
| `--json` | false | Emit stable JSON instead of Markdown. |
| `--trace <categories>` | (none) | Enable `ParserTrace`; useful categories include `verbalizer` and `drift`. |
| `--trace-file <path>` | stderr | Write trace output to a file instead of stderr. |

Markdown output groups hunks by category:

| Category | Meaning |
|---|---|
| `Synonym canonicalized` | Accepted wording changed to the canonical marker. |
| `Structure normalized` | Whitespace or structural layout changed. |
| `Desugar expanded` | A compact idiom/rulebook form expanded to explicit statements. |
| `Meaning-bearing` | Conservative catch-all for differences worth review. |

Example:

```bash
meridian drift corpora/incident/skills/triagealert.meri \
    --merconfig corpora/incident/incident.merconfig \
    --rulebook corpora/incident/incident.merrules
```

`Meaning-bearing` is an audit signal, not an automatic semantic-failure label:
documentation-heavy SKILL files often show many such hunks because reference
sections are retained in manifests but omitted from canonical IR source.

On already-canonical input (for example after `meridian explain` writes the
verbalized source), `meridian drift --json` should report `"total": 0`. The
CLI E2E locks for capture/triagealert assert this zero-drift property.

---

## `meridian grammar-doc`

Emit a Markdown reference for the canonical surface grammar registered in
`GrammarTable` / `PegexSurfaceGrammar`. The output is generated from the live
grammar table, so it is useful for reviewing the current canonical examples and
anchors.

```bash
meridian grammar-doc
```

This command takes no options and writes Markdown to stdout.

---

## `meridian explain-diag`

Print the long-form explanation for a diagnostic code — its cause and fix — plus
the rationale and alternatives of the governing design decision. So "why is this
an error?" is one command away from the error itself.

```bash
meridian explain-diag <code|decision-id>
```

| Argument | Description |
|---|---|
| `<code\|decision-id>` | A diagnostic code (e.g. `MER2002`) or a decision id (e.g. `D-DX-5`). |

```bash
# Explain a diagnostic code (cause + fix + linked decision)
meridian explain-diag MER2002

# Explain a design decision directly
meridian explain-diag D-DX-5
```

An unknown id is itself a guided error: it suggests the closest code/decision id.

---

## `meridian decisions`

List, search, or render the structured design-decision catalog
(`DecisionCatalog`). The decision log is queryable from the CLI, not just a doc.

```bash
meridian decisions [query] [options]
```

| Flag | Default | Description |
|---|---|---|
| `[query]` | (none) | Filter decisions by id/title/rationale substring. |
| `--id <D-DX-n>` | (none) | Print one decision in full (rationale, alternatives, consequences, see-also). |
| `--render <path>` | (none) | Regenerate the readable decision log Markdown (`docs/15_DECISIONS.md`) from the catalog. A test fails if the committed file drifts. |

```bash
# List every decision
meridian decisions

# Search
meridian decisions tool

# Full detail for one
meridian decisions --id D-DX-5

# Regenerate the readable log (kept in sync by a staleness test)
meridian decisions --render docs/15_DECISIONS.md
```

See [14_DEVELOPER_EXPERIENCE.md](14_DEVELOPER_EXPERIENCE.md) for the full
diagnostics + decisions story and [15_DECISIONS.md](15_DECISIONS.md) for the
generated log.

---

## Config file auto-detection

If `--merconfig` is not specified, the compiler searches:

1. All files with `.merconfig` extension in the same directory as `<source>` (sorted alphabetically).
2. All files with `.merconfig` extension in the **parent** directory (if none found in step 1).

When multiple files are found, they are all merged as if each had been passed
separately with `--merconfig`. Duplicate kind/phrase/tool/constant/instance names
across merged vocabularies are rejected with a sourced semantic error.

If none is found, the compiler proceeds without a vocabulary. The compiler is
**strict by default**: an unresolved phrase or unknown tool is a coded error
(MER2001 / MER2002) with a did-you-mean, not a silent `_unresolved` bind. Opt
into placeholders per-file with frontmatter `allow-fallbacks: unresolved-phrases`
(see [14_DEVELOPER_EXPERIENCE.md](14_DEVELOPER_EXPERIENCE.md) §6).

---

## Trace categories

See [08_TRACING.md](08_TRACING.md) for the full list. The most useful ones
during development:

| Category | What it shows |
|---|---|
| `tokenize` | Fence/table collapse, headings, indent/comment decisions |
| `parse` | Top-level parse spans and parser branch routing |
| `phrase` | All phrase pipeline stages (parse, match, args, inline) |
| `phrase.match` | Which phrases are candidates and which wins |
| `phrase.args` | Argument text extracted from each invocation slot |
| `phrase.inline` | Body expansion and substitution steps |
| `phrase.parse` | Pattern tokenisation |
| `expression` | Expression parsing decisions |
| `statement` | Per-statement parser dispatch |
| `lowering` | AST → IR lowering + rule classification |
| `symbols` | Symbol-table construction |
| `merconfig` | MerConfig section and phrase parsing |
| `rulebook` | `.merrules` parsing + rewrite |
| `skill` | Section-role classification + scoped tools |
| `codegen` | Swift/manifest/domain emission |
| `verbalizer` | Canonical English emission from validated IR |
| `drift` | Authored-vs-canonical hunk classification |
| `diagnostics` | Every emitted diagnostic |
| `timing` | Per-phase wall-clock + compile profile (off by default) |
| `all` | Everything (verbose) |

Run `meridian trace categories` to print this list with descriptions.

The `MERIDIAN_TRACE` environment variable is also read at startup:

```bash
MERIDIAN_TRACE=phrase.match meridian compile examples/order_processing.meridian
```

The `--trace` flag (and its `--trace-file` companion, to redirect output to a
file instead of stderr) is available on `compile`, `check`, `verify`, `run`,
`migrate-skill`, `preview-skill`, `explain`, `drift`, `inert-yield`, and
`skill-deviation` — every subcommand that runs the compiler, verbalizer, drift,
or skill-migration analysis pipeline. `migrate-skill` and `preview-skill` log
under the `.skill` category (`meridian migrate-skill SKILL.md --trace skill`);
`explain` logs canonical emission under `.verbalizer`; `drift` and
`skill-deviation` can log hunk classification under `.drift`.

Unknown trace categories are `MER2010` hard errors. Unwritable trace files are
`MER5011` hard errors at startup; if an already-opened file sink fails
mid-stream, the trace visibly falls back to stderr.

---

## SwiftFormat integration

Unless `--no-format` is passed, `CompileCommand` pipes the emitted Swift
string through `swift-format` with:
- Indentation: 4 spaces
- Line length: 120

Errors during formatting are non-fatal: the unformatted source is written
to the output file and a warning is printed to stderr.

---

## End-to-end smoke test

Compile, build, and run the example workflow:

```bash
# Step 1: compile
meridian compile examples/order_processing.meridian \
    --merconfig examples/ecommerce.merconfig \
    --output build/

# Step 2: run directly (no manual build step needed)
meridian run examples/order_processing.meridian \
    --merconfig examples/ecommerce.merconfig \
    --workflow ProcessOrder \
    --input-json 'order={"id":"o-001"}' \
    --input-json 'customer={"id":"c-001"}'

# Or use meridian test to verify against spec fixtures
meridian test Tests/MeridianCoreTests/MeridianTestSpecs
```

---

## `meridian migrate-skill`

Convert a gbrain-style `SKILL.md` into a strict-compiling `.meri`. The
migrator (`Sources/MeridianCore/Migration/SkillMigrator.swift`) **injects no
frontmatter** — section semantics activate structurally on the `##`/`###`
headings (there is no `skill: true` flag), and `vocabulary:`/`rulebook:` are
autodiscovered beside the input by the CLI. It runs one deterministic marking
pass, backed by the real `SymbolTable`/lexicon/rulebook built from those
vocabularies (not shape heuristics), so a line only counts as prose if it
actually fails to trial-lower:

The migrator **never emits `(( inert ))`** — every content unit is classified
into exactly one of four buckets (P1, `docs/13_SKILL_MD_PORTING.md`
§"The governing principle"):

1. **Per-line classification.** Every body line is trial-parsed and lowered:
   `executable` (compiles as-is), `checkable` (a predicate), `annotation
   label` (a `:`-terminated line immediately before a command/fence), an
   `EnglishLexicon.inferenceCueWords` cue (a cognitive verb like "analyse" /
   "understand" / "decide" — the *only* signal that may route to AI
   judgment), an `EnglishLexicon.normativeCueWords` cue with no inference cue
   (an operational/normative line — e.g. "must"/"never" — left for the real
   compiler to reject with a precise reword diagnostic), or genuine
   `documentation` (an `EnglishLexicon.referenceHeadingWords` heading, or body
   text with no operational or inference signal at all).
2. **Automatic mixed-section split.** A heading whose body mixes narrative and
   non-narrative content is split: narrative stays under the original heading
   (marked `(( role: reference ))` only when real leftover content remains),
   and each contiguous executable-or-AI-inference run moves to a generated
   sibling heading (`### <heading> — steps`, `— steps 2`, …) routed to
   `procedure` (or the checkable role the parent already asserted) via a
   rulebook `SectionAlias`. There is no minimum-content threshold — every
   lowerable or AI-inference segment survives as its own child, however small.
3. **Cue-gated AI routing** — the *only* path to an AI marker. A checklist/
   table whose items don't trial-lower AND carry an inference cue becomes
   `!!! checklist (( ai-autonomy ))` / `!!! table (( ai-discretion ))`; a
   section with no executable content but an inference cue becomes `use
   judgment to follow the <heading> guidance:`. **A normative cue with no
   inference cue is never auto-wrapped in judgment** — see (4). These are
   author-visible markers in the emitted `.meri` — nothing calls an LLM
   unless explicitly marked.
4. **No-cue operational content is a hard error, not a marker.** Content that
   is operational/normative-shaped (a `normativeCueWords` cue, or a heading
   that already asserts a checkable/procedure role) but carries no inference
   cue and doesn't itself lower is left **unmarked** (or aliased to
   `procedure`) so the real strict compiler raises its own precise reword
   diagnostic (`uncheckablePredicate` / `unresolvedPhrase`) — never silently
   dropped into documentation, never silently judgment-wrapped. Pass
   `--route-fuzzy` to downgrade this from a hard migration failure to a
   reported, non-fatal skip (marks the section `(( role: reference ))` and
   retries) for exploratory batch runs where some residual is expected;
   without it, migration fails and the diagnostic names exactly what to
   reword. Genuinely documentary content (no operational or inference signal
   at all) gets `(( role: reference ))` — the migrator's only non-executable
   marker. `(( role: template ))` / `(( role: tools ))` / `(( role:
   convention-ref ))` remain for their specific closed shapes (Output Format,
   Tools Used, verbatim rulebook-convention restatement). Recognized
   procedure/applicability/negative/checkable-role headings whose body is
   already fully lowerable are left unmarked.

Category-4 (no-cue operational) lines that don't trial-lower and aren't split
out are never silently dropped: they are listed in the migration report as
`unmined-contract` lines (see `--report` below) — a nonzero count is a signal
that a phrase needs authoring, an assertion needs rewriting, or (rarely) the
content needs an explicit inference-cue reword so it can be judgment-routed.
The pass is idempotent (generated split headings and judgment-wrap bodies are
recognized and never re-split/re-wrapped) and does **not** strip `skill: true`
(a one-time corpus edit, not a reusable transform). It then strict-compiles
the candidate. **LLM proposes, compiler disposes:** a migration is only
"successful" when the emitted `.meri` passes the same strict compile as a
hand-authored file, so a migrated skill can never silently call an LLM at
runtime. Anything the marking pass cannot classify deterministically (e.g. a
non-checkable invariant left under a procedure heading, with no inference
cue) is surfaced as a located compile error for the author — or `--route-fuzzy`,
or the LLM-repair seam — to resolve.

A hand-authored `.meri` may still use plain `(( inert ))` (the compiler
continues to accept it as a non-executable marker), but the migrator itself
never writes it — any `(( inert ))` found in a *migrated* file is flagged as a
violation by `SkillMetrics`/`skill-deviation`'s `inertMarkerCount`. Prefer
`(( role: reference ))` in new hand-authored content too, so a file's markers
read uniformly.

```
meridian migrate-skill <input> [options]
```

### Positional arguments

| Argument | Description |
|---|---|
| `<input>` | Path to the source `SKILL.md` (or a directory, with `--batch`). |

### Options

| Flag | Default | Description |
|---|---|---|
| `--out <file.meri>` | stdout / alongside input | Output path for the migrated `.meri`. |
| `--vocab <path>` | `brain.merconfig` | Frontmatter `vocabulary:` value to inject when absent. **Repeatable.** |
| `--rulebook <path>` | `brain.merrules` | Frontmatter `rulebook:` value to inject when absent. **Repeatable.** |
| `--llm <provider>` | none | Enable bounded LLM-assisted repair (no provider is wired in the default build; the flag reserves the seam). |
| `--max-repair <N>` | `0` | Maximum repair rounds. `0` = deterministic-only. |
| `--route-fuzzy` / `--no-route-fuzzy` | **off** | Downgrade a non-lowerable, no-inference-cue operational section (P1 category 4) from a hard migration error to a reported-but-nonfatal skip, marking it `(( role: reference ))` and retrying — an opt-in escape hatch for exploratory batch runs where some residual is expected. Off by default: cue-less operational content is a reword error the author should fix, not something the migrator quietly launders into documentation. Note: this does not affect cue-gated AI routing (`ai-discretion`/`ai-autonomy`/`use judgment to …:`), which always fires whenever an `inferenceCueWords` cue is present, regardless of this flag. |
| `--report <path>` | none | Write a per-skill migration report (`compiles`, added keys, repair attempts, edit count, line delta, unmined-contract count + lines). |
| `--batch` | false | Treat `<input>` as a directory; migrate every `SKILL.md` and emit a coverage matrix (adds an `unmined` column and total). |
| `--force` | false | Overwrite an existing output file. |
| `--trace <categories>` | (none) | Enable `ParserTrace` output; migration-specific logging is under the `skill` category |
| `--trace-file <path>` | stderr | Write trace output to a file instead of stderr |

### Deterministic-only example

```bash
meridian migrate-skill skills/capture/SKILL.md \
    --out sample-gbrain/skills/capture.meri \
    --vocab sample-gbrain/brain.merconfig \
    --rulebook sample-gbrain/brain.merrules \
    --report /tmp/capture.report.txt
```

The report records exactly what (if anything) a human must resolve. When the
body contains unmarked freeform prose, deterministic-only migration fails with
a sourced diagnostic — the author must either rephrase the line into a
resolvable phrase, wrap it in `use judgment to …:`, or supply a repair closure.

### Batch coverage matrix

```bash
meridian migrate-skill skills/ --batch \
    --vocab sample-gbrain/brain.merconfig \
    --rulebook sample-gbrain/brain.merrules \
    --report /tmp/coverage.txt
```

See [13_SKILL_MD_PORTING.md](13_SKILL_MD_PORTING.md) for the full porting
playbook and the per-tier edit budget.

---

## `meridian inert-yield`

Measure how many currently inert sections would lower with the real vocabulary
and rulebook knowledge. This is a read-only migration-analysis command; it never
rewrites the input.

```bash
meridian inert-yield <input> [options]
```

| Flag | Default | Description |
|---|---|---|
| `--vocab <path>` | auto-detected | Path to a `.merconfig` file. Repeatable. |
| `--rulebook <path>` | auto-detected | Path to a `.merrules` file. Repeatable. |
| `--batch` | false | Treat `<input>` as a directory and analyze every `.meri` file. |
| `-o, --out <path>` | stdout | Write the full Markdown report to a file. |
| `--summary-only` | false | Print only the corpus summary and ranked worklist. |
| `--trace <categories>` | (none) | Enable `ParserTrace`; useful categories include `skill` and `lowering`. |
| `--trace-file <path>` | stderr | Write trace output to a file instead of stderr. |

---

## `meridian skill-deviation`

Report how a ported `.meri` deviates from the original `SKILL.md` it was derived
from. Read-only audit companion to `migrate-skill`: it diffs the two files,
classifies the migration effort into a tier, and renders a Markdown report. Backed
by the reusable `SkillDeviation` helper in `MeridianCore`.

```
meridian skill-deviation <original> <ported> [options]
```

### Positional arguments

| Argument | Description |
|---|---|
| `<original>` | Original `SKILL.md` (or a directory of skills with `--batch`) |
| `<ported>` | Ported `.meri` (or a directory containing the `.meri` ports with `--batch`) |

### Options

| Flag | Default | Description |
|---|---|---|
| `-o, --out <dir>` | stdout | Directory for per-skill `<stem>.md` reports. Printed to stdout in single mode when omitted. |
| `--batch` | false | Treat both inputs as directories. Pairs every `<name>/SKILL.md` (and top-level `*.md` like `RESOLVER.md`) with `<ported>/<slug>.meri` (recursive). |
| `--index` | false | With `--batch`, also write a `README.md` index summarizing tiers, similarity, and any unpaired files. |
| `--no-diff` | false | Omit the raw unified diff; emit summary-only reports. |
| `--trace <categories>` | (none) | Enable `ParserTrace`; useful categories include `verbalizer` and `drift`. |
| `--trace-file <path>` | stderr | Write trace output to a file instead of stderr. |

### Report contents

Each report records the frontmatter delta (`Added`/`Removed` keys), line counts
with added/removed totals, a similarity ratio, a deterministic tier (`>=0.85` ->
1 near-verbatim, `0.5..<0.85` -> 2 light edits, `<0.5` -> 3 structural rewrite),
the structural transforms the migration applied, and a unified diff.

The diff engine (`Difflib.swift`) is a faithful Swift port of Python's
`difflib.SequenceMatcher` / `unified_diff` (matching blocks, `autojunk`,
`get_grouped_opcodes`, `_format_range_unified`), so the reports are byte-for-byte
equivalent to the original Python-generated corpus. Similarity is difflib's
ratio `2*M / (origLines + portLines)` where `M` is the matched-line count;
`added = portLines − M`, `removed = origLines − M`.

Categories name exactly what `migrate-skill`'s marking pass did:

| Category | Meaning |
|---|---|
| `frontmatter-injected` | the port added frontmatter keys |
| `section-marker-added` | the port introduced `(( … ))` heading markers |
| `shell-block-routed` | a pure-shell heading became `(( role: procedure ))` |
| `preamble-blockquoted` | the port blockquoted pre-heading prose |
| `doc-section-marked` | a heading not already non-executable in the original became non-executable (`(( role: reference/template/tools/convention-ref ))`, or hand-authored `(( inert ))`) in the port |

`doc-section-marked` (and the accompanying "Inert deviations" report section)
excludes a migrator-generated split family as a unit: neither a generated
`— steps` sibling heading nor the original heading it was split from is
flagged, since the section's operational content was preserved in the split
sibling rather than lost (`SkillMetrics.analyze` applies the same exclusion to
`totalSections`/`inertSections`, so a split never spuriously dilutes the inert
ratio either). The report also surfaces `inertMarkerCount` — the number of
literal `(( inert ))` markers found in the ported file. The migrator itself
never writes `(( inert ))` (it emits `(( role: reference ))` instead), so a
nonzero count in a *migrated* file is a violation to fix, not an expected
category.

The unified diff is fenced as ` ```diff ` with `--- <original>` / `+++ <ported>`
file headers and standard `@@ -aStart,aCount +bStart,bCount @@` hunk headers
(3 lines of context), so each report shows precisely which lines were added and
removed.

Batch pairing skips reference directories with no `SKILL.md` (e.g.
`conventions/`, `migrations/`) and reports them as skipped. `meridian
skill-deviation --batch --index` is the supported way to regenerate
`sample-gbrain/migration-deviations/` (no external scripts).

### Example

```bash
# Audit the whole gbrain corpus into sample-gbrain/migration-deviations/
meridian skill-deviation \
    sample-gbrain/original-skills sample-gbrain \
    --batch --index --out sample-gbrain/migration-deviations
```
