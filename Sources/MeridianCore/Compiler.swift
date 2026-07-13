import Foundation
import MeridianRuntime

// MARK: - Compiler
//
// Top-level facade for the Meridian compiler pipeline.
// Phase 2: IR → Swift (codegen only — no parser yet).
// Phase 3: Source → AST → IR → Swift (full pipeline).

public struct Compiler {

    public let irVersion = MERIDIAN_IR_VERSION

    public struct Options {
        public var emitterOptions: SwiftEmitter.Options
        /// Diagnostic trace sink. Defaults to the process-wide `ParserTrace.shared`,
        /// which is silent unless `MERIDIAN_TRACE` env var or `--trace` CLI flag
        /// activates categories.
        public var trace: ParserTrace
        /// English surface table used for comparison markers, duration units,
        /// articles, prepositions, and stop-words. Defaults to the built-in
        /// English lexicon; supply a custom instance to extend or override vocabulary.
        public var lexicon: EnglishLexicon
        /// Test-/host-level escape hatch for fallbacks. **The user-facing way
        /// to opt into fallbacks is the `.meridian` frontmatter
        /// `allow-fallbacks:` key.** This option is OR-merged with the
        /// frontmatter policy at compile time. Default: `.strict` (every
        /// resolution failure raises a hard error).
        public var fallbackPolicy: FallbackPolicy
        /// Directories searched for `import <module>` packages (`<path>/<name>/module.merconfig`).
        public var moduleSearchPaths: [URL]
        /// Directory used for relative module resolution (typically the importer's folder).
        public var anchorDirectory: URL?
        /// When true, `compileMultiFile` emits domain and workflow Swift into separate files.
        public var emitMultiFile: Bool
        public init(emitterOptions: SwiftEmitter.Options = .init(),
                    trace: ParserTrace = .shared,
                    lexicon: EnglishLexicon = .default,
                    fallbackPolicy: FallbackPolicy = .strict,
                    moduleSearchPaths: [URL] = [],
                    anchorDirectory: URL? = nil,
                    emitMultiFile: Bool = false) {
            self.emitterOptions = emitterOptions
            self.trace = trace
            self.lexicon = lexicon
            self.fallbackPolicy = fallbackPolicy
            self.moduleSearchPaths = moduleSearchPaths
            self.anchorDirectory = anchorDirectory
            self.emitMultiFile = emitMultiFile
        }
    }

    public let options: Options

    public init(options: Options = Options()) {
        self.options = options
    }

    // MARK: - Phase 2: IR → Swift

    /// Lower an IR workflow to Swift source. Used in Phase 2 forcing function.
    public func emit(
        workflows: [IRWorkflow],
        constantsDecl: SwiftEmitter.ConstantsDecl? = nil
    ) throws -> String {
        try SwiftEmitter(options: options.emitterOptions, trace: options.trace)
            .emitFile(workflows: workflows, constantsDecl: constantsDecl)
    }

    /// Emit the companion JSON manifest.
    public func emitManifest(_ input: ManifestEmitter.Input) throws -> String {
        try ManifestEmitter(trace: options.trace).emit(input)
    }

    // MARK: - Phase 3: Source → Swift

    /// One vocabulary input (a parsed .merconfig). The `name` is the logical
    /// import name (e.g. `import ecommerce.` resolves to `name == "ecommerce"`)
    /// — it's the .merconfig filename without the extension by convention.
    public struct VocabularyInput: Sendable {
        public let name: String
        public let file: String
        public let source: String
        public init(name: String, file: String, source: String) {
            self.name = name; self.file = file; self.source = source
        }
    }

    /// Full pipeline: parse .merconfig + .meridian → lower to IR → emit Swift.
    ///
    /// - Parameters:
    ///   - meridianSource: Contents of the .meridian file.
    ///   - meridianFile:   Filename for source-map comments.
    ///   - merconfigSource: Contents of the .merconfig file (optional).
    ///   - merconfigFile:  Filename for the merconfig (optional).
    /// - Returns: A Swift source string ready to be written to disk.
    public func compile(
        meridianSource: String,
        meridianFile: String = "workflow.meridian",
        merconfigSource: String? = nil,
        merconfigFile: String = "config.merconfig"
    ) throws -> String {
        let inputs: [VocabularyInput]
        if let src = merconfigSource {
            let name = (merconfigFile as NSString).deletingPathExtension
            inputs = [VocabularyInput(name: name, file: merconfigFile, source: src)]
        } else {
            inputs = []
        }
        return try compile(
            meridianSource: meridianSource,
            meridianFile:   meridianFile,
            vocabularies:   inputs
        )
    }

    /// Multi-vocabulary entry point: parse + merge any number of `.merconfig`
    /// files, then run the rest of the pipeline against the merged config.
    ///
    /// `import` statements in the `.meridian` source are validated against the
    /// supplied vocabulary names: an `import shipping.` with no
    /// `VocabularyInput(name: "shipping", …)` available raises a sourced
    /// `CompilerError.semanticError`.
    public func compile(
        meridianSource: String,
        meridianFile: String = "workflow.meridian",
        vocabularies: [VocabularyInput],
        rulebooks: [RulebookInput] = []
    ) throws -> String {
        try compileWithManifest(
            meridianSource: meridianSource, meridianFile: meridianFile,
            vocabularies: vocabularies, rulebooks: rulebooks
        ).swift
    }

    /// Like `compile`, but returns BOTH the Swift source and the complete
    /// `ManifestEmitter.Input` assembled during compilation (workflows,
    /// metadata, outline, recorded sections, …). This removes the silent-loss
    /// point where rich data computed during compilation was discarded; hosts
    /// (the CLI) emit the manifest from this Input rather than a thin stub.
    public func compileWithManifest(
        meridianSource: String,
        meridianFile: String = "workflow.meridian",
        vocabularies: [VocabularyInput],
        rulebooks: [RulebookInput] = []
    ) throws -> (swift: String, multiFile: SwiftEmitter.MultiFileOutput?, manifest: ManifestEmitter.Input) {
        let trace = options.trace
        trace.resetProfile()
        let compileSpan = trace.push(.timing, "compile \(meridianFile)")
        defer { trace.pop(compileSpan); trace.profileSummary() }

        let engine = DiagnosticEngine(trace: trace)
        let bootstrap = try bootstrap(
            meridianSources: [(meridianSource, meridianFile)],
            vocabularies: vocabularies,
            rulebooks: rulebooks,
            trace: trace,
            engine: engine,
            inputMode: .compile
        )

        let ast = try trace.phase("parse") {
            try MeridianParser(symbols: bootstrap.symbols, trace: trace, lexicon: bootstrap.lexicon,
                               rewriteEngine: bootstrap.rewriteEngine, diagnostics: engine)
                .parse(meridianSource, file: meridianFile)
        }
        return try lowerAndEmit(
            ast: ast, meridianFile: meridianFile,
            symbols: bootstrap.symbols, config: bootstrap.config, lexicon: bootstrap.lexicon, trace: trace,
            rulebook: bootstrap.rulebook, vocabularies: vocabularies, rulebooks: rulebooks,
            authoredSource: meridianSource,
            preRegistered: false, engine: engine
        )
    }

    /// Like `compileWithManifest`, but returns a domain/workflows Swift split.
    public func compileMultiFile(
        meridianSource: String,
        meridianFile: String = "workflow.meridian",
        vocabularies: [VocabularyInput],
        rulebooks: [RulebookInput] = []
    ) throws -> (output: SwiftEmitter.MultiFileOutput, manifest: ManifestEmitter.Input) {
        var splitOpts = options
        splitOpts.emitMultiFile = true
        let splitCompiler = Compiler(options: splitOpts)
        let result = try splitCompiler.compileWithManifest(
            meridianSource: meridianSource,
            meridianFile: meridianFile,
            vocabularies: vocabularies,
            rulebooks: rulebooks
        )
        guard let multi = result.multiFile else {
            throw CompilerError.codegenError(message: "multi-file emit was not produced")
        }
        return (multi, result.manifest)
    }

