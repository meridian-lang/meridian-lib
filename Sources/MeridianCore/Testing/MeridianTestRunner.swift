import Foundation

// MARK: - MeridianTestRunner
//
// Discovers and executes `.meridian.test` spec files. Pure library code:
// no `print`, no process exit, no `ArgumentParser` dependency. The CLI's
// `meridian test` subcommand is a thin wrapper; IDE plugins, CI integrations,
// and MCP endpoints can reuse the runner with their own reporting layer.
//
// Spec file format  (key: value; heredoc via key: |):
//
//     name: order processing happy compile
//     description: verifies compile + golden diff
//     source: examples/order_processing.meridian
//     vocab: examples/ecommerce.merconfig
//     golden_swift: examples/golden/order_processing_expected.swift
//     no_line_comments: true
//     expect_workflow_count: 2
//     expect_no_unresolved:
//     expect_invoke_tool: validate an order
//     expect_run: true
//     tool_stub validate an order: {"verdict": "valid"}
//     input order: {"id":"o-001","status":"submitted"}
//     expect_event_kinds_prefix: workflow.started
//     expect_run_succeeded: true
//
// See docs/09_MERIDIAN_TESTS.md for the full format reference.

public struct MeridianTestRunner: Sendable {

    // MARK: - Configuration

    /// Include per-line diffs in golden-mismatch failure reasons.
    public var verbose: Bool

    /// When true, a golden-file assertion that fails will overwrite the golden
    /// with the current output and mark the assertion as passing.
    public var updateGolden: Bool

    /// Run only specs whose tags overlap this set (empty = no filter).
    public var tagFilter: [String]

    /// Run only specs whose `displayName` contains this string (case-insensitive).
    public var nameFilter: String?

    public init(
        verbose:      Bool     = false,
        updateGolden: Bool     = false,
        tagFilter:    [String] = [],
        nameFilter:   String?  = nil
    ) {
        self.verbose      = verbose
        self.updateGolden = updateGolden
        self.tagFilter    = tagFilter
        self.nameFilter   = nameFilter
    }

    // MARK: - Nested types

    /// Where the `.meridian` source comes from.
    public enum SourceInput: Sendable {
        case path(String)
        case inline(String)
    }

    /// Where a `.merconfig` vocabulary file comes from.
    public enum VocabInput: Sendable {
        case path(String)
        case inline(name: String, source: String)
    }

    /// Whether the skip directive was applied to a spec.
    public enum SkipMode: Sendable {
        case none
        case skipped(reason: String?)
    }

    /// What the spec expects the compiler to do.
    public enum CompileExpectation: Sendable, Equatable {
        case pass
        case fail
    }

    /// Runtime execution parameters (from `expect_run: true` and friends).
    public struct RuntimeSpec: Sendable {
        public let workflowName: String?
        public let inputs: [(paramName: String, json: String)]
        public let toolStubs: [(toolID: String, json: String)]
        public let expectEventKinds: [String]?
        public let expectEventKindsPrefix: [String]?
        public let expectFinalEventKind: String?
        public let expectRunSucceeded: Bool?

        public init(
            workflowName:         String?        = nil,
            inputs:               [(paramName: String, json: String)] = [],
            toolStubs:            [(toolID: String, json: String)]    = [],
            expectEventKinds:     [String]?      = nil,
            expectEventKindsPrefix: [String]?    = nil,
            expectFinalEventKind: String?        = nil,
            expectRunSucceeded:   Bool?          = nil
        ) {
            self.workflowName         = workflowName
            self.inputs               = inputs
            self.toolStubs            = toolStubs
            self.expectEventKinds     = expectEventKinds
            self.expectEventKindsPrefix = expectEventKindsPrefix
            self.expectFinalEventKind = expectFinalEventKind
            self.expectRunSucceeded   = expectRunSucceeded
        }
    }

    // MARK: - Spec

    /// Parsed `.meridian.test` spec. All paths are resolved relative to `baseDir`.
    public struct Spec: Sendable {
        public let displayName:        String
        public let baseDir:            URL
        public let description:        String?
        public let tags:               [String]
        public let only:               Bool
        public let skip:               SkipMode
        public let traceCategories:    [ParserTrace.Category]
        public let source:             SourceInput
        public let vocab:              [VocabInput]
        public let compileExpectation: CompileExpectation
        public let assertions:         [Assertion]
        public let runtime:            RuntimeSpec?
        public let noLineComments:     Bool

