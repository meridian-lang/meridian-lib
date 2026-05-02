# ``MeridianCore``

The Meridian compiler frontend, IR, codegen, and diagnostics.

## Overview

`MeridianCore` is the library form of the `meridian` CLI's compile
pipeline. The single public façade is ``Compiler`` — call
``Compiler/compile(meridianSource:meridianFile:vocabularies:)`` with a
`.meridian` source plus zero or more `.merconfig` vocabularies and get
formatted Swift back as a string.

The pipeline runs in five stages:

1. **Parse** — `MeridianParser` and `MerConfigParser` turn source text
   into an AST (``MeridianFile``, ``MerConfigFile``).
2. **Symbol resolution** — ``SymbolTable`` indexes kinds, properties,
   tools, phrases, constants, and instances for downstream lookups.
3. **Lower** — ``ASTToIR`` converts ASTs into the 10-primitive
   intermediate representation (``IRWorkflow`` containing
   ``InvokeIR``, ``BindIR``, ``BranchIR``, ``EmitIR``, ``CompleteIR``,
   ``IterateIR``, ``AssertIR``, ``WaitIR``, ``CommitIR``,
   ``RecoverIR``).
4. **Emit** — ``SwiftEmitter`` writes Swift source via the
   `StringTemplate` builder; ``ManifestEmitter`` writes a companion
   JSON manifest. The same `SwiftEmitter` also emits typed Swift
   structs (a "domain" file) from the vocabulary's `kind` declarations
   when the caller passes a ``SwiftEmitter/DomainDecl`` to
   ``SwiftEmitter/emitFile(workflows:constantsDecl:instancesDecl:domainDecl:)``.
5. **Format** — `swift-format` is run on the emitted Swift unless the
   caller passes `--no-format`.

For diagnostics, every parser and lowerer takes an optional
``ParserTrace`` so a host can opt into category-scoped logging without
touching the codebase.

## Topics

### Compiling

- ``Compiler``
- ``Compiler/Options``
- ``Compiler/VocabularyInput``
- ``CompilerError``

### Parsing and ASTs

- ``MerConfigFile``
- ``MeridianFile``
- ``KindDeclaration``
- ``PhrasePattern``
- ``WorkflowAST``

### Intermediate representation

- ``IRWorkflow``
- ``InvokeIR``
- ``BindIR``
- ``BranchIR``
- ``EmitIR``
- ``CompleteIR``
- ``IterateIR``
- ``AssertIR``
- ``WaitIR``
- ``CommitIR``
- ``RecoverIR``

### Code emission

- ``SwiftEmitter``
- ``SwiftEmitter/Options``
- ``SwiftEmitter/DomainDecl``
- ``ManifestEmitter``

### Tooling

- ``MeridianFormatter``
- ``MerconfigDocsRenderer``
- ``ParserTrace``
- ``SymbolTable``
