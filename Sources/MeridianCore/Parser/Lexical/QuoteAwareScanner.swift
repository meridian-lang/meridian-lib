/// Quote-aware string scanning shared by the expression and statement parsers.
/// A "marker" (comparison cue, connector, …) found *inside* a double-quoted
/// substring must not match — otherwise a literal like `"is more than a hint"`
/// would be misread as a comparison. This is the single implementation of that
/// scan; callers pick case sensitivity.
enum QuoteAwareScanner {

    /// Range of the first occurrence of `marker` that lies outside any
    /// double-quoted span. When `caseInsensitive` is true matching lower-cases
    /// each candidate slice, but the returned range still indexes the original
    /// string. Single quotes are NOT string delimiters (possessives).
    static func rangeOfMarker(
        _ marker: String,
        in s: String,
        caseInsensitive: Bool = false
    ) -> Range<String.Index>? {
        let needle = caseInsensitive ? marker.lowercased() : marker
        var i = s.startIndex
        var inString = false
        while i < s.endIndex {
            let c = s[i]
            if c == "\"" {
                inString.toggle()
                i = s.index(after: i)
                continue
            }
            if !inString {
                if caseInsensitive {
                    let candidate = s[i...]
                    if candidate.lowercased().hasPrefix(needle) {
                        return i ..< s.index(i, offsetBy: marker.count)
                    }
                } else if s[i...].hasPrefix(needle) {
                    return i ..< s.index(i, offsetBy: marker.count)
                }
            }
            i = s.index(after: i)
        }
        return nil
    }
}