        public init(
            displayName:        String,
            baseDir:            URL,
            description:        String?  = nil,
            tags:               [String] = [],
            only:               Bool     = false,
            skip:               SkipMode = .none,
            traceCategories:    [ParserTrace.Category] = [],
            source:             SourceInput,
            vocab:              [VocabInput]   = [],
            compileExpectation: CompileExpectation = .pass,
            assertions:         [Assertion]   = [],
            runtime:            RuntimeSpec?  = nil,
            noLineComments:     Bool          = false
        ) {
            self.displayName        = displayName
            self.baseDir            = baseDir
            self.description        = description
            self.tags               = tags
            self.only               = only
            self.skip               = skip
            self.traceCategories    = traceCategories
            self.source             = source
            self.vocab              = vocab
            self.compileExpectation = compileExpectation
            self.assertions         = assertions
            self.runtime            = runtime
            self.noLineComments     = noLineComments
        }
    }

    // MARK: - Outcome / Report

    public enum Outcome: Sendable, Equatable {
        case success(detail: String)
        case failure(reasons: [String])
        case skipped(reason: String?)

        public var isSuccess: Bool {
            if case .success = self { return true }
            return false
        }

        public var isSkipped: Bool {
            if case .skipped = self { return true }
            return false
        }
    }

    public struct Report: Sendable {
        public let spec:    Spec
        public let outcome: Outcome
        public init(spec: Spec, outcome: Outcome) {
            self.spec    = spec
            self.outcome = outcome
        }
    }

    // MARK: - Errors

    public enum SpecError: Error, CustomStringConvertible, Sendable {
        case missingRequiredKey(String, file: String)
        case readFailure(String, underlying: Error)
        case parseError(String, file: String)

        public var description: String {
            switch self {
            case .missingRequiredKey(let key, let file):
                return "\(file): missing required key `\(key):`"
            case .readFailure(let path, let err):
                return "could not read \(path): \(err)"
            case .parseError(let msg, let file):
                return "\(file): \(msg)"
            }
        }
    }

    // MARK: - Discovery

