import Foundation

public enum GrammarDocumentation {
    public static func markdownReference(lexicon: EnglishLexicon = .default) -> String {
        PegexSurfaceGrammar(lexicon: lexicon).table.markdownReference()
    }
}
