import Foundation
import Testing

@testable import InkMetal

struct NibModelTests {
    func width(
        _ degrees: Double, force: Double = 1, speed: Double = 300, azimuth: Double = .pi,
        _ parameters: InkParameters = .defaults
    ) -> Double {
        NibModel.width(
            direction: degrees * .pi / 180, force: force, speed: speed, azimuth: azimuth, parameters: parameters)
    }

    /// Rendered PencilKit fountain-pen widths measured from the author's strokes (→ ↘ ↓ ↗).
    @Test func defaultsMatchPencilKitWithinTolerance() {
        for (degrees, expected) in [(0.0, 1.3), (45, 5.2), (90, 7.8), (315, 2.2)] {
            #expect(abs(width(degrees) - expected) <= 0.75, "direction \(degrees)°")
        }
    }

    @Test func widthIsSymmetricForOppositeDirections() {
        for degrees in stride(from: 0.0, to: 360, by: 15) {
            #expect(abs(width(degrees) - width(degrees + 180)) < 1e-9)
        }
    }

    @Test func defaultsIgnorePressureAndSpeed() {
        #expect(width(60, force: 0.1) == width(60, force: 4))
        #expect(width(60, speed: 50) == width(60, speed: 1500))
    }

    @Test func pressureAmountWidensHardStrokes() {
        var parameters = InkParameters.defaults
        parameters.pressureAmount = 1
        #expect(width(90, force: 2, parameters) > width(90, force: 1, parameters))
    }

    @Test func speedThinningNarrowsFastStrokes() {
        var parameters = InkParameters.defaults
        parameters.speedThinning = 1
        #expect(width(90, speed: 1000, parameters) < width(90, speed: 100, parameters))
    }

    @Test func zeroForceNeverVanishes() {
        var parameters = InkParameters.defaults
        parameters.pressureAmount = 1
        for degrees in stride(from: 0.0, to: 360, by: 10) {
            #expect(width(degrees, force: 0, parameters) >= 0.25)
        }
    }

    @Test func followsPencilLeanRotatesNib() {
        var parameters = InkParameters.defaults
        parameters.followsPencilLean = true
        let base = 0.3
        #expect(abs(width(0, azimuth: base, parameters) - width(90, azimuth: base + .pi / 2, parameters)) < 1e-9)
        #expect(abs(width(90, azimuth: base, parameters) - width(180, azimuth: base + .pi / 2, parameters)) < 1e-9)
        #expect(width(0, azimuth: base, parameters) != width(0, azimuth: base + .pi / 2, parameters))
    }

    @Test func parametersRoundTripThroughJSON() throws {
        let data = try JSONEncoder().encode(InkParameters.defaults)
        #expect(try JSONDecoder().decode(InkParameters.self, from: data) == .defaults)
    }
}
