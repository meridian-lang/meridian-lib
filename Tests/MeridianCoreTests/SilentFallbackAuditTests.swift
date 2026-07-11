import Foundation
import Testing

@Suite("Silent fallback audit")
struct SilentFallbackAuditTests {
    private struct AllowlistEntry {
        var path: String
        var pattern: String?
        var classification: String
    }

    private struct Hit {
        var path: String
        var line: Int
        var pattern: String
        var allowlistKey: String
        var text: String
    }

    @Test("production silent fallback patterns are explicitly approved")
    func productionSilentFallbacksAreAllowlisted() throws {
        let root = repositoryRoot()
        let sources = root.appendingPathComponent("Sources")
        let allowlist = try parseAllowlist(
            root.appendingPathComponent("docs/coverage/SILENT_FALLBACK_ALLOWLIST.md")
        )
        let approved: Set<String> = [
            "probe", "benchmark", "explicit-fallback", "parser-non-match", "internal-invariant"
        ]

        let hits = try scanSources(at: sources, root: root)
        let failures = hits.compactMap { hit -> String? in
            let matches = allowlist.filter { entry in
                entry.path == hit.path && entryMatches(entry, hit: hit)
            }
            guard let match = matches.first else {
                return "\(hit.path):\(hit.line): unallowlisted \(hit.pattern): \(hit.text)"
            }
            guard approved.contains(match.classification) else {
                return "\(hit.path):\(hit.line): \(hit.pattern) is classified as `\(match.classification)`, not an approved silent-path classification"
            }
            return nil
        }

        #expect(failures.isEmpty, Comment(rawValue: failures.joined(separator: "\n")))
    }

    @Test("production code does not construct legacy CompilerError syntax/semantic errors")
    func legacyCompilerErrorConstructorsAreAbsent() throws {
        let root = repositoryRoot()
        let sources = root.appendingPathComponent("Sources")
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(at: sources, includingPropertiesForKeys: [.isRegularFileKey]) else {
            return
        }

        var failures: [String] = []
        for case let url as URL in enumerator {
            guard url.pathExtension == "swift" else { continue }
            let relativePath = relative(url, to: root)
            let source = try String(contentsOf: url, encoding: .utf8)
            for (offset, rawLine) in source.components(separatedBy: "\n").enumerated() {
                if rawLine.contains("CompilerError.semanticError(")
                    || rawLine.contains("CompilerError.syntaxError(") {
                    failures.append("\(relativePath):\(offset + 1): \(rawLine.trimmedForAudit)")
                }
            }
        }

        #expect(failures.isEmpty, Comment(rawValue: failures.joined(separator: "\n")))
    }

    private func repositoryRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func scanSources(at sources: URL, root: URL) throws -> [Hit] {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(at: sources, includingPropertiesForKeys: [.isRegularFileKey]) else {
            return []
        }

        var hits: [Hit] = []
        for case let url as URL in enumerator {
            guard url.pathExtension == "swift" else { continue }
            let relativePath = relative(url, to: root)
            let source = try String(contentsOf: url, encoding: .utf8)
            for (offset, rawLine) in source.components(separatedBy: "\n").enumerated() {
                let line = offset + 1
                if rawLine.contains("trace: .silent()") || rawLine.contains("ParserTrace.silent()") {
                    hits.append(Hit(path: relativePath, line: line, pattern: "silent trace", allowlistKey: ".silent()", text: rawLine.trimmedForAudit))
                }
                if rawLine.contains("/* inline invoke:") {
                    hits.append(Hit(path: relativePath, line: line, pattern: "inline invoke placeholder", allowlistKey: "inline invoke", text: rawLine.trimmedForAudit))
                }
                if rawLine.contains("code: .legacySemantic")
                    || rawLine.contains("DiagnosticCode.legacySemantic")
                    || rawLine.contains("code: .legacySyntax")
                    || rawLine.contains("DiagnosticCode.legacySyntax") {
                    hits.append(Hit(path: relativePath, line: line, pattern: "legacy syntax/semantic projection", allowlistKey: "legacySemantic", text: rawLine.trimmedForAudit))
                }
                if relativePath.hasPrefix("Sources/MeridianCLIKit/"),
                   rawLine.range(of: #"catch\s*\{\s*return\s*\}"#, options: .regularExpression) != nil {
                    hits.append(Hit(path: relativePath, line: line, pattern: "empty CLI catch swallow", allowlistKey: "catch return", text: rawLine.trimmedForAudit))
                }
                if rawLine.contains(#""a \(parameter.kind)""#) {
                    hits.append(Hit(path: relativePath, line: line, pattern: "invented invoke parameter", allowlistKey: #"a \(parameter.kind)"#, text: rawLine.trimmedForAudit))
                }
            }
        }
        return hits.sorted {
            if $0.path != $1.path { return $0.path < $1.path }
            if $0.line != $1.line { return $0.line < $1.line }
            return $0.pattern < $1.pattern
        }
    }

    private func parseAllowlist(_ url: URL) throws -> [AllowlistEntry] {
        let source = try String(contentsOf: url, encoding: .utf8)
        let known = Set([
            "probe", "benchmark", "test-default", "explicit-fallback",
            "parser-non-match", "internal-invariant", "fix-target", "resolved"
        ])
        return source.components(separatedBy: "\n").compactMap { line in
            guard line.trimmingCharacters(in: .whitespaces).hasPrefix("|") else { return nil }
            let spans = backtickSpans(in: line)
            guard spans.count >= 2, spans[0].hasPrefix("Sources/") else { return nil }
            if known.contains(spans[1]) {
                return AllowlistEntry(path: spans[0], pattern: nil, classification: spans[1])
            }
            guard spans.count >= 3, known.contains(spans[2]) else { return nil }
            return AllowlistEntry(path: spans[0], pattern: spans[1], classification: spans[2])
        }
    }

    private func backtickSpans(in line: String) -> [String] {
        var spans: [String] = []
        var rest = line[...]
        while let open = rest.firstIndex(of: "`") {
            let afterOpen = rest.index(after: open)
            guard let close = rest[afterOpen...].firstIndex(of: "`") else { break }
            spans.append(String(rest[afterOpen..<close]))
            rest = rest[rest.index(after: close)...]
        }
        return spans
    }

    private func entryMatches(_ entry: AllowlistEntry, hit: Hit) -> Bool {
        guard let pattern = entry.pattern else { return true }
        let normalizedPattern = pattern.auditNormalized
        return normalizedPattern.contains(hit.allowlistKey.auditNormalized)
    }

    private func relative(_ url: URL, to root: URL) -> String {
        let rootPath = root.path.hasSuffix("/") ? root.path : root.path + "/"
        guard url.path.hasPrefix(rootPath) else { return url.path }
        return String(url.path.dropFirst(rootPath.count))
    }
}

private extension String {
    var trimmedForAudit: String {
        trimmingCharacters(in: .whitespaces)
    }

    var auditNormalized: String {
        lowercased().filter { $0.isLetter || $0.isNumber }
    }
}
