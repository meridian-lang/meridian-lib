import Foundation
import Testing
@testable import MeridianCore
import MeridianRuntime

@Suite("Wave 6 synthetic corpora")
struct CorporaConformanceTests {
    struct Corpus {
        let name: String
        let root: URL
        let vocabulary: Compiler.VocabularyInput
        let rulebook: RulebookInput
        let moduleSearchPaths: [URL]
        let files: [URL]
    }

    static func repoRoot() -> URL {
        var url = URL(fileURLWithPath: #file)
        while !FileManager.default.fileExists(atPath: url.appendingPathComponent("Package.swift").path) {
            let parent = url.deletingLastPathComponent()
            if parent.path == url.path { break }
            url = parent
        }
        return url
    }

    /// Every corpus under `corpora/<name>/` that has a `skills/` directory of
    /// migrated `.meri` output. Add a new corpus here (and to
    /// `expectedFileCount` below) as soon as `generate-migration.swift` has
    /// produced its `skills/*.meri` — do not leave it out until "later"; a
    /// corpus outside this list is also outside the slow-integration typecheck
    /// gate in `GeneratedSwiftTypecheckSlowTests`; a `swiftc`-invalid emission
    /// can ship silently for as long as it stays unlisted (see IMPLEMENTATION_LOG.md's
    /// entry — that exact bug shipped in `incident/postmortem_render` while
    /// this list only covered `erp`/`procedures`).
    static func corpora() throws -> [Corpus] {
        try ["erp", "procedures", "incident", "etl", "governance", "clinical"].map { name in
            let root = repoRoot().appendingPathComponent("corpora").appendingPathComponent(name)
            let vocabURL = root.appendingPathComponent("\(name).merconfig")
            let ruleURL = root.appendingPathComponent("\(name).merrules")
            let skills = try FileManager.default.contentsOfDirectory(
                at: root.appendingPathComponent("skills"), includingPropertiesForKeys: nil)
                .filter { $0.pathExtension == "meri" }
            let files = (skills + [root.appendingPathComponent("RESOLVER.meri")])
                .sorted { $0.lastPathComponent < $1.lastPathComponent }
            return Corpus(
                name: name,
                root: root,
                vocabulary: .init(
                    name: name,
                    file: vocabURL.lastPathComponent,
                    source: try String(contentsOf: vocabURL, encoding: .utf8)),
                rulebook: .init(
                    name: name,
                    file: ruleURL.lastPathComponent,
                    source: try String(contentsOf: ruleURL, encoding: .utf8)),
                moduleSearchPaths: CorpusCompileSupport.moduleSearchPaths(forCorpus: name, root: root),
                files: files
            )
        }
    }

    /// Expected `skills/*.meri` + `RESOLVER.meri` file count per corpus. Wave 6
    /// started every corpus at 8 skills + RESOLVER (9); the Corpora Complexity
    /// & Coverage Expansion plan grows `erp`/`procedures` to 12 skills +
    /// RESOLVER (13) as their vocabulary/skill enrichment lands.
    /// `incident`/`etl`/`governance` are still at the original 8 + RESOLVER
    /// (9) — bump this when any of them grows further.
    static let expectedFileCount: [String: Int] = [
        "erp": 14,
        "procedures": 14,
        "incident": 10,
        "etl": 10,
        "governance": 10,
        "clinical": 10,
    ]

    @Test("every synthetic corpus is present and complete")
    func corporaPresent() throws {
        for corpus in try Self.corpora() {
            let expected = Self.expectedFileCount[corpus.name] ?? 9
            #expect(corpus.files.count == expected,
                    Comment(rawValue: "\(corpus.name) should have \(expected - 1) skills + RESOLVER"))
            #expect(FileManager.default.fileExists(atPath: corpus.root.appendingPathComponent("migration-deviations/README.md").path))
            #expect(FileManager.default.fileExists(atPath: corpus.root.appendingPathComponent("compile-outputs").path))
        }
    }

