import XCTest
@testable import ClashTimersCore

final class ClashTimersCoreTests: XCTestCase {
    private func fixture(_ number: Int) throws -> String {
        try String(contentsOf: XCTUnwrap(Bundle.module.url(forResource: "export_\(number)", withExtension: "json")))
    }
    private func state(_ number: Int) throws -> AppState {
        try SyncLogic.apply(fixture(number), to: AppState(), now: 1_800_000_000)
    }
    private func village(_ number: Int) throws -> VillageExport { try XCTUnwrap(state(number).village) }
    private func minimal(tag: String = "#TEST", time: Int = 100, timer: Int = 36000) -> String {
        """
        {"tag":"\(tag)","timestamp":\(time),"buildings":[{"data":1000008,"lvl":4,"timer":\(timer)}]}
        """
    }

    func testAllOriginalFixturesAndBuilderCount() throws {
        for number in 1...4 {
            let export = try village(number)
            XCTAssertEqual(export.tag, "#TEST000")
            XCTAssertEqual(export.townHallLevel, 18)
            XCTAssertEqual(export.derivedTotalBuilders, 6)
            XCTAssertEqual(export.helpers.count, 4)
            XCTAssertEqual(Set(export.jobs.map(\.id)).count, export.jobs.count)
            XCTAssertEqual(export.jobs.filter { $0.category == .lab }.count, 1)
            XCTAssertEqual(export.jobs.filter { $0.category == .pet }.count, 1)
        }
    }

    func testNestedModulesAndIdenticalUpgrades() throws {
        let export = try village(1)
        let module = try XCTUnwrap(export.jobs.first { $0.source == .module })
        XCTAssertEqual(module.parentDataID, 1000097)
        XCTAssertEqual(module.typeDataID, 103000013)
        XCTAssertEqual(module.dataID, 102000040)
        XCTAssertEqual(module.targetLevel, 8)
        XCTAssertEqual(export.jobs.filter { $0.dataID == 1000011 }.map(\.id),
                       ["BUILDER:1000011:17#0", "BUILDER:1000011:17#1"])
        XCTAssertFalse(export.jobs.contains { $0.dataID == 1000013 }) // gear_up is not a timer.
        XCTAssertTrue(try XCTUnwrap(export.jobs.first { $0.dataID == 1000102 }).isNewBuilding)
    }

    func testRejectsInvalidExportsWithoutCrashing() {
        for text in ["", "hello", "[]", "{}", "{\"tag\":12,\"timestamp\":1,\"buildings\":[]}",
                     "{\"tag\":\"#A\",\"timestamp\":true,\"buildings\":[]}",
                     "{\"tag\":\"#A\",\"timestamp\":\"1\",\"buildings\":[]}",
                     "{\"tag\":\"#A\",\"timestamp\":1.5,\"buildings\":[]}",
                     "{\"tag\":\"#A\",\"timestamp\":1,\"buildings\":{}}",
                     minimal(timer: Int.max)] {
            XCTAssertThrowsError(try ExportParser.parse(text), text)
        }
    }

    func testHomeVillageSectionsAndBuilderBaseExclusion() throws {
        let text = """
        {"tag":"#X","timestamp":100,"buildings":[],
         "traps":[{"data":1,"lvl":1,"timer":5}],"heroes":[{"data":2,"lvl":1,"timer":6}],
         "guardians":[{"data":3,"lvl":1,"timer":7}],"spells":[{"data":4,"lvl":1,"timer":8}],
         "siege_machines":[{"data":5,"lvl":1,"timer":9}],
         "buildings2":[{"data":6,"lvl":1,"timer":10}],"units2":[{"data":7,"lvl":1,"timer":11}]}
        """
        let export = try ExportParser.parse(text)
        XCTAssertEqual(export.jobs.map(\.source), [.trap, .hero, .guardian, .spell, .siegeMachine])
    }

