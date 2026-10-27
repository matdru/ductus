import Foundation
import PencilKit
import Testing

@testable import Ductus

struct ToolboxTests {
    var toolbox = Toolbox()

    @Test func startsWithABlackMediumFountainPen() throws {
        #expect(toolbox.selection == .ink(.fountainPen))
        #expect(toolbox.color == Toolbox.Swatch.black.hex)
        #expect(toolbox.size == .medium)
        let tool = try #require(toolbox.pkTool as? PKInkingTool)
        #expect(tool.inkType == .fountainPen)
    }

    // MARK: Colour and size belong to the toolbox, not a pen

    @Test func colourAndSizeCarryAcrossInks() throws {
        var toolbox = toolbox
        toolbox.color = Toolbox.Swatch.red.hex
        toolbox.size = .bold
        toolbox.select(.ink(.pencil))
        let tool = try #require(toolbox.pkTool as? PKInkingTool)
        #expect(tool.inkType == .pencil)
        #expect(abs(tool.width - Toolbox.Size.bold.width(for: .pencil)) < 0.0001)
    }

    @Test func sizesGrowFromFineToBoldWithinEveryInk() {
        for ink in Toolbox.Ink.allCases {
            let widths = Toolbox.Size.allCases.map { $0.width(for: ink) }
            #expect(widths == widths.sorted() && Set(widths).count == 3, "\(ink)")
            #expect(widths.allSatisfy { ink.widthRange.contains($0) }, "\(ink)")
        }
    }

    // MARK: Eraser

    @Test func tappingTheEraserInHandSwitchesItsMode() throws {
        var toolbox = toolbox
        toolbox.tap(.eraser)
        #expect(toolbox.selection == .eraser)
        #expect(toolbox.eraser == .stroke)
        toolbox.tap(.eraser)
        #expect(toolbox.eraser == .pixel)
        #expect(try #require(toolbox.pkTool as? PKEraserTool).eraserType == .bitmap)
        toolbox.tap(.eraser)
        #expect(toolbox.eraser == .stroke)
    }

    @Test func tappingAnotherToolJustPicksItUp() {
        var toolbox = toolbox
        toolbox.tap(.lasso)
        toolbox.tap(.lasso)
        #expect(toolbox.selection == .lasso)
        #expect(toolbox.pkTool is PKLassoTool)
    }

    // MARK: Pencil taps

    @Test func switchEraserGoesToTheEraserAndBack() {
        var toolbox = toolbox
        toolbox.select(.ink(.marker))
        toolbox.pencilTapped(.switchEraser)
        #expect(toolbox.selection == .eraser)
        toolbox.pencilTapped(.switchEraser)
        #expect(toolbox.selection == .ink(.marker))
    }

    @Test func switchPreviousSwapsWithTheLastTool() {
        var toolbox = toolbox
        toolbox.select(.ink(.pen))
        toolbox.pencilTapped(.switchPrevious)
        #expect(toolbox.selection == .ink(.fountainPen))
        toolbox.pencilTapped(.switchPrevious)
        #expect(toolbox.selection == .ink(.pen))
    }

    @Test func fromTheEraserWithNothingBeforeItGoesToTheFountainPen() {
        var toolbox = toolbox
        toolbox.select(.eraser)
        toolbox.select(.eraser)
        toolbox.pencilTapped(.switchEraser)
        #expect(toolbox.selection == .ink(.fountainPen))
    }

    @Test func ignoreLeavesTheToolAlone() {
        var toolbox = toolbox
        toolbox.pencilTapped(.ignore)
        #expect(toolbox.selection == .ink(.fountainPen))
    }

    // MARK: Saving

    @Test func roundTrips() throws {
        var toolbox = toolbox
        toolbox.select(.ink(.marker))
        toolbox.color = Toolbox.Swatch.yellow.hex
        toolbox.size = .fine
        toolbox.eraser = .pixel
        let data = try JSONEncoder().encode(toolbox)
        #expect(try JSONDecoder().decode(Toolbox.self, from: data) == toolbox)
    }

    @Test func decodingIsTolerant() throws {
        let json = #"{"color": 2381765, "size": "huge", "selection": {"ink": {"_0": "quill"}}}"#
        let decoded = try JSONDecoder().decode(Toolbox.self, from: Data(json.utf8))
        #expect(decoded.color == 2_381_765)
        #expect(decoded.size == .medium)
        #expect(decoded.eraser == .stroke)
        #expect(try JSONDecoder().decode(Toolbox.self, from: Data("{}".utf8)) == Toolbox())
    }

    @MainActor @Test func toolboxSurvivesRelaunch() throws {
        let defaults = try #require(UserDefaults(suiteName: "ToolboxTests-\(UUID().uuidString)"))
        let store = SettingsStore(defaults: defaults)
        store.toolbox.select(.lasso)
        store.toolbox.color = Toolbox.Swatch.green.hex
        let relaunched = SettingsStore(defaults: defaults)
        #expect(relaunched.toolbox.selection == .lasso)
        #expect(relaunched.toolbox.color == Toolbox.Swatch.green.hex)
    }
}
