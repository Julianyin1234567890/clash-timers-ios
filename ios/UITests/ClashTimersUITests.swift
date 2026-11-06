import XCTest

final class ClashTimersUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
    }

    private func importVillage() {
        app.buttons["startImport"].tap()
        let input = app.textViews["villageExportInput"]
        XCTAssertTrue(input.waitForExistence(timeout: 5))
        input.tap()
        let now = Int(Date().timeIntervalSince1970)
        input.typeText("{\"tag\":\"#UITEST\",\"timestamp\":\(now),\"buildings\":[{\"data\":1000008,\"lvl\":4,\"timer\":36000}]}")
        app.buttons["confirmImport"].tap()
        XCTAssertTrue(app.staticTexts["Cannon"].firstMatch.waitForExistence(timeout: 5))
    }

    func testImportBoostUndoAndPersistence() {
        importVillage()
        app.buttons["openBoosts"].tap()
        let record = app.buttons["record-builderPotion"]
        XCTAssertTrue(record.waitForExistence(timeout: 5))
        record.tap()
        let undo = app.buttons["undo-builderPotion"]
        XCTAssertTrue(undo.isEnabled)
        undo.tap()
        XCTAssertFalse(undo.isEnabled)

        app.terminate()
        app.launchArguments = ["--uitesting", "--keep-state"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Cannon"].firstMatch.waitForExistence(timeout: 5))
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Imported village"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    func testInvalidImportKeepsVillage() {
        importVillage()
        app.buttons["syncVillage"].tap()
        let input = app.textViews["villageExportInput"]
        XCTAssertTrue(input.waitForExistence(timeout: 5))
        input.tap()
        input.typeText("not village data")
        app.buttons["confirmImport"].tap()
        let alert = app.alerts["Couldn’t import village"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        alert.buttons["OK"].tap()
        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.staticTexts["Cannon"].firstMatch.waitForExistence(timeout: 5))
    }
}
