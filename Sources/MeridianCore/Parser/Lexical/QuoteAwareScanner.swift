/// Quote-aware string scanning shared by the expression and statement parsers.
/// A "marker" (comparison cue, connector, …) found *inside* a double-quoted
/// substring must not match — otherwise a literal like `"is more than a hint"`
/// would be misread as a comparison. This is the single implementation of that
/// scan; callers pick case sensitivity.
enum QuoteAwareScanner {

    /// Range of the first occurrence of `marker` that lies outside any
    /// double-quoted span. When `caseInsensitive` is true both the haystack and
    /// the marker are lower-cased before scanning (the returned range indexes
    /// the lower-cased haystack, matching the historical statement-parser
    /// behavior). Single quotes are NOT string delimiters (possessives).
    static func rangeOfMarker(
        _ marker: String,
        in s: String,
        caseInsensitive: Bool = false
    ) -> Range<String.Index>? {
        let hay = caseInsensitive ? s.lowercased() : s
        let needle = caseInsensitive ? marker.lowercased() : marker
        var i = hay.startIndex
        var inString = false
        while i < hay.endIndex {
            let c = hay[i]
            if c == "\"" {
                inString.toggle()
                i = hay.index(after: i)
                continue
            }
            if !inString, hay[i...].hasPrefix(needle) {
                return i ..< hay.index(i, offsetBy: needle.count)
            }
            i = hay.index(after: i)
        }
        return nil
    }
}
