import Foundation
import MeridianRuntime

public struct AnaphoraResolver: Sendable {
    private let lexicon: EnglishLexicon

    public init(lexicon: EnglishLexicon = .default) {
        self.lexicon = lexicon
    }

    public func resolve(_ text: String, referents: [String], file: String = "", line: Int = 0) throws -> String {
        let markers = lexicon.anaphoraMarkers
        guard markers.contains(where: { containsWholeWord($0, in: text) }) else {
            return text
        }
        guard referents.count == 1, let referent = referents.last else {
            throw CompilerError.semanticError(
                message: "ambiguous anaphora in `\(text)`; spell out the referenced value",
                range: SourceRange(file: file, line: line, column: 1)
            )
        }
        var resolved = text
        for marker in markers {
            resolved = replaceWholeWord(marker, in: resolved, with: referent)
        }
        return resolved
    }

    private func containsWholeWord(_ needle: String, in haystack: String) -> Bool {
        replaceWholeWord(needle, in: haystack, with: "__MATCH__") != haystack
    }

    private func replaceWholeWord(_ needle: String, in haystack: String, with replacement: String) -> String {
        let pattern = "\\b" + NSRegularExpression.escapedPattern(for: needle) + "\\b"
        // Escaped literal pattern — compilation cannot fail; a failure is a bug.
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            preconditionFailure("internal: constant whole-word regex failed to compile: \(pattern)")
        }
        let range = NSRange(haystack.startIndex..<haystack.endIndex, in: haystack)
        return regex.stringByReplacingMatches(in: haystack, range: range, withTemplate: replacement)
    }
}
