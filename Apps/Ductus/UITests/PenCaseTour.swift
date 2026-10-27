import XCTest

/// Taps through the pen case on the simulator, checking each step and saving a screenshot of it. Run with
/// `mise run ui-shots`; screenshots land in `.build/ui-shots`. A crash fails the test.
final class PenCaseTour: XCTestCase {
    @MainActor private let app = XCUIApplication()

    @MainActor
    func testPenCase() throws {
        continueAfterFailure = false
        app.launchArguments = ["-uiTesting"]
        app.launch()

        // A fresh library opens on first launch; start a notebook.
        app.buttons["Start writing"].tap()
        let fountainPen = app.buttons["Fountain pen, Black"]
        XCTAssertTrue(fountainPen.waitForExistence(timeout: 5))
        shot("01-editor")

        // Tapping the pen in hand opens its settings.
        fountainPen.tap()
        let bold = app.buttons["Bold"]
        XCTAssertTrue(bold.waitForExistence(timeout: 3))
        shot("02-pen-settings")

        bold.tap()
        XCTAssertTrue(bold.isSelected)
        app.buttons["Navy"].tap()
        XCTAssertTrue(app.buttons["Fountain pen, Navy"].exists)
        shot("03-bold-navy")

        // Change ink; the title follows.
        app.buttons["Ink: Fountain pen"].tap()
        app.buttons["Watercolour"].tap()
        XCTAssertTrue(app.buttons["Ink: Watercolour"].waitForExistence(timeout: 3))
        // Changing ink keeps the size.
        XCTAssertTrue(app.buttons["Bold"].isSelected)
        shot("04-watercolour")

        // Duplicate makes a fourth pen and closes the popover.
        app.buttons["Duplicate"].tap()
        XCTAssertTrue(app.buttons["Watercolour, Navy"].waitForExistence(timeout: 3))
        XCTAssertEqual(app.buttons.matching(identifier: "Watercolour, Navy").count, 2)
        shot("05-duplicated")

        // Remove the copy (it's in hand after duplicating).
        app.buttons.matching(identifier: "Watercolour, Navy").element(boundBy: 1).tap()
        app.buttons["Remove"].tap()
        XCTAssertEqual(app.buttons.matching(identifier: "Watercolour, Navy").count, 1)

        // Add a pen: it copies the one in hand and opens its settings.
        app.buttons["Add a pen"].tap()
        XCTAssertTrue(app.buttons["Fine"].waitForExistence(timeout: 3))
        shot("06-added-pen")
        dismissPopover()

        // The eraser: pick it up, then tap again for its settings.
        app.buttons["Eraser"].tap()
        app.buttons["Eraser"].tap()
        XCTAssertTrue(app.buttons["Pixels"].waitForExistence(timeout: 3))
        app.buttons["Pixels"].tap()
        shot("07-eraser")
        dismissPopover()

        app.buttons["Lasso"].tap()
        shot("08-lasso")
    }

    /// Closes the open popover the way a tap outside it would, without drawing on the page.
    @MainActor
    private func dismissPopover() {
        app.otherElements["PopoverDismissRegion"].firstMatch.tap()
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
