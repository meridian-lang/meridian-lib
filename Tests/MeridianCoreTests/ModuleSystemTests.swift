import Foundation
import Testing
@testable import MeridianCore

@Suite("Module system (Phase F / SEM-MOD-01)")
struct ModuleSystemTests {
    private var fixturesRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/modules")
    }

    @Test("import resolves shared module and merges vocabulary")
    func resolvesSharedModule() throws {
        let resolver = ModuleResolver(
            moduleSearchPaths: [fixturesRoot],
            anchorDirectory: fixturesRoot,
            trace: .silent()
        )
        let result = try resolver.resolve(imports: [
            ModuleImportSpec(name: "shared-domain", sourceFile: "skill.meridian", sourceLine: 1)
        ])
        #expect(result.modules.count == 1)
        #expect(result.modules[0].manifest.id == "shared-domain")
        #expect(result.lockfile.modules.count == 1)
        #expect(result.vocabularies.count == 1)
        let json1 = try result.lockfile.encodeJSON()
        let json2 = try result.lockfile.encodeJSON()
        #expect(json1 == json2)
    }

    @Test("alias import preserves module vocabulary under alias name")
    func aliasImport() throws {
        let spec = try #require(ModuleResolver.parseImportStatement(
            "import shared-domain as gov", file: "t.merconfig", line: 2))
        #expect(spec.name == "shared-domain")
        #expect(spec.alias == "gov")
    }

    @Test("cycle detection reports MER-MOD-002")
    func cycleDetection() throws {
        let resolver = ModuleResolver(
            moduleSearchPaths: [fixturesRoot],
            anchorDirectory: fixturesRoot,
            trace: .silent()
        )
        do {
            _ = try resolver.resolve(imports: [
                ModuleImportSpec(name: "cycle-a", sourceFile: "t.merconfig", sourceLine: 1)
            ])
            Issue.record("Expected cycle error")
        } catch let CompilerError.diagnostics(diags) {
            #expect(diags.contains { $0.code == .moduleImportCycle })
        }
    }

    @Test("missing module reports MER-MOD-001 via Diagnostic.unresolved")
    func missingModuleReportsMod001() throws {
        let resolver = ModuleResolver(
            moduleSearchPaths: [fixturesRoot],
            anchorDirectory: fixturesRoot,
            trace: .silent()
        )
        do {
            _ = try resolver.resolve(imports: [
                ModuleImportSpec(name: "no-such-module", sourceFile: "t.merconfig", sourceLine: 1)
            ])
            Issue.record("Expected module not found")
        } catch let CompilerError.diagnostics(diags) {
            #expect(diags.contains { $0.code == .moduleNotFound })
            #expect(diags.first?.message.contains("unknown module") == true)
        }
    }

    @Test("compile skill using imported shared domain")
    func compileWithSharedModule() throws {
        let cfg = """
        === vocabulary ===
        A review is a kind of thing.
        A review has a policy called the governing policy.
        """
        let mer = """
        ---
        imports: shared-domain
        vocabulary: local.merconfig
        ---
        To audit a review:
          complete.
        """
        let moduleRoot = fixturesRoot
        let compiler = Compiler(options: .init(
            trace: .silent(),
            moduleSearchPaths: [moduleRoot],
            anchorDirectory: moduleRoot
        ))
        let out = try compiler.compile(
            meridianSource: mer,
            meridianFile: "audit.meridian",
            vocabularies: [.init(name: "local", file: "local.merconfig", source: cfg)]
        )
        #expect(out.contains("struct AuditReview"))
        #expect(out.contains("Policy"))
    }

    @Test("internal module exports do not collide on the export surface")
    func internalModuleExportSurface() throws {
        let resolver = ModuleResolver(
            moduleSearchPaths: [fixturesRoot],
            anchorDirectory: fixturesRoot,
            trace: .silent()
        )
        let result = try resolver.resolve(imports: [
            ModuleImportSpec(name: "internal-domain", sourceFile: "t.merconfig", sourceLine: 1),
            ModuleImportSpec(name: "public-domain", sourceFile: "t.merconfig", sourceLine: 2),
        ])
        #expect(result.modules.count == 2)
        let internalMod = try #require(result.modules.first { $0.manifest.id == "internal-domain" })
        let publicMod = try #require(result.modules.first { $0.manifest.id == "public-domain" })
        #expect(internalMod.snapshot.visibility == .internal)
        #expect(publicMod.snapshot.visibility == .public)
        #expect(internalMod.snapshot.exportSurfaceNames().isEmpty)
        #expect(publicMod.snapshot.exportSurfaceNames().contains("customer"))
        #expect(internalMod.snapshot.collision(with: publicMod.snapshot) == nil)
    }

    @Test("compile skill can use vocabulary from an internal module import")
    func compileWithInternalModule() throws {
        let cfg = """
        === vocabulary ===
        A review is a kind of thing.
        """
        let mer = """
        ---
        imports: internal-domain
        vocabulary: local.merconfig
        ---
        To file an internal note:
          complete.
        """
        let compiler = Compiler(options: .init(
            trace: .silent(),
            moduleSearchPaths: [fixturesRoot],
            anchorDirectory: fixturesRoot
        ))
        let out = try compiler.compile(
            meridianSource: mer,
            meridianFile: "note.meridian",
            vocabularies: [.init(name: "local", file: "local.merconfig", source: cfg)]
        )
        #expect(out.contains("struct FileInternalNote"))
    }
}
