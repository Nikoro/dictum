import XCTest

@MainActor
final class DictationViewTests: XCTestCase {
    func testTappingOutsideEditorDismissesKeyboard() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()
        let editor = app.textViews["dictation-test-editor"]
        let keyboard = app.otherElements["inputView"].firstMatch
        XCTAssertTrue(editor.waitForExistence(timeout: 10))
        editor.tap()
        XCTAssertTrue(keyboard.waitForExistence(timeout: 5))
        editor.tap()
        XCTAssertTrue(keyboard.exists)
        app.navigationBars["Dictum"].staticTexts["Dictum"].tap()
        XCTAssertTrue(keyboard.waitForNonExistence(timeout: 3))
    }

    func testModelRowSelectsTheOtherModel() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()
        let ultra = app.buttons["speech-model-ultra"]
        let standard = app.buttons["speech-model-v3"]
        XCTAssertTrue(ultra.waitForExistence(timeout: 10))
        let other = ultra.isSelected ? standard : ultra
        other.tap()
        let selected = XCTNSPredicateExpectation(predicate: NSPredicate(format: "selected == true"), object: other)
        XCTAssertEqual(XCTWaiter.wait(for: [selected], timeout: 3), .completed)
    }
}
