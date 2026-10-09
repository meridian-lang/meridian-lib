import Foundation
@testable import MeridianCore

enum CorpusCompileSupport {
    static func moduleSearchPaths(forCorpus corpus: String, root: URL) -> [URL] {
        switch corpus {
        case "governance":
            return [root.appendingPathComponent("modules")]
        default:
            return []
        }
    }

    static func compilerOptions(moduleSearchPaths: [URL],
                                emitterOptions: SwiftEmitter.Options = .init()) -> Compiler.Options {
        Compiler.Options(
            emitterOptions: emitterOptions,
            moduleSearchPaths: moduleSearchPaths
        )
    }
}
