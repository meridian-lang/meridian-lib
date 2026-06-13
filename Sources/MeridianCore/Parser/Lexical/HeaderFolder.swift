/// Fold a (possibly multi-line) header that terminates in `:`. Both
/// `MerConfigParser` (phrase/workflow headers) and `MeridianParser` (workflow
/// headers) carry the same "keep appending deeper-indented continuation lines
/// until one ends in `:`" algorithm; this is the single source.
enum HeaderFolder {

    /// Starting at `i`, return the joined header text and the index of the first
    /// line after the header. Continuation lines are those with strictly greater
    /// indent than `lines[i]`; empty/comment lines are skipped. Folding stops
    /// after a line ending in `:` (or when the indent drops back to the header).
    static func collect(_ lines: [SourceLine], at i: Int) -> (text: String, nextIndex: Int) {
        var text = lines[i].statement
        if text.hasSuffix(":") { return (text, i + 1) }
        let headerIndent = lines[i].indent
        var j = i + 1
        while j < lines.count {
            let l = lines[j]
            if l.isEmpty || l.isComment { j += 1; continue }
            if l.indent > headerIndent {
                let part = l.statement
                text += " " + part
                j += 1
                if part.hasSuffix(":") { break }
            } else {
                break
            }
        }
        return (text, j)
    }
}
