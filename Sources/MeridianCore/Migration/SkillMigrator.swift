import Foundation

// MARK: - SkillMigrator
//
// Authoring-time tool that converts a gbrain `SKILL.md` into a strict-compiling
// `.meri`. It is the inverse-friendly companion to the rulebook engine:
//
//   1. Deterministic transform — the marking pass. It injects no frontmatter
//      (section semantics activate structurally on any `##`/`###` heading, and
//      the CLI autodiscovers `.merconfig`/`.merrules`), but it blockquotes
//      pre-heading preamble and appends an authoritative `(( … ))` marker to
//      every heading that would not otherwise resolve to an executable role
//      (prose Contract/Anti-Patterns → inert-with-role, pure-shell unknown →
//      `(( role: procedure ))`, other unknown → `(( inert ))`). It does NOT
//      strip `skill: true` (a one-time corpus edit). See `deterministicTransform`.
//   2. Strict compile — run the candidate through `Compiler` exactly like a
//      hand-authored file.
//   3. Bounded repair — when compilation fails AND a repair closure is
//      supplied, hand the diagnostic + candidate to the closure (which may be
//      LLM-backed) for at most `maxRepair` rounds. The closure may ONLY
//      rephrase a flagged line into a resolvable phrase or wrap a genuine
//      judgment step in an explicit `use judgment to …:` marker — it can never
//      introduce a silent LLM path, because the result is re-compiled strict.
//
// LLM proposes, compiler disposes: a migration is "successful" only when the
// emitted `.meri` passes the same strict compile as a hand-authored file. The
// repair closure is a Core-LOCAL `(RepairRequest) async throws -> String`, so
// `MeridianCore` keeps no dependency on `MeridianRuntime`'s `LLMProvider`; the
// CLI adapts a concrete provider to this closure, and tests pass an inline one.

public struct SkillMigrator {

    public struct Options: Sendable {
        /// Maximum repair rounds (0 = deterministic-only).
        public var maxRepair: Int

        public init(maxRepair: Int = 0) {
            self.maxRepair = maxRepair
        }
    }

    /// A request handed to the repair closure when a candidate fails strict
    /// compilation. The closure returns a revised `.meri` source.
    public struct RepairRequest: Sendable {
        public let candidate: String
        public let diagnostic: String
        public let attempt: Int
    }

    public struct Report: Sendable {
        public var compiledOK: Bool
        public var repairAttempts: Int
        public var diagnostics: [String]
        public var addedFrontmatterKeys: [String]
        public var originalLineCount: Int
        public var resultLineCount: Int
        /// Lines changed vs the original (added frontmatter keys + repair rounds).
        public var editCount: Int
    }

    public struct Result: Sendable {
        public var meriSource: String
        public var report: Report
        public var compiledOK: Bool
    }

    let compiler: Compiler
    let vocabularies: [Compiler.VocabularyInput]
    let rulebookInputs: [RulebookInput]
    let options: Options
    let repair: (@Sendable (RepairRequest) async throws -> String)?

    public init(compiler: Compiler,
                vocabularies: [Compiler.VocabularyInput],
                rulebooks: [RulebookInput] = [],
                options: Options = Options(),
                repair: (@Sendable (RepairRequest) async throws -> String)? = nil) {
        self.compiler = compiler
        self.vocabularies = vocabularies
        self.rulebookInputs = rulebooks
        self.options = options
        self.repair = repair
    }

    public func migrate(_ markdown: String, file: String = "skill.meri") async throws -> Result {
        let (transformed, addedKeys) = deterministicTransform(markdown)
        let originalLineCount = markdown.components(separatedBy: "\n").count

        var candidate = transformed
        var diagnostics: [String] = []
        var attempts = 0

        while true {
            do {
                _ = try compiler.compile(
                    meridianSource: candidate, meridianFile: file,
                    vocabularies: vocabularies, rulebooks: rulebookInputs
                )
                return result(candidate, addedKeys: addedKeys, diagnostics: diagnostics,
                              attempts: attempts, originalLineCount: originalLineCount,
                              compiledOK: true)
            } catch {
                let diag = describe(error)
                diagnostics.append(diag)
                guard let repair, attempts < options.maxRepair else {
                    return result(candidate, addedKeys: addedKeys, diagnostics: diagnostics,
                                  attempts: attempts, originalLineCount: originalLineCount,
                                  compiledOK: false)
                }
                attempts += 1
                candidate = try await repair(RepairRequest(
                    candidate: candidate, diagnostic: diag, attempt: attempts))
            }
        }
    }

    // MARK: - Deterministic transform

    /// The reusable, deterministic marking pass. It injects **no frontmatter**
    /// (section semantics activate structurally on `##`/`###` headings, and the
    /// CLI autodiscovers `.merconfig`/`.merrules`) — instead it does the two
    /// edits the universal-sections model needs to make a `SKILL.md`-shaped
    /// document compile with minimal change:
    ///
    ///   1. **Blockquote preamble** — any non-comment content before the first
    ///      heading is prefixed with `> ` (a markdown blockquote, treated as a
    ///      comment by the tokenizer), so it doesn't trip the "content before
    ///      the first heading" hard error.
    ///   2. **Mark headings** — append an authoritative `(( … ))` marker to each
    ///      heading that would otherwise not resolve to an executable role:
    ///        • Contract/Guarantees/Invariants → `(( inert, role: invariants ))`
    ///          (the gbrain corpus states these as prose, not checkable predicates)
    ///        • Anti-Patterns/Avoid/Pitfalls   → `(( inert, role: prohibitions ))`
    ///        • a recognized procedure/applicability/negative/template heading
    ///          → left unmarked (it lowers as that role)
    ///        • an unrecognized heading whose body is *only* shell fences
    ///          → `(( role: procedure ))` (the fences stay deterministic
    ///          `shell.run` invokes)
    ///        • every other unrecognized heading → `(( inert ))`
    ///
    /// Idempotent (an already-marked heading is left untouched) and
    /// frontmatter-preserving. It does NOT strip `skill: true` — that is a
    /// one-time corpus edit, not a reusable transform. Role recognition uses the
    /// built-in alias table (`SkillSectionRole.builtinRole`); idiosyncratic
    /// organizational headings get `(( inert ))` and are the author's residue to
    /// resolve (split into a procedure section, alias in the rulebook, or keep
    /// inert). `addedKeys` is always empty — the pass adds no frontmatter.
    func deterministicTransform(_ markdown: String) -> (source: String, addedKeys: [String]) {
        (markSections(markdown), [])
    }

