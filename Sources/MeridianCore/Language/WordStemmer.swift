import Foundation

/// Lightweight English tokenisation + morphological stemming shared by the
/// rule and convention matchers. Both need to compare an action phrase against
/// a workflow name by overlapping *stems* (so `orders`/`ordered`/`ordering`
/// collapse onto `order`); this is the single implementation. The match
/// *thresholds* stay with each caller — only the mechanics are shared.
enum WordStemmer {

    /// Split on non-alphanumerics, lower-case, and drop stop-words.
    static func tokenize(_ s: String, stopwords: Set<String>) -> [String] {
        s.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty && !stopwords.contains($0) }
    }

    /// Generate simple morphological stems for an English word (plural, past
    /// tense, progressive), always including the original so exact matches work.
    static func stems(of word: String) -> [String] {
        var out: [String] = [word]
        let lower = word.lowercased()
        if lower.hasSuffix("ies") && lower.count > 4 {
            out.append(String(lower.dropLast(3)) + "y")
        } else if lower.hasSuffix("es") && lower.count > 3 {
            out.append(String(lower.dropLast(2)))
        } else if lower.hasSuffix("s") && lower.count > 2 {
            out.append(String(lower.dropLast()))
        }
        if lower.hasSuffix("ed") && lower.count > 3 {
            out.append(String(lower.dropLast(2)))
            out.append(String(lower.dropLast()))
        }
        if lower.hasSuffix("ing") && lower.count > 4 {
            out.append(String(lower.dropLast(3)))
            out.append(String(lower.dropLast(3)) + "e")
        }
        return out
    }

    /// The stem set of a phrase: every token's stems, de-duplicated.
    static func stemSet(_ s: String, stopwords: Set<String>) -> Set<String> {
        Set(tokenize(s, stopwords: stopwords).flatMap { stems(of: $0) })
    }
}
