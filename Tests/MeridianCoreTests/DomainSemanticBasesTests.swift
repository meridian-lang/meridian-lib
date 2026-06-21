import Testing
import Foundation
@testable import MeridianCore
import MeridianRuntime

// MARK: - Domain semantic bases
//
// `A foo is a kind of <base>` should lower the kind protocol to inherit from
// the matching `Meridian<Base>` runtime protocol. These tests exercise every
// supported base in one-line vocabulary fixtures so a regression in
// `DomainEmitter.parentProtocol` surfaces with a precise failure message
// (rather than getting buried inside a 200-line corpus golden).

@Suite("Domain semantic bases — kind-of mapping")
struct DomainSemanticBasesTests {

    /// Compile a minimal one-kind-one-workflow program against the supplied
    /// `kind of <base>` line. The probe kind is given a single own property
    /// so the `<KindName>Kind` protocol is emitted (otherwise the leaf-elide
    /// rule would skip it and the test would be checking nothing).
    private func compileForBase(_ base: BuiltinSemanticBase) throws -> String {
        let baseName = base.rawValue
        let kindNoun = base == .root ? "widget" : "\(baseName) widget"
        let article = "A"
        let kindLine = "\(article) \(kindNoun) is a kind of \(baseName)."
        let propLine = "\(article) \(kindNoun) has a label, which is a String."
        let cfg = """
        === vocabulary ===
        \(kindLine)
        \(propLine)

        === tools ===
        """
        let mer = """
        ---
        name: kind of \(baseName) demo
        vocabulary: probe.merconfig
        ---
        To probe a \(kindNoun):
          complete.
        """
        let opts = Compiler.Options(
            emitterOptions: SwiftEmitter.Options(includeTimestamp: false, emitSourceLineComments: false)
        )
        return try Compiler(options: opts).compile(
            meridianSource: mer,
            meridianFile: "probe.meridian",
            merconfigSource: cfg,
            merconfigFile: "probe.merconfig"
        )
    }

    /// Generated kind-protocol name for a "<adjective> widget" kind, e.g.
    /// `event widget` → `EventWidgetKind`.
    private func protocolName(for base: BuiltinSemanticBase) -> String {
        let kindNoun = base == .root ? "widget" : "\(base.rawValue) widget"
        return "\(IdentifierNaming.pascalCaseFromSpaces(kindNoun))Kind"
    }

