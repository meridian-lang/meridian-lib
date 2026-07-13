import ArgumentParser
import Foundation
import MeridianCore
import MeridianRuntime
import MeridianTools

public struct CanonicalizeCommand: AsyncParsableCommand {
    public init() {}

    public static let configuration = CommandConfiguration(
        commandName: "canonicalize",
        abstract: "Compare authored Meridian to canonical English and optionally propose surface rewrites."
    )

    @Argument(help: "Path to the .meridian or .meri file.")
    var input: String

    @Option(name: .long, parsing: .singleValue,
            help: "Path to a .merconfig file. May be supplied multiple times; auto-discovers when omitted.")
    var merconfig: [String] = []

    @Option(name: .long, parsing: .singleValue,
            help: "Path to a .merrules rulebook. May be supplied multiple times; auto-discovers when omitted.")
    var rulebook: [String] = []

    @Option(name: .long, parsing: .singleValue,
            help: "Directory searched for shared module packages. Repeatable.")
    var modulePath: [String] = []

    @Flag(name: .long,
          help: "Ask the configured LLM provider to propose authored-line rewrites toward canonical English. Never writes the source file.")
    var propose: Bool = false

    @Option(name: .long, help: "Optional model override (requires MERIDIAN_LLM_API_URL).")
    var llm: String?

    @Flag(name: .long, help: "Emit a stable JSON report.")
    var json: Bool = false

    @OptionGroup var cliTrace: CLITraceOptions

    public func run() async throws {
        let loaded = try loadCLIModelInput(
            input: input, merconfig: merconfig, rulebook: rulebook, modulePath: modulePath)
        let traceInstance = try cliTrace.makeTrace()
        let compiler = Compiler(options: compilerOptions(for: loaded, trace: traceInstance))
        do {
            let model = try compiler.compileToModel(
                meridianSource: loaded.meridianSource,
                meridianFile: loaded.meridianURL.lastPathComponent,
                vocabularies: loaded.vocabularies,
                rulebooks: loaded.rulebooks
            )
            let canonical = try traceInstance.phase("verbalize") {
                try Verbalizer(model: model, trace: traceInstance).verbalize()
            }
            let report = traceInstance.phase("drift") {
                DriftEngine.diff(authored: model.authoredSource, canonical: canonical, trace: traceInstance)
            }

            if propose {
                let proposals = try await proposeRewrites(for: report, file: loaded.meridianURL.lastPathComponent)
                if json {
                    try printProposalJSON(proposals, file: loaded.meridianURL.lastPathComponent, report: report)
                } else {
                    print(renderProposalMarkdown(proposals, file: loaded.meridianURL.lastPathComponent, report: report))
                }
                return
            }

            if json {
                try printDriftJSON(report, file: loaded.meridianURL.lastPathComponent)
            } else {
                print(renderDriftMarkdown(report, file: loaded.meridianURL.lastPathComponent))
            }
        } catch {
            throw reportCompilerError(error, sources: loaded.diagnosticSources)
        }
    }

    private struct Proposal: Sendable {
        let index: Int
        let category: DriftCategory
        let authored: String
        let canonical: String
        let proposed: String
    }

    private func proposeRewrites(for report: DriftReport, file: String) async throws -> [Proposal] {
        let provider = try resolvedProvider()
        var proposals: [Proposal] = []
        for (index, hunk) in report.hunks.enumerated() {
            let prompt = """
            MERIDIAN_PROPOSE_LINE:
            authored:
            \(hunk.authored)
            canonical:
            \(hunk.canonical)
            """
            let response = try await provider.complete(LLMRequest(
                messages: [
                    LLMMessage(role: .system, content: """
                    Propose one authored Meridian surface line that would verbalize to the canonical line.
                    Return ONLY the proposed authored line — no commentary or markdown fences.
                    """),
                    LLMMessage(role: .user, content: prompt),
                ],
                temperature: 0,
                responseFormat: .text
            ))
            proposals.append(Proposal(
                index: index + 1,
                category: hunk.category,
                authored: hunk.authored,
                canonical: hunk.canonical,
                proposed: response.text.trimmingCharacters(in: .whitespacesAndNewlines)
            ))
        }
        return proposals
    }

    private func resolvedProvider() throws -> any LLMProvider {
        if let llm = llm?.trimmingCharacters(in: .whitespacesAndNewlines), !llm.isEmpty {
            guard let config = LLMEnvironment.configuration() else {
                throw ValidationError("LLM repair requires \(LLMEnvironment.apiURLKey) when --llm is set.")
            }
            return HTTPLLMProvider(config: LLMEnvironment.Configuration(
                apiURL: config.apiURL, apiKey: config.apiKey, model: llm))
        }
        if let override = LLMProviderRegistry.peekOverride() {
            return override
        }
        do {
            return try LLMProviderRegistry.resolve(requireConfigured: true)
        } catch LLMProviderError.notConfigured {
            throw ValidationError("canonicalize --propose requires \(LLMEnvironment.apiURLKey) (and optionally \(LLMEnvironment.apiKeyKey), \(LLMEnvironment.modelKey)).")
        }
    }

    private func renderDriftMarkdown(_ report: DriftReport, file: String) -> String {
        var out = ["# Canonical drift: \(file)", ""]
        if report.hunks.isEmpty {
            out.append("No drift detected.")
            return out.joined(separator: "\n")
        }
        for (index, hunk) in report.hunks.enumerated() {
            out.append("## Hunk \(index + 1) (\(hunk.category.rawValue))")
            out.append("- Authored: `\(hunk.authored)`")
            out.append("- Canonical: `\(hunk.canonical)`")
            out.append("")
        }
        return out.joined(separator: "\n")
    }

    private func renderProposalMarkdown(_ proposals: [Proposal], file: String, report: DriftReport) -> String {
        var out = ["# Canonicalize proposals: \(file)", "", "Dry-run only — source not modified.", ""]
        if proposals.isEmpty {
            out.append("No drift hunks to propose.")
            return out.joined(separator: "\n")
        }
        for proposal in proposals {
            out.append("## Hunk \(proposal.index) (\(proposal.category.rawValue))")
            out.append("- Authored: `\(proposal.authored)`")
            out.append("- Canonical: `\(proposal.canonical)`")
            out.append("- Proposed: `\(proposal.proposed)`")
            out.append("")
        }
        out.append("Total hunks: \(report.hunks.count)")
        return out.joined(separator: "\n")
    }

    private func printDriftJSON(_ report: DriftReport, file: String) throws {
        let payload: [String: Any] = [
            "file": file,
            "hunks": report.hunks.map {
                ["category": $0.category.rawValue, "authored": $0.authored, "canonical": $0.canonical] as [String: Any]
            },
        ]
        let data = try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])
        print(String(data: data, encoding: .utf8) ?? "{}")
    }

    private func printProposalJSON(_ proposals: [Proposal], file: String, report: DriftReport) throws {
        let payload: [String: Any] = [
            "file": file,
            "dry_run": true,
            "proposals": proposals.map {
                [
                    "index": $0.index,
                    "category": $0.category.rawValue,
                    "authored": $0.authored,
                    "canonical": $0.canonical,
                    "proposed": $0.proposed,
                ] as [String: Any]
            },
            "hunk_count": report.hunks.count,
        ]
        let data = try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])
        print(String(data: data, encoding: .utf8) ?? "{}")
    }
}
