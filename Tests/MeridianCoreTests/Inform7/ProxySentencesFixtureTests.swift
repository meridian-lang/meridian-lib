import Foundation
import Testing
@testable import MeridianCore

/// Wires `Fixtures/Trace/proxy-sentences.json` -- 31 sentences harvested
/// verbatim from `corpora/*/original-skills/**/SKILL.md` prose -- into the
/// actual grammar under test (8D gap closure). The fixture previously sat
/// completely unwired (and was, in fact, invalid JSON: two concatenated
/// top-level arrays from an earlier draft that never got cleaned up).
///
/// These are real-world proxy sentences, not synthetic test fixtures, so the
/// assertions here are deliberately scoped to the one invariant the fixture's
/// own `notes` repeatedly call out and that this workstream's grammar
/// expansion put at risk: narrative/statistical SKILL.md prose must never be
/// silently misinterpreted as `traceTemporal`/`traceStatistical` grammar.
@Suite("Proxy sentences fixture (8D)")
struct ProxySentencesFixtureTests {
    private struct ProxySentence: Decodable {
        let id: String
        let corpus: String
        let sourceFile: String
        let sentence: String
        let kind: String
        let expected: String
        let notes: String

        enum CodingKeys: String, CodingKey {
            case id, corpus, sentence, kind, expected, notes
            case sourceFile = "source_file"
        }
    }

    private static let fixtureURL: URL = {
        guard let url = Bundle.module.url(forResource: "proxy-sentences", withExtension: "json", subdirectory: "Fixtures/Trace") else {
            fatalError("missing Fixtures/Trace/proxy-sentences.json resource")
        }
        return url
    }()

    private static let entries: [ProxySentence] = {
        let data = try! Data(contentsOf: fixtureURL)
        return try! JSONDecoder().decode([ProxySentence].self, from: data)
    }()

    @Test("fixture is valid single-array JSON with 31 unique, well-formed entries")
    func fixtureSchemaIsValid() throws {
        let entries = Self.entries
        #expect(entries.count == 31)

        let ids = entries.map(\.id)
        #expect(Set(ids).count == ids.count, Comment(rawValue: "duplicate ids: \(ids)"))

        let validKinds: Set<String> = ["positive", "negative", "ambiguous", "causal-since"]
        for entry in entries {
            #expect(!entry.sentence.isEmpty, Comment(rawValue: "\(entry.id) has an empty sentence"))
            #expect(!entry.sourceFile.isEmpty, Comment(rawValue: "\(entry.id) has an empty source_file"))
            #expect(validKinds.contains(entry.kind), Comment(rawValue: "\(entry.id) has unknown kind `\(entry.kind)`"))
            #expect(
                entry.expected == "narrative" || entry.expected == "unique-parse"
                    || entry.expected == "value-temporal" || entry.expected.hasPrefix("diagnostic:"),
                Comment(rawValue: "\(entry.id) has unrecognized expected `\(entry.expected)`")
            )
        }
    }

    @Test("every `diagnostic:MER-xxx` expectation names a real, registered DiagnosticCode")
    func diagnosticExpectationsNameRealCodes() throws {
        let byID = DiagnosticCode.catalogByID
        for entry in Self.entries where entry.expected.hasPrefix("diagnostic:") {
            let code = String(entry.expected.dropFirst("diagnostic:".count))
            #expect(byID[code] != nil, Comment(rawValue: "\(entry.id) references unknown diagnostic code `\(code)`"))
        }
    }

    @Test("every cited corpus source_file still exists on disk")
    func citedSourceFilesExist() throws {
        let repoRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        for entry in Self.entries {
            let path = repoRoot
                .appendingPathComponent("corpora")
                .appendingPathComponent(entry.corpus)
                .appendingPathComponent(entry.sourceFile)
            #expect(FileManager.default.fileExists(atPath: path.path),
                    Comment(rawValue: "\(entry.id) cites a missing source file: \(path.path)"))
        }
    }

    @Test("narrative/statistical-adverb proxy sentences never get misparsed as trace-temporal or trace-statistical grammar")
    func narrativeSentencesStayNarrative() throws {
        let narrativeEntries = Self.entries.filter { $0.kind == "ambiguous" || $0.kind == "negative" }
        #expect(narrativeEntries.count == 20, Comment(rawValue: "expected 20 narrative-labeled entries, got \(narrativeEntries.count)"))

        for entry in narrativeEntries {
            let parsed = ExpressionParser().parse(entry.sentence)
            switch parsed {
            case .traceTemporal, .traceStatistical:
                Issue.record("`\(entry.id)` (\(entry.notes)) was misparsed as trace grammar: \(parsed)")
            default:
                break
            }
        }
    }
}
