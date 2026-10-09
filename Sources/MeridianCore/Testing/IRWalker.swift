import Foundation

// MARK: - IRWalker

/// Recursive traversal utilities over `[IRWorkflow]`.
/// All methods are static so callers don't need to hold an instance.
public enum IRWalker {

    // MARK: - Flat primitive collection

    /// Collect every `IRPrimitive` across all workflows, including those
    /// nested inside branch/iterate/assert/recover sub-blocks.
    public static func flatPrimitives(workflows: [IRWorkflow]) -> [IRPrimitive] {
        workflows.flatMap { flatPrimitives($0.body) }
    }

    /// Collect every `IRPrimitive` in `block`, recursively.
    public static func flatPrimitives(_ block: IRBlock) -> [IRPrimitive] {
        var result: [IRPrimitive] = []
        for prim in block.statements {
            result.append(prim)
            for child in childBlocks(of: prim) {
                result.append(contentsOf: flatPrimitives(child))
            }
        }
        return result
    }

    // MARK: - Count by kind

    /// Count all occurrences of a given primitive kind across all workflows.
    public static func count(kind: IRPrimitiveKind, in workflows: [IRWorkflow]) -> Int {
        flatPrimitives(workflows: workflows).filter { matches(kind: kind, prim: $0) }.count
    }

    // MARK: - Unresolved binds

    /// True when at least one `BindIR(name: "_unresolved")` exists anywhere.
    public static func hasUnresolved(in workflows: [IRWorkflow]) -> Bool {
        flatPrimitives(workflows: workflows).contains { prim in
            if case .bind(let b) = prim { return b.name == "_unresolved" }
            return false
        }
    }

    ///: true when any `AssertIR` anywhere is a "blocking site" —
    /// an ordinary (non-monitored) assert, which is inherently blocking
    /// because its failure always throws, OR a monitored statistical assert
    /// that carries the explicit `, blocking` suffix. Mirrors
    /// `ASTToIR`'s own `let blockingSite = !monitored || blocking` used for
    /// the MER-TMP unknown-arm-policy check, since both answer the same
    /// underlying question: does this skill have an assertion whose failure
    /// (or missed witnessing of that failure) must halt execution.
    public static func hasBlockingAssert(in workflows: [IRWorkflow]) -> Bool {
        flatPrimitives(workflows: workflows).contains { prim in
            guard case .assert(let a) = prim else { return false }
            return !a.monitored || a.blocking
        }
    }

    // MARK: - Specific searches

    /// All distinct tool IDs appearing in any InvokeIR.
    public static func allToolIDs(in workflows: [IRWorkflow]) -> Set<String> {
        var ids: Set<String> = []
        for prim in flatPrimitives(workflows: workflows) {
            if case .invoke(let inv) = prim { ids.insert(inv.toolID) }
        }
        return ids
    }

    /// All distinct event IDs appearing in any EmitIR.
    public static func allEventIDs(in workflows: [IRWorkflow]) -> Set<String> {
        var ids: Set<String> = []
        for prim in flatPrimitives(workflows: workflows) {
            if case .emit(let em) = prim { ids.insert(em.eventID) }
        }
        return ids
    }

    /// All distinct domain kind names referenced anywhere in `workflows`:
    /// parameter types, `for each`/`until` iteration subjects
    /// (`IterateMode.overCollection`), and typed `recover where` patterns
    /// (`ErrorPattern.typed`). Used for the manifest's `kinds_used` (C5-adjacent
    /// audit data) — see `Compiler.CompiledFile.manifest`.
    public static func allKindNames(in workflows: [IRWorkflow]) -> Set<String> {
        var names: Set<String> = []
        for wf in workflows {
            for param in wf.parameters { names.insert(param.kind.name) }
        }
        for prim in flatPrimitives(workflows: workflows) {
            switch prim {
            case .iterate(let i):
                if case .overCollection(_, let kind, _) = i.mode { names.insert(kind.name) }
            case .recover(let r):
                if case .typed(let kind) = r.pattern { names.insert(kind.name) }
            default:
                break
            }
        }
        return names
    }

    // MARK: - Private

    private static func childBlocks(of prim: IRPrimitive) -> [IRBlock] {
        switch prim {
        case .invoke:                               return []
        case .bind:                                 return []
        case .complete:                             return []
        case .emit:                                 return []
        case .wait:                                 return []
        case .commit:                               return []
        case .aiJudgment:                           return []
        case .aiAutonomy:                           return []
        case .branch(let b):
            var blocks: [IRBlock] = [b.thenBlock]
            if let el = b.elseBlock { blocks.append(el) }
            return blocks
        case .iterate(let i):                       return [i.body]
        case .assert(let a):
            return a.otherwiseAction.map { [$0] } ?? []
        case .recover(let r):                       return [r.handler, r.attachedTo]
        case .simultaneously(let s):                return s.branches
        }
    }

    private static func matches(kind: IRPrimitiveKind, prim: IRPrimitive) -> Bool {
        switch (kind, prim) {
        case (.invoke,   .invoke):   return true
        case (.bind,     .bind):     return true
        case (.branch,   .branch):   return true
        case (.emit,     .emit):     return true
        case (.complete, .complete): return true
        case (.wait,     .wait):     return true
        case (.iterate,  .iterate):  return true
        case (.assert,   .assert):   return true
        case (.commit,   .commit):   return true
        case (.recover,  .recover):  return true
        case (.simultaneously, .simultaneously): return true
        case (.aiJudgment, .aiJudgment): return true
        case (.aiAutonomy, .aiAutonomy): return true
        default:                     return false
        }
    }
}
