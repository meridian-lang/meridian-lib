import Foundation
import MeridianRuntime

// MARK: - RulebookParser
//
// Hand-written, line-oriented recursive-descent parser for `.merrules` files,
// mirroring `MerConfigParser`'s section + indent style (no PegexBuilder).
//
// File shape:
//
//   === desugar ===
//
//   rule "arrow-conditional":
//     match: If {c} -> {a}
//     rewrite: if {c}, {a}.
//
//   rule "report-emit" (priority 10):
//     match: Report: {m}
//     lowers to: emit "skill.report" with message = {m}.
//
//   === sections ===
//
//   section "Contract" -> invariants
//   section "Guarantees", "Contract & Guarantees" -> invariants
//   section "When To Use" -> applicability
//
//   === conventions ===
//
//   after writing a page that mentions an entity:
//     create a back-link from the entity to the page.
//
// `match:` / `rewrite:` / `lowers to:` may be inline or on indented follow-on
// lines. Conventions are Inform-style `before/after/check/instead of/carry
// out/report` rules parsed by the existing `InformRulebookParser`.

public struct RulebookParser {

    public let trace: ParserTrace

    public init(trace: ParserTrace = .shared) {
        self.trace = trace
    }

    public func parse(_ source: String, file: String = "") throws -> Rulebook {
        let token = trace.push(.rulebook, "RulebookParser.parse(\(file))")
        defer { trace.pop(token) }

        let lines = IndentTokenizer().tokenize(source, file: file, trace: trace)

        // Split into sections by `=== name ===` headers (same convention as
        // merconfig). Lines before the first header are ignored.
        var sectionRanges: [(name: String, lines: [SourceLine])] = []
        var currentSection: String? = nil
        var currentLines: [SourceLine] = []
        for line in lines {
            if let section = sectionName(line.text) {
                if let name = currentSection { sectionRanges.append((name, currentLines)) }
                currentSection = section
                currentLines = []
            } else if currentSection != nil {
                currentLines.append(line)
            }
        }
        if let name = currentSection { sectionRanges.append((name, currentLines)) }

        var desugars: [DesugarRule] = []
        var sectionRoles: [SectionRoleRule] = []
        var conventionLines: [RuleAST] = []
        var triggerWords: [TriggerWordRule] = []

        for (section, body) in sectionRanges {
            switch section {
            case "desugar", "desugars", "idioms":
                desugars += try parseDesugarSection(body, file: file)
            case "sections", "section-roles", "section roles":
                sectionRoles += try parseSectionRolesSection(body, file: file)
            case "conventions", "behavior", "behaviour":
                conventionLines += parseConventionsSection(body)
            case "triggers", "trigger-words", "trigger words":
                triggerWords += try parseTriggersSection(body, file: file)
            default:
                throw CompilerError.diagnostics([
                    Diagnostic.unresolved(
                        .rulebookSectionUnknown,
                        target: section,
                        among: ["desugar", "sections", "conventions", "triggers"],
                        range: SourceRange(file: file, line: body.first?.number ?? 1, column: 1),
                        noun: "rulebook section",
                        help: "Use one of: `=== desugar ===`, `=== sections ===`, `=== conventions ===`, `=== triggers ===`.")
                ])
            }
        }

        var conventions: [RulebookRule] = []
        let convParser = InformRulebookParser()
        for rule in conventionLines {
            if let parsed = convParser.parse(rule) {
                conventions.append(parsed)
            } else {
                throw CompilerError.diagnostics([
                    Diagnostic.structural(
                        .unparseableRule,
                        message: "unparseable convention rule",
                        range: SourceRange(file: file, line: rule.sourceLine, column: 1),
                        help: "Use an Inform-style phase prefix: `before …:`, `after …:`, `check …:`, `instead of …:`, `carry out …:`, or `report …:`.")
                ])
            }
        }
        conventions.sort { lhs, rhs in
            if lhs.phase.rawValue == rhs.phase.rawValue {
                return lhs.sourceLine < rhs.sourceLine
            }
            return lhs.phase.rawValue < rhs.phase.rawValue
        }
        trace.log(.rulebook, "parsed \(desugars.count) desugar, \(sectionRoles.count) section-role, \(conventions.count) convention, \(triggerWords.count) trigger-word rule(s)")
        return Rulebook(desugars: desugars, sectionRoles: sectionRoles,
                        conventions: conventions, triggerWords: triggerWords)
    }

    // MARK: - Section header detection

    private func sectionName(_ text: String) -> String? {
        let t = text.trimmingCharacters(in: .whitespaces)
        guard t.hasPrefix("===") && t.hasSuffix("===") else { return nil }
        if t.allSatisfy({ $0 == "=" }) { return nil }
        let inner = t.dropFirst(3).dropLast(3)
            .trimmingCharacters(in: .whitespaces)
            .lowercased()
        return inner.isEmpty ? nil : inner
    }