    public func compileToModel(
        meridianSource: String,
        meridianFile: String = "workflow.meridian",
        vocabularies: [VocabularyInput],
        rulebooks: [RulebookInput] = []
    ) throws -> VerbalizerModel {
        let trace = options.trace
        trace.resetProfile()
        let compileSpan = trace.push(.timing, "compileToModel \(meridianFile)")
        defer { trace.pop(compileSpan); trace.profileSummary() }

        let engine = DiagnosticEngine(trace: trace)
        let bootstrap = try bootstrap(
            meridianSources: [(meridianSource, meridianFile)],
            vocabularies: vocabularies,
            rulebooks: rulebooks,
            trace: trace,
            engine: engine,
            inputMode: .compile
        )

        let ast = try trace.phase("parse") {
            try MeridianParser(symbols: bootstrap.symbols, trace: trace, lexicon: bootstrap.lexicon,
                               rewriteEngine: bootstrap.rewriteEngine, diagnostics: engine)
                .parse(meridianSource, file: meridianFile)
        }
        let lowered = try lowerParsedAST(
            ast: ast,
            meridianFile: meridianFile,
            symbols: bootstrap.symbols,
            config: bootstrap.config,
            lexicon: bootstrap.lexicon,
            trace: trace,
            rulebook: bootstrap.rulebook,
            vocabularies: vocabularies,
            rulebooks: rulebooks,
            authoredSource: meridianSource,
            preRegistered: false,
            engine: engine
        )

        return VerbalizerModel(
            workflows: lowered.workflows,
            loweredDefinitions: definitionInfos(
                symbols: bootstrap.symbols,
                loweredDefinitions: lowered.loweredDefinitions,
                inlineDefinitions: ast.definitions
            ),
            inlineDefinitions: ast.definitions,
            symbols: bootstrap.symbols,
            lexicon: bootstrap.lexicon,
            sourceFileName: meridianFile,
            authoredSource: meridianSource,
            metadata: ast.metadata,
            outline: ast.outline,
            skillSections: ast.skillSections,
            toolsUsed: ast.toolsUsed
        )
    }

    public struct SkillpackInput: Sendable {
        public let source: String
        public let file: String
        public init(source: String, file: String) {
            self.source = source
            self.file = file
        }
    }

    /// Real vocabulary/rulebook knowledge for a `.meri` source, without
    /// running parse/lower/emit. This is the same `bootstrap` phase
    /// `compileWithManifest` uses, exposed for authoring-time tooling that
    /// needs a genuine `SymbolTable`/`EnglishLexicon`/`Rulebook`/`RewriteEngine`
    /// (the migrator's marking pass, the inert-yield analyzer) instead of
    /// re-deriving vocabulary knowledge from shape heuristics. Domain
    /// vocabulary declared inline via `## Domain` sections in `source` is
    /// harvested exactly as it would be for a real compile.
    public struct KnowledgeContext {
        public let symbols: SymbolTable
        public let lexicon: EnglishLexicon
        public let rulebook: Rulebook
        public let rewriteEngine: RewriteEngine?
    }

    /// See `KnowledgeContext`. Throws the same diagnostics a real compile's
    /// bootstrap phase would (duplicate vocab/rulebook names, malformed
    /// `.merconfig`/`.merrules`).
    public func knowledge(
        forSource source: String,
        sourceFile: String,
        vocabularies: [VocabularyInput],
        rulebooks: [RulebookInput] = []
    ) throws -> KnowledgeContext {
        let trace = options.trace
        let engine = DiagnosticEngine(trace: trace)
        let ctx = try bootstrap(
            meridianSources: [(source, sourceFile)],
            vocabularies: vocabularies,
            rulebooks: rulebooks,
            trace: trace,
            engine: engine,
            inputMode: .compile
        )
        return KnowledgeContext(symbols: ctx.symbols, lexicon: ctx.lexicon,
                                rulebook: ctx.rulebook, rewriteEngine: ctx.rewriteEngine)
    }

    private struct BootstrapContext {
        let config: MerConfigFile
        let lexicon: EnglishLexicon
        let rulebook: Rulebook
        let rewriteEngine: RewriteEngine?
        let symbols: SymbolTable
        let engine: DiagnosticEngine
    }

    private enum BootstrapInputMode {
        case compile
        case skillpack
    }

    private struct DuplicateInputHelp {
        let rulebook: String
        let vocabulary: String
    }

    private func bootstrap(
        meridianSources: [(source: String, file: String)],
        vocabularies: [VocabularyInput],
        rulebooks: [RulebookInput],
        trace: ParserTrace,
        engine: DiagnosticEngine,
        inputMode: BootstrapInputMode
    ) throws -> BootstrapContext {
        let duplicateHelp = duplicateInputHelp(for: inputMode)
        var lexicon = options.lexicon
        var rulebook = Rulebook.empty
        var seenRulebooks: Set<String> = []
        for input in rulebooks {
            if !seenRulebooks.insert(input.name).inserted {
                throw CompilerError.diagnostics([
                    Diagnostic.error(
                        .duplicateName,
                        message: "duplicate rulebook name: \(input.name)",
                        range: SourceRange(file: input.file, line: 1, column: 1),
                        help: duplicateHelp.rulebook)
                ])
            }
            let parsed = try trace.phase("bootstrap.rulebook") {
                try RulebookParser(trace: trace).parse(input.source, file: input.file)
            }
            rulebook = rulebook.merging(parsed)
        }
        let rewriteEngine = rulebook.isEmpty ? nil : RewriteEngine(rulebook: rulebook, trace: trace)

        let anchor = options.anchorDirectory
            ?? meridianSources.first.map { URL(fileURLWithPath: ($0.file as NSString).deletingLastPathComponent) }
            ?? URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        var moduleImportSpecs: [ModuleImportSpec] = []
        for meridian in meridianSources {
            moduleImportSpecs += harvestModuleImports(from: meridian.source, file: meridian.file)
        }

        var config = MerConfigFile()
        var seenNames: Set<String> = []
        var localVocabConfigs: [MerConfigFile] = []
        for input in vocabularies {
            if !seenNames.insert(input.name).inserted {
                throw CompilerError.diagnostics([
                    Diagnostic.error(
                        .duplicateName,
                        message: "duplicate vocabulary name: \(input.name)",
                        range: SourceRange(file: input.file, line: 1, column: 1),
                        help: duplicateHelp.vocabulary)
                ])
            }
            let parsed = try trace.phase("bootstrap.merconfig") {
                try MerConfigParser(trace: trace, lexicon: lexicon, diagnostics: engine)
                    .parse(input.source, file: input.file)
            }
            moduleImportSpecs += ModuleResolver.parseImportsLines(parsed.imports, file: input.file)
            localVocabConfigs.append(parsed)
        }

        if !moduleImportSpecs.isEmpty {
            let resolver = ModuleResolver(
                moduleSearchPaths: options.moduleSearchPaths,
                anchorDirectory: anchor,
                trace: trace,
                lexicon: lexicon
            )
            let resolution = try trace.phase("bootstrap.modules") {
                try resolver.resolve(imports: moduleImportSpecs)
            }
            for mod in resolution.modules {
                config = try config.merging(mod.config)
            }
            trace.log(.symbols, "module lockfile: \(resolution.lockfile.modules.count) entries")
        }
        for parsed in localVocabConfigs {
            config = try config.merging(parsed)
        }
        for meridian in meridianSources {
            let inlineDomain = try trace.phase("bootstrap.inlineDomain") {
                try harvestDomainVocabulary(
                    from: meridian.source,
                    file: meridian.file,
                    rulebook: rulebook,
                    trace: trace,
                    lexicon: lexicon
                )
            }
            config = try config.merging(inlineDomain)
        }
        try requireUniqueDeclarations(in: config, engine: engine)
        validateProductionTraceCapturePolicies(in: config, engine: engine)
        try engine.throwIfErrors()

        lexicon = trace.phase("bootstrap.lexiconMerge") {
            lexicon.merging(from: config.languageSynonyms)
        }

        let symbolsFile = vocabularies.first?.file ?? "config.merconfig"
        let symbols = trace.phase("symbols") {
            SymbolTable.build(from: config, sourceFile: symbolsFile, trace: trace, lexicon: lexicon)
        }
        return BootstrapContext(
            config: config,
            lexicon: lexicon,
            rulebook: rulebook,
            rewriteEngine: rewriteEngine,
            symbols: symbols,
            engine: engine
        )
    }

