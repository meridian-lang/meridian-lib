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
        vocabularies: [VocabularyInput]
    ) throws -> String {
        let trace = options.trace
        var lexicon = options.lexicon

        // Parse + merge every supplied .merconfig.
        var config = MerConfigFile()
        var seenNames: Set<String> = []
        for input in vocabularies {
            if !seenNames.insert(input.name).inserted {
                throw CompilerError.semanticError(
                    message: "duplicate vocabulary name: \(input.name)",
                    range: SourceRange(file: input.file, line: 1, column: 1)
                )
            }
            let parsed = try MerConfigParser(trace: trace, lexicon: lexicon).parse(input.source, file: input.file)
            config = config.merging(parsed)
        }
        try requireUniqueDeclarations(in: config)

        // Apply language synonyms from merged config into the effective lexicon.
        lexicon = lexicon.merging(
            comparisonSynonyms: config.languageSynonyms.comparisonSynonyms,
            durationSynonyms: config.languageSynonyms.durationSynonyms
        )

        // Use the first vocabulary file (if any) for symbol-table source
        // attribution; multi-vocab attributes still flow through the merged
        // config's individual statement source lines.
        let symbolsFile = vocabularies.first?.file ?? "config.merconfig"
        let symbols = SymbolTable.build(from: config, sourceFile: symbolsFile, trace: trace, lexicon: lexicon)

        let ast = try MeridianParser(symbols: symbols, trace: trace, lexicon: lexicon).parse(meridianSource, file: meridianFile)
        try validateImports(ast.imports, against: vocabularies, file: meridianFile)

        // Merge the frontmatter `allow-fallbacks:` policy (if any) with the
        // option-level escape hatch. The resulting policy is the union.
        var effectivePolicy = options.fallbackPolicy
        if let raw = ast.metadata?["allow-fallbacks"] {
            let (frontPolicy, unknown) = FallbackPolicy.parse(raw)
            effectivePolicy = effectivePolicy.merging(frontPolicy)
            for token in unknown {
                trace.log(.lowering, "frontmatter allow-fallbacks: unknown kind '\(token)' (allowed: \(FallbackKind.allCases.map(\.rawValue).joined(separator: ", ")))")
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

        let domainDecl = buildDomainDecl(from: config)

        let lowerer = ASTToIR(symbols: symbols, sourceFile: meridianFile, trace: trace,
                              lexicon: lexicon, fallbackPolicy: effectivePolicy)
        let workflows = try lowerer.lower(ast)

        // Emit Swift
        let emitterOpts = SwiftEmitter.Options(
            includeTimestamp: options.emitterOptions.includeTimestamp,
            sourceFileName: meridianFile,
            indentUnit: options.emitterOptions.indentUnit,
            emitSourceLineComments: options.emitterOptions.emitSourceLineComments
        )
        return SwiftEmitter(options: emitterOpts)
            .emitFile(workflows: workflows,
                      constantsDecl: constantsDecl,
                      instancesDecl: instancesDecl,
                      domainDecl: domainDecl,
                      fileMetadata: ast.metadata)
    }

    /// Reject duplicate kind / phrase / tool / constant / instance names in
    /// the merged config. Without this check, a second `kind: order` from a
    /// second .merconfig would silently shadow the first.
    private func requireUniqueDeclarations(in config: MerConfigFile) throws {
        func ensureUnique<S: Sequence>(_ seq: S, _ kind: String,
                                       name: (S.Element) -> String,
                                       line: (S.Element) -> Int) throws {
            var seen: [String: Int] = [:]
            for el in seq {
                let n = name(el)
                if let prev = seen[n] {
                    throw CompilerError.semanticError(
                        message: "duplicate \(kind) `\(n)` (first at line \(prev))",
                        range: SourceRange(file: "<merged>", line: line(el), column: 1)
                    )
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
            throw CompilerError.semanticError(
                message: "no vocabulary named `\(token)` was supplied (saw: )",
                range: SourceRange(file: file, line: imp.sourceLine, column: 1)
            )
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
                throw CompilerError.semanticError(
                    message: "no vocabulary named `\(token)` was supplied (saw: \(names.sorted().joined(separator: ", ")))",
                    range: SourceRange(file: file, line: imp.sourceLine, column: 1)
                )
            }
        }
    }

    /// Phase 4: distil the vocabulary section into a `DomainDecl` the emitter
    /// can turn into typed Swift structs. Inheritance is flattened here (each
    /// generated struct lists ancestor properties first, in declaration order)
    /// so the emitter doesn't need to know about kind chains.
    private func buildDomainDecl(from config: MerConfigFile) -> SwiftEmitter.DomainDecl? {
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

        // Collect enumerations: every property typed as `one of (a, b, c)` becomes
        // a top-level enum named `<KindType><PropertyName>` (e.g. `OrderStatus`).
        var enumerations: [SwiftEmitter.DomainDecl.Enumeration] = []
        var enumNameByKindProp: [String: String] = [:]   // "order|status" → "OrderStatus"
        for (kindName, entries) in props {
            for e in entries {
                if case .enumeration(let cases) = e.type {
                    let typeName = pascalCase(kindName) + pascalCase(e.name)
                    enumerations.append(.init(typeName, cases))
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

    /// Walk the parent chain (excluding the kind itself, root → direct parent).
    /// Stops at `thing` or any built-in scalar. Cycle-safe.
    private func ancestorChain(of name: String, in kinds: [String: KindDeclaration]) -> [String] {
        var chain: [String] = []
        var cur = name
        var seen: Set<String> = [cur]
        while let kd = kinds[cur] {
            let p = kd.parent.lowercased()
            if p == "thing" || builtinScalars.contains(p) { break }
            if seen.contains(kd.parent) { break }
            chain.insert(kd.parent, at: 0)
            seen.insert(kd.parent)
            cur = kd.parent
        }
        return chain
    }

    private let builtinScalars: Set<String> = [
        "string", "number", "money", "date", "datetime",
        "boolean", "bool", "duration", "list"
    ]

    private func propertyToDecl(_ p: PropertyEntry,
                                kindName: String,
                                enumByKindProp: [String: String]) -> SwiftEmitter.DomainDecl.Property {
        switch p.type {
        case .defaulted:
            // Defaulted properties (no `which is …` clause) are scalar Strings.
            return .init(p.name, .scalar("String"))
        case .explicit(let typeName):
            return .init(p.name, .scalar(scalarTypeName(typeName)))
        case .enumeration:
            // The enumeration's Swift type was registered above; look it up.
            let enumName = enumByKindProp["\(kindName)|\(p.name)"] ?? "String"
            return .init(p.name, .enumeration(enumName))
        }
    }

    private func scalarTypeName(_ raw: String) -> String {
        switch raw.lowercased() {
        case "string":      return "String"
        case "number":      return "Decimal"
        case "money":       return "Money"
        case "date":        return "Date"
        case "datetime":    return "Date"
        case "boolean":     return "Bool"
        case "bool":        return "Bool"
        case "duration":    return "Duration"
        case "list":        return "[String]"
        default:
            // Custom kind name → reference its generated Swift type.
            return pascalCase(raw)
        }
    }

    private func pascalCase(_ raw: String) -> String {
        raw.split(whereSeparator: { $0 == " " || $0 == "_" })
            .map { $0.prefix(1).uppercased() + $0.dropFirst().lowercased() }
            .joined()
    }

    private func propertyValueToInstance(_ v: PropertyValueAST) -> SwiftEmitter.InstancesDecl.PropertyValue {
        switch v {
        case .literal(let lit):     return .literal(constantToIRLiteral(lit))
        case .envVar(let name):     return .envVar(name)
        }
    }

    private func constantToIRLiteral(_ lit: LiteralAST) -> IRLiteral {
        switch lit {
        case .string(let s):            return .string(s)
        case .integer(let n):           return .number(Decimal(n))
        case .double(let d):            return .number(Decimal(d))
        case .boolean(let b):           return .boolean(b)
        case .money(let a, let c):      return .money(Decimal(a), currency: c)
        case .duration(let v, let u):   return .duration(.seconds(Int64(v * Double(u.inSeconds))))
        }
    }
}

// MARK: - CompilerError

public enum CompilerError: Error, Sendable {
    case notImplemented(String)
    case syntaxError(message: String, range: SourceRange)
    case semanticError(message: String, range: SourceRange)
    case codegenError(message: String)
}
