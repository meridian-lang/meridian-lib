public protocol LLMBackedPlanner: Planner {
    init(provider: any LLMProvider)
}

public protocol LLMBackedActPlanner: ActPlanner {
    init(provider: any LLMProvider)
}

public protocol LLMBackedDiscretion: Discretion {
    init(provider: any LLMProvider)
}
