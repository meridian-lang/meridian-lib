import Foundation
import MeridianRuntime

// Phrase invocation lowering — extracted from ASTToIR for Phase 3 readability.

extension ASTToIR {

    // MARK: - Phrase invocation

    func lowerPhraseInvocation(
        _ s: PhraseInvocationAST,
        mode: ExecutionMode,
        depth: Int,
        defaultParam: (parameter: PhraseParameterAST, owningStructName: String)? = nil,
        proseDispatchMode: ProseDispatchMode? = nil,
        autonomyConfig: AutonomyConfigIR? = nil,
        scope: Set<String> = []
    ) throws -> [IRPrimitive] {
        let trace = ParserTrace.current
        let token = trace.push(.phraseInline, "phrase invocation @L\(s.sourceLine) depth=\(depth): \"\(s.words)\"")
        defer { trace.pop(token) }

        guard depth < maxInlineDepth else {
            trace.log(.phraseInline, "  depth limit reached — bailing out")
            throw CompilerError.diagnostics([
                Diagnostic.error(
                    .phraseInlineDepthExceeded,
                    message: "phrase inlining exceeded the depth limit (\(maxInlineDepth)) at \"\(s.words)\"",
                    range: sourceRange(s.sourceLine),
                    help: "This usually means a phrase definition is cyclic (it inlines itself directly or transitively). Break the cycle, or call it as a workflow instead of a phrase.")
            ])
        }

        // Command surface: a verbatim shell command (from a fenced ```bash
        // block or an inline backticked command) lowers to a deterministic
        // `shell.run` invoke. This sits before the prose gate so literal
        // commands stay deterministic even inside a discretion/autonomy
        // workflow — exactly like an explicit `invoke …`.
        if let command = decodeShellCommand(s.words) {
            trace.log(.phraseInline, "  shell command → shell.run")
            let commandValue = try lowerShellCommand(command, scope: scope, sourceLine: s.sourceLine)
            return [.invoke(InvokeIR(
                toolID: "shell.run",
                arguments: [InvokeArg("command", commandValue)],
                comment: s.annotation,
                sourceRange: sourceRange(s.sourceLine)
            ))]
        }

        // General-abilities: a non-shell fence with a configured
        // `=== language ===` `Fence tool mapping:` entry lowers to a plain
        // `invoke` — the whole fence body as one literal `code` string
        // argument, no command-hole interpolation (that is `shell.run`-
        // specific). Lets non-shell skill repos (e.g. ```python fences) lower
        // deterministically instead of falling to inert or AI dispatch.
        if let (toolID, body) = decodeToolFenceCommand(s.words) {
            trace.log(.phraseInline, "  tool fence → \(toolID)")
            return [.invoke(InvokeIR(
                toolID: toolID,
                arguments: [InvokeArg("code", .literal(.string(body)))],
                comment: s.annotation,
                sourceRange: sourceRange(s.sourceLine)
            ))]
        }

        if s.words.lowercased().hasPrefix(lexicon.grammar.statement.invokePrefix) {
            let sp = StatementParser(symbols: symbols, lexicon: lexicon)
            let expr = sp.buildInvokeExpr(s.words)
            if case .invoke(let toolID, let args) = expr {
                trace.log(.phraseInline, "  bare invoke: tool=\(toolID) args=\(args.count)")
                return autoBindIfNeeded([.invoke(InvokeIR(
                    toolID: toolID,
                    arguments: try args.map { InvokeArg($0.0, try lowerExpr($0.1)) },
                    sourceRange: sourceRange(s.sourceLine)
                ))], invocationWords: s.words)
            }
        }

        // When a workflow is declared `with discretion` or `with autonomy`,
        // EVERY body line is prose — never a deterministic phrase invocation.
        // Without this gate a prose sentence whose first word happens to match
        // a vocabulary phrase (e.g. "Inspect the failing job…" overlapping
        // with the deterministic phrase "inspect the ci status of a pull
        // request") would silently bypass the planner and lower to the wrong
        // tool call. Phrase resolution is only consulted in non-prose
        // workflows.
        if let proseDispatchMode {
            return [makeAIPrimitive(text: s.words, dispatchMode: proseDispatchMode, autonomy: autonomyConfig, line: s.sourceLine)]
        }

        guard let (phrase, args) = symbols.matchPhrase(
            s.words,
            defaultParam: defaultParam?.parameter,
            excludingStructName: defaultParam?.owningStructName
        ) else {
            if fallbackPolicy.allows(.unresolvedPhrases) {
                reportFallbackWarning(
                    .unresolvedPhrase,
                    message: "unresolved phrase placeholder emitted by allow-fallbacks: \"\(s.words)\"",
                    range: sourceRange(s.sourceLine),
                    help: "Add a matching phrase or workflow; remove `allow-fallbacks: unresolved-phrases` to make this a hard error.")
                return [.bind(BindIR(
                    name: "_unresolved",
                    expression: .literal(.string("/* unresolved: \(s.words) */")),
                    sourceRange: sourceRange(s.sourceLine)
                ))]
            } else {
                let candidates = symbols.phrases.map { $0.pattern.displayText }
                throw CompilerError.diagnostics([
                    Diagnostic.unresolved(
                        .unresolvedPhrase,
                        target: s.words,
                        among: candidates,
                        range: sourceRange(s.sourceLine),
                        noun: "phrase",
                        help: "Add a matching phrase or workflow, or set frontmatter `allow-fallbacks: unresolved-phrases` to allow placeholders.")
                ])
            }
        }

        if let structName = phrase.workflowStructName {
            // Argument order MUST match the pattern's declared parameter order
            // (which is what `IRWorkflow.parameters` and the generated init
            // signature use). Dict iteration is unordered, so iterate the
            // pattern instead.
            //
            // `extractArgs` stores values under `param.name` verbatim (which is
            // already camelCased). Try the verbatim form first and fall back to
            // a few common case/spacing variants so a body written with snake
            // or space-separated parameter names still resolves.
            let ordered: [InvokeArg] = try phrase.pattern.parameters.map { p in
                let candidates = [
                    p.name,
                    p.name.lowercased(),
                    p.kind.lowercased(),
                    p.name.replacingOccurrences(of: " ", with: ""),
                ]
                for candidate in candidates {
                    if let val = args[candidate] {
                        return InvokeArg(p.name, try lowerExpr(val))
                    }
                }
                throw CompilerError.diagnostics([
                    Diagnostic.unresolved(
                        .missingPhraseArgument,
                        target: p.name,
                        among: Array(args.keys),
                        range: sourceRange(s.sourceLine),
                        noun: "phrase argument",
                        help: "Workflow \"\(structName)\" declares a parameter \"\(p.name)\" (kind \(p.kind)); the invocation \"\(s.words)\" did not supply a matching argument. Pass an argument named \"\(p.name)\", or rename it to match.")
                ])
            }
            trace.log(.phraseInline, "  workflow call → \(structName)  args=\(ordered.map(\.key))")
            return [.invoke(InvokeIR(
                toolID: "workflow:\(structName)",
                arguments: ordered,
                sourceRange: sourceRange(s.sourceLine)
            ))]
        }

        trace.log(.phraseInline, "  matched @L\(phrase.sourceLine)  args=\(args.keys.sorted())")
        let inlined = try inlinePhrase(
            phrase,
            args: args,
            invocationLine: s.sourceLine,
            mode: mode,
            depth: depth + 1,
            defaultParam: defaultParam,
            proseDispatchMode: proseDispatchMode,
            autonomyConfig: autonomyConfig
        )
        return autoBindIfNeeded(inlined, invocationWords: s.words)
    }

