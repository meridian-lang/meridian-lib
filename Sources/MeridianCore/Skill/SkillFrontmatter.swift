import Foundation

// MARK: - SkillFrontmatter
//
// A typed projection over the raw `FileMetadataAST` frontmatter bag for files
// authored in the SKILL.md style. The raw bag is always preserved (`raw`) so
// nothing is lost; this struct just surfaces the keys the compiler and manifest
// care about with the right shape (scalars vs. lists).
//
// Multi-valued keys (YAML block sequences / inline `[a, b]` / block scalars)
// are packed by `MeridianParser` into a single value string joined by
// `frontmatterListSeparator`. `list(_:)` unpacks them, tolerating both newline
// and comma delimiters so authors can use either YAML or inline comma style.

public struct SkillFrontmatter: Sendable {
    public let raw: FileMetadataAST

    public init(_ raw: FileMetadataAST?) {
        self.raw = raw ?? FileMetadataAST(entries: [])
    }

    // MARK: Scalars

    public var name: String?          { scalar("name") }
    public var description: String?   { scalar("description") }
    public var goal: String?          { scalar("goal") }
    public var version: String?       { scalar("version") }
    public var promptVersion: String? { scalar("prompt_version") ?? scalar("prompt-version") }
    public var priority: String?      { scalar("priority") }
    public var brainFirst: String?    { scalar("brain_first") ?? scalar("brain-first") }
    public var writesPages: String?   { scalar("writes_pages") ?? scalar("writes-pages") }

    // MARK: Lists

    public var parameters: [String] { list("parameters") }
    public var vocabulary: [String] { list("vocabulary") }
    public var rulebooks:  [String] { list("rulebook") + list("rulebooks") }
    public var tools:      [String] { list("tools") + list("tools_required") + list("tools-required") }
    public var triggers:   [String] { list("triggers") }
    public var writesTo:   [String] { list("writes_to") + list("writes-to") }
    public var whenToUse:  [String] { list("when_to_use") + list("when-to-use") }

    /// Keys to surface under `meridian_skill` in the manifest. Order-preserving,
    /// de-duplicated by key. Values keep their packed (newline-joined) form.
    public var manifestEntries: [(key: String, value: String)] {
        let interesting: Set<String> = [
            "name", "description", "goal", "version", "prompt_version", "prompt-version",
            "priority", "brain_first", "brain-first", "writes_pages", "writes-pages",
            "writes_to", "writes-to", "triggers", "tools", "tools_required", "tools-required",
            "when_to_use", "when-to-use",
        ]
        var seen: Set<String> = []
        var out: [(key: String, value: String)] = []
        for entry in raw.entries {
            let norm = entry.key.lowercased().replacingOccurrences(of: "-", with: "_")
            guard interesting.contains(entry.key.lowercased()) || interesting.contains(norm) else { continue }
            guard !seen.contains(norm) else { continue }
            seen.insert(norm)
            out.append((key: norm, value: entry.value))
        }
        return out
    }

    // MARK: Helpers

    private func scalar(_ key: String) -> String? {
        guard let v = raw[key]?.trimmingCharacters(in: .whitespacesAndNewlines), !v.isEmpty else { return nil }
        return v
    }

    private func list(_ key: String) -> [String] {
        guard let v = raw[key] else { return [] }
        return v.split(whereSeparator: { $0 == "\n" || $0 == "," })
            .map { $0.trimmingCharacters(in: .whitespaces).trimmingCharacters(in: .init(charactersIn: "\"'")) }
            .filter { !$0.isEmpty }
    }
}
