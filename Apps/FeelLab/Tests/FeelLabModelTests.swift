import Foundation
import InkCore
import InkPencilKit
import PencilKit
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

    @Test func pencilKitToolReachesTheSurface() {
        let model = FeelLabModel(allowsFingerDrawing: false)
        model.pencilKitTool = .eraser(.bitmap)
        #expect(model.pencilKitSurface.selectedTool == .eraser(.bitmap))
    }

    @Test func exportWritesThePencilKitStrokesAsJSON() throws {
        let model = FeelLabModel(allowsFingerDrawing: false)
        model.pencilKitSurface.load([
            Stroke(
                tool: .defaultPen,
                samples: [
                    StrokeSample(x: 0, y: 0, force: 1, altitude: 1, azimuth: 0, timestamp: 0),
                    StrokeSample(x: 10, y: 10, force: 1, altitude: 1, azimuth: 0, timestamp: 0.01),
                ])
        ])
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let url = try model.exportPencilKitStrokes(to: directory)

        let dump = try JSONDecoder().decode(StrokeDump.self, from: Data(contentsOf: url))
        #expect(dump.strokes.count == 1)
        #expect(url.lastPathComponent.hasPrefix("strokes-"))
    }

    @Test func customToolDefaultsToFountain() {
        let model = FeelLabModel(allowsFingerDrawing: false)
        #expect(model.customTool == .fountainPen)
        #expect(model.customSurface.tool == .fountainPen)
    }

    @Test func customToolReachesTheSurface() {
        let model = FeelLabModel(allowsFingerDrawing: false)
        model.customTool = .pen
        #expect(model.customSurface.tool == .defaultPen)
    }
}
