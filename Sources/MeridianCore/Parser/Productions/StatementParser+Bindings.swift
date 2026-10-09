import Foundation
import MeridianRuntime

// MARK: - Bind / invoke / emit / match / assert
//
// Value-side statement productions extracted from StatementParser for
// Phase 3 readability. Call sites in parseStatement remain on the
// orchestrator.

extension StatementParser {

    // MARK: - Bind value (invoke expression or literal)

    func parseBindValue(_ s: String, lines: [SourceLine], at i: Int) throws -> (ExpressionAST, Int) {
        if s.trimmingCharacters(in: .whitespaces).isEmpty {
            var j = i + 1
            while j < lines.count {
                let l = lines[j]
                if l.isEmpty || l.isComment { j += 1; continue }
                if l.statement.hasPrefix(codeBlockSentinelPrefix) {
                    return (exprParser.parseAtom(l.statement), j - i)
                }
                break
            }
        }

        // B3: "decide whether <question>" — routes to llm.decide at runtime.
        if s.lowercased().hasPrefix(lexicon.grammar.decideWhetherIntroducer) {
            let question = String(s.dropFirst(lexicon.grammar.decideWhetherIntroducer.count)).trimmingCharacters(in: .whitespaces)
            return (.decideWhether(question: question), 0)
        }

        // B6/B7: "decide using:" followed by an indented code-block sentinel.
        // Use parseAtom to decode the sentinel — this handles plain bodies
        // (.literal(.string)) and {{ expr }} interpolated bodies
        // (.interpolatedString) uniformly. Wrap both forms as .invoke so the
        // question argument can be any IRExpression (including interpolated).
        if s.lowercased() == lexicon.grammar.decideUsingMarker {
            var j = i + 1
            while j < lines.count {
                let l = lines[j]
                if l.isEmpty || l.isComment { j += 1; continue }
                if l.statement.hasPrefix(codeBlockSentinelPrefix) {
                    let questionExpr = exprParser.parseAtom(l.statement)
                    return (.invoke("llm.decide", [("question", questionExpr)]), j - i)
                }
                break
            }
            return (.invoke("llm.decide", [("question", .literal(.string("")))]), 0)
        }

        // B6: Sentinel used directly as a value expression (safety net for
        // future inline-fence handling; currently unreachable with normal source).
        if s.hasPrefix(codeBlockSentinelPrefix) {
            return (exprParser.parseAtom(s), 0)
        }

        if s.lowercased().hasPrefix(lexicon.grammar.statement.invokePrefix) {
            let (expr, extra) = parseInvokeExpr(s, lines: lines, at: i)
            return (expr, extra)
        }
        return (exprParser.parse(s), 0)
    }

    // MARK: - Invoke expression

    func parseInvokeExpr(_ s: String, lines: [SourceLine], at i: Int) -> (ExpressionAST, Int) {
        // "invoke {tool words} with {args}"  or multi-line
        var invText = s
        var extra = 0

        // Collect continuation lines for multi-line args
        let parentIndent = lines[i].indent
        var contLines: [SourceLine] = []
        var j = i + 1
        while j < lines.count {
            let l = lines[j]
            if l.isEmpty || l.isComment { j += 1; continue }
            if l.indent > parentIndent {
                contLines.append(l)
                j += 1
                extra += 1
            } else {
                break
            }
        }
        // Append continuation args to invText
        if !contLines.isEmpty {
            let contStr = contLines.map { $0.statement }.joined(separator: ", ")
            invText = invText.hasSuffix(",") ? invText + " " + contStr
                                             : invText + " " + contStr
        }

        return (buildInvokeExpr(invText), extra)
    }

    func buildInvokeExpr(_ s: String) -> ExpressionAST {
        let trace = ParserTrace.current
        // "invoke {tool name} with {k = v, k = v}"
        // Strip "invoke "
        trace.log(.statement, "buildInvokeExpr start: \(ParserTrace.short(s))")
        var rest = s
        if rest.lowercased().hasPrefix(lexicon.grammar.statement.invokePrefix) {
            rest = String(rest.dropFirst(lexicon.grammar.statement.invokePrefix.count))
        }
        trace.log(.statement, "buildInvokeExpr rest: \(ParserTrace.short(rest))")

        let toolName: String
        let args: [(String, ExpressionAST)]

        if let withRange = rest.range(of: lexicon.grammar.merconfig.withMarker, options: [.caseInsensitive]) {
            toolName = String(rest[rest.startIndex ..< withRange.lowerBound]).trimmingCharacters(in: .whitespaces)
            let argStr = String(rest[withRange.upperBound...]).trimmingCharacters(in: .whitespaces)
            trace.log(.statement, "buildInvokeExpr args: \(ParserTrace.short(argStr))")
            args = parseArgList(argStr)
        } else {
            toolName = rest.trimmingCharacters(in: .whitespaces)
            args = []
        }
        trace.log(.statement, "buildInvokeExpr tool: \(toolName) args=\(args.count)")

        // Resolve tool method name
        let methodName = symbols?.tool(fromWords: toolName)?.methodName ?? methodize(toolName)
        trace.log(.statement, "buildInvokeExpr method: \(methodName)")
        return .invoke(methodName, args)
    }