    @Test(
        "each semantic base maps to its Meridian<Base> protocol",
        arguments: BuiltinSemanticBase.allCases
    )
    func semanticBaseLowersToRuntimeProtocol(base: BuiltinSemanticBase) throws {
        let swift = try compileForBase(base)
        let proto = protocolName(for: base)
        let expected = base.runtimeProtocolName
        #expect(
            swift.contains("public protocol \(proto): \(expected) {"),
            Comment(rawValue: "expected `\(proto): \(expected)` in:\n\(swift)")
        )
        #expect(
            swift.contains("public struct \(String(proto.dropLast(4))): \(proto) {"),
            Comment(rawValue: "expected struct conforming to \(proto) in:\n\(swift)")
        )
    }

    @Test("semantic-base enum owns root and protocol naming")
    func semanticBaseEnumOwnsRootAndProtocolNaming() {
        #expect(BuiltinSemanticBase.root == .thing)
        #expect(BuiltinSemanticBase.isRoot(BuiltinSemanticBase.root.rawValue))
        #expect(BuiltinSemanticBase.runtimeProtocolName(for: BuiltinSemanticBase.root.rawValue) == BuiltinSemanticBase.root.runtimeProtocolName)
    }

    @Test("scalar parents still collapse to typealias (no protocol/struct)")
    func scalarParentsStillTypealias() throws {
        let cfg = """
        === vocabulary ===
        A label is a kind of String.
        A score is a kind of Number.
        A pointer is a kind of Reference.

        === tools ===
        """
        let mer = """
        ---
        name: scalar probe
        vocabulary: probe.merconfig
        ---
        To probe a label:
          complete.
        """
        let opts = Compiler.Options(
            emitterOptions: SwiftEmitter.Options(includeTimestamp: false, emitSourceLineComments: false)
        )
        let swift = try Compiler(options: opts).compile(
            meridianSource: mer,
            meridianFile: "probe.meridian",
            merconfigSource: cfg,
            merconfigFile: "probe.merconfig"
        )
        #expect(swift.contains("public typealias Label = String"))
        #expect(swift.contains("public typealias Score = Decimal"))
        #expect(swift.contains("public typealias Pointer = String"))
        #expect(!swift.contains("public protocol LabelKind"))
        #expect(!swift.contains("public protocol ScoreKind"))
        #expect(!swift.contains("public protocol PointerKind"))
    }

    @Test("chained kinds inherit through `<Parent>Kind` (not the runtime base)")
    func chainedKindsInheritThroughKindProtocol() throws {
        let cfg = """
        === vocabulary ===
        A person is a kind of thing.
        A customer is a kind of person.
        A person has a name, which is a String.
        A customer has a tier, which is a String.

        === tools ===
        """
        let mer = """
        ---
        name: chain probe
        vocabulary: probe.merconfig
        ---
        To probe a customer:
          complete.
        """
        let opts = Compiler.Options(
            emitterOptions: SwiftEmitter.Options(includeTimestamp: false, emitSourceLineComments: false)
        )
        let swift = try Compiler(options: opts).compile(
            meridianSource: mer,
            meridianFile: "probe.meridian",
            merconfigSource: cfg,
            merconfigFile: "probe.merconfig"
        )
        #expect(swift.contains("public protocol PersonKind: \(BuiltinSemanticBase.root.runtimeProtocolName) {"))
        #expect(swift.contains("public protocol CustomerKind: PersonKind {"))
        #expect(swift.contains("public struct Customer: CustomerKind {"))
    }

    // MARK: - Empty-protocol elision

    @Test("leaf kinds with no own properties skip the `<KindName>Kind` protocol")
    func leafKindElidesEmptyProtocol() throws {
        let cfg = """
        === vocabulary ===
        A pull request is a kind of thing.

        === tools ===
        """
        let mer = """
        ---
        name: leaf probe
        vocabulary: probe.merconfig
        ---
        To probe a pull request:
          complete.
        """
        let opts = Compiler.Options(
            emitterOptions: SwiftEmitter.Options(includeTimestamp: false, emitSourceLineComments: false)
        )
        let swift = try Compiler(options: opts).compile(
            meridianSource: mer,
            meridianFile: "probe.meridian",
            merconfigSource: cfg,
            merconfigFile: "probe.merconfig"
        )
        // Struct conforms directly to the runtime base — no empty
        // `PullRequestKind` protocol, no double indirection.
        #expect(swift.contains("public struct PullRequest: \(BuiltinSemanticBase.root.runtimeProtocolName) {"))
        #expect(!swift.contains("public protocol PullRequestKind"))
    }

    @Test("kinds with descendants keep their protocol even with no own properties")
    func chainAnchorKeepsEmptyProtocol() throws {
        // `pull request` has no own properties but is the parent of
        // `draft pull request`, so the chain anchor must stay — descendant
        // protocols inherit through `<KindName>Kind`, and structs can't be
        // the inheritance anchor.
        let cfg = """
        === vocabulary ===
        A pull request is a kind of thing.
        A draft pull request is a kind of pull request.
        A draft pull request has a title, which is a String.

        === tools ===
        """
        let mer = """
        ---
        name: anchor probe
        vocabulary: probe.merconfig
        ---
        To probe a draft pull request:
          complete.
        """
        let opts = Compiler.Options(
            emitterOptions: SwiftEmitter.Options(includeTimestamp: false, emitSourceLineComments: false)
        )
        let swift = try Compiler(options: opts).compile(
            meridianSource: mer,
            meridianFile: "probe.meridian",
            merconfigSource: cfg,
            merconfigFile: "probe.merconfig"
        )
        #expect(swift.contains("public protocol PullRequestKind: \(BuiltinSemanticBase.root.runtimeProtocolName) {"))
        #expect(swift.contains("public struct PullRequest: PullRequestKind {"))
        #expect(swift.contains("public protocol DraftPullRequestKind: PullRequestKind {"))
        #expect(swift.contains("public struct DraftPullRequest: DraftPullRequestKind {"))
    }
}