    private func autoBindIfNeeded(_ primitives: [IRPrimitive], invocationWords: String) -> [IRPrimitive] {
        guard primitives.count == 1,
              case .invoke(let invoke) = primitives[0],
              invoke.resultBinding == nil,
              toolReturnsValue(invoke.toolID),
              let bindName = implicitBindName(from: invocationWords) else {
            return primitives
        }
        ParserTrace.current.log(.lowering, "implicit bind \(bindName) for \(invoke.toolID)")
        return [.invoke(InvokeIR(
            toolID: invoke.toolID,
            arguments: invoke.arguments,
            resultBinding: bindName,
            sourceRange: invoke.sourceRange
        ))]
    }

    private func toolReturnsValue(_ toolID: String) -> Bool {
        guard !toolID.hasPrefix("workflow:") else {
            return false
        }
        guard let tool = symbols.tools[toolID] ?? symbols.tools.values.first(where: {
            $0.methodName.caseInsensitiveCompare(toolID) == .orderedSame
        }) else { return false }
        let ret = tool.returnType.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        return !ret.isEmpty && !lexicon.grammar.merconfig.voidReturnTypeNames.contains(ret)
    }

    private func implicitBindName(from invocationWords: String) -> String? {
        var text = invocationWords.trimmingCharacters(in: .whitespaces)
        if text.lowercased().hasPrefix(lexicon.grammar.statement.invokePrefix) {
            text = String(text.dropFirst(lexicon.grammar.statement.invokePrefix.count)).trimmingCharacters(in: .whitespaces)
        }
        let tokens = text.split(separator: " ").map(String.init)
        guard tokens.count > 1 else { return nil }

        var objectWords: [String] = []
        for token in tokens.dropFirst() {
            let cleaned = token.trimmingCharacters(in: CharacterSet(charactersIn: ",;:."))
            let lower = cleaned.lowercased()
            if lexicon.prepositions.contains(lower) {
                break
            }
            if lexicon.articles.contains(lower) { continue }
            objectWords.append(cleaned)
        }
        guard !objectWords.isEmpty else { return nil }
        return camelCase(objectWords.joined(separator: " "))
    }

}
