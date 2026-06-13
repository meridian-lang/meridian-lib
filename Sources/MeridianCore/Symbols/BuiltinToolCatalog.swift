/// The canonical set of tool IDs the Meridian runtime registers as built-ins.
///
/// `MeridianCore` cannot import `MeridianTools` (the dependency points the other
/// way), so this list is a hand-mirror of `MeridianTools.allToolIDs`. The guard
/// test `BuiltinToolCatalogTests` asserts the two stay in lockstep — if a tool
/// is added/removed in `MeridianTools`, that test fails until this list matches.
public enum BuiltinToolCatalog {
    public static let ids: [String] = [
        "http.get", "http.post", "http.put", "http.delete",
        "file.read", "file.write", "file.append",
        "json.parse", "json.stringify", "json.transform",
        "regex.match", "regex.replace",
        "shell.run",
        "mcp.call",
        "llm.chat",
        "llm.decide", "llm.judge",
        "validate.json_schema",
        "time.now", "time.format",
        "uuid.generate",
    ]

    public static let idSet: Set<String> = Set(ids)

    public static func contains(_ id: String) -> Bool { idSet.contains(id) }
}
