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
    /// Nib shape, thin side ÷ broad side: 1 is a round nib; PencilKit's is about 0.25. A round nib leaves blobs at
    /// tight turns and pen lifts, because its full thick width shows in every direction.
    public var nibRoundness: Double
    /// Adds the Pencil's azimuth to the nib angle (width only; the oval keeps the base nib angle).
    public var followsPencilLean: Bool
    /// 0 ignores force; 1 scales width by `force ^ pressureCurve`.
    public var pressureAmount: Double
    public var pressureCurve: Double
    /// 0 ignores speed; 1 halves width at 1,000 pt/s.
    public var speedThinning: Double
    /// 0 is raw input; 1 is the strongest smoothing (lag still capped at 0.5 pt).
    public var smoothing: Double
    /// Hand-steadying: keep a point every this many points and draw a smooth curve through them. 0 is off.
    public var steadiness: Double
    /// Hand-steadying leash: the smoothed ink follows this many points behind the pen. 0 is off.
    public var trail: Double
    public var predictionEnabled: Bool
    /// Draws with the original constant-width quads, for before/after comparison.
    public var baselineRenderer: Bool

    public static let defaults = InkParameters(
        thinWidth: 1.35, thickWidth: 8.9, nibAngleDegrees: -10, sharpness: 3.5, nibRoundness: 0.25,
        followsPencilLean: false,
        pressureAmount: 0, pressureCurve: 1, speedThinning: 0, smoothing: 0.5, steadiness: 6, trail: 2.5,
        predictionEnabled: true,
        baselineRenderer: false)

    /// Identifies `defaults`; bump whenever the baked defaults change.
    public static let defaultsID = "2026-10-22-pencilkit-fit"
}

extension InkParameters {
    private enum CodingKeys: String, CodingKey {
        case thinWidth, thickWidth, nibAngleDegrees, sharpness, nibRoundness, followsPencilLean, pressureAmount
        case pressureCurve
        case speedThinning, smoothing, steadiness, trail, predictionEnabled, baselineRenderer
    }

    /// Missing keys take their default, so settings saved before a parameter existed still load.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        var parameters = InkParameters.defaults
        func decode<Value: Decodable>(_ keyPath: WritableKeyPath<InkParameters, Value>, _ key: CodingKeys) throws {
            if let value = try container.decodeIfPresent(Value.self, forKey: key) {
                parameters[keyPath: keyPath] = value
            }
        }
        try decode(\.thinWidth, .thinWidth)
        try decode(\.thickWidth, .thickWidth)
        try decode(\.nibAngleDegrees, .nibAngleDegrees)
        try decode(\.sharpness, .sharpness)
        try decode(\.nibRoundness, .nibRoundness)
        try decode(\.followsPencilLean, .followsPencilLean)
        try decode(\.pressureAmount, .pressureAmount)
        try decode(\.pressureCurve, .pressureCurve)
        try decode(\.speedThinning, .speedThinning)
        try decode(\.smoothing, .smoothing)
        try decode(\.steadiness, .steadiness)
        try decode(\.trail, .trail)
        try decode(\.predictionEnabled, .predictionEnabled)
        try decode(\.baselineRenderer, .baselineRenderer)
        self = parameters
    }
}