    /// Apply the blockquote-preamble + heading-marker pass (see
    /// `deterministicTransform`). A heading-less document is returned untouched.
    func markSections(_ markdown: String) -> String {
        var lines = markdown.components(separatedBy: "\n")
        let bodyStart = frontmatterEnd(lines)

        let headingIdxs = lines.indices.filter { $0 >= bodyStart && headingMatch(lines[$0]) != nil }
        guard let firstHeading = headingIdxs.first else { return markdown }

        // 1. Blockquote preamble (body lines before the first heading).
        if firstHeading > bodyStart {
            for i in bodyStart..<firstHeading {
                let t = lines[i].trimmingCharacters(in: .whitespaces)
                if t.isEmpty || t.hasPrefix("#") || t.hasPrefix(">") { continue }
                lines[i] = "> " + lines[i]
            }
        }

        // 2. Mark headings.
        for (k, idx) in headingIdxs.enumerated() {
            guard let m = headingMatch(lines[idx]) else { continue }
            if m.text.hasSuffix("))") { continue }   // already marked — idempotent
            let end = (k + 1 < headingIdxs.count) ? headingIdxs[k + 1] : lines.count
            let body = lines[(idx + 1)..<end]
            if let marker = marker(forHeading: m.text, body: body) {
                lines[idx] = "\(m.hashes) \(m.text) \(marker)"
            }
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - Marking helpers

    /// Index of the first body line (after a leading `--- … ---` frontmatter
    /// block), or 0 when there is no frontmatter.
    private func frontmatterEnd(_ lines: [String]) -> Int {
        guard lines.first?.trimmingCharacters(in: .whitespaces) == "---" else { return 0 }
        var i = 1
        while i < lines.count {
            if lines[i].trimmingCharacters(in: .whitespaces) == "---" { return i + 1 }
            i += 1
        }
        return 0
    }

    /// Recognize a `##`…`######` heading line (no leading whitespace, at least
    /// one space after the hashes, non-empty text). Returns the hash run and the
    /// trimmed heading text.
    private func headingMatch(_ line: String) -> (hashes: String, text: String)? {
        guard line.hasPrefix("##") else { return nil }
        var hashes = 0
        for ch in line { if ch == "#" { hashes += 1 } else { break } }
        guard (2...6).contains(hashes) else { return nil }
        let after = line.dropFirst(hashes)
        guard let first = after.first, first == " " || first == "\t" else { return nil }
        let text = after.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return nil }
        return (String(repeating: "#", count: hashes), text)
    }

    /// The marker to append to `heading` (or nil to leave it unmarked), chosen by
    /// the built-in role alias and, for unrecognized headings, whether the body
    /// is pure shell.
    private func marker(forHeading heading: String, body: ArraySlice<String>) -> String? {
        switch SkillSectionRole.builtinRole(forHeading: heading) {
        case .invariants:
            return "(( inert, role: invariants ))"
        case .prohibitions:
            return "(( inert, role: prohibitions ))"
        case .some:
            // procedure / applicability / negative-applicability / template —
            // these lower as their role, leave them unmarked.
            return nil
        case .none:
            return sectionIsPureShell(body) ? "(( role: procedure ))" : "(( inert ))"
        }
    }

    /// True iff every non-blank body line lives inside a shell fence
    /// (```bash/```sh/…) — i.e. the section is only deterministic shell commands.
    private func sectionIsPureShell(_ body: ArraySlice<String>) -> Bool {
        var inFence = false
        var sawShell = false
        var sawOther = false
        for raw in body {
            let t = raw.trimmingCharacters(in: .whitespaces)
            if t.hasPrefix("```") {
                if !inFence {
                    inFence = true
                    let lang = String(t.dropFirst(3)).trimmingCharacters(in: .whitespaces).lowercased()
                    if shellFenceLanguages.contains(lang) { sawShell = true } else { sawOther = true }
                } else {
                    inFence = false
                }
                continue
            }
            if inFence { continue }
            if t.isEmpty { continue }
            sawOther = true
        }
        return sawShell && !sawOther
    }

    // MARK: - Helpers

    private func result(_ source: String, addedKeys: [String], diagnostics: [String],
                        attempts: Int, originalLineCount: Int, compiledOK: Bool) -> Result {
        let resultLineCount = source.components(separatedBy: "\n").count
        let report = Report(
            compiledOK: compiledOK,
            repairAttempts: attempts,
            diagnostics: diagnostics,
            addedFrontmatterKeys: addedKeys,
            originalLineCount: originalLineCount,
            resultLineCount: resultLineCount,
            editCount: addedKeys.count + attempts
        )
        return Result(meriSource: source, report: report, compiledOK: compiledOK)
    }

    private func describe(_ error: any Error) -> String {
        if let compilerError = error as? CompilerError {
            switch compilerError {
            case .semanticError(let message, let range):
                return "L\(range.startLine): \(message)"
            default:
                return String(describing: compilerError)
            }
        }
        return String(describing: error)
    }
}
