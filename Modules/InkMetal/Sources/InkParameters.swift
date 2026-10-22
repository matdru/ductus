/// Tunable knobs for the custom engine's inks. Defaults are fitted to PencilKit's fountain pen
/// (see docs/superpowers/specs/2026-10-22-fountain-pen-design.md).
public struct InkParameters: Sendable, Codable, Equatable {
    /// Fountain-nib width across the nib's thin and broad directions, in points.
    public var thinWidth: Double
    public var thickWidth: Double
    /// Direction of the thinnest stroke, screen coordinates (y down).
    public var nibAngleDegrees: Double
    /// How quickly width rises away from the thin direction; higher keeps diagonals thinner.
    public var sharpness: Double
    /// Adds the Pencil's azimuth to the nib angle.
    public var followsPencilLean: Bool
    /// 0 ignores force; 1 scales width by `force ^ pressureCurve`.
    public var pressureAmount: Double
    public var pressureCurve: Double
    /// 0 ignores speed; 1 halves width at 1,000 pt/s.
    public var speedThinning: Double
    /// 0 is raw input; 1 is the strongest smoothing (lag still capped at 0.5 pt).
    public var smoothing: Double
    public var predictionEnabled: Bool
    /// Draws with the original constant-width quads, for before/after comparison.
    public var baselineRenderer: Bool

    public static let defaults = InkParameters(
        thinWidth: 1.35, thickWidth: 8.9, nibAngleDegrees: -10, sharpness: 3.5, followsPencilLean: false,
        pressureAmount: 0, pressureCurve: 1, speedThinning: 0, smoothing: 0.5, predictionEnabled: true,
        baselineRenderer: false)

    /// Identifies `defaults`; bump whenever the baked defaults change.
    public static let defaultsID = "2026-10-22-pencilkit-fit"
}
