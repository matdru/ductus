import Foundation

/// Direction-driven fountain nib: thin along `nibAngle`, thick across it.
public enum NibModel {
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