    /// Skillpack entry point: compile a *set* of `.meri` files against shared
    /// `.merconfig`(s) + `.merrules`. Every file's workflows are registered as
    /// phrase stubs in one shared `SymbolTable` **before** any file is lowered,
    /// so cross-skill invocation ("delegate to enrich", "route through X") and
    /// the resolver table resolve across files. Single-file `compile` remains
    /// the default; this returns a `file → Swift source` map.
    public func compileSkillpack(
        _ skills: [SkillpackInput],
        vocabularies: [VocabularyInput],
        rulebooks: [RulebookInput] = []
    ) throws -> [String: String] {
        let trace = options.trace
        trace.resetProfile()
        let packSpan = trace.push(.timing, "compileSkillpack (\(skills.count) file(s))")
        defer { trace.pop(packSpan); trace.profileSummary() }

        let engine = DiagnosticEngine(trace: trace)
        let bootstrap = try bootstrap(
            meridianSources: skills.map { ($0.source, $0.file) },
            vocabularies: vocabularies,
            rulebooks: rulebooks,
            trace: trace,
            engine: engine,
            inputMode: .skillpack
        )

        // Parse every skill against the SHARED symbol table. Each file gets its
        // own per-file `DiagnosticEngine` (so batching never crosses files) used
        // for both its parse and lower phases.
        var parsed: [(ast: MeridianFile, file: String, engine: DiagnosticEngine)] = []
        for skill in skills {
            let engine = DiagnosticEngine(trace: trace)
            let ast = try trace.phase("parse \(skill.file)") {
                try MeridianParser(symbols: bootstrap.symbols, trace: trace, lexicon: bootstrap.lexicon,
                                   rewriteEngine: bootstrap.rewriteEngine, diagnostics: engine)
                    .parse(skill.source, file: skill.file)
            }
            parsed.append((ast, skill.file, engine))
        }

        // Pre-register EVERY file's workflows as phrase stubs first, so a body
        // in one skill can invoke a workflow declared in another.
        for entry in parsed {
            for wf in entry.ast.workflows {
                let structName = IRWorkflow.structName(from: wf.pattern.displayText, lexicon: bootstrap.lexicon)
                bootstrap.symbols.registerWorkflowPhrase(
                    pattern: wf.pattern,
                    structName: structName,
                    sourceLine: wf.sourceLine,
                    sourceFile: wf.sourceFile.isEmpty ? entry.file : wf.sourceFile
                )
            }
        }

        var outputs: [String: String] = [:]
        for entry in parsed {
            outputs[entry.file] = try lowerAndEmit(
                ast: entry.ast, meridianFile: entry.file,
                symbols: bootstrap.symbols, config: bootstrap.config, lexicon: bootstrap.lexicon, trace: trace,
                rulebook: bootstrap.rulebook, vocabularies: vocabularies, rulebooks: rulebooks,
                authoredSource: skills.first(where: { $0.file == entry.file })?.source ?? "",
                preRegistered: true, engine: entry.engine
            ).swift
        }
        return outputs
    }

    /// Lower a parsed `.meri` AST against a (possibly shared) symbol table and
    /// emit Swift. Shared by single-file `compile` and `compileSkillpack`.
    private func lowerAndEmit(
        ast: MeridianFile,
        meridianFile: String,
        symbols: SymbolTable,
        config: MerConfigFile,
        lexicon: EnglishLexicon,
        trace: ParserTrace,
        rulebook: Rulebook,
        vocabularies: [VocabularyInput],
        rulebooks: [RulebookInput],
        authoredSource: String,
        preRegistered: Bool,
        engine: DiagnosticEngine
    ) throws -> (swift: String, multiFile: SwiftEmitter.MultiFileOutput?, manifest: ManifestEmitter.Input) {
        let lowered = try lowerParsedAST(
            ast: ast,
            meridianFile: meridianFile,
            symbols: symbols,
            config: config,
            lexicon: lexicon,
            trace: trace,
            rulebook: rulebook,
            vocabularies: vocabularies,
            rulebooks: rulebooks,
            authoredSource: authoredSource,
            preRegistered: preRegistered,
            engine: engine
        )
        let workflows = lowered.workflows
        let loweredDefinitions = lowered.loweredDefinitions
        let skillName = lowered.skillName

        let constantsDecl: SwiftEmitter.ConstantsDecl? = config.constants.isEmpty ? nil :
            SwiftEmitter.ConstantsDecl(entries: config.constants.map { c in
                SwiftEmitter.ConstantsDecl.Entry(c.name, constantToIRLiteral(c.value))
            })

        let instancesDecl: SwiftEmitter.InstancesDecl? = config.instances.isEmpty ? nil :
            SwiftEmitter.InstancesDecl(entries: config.instances.map { i in
                SwiftEmitter.InstancesDecl.Entry(
                    i.name,
                    i.kind,
                    i.properties.map { (key, val) in
                        SwiftEmitter.InstancesDecl.Field(key, propertyValueToInstance(val))
                    }
                )
            })

        let domainDecl = try trace.phase("domainDecl") {
            try buildDomainDecl(from: config)
        }
        if let domainDecl {
            trace.log(.codegen,
                      "domain decl: \(domainDecl.kinds.count) kind(s), \(domainDecl.enumerations.count) enum(s)")
        }

        // Emit Swift
        let emitterOpts = SwiftEmitter.Options(
            includeTimestamp: options.emitterOptions.includeTimestamp,
            sourceFileName: meridianFile,
            indentUnit: options.emitterOptions.indentUnit,
            emitSourceLineComments: options.emitterOptions.emitSourceLineComments,
            namespaceEnum: options.emitterOptions.namespaceEnum
        )
        let swift = try trace.phase("codegen") {
            try SwiftEmitter(options: emitterOpts, trace: trace)
                .emitFile(workflows: workflows,
                          constantsDecl: constantsDecl,
                          instancesDecl: instancesDecl,
                          domainDecl: domainDecl,
                          fileMetadata: ast.metadata,
                          definitions: loweredDefinitions)
        }
        let multiFile: SwiftEmitter.MultiFileOutput?
        if options.emitMultiFile {
            multiFile = try trace.phase("codegen-multi") {
                try SwiftEmitter(options: emitterOpts, trace: trace)
                    .emitMultiFile(workflows: workflows,
                                   constantsDecl: constantsDecl,
                                   instancesDecl: instancesDecl,
                                   domainDecl: domainDecl,
                                   fileMetadata: ast.metadata,
                                   definitions: loweredDefinitions)
            }
            trace.log(.codegen, "multi-file emit: domain + workflows split")
        } else {
            multiFile = nil
        }

        // C5: Rule manifest entries. Reclassify `ast.rules` independently of
        // the lowering pass above (whose attach/no-attach bookkeeping is
        // local to `ASTToIR.lower` and isn't returned) — cheap because
        // `RuleAnalyzer.classify` is pure pattern matching, no lowering. Every
        // rule that survives to this point in a successful compile either
        // classified-and-attached, or was an allowed `unparseable-rules` /
        // `unattached-rules` fallback drop; the latter is rare enough in
        // practice (opt-in frontmatter) that we accept reporting it as
        // `executes: true` here rather than threading attach status out of
        // the lowerer for this edge case.
        let ruleAnalyzer = RuleAnalyzer(lexicon: lexicon, trace: trace, symbols: symbols)
        let ruleManifestEntries: [ManifestEmitter.RuleManifestEntry] = try trace.phase("manifestRules") {
            try ast.rules.map { raw in
                guard let parsed = try ruleAnalyzer.classify(raw) else {
                    return ManifestEmitter.RuleManifestEntry(
                        text: raw.text, kind: "unknown", executes: false,
                        source: .init(file: meridianFile, line: raw.sourceLine))
                }
                let (kind, bounded) = Compiler.ruleManifestKind(parsed)
                return ManifestEmitter.RuleManifestEntry(
                    text: raw.text, kind: kind, executes: true, bounded: bounded,
                    source: .init(file: meridianFile, line: raw.sourceLine))
            }
        }
        trace.log(.codegen, "manifest rules: \(ruleManifestEntries.count) entr\(ruleManifestEntries.count == 1 ? "y" : "ies")")

        // Assemble the COMPLETE manifest Input as part of every compile. The
        // rich data computed here (workflows, outline, recorded sections) is no
        // longer discarded — the host emits the manifest from this Input.
        let verbalizerModel = VerbalizerModel(
            workflows: workflows,
            loweredDefinitions: definitionInfos(
                symbols: symbols,
                loweredDefinitions: loweredDefinitions,
                inlineDefinitions: ast.definitions
            ),
            inlineDefinitions: ast.definitions,
            symbols: symbols,
            lexicon: lexicon,
            sourceFileName: meridianFile,
            authoredSource: authoredSource,
            metadata: ast.metadata,
            outline: ast.outline,
            skillSections: ast.skillSections,
            toolsUsed: ast.toolsUsed
        )
        let skillVersionHash = try TraceIdentityPlanner.skillVersionHash(
            meridianSource: authoredSource,
            vocabularies: vocabularies,
            rulebooks: rulebooks
        )
        let obligationDocument = try trace.phase("obligationDocument") {
            try ObligationDocumentBuilder.build(
                from: verbalizerModel,
                options: .init(skillName: skillName, skillVersionHash: skillVersionHash)
            )
        }
        trace.log(.codegen,
                  "obligation document: \(obligationDocument.obligations.count) obligation(s)")
        let manifestInput = ManifestEmitter.Input(
            sourceFiles: [meridianFile] + vocabularies.map(\.file),
            workflows: workflows,
            constantsDecl: constantsDecl,
            toolsUsed: ast.toolsUsed,
            // Every declared vocabulary kind's PascalCase Swift name, used to
            // filter `IRWalker.allKindNames` down to genuine domain kinds —
            // some `IRParameter.kind`s are synthetic placeholders derived
            // straight from an implicit phrase parameter's own text (e.g. a
            // rule-synthesized workflow's unresolved "reviewer approve"
            // parameter), never a real vocabulary kind, and SwiftEmitter
            // already falls back to `Value` for those at codegen time.
            kindsUsed: IRWalker.allKindNames(in: workflows)
                .intersection(symbols.kinds.keys.map { IdentifierNaming.pascalCaseFromSpaces($0) })
                .sorted(),
            instancesRequired: instancesDecl.map { decl in
                decl.entries.map { e in
                    ManifestEmitter.InstanceManifestEntry(name: e.name, kind: e.kind)
                }
            } ?? [],
            sourceMap: Compiler.sourceMap(fromGeneratedSwift: swift),
            metadata: ast.metadata,
            outline: ast.outline,
            rules: ruleManifestEntries,
            skillSections: ast.skillSections.map {
                ManifestEmitter.SkillSectionEntry(
                    heading: $0.heading, role: $0.role, executes: $0.executes,
                    lines: $0.lines, line: $0.line)
            },
            definitions: symbols.definitions.values
                .sorted { $0.functionName < $1.functionName }
                .map {
                    ManifestEmitter.DefinitionManifestEntry(
                        adjective: $0.adjective, kind: $0.kind,
                        function: $0.functionName, line: $0.sourceLine)
                },
            relations: relationManifestEntries(symbols),
            verbs: symbols.verbs.values
                .sorted { $0.base < $1.base }
                .map {
                    ManifestEmitter.VerbManifestEntry(
                        base: $0.base, thirdPerson: $0.thirdPerson,
                        pastParticiple: $0.pastParticiple, relation: $0.relation, line: $0.sourceLine)
                },
            skillVersionHash: skillVersionHash,
            obligations: obligationDocument.obligations
        )
        return (swift, multiFile, manifestInput)
    }

