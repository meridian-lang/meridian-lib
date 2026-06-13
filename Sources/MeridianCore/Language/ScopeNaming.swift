import Foundation

/// Canonical in-scope name key: lowercased, stripped to alphanumerics. Used to
/// compare workflow parameter / bind / loop-variable names regardless of
/// camelCase or spacing differences. Single source for the identical key
/// computation in `ASTToIR`, `SkillMigrator`, and `SkillDeviation`.
enum ScopeNaming {
    static func key(_ s: String) -> String {
        String(s.lowercased().unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }.map(Character.init))
    }
}
