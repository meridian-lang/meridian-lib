import Foundation
import MeridianRuntime

public enum ModuleResolverError: Error, Sendable {
    case notFound(module: String, searched: [String])
    case cycle(path: [String])
    case duplicateExport(module: String, other: String, symbol: String)
    case sealedOverride(module: String, symbol: String)
    case duplicateImport(name: String)
    case parseFailed(file: String, underlying: String)
    case encodingFailed
    case decodingFailed
}

/// A fully resolved module node in dependency-first topological order.
public struct ResolvedModule: Sendable {
    public let spec: ModuleImportSpec
    public let manifest: ModuleManifest
    public let packageRoot: URL
    public let merconfigSource: String
    public let merconfigFile: String
    public let config: MerConfigFile
    public let snapshot: ModuleSymbolSnapshot
    public let imports: [ModuleImportSpec]
}

public struct ModuleResolutionResult: Sendable {
    public let modules: [ResolvedModule]
    public let lockfile: ModuleLockfile
    public let vocabularies: [Compiler.VocabularyInput]
}

/// Resolves `import <module> [as <alias>]` against local relative paths and
/// `--module-path` search roots. Performs cycle detection and produces a
/// deterministic topological order.
public struct ModuleResolver: Sendable {

    public let moduleSearchPaths: [URL]
    public let anchorDirectory: URL
    public let trace: ParserTrace
    public let lexicon: EnglishLexicon

    public init(
        moduleSearchPaths: [URL],
        anchorDirectory: URL,
        trace: ParserTrace = .shared,
        lexicon: EnglishLexicon = .default
    ) {
        self.moduleSearchPaths = moduleSearchPaths
        self.anchorDirectory = anchorDirectory.standardizedFileURL
        self.trace = trace
        self.lexicon = lexicon
    }

    public func resolve(imports: [ModuleImportSpec]) throws -> ModuleResolutionResult {
        var seenImportNames: Set<String> = []
        for spec in imports {
            let key = spec.name.lowercased()
            if !seenImportNames.insert(key).inserted {
                throw CompilerError.diagnostics([
                    Diagnostic.error(
                        .duplicateModuleImport,
                        message: "duplicate module import `\(spec.name)`",
                        range: SourceRange(file: spec.sourceFile, line: spec.sourceLine, column: 1),
                        help: "Import each module at most once, or use `as` to alias a second reference.")
                ])
            }
        }

        var resolvedByID: [String: ResolvedModule] = [:]
        var visiting: Set<String> = []
        var order: [ResolvedModule] = []

        func resolveOne(_ spec: ModuleImportSpec) throws {
            let id = spec.name.lowercased()
            if resolvedByID[id] != nil { return }
            if visiting.contains(id) {
                let cycle = visiting.sorted() + [spec.name]
                throw CompilerError.diagnostics([
                    Diagnostic.error(
                        .moduleImportCycle,
                        message: "cyclic module import: \(cycle.joined(separator: " → "))",
                        range: SourceRange(file: spec.sourceFile, line: spec.sourceLine, column: 1),
                        help: "Break the cycle by moving shared vocabulary to a separate module or removing a redundant import.")
                ])
            }
            visiting.insert(id)
            let located = try locatePackage(named: spec.name, sourceFile: spec.sourceFile, sourceLine: spec.sourceLine)
            let manifest = located.manifest
            let config = try parseMerconfig(at: located.merconfigURL, file: located.merconfigURL.lastPathComponent)
            let nestedImports = parseImportsSection(from: config, file: located.merconfigURL.lastPathComponent)
                + parseImportsFromMeridian(at: located.meridianURL)
            for nested in nestedImports {
                try resolveOne(nested)
            }
            let snapshot = ModuleSymbolSnapshot.build(from: config, manifest: manifest)
            for existing in resolvedByID.values {
                if let symbol = snapshot.collision(with: existing.snapshot) {
                    throw CompilerError.diagnostics([
                        Diagnostic.error(
                            .moduleExportCollision,
                            message: "modules `\(manifest.id)` and `\(existing.manifest.id)` both export `\(symbol)`",
                            range: SourceRange(file: spec.sourceFile, line: spec.sourceLine, column: 1),
                            help: "Rename the symbol in one module, mark it `sealed` in the exporter, or import only one module.")
                    ])
                }
            }
            let resolved = ResolvedModule(
                spec: spec,
                manifest: manifest,
                packageRoot: located.rootURL,
                merconfigSource: located.merconfigSource,
                merconfigFile: located.merconfigURL.lastPathComponent,
                config: config,
                snapshot: snapshot,
                imports: nestedImports
            )
            resolvedByID[id] = resolved
            visiting.remove(id)
            order.append(resolved)
        }

        for spec in imports.sorted(by: { $0.name.lowercased() < $1.name.lowercased() }) {
            try resolveOne(spec)
        }

        let lockEntries: [ModuleLockfile.Entry] = try order.map { mod in
            let hash = try contentHash(mod.merconfigSource)
            return ModuleLockfile.Entry(
                id: mod.manifest.id,
                path: mod.packageRoot.path,
                contentHash: hash,
                alias: mod.spec.alias
            )
        }
        let lockfile = ModuleLockfile(modules: lockEntries)
        let vocabularies: [Compiler.VocabularyInput] = order.map { mod in
            Compiler.VocabularyInput(
                name: mod.spec.alias ?? mod.manifest.id,
                file: mod.merconfigFile,
                source: mod.merconfigSource
            )
        }
        trace.log(.symbols, "resolved \(order.count) module(s): \(order.map(\.manifest.id).joined(separator: ", "))")
        return ModuleResolutionResult(modules: order, lockfile: lockfile, vocabularies: vocabularies)
    }