    func parseArgList(_ s: String) -> [(String, ExpressionAST)] {
        // "key = value, key = value, ..."
        // Split on commas not inside quotes
        let parts = splitArgs(s)
        return parts.compactMap { part -> (String, ExpressionAST)? in
            let p = part.trimmingCharacters(in: .whitespaces)
            guard let range = p.range(of: " = ") ?? p.range(of: "=") else { return nil }
            let key = String(p[p.startIndex ..< range.lowerBound]).trimmingCharacters(in: .whitespaces)
            let val = String(p[range.upperBound...]).trimmingCharacters(in: .whitespaces)
            ParserTrace.current.log(.statement, "parseArgList key=\(key) val=\(ParserTrace.short(val))")
            return (key, exprParser.parse(val))
        }
    }

    func splitArgs(_ s: String) -> [String] {
        var parts: [String] = []
        var current = ""
        var depth = 0
        var inString = false
        // Only double quotes delimit string literals here — single-quote
        // (apostrophe) is too common in possessives ("customer's email") to
        // treat as a string boundary.
        for c in s {
            if c == "\"" {
                inString.toggle()
                current.append(c)
                continue
            }
            if !inString {
                if c == "(" { depth += 1 }
                else if c == ")" { depth -= 1 }
                else if c == "," && depth == 0 {
                    parts.append(current.trimmingCharacters(in: .whitespaces))
                    current = ""
                    continue
                }
            }
            current.append(c)
        }
        if !current.trimmingCharacters(in: .whitespaces).isEmpty {
            parts.append(current.trimmingCharacters(in: .whitespaces))
        }
        return parts
    }

    // MARK: - Emit

    func parseEmit(_ lines: [SourceLine], at i: Int) throws -> (EmitStatementAST, Int) {
        let line = lines[i]
        let t = line.statement
        var rest = String(t.dropFirst(lexicon.grammar.statement.emitPrefix.count)).trimmingCharacters(in: .whitespaces)

        let eventID: String
        var extra = 0
        let parentIndent = line.indent

        // Collect any continuation lines (deeper indent) before deciding on eventID.
        // This handles both "emit X with arg = v" and "emit X with\n  arg = v,\n  ..."
        var contLines: [SourceLine] = []
        var j = i + 1
        while j < lines.count {
            let l = lines[j]
            if l.isEmpty || l.isComment { j += 1; continue }
            if l.indent > parentIndent { contLines.append(l); j += 1; extra += 1 }
            else { break }
        }

        // Normalise: append continuation into rest so we can find " with " cleanly
        if !contLines.isEmpty {
            let contStr = contLines.map(\.statement).joined(separator: ", ")
            if rest.hasSuffix(" with") {
                rest = rest + " " + contStr
            } else if rest.hasSuffix(",") {
                rest = rest + " " + contStr
            } else {
                rest = rest + contStr
            }
        }

        if let withRange = rest.range(of: lexicon.grammar.merconfig.withMarker, options: [.caseInsensitive]) {
            eventID = String(rest[rest.startIndex ..< withRange.lowerBound]).trimmingCharacters(in: .whitespaces)
            let argStr = String(rest[withRange.upperBound...]).trimmingCharacters(in: .whitespaces)
            let payload = parseArgList(argStr)
            return (EmitStatementAST(eventID: eventID, payload: payload, sourceLine: line.number), extra)
        } else {
            eventID = rest
            return (EmitStatementAST(eventID: eventID, payload: [], sourceLine: line.number), extra)
        }
    }

    // MARK: - Match branch (`branch on …:`)

