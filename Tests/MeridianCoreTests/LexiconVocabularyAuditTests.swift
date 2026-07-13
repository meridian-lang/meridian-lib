import Foundation
import Testing

@Suite("Lexicon vocabulary audit")
struct LexiconVocabularyAuditTests {
    private func repositoryRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    @Test("Parser/Lowering/Migration/Verbalizer do not reintroduce known banned surface hardcodings")
    func noBannedSurfaceHardcodings() throws {
        let root = repositoryRoot()
        let scopes = [
            "Sources/MeridianCore/Parser",
            "Sources/MeridianCore/Lowering",
            "Sources/MeridianCore/Migration",
            "Sources/MeridianCore/Verbalizer",
        ]
        let banned: [(name: String, regex: String, allowPathSubstrings: [String])] = [
            (
                "hasPrefix(\"the \")",
                #"hasPrefix\("the ""#,
                ["EnglishLexicon.swift", "FixedGrammar.swift", "LEXICON_VOCABULARY_ALLOWLIST"]
            ),
            (
                "leading token == \"the\"",
                #"lowercased\(\)\s*==\s*"the""#,
                ["EnglishLexicon.swift", "FixedGrammar.swift", "PegexSurfaceGrammar.swift"]
            ),
        ]

        var failures: [String] = []
        for scope in scopes {
            let dir = root.appendingPathComponent(scope)
            guard FileManager.default.fileExists(atPath: dir.path) else { continue }
            let enumerator = FileManager.default.enumerator(
                at: dir,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            )
            while let item = enumerator?.nextObject() as? URL {
                guard item.pathExtension == "swift" else { continue }
                let rel = item.path.replacingOccurrences(of: root.path + "/", with: "")
                let text = try String(contentsOf: item, encoding: .utf8)
                for (offset, line) in text.components(separatedBy: "\n").enumerated() {
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    if trimmed.hasPrefix("//") { continue }
                    for ban in banned {
                        guard line.range(of: ban.regex, options: .regularExpression) != nil else { continue }
                        if ban.allowPathSubstrings.contains(where: { rel.contains($0) }) { continue }
                        failures.append("\(rel):\(offset + 1): \(ban.name): \(trimmed)")
                    }
                    // Free-function shell fence in Migration (not lexicon.isShellFence).
                    if scope.contains("Migration"),
                       line.range(of: #"\bisShellFence\("#, options: .regularExpression) != nil,
                       !line.contains("lexicon.isShellFence"),
                       !line.contains("knowledge.lexicon.isShellFence") {
                        failures.append("\(rel):\(offset + 1): free isShellFence(: \(trimmed)")
                    }
                }
            }
        }

        #expect(failures.isEmpty, Comment(rawValue: failures.joined(separator: "\n")))
    }

    @Test("lexicon vocabulary allowlist doc exists")
    func allowlistDocExists() {
        let url = repositoryRoot().appendingPathComponent("docs/coverage/LEXICON_VOCABULARY_ALLOWLIST.md")
        #expect(FileManager.default.fileExists(atPath: url.path))
    }
}
