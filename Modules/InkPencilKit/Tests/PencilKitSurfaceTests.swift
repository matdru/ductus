import InkCore
import PencilKit
import Testing

@testable import InkPencilKit

@MainActor
struct PencilKitSurfaceTests {
    func stroke(_ x: Double) -> Stroke {
        Stroke(
            tool: .defaultPen,
            samples: [
                StrokeSample(x: x, y: 0, force: 1, altitude: 1, azimuth: 0, timestamp: 0),
                StrokeSample(x: x + 10, y: 10, force: 1, altitude: 1, azimuth: 0, timestamp: 0.01),
            ])
    }

    @Test func loadThenExportReturnsSameStrokeCount() {
        let surface = PencilKitSurface()
        surface.load([stroke(0), stroke(50)])
        #expect(surface.exportStrokes().count == 2)
    }

    @Test func undoRemovesMostRecentStroke() throws {
        let surface = PencilKitSurface()
        surface.load([stroke(0), stroke(50)])
        surface.undo()
        let remaining = try #require(surface.exportStrokes().first)
        #expect(surface.exportStrokes().count == 1)
        #expect(abs(remaining.samples[0].x) < 1e-3)
    }

    @Test func undoAndClearOnEmptySurfaceAreNoOps() {
        let surface = PencilKitSurface()
        surface.undo()
        surface.clear()
        #expect(surface.exportStrokes().isEmpty)
    }

    @Test func clearRemovesEverything() {
        let surface = PencilKitSurface()
        surface.load([stroke(0)])
        surface.clear()
        #expect(surface.exportStrokes().isEmpty)
    }

    @Test func fingerDrawingTogglesDrawingPolicy() {
        let surface = PencilKitSurface()
        #expect(surface.canvasView.drawingPolicy == .pencilOnly)
        surface.allowsFingerDrawing = true
        #expect(surface.canvasView.drawingPolicy == .anyInput)
    }

    @Test func setToolUpdatesCanvasTool() throws {
        let surface = PencilKitSurface()
        surface.setTool(InkTool(kind: .highlighter, color: .black, width: 12))
        let tool = try #require(surface.canvasView.tool as? PKInkingTool)
        #expect(tool.inkType == .marker)
        #expect(abs(tool.width - 12) < 1e-3)
    }
}
