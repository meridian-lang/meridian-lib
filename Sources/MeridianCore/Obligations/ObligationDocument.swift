import Foundation

public struct ObligationDocumentIdentity: Sendable, Codable {
    public let skillName: String
    public let skillVersionHash: String?
    public let sourceFile: String
    public let compilerIRVersion: String

    enum CodingKeys: String, CodingKey {
        case skillName = "skill_name"
        case skillVersionHash = "skill_version_hash"
        case sourceFile = "source_file"
        case compilerIRVersion = "compiler_ir_version"
    }
}

public struct ObligationDocument: Sendable, Codable {
    public let schemaVersion: String
    public let semanticsVersion: String
    public let proofIRVersion: String
    public let identity: ObligationDocumentIdentity
    public let obligations: [ObligationArtifact]

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case semanticsVersion = "semantics_version"
        case proofIRVersion = "proof_ir_version"
        case identity
        case obligations
    }
}

public struct ObligationDocumentOptions: Sendable {
    public let includeProofIR: Bool
    public let skillName: String?
    public let skillVersionHash: String?

    public init(
        includeProofIR: Bool = true,
        skillName: String? = nil,
        skillVersionHash: String? = nil
    ) {
        self.includeProofIR = includeProofIR
        self.skillName = skillName
        self.skillVersionHash = skillVersionHash
    }
}

public enum ObligationDocumentBuilder {

    public static func build(
        from model: VerbalizerModel,
        options: ObligationDocumentOptions = .init()
    ) throws -> ObligationDocument {
        let verbalizer = Verbalizer(model: model)
        let skillName = options.skillName
            ?? model.metadata?.entries.first(where: { $0.key == "name" })?.value
            ?? model.sourceFileName
                .replacingOccurrences(of: ".meridian", with: "")
                .replacingOccurrences(of: ".meri", with: "")
        var artifacts: [ObligationArtifact] = []
        var seenNormIDs = Set<String>()
        var seenAssertIDs = Set<String>()

        for workflow in model.workflows {
            for norm in workflow.norms where !seenNormIDs.contains(norm.id) {
                seenNormIDs.insert(norm.id)
                artifacts.append(try ObligationArtifactBuilder.from(
                    norm: norm,
                    verbalizer: verbalizer,
                    sourceFile: model.sourceFileName,
                    includeProofIR: options.includeProofIR
                ))
            }
        }

        for workflow in model.workflows {
            let scope: NormScope = .workflow(workflow.structName)
            for primitive in IRWalker.flatPrimitives(workflow.body) {
                guard case .assert(let assertIR) = primitive,
                      let obligationId = assertIR.obligationId,
                      !seenNormIDs.contains(obligationId),
                      !seenAssertIDs.contains(obligationId),
                      ContractObligationDetector.isContractObligation(assertIR) else { continue }
                seenAssertIDs.insert(obligationId)
                artifacts.append(try ObligationArtifactBuilder.from(
                    assert: assertIR,
                    obligationId: obligationId,
                    scope: scope,
                    verbalizer: verbalizer,
                    sourceFile: model.sourceFileName,
                    includeProofIR: options.includeProofIR
                ))
            }
        }

        artifacts.sort { $0.id < $1.id }
        return ObligationDocument(
            schemaVersion: OBLIGATION_ARTIFACT_SCHEMA_VERSION,
            semanticsVersion: OBLIGATION_SEMANTICS_VERSION,
            proofIRVersion: PROOF_IR_VERSION,
            identity: ObligationDocumentIdentity(
                skillName: skillName,
                skillVersionHash: options.skillVersionHash ?? model.workflows.first?.skillVersionHash,
                sourceFile: model.sourceFileName,
                compilerIRVersion: MERIDIAN_IR_VERSION
            ),
            obligations: artifacts
        )
    }

    public static func emitJSON(
        _ document: ObligationDocument,
        prettyPrinted: Bool = true
    ) throws -> String {
        let encoder = JSONEncoder()
        if prettyPrinted {
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        } else {
            encoder.outputFormatting = [.sortedKeys]
        }
        let data = try encoder.encode(document)
        guard let text = String(data: data, encoding: .utf8) else {
            throw CompilerError.codegenError(message: "failed to encode obligation document")
        }
        return text
    }

    public static func summary(_ document: ObligationDocument) -> String {
        var counts: [ObligationProofKind: Int] = [:]
        for artifact in document.obligations {
            counts[artifact.kind, default: 0] += 1
        }
        let parts = ObligationProofKind.allCases.sorted(by: { $0.rawValue < $1.rawValue }).compactMap { kind -> String? in
            guard let count = counts[kind], count > 0 else { return nil }
            return "\(kind.rawValue): \(count)"
        }
        return "\(document.obligations.count) obligation(s)" + (parts.isEmpty ? "" : " (\(parts.joined(separator: ", ")))")
    }
}

extension ObligationProofKind: CaseIterable {
    public static var allCases: [ObligationProofKind] {
        [.unreachability, .invariant, .coverage, .statisticalMonitor]
    }
}

public struct ObligationSchemaDocument: Sendable, Codable {
    public let schemaVersion: String
    public let semanticsVersion: String
    public let proofIRVersion: String
    public let dischargeStatuses: [String]
    public let obligationKinds: [String]

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case semanticsVersion = "semantics_version"
        case proofIRVersion = "proof_ir_version"
        case dischargeStatuses = "discharge_statuses"
        case obligationKinds = "obligation_kinds"
    }

    public static let current = ObligationSchemaDocument(
        schemaVersion: OBLIGATION_ARTIFACT_SCHEMA_VERSION,
        semanticsVersion: OBLIGATION_SEMANTICS_VERSION,
        proofIRVersion: PROOF_IR_VERSION,
        dischargeStatuses: ObligationDischargeStatus.allCases.map(\.rawValue),
        obligationKinds: ObligationProofKind.allCases.map(\.rawValue)
    )
}
