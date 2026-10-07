import Foundation
import Testing
@testable import MeridianCore
@testable import MeridianRuntime

@Suite("Documentation parity")
struct DocumentationParityTests {

    private func repositoryRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private static let numberedDocs: [Int] = Array(1 ... 22) + [24]

    private static let activeDocRoots: [String] = [
        "docs",
        "README.md",
        "AGENTS.md",
        "corpora/GENERATING_A_CORPUS.md",
    ]

    private static let allowedBrokenModuleLinkPaths: Set<String> = [
        "IMPLEMENTATION_LOG.md",
        ".ai/implementation-log-archive",
    ]

    @Test("active docs do not link to nonexistent docs/22_MODULES.md")
    func noStaleModulesDocLinks() throws {
        let root = repositoryRoot()
        var offenders: [String] = []
        for rel in Self.activeDocRoots {
            let url = root.appendingPathComponent(rel)
            if rel.hasSuffix(".md") {
                try scanFile(url, relativeTo: root, offenders: &offenders)
            } else {
                try scanDirectory(url, relativeTo: root, offenders: &offenders)
            }
        }
        #expect(offenders.isEmpty,
                Comment(rawValue: offenders.sorted().joined(separator: "\n")))
    }

    @Test("docs/README.md does not mark Wave 9 as in progress")
    func docsIndexWave9Status() throws {
        let text = try String(
            contentsOf: repositoryRoot().appendingPathComponent("docs/README.md"),
            encoding: .utf8
        )
        let lower = text.lowercased()
        let wave9Range = lower.range(of: "wave 9")
        let inProgressRange = lower.range(of: "in progress")
        if let wave9Range, let inProgressRange {
            let distance = abs(wave9Range.lowerBound.utf16Offset(in: lower)
                - inProgressRange.lowerBound.utf16Offset(in: lower))
            #expect(distance > 120,
                    Comment(rawValue: "docs/README.md pairs Wave 9 with in-progress status"))
        }
    }

    @Test("docs/06_RUNTIME.md documents 31 event kinds including violated")
    func runtimeEventKindCount() throws {
        let text = try String(
            contentsOf: repositoryRoot().appendingPathComponent("docs/06_RUNTIME.md"),
            encoding: .utf8
        )
        #expect(text.contains("31 event kinds"))
        #expect(text.contains("case violated"))
        #expect(text.contains("branch.end"))
    }

    @Test("numbered docs 01-22 plus 24 exist and appear in docs/README.md reading-order table")
    func numberedDocsIndexed() throws {
        let root = repositoryRoot()
        let index = try String(
            contentsOf: root.appendingPathComponent("docs/README.md"),
            encoding: .utf8
        )
        var missingFiles: [String] = []
        var missingIndex: [String] = []
        for n in Self.numberedDocs {
            let prefix = String(format: "%02d_", n)
            let docsDir = root.appendingPathComponent("docs")
            let matches = try FileManager.default.contentsOfDirectory(atPath: docsDir.path)
                .filter { $0.hasPrefix(prefix) && $0.hasSuffix(".md") }
            guard let filename = matches.first else {
                missingFiles.append(prefix)
                continue
            }
            let stem = (filename as NSString).deletingPathExtension
            if !index.contains("\(stem).md") && !index.contains("(\(stem).md)") {
                missingIndex.append(filename)
            }
        }
        #expect(missingFiles.isEmpty,
                Comment(rawValue: "missing numbered docs: \(missingFiles)"))
        #expect(missingIndex.isEmpty,
                Comment(rawValue: "docs/README.md missing index entries: \(missingIndex)"))
    }

    private func scanDirectory(_ url: URL, relativeTo root: URL, offenders: inout [String]) throws {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: url,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return }
        for case let fileURL as URL in enumerator {
            guard fileURL.pathExtension == "md" else { continue }
            try scanFile(fileURL, relativeTo: root, offenders: &offenders)
        }
    }

    private func scanFile(_ url: URL, relativeTo root: URL, offenders: inout [String]) throws {
        let rel = url.path.replacingOccurrences(of: root.path + "/", with: "")
        if Self.allowedBrokenModuleLinkPaths.contains(where: { rel.hasPrefix($0) }) {
            return
        }
        let text = try String(contentsOf: url, encoding: .utf8)
        if text.contains("22_MODULES.md") {
            offenders.append("\(rel): references docs/22_MODULES.md (use 22_MODULES_AND_IMPORTS.md)")
        }
    }
}
