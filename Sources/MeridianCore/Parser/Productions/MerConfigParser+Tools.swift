import Foundation
import MeridianRuntime

// MARK: - Tools section

extension MerConfigParser {

    func parseToolCapturePolicy(
        _ raw: String,
        file: String,
        line: Int,
        toolID: String
    ) throws -> TraceCapturePolicy {
        let text = raw.trimmingCharacters(in: .whitespaces)
        let lower = text.lowercased()
        switch lower {
        case "full":
            return .full
        case "hash-only":
            return .hashOnly
        case "omitted":
            return .omitted
        default:
            break
        }
        let prefix = "redacted"
        guard lower.hasPrefix(prefix) else {
            try reportToolDiagnostic(
                message: "unknown capture policy `\(text)` for tool \"\(toolID)\"",
                range: SourceRange(file: file, line: line, column: 1),
                help: "Use `full`, `hash-only`, `omitted`, or `redacted (field1, field2)`."
            )
            return .full
        }
        let remainder = text.dropFirst(prefix.count).trimmingCharacters(in: .whitespaces)
        guard remainder.hasPrefix("("), remainder.hasSuffix(")") else {
            try reportToolDiagnostic(
                message: "redacted capture policy for tool \"\(toolID)\" must list fields",
                range: SourceRange(file: file, line: line, column: 1),
                help: "Use `redacted (field1, field2)`."
            )
            return .redacted([])
        }
        let fields = remainder.dropFirst().dropLast()
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return .redacted(fields)
    }

    func parseToolsSection(_ lines: [SourceLine], file: String) throws -> [ToolDeclaration] {
        var results: [ToolDeclaration] = []
        let content = lines.filter(\.isContent)
        var i = 0
        while i < content.count {
            let line = content[i]
            // Tool title: mixed case, no leading article, no "."
            // Followed by underline (=====)
            let nextIsUnderline = i + 1 < content.count && content[i+1].text.allSatisfy({ $0 == "=" })
            guard nextIsUnderline else { i += 1; continue }
            let displayName = line.text
            i += 2  // skip title + underline

            // Skip description lines (starting with "--")
            while i < content.count && content[i].text.hasPrefix("--") { i += 1 }

            // Method signature: "~ methodName(params) : ReturnType"
            guard i < content.count, content[i].text.hasPrefix("~") else {
                try reportToolDiagnostic(
                    message: "tool \"\(displayName)\" is missing a `~ methodName(params) : ReturnType` signature line",
                    range: SourceRange(file: file, line: line.number, column: 1),
                    help: "After the title underline and optional `--` description, declare `~ chargePayment(order: Order) : Order`.")
                i += 1
                continue
            }
            let signatureLine = content[i]
            let sig = signatureLine.text.dropFirst().trimmingCharacters(in: .whitespaces)
            var capturePolicy: TraceCapturePolicy?
            var k = i + 1
            while k < content.count, content[k].indent > signatureLine.indent {
                let optionLine = content[k].statement.trimmingCharacters(in: .whitespaces)
                if optionLine.lowercased().hasPrefix("capture:") {
                    let raw = optionLine.dropFirst("capture:".count).trimmingCharacters(in: .whitespaces)
                    capturePolicy = try parseToolCapturePolicy(
                        raw,
                        file: file,
                        line: content[k].number,
                        toolID: displayName
                    )
                }
                k += 1
            }
            if let tool = parseToolSignature(sig, displayName: displayName, sourceLine: line.number, sourceFile: file, capturePolicy: capturePolicy) {
                results.append(tool)
            } else {
                try reportToolDiagnostic(
                    message: "malformed tool signature for \"\(displayName)\": \"\(sig)\"",
                    range: SourceRange(file: file, line: content[i].number, column: 1),
                    help: "Use `~ methodName(param: Type, …) : ReturnType` with balanced parentheses.")
            }
            i = max(k, i + 1)
        }
        return results
    }

    func parseToolSignature(
        _ sig: String,
        displayName: String,
        sourceLine: Int,
        sourceFile: String,
        capturePolicy: TraceCapturePolicy?
    ) -> ToolDeclaration? {
        // "methodName(param: Type, ...) : ReturnType"
        guard let parenOpen = sig.firstIndex(of: "("),
              let parenClose = sig.lastIndex(of: ")") else { return nil }
        let methodName = String(sig[sig.startIndex ..< parenOpen]).trimmingCharacters(in: .whitespaces)
        let paramsStr  = String(sig[sig.index(after: parenOpen) ..< parenClose])
        var returnType = "Any"
        if let colonRange = sig[sig.index(after: parenClose)...].range(of: ":") {
            returnType = String(sig[sig.index(after: colonRange.lowerBound)...])
                .trimmingCharacters(in: .whitespaces)
        }
        let params = paramsStr.components(separatedBy: ",").compactMap { p -> ToolParameterAST? in
            let parts = p.trimmingCharacters(in: .whitespaces).components(separatedBy: ":")
            guard parts.count == 2 else { return nil }
            return ToolParameterAST(
                name: parts[0].trimmingCharacters(in: .whitespaces),
                type: parts[1].trimmingCharacters(in: .whitespaces)
            )
        }
        return ToolDeclaration(displayName: displayName, methodName: methodName,
                               parameters: params, returnType: returnType, sourceLine: sourceLine,
                               sourceFile: sourceFile, capturePolicy: capturePolicy)
    }
}
