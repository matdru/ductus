import InkCore
import Testing

@testable import FeelLab

@MainActor
struct FeelLabModelTests {
    @Test func activeSurfaceFollowsEngine() {
        let model = FeelLabModel(allowsFingerDrawing: false)
        model.engine = .pencilKit
        #expect(model.activeView === model.pencilKitSurface)
        model.engine = .custom
        #expect(model.activeView === model.customSurface)
    }

    @Test func fingerDrawingAppliesToBothEngines() {
        let model = FeelLabModel(allowsFingerDrawing: true)
        #expect(model.pencilKitSurface.allowsFingerDrawing)
        #expect(model.customSurface.allowsFingerDrawing)
    }

    @Test func onlySingleModeIsAvailable() {
        #expect(ComparisonMode.allCases.filter(\.isAvailable) == [.single])
    }

    @Test func switchingEnginesKeepsEachEnginesInk() {
        let model = FeelLabModel(allowsFingerDrawing: false)
        let stroke = Stroke(
            tool: .defaultPen, samples: [StrokeSample(x: 1, y: 1, force: 1, altitude: 1, azimuth: 0, timestamp: 0)])
        model.engine = .custom
        model.activeSurface.load([stroke])
        model.engine = .pencilKit
        model.engine = .custom
        #expect(model.activeSurface.exportStrokes() == [stroke])
    }
}
