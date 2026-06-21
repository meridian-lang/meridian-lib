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
        public init(emitterOptions: SwiftEmitter.Options = .init(),
                    trace: ParserTrace = .shared,
                    lexicon: EnglishLexicon = .default,
                    fallbackPolicy: FallbackPolicy = .strict) {
            self.emitterOptions = emitterOptions
            self.trace = trace
            self.lexicon = lexicon
            self.fallbackPolicy = fallbackPolicy
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
    ) -> String {
        SwiftEmitter(options: options.emitterOptions)
            .emitFile(workflows: workflows, constantsDecl: constantsDecl)
    }

    /// Emit the companion JSON manifest.
    public func emitManifest(_ input: ManifestEmitter.Input) throws -> String {
        try ManifestEmitter().emit(input)
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
    ) throws -> (swift: String, manifest: ManifestEmitter.Input) {
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
            duplicateRulebookHelp: "Each `--rulebook` / frontmatter `rulebook:` entry must have a unique name.",
            duplicateVocabularyHelp: "Each `--vocabulary` / frontmatter `vocabulary:` entry must have a unique name."
        )

        let ast = try trace.phase("parse") {
            try MeridianParser(symbols: bootstrap.symbols, trace: trace, lexicon: bootstrap.lexicon,
                               rewriteEngine: bootstrap.rewriteEngine, diagnostics: engine).parse(meridianSource, file: meridianFile)
        }
        return try lowerAndEmit(
            ast: ast, meridianFile: meridianFile,
            symbols: bootstrap.symbols, config: bootstrap.config, lexicon: bootstrap.lexicon, trace: trace,
            rulebook: bootstrap.rulebook, vocabularies: vocabularies, rulebooks: rulebooks,
            preRegistered: false, engine: engine
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

    private struct BootstrapContext {
        let config: MerConfigFile
        let lexicon: EnglishLexicon
        let rulebook: Rulebook
        let rewriteEngine: RewriteEngine?
        let symbols: SymbolTable
        let engine: DiagnosticEngine
    }

    private func bootstrap(
        meridianSources: [(source: String, file: String)],
        vocabularies: [VocabularyInput],
        rulebooks: [RulebookInput],
        trace: ParserTrace,
        engine: DiagnosticEngine,
        duplicateRulebookHelp: String,
        duplicateVocabularyHelp: String
    ) throws -> BootstrapContext {
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
                        help: duplicateRulebookHelp)
                ])
            }
            let parsed = try RulebookParser(trace: trace).parse(input.source, file: input.file)
            rulebook = rulebook.merging(parsed)
        }
        let rewriteEngine = rulebook.isEmpty ? nil : RewriteEngine(rulebook: rulebook, trace: trace)

        var config = MerConfigFile()
        var seenNames: Set<String> = []
        for input in vocabularies {
            if !seenNames.insert(input.name).inserted {
                throw CompilerError.diagnostics([
                    Diagnostic.error(
                        .duplicateName,
                        message: "duplicate vocabulary name: \(input.name)",
                        range: SourceRange(file: input.file, line: 1, column: 1),
                        help: duplicateVocabularyHelp)
                ])
            }
            let parsed = try MerConfigParser(trace: trace, lexicon: lexicon, diagnostics: engine)
                .parse(input.source, file: input.file)
            config = config.merging(parsed)
        }
        for meridian in meridianSources {
            let inlineDomain = try harvestDomainVocabulary(
                from: meridian.source,
                file: meridian.file,
                rulebook: rulebook,
                trace: trace,
                lexicon: lexicon
            )
            config = config.merging(inlineDomain)
        }
        try requireUniqueDeclarations(in: config, engine: engine)
        try engine.throwIfErrors()

        lexicon = lexicon.merging(
            comparisonSynonyms: config.languageSynonyms.comparisonSynonyms,
            durationSynonyms: config.languageSynonyms.durationSynonyms,
            assertionSynonyms: config.languageSynonyms.assertionSynonyms,
            timestampProperty: config.languageSynonyms.timestampProperty,
            emptySynonyms: config.languageSynonyms.emptySynonyms,
            filledSynonyms: config.languageSynonyms.filledSynonyms,
            pastWindowSynonyms: config.languageSynonyms.pastWindowSynonyms,
            futureWindowSynonyms: config.languageSynonyms.futureWindowSynonyms,
            timestampAliasSynonyms: config.languageSynonyms.timestampAliasSynonyms,
            aggregateSynonyms: config.languageSynonyms.aggregateSynonyms,
            superlativeSynonyms: config.languageSynonyms.superlativeSynonyms,
            sortBySynonyms: config.languageSynonyms.sortBySynonyms,
            ascendingSynonyms: config.languageSynonyms.ascendingSynonyms,
            descendingSynonyms: config.languageSynonyms.descendingSynonyms,
            possessiveSynonyms: config.languageSynonyms.possessiveSynonyms,
            anaphoraSynonyms: config.languageSynonyms.anaphoraSynonyms,
            conditionHeaderSynonyms: config.languageSynonyms.conditionHeaderSynonyms,
            actionHeaderSynonyms: config.languageSynonyms.actionHeaderSynonyms,
            wildcardSynonyms: config.languageSynonyms.wildcardSynonyms,
            shellFenceSynonyms: config.languageSynonyms.shellFenceSynonyms
        )

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
        let engine = DiagnosticEngine(trace: trace)
        let bootstrap = try bootstrap(
            meridianSources: skills.map { ($0.source, $0.file) },
            vocabularies: vocabularies,
            rulebooks: rulebooks,
            trace: trace,
            engine: engine,
            duplicateRulebookHelp: "Supply each rulebook only once or rename the duplicate.",
            duplicateVocabularyHelp: "Supply each vocabulary only once or rename the duplicate."
        )

        // Parse every skill against the SHARED symbol table. Each file gets its
        // own per-file `DiagnosticEngine` (so batching never crosses files) used
        // for both its parse and lower phases.
        var parsed: [(ast: MeridianFile, file: String, engine: DiagnosticEngine)] = []
        for skill in skills {
            let engine = DiagnosticEngine(trace: trace)
            let ast = try MeridianParser(symbols: bootstrap.symbols, trace: trace, lexicon: bootstrap.lexicon,
                                         rewriteEngine: bootstrap.rewriteEngine, diagnostics: engine).parse(skill.source, file: skill.file)
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
        preRegistered: Bool,
        engine: DiagnosticEngine
    ) throws -> (swift: String, manifest: ManifestEmitter.Input) {
        try validateImports(ast.imports, against: vocabularies, file: meridianFile)
        try validateRulebookReferences(ast.metadata, against: rulebooks, file: meridianFile)

        // Merge the frontmatter `allow-fallbacks:` policy (if any) with the
        // option-level escape hatch. The resulting policy is the union.
        var effectivePolicy = options.fallbackPolicy
        if let raw = ast.metadata?["allow-fallbacks"] {
            let (frontPolicy, unknown) = FallbackPolicy.parse(raw)
            effectivePolicy = effectivePolicy.merging(frontPolicy)
            let fbLine = ast.metadata?.sourceLine ?? 1
            for token in unknown {
                // A typo'd allow-fallbacks token would otherwise silently fail to
                // take effect — surface it through the always-on funnel.
                engine.report(Diagnostic.unresolved(
                    .unknownFallbackKind,
                    target: token,
                    among: FallbackKind.allCases.map(\.rawValue),
                    range: SourceRange(file: meridianFile, line: fbLine, column: 1),
                    noun: "allow-fallbacks kind",
                    help: "Use one of the recognized fallback kinds, or remove the token."))
            }
        }

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

        let domainDecl = try buildDomainDecl(from: config)

        // Narrow the plan-step tool allow-list to the skill's declared `tools:`
        // frontmatter (if any). Unresolved tokens fall back to the full set so a
        // typo can never silently empty the planner's capability surface.
        let frontmatter = SkillFrontmatter(ast.metadata)
        var scopedTools = resolveScopedTools(frontmatter.tools, symbols: symbols, trace: trace)
        // A `## Tools Used` section (1D) declares the skill's tool surface with
        // authoritative tool ids — merge them into the scope. When no
        // frontmatter `tools:` were declared, the section narrows scope to its
        // ids (plus the shell fallback); otherwise it unions in.
        if !ast.toolsUsed.isEmpty {
            var set = Set(scopedTools ?? [])
            set.formUnion(ast.toolsUsed)
            set.insert("shell.run")
            scopedTools = set.sorted()
        }

        // Batch diagnostics collector — per-file, single-threaded (passed in so
        // it also holds any parse-phase diagnostics). The lowerer recovers
        // per-workflow/per-rule into this engine so one compile reports many
        // errors; we throw the aggregate before codegen.
        let lowerer = ASTToIR(symbols: symbols, sourceFile: meridianFile, trace: trace,
                              lexicon: lexicon, fallbackPolicy: effectivePolicy,
                              rulebook: rulebook, scopedTools: scopedTools,
                              frontmatterTools: frontmatter.tools + ast.toolsUsed,
                              engine: engine)
        var workflows = try trace.phase("lower") { try lowerer.lower(ast, preRegistered: preRegistered) }
        // 2B: lower the registered checkable adjectives to file-scope helpers.
        let loweredDefinitions = try lowerer.lowerRegisteredDefinitions()
        // Surface all collected lowering diagnostics at once, before codegen.
        try engine.throwIfErrors()

        // E: Frontmatter `triggers:` → typed triggers → one synthetic trigger
        // workflow each (wait for the trigger + fan out `trigger.<name>.fired`).
        // The host owns actual firing; routing is the resolver's job.
        if !frontmatter.triggers.isEmpty {
            let classifier = TriggerClassifier(lexicon: lexicon, rulebook: rulebook)
            let triggers = frontmatter.triggers.map {
                classifier.classify($0, sourceLine: ast.metadata?.sourceLine ?? 0)
            }
            workflows += TriggerSynthesizer(lexicon: lexicon, trace: trace)
                .synthesize(triggers, sourceFile: meridianFile)
        }

        // Emit Swift
        let emitterOpts = SwiftEmitter.Options(
            includeTimestamp: options.emitterOptions.includeTimestamp,
            sourceFileName: meridianFile,
            indentUnit: options.emitterOptions.indentUnit,
            emitSourceLineComments: options.emitterOptions.emitSourceLineComments,
            namespaceEnum: options.emitterOptions.namespaceEnum
        )
        let swift = trace.phase("codegen") {
            SwiftEmitter(options: emitterOpts, trace: trace)
                .emitFile(workflows: workflows,
                          constantsDecl: constantsDecl,
                          instancesDecl: instancesDecl,
                          domainDecl: domainDecl,
                          fileMetadata: ast.metadata,
                          definitions: loweredDefinitions)
        }

        // Assemble the COMPLETE manifest Input as part of every compile. The
        // rich data computed here (workflows, outline, recorded sections) is no
        // longer discarded — the host emits the manifest from this Input.
        let manifestInput = ManifestEmitter.Input(
            sourceFiles: [meridianFile] + vocabularies.map(\.file),
            workflows: workflows,
            constantsDecl: constantsDecl,
            toolsUsed: ast.toolsUsed,
            instancesRequired: instancesDecl.map { decl in
                decl.entries.map { e in
                    ManifestEmitter.InstanceManifestEntry(name: e.name, kind: e.kind)
                }
            } ?? [],
            sourceMap: Compiler.sourceMap(fromGeneratedSwift: swift),
            metadata: ast.metadata,
            outline: ast.outline,
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
                }
        )
        return (swift, manifestInput)
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
                trace.log(.skill, "scoped tool `\(token)` did not resolve to a declared tool; relying on shell/fallback")
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
        if vocabularies.isEmpty {
            guard let imp = imports.first else { return }
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
        for imp in imports {
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
        let outKinds: [SwiftEmitter.DomainDecl.Kind] = kindList.map { k in
            let inheritedChain = ancestorChain(of: k.name, in: kinds)
            let inheritedProps = inheritedChain.flatMap { ancestor in
                (props[ancestor] ?? []).map { propertyToDecl($0, kindName: ancestor, enumByKindProp: enumNameByKindProp) }
            }
            let ownProps = (props[k.name] ?? []).map { propertyToDecl($0, kindName: k.name, enumByKindProp: enumNameByKindProp) }
            return .init(name: k.name, parent: k.parent,
                         ownProperties: ownProps, inheritedProperties: inheritedProps)
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
                        throw CompilerError.diagnostics([
                            Diagnostic.error(
                                .invalidEnumDefault,
                                message: "conflicting defaults for `\(kind).\(entry.name)`: `\(existingDefault)` and `\(defaultValue)`",
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
                                enumByKindProp: [String: String]) -> SwiftEmitter.DomainDecl.Property {
        switch p.type {
        case .defaulted:
            // Defaulted properties (no `which is …` clause) are scalar Strings.
            return .init(p.name, .scalar("String"))
        case .explicit(let typeName):
            return .init(p.name, .scalar(scalarTypeName(typeName)))
        case .enumeration(_, let defaultCase):
            // The enumeration's Swift type was registered above; look it up.
            let enumName = enumByKindProp["\(kindName)|\(p.name)"] ?? "String"
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
    case notImplemented(String)
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
        case .notImplemented(let m):
            return [Diagnostic(code: .notImplemented, severity: .error, message: m,
                               primaryRange: SourceRange(file: "<unknown>", line: 0, column: 1))]
        }
    }

    /// The first diagnostic's primary message (used by legacy text assertions).
    public var primaryMessage: String {
        diagnostics.first?.message ?? "\(self)"
    }
}
