import XCTest

/// Taps through the ink toolbar on the simulator, checking each step and saving a screenshot of it. Run with
/// `mise run ui-shots`; screenshots land in `.build/ui-shots`. A crash fails the test.
final class ToolbarTour: XCTestCase {
    @MainActor private let app = XCUIApplication()

    @MainActor
    func testToolbar() throws {
        continueAfterFailure = false
        app.launchArguments = ["-uiTesting"]
        app.launch()

        // A fresh library opens on first launch; start a notebook.
        app.buttons["Start writing"].tap()
        let fountainPen = app.buttons["Fountain pen"]
        XCTAssertTrue(fountainPen.waitForExistence(timeout: 5))
        XCTAssertTrue(fountainPen.isSelected)
        shot("01-editor")

        // Pick up the pencil, go bold.
        app.buttons["Pencil"].tap()
        app.buttons["Bold"].tap()
        XCTAssertTrue(app.buttons["Pencil"].isSelected && app.buttons["Bold"].isSelected)

        // The colour opens a palette; choosing closes it.
        app.buttons["Colour"].tap()
        XCTAssertTrue(app.buttons["Navy"].waitForExistence(timeout: 3))
        shot("02-palette")
        app.buttons["Navy"].tap()
        XCTAssertEqual(app.buttons["Colour"].value as? String, "Navy")
        shot("03-bold-navy-pencil")

        // Tapping the eraser in hand switches its mode.
        let eraser = app.buttons["Eraser"]
        eraser.tap()
        XCTAssertEqual(eraser.value as? String, "Whole strokes")
        eraser.tap()
        XCTAssertEqual(eraser.value as? String, "Pixels")
        shot("04-pixel-eraser")
        eraser.tap()
        XCTAssertEqual(eraser.value as? String, "Whole strokes")

        app.buttons["Lasso"].tap()
        XCTAssertTrue(app.buttons["Lasso"].isSelected)
        shot("05-lasso")
    }

    /// Attaches a screenshot to the result and, when `SHOTS_DIR` is set, saves it there too.
    @MainActor
    private func shot(_ name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        if let directory = ProcessInfo.processInfo.environment["SHOTS_DIR"] {
            let url = URL(fileURLWithPath: directory).appending(path: "\(name).png")
            try? screenshot.pngRepresentation.write(to: url)
        }
    }
}
