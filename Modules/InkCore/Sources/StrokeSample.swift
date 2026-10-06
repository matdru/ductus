import Foundation

/// One raw input sample, in canvas points. Angles are radians, as reported by UITouch.
public struct StrokeSample: Sendable, Codable, Equatable {
    public var x: Double
    public var y: Double
    /// UITouch.force: 1.0 is an average touch; 0 when the input has no force (finger, simulator).
    public var force: Double
    public var altitude: Double
    public var azimuth: Double
    public var timestamp: TimeInterval

    public init(x: Double, y: Double, force: Double, altitude: Double, azimuth: Double, timestamp: TimeInterval) {
        self.x = x
        self.y = y
        self.force = force
        self.altitude = altitude
        self.azimuth = azimuth
        self.timestamp = timestamp
    }
}
