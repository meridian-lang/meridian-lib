struct ObjectKindExtractor {
    enum NoArticleFallback {
        case fullText
        case lastWord
    }

    let lexicon: EnglishLexicon

    func extract(from text: String, noArticleFallback: NoArticleFallback) -> String {
        let words = text.lowercased()
            .trimmingCharacters(in: .whitespaces)
            .components(separatedBy: " ")
            .filter { !$0.isEmpty }
        for (index, word) in words.enumerated() {
            if lexicon.grammar.nounPhraseDeterminers.contains(word), index + 1 < words.count {
                return words[(index + 1)...].joined(separator: " ")
            }
        }
        switch noArticleFallback {
        case .fullText:
            return words.joined(separator: " ")
        case .lastWord:
            return words.last ?? ""
        }
    }
}
