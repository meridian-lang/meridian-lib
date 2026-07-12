import Foundation
import Testing

@Suite("Silent fallback audit")
struct SilentFallbackAuditTests {
    private struct AllowlistEntry {
        var path: String
        var pattern: String?
        var classification: String
        var rationale: String
        var userVisibleSignal: String
        var owningTest: String
        var explicitOptIn: String
    }

    private struct Hit {
        var path: String
        var line: Int
        var pattern: String
        var allowlistKey: String
        var text: String
    }

    private static let approvedClassifications: Set<String> = [
        "probe", "benchmark", "explicit-fallback", "parser-non-match", "internal-invariant"
    ]

    private static let knownClassifications: Set<String> = approvedClassifications.union([
        "test-default", "fix-target", "resolved"
    ])

    @Test("production silent fallback patterns are explicitly approved")
    func productionSilentFallbacksAreAllowlisted() throws {
        let root = repositoryRoot()
        let sources = root.appendingPathComponent("Sources")
        let allowlist = try parseAllowlist(
            root.appendingPathComponent("docs/coverage/SILENT_FALLBACK_ALLOWLIST.md")
        )
        let allowlistFailures = validateAllowlist(allowlist)
        let hits = try scanDirectory(at: sources, root: root, scope: "Sources")
        let hitFailures = hits.compactMap { hit -> String? in
            let matches = allowlist.filter { entry in
                entry.path == hit.path && entryMatches(entry, hit: hit)
            }
            guard let match = matches.first else {
                return "\(hit.path):\(hit.line): unallowlisted \(hit.pattern): \(hit.text)"
            }
            guard Self.approvedClassifications.contains(match.classification) else {
                return "\(hit.path):\(hit.line): \(hit.pattern) is classified as `\(match.classification)`, not an approved silent-path classification"
            }
            return nil
        }

        let failures = allowlistFailures + hitFailures
        #expect(failures.isEmpty, Comment(rawValue: failures.joined(separator: "\n")))
    }

