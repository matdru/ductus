import Foundation
import Testing

@testable import InkCore

struct InkDocumentTests {
    func makeStroke() -> Stroke {
        Stroke(tool: .defaultPen, samples: [StrokeSample(x: 0, y: 0, force: 1, altitude: 1, azimuth: 0, timestamp: 0)])
    }

    @Test func addStrokeAppendsInOrder() {
        var doc = InkDocument()
        let a = makeStroke()
        let b = makeStroke()
        doc.apply(.addStroke(a))
        doc.apply(.addStroke(b))
        #expect(doc.strokes.map(\.id) == [a.id, b.id])
        #expect(doc.ops.count == 2)
    }

    @Test func removeStrokeRemovesById() {
        var doc = InkDocument()
        let a = makeStroke()
        let b = makeStroke()
        doc.apply(.addStroke(a))
        doc.apply(.addStroke(b))
        doc.apply(.removeStroke(a.id))
        #expect(doc.strokes.map(\.id) == [b.id])
    }

    @Test func clearEmptiesStrokesAndUndoRestoresThem() {
        var doc = InkDocument()
        let a = makeStroke()
        doc.apply(.addStroke(a))
        doc.apply(.clear)
        #expect(doc.strokes.isEmpty)
        doc.undo()
        #expect(doc.strokes.map(\.id) == [a.id])
    }

    @Test func undoRemovesLastStroke() {
        var doc = InkDocument()
        let a = makeStroke()
        let b = makeStroke()
        doc.apply(.addStroke(a))
        doc.apply(.addStroke(b))
        doc.undo()
        #expect(doc.strokes.map(\.id) == [a.id])
    }

    @Test func undoOnEmptyDocumentIsNoOp() {
        var doc = InkDocument()
        doc.undo()
        #expect(doc == InkDocument())
    }
}
