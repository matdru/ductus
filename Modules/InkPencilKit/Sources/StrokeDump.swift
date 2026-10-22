import Foundation
import PencilKit

/// Raw PencilKit control points, including the size PencilKit chose for each one. Feel Lab exports
/// this to study how PencilKit maps Pencil input (force, speed, tilt) to ink.
public struct StrokeDump: Codable, Equatable, Sendable {
    public struct Point: Codable, Equatable, Sendable {
        public var x: Double
        public var y: Double
        public var timeOffset: Double
        public var force: Double
        public var azimuth: Double
        public var altitude: Double
        public var width: Double
        public var height: Double
        public var opacity: Double
    }

    public struct Entry: Codable, Equatable, Sendable {
        public var ink: String
        public var points: [Point]
    }

    public var strokes: [Entry]

    public init(drawing: PKDrawing) {
        strokes = drawing.strokes.map { stroke in
            Entry(
                ink: String(describing: stroke.ink.inkType),
                points: stroke.path.map { point in
                    let location = point.location.applying(stroke.transform)
                    return Point(
                        x: location.x, y: location.y, timeOffset: point.timeOffset, force: point.force,
                        azimuth: point.azimuth, altitude: point.altitude, width: point.size.width,
                        height: point.size.height, opacity: point.opacity)
                })
        }
    }
}