    // MARK: - Package discovery

    private struct LocatedPackage {
        let rootURL: URL
        let merconfigURL: URL
        let meridianURL: URL?
        let merconfigSource: String
        let manifest: ModuleManifest
    }

    private func locatePackage(named name: String, sourceFile: String, sourceLine: Int) throws -> LocatedPackage {
        var candidates: [URL] = []
        let stem = (name as NSString).lastPathComponent
        func appendCandidates(relativeTo base: URL) {
            let base = base.standardizedFileURL
            candidates.append(base.appendingPathComponent(stem).appendingPathComponent("module.merconfig"))
            candidates.append(base.appendingPathComponent("\(stem).merconfig"))
            candidates.append(base.appendingPathComponent(stem).appendingPathComponent("\(stem).merconfig"))
            if name.contains("/") {
                candidates.append(base.appendingPathComponent(name).appendingPathComponent("module.merconfig"))
                candidates.append(base.appendingPathComponent("\(name).merconfig"))
            }
        }
        appendCandidates(relativeTo: anchorDirectory)
        for path in moduleSearchPaths {
            appendCandidates(relativeTo: path)
        }
        for url in candidates {
            if FileManager.default.fileExists(atPath: url.path) {
                let source = try String(contentsOf: url, encoding: .utf8)
                let root = url.deletingLastPathComponent()
                let meridianURL = ["module.meridian", "\(stem).meridian"].lazy
                    .map { root.appendingPathComponent($0) }
                    .first { FileManager.default.fileExists(atPath: $0.path) }
                let manifest: ModuleManifest
                if let meridianURL {
                    do {
                        let meridianSource = try String(contentsOf: meridianURL, encoding: .utf8)
                        if let parsed = ModuleManifest.parse(
                            fromMeridianSource: meridianSource, file: meridianURL.lastPathComponent) {
                            manifest = parsed
                        } else {
                            trace.log(.symbols,
                                "warning: could not parse module manifest from \(meridianURL.lastPathComponent); using inferred id `\(stem)`")
                            manifest = ModuleManifest.inferred(id: stem)
                        }
                    } catch {
                        trace.log(.symbols,
                            "warning: could not read \(meridianURL.lastPathComponent) (\(error.localizedDescription)); using inferred manifest id `\(stem)`")
                        manifest = ModuleManifest.inferred(id: stem)
                    }
                } else {
                    manifest = ModuleManifest.inferred(id: stem)
                }
                return LocatedPackage(
                    rootURL: root,
                    merconfigURL: url,
                    meridianURL: meridianURL,
                    merconfigSource: source,
                    manifest: manifest
                )
            }
        }
        throw CompilerError.diagnostics([
            Diagnostic.unresolved(
                .moduleNotFound,
                target: name,
                among: moduleSearchPaths.map(\.lastPathComponent).sorted(),
                range: SourceRange(file: sourceFile, line: sourceLine, column: 1),
                noun: "module",
                help: "Add the module directory to `--module-path` or place it beside the importer as `\(stem)/module.merconfig`.")
        ])
    }

    private func parseMerconfig(at url: URL, file: String) throws -> MerConfigFile {
        let source = try String(contentsOf: url, encoding: .utf8)
        return try MerConfigParser(trace: trace, lexicon: lexicon).parse(source, file: file)
    }