    private func duplicateInputHelp(for mode: BootstrapInputMode) -> DuplicateInputHelp {
        switch mode {
        case .compile:
            return DuplicateInputHelp(
                rulebook: "Each `--rulebook` / frontmatter `rulebook:` entry must have a unique name.",
                vocabulary: "Each `--vocabulary` / frontmatter `vocabulary:` entry must have a unique name."
            )
        case .skillpack:
            return DuplicateInputHelp(
                rulebook: "Supply each rulebook only once or rename the duplicate.",
                vocabulary: "Supply each vocabulary only once or rename the duplicate."
            )
        }
    }

    private func effectiveFallbackPolicy(
        metadata: FileMetadataAST?,
        sourceFile: String,
        engine: DiagnosticEngine
    ) -> FallbackPolicy {
        var effectivePolicy = options.fallbackPolicy
        guard let raw = metadata?["allow-fallbacks"] else {
            return effectivePolicy
        }

        let (frontPolicy, unknown) = FallbackPolicy.parse(raw)
        effectivePolicy = effectivePolicy.merging(frontPolicy)
        let fallbackLine = metadata?.sourceLine ?? 1
        for token in unknown {
            engine.report(Diagnostic.unresolved(
                .unknownFallbackKind,
                target: token,
                among: FallbackKind.allCases.map(\.rawValue),
                range: SourceRange(file: sourceFile, line: fallbackLine, column: 1),
                noun: "allow-fallbacks kind",
                help: "Use one of the recognized fallback kinds, or remove the token."))
        }
        return effectivePolicy
    }

    private struct LoweringContext {
        let lowerer: ASTToIR
        let frontmatter: SkillFrontmatter
    }

    private struct LoweredCompileUnit {
        let workflows: [IRWorkflow]
        let loweredDefinitions: [LoweredDefinition]
        let frontmatter: SkillFrontmatter
        let skillName: String
    }

    /// Shared parse→lower→trigger→obligation path for `compileToModel` and
    /// `lowerAndEmit`. Preserves `preRegistered`, trace phases, and diagnostics.
    private func lowerParsedAST(
        ast: MeridianFile,
        meridianFile: String,
        symbols: SymbolTable,
        config: MerConfigFile,
        lexicon: EnglishLexicon,
        trace: ParserTrace,
        rulebook: Rulebook,
        vocabularies: [VocabularyInput],
        rulebooks: [RulebookInput],
        authoredSource: String,
        preRegistered: Bool,
        engine: DiagnosticEngine
    ) throws -> LoweredCompileUnit {
        try validateImports(ast.imports, against: vocabularies, file: meridianFile)
        try validateRulebookReferences(ast.metadata, against: rulebooks, file: meridianFile)

        let effectivePolicy = effectiveFallbackPolicy(
            metadata: ast.metadata,
            sourceFile: meridianFile,
            engine: engine
        )
        let lowering = makeLoweringContext(
            ast: ast,
            sourceFile: meridianFile,
            symbols: symbols,
            lexicon: lexicon,
            rulebook: rulebook,
            trace: trace,
            fallbackPolicy: effectivePolicy,
            engine: engine
        )
        let frontmatter = lowering.frontmatter
        let lowerer = lowering.lowerer
        var workflows = try trace.phase("lower") { try lowerer.lower(ast, preRegistered: preRegistered) }
        let loweredDefinitions = try lowerer.lowerRegisteredDefinitions()
        try engine.throwIfErrors()

        workflows = addingSynthesizedTriggers(
            to: workflows,
            frontmatter: frontmatter,
            metadata: ast.metadata,
            sourceFile: meridianFile,
            lexicon: lexicon,
            rulebook: rulebook,
            trace: trace
        )
        let skillName = frontmatter.name
            ?? meridianFile.replacingOccurrences(of: ".meridian", with: "")
                .replacingOccurrences(of: ".meri", with: "")
        workflows = try annotateAndStampObligations(
            workflows: workflows,
            skillSections: ast.skillSections,
            config: config,
            skillName: skillName,
            authoredSource: authoredSource,
            vocabularies: vocabularies,
            rulebooks: rulebooks,
            trace: trace
        )
        return LoweredCompileUnit(
            workflows: workflows,
            loweredDefinitions: loweredDefinitions,
            frontmatter: frontmatter,
            skillName: skillName
        )
    }