    /// Walk `roots` (files or directories) and return every `.meridian.test`
    /// file found, sorted by path for stable test ordering.
    public func discover(in roots: [URL]) -> [URL] {
        var results: [URL] = []
        let fm = FileManager.default
        for root in roots {
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: root.path, isDirectory: &isDir) else { continue }
            if isDir.boolValue {
                if let enumerator = fm.enumerator(
                    at: root,
                    includingPropertiesForKeys: nil,
                    options: [.skipsHiddenFiles]
                ) {
                    for case let entry as URL in enumerator
                        where entry.lastPathComponent.hasSuffix(".meridian.test") {
                        results.append(entry)
                    }
                }
            } else if root.lastPathComponent.hasSuffix(".meridian.test") {
                results.append(root)
            }
        }
        return results.sorted { $0.path < $1.path }
    }

    // MARK: - Spec loading

    /// Parse a single `.meridian.test` file from disk.
    /// Throws `SpecError` on parse failures or missing required keys.
    public func loadSpec(_ url: URL) throws -> Spec {
        let raw: String
        do { raw = try String(contentsOf: url, encoding: .utf8) }
        catch { throw SpecError.readFailure(url.path, underlying: error) }

        do {
            return try SpecParser().parse(raw, fileURL: url)
        } catch let e as SpecParser.ParseError {
            throw SpecError.parseError(e.message, file: url.lastPathComponent)
        } catch let e as CompilerError {
            if case .diagnostics(let ds) = e, let first = ds.first {
                throw SpecError.parseError("[\(first.code.id)] \(first.message)", file: url.lastPathComponent)
            }
            throw SpecError.parseError("\(e)", file: url.lastPathComponent)
        } catch let e as SpecError {
            throw e
        } catch {
            throw SpecError.parseError("\(error)", file: url.lastPathComponent)
        }
    }

    // MARK: - Execution

    /// Run a single spec. Never throws. All failure modes are folded into
    /// `Outcome.failure(reasons:)` so the caller can keep iterating.
    public func run(_ spec: Spec) -> Outcome {
        // Skip check
        if case .skipped(let reason) = spec.skip {
            return .skipped(reason: reason)
        }

        // Tag filter (runner-level: not a spec-level skip)
        if !tagFilter.isEmpty, !spec.tags.contains(where: { tagFilter.contains($0) }) {
            return .skipped(reason: "not in tag filter [\(tagFilter.joined(separator: ", "))]")
        }

        // Name filter
        if let filter = nameFilter,
           !spec.displayName.lowercased().contains(filter.lowercased()) {
            return .skipped(reason: "name does not match filter '\(filter)'")
        }

        // Resolve + read source
        let meridianSource: String
        switch readSourceInput(spec.source, baseDir: spec.baseDir) {
        case .success(let s): meridianSource = s
        case .failure(let e):
            if case .message(let msg) = e { return .failure(reasons: [msg]) }
            return .failure(reasons: ["\(e)"])
        }

        // Resolve + read vocabs
        var vocabularies: [Compiler.VocabularyInput] = []
        for vocabInput in spec.vocab {
            switch readVocabInput(vocabInput, baseDir: spec.baseDir) {
            case .success(let v): vocabularies.append(v)
            case .failure(let e):
                if case .message(let msg) = e { return .failure(reasons: [msg]) }
                return .failure(reasons: ["\(e)"])
            }
        }

        // Set up per-spec trace capture
        let traceCapture: (trace: ParserTrace, lines: @Sendable () -> [String])?
        if !spec.traceCategories.isEmpty || spec.assertions.contains(where: {
            if case .traceContains = $0 { return true }
            return false
        }) {
            let cats = spec.traceCategories.isEmpty ? ParserTrace.Category.allCases : spec.traceCategories
            traceCapture = ParserTrace.capturing(categories: cats)
        } else {
            traceCapture = nil
        }

        // Compile
        let compiler = Compiler(options: .init(
            emitterOptions: SwiftEmitter.Options(
                includeTimestamp:       false,
                sourceFileName:         sourceFileName(spec.source),
                emitSourceLineComments: !spec.noLineComments
            ),
            trace: traceCapture?.trace ?? .silent()
        ))

        var swiftOutput: String? = nil
        var workflows:   [IRWorkflow]? = nil
        var compileError: CompilerError? = nil

        // We need access to workflows (IR) for IR-level assertions. The
        // Compiler.compile() API doesn't expose them, so we re-run the first
        // few pipeline stages ourselves when any IR assertion is present.
        let needsIR = spec.assertions.contains(where: isIRAssertion) || spec.runtime != nil

        if needsIR {
            let result = compileWithIR(
                meridianSource: meridianSource,
                vocabs: vocabularies,
                spec: spec,
                compiler: compiler
            )
            swiftOutput  = result.swift
            workflows    = result.workflows
            compileError = result.error
        } else {
            do {
                swiftOutput = try compiler.compile(
                    meridianSource: meridianSource,
                    meridianFile:   sourceFileName(spec.source),
                    vocabularies:   vocabularies
                )
            } catch let e as CompilerError {
                compileError = e
            } catch {
                return .failure(reasons: ["unexpected error: \(error)"])
            }
        }

        let traceLines = traceCapture?.lines() ?? []

        // Check compile expectation
        switch spec.compileExpectation {
        case .pass:
            if let err = compileError {
                return .failure(reasons: ["compilation failed: \(describeError(err))"])
            }
        case .fail:
            if compileError == nil {
                return .failure(reasons: ["expected compile to fail, but it succeeded"])
            }
        }

        // Build assertion context
        let ctx = AssertionContext(
            swift:          swiftOutput,
            workflows:      workflows,
            traceLines:     traceLines,
            baseDir:        spec.baseDir,
            meridianSource: meridianSource,
            verbose:        verbose,
            compileError:   compileError,
            updateGolden:   updateGolden
        )

        // Evaluate all assertions, collecting every failure
        var reasons: [String] = []
        for assertion in spec.assertions {
            if let failure = evaluate(assertion, in: ctx) {
                reasons.append(failure)
            }
        }

        // Runtime execution (if requested and compile succeeded)
        if let runtimeSpec = spec.runtime, swiftOutput != nil, let wfs = workflows {
            let repoRoot = findRepoRoot(from: spec.baseDir)
            let executor = RuntimeExecutor(verbose: verbose)
            let runtimeFailures = executor.run(
                spec:        runtimeSpec,
                swiftSource: swiftOutput!,
                workflows:   wfs,
                repoRoot:    repoRoot ?? spec.baseDir
            )
            reasons.append(contentsOf: runtimeFailures)
        }

        if reasons.isEmpty {
            let detail = buildSuccessDetail(spec: spec)
            return .success(detail: detail)
        }
        return .failure(reasons: reasons)
    }

    // MARK: - One-shot convenience

    /// Discover every spec under `roots`, apply `only` focusing, run them
    /// in path order, and return one `Report` per discovered file.
    public func runAll(roots: [URL]) -> [Report] {
        let urls = discover(in: roots)
        let specs: [(url: URL, spec: Result<Spec, Error>)] = urls.map { url in
            do    { return (url, .success(try loadSpec(url))) }
            catch { return (url, .failure(error)) }
        }

        // Apply `only` focus: if any spec sets `only: true`, skip all others.
        let anyOnly = specs.contains { (_, r) in
            if case .success(let s) = r { return s.only }
            return false
        }

        var reports: [Report] = []
        for (url, result) in specs {
            switch result {
            case .success(let spec):
                if anyOnly, !spec.only {
                    // Re-wrap with a forced skip — can't mutate, build synthetic spec
                    let skipped = makeSkippedReport(spec: spec, reason: "not only-focused")
                    reports.append(skipped)
                    continue
                }
                let outcome = run(spec)
                reports.append(Report(spec: spec, outcome: outcome))

            case .failure(let error):
                let placeholder = Spec(
                    displayName: url.deletingPathExtension().lastPathComponent,
                    baseDir:     url.deletingLastPathComponent(),
                    source:      .path("")
                )
                reports.append(Report(
                    spec:    placeholder,
                    outcome: .failure(reasons: ["spec parse error: \(error)"])
                ))
            }
        }
        return reports
    }

    // MARK: - Short-diff helper (public so CLI can format long diffs too)

    /// Returns a short human-readable diff between two multi-line strings.
    public static func shortDiff(actual: String, expected: String) -> String {
        let a = actual.split(separator:   "\n", omittingEmptySubsequences: false).map(String.init)
        let e = expected.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let n = min(a.count, e.count)
        for i in 0..<n {
            if a[i] != e[i] {
                return """
                first mismatch at line \(i + 1):
                  actual:   \(a[i])
                  expected: \(e[i])
                """
            }
        }
        if a.count != e.count {
            return "line count differs: actual \(a.count), expected \(e.count)"
        }
        return "outputs differ but per-line scan found no mismatch (whitespace?)"
    }

    // MARK: - Private helpers

    private enum ReadError: Error { case message(String) }

    private func readSourceInput(_ input: SourceInput, baseDir: URL) -> Result<String, ReadError> {
        switch input {
        case .inline(let src):
            return .success(src)
        case .path(let p):
            let url = URL(fileURLWithPath: p, relativeTo: baseDir).standardized
            guard FileManager.default.fileExists(atPath: url.path) else {
                return .failure(.message("source not found: \(url.path)"))
            }
            do {
                return .success(try String(contentsOf: url, encoding: .utf8))
            } catch {
                return .failure(.message("failed to read source: \(error)"))
            }
        }
    }

    private func readVocabInput(_ input: VocabInput, baseDir: URL) -> Result<Compiler.VocabularyInput, ReadError> {
        switch input {
        case .inline(let name, let source):
            return .success(.init(name: name, file: "\(name).merconfig", source: source))
        case .path(let p):
            let url = URL(fileURLWithPath: p, relativeTo: baseDir).standardized
            guard FileManager.default.fileExists(atPath: url.path) else {
                return .failure(.message("vocab not found: \(url.path)"))
            }
            do {
                let src  = try String(contentsOf: url, encoding: .utf8)
                let name = url.deletingPathExtension().lastPathComponent
                return .success(.init(name: name, file: url.lastPathComponent, source: src))
            } catch {
                return .failure(.message("failed to read vocab \(p): \(error)"))
            }
        }
    }

    private func sourceFileName(_ input: SourceInput) -> String {
        switch input {
        case .path(let p): return URL(fileURLWithPath: p).lastPathComponent
        case .inline:      return "inline.meridian"
        }
    }

    /// Re-run enough of the pipeline to get both the compiled Swift string and
    /// the `[IRWorkflow]`. This is needed for IR assertions.
    private func compileWithIR(
        meridianSource: String,
        vocabs: [Compiler.VocabularyInput],
        spec: Spec,
        compiler: Compiler
    ) -> (swift: String?, workflows: [IRWorkflow]?, error: CompilerError?) {
        do {
            let trace = compiler.options.trace

            var config = MerConfigFile()
            for v in vocabs {
                let parsed = try MerConfigParser(trace: trace).parse(v.source, file: v.file)
                config = config.merging(parsed)
            }
            let symbolsFile = vocabs.first?.file ?? "config.merconfig"
            let symbols = SymbolTable.build(from: config, sourceFile: symbolsFile, trace: trace)
            let ast = try MeridianParser(symbols: symbols, trace: trace).parse(
                meridianSource, file: sourceFileName(spec.source)
            )
            let lowerer   = ASTToIR(symbols: symbols, sourceFile: sourceFileName(spec.source), trace: trace)
            let workflows = try lowerer.lower(ast)

            let swift = try compiler.compile(
                meridianSource: meridianSource,
                meridianFile:   sourceFileName(spec.source),
                vocabularies:   vocabs
            )
            return (swift, workflows, nil)
        } catch let e as CompilerError {
            return (nil, nil, e)
        } catch {
            return (nil, nil, .codegenError(message: "\(error)"))
        }
    }

    private func isIRAssertion(_ a: Assertion) -> Bool {
        switch a {
        case .workflowCount, .workflowNamed, .noUnresolved,
             .invokeToolID, .emitEventID, .primitiveCount,
             .workflowMode, .goldenManifest:
            return true
        default:
            return false
        }
    }

    private func describeError(_ err: CompilerError) -> String {
        switch err {
        case .syntaxError(let m, let r):  return "syntax error at \(r): \(m)"
        case .semanticError(let m, let r): return "semantic error at \(r): \(m)"
        case .codegenError(let m):        return "codegen error: \(m)"
        case .notImplemented(let m):      return "not implemented: \(m)"
        case .diagnostics(let ds):
            return ds.map { d in
                let notes = d.notes.map { " note: \($0.message)" }.joined()
                return "\(d.code.id) at \(d.primaryRange): \(d.message)\(notes)"
            }.joined(separator: "; ")
        }
    }

    private func buildSuccessDetail(spec: Spec) -> String {
        var parts: [String] = []
        if spec.compileExpectation == .fail { parts.append("compile-fail") }
        else { parts.append("compile") }
        if spec.assertions.contains(where: {
            if case .goldenSwift = $0 { return true }
            return false
        }) { parts.append("golden") }
        if spec.runtime != nil { parts.append("run") }
        return parts.joined(separator: " + ")
    }

    private func makeSkippedReport(spec: Spec, reason: String) -> Report {
        Report(spec: spec, outcome: .skipped(reason: reason))
    }

    private func findRepoRoot(from dir: URL) -> URL? {
        if let root = findMeridianPackageRoot(from: dir) { return root }
        return findMeridianPackageRoot(from: URL(fileURLWithPath: FileManager.default.currentDirectoryPath))
    }

    private func findMeridianPackageRoot(from dir: URL) -> URL? {
        var current = dir
        let fm = FileManager.default
        for _ in 0..<10 {
            let manifest = current.appendingPathComponent("Package.swift")
            if fm.fileExists(atPath: manifest.path),
               let source = try? String(contentsOf: manifest, encoding: .utf8),
               source.contains("name: \"meridian\""),
               source.contains("MeridianRuntime") {
                return current
            }
            current = current.deletingLastPathComponent()
        }
        return nil
    }
}
