import Foundation
import NotebookCore
import NotebookStore
import PencilKit
import Testing
import UIKit

@testable import Ductus

@MainActor
struct UndoTests {
    let store = NotebookStore(
        root: FileManager.default.temporaryDirectory.appending(path: "UndoTests-\(UUID().uuidString)"))

    func stroke(at point: CGPoint, created: Date = Date()) -> PKStroke {
        let points = (0..<5).map { i in
            PKStrokePoint(
                location: CGPoint(x: point.x - 10 + Double(i) * 5, y: point.y), timeOffset: Double(i) * 0.01,
                size: CGSize(width: 3, height: 3), opacity: 1, force: 1, azimuth: 0, altitude: .pi / 2)
        }
        return PKStroke(
            ink: PKInk(.pen, color: .black), path: PKStrokePath(controlPoints: points, creationDate: created))
    }

    // MARK: What changed

    @Test func noChangeHasNoBounds() {
        let drawing = PKDrawing(strokes: [stroke(at: CGPoint(x: 100, y: 100))])
        #expect(DrawingChange.bounds(from: drawing, to: drawing) == nil)
    }

    @Test func anAddedStrokeIsTheChange() throws {
        let kept = stroke(at: CGPoint(x: 100, y: 100))
        let added = stroke(at: CGPoint(x: 400, y: 2000))
        let change = try #require(
            DrawingChange.bounds(from: PKDrawing(strokes: [kept]), to: PKDrawing(strokes: [kept, added])))
        #expect(change.contains(CGPoint(x: 400, y: 2000)))
        #expect(!change.contains(CGPoint(x: 100, y: 100)))
    }

    @Test func aRemovedStrokeIsTheChange() throws {
        let kept = stroke(at: CGPoint(x: 100, y: 100))
        let removed = stroke(at: CGPoint(x: 300, y: 900))
        let change = try #require(
            DrawingChange.bounds(from: PKDrawing(strokes: [kept, removed]), to: PKDrawing(strokes: [kept])))
        #expect(change.contains(CGPoint(x: 300, y: 900)))
    }

    @Test func aMovedStrokeCoversBothPlaces() throws {
        let original = stroke(at: CGPoint(x: 100, y: 100))
        var moved = original
        moved.transform = CGAffineTransform(translationX: 0, y: 500)
        let change = try #require(
            DrawingChange.bounds(from: PKDrawing(strokes: [original]), to: PKDrawing(strokes: [moved])))
        #expect(change.contains(CGPoint(x: 100, y: 100)) && change.contains(CGPoint(x: 100, y: 600)))
    }

    // MARK: Finger taps

    @Test func palmSizedTouchesAreIgnored() {
        #expect(FingerTap.isFinger(majorRadius: 8))
        #expect(FingerTap.isFinger(majorRadius: 24))
        #expect(!FingerTap.isFinger(majorRadius: 73))
    }

    /// Radii come in steps of about 10.4pt. Recorded on an iPad Pro: fingertips at 20.9 and 31.3, a firmer press at
    /// 41.7, and a resting palm landing at 52.1 before growing to 73.
    @Test func aFirmlyPressedFingertipStillCounts() {
        #expect(FingerTap.isFinger(majorRadius: 41.7))
        #expect(!FingerTap.isFinger(majorRadius: 52.1))
    }

    @Test func eachTapCanBeTurnedOff() {
        let view = UIView()
        let fingerTap = FingerTap(on: view, undo: {}, redo: {})
        fingerTap.setEnabled(undo: false, redo: true)
        let taps = view.gestureRecognizers?.compactMap { $0 as? UITapGestureRecognizer } ?? []
        #expect(taps.first { $0.numberOfTouchesRequired == 2 }?.isEnabled == false)
        #expect(taps.first { $0.numberOfTouchesRequired == 3 }?.isEnabled == true)
    }

    @Test func otherTapsWaitForTheFingerTaps() {
        let view = UIView()
        let fingerTap = FingerTap(on: view, undo: {}, redo: {})
        let pencilKitTap = UITapGestureRecognizer()
        #expect(fingerTap.delays(pencilKitTap))
        #expect(!fingerTap.delays(UIPinchGestureRecognizer()))
        #expect(!fingerTap.delays(UIPanGestureRecognizer()))
        for own in view.gestureRecognizers ?? [] { #expect(!fingerTap.delays(own)) }
    }

    /// Recorded on an iPad Pro: ~110 real taps were held 0.06–0.14s; pinches that ended in an undo, 0.44–0.81s.
    @Test func aLongerPressIsNotATap() {
        #expect(FingerTap.isTap(heldFor: 0.07))
        #expect(FingerTap.isTap(heldFor: 0.14))
        #expect(!FingerTap.isTap(heldFor: 0.44))
        #expect(!FingerTap.isTap(heldFor: 2))
    }

    /// A pinch keeps the fingers' centre nearly still, so on its own the tap recognizer let pinch-zooms end in an undo.
    @Test func fingerTapsWaitForPinchAndScrollToFail() throws {
        let scrollView = UIScrollView()
        scrollView.maximumZoomScale = 4  // a scroll view only has a pinch recognizer once it can zoom
        let fingerTap = FingerTap(on: scrollView, undo: {}, redo: {})
        #expect(fingerTap.waits(for: try #require(scrollView.pinchGestureRecognizer)))
        #expect(fingerTap.waits(for: scrollView.panGestureRecognizer))
        #expect(!fingerTap.waits(for: UIPanGestureRecognizer()))
        #expect(!fingerTap.waits(for: UITapGestureRecognizer()))
    }

    @Test func theCanvasOptsOutOfSystemThreeFingerEditing() {
        // iPadOS's three-finger tap opens an edit menu (and swipes undo); taps on that menu caused stray undos.
        #expect(LayoutReportingCanvasView().editingInteractionConfiguration == .none)
    }

    // MARK: Adding pages

    struct Fixture {
        let library: LibraryModel
        let editor: EditorModel
        let undoManager: UndoManager
    }

    func openEditor() async throws -> Fixture {
        let library = LibraryModel(store: store)
        await library.load()
        let notebook = try await library.create(NotebookDraft(title: "Undo"))
        let editor = EditorModel(notebook: notebook, library: library, store: store)
        await editor.load()
        let undoManager = UndoManager()
        undoManager.groupsByEvent = false
        editor.undoManager = undoManager
        return Fixture(library: library, editor: editor, undoManager: undoManager)
    }

    @Test func undoRemovesAnAddedBlankPageAndRedoBringsItBack() async throws {
        let fixture = try await openEditor()
        let (library, editor, undoManager) = (fixture.library, fixture.editor, fixture.undoManager)
        undoManager.beginUndoGrouping()
        try await editor.appendPage()
        undoManager.endUndoGrouping()
        #expect(editor.layout.pageCount == 2)

        undoManager.undo()
        await editor.pendingPageChange?.value
        #expect(editor.layout.pageCount == 1)
        #expect(library.notebooks.first?.pages.count == 1)
        #expect(await store.loadLibrary().notebooks.first?.pages.count == 1)

        undoManager.redo()
        await editor.pendingPageChange?.value
        #expect(editor.layout.pageCount == 2)
    }

    @Test func undoKeepsAnAddedPageThatHasInk() async throws {
        let fixture = try await openEditor()
        let (editor, undoManager) = (fixture.editor, fixture.undoManager)
        undoManager.beginUndoGrouping()
        try await editor.appendPage()
        undoManager.endUndoGrouping()
        let onSecond = CGPoint(x: 200, y: editor.layout.pageRect(1).minY + 80)
        editor.drawingChanged(PKDrawing(strokes: [stroke(at: onSecond)]))

        undoManager.undo()
        await editor.pendingPageChange?.value
        #expect(editor.layout.pageCount == 2)
        #expect(editor.drawing.strokes.count == 1)
    }
}
