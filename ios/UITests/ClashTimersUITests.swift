import XCTest
import UIKit

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

    func testOnlineLevelsWithoutExportPersistAndSurviveFailure() {
        let fixture = """
        {"tag":"#P0Y8LQ","name":"Sample Village","townHallLevel":16,
         "heroes":[{"id":0,"level":8,"maxLevel":105,"village":"home"}],
         "troops":[],"spells":[],"heroEquipment":[]}
        """
        app.terminate()
        app.launchEnvironment["CLASH_PROFILE_RESPONSE"] = fixture
        app.launch()
        app.buttons["openLevels"].tap()
        let tag = app.textFields["onlinePlayerTag"]
        XCTAssertTrue(tag.waitForExistence(timeout: 5))
        tag.tap()
        tag.typeText("#P0Y8LQ")
        app.buttons["downloadLevels"].tap()
        XCTAssertTrue(app.staticTexts["onlineProfileName"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["levelsChanges"].label.contains("Starting levels saved"))
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Online level refresh"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        app.buttons["Done"].tap()
        // No export or clipboard interaction was necessary to download levels.
        XCTAssertTrue(app.buttons["startSync"].exists)

        app.terminate()
        app.launchArguments = ["--uitesting", "--keep-state"]
        app.launchEnvironment["CLASH_PROFILE_RESPONSE"] = fixture.replacingOccurrences(of: "\"level\":8", with: "\"level\":9")
        app.launch()
        app.buttons["openLevels"].tap()
        XCTAssertEqual(app.textFields["onlinePlayerTag"].value as? String, "#P0Y8LQ")
        app.buttons["downloadLevels"].tap()
        let changes = app.staticTexts["levelsChanges"]
        let upgraded = NSPredicate(format: "label CONTAINS %@", "1 level increase")
        expectation(for: upgraded, evaluatedWith: changes)
        waitForExpectations(timeout: 5)

        app.terminate()
        app.launchEnvironment.removeValue(forKey: "CLASH_PROFILE_RESPONSE")
        app.launch()
        app.buttons["openLevels"].tap()
        app.buttons["downloadLevels"].tap()
        XCTAssertTrue(app.staticTexts["levelsError"].waitForExistence(timeout: 5)
                      || app.otherElements["levelsError"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["onlineProfileName"].exists)
        XCTAssertTrue(app.staticTexts["levelsChanges"].label.contains("1 level increase"))
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
        expectation(for: NSPredicate(format: "enabled == false"), evaluatedWith: undo)
        waitForExpectations(timeout: 5)
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
        // The panel uses TimelineView's date, which advances on the next one-second tick.
        XCTAssertTrue(undo.waitForNonExistence(timeout: 5))
        let helper = app.buttons["helper-BUILDER:1000008:5#0"]
        XCTAssertEqual(helper.label, "Link helper for Cannon")
        helper.tap()
        XCTAssertEqual(helper.label, "Unlink helper for Cannon")
        helper.tap()
        XCTAssertEqual(helper.label, "Link helper for Cannon")
    }

    func testInvalidImportKeepsVillage() {
        importVillage()
        app.buttons["startImport"].tap()
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

    @MainActor
    private func copyVillage(tag: String = "#COPIED", timestamp: Int? = nil) {
        let now = timestamp ?? Int(Date().timeIntervalSince1970)
        UIPasteboard.general.string = "{\"tag\":\"\(tag)\",\"timestamp\":\(now),\"buildings\":[{\"data\":1000008,\"lvl\":4,\"timer\":36000}]}"
    }

    private func allowPasteIfRequested() {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let allow = springboard.buttons["Allow Paste"]
        if allow.waitForExistence(timeout: 2) { allow.tap() }
        let appAllow = app.buttons["Allow Paste"]
        if appAllow.exists { appAllow.tap() }
    }

    private func assertSynced(_ tag: String = "#COPIED") {
        allowPasteIfRequested()
        XCTAssertTrue(app.staticTexts[tag].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["syncSuccess"].exists || app.otherElements["syncSuccess"].exists)
        XCTAssertFalse(app.textViews["villageExportInput"].exists)
        XCTAssertEqual(app.alerts.count, 0)
    }

    @MainActor
    func testSyncTapImportsClipboardAndRejectsInvalidOrOlderData() {
        let now = Int(Date().timeIntervalSince1970)
        copyVillage(timestamp: now)
        app.buttons["panelSync"].tap()
        assertSynced()
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Copy then Sync"
        screenshot.lifetime = .keepAlways
        add(screenshot)

        // A bad or stale copy cannot overwrite the successfully synced village.
        for contents in ["unrelated clipboard text",
                         "{\"tag\":\"#COPIED\",\"timestamp\":\(now - 100),\"buildings\":[]}"] {
            UIPasteboard.general.string = contents
            app.buttons["syncVillage"].tap()
            allowPasteIfRequested()
            let alert = app.alerts["Couldn’t import village"]
            XCTAssertTrue(alert.waitForExistence(timeout: 5))
            alert.buttons["OK"].tap()
            app.buttons["Cancel"].tap()
            XCTAssertTrue(app.staticTexts["#COPIED"].exists)
            XCTAssertTrue(app.staticTexts["Cannon"].exists)
        }
    }

    @MainActor
    func testWidgetSyncURLFromBackgroundAndOrdinaryLaunchDoesNotPaste() {
        copyVillage()
        XCUIDevice.shared.press(.home)
        app.activate()
        // Opening the app normally must leave copied data untouched.
        XCTAssertTrue(app.buttons["startSync"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["#COPIED"].exists)
        XCUIDevice.shared.press(.home)
        app.open(URL(string: "clashtimers://sync")!)
        assertSynced()

        // A subsequent widget request can import a different copy.
        copyVillage(tag: "#UPDATED")
        XCUIDevice.shared.press(.home)
        app.open(URL(string: "clashtimers://sync")!)
        assertSynced("#UPDATED")
    }

    @MainActor
    func testWidgetSyncURLOnColdLaunch() {
        copyVillage()
        app.terminate()
        app.open(URL(string: "clashtimers://sync")!)
        assertSynced()
        app.terminate()
        app.launchArguments = ["--uitesting", "--keep-state"]
        app.launch()
        XCTAssertTrue(app.staticTexts["#COPIED"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testEmptyClipboardRecoveryAndPasteSavesImmediately() {
        UIPasteboard.general.items = []
        app.buttons["startSync"].tap()
        let alert = app.alerts["No village data to paste"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        alert.buttons["OK"].tap()
        copyVillage()
        let paste = app.buttons["pasteAndImport"]
        XCTAssertTrue(paste.waitForExistence(timeout: 5))
        paste.tap()
        assertSynced()
    }
}
