import Foundation
import MeridianRuntime

public struct PlanFuzzer: Sendable {
    public let seed: UInt64

    public init(seed: UInt64 = 0x5EED) {
        self.seed = seed
    }

    public func proposals(toolIDs: [String], count: Int) -> [PlanProposal] {
        guard !toolIDs.isEmpty, count > 0 else { return [] }
        return (0..<count).map { idx in
            let tool = toolIDs[Int((UInt64(idx) &+ seed) % UInt64(toolIDs.count))]
            return PlanProposal(actions: [
                ProposedAction(
                    toolID: tool,
                    arguments: ["seed": .number(Decimal(seed)), "index": .number(Decimal(idx))],
                    resultBinding: "result\(idx)"
                )
            ])
        }
    }
}