    /// Parse `branch on <subject>:` followed by indented `pattern:` case arms
    /// and an optional sibling `otherwise:` default. Patterns are string
    /// literals, bare enum identifiers, or the verbalizer wildcard `anything`.
    func parseMatchBranch(_ lines: [SourceLine], at i: Int, sourceFile: String) throws -> (MatchBranchStatementAST, Int) {
        let line = lines[i]
        let t = line.statement
        let prefix = lexicon.grammar.statement.branchOnPrefix
        var subjectText = t
        if subjectText.lowercased().hasPrefix(prefix) {
            subjectText = String(subjectText.dropFirst(prefix.count))
        }
        if subjectText.hasSuffix(":") { subjectText = String(subjectText.dropLast()) }
        subjectText = subjectText.trimmingCharacters(in: .whitespaces)
        let subject = exprParser.parse(subjectText)

        let parentIndent = line.indent
        var cases: [MatchBranchCaseAST] = []
        var otherwiseBlock: ASTBlock? = nil
        var j = i + 1
        while j < lines.count {
            let l = lines[j]
            if l.isEmpty || l.isComment { j += 1; continue }
            if l.indent <= parentIndent { break }
            let header = l.statement
            guard header.hasSuffix(":") else {
                let label = header.trimmingCharacters(in: .whitespaces)
                let keywords = lexicon.grammar.statement
                let wildcardLabels = Array(keywords.matchBranchWildcardLabels)
                let wildcardRewrite = "\(keywords.matchBranchCanonicalWildcard):"
                let rewrite = label.isEmpty ? wildcardRewrite : "\(label):"
                let suggestion = Suggester().closest(label, among: wildcardLabels).map {
                    Suggestion(
                        replacement: "\($0):",
                        range: l.statementRange(file: sourceFile),
                        rationale: "did you mean \"\($0):\"?"
                    )
                }
                throw CompilerError.diagnostics([
                    Diagnostic.problem(
                        .matchBranchSyntax,
                        range: l.statementRange(file: sourceFile),
                        read: header,
                        as: "a match-branch arm",
                        but: "it is missing a trailing ':'",
                        expected: [
                            "`\"ready\":`",
                            "`\(wildcardRewrite)`",
                            "`\(keywords.matchOtherwiseLabel)`",
                        ],
                        rewrite: rewrite,
                        suggestions: suggestion.map { [$0] } ?? []
                    )
                ])
            }
            let label = String(header.dropLast()).trimmingCharacters(in: .whitespaces)
            let caseIndent = l.indent
            var bodyLines: [SourceLine] = []
            var k = j + 1
            while k < lines.count {
                let body = lines[k]
                if body.isEmpty || body.isComment { k += 1; continue }
                if body.indent > caseIndent { bodyLines.append(body); k += 1 }
                else { break }
            }
            let block = try parseBlock(bodyLines, sourceFile: sourceFile)
            let lowerLabel = label.lowercased()
            let keywords = lexicon.grammar.statement
            if lowerLabel == keywords.otherwiseKeyword {
                otherwiseBlock = block
            } else {
                cases.append(MatchBranchCaseAST(pattern: parseMatchPattern(label), block: block))
            }
            j = k
        }
        ParserTrace.current.log(.statement, "match branch @L\(line.number): \(cases.count) case arm(s), otherwise \(otherwiseBlock == nil ? "absent" : "present")")
        return (
            MatchBranchStatementAST(
                subject: subject,
                cases: cases,
                otherwiseBlock: otherwiseBlock,
                sourceLine: line.number
            ),
            j - i
        )
    }

    func parseMatchPattern(_ label: String) -> MatchPatternAST {
        let trimmed = label.trimmingCharacters(in: .whitespaces)
        let wildcards = lexicon.grammar.statement.matchBranchWildcardLabels
        if wildcards.contains(trimmed.lowercased()) || wildcards.contains(trimmed) {
            return .wildcard
        }
        if trimmed.hasPrefix("\""), trimmed.hasSuffix("\""), trimmed.count >= 2 {
            return .literal(exprParser.parse(trimmed))
        }
        return .enumValue(trimmed)
    }

    // MARK: - Assert with otherwise:

    /// `assert <condition> otherwise:` header, followed by an indented
    /// fallback block — `AssertStatementAST.otherwise` / `AssertIR.otherwiseAction`
    /// (cookbook: a blocking guard that records its fallback policy instead
    /// of throwing). Only fires when the line both starts with a declared
    /// assertion marker AND ends with the fixed `otherwise:` block-header
    /// suffix (`FixedGrammar.matchOtherwiseLabel`) — a bare `assert X.` or a
    /// suffix-conditional `... otherwise, ...` on the same line are handled
    /// by their own productions and must not be shadowed here.
    func parseAssertWithOtherwise(_ lines: [SourceLine], at i: Int, sourceFile: String) throws -> (AssertStatementAST, Int)? {
        let line = lines[i]
        let t = line.statement
        let lower = t.lowercased()
        guard let marker = lexicon.assertionMarkers.first(where: { lower.hasPrefix($0 + " ") }) else { return nil }
        let otherwiseLabel = lexicon.grammar.statement.matchOtherwiseLabel
        guard lower.hasSuffix(otherwiseLabel) else { return nil }

        let afterMarker = String(t.dropFirst(marker.count + 1))
        let condition = String(afterMarker.dropLast(otherwiseLabel.count)).trimmingCharacters(in: .whitespaces)
        guard !condition.isEmpty else { return nil }

        let parentIndent = line.indent
        var otherwiseLines: [SourceLine] = []
        var j = i + 1
        while j < lines.count {
            let l = lines[j]
            if l.isEmpty || l.isComment { j += 1; continue }
            if l.indent > parentIndent { otherwiseLines.append(l); j += 1 }
            else { break }
        }
        guard !otherwiseLines.isEmpty else { return nil }
        let otherwiseBlock = try parseBlock(otherwiseLines, sourceFile: sourceFile)

        return (AssertStatementAST(
            condition: exprParser.parse(condition),
            message: "Expected \(condition)",
            otherwise: otherwiseBlock,
            sourceLine: line.number
        ), j - i)
    }

}
