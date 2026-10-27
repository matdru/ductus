import Foundation
import PencilKit
import Testing
import UIKit

@testable import Ductus

struct PenCaseTests {
    var penCase = PenCase.default
    var first: Pen { penCase.pens[0] }
    var second: Pen { penCase.pens[1] }

    // MARK: Pens

    @Test func startsWithAFountainPenSelected() {
        #expect(penCase.pens.count == 3)
        #expect(first.ink == .fountainPen)
        #expect(penCase.selection == .pen(first.id))
        #expect(penCase.selectedPen == first)
    }

    @Test func addingAPenCopiesTheCurrentOneAndSelectsIt() {
        var penCase = penCase
        let added = penCase.addPen()
        #expect(penCase.pens.count == 4)
        #expect(added.ink == first.ink && added.color == first.color && added.width == first.width)
        #expect(added.id != first.id)
        #expect(penCase.selection == .pen(added.id))
    }

    @Test func thePenCaseHasRoomForSixPens() {
        var penCase = penCase
        while penCase.canAddPen { penCase.addPen() }
        #expect(penCase.pens.count == PenCase.maximumPens)
    }

    @Test func duplicateSitsNextToTheOriginal() {
        var penCase = penCase
        let copy = penCase.duplicate(first.id)
        #expect(penCase.pens[1].id == copy?.id)
        #expect(copy?.color == first.color)
    }

    @Test func removingTheSelectedPenSelectsItsNeighbour() {
        var penCase = penCase
        penCase.select(.pen(second.id))
        penCase.remove(second.id)
        #expect(penCase.pens.count == 2)
        #expect(penCase.selection == .pen(penCase.pens[1].id))
    }

    @Test func theLastPenCantBeRemoved() {
        var penCase = penCase
        for pen in penCase.pens { penCase.remove(pen.id) }
        #expect(penCase.pens.count == 1)
        #expect(!penCase.canRemovePen)
    }

    @Test func updatingAPenChangesItInPlace() {
        var penCase = penCase
        var pen = second
        pen.color = Pen.Swatch.green.hex
        penCase.update(pen)
        #expect(penCase.pens[1].color == Pen.Swatch.green.hex)
    }

    // MARK: Width

    @Test func widthStaysInTheInksRange() {
        var pen = Pen(ink: .monoline, color: 0, width: 100)
        #expect(abs(pen.clampedWidth - Pen.Ink.monoline.widthRange.upperBound) < 0.0001)
        pen.width = 0
        #expect(abs(pen.clampedWidth - Pen.Ink.monoline.widthRange.lowerBound) < 0.0001)
    }

    @Test func changingInkKeepsTheRelativeWidth() {
        let range = PKInk.InkType.fountainPen.validWidthRange
        var pen = Pen(ink: .fountainPen, color: 0, width: range.lowerBound + (range.upperBound - range.lowerBound) / 2)
        pen.change(ink: .watercolor)
        let watercolor = PKInk.InkType.watercolor.validWidthRange
        #expect(abs(pen.width - (watercolor.lowerBound + watercolor.upperBound) / 2) < 0.001)
    }

    @Test func customColoursRoundTripAsHex() {
        // swiftlint:disable:next no_raw_colors
        #expect(Pen.hex(of: UIColor(red: 0x24 / 255, green: 0x57 / 255, blue: 0xC5 / 255, alpha: 1)) == 0x2457C5)
        // Display P3 reds beyond sRGB clamp rather than wrap.
        #expect(Pen.hex(of: UIColor(displayP3Red: 1, green: 0, blue: 0, alpha: 1)) >> 16 == 0xFF)
    }

    @Test func widthInPointsHalvesCanvasUnits() {
        #expect(Pen(ink: .pen, color: 0, width: 4).widthInPoints == 2)
    }

    // MARK: Tools

    @Test func penToolUsesTheInkColourAndWidth() throws {
        let pen = Pen(ink: .pencil, color: Pen.Swatch.red.hex, width: 5)
        let tool = try #require(PenCase(pens: [pen], selection: .pen(pen.id)).pkTool as? PKInkingTool)
        #expect(tool.inkType == .pencil)
        #expect(abs(tool.width - 5) < 0.001)
    }

    @Test func eraserCanBeStrokeOrPixel() throws {
        var penCase = penCase
        penCase.select(.eraser)
        #expect(try #require(penCase.pkTool as? PKEraserTool).eraserType == .vector)
        penCase.eraser = .pixel
        #expect(try #require(penCase.pkTool as? PKEraserTool).eraserType == .bitmap)
    }

    // MARK: Pencil taps

    @Test func switchEraserGoesToTheEraserAndBack() {
        var penCase = penCase
        penCase.select(.pen(second.id))
        penCase.pencilTapped(.switchEraser)
        #expect(penCase.selection == .eraser)
        penCase.pencilTapped(.switchEraser)
        #expect(penCase.selection == .pen(second.id))
    }

    @Test func switchEraserFromTheLassoStillGoesToTheEraser() {
        var penCase = penCase
        penCase.select(.lasso)
        penCase.pencilTapped(.switchEraser)
        #expect(penCase.selection == .eraser)
    }

    @Test func switchPreviousSwapsWithTheLastTool() {
        var penCase = penCase
        penCase.select(.pen(second.id))
        penCase.pencilTapped(.switchPrevious)
        #expect(penCase.selection == .pen(first.id))
        penCase.pencilTapped(.switchPrevious)
        #expect(penCase.selection == .pen(second.id))
    }

    @Test func aRemovedPreviousPenFallsBackToTheFirstPen() {
        var penCase = penCase
        penCase.select(.pen(second.id))
        penCase.select(.eraser)
        penCase.remove(second.id)
        penCase.pencilTapped(.switchEraser)
        #expect(penCase.selection == .pen(first.id))
    }

    @Test func ignoreLeavesTheToolAlone() {
        var penCase = penCase
        penCase.pencilTapped(.ignore)
        #expect(penCase.selection == .pen(first.id))
    }

    // MARK: Saving

    @Test func roundTrips() throws {
        var penCase = penCase
        penCase.select(.lasso)
        penCase.eraser = .pixel
        let data = try JSONEncoder().encode(penCase)
        #expect(try JSONDecoder().decode(PenCase.self, from: data) == penCase)
    }

    @Test func decodingRepairsAnInvalidSelection() throws {
        let json = #"{"pens": [], "selection": {"pen": {"_0": "00000000-0000-0000-0000-000000000000"}}}"#
        let decoded = try JSONDecoder().decode(PenCase.self, from: Data(json.utf8))
        #expect(!decoded.pens.isEmpty)
        #expect(decoded.selection == .pen(decoded.pens[0].id))
    }

    @MainActor @Test func penCaseSurvivesRelaunch() throws {
        let defaults = try #require(UserDefaults(suiteName: "PenCaseTests-\(UUID().uuidString)"))
        let store = SettingsStore(defaults: defaults)
        store.penCase.select(.lasso)
        #expect(SettingsStore(defaults: defaults).penCase.selection == .lasso)
    }
}
