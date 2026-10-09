import Foundation
import MeridianRuntime
import Testing
@testable import MeridianCore

enum VerbalizerTestSupport {
    struct Fixture: Sendable {
        let file: URL
        let vocabularies: [Compiler.VocabularyInput]
        let rulebooks: [RulebookInput]
        let moduleSearchPaths: [URL]

        init(file: URL, vocabularies: [Compiler.VocabularyInput], rulebooks: [RulebookInput],
             moduleSearchPaths: [URL] = []) {
            self.file = file
            self.vocabularies = vocabularies
            self.rulebooks = rulebooks
            self.moduleSearchPaths = moduleSearchPaths
        }

        var displayPath: String {
            file.path.replacingOccurrences(of: repositoryRoot().path + "/", with: "")
        }
    }

    static let baseVocabulary = """
    === vocabulary ===
    A user is a kind of thing.
    A page is a kind of thing.
    A page has a summary, which is String.
    A page has a status, which is String.
    A page has an owner, which is String.
    A page has a last reviewed, which is DateTime.
    A task is a kind of thing.
    A task has an assignee, which is String.
    A deal is a kind of thing.
    A deal has an amount, which is Number.
    A row is a kind of thing.
    A service is a kind of thing.
    A service has a text called the name.
    A service has a text called the status.
    A service is keyed by the name.
    Ownership relates one user to various pages.
    Ownership is read from the page's owner.
    The verb to own (it owns, it is owned) means the ownership relation.
    Assignment relates one user to one task.
    Assignment is read from the task's assignee.
    The verb to assign (it assigns, it is assigned) means the assignment relation.

    === constants ===
    The default threshold is 3.

    === tools ===
    Demo Tool
    =========
    ~ demoTool(value: Number) : String
    """

