import Foundation

/// Exported symbol names from a parsed module vocabulary, used for collision
/// detection and sealed-export enforcement during merge.
public struct ModuleSymbolSnapshot: Sendable, Equatable {
    public let moduleID: String
    public let visibility: ModuleVisibility
    public let kinds: Set<String>
    public let phrases: Set<String>
    public let tools: Set<String>
    public let constants: Set<String>
    public let instances: Set<String>
    public let relations: Set<String>
    public let verbs: Set<String>
    public let definitions: Set<String>
    public let sealed: Set<String>

    public init(
        moduleID: String,
        visibility: ModuleVisibility = .public,
        kinds: Set<String> = [],
        phrases: Set<String> = [],
        tools: Set<String> = [],
        constants: Set<String> = [],
        instances: Set<String> = [],
        relations: Set<String> = [],
        verbs: Set<String> = [],
        definitions: Set<String> = [],
        sealed: Set<String> = []
    ) {
        self.moduleID = moduleID
        self.visibility = visibility
        self.kinds = kinds
        self.phrases = phrases
        self.tools = tools
        self.constants = constants
        self.instances = instances
        self.relations = relations
        self.verbs = verbs
        self.definitions = definitions
        self.sealed = sealed
    }

    public static func build(from config: MerConfigFile, manifest: ModuleManifest) -> ModuleSymbolSnapshot {
        var kinds: Set<String> = []
        var phrases: Set<String> = []
        var relations: Set<String> = []
        var verbs: Set<String> = []
        var definitions: Set<String> = []
        for stmt in config.vocabulary {
            switch stmt {
            case .kind(let k):
                kinds.insert(k.name.lowercased())
            case .phrase(let p):
                phrases.insert(p.pattern.displayText.lowercased())
            case .relation(let r):
                relations.insert(r.verb.lowercased())
            case .verb(let v):
                verbs.insert(v.base.lowercased())
            case .definition(let d):
                definitions.insert(d.adjective.lowercased())
            default:
                break
            }
        }
        let tools = Set(config.tools.map { $0.methodName.lowercased() })
        let constants = Set(config.constants.map { $0.name.lowercased() })
        let instances = Set(config.instances.map { $0.name.lowercased() })
        return ModuleSymbolSnapshot(
            moduleID: manifest.id,
            visibility: manifest.visibility,
            kinds: kinds,
            phrases: phrases,
            tools: tools,
            constants: constants,
            instances: instances,
            relations: relations,
            verbs: verbs,
            definitions: definitions,
            sealed: manifest.sealedExports
        )
    }

    public func allExportedNames() -> Set<String> {
        kinds.union(phrases).union(tools).union(constants).union(instances)
            .union(relations).union(verbs).union(definitions)
    }

    /// Symbols that participate in cross-module export collision checks.
    /// `exports: internal` modules merge vocabulary for direct importers but
    /// do not publish symbols on the export surface.
    public func exportSurfaceNames() -> Set<String> {
        visibility == .public ? allExportedNames() : []
    }

    public func collision(with other: ModuleSymbolSnapshot) -> String? {
        for name in exportSurfaceNames().intersection(other.exportSurfaceNames()).sorted() {
            return name
        }
        return nil
    }
}
