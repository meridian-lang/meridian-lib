import Foundation

public struct LoweredDefinitionInfo: Sendable {
    public let adjective: String
    public let kind: String
    public let subjectVar: String
    public let functionName: String
    public let body: IRExpression
    public let sourceLine: Int
    public let isInline: Bool

    public init(
        adjective: String,
        kind: String,
        subjectVar: String,
        functionName: String,
        body: IRExpression,
        sourceLine: Int,
        isInline: Bool
    ) {
        self.adjective = adjective
        self.kind = kind
        self.subjectVar = subjectVar
        self.functionName = functionName
        self.body = body
        self.sourceLine = sourceLine
        self.isInline = isInline
    }
}

public struct VerbalizerModel: Sendable {
    public let workflows: [IRWorkflow]
    public let loweredDefinitions: [LoweredDefinitionInfo]
    public let inlineDefinitions: [DefinitionDeclaration]
    public let symbols: SymbolTable
    public let lexicon: EnglishLexicon
    public let sourceFileName: String
    public let authoredSource: String
    public let metadata: FileMetadataAST?
    public let outline: [HeadingEntry]
    public let skillSections: [SkillSectionRecord]
    public let toolsUsed: [String]

    public init(
        workflows: [IRWorkflow],
        loweredDefinitions: [LoweredDefinitionInfo],
        inlineDefinitions: [DefinitionDeclaration],
        symbols: SymbolTable,
        lexicon: EnglishLexicon,
        sourceFileName: String,
        authoredSource: String,
        metadata: FileMetadataAST? = nil,
        outline: [HeadingEntry] = [],
        skillSections: [SkillSectionRecord] = [],
        toolsUsed: [String] = []
    ) {
        self.workflows = workflows
        self.loweredDefinitions = loweredDefinitions
        self.inlineDefinitions = inlineDefinitions
        self.symbols = symbols
        self.lexicon = lexicon
        self.sourceFileName = sourceFileName
        self.authoredSource = authoredSource
        self.metadata = metadata
        self.outline = outline
        self.skillSections = skillSections
        self.toolsUsed = toolsUsed
    }
}
