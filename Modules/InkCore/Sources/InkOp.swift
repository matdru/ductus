import Foundation

/// One entry in the append-only operation log. Persisting the log comes in Phase 1.
public enum InkOp: Sendable, Codable, Equatable {
    case addStroke(Stroke)
    case removeStroke(UUID)
    case clear
}