    @Test("test harness silent trace defaults are explicitly approved")
    func testHarnessSilentTraceDefaultsAreAllowlisted() throws {
        let root = repositoryRoot()
        let tests = root.appendingPathComponent("Tests")
        let allowlist = try parseAllowlist(
            root.appendingPathComponent("docs/coverage/SILENT_FALLBACK_ALLOWLIST.md")
        )
        let hits = try scanDirectory(at: tests, root: root, scope: "Tests")
            .filter { $0.pattern == "traceCapture silent default" }
        let failures = hits.compactMap { hit -> String? in
            let matches = allowlist.filter { entry in
                entry.path == hit.path && entryMatches(entry, hit: hit)
            }
            guard let match = matches.first else {
                return "\(hit.path):\(hit.line): unallowlisted \(hit.pattern): \(hit.text)"
            }
            guard Self.approvedClassifications.contains(match.classification) else {
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

    private func scanDirectory(at directory: URL, root: URL, scope: String) throws -> [Hit] {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(at: directory, includingPropertiesForKeys: [.isRegularFileKey]) else {
            return []
        }

        var hits: [Hit] = []
        for case let url as URL in enumerator {
            guard url.pathExtension == "swift" else { continue }
            let relativePath = relative(url, to: root)
            if scope == "Tests", relativePath.hasSuffix("SilentFallbackAuditTests.swift") { continue }
            let lines = try String(contentsOf: url, encoding: .utf8).components(separatedBy: "\n")
            hits.append(contentsOf: scanLines(lines, relativePath: relativePath, scope: scope))
        }
        return hits.sorted {
            if $0.path != $1.path { return $0.path < $1.path }
            if $0.line != $1.line { return $0.line < $1.line }
            return $0.pattern < $1.pattern
        }
    }

    private func scanLines(_ lines: [String], relativePath: String, scope: String) -> [Hit] {
        var hits: [Hit] = []
        for (offset, rawLine) in lines.enumerated() {
            let line = offset + 1
            let trimmed = rawLine.trimmedForAudit

            if scope == "Sources" {
                if (rawLine.contains("trace: .silent()") || rawLine.contains("ParserTrace.silent()")
                    || (rawLine.contains(".silent()") && !rawLine.contains("?? .silent()")))
                    && !trimmed.hasPrefix("//") {
                    hits.append(Hit(path: relativePath, line: line, pattern: "silent trace",
                                    allowlistKey: ".silent()", text: trimmed))
                }
                if rawLine.contains("/* inline invoke:") {
                    hits.append(Hit(path: relativePath, line: line, pattern: "inline invoke placeholder",
                                    allowlistKey: "inline invoke", text: trimmed))
                }
                if rawLine.contains("code: .legacySemantic")
                    || rawLine.contains("DiagnosticCode.legacySemantic")
                    || rawLine.contains("code: .legacySyntax")
                    || rawLine.contains("DiagnosticCode.legacySyntax") {
                    hits.append(Hit(path: relativePath, line: line, pattern: "legacy syntax/semantic projection",
                                    allowlistKey: "legacySemantic", text: trimmed))
                }
                if rawLine.contains(#""a \(parameter.kind)""#) {
                    hits.append(Hit(path: relativePath, line: line, pattern: "invented invoke parameter",
                                    allowlistKey: #"a \(parameter.kind)"#, text: trimmed))
                }
                if rawLine.contains(#"name: "_unresolved""#)
                    && !trimmed.hasPrefix("//") && !trimmed.hasPrefix("///") {
                    hits.append(Hit(path: relativePath, line: line, pattern: "allow-fallback unresolved bind",
                                    allowlistKey: "_unresolved", text: trimmed))
                }
                if rawLine.contains("try? FileHandle") {
                    hits.append(Hit(path: relativePath, line: line, pattern: "try? FileHandle",
                                    allowlistKey: "try? FileHandle", text: trimmed))
                }
                if rawLine.range(of: #"try\?\s+.*\.write\("#, options: .regularExpression) != nil {
                    hits.append(Hit(path: relativePath, line: line, pattern: "try? write",
                                    allowlistKey: "try? write", text: trimmed))
                }
                if rawLine.range(of: #"try\?\s+.*\.close\("#, options: .regularExpression) != nil {
                    hits.append(Hit(path: relativePath, line: line, pattern: "try? close",
                                    allowlistKey: "try? close", text: trimmed))
                }
                if rawLine.contains("serialization_failed") {
                    hits.append(Hit(path: relativePath, line: line, pattern: "serialization_failed literal",
                                    allowlistKey: "serialization_failed", text: trimmed))
                }
                if rawLine.contains("traceCapture?.trace ?? .silent()") {
                    hits.append(Hit(path: relativePath, line: line, pattern: "traceCapture silent default",
                                    allowlistKey: "traceCapture", text: trimmed))
                }
                hits.append(contentsOf: catchSwallowHits(in: lines, at: offset, relativePath: relativePath))
            }

            if scope == "Tests", rawLine.contains("traceCapture?.trace ?? .silent()") {
                hits.append(Hit(path: relativePath, line: line, pattern: "traceCapture silent default",
                                allowlistKey: "traceCapture", text: trimmed))
            }
        }
        return hits
    }

    private func catchSwallowHits(in lines: [String], at offset: Int, relativePath: String) -> [Hit] {
        let line = offset + 1
        let trimmed = lines[offset].trimmedForAudit
        var hits: [Hit] = []

        let singleLinePatterns: [(String, String, String)] = [
            (#"catch\s*\{\s*\}"#, "empty catch swallow", "catch swallow"),
            (#"catch\s*\{\s*return\s*\}"#, "catch return swallow", "catch return"),
            (#"catch\s*\{\s*return\s*nil(\s|\})"#, "catch return nil swallow", "catch return"),
            (#"catch\s*\{\s*return\s*\[\s*\](\s|\})"#, "catch return empty array swallow", "catch return"),
            (#"catch\s*\{\s*continue(\s|\}|$)"#, "catch continue swallow", "catch continue"),
            (#"catch\s*\{\s*_\s*in"#, "catch wildcard swallow", "catch wildcard"),
        ]
        for (regex, pattern, key) in singleLinePatterns {
            if trimmed.range(of: regex, options: .regularExpression) != nil {
                hits.append(Hit(path: relativePath, line: line, pattern: pattern,
                                allowlistKey: key, text: trimmed))
            }
        }

        if trimmed.hasSuffix("catch {") || trimmed == "catch {" {
            let body = nextCatchBodyLine(in: lines, startingAt: offset + 1)
            if isSilentCatchReturn(body) || body == "continue" || body.hasPrefix("continue ") {
                hits.append(Hit(path: relativePath, line: line, pattern: "multiline catch swallow",
                                allowlistKey: "catch return", text: "\(trimmed) / \(body)"))
            } else if body.isEmpty {
                hits.append(Hit(path: relativePath, line: line, pattern: "multiline empty catch swallow",
                                allowlistKey: "catch swallow", text: trimmed))
            }
        }
        return hits
    }

    private func isSilentCatchReturn(_ body: String) -> Bool {
        if body == "return" { return true }
        if body == "return nil" || body.hasPrefix("return nil ") { return true }
        if body == "return []" || body.hasPrefix("return []") { return true }
        return false
    }

    private func nextCatchBodyLine(in lines: [String], startingAt index: Int) -> String {
        guard index < lines.count else { return "" }
        let next = lines[index].trimmedForAudit
        if next == "}" { return "" }
        return next
    }

    private func validateAllowlist(_ entries: [AllowlistEntry]) -> [String] {
        var failures: [String] = []
        for entry in entries {
            if entry.classification == "fix-target" {
                failures.append("\(entry.path): allowlist entry uses forbidden `fix-target` classification")
            }
            if !Self.knownClassifications.contains(entry.classification) {
                failures.append("\(entry.path): unknown classification `\(entry.classification)`")
            }
            if entry.rationale.isEmpty {
                failures.append("\(entry.path): missing rationale")
            }
            if entry.userVisibleSignal.isEmpty {
                failures.append("\(entry.path): missing user-visible signal")
            }
            if entry.owningTest.isEmpty {
                failures.append("\(entry.path): missing owning test")
            }
            if entry.explicitOptIn.isEmpty {
                failures.append("\(entry.path): missing explicit-opt-in flag")
            }
        }
        return failures
    }

    private func parseAllowlist(_ url: URL) throws -> [AllowlistEntry] {
        let source = try String(contentsOf: url, encoding: .utf8)
        return source.components(separatedBy: "\n").compactMap { line in
            guard line.trimmingCharacters(in: .whitespaces).hasPrefix("|") else { return nil }
            let cells = line.split(separator: "|", omittingEmptySubsequences: false).dropFirst().map {
                String($0).trimmingCharacters(in: .whitespaces)
            }
            guard cells.count >= 7 else { return nil }
            let pathCell = cells[0].replacingOccurrences(of: "`", with: "")
            guard pathCell.hasPrefix("Sources/") || pathCell.hasPrefix("Tests/") else { return nil }
            let patternCell = cells[1].replacingOccurrences(of: "`", with: "")
            let classification = cells[2].replacingOccurrences(of: "`", with: "")
            guard Self.knownClassifications.contains(classification) else { return nil }
            return AllowlistEntry(
                path: pathCell,
                pattern: patternCell == "—" || patternCell.isEmpty ? nil : patternCell,
                classification: classification,
                rationale: cells[3],
                userVisibleSignal: cells[4],
                owningTest: cells[5],
                explicitOptIn: cells[6]
            )
        }
    }

    private func entryMatches(_ entry: AllowlistEntry, hit: Hit) -> Bool {
        guard let pattern = entry.pattern else { return true }
        let normalizedPattern = pattern.auditNormalized
        let normalizedKey = hit.allowlistKey.auditNormalized
        let normalizedPatternText = hit.pattern.auditNormalized
        return normalizedPattern.contains(normalizedKey)
            || normalizedKey.contains(normalizedPattern)
            || normalizedPattern.contains(normalizedPatternText)
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
