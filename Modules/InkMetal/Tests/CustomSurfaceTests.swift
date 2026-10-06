import InkCore
import QuartzCore
import Testing
import UIKit

@testable import InkMetal

@MainActor
struct CustomSurfaceTests {
    func stroke(_ x: Double) -> Stroke {
        Stroke(tool: .defaultPen, samples: [StrokeSample(x: x, y: 0, force: 1, altitude: 1, azimuth: 0, timestamp: 0)])
    }

    @Test func drawableSizeTracksBoundsTimesScale() {
        let surface = CustomSurface(frame: CGRect(x: 0, y: 0, width: 300, height: 200))
        surface.layoutIfNeeded()
        let scale = surface.contentScaleFactor
        #expect(surface.metalLayer.drawableSize == CGSize(width: 300 * scale, height: 200 * scale))

        // Rotation / Split View / Stage Manager resize.
        surface.frame = CGRect(x: 0, y: 0, width: 200, height: 500)
        surface.layoutIfNeeded()
        #expect(surface.metalLayer.drawableSize == CGSize(width: 200 * scale, height: 500 * scale))
    }

    @Test func loadUndoClearAndExport() {
        let surface = CustomSurface()
        let a = stroke(0)
        let b = stroke(10)
        surface.load([a, b])
        #expect(surface.exportStrokes() == [a, b])
        surface.undo()
        #expect(surface.exportStrokes() == [a])
        surface.clear()
        #expect(surface.exportStrokes().isEmpty)
    }

    @Test func clearIsNotUndoable() {
        let surface = CustomSurface()
        surface.load([stroke(0)])
        surface.clear()
        surface.undo()
        #expect(surface.exportStrokes().isEmpty)
    }

    @Test func undoAndClearOnEmptySurfaceAreNoOps() {
        let surface = CustomSurface()
        surface.undo()
        surface.clear()
        #expect(surface.exportStrokes().isEmpty)
    }

    @Test func pencilOnlyByDefault() {
        #expect(CustomSurface().allowsFingerDrawing == false)
    }
}