    func testExportTwoMatchesAndroidFinishTimes() throws {
        let state = try state(2)
        let export = try XCTUnwrap(state.village)
        let engine = TimerEngine()
        let dragon = try XCTUnwrap(export.jobs.first { $0.category == .lab })
        let module = try XCTUnwrap(export.jobs.first { $0.source == .module })
        XCTAssertEqual(engine.finishTime(for: dragon, village: export, state: state), export.timestamp + 78685)
        XCTAssertEqual(engine.finishTime(for: module, village: export, state: state), export.timestamp + 74607)
        for job in export.jobs where !job.helperLinked {
            XCTAssertEqual(engine.finishTime(for: job, village: export, state: state), export.timestamp + job.remainingAtT0)
        }
    }

    func testExportFourRunningHelperAndGoblinFinishTimes() throws {
        let state = try state(4)
        let export = try XCTUnwrap(state.village)
        let engine = TimerEngine()
        let lab = try XCTUnwrap(export.jobs.first { $0.category == .lab })
        XCTAssertEqual(lab.helperTimer, 279)
        XCTAssertEqual(engine.finishTime(for: lab, village: export, state: state), export.timestamp + 342489)
        let cases: [(Job, Int)] = [
            (try XCTUnwrap(export.jobs.first { $0.dataID == 1000027 }), 352),
            (try XCTUnwrap(export.jobs.first { $0.isGoblin }), 2918),
            (try XCTUnwrap(export.jobs.first { $0.dataID == 28000000 }), 5084)
        ]
        for (job, seconds) in cases {
            XCTAssertEqual(engine.finishTime(for: job, village: export, state: state), export.timestamp + seconds)
        }
        XCTAssertEqual(state.boosts, [BoostUse(type: .builderPotion, start: export.timestamp, end: export.timestamp + 7515)])
    }

    func testCrossExportPredictionMatchesOriginal() throws {
        var state = try state(1)
        let first = try XCTUnwrap(state.village)
        let second = try village(2)
        let module = try XCTUnwrap(first.jobs.first { $0.source == .module })
        state.links.apprenticeJobKey = module.id
        state.boosts = [BoostUse(type: .builderBite, start: first.timestamp + 1000, end: first.timestamp + 4600)]
        let engine = TimerEngine()
        for (a, b) in zip(first.jobs, second.jobs) {
            XCTAssertEqual(a.id, b.id)
            let tolerance = a.id == module.id || a.category == .lab ? 60 : 0
            let predicted = engine.remaining(for: a, village: first, state: state, at: second.timestamp)
            XCTAssertLessThanOrEqual(abs(predicted - b.remainingAtT0), tolerance, a.id)
        }
    }

    func testBoostsQueueByTypeAndUndoPreservesElapsedWork() {
        var boosts = BoostStacking.adding(.builderPotion, to: [], at: 100, duration: 3600)
        boosts = BoostStacking.adding(.builderPotion, to: boosts, at: 200, duration: 3600)
        boosts = BoostStacking.adding(.builderBite, to: boosts, at: 200, duration: 3600)
        XCTAssertEqual(boosts.map(\.start), [100, 3700, 200])
        boosts = BoostStacking.undoing(.builderPotion, in: boosts, at: 700)
        XCTAssertEqual(boosts.count, 2)
        boosts = BoostStacking.undoing(.builderPotion, in: boosts, at: 700)
        XCTAssertEqual(boosts.first?.end, 700)
        XCTAssertEqual(BoostStacking.undoing(.builderPotion, in: boosts, at: 800), boosts)
        let finish = TimerEngine.finishTime(t0: 100, remaining: 36000,
                                           windows: [.fixed(start: 100, end: 700, extraRate: 9)])
        XCTAssertEqual(finish, 100 + 36000 - 600 * 9)
    }

    func testPotionAndHelperRatesAddInsteadOfMultiply() {
        let windows: [SpeedWindow] = [.fixed(start: 100, end: 3700, extraRate: 9),
                                      .periodic(firstStart: 100, duration: 3600, period: 82800, extraRate: 8)]
        XCTAssertEqual(TimerEngine.finishTime(t0: 100, remaining: 18 * 3600 + 500, windows: windows), 4200)
    }