    private func makeLoweringContext(
        ast: MeridianFile,
        sourceFile: String,
        symbols: SymbolTable,
        lexicon: EnglishLexicon,
        rulebook: Rulebook,
        trace: ParserTrace,
        fallbackPolicy: FallbackPolicy,
        engine: DiagnosticEngine
    ) -> LoweringContext {
        let frontmatter = SkillFrontmatter(ast.metadata)
        let scopedTools = mergedScopedTools(
            frontmatterTools: frontmatter.tools,
            toolsUsed: ast.toolsUsed,
            symbols: symbols,
            trace: trace
        )
        let lowerer = ASTToIR(
            symbols: symbols,
            sourceFile: sourceFile,
            trace: trace,
            lexicon: lexicon,
            fallbackPolicy: fallbackPolicy,
            rulebook: rulebook,
            scopedTools: scopedTools,
            frontmatterTools: frontmatter.tools + ast.toolsUsed,
            engine: engine
        )
        return LoweringContext(lowerer: lowerer, frontmatter: frontmatter)
    }

    private func addingSynthesizedTriggers(
        to workflows: [IRWorkflow],
        frontmatter: SkillFrontmatter,
        metadata: FileMetadataAST?,
        sourceFile: String,
        lexicon: EnglishLexicon,
        rulebook: Rulebook,
        trace: ParserTrace
    ) -> [IRWorkflow] {
        guard !frontmatter.triggers.isEmpty else {
            return workflows
        }

        let classifier = TriggerClassifier(lexicon: lexicon, rulebook: rulebook, trace: trace)
        let triggers = frontmatter.triggers.map {
            classifier.classify($0, sourceLine: metadata?.sourceLine ?? 0)
        }
        return workflows + TriggerSynthesizer(lexicon: lexicon, trace: trace)
            .synthesize(triggers, sourceFile: sourceFile)
    }

    private func annotateAndStampObligations(
        workflows: [IRWorkflow],
        skillSections: [SkillSectionRecord],
        config: MerConfigFile,
        skillName: String,
        authoredSource: String,
        vocabularies: [VocabularyInput],
        rulebooks: [RulebookInput],
        trace: ParserTrace
    ) throws -> [IRWorkflow] {
        let skillVersionHash = try trace.phase("traceIdentity.hash") {
            try TraceIdentityPlanner.skillVersionHash(
                meridianSource: authoredSource,
                vocabularies: vocabularies,
                rulebooks: rulebooks
            )
        }
        let runtimeTraceConfiguration = TraceIdentityPlanner.runtimeTraceConfiguration(
            from: config,
            skillName: skillName,
            skillVersionHash: skillVersionHash,
            workflows: workflows
        )
        var annotated = try trace.phase("traceIdentity.annotate") {
            try TraceIdentityPlanner.annotate(
                workflows: workflows,
                skillSections: skillSections,
                runtimeTraceConfiguration: runtimeTraceConfiguration
            )
        }
        trace.log(.codegen, "trace identity: annotated \(annotated.count) workflow(s)")
        annotated = try trace.phase("obligationStamp") {
            try ObligationIdStamper.stampContractAsserts(in: annotated)
        }
        trace.log(.codegen, "obligation stamp: contract asserts stamped")
        return annotated
    }

    /// Build the meridian-line → swift-line source map from the generated Swift
    /// by reading the `// L{n}` provenance comments codegen emits above each
    /// primitive. This is the compile→run bridge: a runtime JSONL event's Swift
    /// location maps back to a Meridian source line through this table. Built as
    /// part of `compileWithManifest` so EVERY emitted manifest carries it (the
    /// CLI previously rebuilt it by hand, dropping it from library callers).
    public static func sourceMap(fromGeneratedSwift swift: String) -> [ManifestEmitter.SourceMapEntry] {
        swift.components(separatedBy: "\n").enumerated().compactMap { idx, line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("// L"),
                  let lineNumber = Int(trimmed.dropFirst(4).split(separator: " ").first ?? "")
            else { return nil }
            return ManifestEmitter.SourceMapEntry(meridianLine: lineNumber, swiftLine: idx + 1)
        }
    }

    /// 3A: backed relations rendered for the manifest (`meridian_relations`),
    /// sorted by name. Unbacked legacy relations are omitted.
    /// C5: Map a classified `ParsedRule` to its manifest `kind` string + the
    /// `bounded` flag (meaningful only for `.permission`, e.g. "may … up to N").
    private static func ruleManifestKind(_ rule: ParsedRule) -> (kind: String, bounded: Bool) {
        switch rule {
        case .invariant: return ("invariant", false)
        case .parameterGuard: return ("parameterGuard", false)
        case .precondition: return ("precondition", false)
        case .trigger: return ("trigger", false)
        case .unsupportedTriggerCondition: return ("unsupportedTrigger", false)
        case .permission(_, _, _, _, let isBounded, _, _): return ("permission", isBounded)
        case .deonticProhibition: return ("deonticProhibition", false)
        case .deonticObligation: return ("deonticObligation", false)
        case .deonticPermission: return ("deonticPermission", false)
        }
    }

    private func definitionInfos(
        symbols: SymbolTable,
        loweredDefinitions: [LoweredDefinition],
        inlineDefinitions: [DefinitionDeclaration]
    ) -> [LoweredDefinitionInfo] {
        let loweredByFunction = Dictionary(uniqueKeysWithValues: loweredDefinitions.map { ($0.functionName, $0) })
        let inlineKeys = Set(inlineDefinitions.map { "\($0.kind.lowercased())|\($0.adjective.lowercased())" })
        return symbols.definitions.values
            .sorted { $0.functionName < $1.functionName }
            .compactMap { record in
                guard let lowered = loweredByFunction[record.functionName] else { return nil }
                let key = "\(record.kind.lowercased())|\(record.adjective.lowercased())"
                return LoweredDefinitionInfo(
                    adjective: record.adjective,
                    kind: record.kind,
                    subjectVar: lowered.subjectVar,
                    functionName: record.functionName,
                    body: lowered.body,
                    sourceLine: record.sourceLine,
                    isInline: inlineKeys.contains(key)
                )
            }
    }

    private func relationManifestEntries(_ symbols: SymbolTable) -> [ManifestEmitter.RelationManifestEntry] {
        func card(_ c: CardinalityAST) -> String { c == .one ? "one" : "various" }
        return symbols.relations
            .sorted { $0.key < $1.key }
            .compactMap { (name, rel) in
                guard let backing = symbols.backing(forRelation: name) else { return nil }
                let kind: String
                let via: String
                switch backing {
                case .property(let k, let path): kind = "property"; via = "\(k).\(path)"
                case .tool(let toolID):          kind = "tool";     via = toolID
                }
                return ManifestEmitter.RelationManifestEntry(
                    name: name, leftKind: rel.leftKind, leftCardinality: card(rel.leftCardinality),
                    rightKind: rel.rightKind, rightCardinality: card(rel.rightCardinality),
                    backing: kind, via: via, line: rel.sourceLine)
            }
    }