    private func parseImportsFromMeridian(at url: URL?) -> [ModuleImportSpec] {
        guard let url else { return [] }
        let source: String
        do {
            source = try String(contentsOf: url, encoding: .utf8)
        } catch {
            trace.log(.symbols,
                "warning: could not read nested module imports from \(url.lastPathComponent) (\(error.localizedDescription)); skipping meridian frontmatter imports")
            return []
        }
        guard let frontmatter = Frontmatter.simpleEntries(source) else { return [] }
        return Self.parseImportList(frontmatter["imports"], file: url.lastPathComponent, line: 1)
    }

    private func parseImportsSection(from config: MerConfigFile, file: String) -> [ModuleImportSpec] {
        Self.parseImportsLines(config.imports, file: file)
    }

    public static func parseImportsLines(_ lines: [ModuleImportLine], file: String) -> [ModuleImportSpec] {
        lines.compactMap { line in
            parseImportStatement(line.text, file: file, line: line.sourceLine)
        }
    }

    public static func parseImportStatement(_ text: String, file: String, line: Int) -> ModuleImportSpec? {
        var work = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !work.isEmpty, !work.hasPrefix("#") else { return nil }
        if work.lowercased().hasPrefix("import module ") {
            work = String(work.dropFirst("import module ".count))
        } else if work.lowercased().hasPrefix("import ") {
            work = String(work.dropFirst("import ".count))
        } else {
            return nil
        }
        work = work.trimmingCharacters(in: .whitespacesAndNewlines)
        if work.hasSuffix(".") { work = String(work.dropLast()) }
        var alias: String?
        if let asRange = work.range(of: " as ", options: [.caseInsensitive, .backwards]) {
            alias = String(work[asRange.upperBound...]).trimmingCharacters(in: .whitespaces)
            work = String(work[..<asRange.lowerBound]).trimmingCharacters(in: .whitespaces)
        }
        guard !work.isEmpty else { return nil }
        return ModuleImportSpec(name: work, alias: alias, sourceFile: file, sourceLine: line)
    }

    public static func parseImportList(_ raw: String?, file: String, line: Int) -> [ModuleImportSpec] {
        guard let raw else { return [] }
        return raw.split(whereSeparator: { $0 == "," || $0 == "\n" }).compactMap { part in
            let token = String(part).trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: .init(charactersIn: "\"'"))
            guard !token.isEmpty else { return nil }
            return parseImportStatement("import \(token)", file: file, line: line)
        }
    }

    private func contentHash(_ source: String) throws -> String {
        try CanonicalJSON.sha256Hex(for: ["source": .string(source)])
    }

    /// Merge module configs under a local config. Local/importer declarations win
    /// unless they collide with a module `sealed` export.
    public static func mergeModuleConfigs(
        modules: [ResolvedModule],
        into local: MerConfigFile,
        importerFile: String,
        importerLine: Int
    ) throws -> MerConfigFile {
        var merged = MerConfigFile()
        var sealed: Set<String> = []
        for mod in modules {
            sealed.formUnion(mod.snapshot.sealed)
            merged = try merged.merging(mod.config)
        }
        let localNames = localSymbolNames(local)
        for name in localNames.intersection(sealed) {
            throw CompilerError.diagnostics([
                Diagnostic.error(
                    .moduleSealedCollision,
                    message: "importer redefines sealed export `\(name)`",
                    range: SourceRange(file: importerFile, line: importerLine, column: 1),
                    help: "Remove the local declaration or stop importing the module that seals `\(name)`.")
            ])
        }
        return try merged.merging(local)
    }

    private static func localSymbolNames(_ config: MerConfigFile) -> Set<String> {
        var names: Set<String> = []
        for stmt in config.vocabulary {
            switch stmt {
            case .kind(let k): names.insert(k.name.lowercased())
            case .phrase(let p): names.insert(p.pattern.displayText.lowercased())
            case .relation(let r): names.insert(r.verb.lowercased())
            case .verb(let v): names.insert(v.base.lowercased())
            case .definition(let d): names.insert(d.adjective.lowercased())
            default: break
            }
        }
        names.formUnion(config.tools.map { $0.methodName.lowercased() })
        names.formUnion(config.constants.map { $0.name.lowercased() })
        names.formUnion(config.instances.map { $0.name.lowercased() })
        return names
    }
}

/// A line harvested from `=== imports ===` in a `.merconfig`.
public struct ModuleImportLine: Sendable {
    public let text: String
    public let sourceLine: Int
    public init(text: String, sourceLine: Int) {
        self.text = text
        self.sourceLine = sourceLine
    }
}
