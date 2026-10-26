import Foundation
import InkCore

/// The pen tip's footprint: an oval whose long axis lies along `angle`, `roundness` times as wide across it.
/// Strokes are drawn in "nib space", where this oval becomes a unit circle, so the capsule shader sweeps an oval.
public struct NibShape: Sendable, Equatable {
    public var angle: Double
    public var roundness: Double

    public static let circle = NibShape(angle: 0, roundness: 1)

    public init(angle: Double, roundness: Double) {
        self.angle = angle
        self.roundness = min(max(roundness, 0.05), 1)
    }

    /// Swept width of the unit oval (long half-axis 1) moving in `direction` (radians).
    public func width(acrossDirection direction: Double) -> Double {
        let offset = direction - angle
        return 2 * (sin(offset) * sin(offset) + roundness * roundness * cos(offset) * cos(offset)).squareRoot()
    }

    /// Screen point → nib space: rotate the long axis onto x, then stretch y by 1 / roundness.
    public func toNibSpace(x: Double, y: Double) -> (x: Double, y: Double) {
        let c = cos(angle)
        let s = sin(angle)
        return (c * x + s * y, (-s * x + c * y) / roundness)
    }

    /// Row-major 2×2 matrix of `toNibSpace`, for the shader.
    var matrix: SIMD4<Float> {
        SIMD4(Float(cos(angle)), Float(sin(angle)), Float(-sin(angle) / roundness), Float(cos(angle) / roundness))
    }

    /// Half extents in screen points of the oval scaled by `scale`.
    func extents(scale: Double) -> (x: Double, y: Double) {
        let c = cos(angle)
        let s = sin(angle)
        let r = roundness
        return (scale * (c * c + r * r * s * s).squareRoot(), scale * (s * s + r * r * c * c).squareRoot())
    }
}

/// Direction-driven fountain nib: thin along `nibAngle`, thick across it.
public enum NibModel {
    /// Fountain pens draw with an oval nib along the thin direction; other tools use a round tip.
    public static func shape(for tool: InkTool, parameters: InkParameters) -> NibShape {
        guard tool.kind == .fountainPen else { return .circle }
        return NibShape(angle: parameters.nibAngleDegrees * .pi / 180, roundness: parameters.nibRoundness)
    }

    static let minimumWidth = 0.25

    /// Fountain-pen width in points. `direction` is radians in screen coordinates; `speed` is pt/s.
    public static func width(
        direction: Double, force: Double, speed: Double, azimuth: Double, parameters: InkParameters
    ) -> Double {
        var nib = parameters.nibAngleDegrees * .pi / 180
        if parameters.followsPencilLean { nib += azimuth }
        let across = pow(abs(sin(direction - nib)), parameters.sharpness)
        var width = parameters.thinWidth + (parameters.thickWidth - parameters.thinWidth) * across
        if parameters.pressureAmount > 0 {
            let pressure = pow(min(max(force, 0), 4), parameters.pressureCurve)
            width *= 1 + parameters.pressureAmount * (pressure - 1)
        }
        if parameters.speedThinning > 0 {
            width /= 1 + parameters.speedThinning * max(speed, 0) / 1000
        }
        return max(width, minimumWidth)
    }
}