    func testOnlyBoostTimeAfterExportCounts() {
        XCTAssertEqual(TimerEngine.finishTime(t0: 10000, remaining: 72000,
                                              windows: [.fixed(start: 8200, end: 11800, extraRate: 9)]),
                       10000 + 72000 - 1800 * 9)
        XCTAssertEqual(TimerEngine.finishTime(t0: 10000, remaining: 72000,
                                              windows: [.fixed(start: 0, end: 10000, extraRate: 9)]), 82000)
    }

    func testHelperCycleRepeatsEvery23Hours() {
        let window = SpeedWindow.periodic(firstStart: 3600, duration: 3600, period: 82800, extraRate: 8)
        XCTAssertEqual(TimerEngine.finishTime(t0: 0, remaining: 72 * 3600, windows: [window]), 48 * 3600)
        XCTAssertEqual(TimerEngine.remaining(t0: 0, remaining: 72 * 3600, windows: [window], at: 48 * 3600), 0)
    }

    func testPetAndResearchBoostsDoNotAffectBuilders() throws {
        var state = try state(2)
        let export = try XCTUnwrap(state.village)
        let builder = try XCTUnwrap(export.jobs.first { $0.category == .builder })
        let engine = TimerEngine()
        let baseline = engine.finishTime(for: builder, village: export, state: state)
        TimerActions.addBoost(.petPotion, state: &state, settings: BoostSettings(), now: export.timestamp)
        TimerActions.addBoost(.researchPotion, state: &state, settings: BoostSettings(), now: export.timestamp)
        XCTAssertEqual(engine.finishTime(for: builder, village: export, state: state), baseline)
    }

    func testSyncRejectsOldFutureAndInvalidButKeepsExistingState() throws {
        let original = try SyncLogic.apply(minimal(time: 200), to: AppState(), now: 200)
        XCTAssertThrowsError(try SyncLogic.apply(minimal(time: 199), to: original, now: 200))
        XCTAssertThrowsError(try SyncLogic.apply(minimal(time: 1000), to: original, now: 200))
        XCTAssertThrowsError(try SyncLogic.apply("invalid", to: original, now: 200))
        XCTAssertEqual(original.village?.timestamp, 200)
    }

    func testSwitchingVillageClearsBoostsAndLinks() throws {
        var original = try state(4)
        original.links.apprenticeJobKey = original.village?.jobs.first?.id
        let other = try SyncLogic.apply(minimal(tag: "#OTHER", time: 100), to: original, now: 1_800_000_000)
        XCTAssertTrue(other.boosts.isEmpty)
        XCTAssertEqual(other.links, HelperLinks())
    }

    func testManualLinkSurvivesSyncAndHelperOnFinishedItemClearsLink() throws {
        var original = try state(4)
        let key = try XCTUnwrap(original.village?.jobs.first { $0.dataID == 107000008 }?.id)
        TimerActions.toggleHelper(jobID: key, state: &original)
        XCTAssertEqual(original.links.apprenticeJobKey, key)
        XCTAssertEqual(try SyncLogic.apply(fixture(4), to: original, now: 1_800_000_000).links.apprenticeJobKey, key)
        TimerActions.toggleHelper(jobID: key, state: &original)
        XCTAssertNil(original.links.apprenticeJobKey)
        let export3 = try state(3)
        XCTAssertNil(export3.links.labAssistantJobKey)
        XCTAssertTrue(try village(3).helperOnFinishedItem.contains(.lab))
    }

    func testGameDataResourcesAndUnknownFallback() throws {
        let data = GameData.bundled
        XCTAssertEqual(data.name(1000011), "Wizard Tower")
        XCTAssertEqual(data.name(999999999), "Unknown (999999999)")
        let module = try XCTUnwrap(village(1).jobs.first { $0.source == .module })
        XCTAssertEqual(data.label(for: module), "Cake-A-Pult Damage → 8")
        XCTAssertGreaterThan(try XCTUnwrap(data.fullDuration(for: module)), 0)
    }