    /// Resolve frontmatter `tools:` tokens to registered tool method names for
    /// the prose/autonomy plan-step allow-list. Returns `nil` when no tools are
    /// declared (meaning "every registered tool", the historical default).
    ///
    /// Each token is matched against: an exact method name, the dotted form of a
    /// space-separated phrase (`page search` → `page.search`), a display-name
    /// lookup, and finally fuzzy word-overlap. `shell.run` is always included so
    /// literal shell commands keep working. If nothing resolves we fall back to
    /// the full set rather than risk an over-narrow scope.
    /// Resolve frontmatter + section tool tokens together, then keep both the
    /// resolved method names and the authored aliases. One path for
    /// `compileToModel` / `compileWithManifest` so verbalizer round-trips that
    /// fold `toolsUsed` into `tools:` cannot invent a different allow-list.
    private func mergedScopedTools(
        frontmatterTools: [String],
        toolsUsed: [String],
        symbols: SymbolTable,
        trace: ParserTrace
    ) -> [String]? {
        let tokens = frontmatterTools + toolsUsed
        guard let resolved = resolveScopedTools(tokens, symbols: symbols, trace: trace) else {
            return nil
        }
        var set = Set(resolved)
        set.formUnion(tokens.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty })
        set.insert("shell.run")
        return set.sorted()
    }

    private func resolveScopedTools(_ tokens: [String], symbols: SymbolTable, trace: ParserTrace) -> [String]? {
        guard !tokens.isEmpty else { return nil }
        let methodNames = Set(symbols.tools.keys)
        var resolved: Set<String> = []
        for raw in tokens {
            let token = raw.trimmingCharacters(in: .whitespaces)
            guard !token.isEmpty else { continue }
            let dotted = token.lowercased().split(whereSeparator: { $0 == " " }).joined(separator: ".")
            if methodNames.contains(token) {
                resolved.insert(token)
            } else if let hit = methodNames.first(where: { $0.lowercased() == token.lowercased() || $0.lowercased() == dotted }) {
                resolved.insert(hit)
            } else if let decl = symbols.tool(named: token) ?? symbols.tool(fromWords: token) {
                resolved.insert(decl.methodName)
            } else {
                // Keep unresolved aliases so section-discovered tool ids still
                // narrow the planner surface (and round-trip through frontmatter).
                resolved.insert(token)
                trace.log(.skill, "scoped tool `\(token)` did not resolve to a declared tool; keeping alias + shell/fallback")
            }
        }
        // Always allow the shell built-in for literal command surfaces.
        resolved.insert("shell.run")
        // If only the shell fallback resolved, treat the declaration as
        // unhelpful and keep the full surface available.
        if resolved.subtracting(["shell.run"]).isEmpty {
            return nil
        }
        return resolved.sorted()
    }

    /// Reject duplicate kind / phrase / tool / constant / instance names in
    /// the merged config. Without this check, a second `kind: order` from a
    /// second .merconfig would silently shadow the first.
    private func requireUniqueDeclarations(in config: MerConfigFile,
                                           engine: DiagnosticEngine? = nil) throws {
        func ensureUnique<S: Sequence>(_ seq: S, _ kind: String,
                                       name: (S.Element) -> String,
                                       line: (S.Element) -> Int) throws {
            var seen: [String: Int] = [:]
            for el in seq {
                let n = name(el)
                if let prev = seen[n] {
                    let diag = Diagnostic.error(
                        .duplicateDeclaration,
                        message: "duplicate \(kind) `\(n)` (first at line \(prev))",
                        range: SourceRange(file: "<merged>", line: line(el), column: 1),
                        help: "Rename or remove the duplicate \(kind) declaration.")
                    if let engine {
                        engine.report(diag)
                    } else {
                        throw CompilerError.diagnostics([diag])
                    }
                }
                seen[n] = line(el)
            }
        }
        var kinds: [(name: String, line: Int)] = []
        var phrases: [(name: String, line: Int)] = []
        for stmt in config.vocabulary {
            switch stmt {
            case .kind(let k):    kinds.append((k.name, k.sourceLine))
            case .phrase(let p):  phrases.append((p.pattern.displayText, p.sourceLine))
            default: break
            }
        }
        try ensureUnique(kinds,    "kind",    name: { $0.name }, line: { $0.line })
        try ensureUnique(phrases,  "phrase",  name: { $0.name }, line: { $0.line })
        try ensureUnique(config.tools,     "tool",     name: { $0.displayName }, line: { $0.sourceLine })
        try ensureUnique(config.constants, "constant", name: { $0.name }, line: { $0.sourceLine })
        try ensureUnique(config.instances, "instance", name: { $0.name }, line: { $0.sourceLine })
    }

    /// D9 / SEM-4-08: in a production trace profile, every declared tool must
    /// opt into an explicit capture policy instead of inheriting the runtime's
    /// development-oriented default.
    private func validateProductionTraceCapturePolicies(
        in config: MerConfigFile,
        engine: DiagnosticEngine
    ) {
        guard let profile = config.traceConfiguration.profile, profile.value == .production else {
            return
        }
        for tool in config.tools where tool.capturePolicy == nil {
            let toolRange = SourceRange(
                file: tool.sourceFile.isEmpty ? profile.file : tool.sourceFile,
                line: tool.sourceLine > 0 ? tool.sourceLine : profile.line,
                column: 1
            )
            let profileNote = DiagnosticNote(
                "trace profile `production` declared here",
                range: SourceRange(file: profile.file, line: profile.line, column: 1)
            )
            engine.report(Diagnostic.structural(
                .traceMissingProductionCapturePolicy,
                message: "tool \"\(tool.displayName)\" must declare `capture:` because the trace profile is `production`",
                range: toolRange,
                help: "Add `capture: full`, `capture: hash-only`, or `capture: redacted (field1, field2)` under this tool declaration.",
                notes: [profileNote]
            ))
        }
    }

    /// Wave 4A: `## Domain` sections in a `.meri` file are assembly-time
    /// vocabulary declarations. They must be harvested before the main
    /// `MeridianParser` runs so frontmatter parameters, workflow headers, and
    /// expressions can resolve the newly-declared kinds/properties.
    private func harvestDomainVocabulary(from source: String,
                                         file: String,
                                         rulebook: Rulebook,
                                         trace: ParserTrace,
                                         lexicon: EnglishLexicon) throws -> MerConfigFile {
        let lines = IndentTokenizer().tokenize(source, file: file, trace: trace)
        var sections: [[SourceLine]] = []
        var currentIsDomain = false
        var current: [SourceLine] = []

        func role(for heading: String) -> SkillSectionRole? {
            let parsed = SkillSectionRole.parseMarker(from: heading)
            if let markerRole = parsed.marker?.role {
                return markerRole
            }
            return rulebook.role(forHeading: parsed.cleanHeading)
                ?? SkillSectionRole.builtinRole(forHeading: parsed.cleanHeading)
        }

        for line in lines {
            if line.headingLevel != nil {
                if currentIsDomain, !current.isEmpty { sections.append(current) }
                current = []
                currentIsDomain = role(for: line.text) == .domain
                continue
            }
            if currentIsDomain, line.isContent {
                current.append(line)
            }
        }
        if currentIsDomain, !current.isEmpty { sections.append(current) }

        guard !sections.isEmpty else { return MerConfigFile() }
        let parser = MerConfigParser(trace: trace, lexicon: lexicon)
        let vocab = try sections.flatMap { try parser.parseVocabularyLines($0, file: file) }
        return MerConfigFile(vocabulary: vocab)
    }

    private func harvestModuleImports(from source: String, file: String) -> [ModuleImportSpec] {
        let lines = source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        guard lines.first?.trimmingCharacters(in: .whitespaces) == "---" else { return [] }
        var entries: [String: String] = [:]
        var i = 1
        while i < lines.count {
            let line = lines[i]
            if line.trimmingCharacters(in: .whitespaces) == "---" { break }
            if let colon = line.firstIndex(of: ":") {
                let key = String(line[..<colon]).trimmingCharacters(in: .whitespaces).lowercased()
                var value = String(line[line.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
                if value.hasPrefix("\"") && value.hasSuffix("\"") && value.count >= 2 {
                    value = String(value.dropFirst().dropLast())
                }
                entries[key] = value
            }
            i += 1
        }
        return ModuleResolver.parseImportList(entries["imports"], file: file, line: 1)
    }

    /// Verify each `vocabulary:` entry from the frontmatter resolves to one of
    /// the provided `VocabularyInput` names. The matcher accepts either the
    /// bare name (`foo`) or the file form (`foo.merconfig`). When
    /// `vocabularies` is empty and the source has no `vocabulary:` entries,
    /// validation is a no-op. When `vocabularies` is empty but entries exist,
    /// every entry fails — there is no vocabulary to satisfy the reference
    /// (same message shape as the non-empty case so tests can `errorContains`
    /// the vocabulary token).
    private func validateImports(_ imports: [ImportStatementAST],
                                 against vocabularies: [VocabularyInput],
                                 file: String) throws {
        let vocabularyImports = imports.filter { $0.kind == .vocabulary }
        let moduleImports = imports.filter { $0.kind == .module }
        if !moduleImports.isEmpty && options.moduleSearchPaths.isEmpty
            && options.anchorDirectory == nil {
            // Module imports are resolved during bootstrap; validation here only
            // checks legacy vocabulary references.
        }
        if vocabularies.isEmpty {
            guard let imp = vocabularyImports.first else { return }
            let raw = imp.path.trimmingCharacters(in: .whitespacesAndNewlines)
            let token = raw.hasSuffix(".") ? String(raw.dropLast()) : raw
            throw CompilerError.diagnostics([
                Diagnostic.unresolved(
                    .unknownVocabulary,
                    target: token,
                    among: [],
                    range: SourceRange(file: file, line: imp.sourceLine, column: 1),
                    noun: "vocabulary",
                    help: "Supply the `.merconfig` via the host (CLI: it is auto-discovered beside the source) and reference it in frontmatter `vocabulary:`.")
            ])
        }
        let names  = Set(vocabularies.map(\.name))
        let files  = Set(vocabularies.map(\.file))
        for imp in vocabularyImports {
            let raw = imp.path.trimmingCharacters(in: .whitespacesAndNewlines)
            let token = raw.hasSuffix(".") ? String(raw.dropLast()) : raw
            // Vocabulary tokens may carry path-like prefixes (`../foo.merconfig`)
            // when authors keep merconfigs in a sibling directory. The compiler
            // doesn't actually resolve filesystem paths — `name`/`file` are
            // logical labels supplied by the host. Strip directory components
            // and the `.merconfig` extension so the token compares against the
            // basename and stem of every supplied vocabulary.
            let basename     = (token as NSString).lastPathComponent
            let basenameStem = (basename as NSString).deletingPathExtension
            let stem         = (token as NSString).deletingPathExtension
            let matchesName = names.contains { $0.caseInsensitiveCompare(stem) == .orderedSame }
                            || names.contains { $0.caseInsensitiveCompare(token) == .orderedSame }
                            || names.contains { $0.caseInsensitiveCompare(basenameStem) == .orderedSame }
                            || names.contains { $0.caseInsensitiveCompare(basename) == .orderedSame }
            let matchesFile = files.contains { $0.caseInsensitiveCompare(token) == .orderedSame }
                            || files.contains { $0.caseInsensitiveCompare(basename) == .orderedSame }
            if !matchesName && !matchesFile {
                throw CompilerError.diagnostics([
                    Diagnostic.unresolved(
                        .unknownVocabulary,
                        target: token,
                        among: names.sorted(),
                        range: SourceRange(file: file, line: imp.sourceLine, column: 1),
                        noun: "vocabulary",
                        help: "Reference one of the supplied vocabularies in frontmatter `vocabulary:`, or supply the missing `.merconfig`.")
                ])
            }
        }
    }

    /// Validate each `rulebook:` frontmatter entry resolves to a supplied
    /// `RulebookInput`. Like `vocabulary:`, the host owns the actual rulebook
    /// sources; the frontmatter key is a declarative reference. A no-rulebook
    /// file is unaffected.
    private func validateRulebookReferences(_ metadata: FileMetadataAST?,
                                            against rulebooks: [RulebookInput],
                                            file: String) throws {
        guard let raw = metadata?["rulebook"] else { return }
        let line = metadata?.sourceLine ?? 1
        let names = Set(rulebooks.map(\.name))
        let files = Set(rulebooks.map(\.file))
        for part in raw.split(separator: ",") {
            let token = String(part)
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: .init(charactersIn: "\"'"))
            guard !token.isEmpty else { continue }
            let basename = (token as NSString).lastPathComponent
            let stem = (basename as NSString).deletingPathExtension
            let ok = names.contains { $0.caseInsensitiveCompare(stem) == .orderedSame }
                || names.contains { $0.caseInsensitiveCompare(token) == .orderedSame }
                || files.contains { $0.caseInsensitiveCompare(token) == .orderedSame }
                || files.contains { $0.caseInsensitiveCompare(basename) == .orderedSame }
            if !ok {
                throw CompilerError.diagnostics([
                    Diagnostic.unresolved(
                        .unknownRulebook,
                        target: token,
                        among: names.sorted(),
                        range: SourceRange(file: file, line: line, column: 1),
                        noun: "rulebook",
                        help: "Reference one of the supplied rulebooks in frontmatter `rulebook:`, or supply the missing `.merrules`.")
                ])
            }
        }
    }

    /// Phase 4: distil the vocabulary section into a `DomainDecl` the emitter
    /// can turn into typed Swift structs. Inheritance is flattened here (each
    /// generated struct lists ancestor properties first, in declaration order)
    /// so the emitter doesn't need to know about kind chains.
    private func buildDomainDecl(from config: MerConfigFile) throws -> SwiftEmitter.DomainDecl? {
        var kinds: [String: KindDeclaration] = [:]
        var props: [String: [PropertyEntry]] = [:]
        for stmt in config.vocabulary {
            switch stmt {
            case .kind(let k):       kinds[k.name] = k
            case .property(let p):   props[p.kind, default: []].append(contentsOf: p.properties)
            default: break
            }
        }
        if kinds.isEmpty { return nil }
        props = try mergeEnumDefaults(in: props)

        // Collect enumerations: every property typed as `one of (a, b, c)` becomes
        // a top-level enum named `<KindType><PropertyName>` (e.g. `OrderStatus`).
        var enumerations: [SwiftEmitter.DomainDecl.Enumeration] = []
        var enumNameByKindProp: [String: String] = [:]   // "order|status" → "OrderStatus"
        for (kindName, entries) in props {
            for e in entries {
                if case .enumeration(let cases, let defaultCase) = e.type {
                    let typeName = IdentifierNaming.pascalCase(kindName) + IdentifierNaming.pascalCase(e.name)
                    enumerations.append(.init(typeName, cases, defaultCase: defaultCase))
                    enumNameByKindProp["\(kindName)|\(e.name)"] = typeName
                }
            }
        }
        // Stable ordering by type name keeps generated diffs minimal.
        enumerations.sort { $0.typeName < $1.typeName }

        // Build per-kind properties; flatten parent chain.
        // Stable iteration over kind declarations: source-line order.
        let kindList = kinds.values.sorted { $0.sourceLine < $1.sourceLine }
        let knownKindNames = Set(kinds.keys.map { $0.lowercased() })
        let outKinds: [SwiftEmitter.DomainDecl.Kind] = kindList.map { k in
            let inheritedChain = ancestorChain(of: k.name, in: kinds)
            // Farthest ancestor first, nearest parent last (matches
            // `ancestorChain`'s ordering) — so a nearer declaration is a later
            // element here, which is what "nearest wins" dedup below relies on.
            let rawInherited = inheritedChain.flatMap { ancestor in
                (props[ancestor] ?? []).map { propertyToDecl($0, kindName: ancestor, enumByKindProp: enumNameByKindProp, knownKindNames: knownKindNames) }
            }
            let ownProps = (props[k.name] ?? []).map { propertyToDecl($0, kindName: k.name, enumByKindProp: enumNameByKindProp, knownKindNames: knownKindNames) }
            // A kind re-declaring an ancestor's property name — e.g. "A
            // clinician has a name and a role." / "A nurse has a name and a
            // dose count." — overrides that property, not duplicates it: the
            // emitted struct must end up with exactly one stored `name`, not
            // two (which is an invalid redeclaration in Swift). `ownProps`
            // always wins over anything inherited; among inherited levels
            // alone, the nearer ancestor's declaration wins over a farther
            // one with the same name. Iterate nearest-to-farthest (reversed)
            // so first-seen == nearest, then reverse back to restore the
            // farthest-first output ordering the rest of the pipeline expects.
            let ownNames = Set(ownProps.map { IdentifierNaming.camelPreservingCase($0.name).lowercased() })
            var seenNames = ownNames
            var dedupedReversed: [SwiftEmitter.DomainDecl.Property] = []
            for prop in rawInherited.reversed() {
                let key = IdentifierNaming.camelPreservingCase(prop.name).lowercased()
                if seenNames.contains(key) { continue }
                seenNames.insert(key)
                dedupedReversed.append(prop)
            }
            let inheritedProps = dedupedReversed.reversed()
            return .init(name: k.name, parent: k.parent,
                         ownProperties: ownProps, inheritedProperties: Array(inheritedProps))
        }
        return SwiftEmitter.DomainDecl(kinds: outKinds, enumerations: enumerations)
    }

    private func mergeEnumDefaults(in props: [String: [PropertyEntry]]) throws -> [String: [PropertyEntry]] {
        var out = props
        for (kind, entries) in props {
            let defaults: [(value: String, lineEntry: PropertyEntry)] = entries.compactMap { entry in
                if case .enumeration(let cases, let defaultCase) = entry.type,
                   entry.name.isEmpty, cases.isEmpty, let defaultCase {
                    return (defaultCase, entry)
                }
                return nil
            }
            guard !defaults.isEmpty else { continue }
            if defaults.count >= 2 {
                let usuallyDefaults = defaults.filter { $0.lineEntry.name.isEmpty }
                let uniqueUsually = Set(usuallyDefaults.map(\.value))
                if usuallyDefaults.count >= 2, uniqueUsually.count > 1 {
                    throw CompilerError.diagnostics(usuallyDefaults.map { entry in
                        Diagnostic.error(
                            .domainContradictoryDefault,
                            message: "contradictory default for `\(kind)`: `\(entry.value)` conflicts with another `is usually` assertion",
                            range: SourceRange(file: "<merged>", line: 0, column: 1),
                            help: "Pick a single default case per kind, or split the kind so each default applies to a distinct property.")
                    })
                }
            }
            var concrete = entries.filter { entry in
                if case .enumeration(let cases, let defaultCase) = entry.type {
                    return !(entry.name.isEmpty && cases.isEmpty && defaultCase != nil)
                }
                return true
            }
            for (defaultValue, _) in defaults {
                let matches = concrete.enumerated().filter { _, entry in
                    if case .enumeration(let cases, _) = entry.type {
                        return cases.contains { $0.caseInsensitiveCompare(defaultValue) == .orderedSame }
                    }
                    return false
                }
                guard matches.count == 1, let match = matches.first else {
                    throw CompilerError.diagnostics([
                        Diagnostic.error(
                            .invalidEnumDefault,
                            message: "default enum case `\(defaultValue)` for `\(kind)` does not identify exactly one enum property. Add `, called the <property>` to the `can be` declaration or choose a case unique to one property.",
                            range: SourceRange(file: "<merged>", line: 1, column: 1),
                            help: "Disambiguate with `, called the <property>` or pick a case that belongs to only one enum property.")
                    ])
                }
                let (idx, entry) = match
                if case .enumeration(let cases, let existingDefault) = entry.type {
                    if let existingDefault,
                       existingDefault.caseInsensitiveCompare(defaultValue) != .orderedSame {
                        let code: DiagnosticCode = entry.name.isEmpty ? .domainContradictoryDefault : .invalidEnumDefault
                        throw CompilerError.diagnostics([
                            Diagnostic.error(
                                code,
                                message: "conflicting defaults for `\(kind).\(entry.name.isEmpty ? kind : entry.name)`: `\(existingDefault)` and `\(defaultValue)`",
                                range: SourceRange(file: "<merged>", line: 1, column: 1),
                                help: "Pick a single default case per enum property.")
                        ])
                    }
                    concrete[idx] = PropertyEntry(
                        name: entry.name,
                        type: .enumeration(cases: cases, defaultCase: existingDefault ?? defaultValue)
                    )
                }
            }
            out[kind] = concrete
        }
        return out
    }

    /// Walk the parent chain (excluding the kind itself, root → direct parent).
    /// Stops at the semantic root or any built-in scalar. Cycle-safe.
    private func ancestorChain(of name: String, in kinds: [String: KindDeclaration]) -> [String] {
        var chain: [String] = []
        var cur = name
        var seen: Set<String> = [cur]
        while let kd = kinds[cur] {
            let p = kd.parent.lowercased()
            if BuiltinSemanticBase.isRoot(p) || BuiltinScalarTypes.scalarParents.contains(p) { break }
            if seen.contains(kd.parent) { break }
            chain.insert(kd.parent, at: 0)
            seen.insert(kd.parent)
            cur = kd.parent
        }
        return chain
    }

    private func propertyToDecl(_ p: PropertyEntry,
                                kindName: String,
                                enumByKindProp: [String: String],
                                knownKindNames: Set<String>) -> SwiftEmitter.DomainDecl.Property {
        switch p.type {
        case .defaulted:
            return .init(p.name, .scalar("String"))
        case .explicit, .listOf, .optional:
            let swift = BuiltinScalarTypes.resolvePropertySwiftType(p.type, knownKindNames: knownKindNames)
            return .init(p.name, .scalar(swift))
        case .enumeration(_, let defaultCase):
            // The enumeration's Swift type was registered above (same `props`
            // dict, same "kind|property" key) — the lookup is guaranteed to
            // succeed by construction. Falling back to a bogus "String" enum
            // name here would silently corrupt the property into a
            // nonsensical `.enumeration("String", …)` that later crashes in
            // `DomainEmitter.defaultExpr`'s `enumFirstCase` lookup instead of
            // surfacing the real internal-consistency bug at its source.
            guard let enumName = enumByKindProp["\(kindName)|\(p.name)"] else {
                preconditionFailure(
                    "internal: no registered enum type for \(kindName).\(p.name) — MER0004 enumByKindProp/props desynchronized")
            }
            return .init(p.name, .enumeration(enumName, defaultCase: defaultCase))
        }
    }

    private func scalarTypeName(_ raw: String) -> String {
        BuiltinScalarTypes.swiftTypeName(for: raw) ?? IdentifierNaming.pascalCase(raw)
    }

    private func propertyValueToInstance(_ v: PropertyValueAST) -> SwiftEmitter.InstancesDecl.PropertyValue {
        switch v {
        case .literal(let lit):     return .literal(constantToIRLiteral(lit))
        case .envVar(let name):     return .envVar(name)
        }
    }

    private func constantToIRLiteral(_ lit: LiteralAST) -> IRLiteral { LiteralLowering.toIRLiteral(lit) }
}

