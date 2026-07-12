import MeridianRuntime

extension IRPrimitive {
    var sourceRange: SourceRange {
        switch self {
        case .invoke(let ir): return ir.sourceRange
        case .bind(let ir): return ir.sourceRange
        case .branch(let ir): return ir.sourceRange
        case .iterate(let ir): return ir.sourceRange
        case .assert(let ir): return ir.sourceRange
        case .emit(let ir): return ir.sourceRange
        case .wait(let ir): return ir.sourceRange
        case .commit(let ir): return ir.sourceRange
        case .recover(let ir): return ir.sourceRange
        case .simultaneously(let ir): return ir.sourceRange
        case .aiJudgment(let ir): return ir.sourceRange
        case .aiAutonomy(let ir): return ir.sourceRange
        case .complete(let ir): return ir.sourceRange
        }
    }

    var stableStepPath: String? {
        switch self {
        case .invoke(let ir): return ir.stableStepPath
        case .bind(let ir): return ir.stableStepPath
        case .branch(let ir): return ir.stableStepPath
        case .iterate(let ir): return ir.stableStepPath
        case .assert(let ir): return ir.stableStepPath
        case .emit(let ir): return ir.stableStepPath
        case .wait(let ir): return ir.stableStepPath
        case .commit(let ir): return ir.stableStepPath
        case .recover(let ir): return ir.stableStepPath
        case .simultaneously(let ir): return ir.stableStepPath
        case .aiJudgment(let ir): return ir.stableStepPath
        case .aiAutonomy(let ir): return ir.stableStepPath
        case .complete(let ir): return ir.stableStepPath
        }
    }
}