    func testFinishBoundariesFreeBuildersAndTimeline() throws {
        var document = StoredDocument()
        document.state = try state(4)
        let t0 = try XCTUnwrap(document.state.village?.timestamp)
        XCTAssertEqual(DashboardSnapshot(document: document, at: t0 + 351).freeBuilders, 0)
        XCTAssertEqual(DashboardSnapshot(document: document, at: t0 + 352).freeBuilders, 1)
        // Goblin finishing doesn't release a regular builder.
        XCTAssertEqual(DashboardSnapshot(document: document, at: t0 + 2918).freeBuilders, 1)
        let dates = WidgetSchedule.dates(for: document, now: t0)
        XCTAssertEqual(dates.first, t0)
        XCTAssertTrue(dates.contains(t0 + 352))
        XCTAssertEqual(dates, Array(Set(dates)).sorted())
    }

    func testNotificationPlanReschedulesAfterBoostAndDisablesCleanly() throws {
        var document = StoredDocument()
        document.state = try SyncLogic.apply(minimal(), to: AppState(), now: 100)
        XCTAssertTrue(NotificationPlan.make(document: document, now: 100).isEmpty)
        document.settings.notificationsEnabled = true
        let before = try XCTUnwrap(NotificationPlan.make(document: document, now: 100).first)
        TimerActions.addBoost(.builderPotion, state: &document.state, settings: document.settings.boosts, now: 100)
        let after = try XCTUnwrap(NotificationPlan.make(document: document, now: 100).first)
        XCTAssertEqual(before.id, after.id)
        XCTAssertLessThan(after.fireAt, before.fireAt)
        XCTAssertTrue(NotificationPlan.make(document: document, now: after.fireAt).isEmpty)
    }

    func testPersistenceRoundTripAndCorruptDataIsNotSilentlyReset() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = DocumentStore(fileURL: folder.appendingPathComponent("state.json"))
        XCTAssertEqual(try store.load(), StoredDocument())
        var document = StoredDocument()
        document.state = try state(4)
        document.settings.playerName = "Chief Test"
        try store.save(document)
        XCTAssertEqual(try store.load(), document)
        try Data("broken".utf8).write(to: store.fileURL)
        XCTAssertThrowsError(try store.load())
        XCTAssertEqual(try String(contentsOf: store.fileURL), "broken")
    }

    func testAltStoreGroupResolutionPreservesWidgetAndStandaloneStorage() {
        let base = "group.com.kuswaa.clashtimers.ios"
        let mapped = base + ".AB123CD456"
        let unrelated = "group.com.rileytestut.AltStore.AB123CD456"
        XCTAssertEqual(DocumentStore.sharedGroup(configured: base, altStoreGroups: [unrelated, mapped]), mapped)
        XCTAssertEqual(DocumentStore.sharedGroup(configured: base, altStoreGroups: []), base)
        XCTAssertEqual(DocumentStore.sharedGroup(configured: base, altStoreGroups: [unrelated, base + ".extension"]), base)
        XCTAssertNil(DocumentStore.sharedGroup(configured: "", altStoreGroups: [mapped]))
    }

    func testInvalidSettingsCannotBeSaved() throws {
        var document = StoredDocument()
        document.settings.boosts.helperWindow = 0
        let store = DocumentStore(fileURL: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
        XCTAssertThrowsError(try store.save(document))
        XCTAssertEqual(TimerEngine(settings: document.settings.boosts).settings, BoostSettings())
    }

    func testCountdownClampsFinishedTimers() {
        XCTAssertEqual(Countdown.text(seconds: -5), "00:00:00")
        XCTAssertEqual(Countdown.text(seconds: 86401), "1d 00:00:01")
        XCTAssertEqual(Countdown.text(seconds: 3661), "01:01:01")
    }
}