// MARK: - CompilerError

public enum CompilerError: Error, Sendable {
    case syntaxError(message: String, range: SourceRange)
    case semanticError(message: String, range: SourceRange)
    case codegenError(message: String)
    /// One or more structured diagnostics (the modern path). A failed compile
    /// reports *all* collected errors here. Legacy cases above project into this
    /// shape via `diagnostics` so every consumer can render uniformly.
    case diagnostics([Diagnostic])

    /// Project any `CompilerError` into structured diagnostics so renderers and
    /// test shims can treat every error uniformly. Legacy cases map to generic
    /// codes; `.diagnostics` returns its payload.
    public var diagnostics: [Diagnostic] {
        switch self {
        case .diagnostics(let ds):
            return ds
        case .semanticError(let m, let r):
            return [Diagnostic(code: .legacySemantic, severity: .error, message: m, primaryRange: r)]
        case .syntaxError(let m, let r):
            return [Diagnostic(code: .legacySyntax, severity: .error, message: m, primaryRange: r)]
        case .codegenError(let m):
            return [Diagnostic(code: .codegenError, severity: .error, message: m,
                               primaryRange: SourceRange(file: "<generated>", line: 0, column: 1))]
        }
    }

    /// The first diagnostic's primary message (used by legacy text assertions).
    public var primaryMessage: String {
        diagnostics.first?.message ?? "\(self)"
    }
}
