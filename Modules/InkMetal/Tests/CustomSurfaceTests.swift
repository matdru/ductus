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
        let scale: CGFloat = 2
        surface.traitOverrides.displayScale = scale
        surface.updateTraitsIfNeeded()
        surface.layoutIfNeeded()
        #expect(surface.metalLayer.drawableSize == CGSize(width: 300 * scale, height: 200 * scale))

        // Rotation / Split View / Stage Manager resize.
        surface.frame = CGRect(x: 0, y: 0, width: 200, height: 500)
        surface.layoutIfNeeded()
        #expect(surface.metalLayer.drawableSize == CGSize(width: 200 * scale, height: 500 * scale))
    }

    /// A CAMetalLayer-backed view keeps contentScaleFactor at 1 even on Retina screens,
    /// so the drawable must be sized from the display scale trait.
    @Test func drawableUsesDisplayScale() {
        let surface = CustomSurface(frame: CGRect(x: 0, y: 0, width: 300, height: 200))
        surface.traitOverrides.displayScale = 3
        surface.updateTraitsIfNeeded()
        surface.setNeedsLayout()
        surface.layoutIfNeeded()
        #expect(surface.metalLayer.drawableSize == CGSize(width: 900, height: 600))
        #expect(surface.metalLayer.contentsScale == 3)
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

    /// With multi-touch off, UIKit delivers only the first touch: a resting palm would
    /// swallow the Pencil. The surface's own guards keep it to one stroke at a time.
    @Test func restingPalmDoesNotBlockPencilDelivery() {
        #expect(CustomSurface().isMultipleTouchEnabled)
    }

    /// If a frame can't be drawn (no drawable, zero viewport), the pending render must survive
    /// so the next display-link tick retries — otherwise the stroke-end frame can be lost.
    @Test func failedRenderStaysPending() {
        let surface = CustomSurface(frame: .zero)
        surface.load([stroke(0)])
        surface.renderIfNeeded()
        #expect(surface.needsRender)
    }

    @Test func pencilOnlyByDefault() {
        #expect(CustomSurface().allowsFingerDrawing == false)
    }

    @Test func parameterChangeRebuildsCache() {
        let surface = CustomSurface()
        surface.cacheNeedsRebuild = false
        surface.parameters.thickWidth = 5
        #expect(surface.cacheNeedsRebuild)
        #expect(surface.needsRender)
    }

    /// A stroke that finishes on a frame that can't present must still reach the page cache later.
    @Test func finishedStrokeSurvivesFailedFrame() {
        let surface = CustomSurface(frame: .zero)
        surface.commitActiveStroke(stroke(0))
        surface.renderIfNeeded()
        #expect(surface.pendingAppends.count == 1)
        #expect(surface.exportStrokes().count == 1)
    }

    @Test func resizeRequestsRebuild() {
        let surface = CustomSurface(frame: CGRect(x: 0, y: 0, width: 300, height: 200))
        surface.traitOverrides.displayScale = 2
        surface.updateTraitsIfNeeded()
        surface.layoutIfNeeded()
        surface.cacheNeedsRebuild = false
        surface.frame = CGRect(x: 0, y: 0, width: 200, height: 500)
        surface.layoutIfNeeded()
        #expect(surface.cacheNeedsRebuild)
    }

    @Test func undoAndLoadRebuildCache() {
        let surface = CustomSurface()
        surface.cacheNeedsRebuild = false
        surface.load([stroke(0), stroke(10)])
        #expect(surface.cacheNeedsRebuild)
        surface.cacheNeedsRebuild = false
        surface.undo()
        #expect(surface.cacheNeedsRebuild)
    }

    /// The page cache is blitted into the drawable, which needs identical whole-pixel sizes.
    @Test func drawableSizeIsWholePixels() {
        let surface = CustomSurface(frame: CGRect(x: 0, y: 0, width: 100.4, height: 50.3))
        surface.traitOverrides.displayScale = 3
        surface.updateTraitsIfNeeded()
        surface.layoutIfNeeded()
        #expect(surface.metalLayer.drawableSize == CGSize(width: 301, height: 151))
    }
}