    // MARK: - Desugar section

    private func parseDesugarSection(_ lines: [SourceLine], file: String) throws -> [DesugarRule] {
        var results: [DesugarRule] = []
        let content = lines.filter(\.isContent)
        var i = 0
        while i < content.count {
            let line = content[i]
            let t = line.statement
            guard t.lowercased().hasPrefix("rule ") else { i += 1; continue }

            let (name, priority) = parseRuleHeader(t)
            var matchText: String? = nil
            var rewriteText: String? = nil
            var targetsPrimitive = false

            // Header may carry an inline `match:` etc., but normally the fields
            // are on indented follow-on lines.
            let headerIndent = line.indent
            var j = i + 1
            while j < content.count {
                let l = content[j]
                if l.indent <= headerIndent { break }
                let body = l.statement
                let lower = body.lowercased()
                if lower.hasPrefix("match:") {
                    matchText = String(body.dropFirst("match:".count)).trimmingCharacters(in: .whitespaces)
                } else if lower.hasPrefix("rewrite:") {
                    rewriteText = String(body.dropFirst("rewrite:".count)).trimmingCharacters(in: .whitespaces)
                } else if lower.hasPrefix("lowers to:") {
                    rewriteText = String(body.dropFirst("lowers to:".count)).trimmingCharacters(in: .whitespaces)
                    targetsPrimitive = true
                }
                j += 1
            }

            guard let m = matchText, let r = rewriteText, !m.isEmpty, !r.isEmpty else {
                throw CompilerError.diagnostics([
                    Diagnostic.structural(
                        .malformedRulebookEntry,
                        message: "rulebook desugar rule \(name.isEmpty ? "<unnamed>" : "\"\(name)\"") needs both `match:` and `rewrite:`/`lowers to:`",
                        range: SourceRange(file: file, line: line.number, column: 1),
                        help: "Add indented `match:` and `rewrite:` (or `lowers to:`) lines under the rule header.")
                ])
            }
            results.append(DesugarRule(
                name: name,
                priority: priority,
                match: RulebookParser.tokenizeMatch(m),
                rewrite: r,
                targetsPrimitive: targetsPrimitive,
                sourceLine: line.number
            ))
            trace.log(.rulebook, "desugar \"\(name)\" prio=\(priority): \(m) ⇒ \(r)")
            i = j
        }
        return results
    }

    /// `rule "name":` or `rule "name" (priority 10):`
    private func parseRuleHeader(_ t: String) -> (name: String, priority: Int) {
        var rest = String(t.dropFirst("rule ".count)).trimmingCharacters(in: .whitespaces)
        var name = ""
        if rest.hasPrefix("\"") , let close = rest.dropFirst().firstIndex(of: "\"") {
            name = String(rest[rest.index(after: rest.startIndex)..<close])
            rest = String(rest[rest.index(after: close)...]).trimmingCharacters(in: .whitespaces)
        }
        var priority = 0
        if let pr = rest.range(of: "priority", options: .caseInsensitive) {
            let after = rest[pr.upperBound...]
            let digits = after.drop(while: { !$0.isNumber }).prefix(while: { $0.isNumber })
            priority = Int(String(digits)) ?? 0
        }
        return (name, priority)
    }

    /// Split a `match:` template into literal/hole tokens. `{name}` is a hole;
    /// everything else is literal text (whitespace-trimmed at the edges).
    static func tokenizeMatch(_ template: String) -> [RuleToken] {
        var tokens: [RuleToken] = []
        var literal = ""
        var i = template.startIndex
        while i < template.endIndex {
            let c = template[i]
            if c == "{", let close = template[i...].firstIndex(of: "}") {
                if !literal.isEmpty { tokens.append(.literal(literal)); literal = "" }
                let name = String(template[template.index(after: i)..<close])
                    .trimmingCharacters(in: .whitespaces)
                tokens.append(.hole(name))
                i = template.index(after: close)
            } else {
                literal.append(c)
                i = template.index(after: i)
            }
        }
        if !literal.isEmpty { tokens.append(.literal(literal)) }
        return tokens
    }

    // MARK: - Section-role section

    private func parseSectionRolesSection(_ lines: [SourceLine], file: String) throws -> [SectionRoleRule] {
        var results: [SectionRoleRule] = []
        for line in lines.filter(\.isContent) {
            let t = line.statement
            guard t.lowercased().hasPrefix("section ") else { continue }
            guard let arrow = t.range(of: "->") else {
                throw CompilerError.diagnostics([
                    Diagnostic.structural(
                        .malformedRulebookEntry,
                        message: "rulebook section rule needs `-> <role>`: \(t)",
                        range: SourceRange(file: file, line: line.number, column: 1),
                        help: "Write `section \"Heading\" -> <role>` where <role> is a recognized section role.")
                ])
            }
            let aliasPart = String(t[t.index(t.startIndex, offsetBy: "section ".count)..<arrow.lowerBound])
            let roleName = String(t[arrow.upperBound...])
                .trimmingCharacters(in: .whitespaces)
                .lowercased()
            guard let role = SkillSectionRole(rawValue: roleName) else {
                throw CompilerError.diagnostics([
                    Diagnostic.error(
                        .malformedRulebookEntry,
                        message: "unknown section role `\(roleName)` (expected one of: \(SkillSectionRole.allCases.map(\.rawValue).joined(separator: ", ")))",
                        range: SourceRange(file: file, line: line.number, column: 1),
                        help: "Use one of the recognized section roles after `->`.")
                ])
            }
            // One rule may declare several comma-separated aliases.
            for rawAlias in splitQuotedList(aliasPart) {
                results.append(SectionRoleRule(
                    alias: Rulebook.normalizeHeading(rawAlias),
                    role: role,
                    sourceLine: line.number
                ))
            }
        }
        return results
    }

    /// Split `"Contract", "Guarantees"` into `["Contract", "Guarantees"]`,
    /// stripping the surrounding quotes.
    private func splitQuotedList(_ s: String) -> [String] {
        var items: [String] = []
        var current = ""
        var inString = false
        for c in s {
            if c == "\"" { inString.toggle(); continue }
            if c == "," && !inString {
                let trimmed = current.trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty { items.append(trimmed) }
                current = ""
                continue
            }
            current.append(c)
        }
        let trimmed = current.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty { items.append(trimmed) }
        return items
    }

    // MARK: - Triggers section

    /// Parse `=== triggers ===` lines of the form `<kind>: word1, word2, …`,
    /// where `<kind>` is a `TriggerKind` raw value (`schedule`/`ambient`/
    /// `event`/`keyword`). Each comma-separated word becomes a `TriggerWordRule`
    /// that adds to the built-in classification set for that kind.
    private func parseTriggersSection(_ lines: [SourceLine], file: String) throws -> [TriggerWordRule] {
        var results: [TriggerWordRule] = []
        for line in lines.filter(\.isContent) {
            let t = line.statement
            guard let colon = t.firstIndex(of: ":") else {
                throw CompilerError.diagnostics([
                    Diagnostic.structural(
                        .malformedRulebookEntry,
                        message: "rulebook trigger rule needs `<kind>: <words>`: \(t)",
                        range: SourceRange(file: file, line: line.number, column: 1),
                        help: "Write `<schedule|ambient|event|keyword>: word1, word2, …`.")
                ])
            }
            let kindName = String(t[..<colon]).trimmingCharacters(in: .whitespaces).lowercased()
            guard let kind = TriggerKind(rawValue: kindName) else {
                throw CompilerError.diagnostics([
                    Diagnostic.error(
                        .malformedRulebookEntry,
                        message: "unknown trigger kind `\(kindName)` (expected one of: \(TriggerKind.allCases.map(\.rawValue).joined(separator: ", ")))",
                        range: SourceRange(file: file, line: line.number, column: 1),
                        help: "Use one of: schedule, ambient, event, keyword.")
                ])
            }
            let wordsPart = String(t[t.index(after: colon)...])
            for raw in wordsPart.split(separator: ",") {
                let word = raw.trimmingCharacters(in: .whitespaces).lowercased()
                if !word.isEmpty {
                    results.append(TriggerWordRule(kind: kind, word: word, sourceLine: line.number))
                }
            }
        }
        return results
    }

    // MARK: - Conventions section

    /// Collect Inform-style behavioral rules. Each rule may span continuation
    /// lines indented deeper than its header; they are folded into one RuleAST
    /// so `InformRulebookParser` sees `before …: <body>`.
    private func parseConventionsSection(_ lines: [SourceLine]) -> [RuleAST] {
        var results: [RuleAST] = []
        let content = lines.filter(\.isContent)
        var i = 0
        while i < content.count {
            let line = content[i]
            var text = line.statement
            let headerIndent = line.indent
            var j = i + 1
            // Fold deeper-indented continuation lines (the rule body after the colon).
            while j < content.count, content[j].indent > headerIndent {
                text += " " + content[j].statement
                j += 1
            }
            results.append(RuleAST(text: text, sourceLine: line.number))
            i = j
        }
        return results
    }
}
