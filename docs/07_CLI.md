# Meridian — CLI Reference

The `meridian` executable is built from `Sources/MeridianCLI/`.

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
| `-o, --output <dir>` | `build` | Directory to write the generated `.swift` and `.meridian.manifest.json`. Created with intermediate directories if needed. |
| `--timestamp` | false | Include a generation timestamp in the generated file header. |
| `--no-line-comments` | false | Suppress `// L{n}` source-line comments in generated code. |
| `--no-format` | false | Skip `swift-format` post-processing. |
| `--trace <categories>` | (none) | Enable `ParserTrace` output. Comma or space-separated. Examples: `phrase`, `phrase.match`, `lowering`, `all`. Also read from `MERIDIAN_TRACE` env var. |
| `--trace-file <path>` | stderr | Write trace output to a file instead of stderr. |

### Output files

Two files are written to the output directory:
- `{stem}.swift` — the generated Swift source (domain types, constants, instances, workflow structs)
- `{stem}.meridian.manifest.json` — companion manifest with parameters, event IDs, tool IDs, and source-map entries

### Successful output

On success, prints `✓ <output-path>` and exits with code 0.

### Exit codes

| Code | Meaning |
|---|---|
| 0 | Success |
| 1 | Parse, compile, or I/O error |

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
- Accept `--trace <categories>` and `--trace-file <path>`.
- Print a success summary (workflow count, vocabulary count) on exit 0.
- Print the first compiler diagnostic to stderr and exit 1 on failure.

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

## Config file auto-detection

If `--merconfig` is not specified, the compiler searches:

1. All files with `.merconfig` extension in the same directory as `<source>` (sorted alphabetically).
2. All files with `.merconfig` extension in the **parent** directory (if none found in step 1).

When multiple files are found, they are all merged as if each had been passed
separately with `--merconfig`. Duplicate kind/phrase/tool/constant/instance names
across merged vocabularies are rejected with a sourced semantic error.

If none is found, the compiler proceeds without a vocabulary (phrase invocations
produce `_unresolved` binds).

---

## Trace categories

See [08_TRACING.md](08_TRACING.md) for the full list. The most useful ones
during development:

| Category | What it shows |
|---|---|
| `phrase` | All phrase pipeline stages (parse, match, args, inline) |
| `phrase.match` | Which phrases are candidates and which wins |
| `phrase.args` | Argument text extracted from each invocation slot |
| `phrase.inline` | Body expansion and substitution steps |
| `phrase.parse` | Pattern tokenisation |
| `expression` | Expression parsing decisions |
| `statement` | Statement parsing dispatch |
| `lowering` | AST → IR lowering decisions |
| `symbols` | Symbol table lookups |
| `merconfig` | MerConfig section and phrase parsing |
| `all` | Everything (verbose) |

The `MERIDIAN_TRACE` environment variable is also read at startup:

```bash
MERIDIAN_TRACE=phrase.match meridian compile examples/order_processing.meridian
```

The `--trace` flag is available on `compile`, `check`, `verify`, and `run`.

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
