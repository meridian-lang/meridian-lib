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
                ambiguousDiagnostic(text: text, referents: referents, file: file, line: line)
            ])
        }
        var resolved = text
        for marker in markers {
            resolved = WholeWordRegex.replace(resolved, of: marker, with: referent)
        }
        return resolved
    }

    /// Build the canonical MER3014 diagnostic, listing in-scope bind referents
    /// when more than one (or none) could match an anaphoric marker.
    public func ambiguousDiagnostic(text: String, referents: [String],
                                    file: String = "", line: Int = 0) -> Diagnostic {
        var notes: [DiagnosticNote] = []
        if referents.isEmpty {
            notes.append(DiagnosticNote("no bind referents are in scope"))
        } else {
            notes.append(DiagnosticNote("possible referents: \(referents.joined(separator: ", "))"))
        }
        return Diagnostic.error(
            .ambiguousAnaphora,
            message: "ambiguous anaphora in `\(text)`; spell out the referenced value",
            range: SourceRange(file: file, line: line, column: 1),
            notes: notes,
            help: "Replace the anaphoric marker with the explicit referent name.")
    }
}
