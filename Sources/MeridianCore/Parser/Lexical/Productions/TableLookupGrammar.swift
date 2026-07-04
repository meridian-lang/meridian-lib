import Foundation

/// `table-lookup` (`GrammarTable`, `.pegex`): `the <value column> corresponding
/// to the [<key column>] "<key>" in the <table>`.
///
/// No symbol table is required — this is a pure marker-shape production.
/// `correspondingToMarker` is located case-insensitively; `inTableMarker` is
/// located from the **back** of the string (plain, non-quote-aware
/// `range(of:options:.backwards)`, matching the pre-rewrite production exactly —
/// table names/keys aren't expected to contain nested quotes that would need
/// shielding here).
struct TableLookupGrammar {
    let lexicon: EnglishLexicon
    /// Recurses the full grammar for the key expression (`parse`, not `atom`) —
    /// matches the pre-rewrite behavior, which builds the key via `parse(keyText)`.
    let recurse: (String) -> ExpressionAST

    func parse(_ raw: String) -> ExpressionAST? {
        guard lexicon.hasLeadingArticle(raw) else { return nil }
        let body = lexicon.stripLeadingArticle(raw)
        let lookup = lexicon.grammar.tableLookup
        guard let corr = body.range(of: lookup.correspondingToMarker, options: [.caseInsensitive]),
              let inRange = body.range(of: lookup.inTableMarker, options: [.caseInsensitive, .backwards]),
              corr.upperBound < inRange.lowerBound else { return nil }

        let valueColumn = String(body[body.startIndex..<corr.lowerBound]).trimmingCharacters(in: .whitespaces)
        let keyPhrase = String(body[corr.upperBound..<inRange.lowerBound]).trimmingCharacters(in: .whitespaces)
        let tableName = String(body[inRange.upperBound...]).trimmingCharacters(in: .whitespaces)
        guard !valueColumn.isEmpty, !keyPhrase.isEmpty, !tableName.isEmpty else { return nil }

        let (keyColumn, keyText) = splitKeyPhrase(keyPhrase)
        guard !keyColumn.isEmpty, !keyText.isEmpty else { return nil }
        return .tableLookup(table: tableName, keyColumn: keyColumn, key: recurse(keyText), valueColumn: valueColumn)
    }

    private func splitKeyPhrase(_ keyPhrase: String) -> (column: String, key: String) {
        if let quote = keyPhrase.firstIndex(of: "\"") {
            let column = String(keyPhrase[keyPhrase.startIndex..<quote]).trimmingCharacters(in: .whitespaces)
            let key = String(keyPhrase[quote...]).trimmingCharacters(in: .whitespaces)
            return (column, key)
        }
        let parts = keyPhrase.split(separator: " ").map(String.init)
        guard parts.count > 1 else { return ("", keyPhrase) }
        return (parts.dropLast().joined(separator: " "), parts.last ?? "")
    }
}
