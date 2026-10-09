# Modules and shared imports

Status: Final Wave Phase F (SEM-MOD-01, SEM-MOD-02 companion).

Meridian modules package reusable vocabulary — domain kinds, tools, constants,
language synonyms, and `=== imports ===` chains — under a stable module id.
Skills import modules instead of copying `.merconfig` fragments.

## Package layout

```
modules/
  shared-domain/
    module.meridian     # optional manifest frontmatter
    module.merconfig    # required vocabulary entry point
```

Discovery order for `import <name>`:

1. `<anchor>/<name>/module.merconfig`
2. `<anchor>/<name>.merconfig`
3. Each `--module-path/<name>/module.merconfig`

`<anchor>` is the importer's directory (the skill or merconfig being compiled).

## Surface syntax

**Skill frontmatter**

```yaml
---
imports: shared-domain, billing-core as billing
vocabulary: local.merconfig
---
```

**Merconfig section**

```merconfig
=== imports ===
import shared-domain
import billing-core as billing
```

Both `import <module>` and `import module <module>` are accepted. Optional
`as <alias>` renames the merged vocabulary bucket (defaults to the module id).

Legacy `vocabulary:` frontmatter remains for direct `.merconfig` references
alongside module imports.

## Merge semantics

1. Resolve the import graph (depth-first, deterministic by module name).
2. Merge module configs in topological order.
3. Merge the importer's local `.merconfig` and inline `## Domain` sections on
   top — **importer wins** on name collisions.
4. If a module export is listed in manifest `sealed:` (or `sealed:` frontmatter),
   the importer cannot override that symbol (MER-MOD-004).

Cross-module export collisions (same kind/tool name from two imports) are
MER-MOD-003. Cycles are MER-MOD-002. Missing packages are MER-MOD-001.

## Manifest (`module.meridian`)

```yaml
---
module: shared-domain
version: 1.0.0
exports: public
sealed: policy, customer
---
```

- `exports: public|internal` — `public` modules publish symbols on the export
  surface (cross-module collision checks). `internal` modules still merge
  vocabulary for direct importers but do not export symbols to sibling imports.
- `sealed:` — comma-separated symbols the importer must not redefine.

## Lockfile

`ModuleLockfile` records resolved `{id, path, contentHash, alias?}` entries in
sorted order for reproducible builds. Hosts may persist the JSON beside a skill;
the compiler computes it during bootstrap.

## CLI

```bash
meridian compile skill.meridian --module-path ./modules
meridian check skill.meridian --module-path ./modules
meridian explain skill.meri --module-path ./modules
```

## API

- `ModuleManifest` — parsed manifest metadata
- `ModuleResolver` — graph resolution + cycle/collision checks
- `ModuleSymbolSnapshot` — exported symbol sets per module
- `ModuleLockfile` — deterministic lock encoding
- `Compiler.Options.moduleSearchPaths` / `anchorDirectory`

## Related

- SEM-MOD-01: `docs/cookbook/MERIDIAN_SEMANTICS.md` §10.1
- SEM-MOD-02: explicit imports + deployment allow-lists (no implicit globals)