    @Test("every synthetic corpus skill compiles with no unresolved placeholders")
    func everySkillCompiles() throws {
        var failures: [String] = []
        for corpus in try Self.corpora() {
            for file in corpus.files {
                do {
                    let source = try String(contentsOf: file, encoding: .utf8)
                    let swift = try Compiler(options: Self.compilerOptions(for: corpus)).compile(
                        meridianSource: source,
                        meridianFile: file.lastPathComponent,
                        vocabularies: [corpus.vocabulary],
                        rulebooks: [corpus.rulebook]
                    )
                    if swift.contains("_unresolved") {
                        failures.append("\(corpus.name)/\(file.lastPathComponent): emitted _unresolved")
                    }
                    if swift.isEmpty {
                        failures.append("\(corpus.name)/\(file.lastPathComponent): emitted empty Swift")
                    }
                } catch {
                    failures.append("\(corpus.name)/\(file.lastPathComponent): \(error)")
                }
            }
        }
        #expect(failures.isEmpty,
                Comment(rawValue: "Synthetic corpus compile failures:\n" + failures.joined(separator: "\n")))
    }

    @Test("synthetic corpora exercise Wave 2-4 mechanisms")
    func mechanismCoverage() throws {
        var definitionCount = 0
        var relationCount = 0
        var verbCount = 0
        var tableCount = 0
        var quantifierCount = 0

        for corpus in try Self.corpora() {
            for file in corpus.files {
                let source = try String(contentsOf: file, encoding: .utf8)
                let (_, _, manifest) = try Compiler(options: Self.compilerOptions(for: corpus)).compileWithManifest(
                    meridianSource: source,
                    meridianFile: file.lastPathComponent,
                    vocabularies: [corpus.vocabulary],
                    rulebooks: [corpus.rulebook]
                )
                definitionCount += manifest.definitions.count
                relationCount += manifest.relations.count
                verbCount += manifest.verbs.count
                let hasTable = source.components(separatedBy: "\n")
                    .contains { $0.trimmingCharacters(in: .whitespaces).hasPrefix("|") }
                tableCount += hasTable ? 1 : 0
                quantifierCount += Self.quantifierHits(in: source)
            }
        }

        #expect(definitionCount >= 10)
        #expect(relationCount >= 6)
        #expect(verbCount >= 6)
        #expect(tableCount >= 4)
        #expect(quantifierCount >= 10)
    }

    @Test("flat rules/*.meridian fixtures compile with populated manifest rule entries")
    func rulesFixturesEmitManifestEntries() throws {
        var failures: [String] = []
        var sawBoundedPermission = false
        var sawAnyFixture = false
        for corpus in try Self.corpora() {
            let rulesDir = corpus.root.appendingPathComponent("rules")
            guard let files = try? FileManager.default.contentsOfDirectory(
                at: rulesDir, includingPropertiesForKeys: nil
            ).filter({ $0.pathExtension == "meridian" }), !files.isEmpty else { continue }
            for file in files.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
                sawAnyFixture = true
                do {
                    let source = try String(contentsOf: file, encoding: .utf8)
                    let (_, _, manifest) = try Compiler(options: Self.compilerOptions(for: corpus)).compileWithManifest(
                        meridianSource: source,
                        meridianFile: file.lastPathComponent,
                        vocabularies: [corpus.vocabulary],
                        rulebooks: [corpus.rulebook]
                    )
                    if manifest.rules.isEmpty {
                        failures.append("\(corpus.name)/\(file.lastPathComponent): manifest.rules is empty")
                    }
                    for r in manifest.rules {
                        if !r.executes {
                            failures.append("\(corpus.name)/\(file.lastPathComponent): rule did not execute: \(r.text)")
                        }
                        if r.bounded { sawBoundedPermission = true }
                    }
                } catch {
                    failures.append("\(corpus.name)/\(file.lastPathComponent): \(error)")
                }
            }
        }
        #expect(sawAnyFixture, Comment(rawValue: "expected at least one corpora/*/rules/*.meridian fixture"))
        #expect(failures.isEmpty,
                Comment(rawValue: "Flat rules fixture manifest failures:\n" + failures.joined(separator: "\n")))
        #expect(sawBoundedPermission,
                Comment(rawValue: "expected at least one bounded: true permission rule across rules/*.meridian fixtures"))
    }

    @Test("every emitted Swift file has no raw newline inside a single-line string literal")
    func emittedSwiftIsWellFormed() throws {
        var failures: [String] = []
        for (name, swift) in try compileAll() {
            let bad = unterminatedStringLiteralLines(in: swift)
            if !bad.isEmpty {
                failures.append("\(name): unterminated string literal at lines \(bad.map(String.init).joined(separator: ", "))")
            }
        }
        #expect(failures.isEmpty,
                Comment(rawValue: "Malformed generated Swift:\n" + failures.joined(separator: "\n")))
    }

    private static func compilerOptions(for corpus: Corpus,
                                        emitterOptions: SwiftEmitter.Options = .init()) -> Compiler.Options {
        CorpusCompileSupport.compilerOptions(
            moduleSearchPaths: corpus.moduleSearchPaths,
            emitterOptions: emitterOptions
        )
    }

    private static func quantifierHits(in source: String) -> Int {
        let lower = source.lowercased()
        return ["all ", "any ", "no ", "at least ", "at most ", "exactly "]
            .reduce(0) { $0 + lower.components(separatedBy: $1).count - 1 }
    }

    private func compileAll() throws -> [(name: String, swift: String)] {
        try Self.corpora().flatMap { corpus in
            try corpus.files.map { file in
                let source = try String(contentsOf: file, encoding: .utf8)
                let opts = Self.compilerOptions(
                    for: corpus,
                    emitterOptions: SwiftEmitter.Options(
                        namespaceEnum: IdentifierNaming.swiftTypeNameFromStem(file.deletingPathExtension().lastPathComponent))
                )
                let swift = try Compiler(options: opts).compile(
                    meridianSource: source,
                    meridianFile: file.lastPathComponent,
                    vocabularies: [corpus.vocabulary],
                    rulebooks: [corpus.rulebook]
                )
                return ("\(corpus.name)/\(file.lastPathComponent)", swift)
            }
        }
    }

    private func unterminatedStringLiteralLines(in source: String) -> [Int] {
        enum Mode { case normal, string, multiline, lineComment, blockComment }
        var mode: Mode = .normal
        var line = 1
        var stringStartLine = 0
        var flagged: [Int] = []
        let chars = Array(source)
        var i = 0

        func peek(_ ahead: Int) -> Character? {
            let j = i + ahead
            return j < chars.count ? chars[j] : nil
        }

        while i < chars.count {
            let c = chars[i]
            switch mode {
            case .normal:
                if c == "\n" { line += 1; i += 1 }
                else if c == "\"", peek(1) == "\"", peek(2) == "\"" { mode = .multiline; i += 3 }
                else if c == "\"" { mode = .string; stringStartLine = line; i += 1 }
                else if c == "/", peek(1) == "/" { mode = .lineComment; i += 2 }
                else if c == "/", peek(1) == "*" { mode = .blockComment; i += 2 }
                else { i += 1 }
            case .string:
                if c == "\\" { i += 2 }
                else if c == "\"" { mode = .normal; i += 1 }
                else if c == "\n" { flagged.append(stringStartLine); mode = .normal; line += 1; i += 1 }
                else { i += 1 }
            case .multiline:
                if c == "\"", peek(1) == "\"", peek(2) == "\"" { mode = .normal; i += 3 }
                else if c == "\n" { line += 1; i += 1 }
                else if c == "\\" { i += 2 }
                else { i += 1 }
            case .lineComment:
                if c == "\n" { mode = .normal; line += 1; i += 1 } else { i += 1 }
            case .blockComment:
                if c == "*", peek(1) == "/" { mode = .normal; i += 2 }
                else if c == "\n" { line += 1; i += 1 }
                else { i += 1 }
            }
        }
        return flagged
    }
}
