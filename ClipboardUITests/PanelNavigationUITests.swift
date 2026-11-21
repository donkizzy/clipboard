import XCTest

/// Drives the real panel in demo mode: keyboard navigation, Quick Look,
/// Esc layering, filter switching and the layout toggle.
@MainActor
final class PanelNavigationUITests: XCTestCase {
    private var app: XCUIApplication!

    /// Stable IDs from `DemoSeed`.
    private func cardID(_ index: Int) -> String { "card.00000000-0000-0000-0000-\(String(format: "%012d", index))" }
    private func rowID(_ index: Int) -> String { "row.00000000-0000-0000-0000-\(String(format: "%012d", index))" }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }

    private var itemCount: String {
        let label = element("itemCount")
        return (label.value as? String).flatMap { $0.isEmpty ? nil : $0 } ?? label.label
    }

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
        // Demo data, deterministic layout and appearance, regardless of stored preferences.
        app.launchArguments = ["--demo", "-layout", "row", "-appearance", "dark", "-pinnedOnTop", "NO"]
        app.launch()
        XCTAssertTrue(element(cardID(1)).waitForExistence(timeout: 10), "Panel didn't open in demo mode")
    }

    override func tearDown() async throws {
        app.terminate()
    }

    func testArrowKeysMoveTheSelection() {
        XCTAssertTrue(element(cardID(1)).isSelected)

        app.typeKey(.rightArrow, modifierFlags: [])
        app.typeKey(.rightArrow, modifierFlags: [])
        XCTAssertTrue(element(cardID(3)).isSelected)
        XCTAssertFalse(element(cardID(1)).isSelected)

        app.typeKey(.leftArrow, modifierFlags: [])
        XCTAssertTrue(element(cardID(2)).isSelected)

        // Far enough right to need scrolling: the card must still be reachable and selected.
        for _ in 0..<6 { app.typeKey(.downArrow, modifierFlags: []) }
        XCTAssertTrue(element(cardID(8)).isSelected)
        XCTAssertTrue(element(cardID(8)).isHittable, "Selected card should be scrolled into view")
    }

    func testSpacePreviewsAndEscapeBacksOutInLayers() {
        app.typeKey(.rightArrow, modifierFlags: []) // hands focus to the results
        app.typeKey(.space, modifierFlags: [])
        XCTAssertTrue(element("quickLook").waitForExistence(timeout: 2))

        app.typeKey(.escape, modifierFlags: [])
        XCTAssertTrue(element("quickLook").waitForNonExistence(timeout: 2))
        XCTAssertTrue(element(cardID(2)).exists, "Esc should close only the preview")

        // Typing while the results have focus goes back to the search field.
        app.typeText("natoma")
        XCTAssertEqual(itemCount, "1 item")

        app.typeKey(.escape, modifierFlags: [])
        XCTAssertEqual(itemCount, "12 items", "Esc should clear the search before closing")

        app.typeKey(.escape, modifierFlags: [])
        XCTAssertTrue(element(cardID(1)).waitForNonExistence(timeout: 2), "Esc with nothing to clear closes the panel")
    }

    func testFiltersSwitchWithCommandNumbersAndClicks() {
        app.typeKey("3", modifierFlags: .command)
        XCTAssertEqual(itemCount, "3 items")
        XCTAssertTrue(element(cardID(2)).exists)
        XCTAssertFalse(element(cardID(1)).exists)

        app.typeKey("6", modifierFlags: .command)
        XCTAssertEqual(itemCount, "2 items")

        element("filter.Images").click()
        XCTAssertEqual(itemCount, "2 items")
        XCTAssertTrue(element(cardID(3)).exists)

        app.typeKey("1", modifierFlags: .command)
        XCTAssertEqual(itemCount, "12 items")
    }

    func testLayoutToggleSwitchesToTheListAndBack() {
        element("layoutToggle").click()
        XCTAssertTrue(element(rowID(1)).waitForExistence(timeout: 2))
        XCTAssertFalse(element(cardID(1)).exists)

        app.typeKey(.downArrow, modifierFlags: [])
        XCTAssertTrue(element(rowID(2)).isSelected)

        element("layoutToggle").click()
        XCTAssertTrue(element(cardID(1)).waitForExistence(timeout: 2))
    }
}
