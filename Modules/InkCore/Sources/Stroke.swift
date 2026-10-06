import Foundation

public struct Stroke: Sendable, Codable, Equatable, Identifiable {
    public let id: UUID
    public var tool: InkTool
    public var samples: [StrokeSample]

    public init(id: UUID = UUID(), tool: InkTool, samples: [StrokeSample]) {
        self.id = id
        self.tool = tool
        self.samples = samples
    }
}