    static func repositoryRoot() -> URL {
        var url = URL(fileURLWithPath: #filePath)
        while !FileManager.default.fileExists(atPath: url.appendingPathComponent("Package.swift").path) {
            let parent = url.deletingLastPathComponent()
            if parent.path == url.path { break }
            url = parent
        }
        return url
    }

    static func compiler(moduleSearchPaths: [URL] = []) -> Compiler {
        Compiler(options: .init(moduleSearchPaths: moduleSearchPaths))
    }

    static func moduleSearchPaths(forCorpus corpus: String, root: URL) -> [URL] {
        switch corpus {
        case "governance":
            return [root.appendingPathComponent("modules")]
        default:
            return []
        }
    }

    static func baseVocabInput() -> Compiler.VocabularyInput {
        Compiler.VocabularyInput(name: "test", file: "test.merconfig", source: baseVocabulary)
    }

    static func sampleGbrainFixtures() throws -> [Fixture] {
        let root = repositoryRoot().appendingPathComponent("sample-gbrain")
        let vocab = try vocabularyInput(root.appendingPathComponent("brain.merconfig"), name: "brain")
        let rulebook = try rulebookInput(root.appendingPathComponent("brain.merrules"), name: "brain")
        let skillFiles = try sortedMeriFiles(in: root.appendingPathComponent("skills"))
        return (skillFiles + [root.appendingPathComponent("RESOLVER.meri")]).map {
            Fixture(file: $0, vocabularies: [vocab], rulebooks: [rulebook])
        }
    }

    static func corpusFixtures() throws -> [Fixture] {
        let corpora = repositoryRoot().appendingPathComponent("corpora")
        let names = try FileManager.default.contentsOfDirectory(at: corpora, includingPropertiesForKeys: nil)
            .filter(\.hasDirectoryPath)
            .sorted { $0.lastPathComponent < $1.lastPathComponent }

        var fixtures: [Fixture] = []
        for root in names {
            let corpus = root.lastPathComponent
            let vocab = try vocabularyInput(root.appendingPathComponent("\(corpus).merconfig"), name: corpus)
            let rulebook = try rulebookInput(root.appendingPathComponent("\(corpus).merrules"), name: corpus)
            let moduleSearchPaths = moduleSearchPaths(forCorpus: corpus, root: root)
            fixtures += try sortedMeriFiles(in: root.appendingPathComponent("skills")).map {
                Fixture(file: $0, vocabularies: [vocab], rulebooks: [rulebook],
                        moduleSearchPaths: moduleSearchPaths)
            }
            let resolver = root.appendingPathComponent("RESOLVER.meri")
            if FileManager.default.fileExists(atPath: resolver.path) {
                fixtures.append(Fixture(file: resolver, vocabularies: [vocab], rulebooks: [rulebook],
                                        moduleSearchPaths: moduleSearchPaths))
            }
        }
        return fixtures
    }

    static func compileFixture(_ fixture: Fixture, source: String) throws -> VerbalizerModel {
        try compiler(moduleSearchPaths: fixture.moduleSearchPaths).compile(Compiler.CompilationUnit(sources: [Compiler.SourceInput(source: source, file: fixture.file.lastPathComponent)], vocabularies: fixture.vocabularies, rulebooks: fixture.rulebooks))[fixture.file.lastPathComponent]!.model
    }

    static func canonicalRoundTrip(_ fixture: Fixture, source: String) throws -> (VerbalizerModel, String, VerbalizerModel) {
        try canonicalRoundTrip(
            source,
            vocabularies: fixture.vocabularies,
            rulebooks: fixture.rulebooks,
            file: fixture.file.lastPathComponent,
            moduleSearchPaths: fixture.moduleSearchPaths
        )
    }

    static func exampleFixtures() throws -> [Fixture] {
        let root = repositoryRoot().appendingPathComponent("examples")
        let vocabURL = root.appendingPathComponent("ecommerce.merconfig")
        let vocabularies = FileManager.default.fileExists(atPath: vocabURL.path)
            ? [try vocabularyInput(vocabURL, name: "ecommerce")]
            : []
        return try sortedMeriFiles(in: root).map {
            Fixture(file: $0, vocabularies: vocabularies, rulebooks: [])
        }
    }

    /// Skill examples under `examples/skill/` that declare their own vocabulary
    /// (e.g. `comprehensive_workflows.merconfig` for autonomy demos).
    /// Always attaches `skill.merrules` so section-role aliases match the CLI
    /// auto-discovery path used by `meridian explain`.
    static func skillExampleFixtures() throws -> [Fixture] {
        let root = repositoryRoot().appendingPathComponent("examples/skill")
        let defaultVocab = try vocabularyInput(
            root.appendingPathComponent("comprehensive_workflows.merconfig"),
            name: "comprehensive_workflows"
        )
        let rulebookURL = root.appendingPathComponent("skill.merrules")
        let rulebooks = FileManager.default.fileExists(atPath: rulebookURL.path)
            ? [try rulebookInput(rulebookURL, name: "skill")]
            : []
        return try sortedMeriFiles(in: root).map { file in
            let source = try String(contentsOf: file, encoding: .utf8)
            let vocabName = frontmatterValue(source, key: "vocabulary")
                ?? "comprehensive_workflows.merconfig"
            let vocabURL = root.appendingPathComponent(vocabName)
            let vocabularies = FileManager.default.fileExists(atPath: vocabURL.path)
                ? [try vocabularyInput(vocabURL, name: (vocabName as NSString).deletingPathExtension)]
                : [defaultVocab]
            return Fixture(file: file, vocabularies: vocabularies, rulebooks: rulebooks)
        }
    }

    private static func frontmatterValue(_ source: String, key: String) -> String? {
        guard source.hasPrefix("---") else { return nil }
        let lines = source.components(separatedBy: .newlines)
        guard lines.count > 1 else { return nil }
        for line in lines.dropFirst() {
            if line == "---" { break }
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("\(key):") else { continue }
            return trimmed.dropFirst(key.count + 1)
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return nil
    }

    static func canonicalRoundTrip(_ source: String, vocabularies: [Compiler.VocabularyInput] = [baseVocabInput()],
                                   rulebooks: [RulebookInput] = [], file: String = "test.meri",
                                   moduleSearchPaths: [URL] = []) throws -> (VerbalizerModel, String, VerbalizerModel) {
        let compiler = Self.compiler(moduleSearchPaths: moduleSearchPaths)
        let first = try compiler.compile(Compiler.CompilationUnit(sources: [Compiler.SourceInput(source: source, file: file)], vocabularies: vocabularies, rulebooks: rulebooks))[file]!.model
        let canonical = try Verbalizer(model: first).verbalize()
        let second = try compiler.compile(Compiler.CompilationUnit(sources: [Compiler.SourceInput(source: canonical, file: "canonical-\(file)")], vocabularies: vocabularies, rulebooks: rulebooks))["canonical-\(file)"]!.model
        return (first, canonical, second)
    }

    static func assertNoUnresolved(_ model: VerbalizerModel, context: String) {
        #expect(!IRWalker.hasUnresolved(in: model.workflows), Comment(rawValue: "\(context) produced _unresolved"))
        #expect(!model.workflows.isEmpty, Comment(rawValue: "\(context) produced no workflows"))
    }

    static func definitionInfosEqual(_ lhs: [LoweredDefinitionInfo], _ rhs: [LoweredDefinitionInfo]) -> Bool {
        guard lhs.count == rhs.count else { return false }
        return zip(lhs, rhs).allSatisfy { left, right in
            left.adjective == right.adjective
                && left.kind == right.kind
                && left.subjectVar == right.subjectVar
                && left.functionName == right.functionName
                && IREquality.structurallyEqual(left.body, right.body)
                && left.isInline == right.isInline
        }
    }

    static func firstInequalityHint(_ lhs: [IRWorkflow], _ rhs: [IRWorkflow]) -> String {
        guard lhs.count == rhs.count else {
            return "workflow count \(lhs.count) != \(rhs.count)"
        }
        for (index, pair) in zip(lhs, rhs).enumerated() {
            if !IREquality.structurallyEqual(pair.0, pair.1) {
                if !IREquality.identifiersEqual(pair.0.name, pair.1.name) {
                    return "workflow[\(index)] name \(pair.0.name) != \(pair.1.name)"
                }
                if !IREquality.identifiersEqual(pair.0.structName, pair.1.structName) {
                    return "workflow[\(index)] struct \(pair.0.structName) != \(pair.1.structName)"
                }
                if pair.0.parameters.count != pair.1.parameters.count
                    || zip(pair.0.parameters, pair.1.parameters).contains(where: { !IREquality.structurallyEqual($0, $1) }) {
                    return "workflow[\(index)] params \(pair.0.parameters) != \(pair.1.parameters)"
                }
                if pair.0.mode != pair.1.mode {
                    return "workflow[\(index)] mode \(pair.0.mode) != \(pair.1.mode)"
                }
                if pair.0.allowsDiscretion != pair.1.allowsDiscretion {
                    return "workflow[\(index)] allowsDiscretion \(pair.0.allowsDiscretion) != \(pair.1.allowsDiscretion)"
                }
                if pair.0.body.statements.count != pair.1.body.statements.count {
                    return "workflow[\(index)] statement count \(pair.0.body.statements.count) != \(pair.1.body.statements.count)"
                }
                for (statementIndex, statements) in zip(pair.0.body.statements, pair.1.body.statements).enumerated()
                    where !IREquality.structurallyEqual(statements.0, statements.1) {
                    return "workflow[\(index)] statement[\(statementIndex)] \(statements.0) != \(statements.1)"
                }
                return "workflow[\(index)] residual structural mismatch"
            }
        }
        return "semantic field mismatch; inspect canonical snippet"
    }

    static func snippet(_ text: String, limit: Int = 900) -> String {
        if text.count <= limit { return text }
        return String(text.prefix(limit)) + "\n..."
    }

    private static func vocabularyInput(_ url: URL, name: String) throws -> Compiler.VocabularyInput {
        Compiler.VocabularyInput(
            name: name,
            file: url.lastPathComponent,
            source: try String(contentsOf: url, encoding: .utf8)
        )
    }

    private static func rulebookInput(_ url: URL, name: String) throws -> RulebookInput {
        RulebookInput(
            name: name,
            file: url.lastPathComponent,
            source: try String(contentsOf: url, encoding: .utf8)
        )
    }

    private static func sortedMeriFiles(in directory: URL) throws -> [URL] {
        guard FileManager.default.fileExists(atPath: directory.path) else { return [] }
        return try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { ["meri", "meridian"].contains($0.pathExtension) }
            .sorted { $0.path < $1.path }
    }
}
