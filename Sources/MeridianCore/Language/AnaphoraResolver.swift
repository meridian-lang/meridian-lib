import Foundation
import MeridianRuntime

public struct AnaphoraResolver: Sendable {
    private let lexicon: EnglishLexicon

    public init(lexicon: EnglishLexicon = .default) {
        self.lexicon = lexicon
    }

    public func resolve(_ text: String, referents: [String], file: String = "", line: Int = 0) throws -> String {
        let markers = lexicon.anaphoraMarkers
        guard markers.contains(where: { WholeWordRegex.contains($0, in: text) }) else {
            return text
        }
        guard referents.count == 1, let referent = referents.last else {
            throw CompilerError.diagnostics([
                Diagnostic.error(
                    .ambiguousAnaphora,
                    message: "ambiguous anaphora in `\(text)`; spell out the referenced value",
                    range: SourceRange(file: file, line: line, column: 1),
                    help: "Replace the anaphoric marker with the explicit referent name.")
            ])
        }
        var resolved = text
        for marker in markers {
            resolved = WholeWordRegex.replace(resolved, of: marker, with: referent)
        }
        return resolved
    }
}
