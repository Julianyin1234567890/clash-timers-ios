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
        input.typeText("{\"tag\":\"#UITEST\",\"timestamp\":\(now),\"helpers\":[{\"data\":93000000,\"lvl\":8,\"helper_cooldown\":0}],\"buildings\":[{\"data\":1000008,\"lvl\":4,\"timer\":36000}]}")
        app.buttons["confirmImport"].tap()
        XCTAssertTrue(app.staticTexts["Cannon"].firstMatch.waitForExistence(timeout: 5))
    }

    func testImportBoostUndoAndPersistence() {
        importVillage()
        app.buttons["openBoosts"].tap()
        let record = app.buttons["record-builderPotion"]
        XCTAssertTrue(record.waitForExistence(timeout: 5))
        let boostScreen = XCTAttachment(screenshot: app.screenshot())
        boostScreen.name = "Boost logging screen"
        boostScreen.lifetime = .keepAlways
        add(boostScreen)
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

    func testInlinePotionAndHelperControls() {
        importVillage()
        let add = app.buttons["panel-add-builderPotion"]
        XCTAssertTrue(add.waitForExistence(timeout: 5))
        add.tap()
        let undo = app.buttons["panel-undo-builderPotion"]
        XCTAssertTrue(undo.waitForExistence(timeout: 5))
        let active = XCTAttachment(screenshot: app.screenshot())
        active.name = "App-active-potion"
        active.lifetime = .keepAlways
        self.add(active)
        undo.tap()
        XCTAssertFalse(undo.exists)
        let helper = app.buttons["helper-BUILDER:1000008:5#0"]
        XCTAssertEqual(helper.label, "Link helper for Cannon")
        helper.tap()
        XCTAssertEqual(helper.label, "Unlink helper for Cannon")
        helper.tap()
        XCTAssertEqual(helper.label, "Link helper for Cannon")
    }

    func testInvalidImportKeepsVillage() {
        importVillage()
        app.buttons["syncVillage"].tap()
        let input = app.textViews["villageExportInput"]
        XCTAssertTrue(input.waitForExistence(timeout: 5))
        let importScreen = XCTAttachment(screenshot: app.screenshot())
        importScreen.name = "Saved village import screen"
        importScreen.lifetime = .keepAlways
        add(importScreen)
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
