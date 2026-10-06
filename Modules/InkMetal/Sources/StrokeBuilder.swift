import Foundation
import InkCore

/// Accumulates samples for the stroke currently being drawn. Committed samples are real input;
/// predicted samples are a disposable tail replaced on every touch event and never exported.
public struct StrokeBuilder: Sendable {
    public let tool: InkTool
    public let id: UUID
    public private(set) var committed: [StrokeSample] = []
    public private(set) var predicted: [StrokeSample] = []

    public init(tool: InkTool, id: UUID = UUID()) {
        self.tool = tool
        self.id = id
    }

    public mutating func append(committed newCommitted: [StrokeSample], predicted newPredicted: [StrokeSample]) {
        committed += newCommitted
        predicted = newPredicted
    }

    public var displaySamples: [StrokeSample] { committed + predicted }

    public func finish() -> Stroke? {
        committed.isEmpty ? nil : Stroke(id: id, tool: tool, samples: committed)
    }
}
