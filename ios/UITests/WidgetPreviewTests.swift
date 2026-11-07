import SwiftUI
import UIKit
import WidgetKit
import XCTest
import ClashTimersCore

final class WidgetPreviewTests: XCTestCase {
    private func village(at timestamp: Int) throws -> StoredDocument {
        let export = """
        {"tag":"#PREVIEW","timestamp":\(timestamp),
         "helpers":[{"data":93000000,"lvl":8,"helper_cooldown":0},{"data":93000001,"lvl":12,"helper_cooldown":0}],
         "buildings":[{"data":1000001,"lvl":18},{"data":1000011,"lvl":14,"timer":86270,"extra":true},
                      {"data":1000084,"lvl":2,"timer":91667},{"data":1000021,"lvl":11,"timer":142598}],
         "heroes":[{"data":28000007,"lvl":21,"timer":94984},{"data":28000001,"lvl":97,"timer":119033},
                   {"data":28000006,"lvl":83,"timer":125181},{"data":28000002,"lvl":76,"timer":125596}],
         "spells":[{"data":26000120,"lvl":3,"timer":541037}],
         "pets":[{"data":73000016,"lvl":7,"timer":13250}]}
        """
        var document = StoredDocument()
        document.state = try SyncLogic.apply(export, to: document.state, now: timestamp)
        document.settings.playerName = "Kuswa"
        document.settings.totalBuildersOverride = 6
        return document
    }

    /// Every preview uses the production views, original font and decoded source artwork.
    @MainActor
    func testCaptureOriginalAppearanceAndStates() throws {
        let timestamp = Int(Date.now.timeIntervalSince1970)
        let document = try village(at: timestamp)
        let sizes: [(WidgetFamily, String, CGSize)] = [
            (.systemSmall, "Widget-small", CGSize(width: 170, height: 170)),
            (.systemMedium, "Widget-medium", CGSize(width: 364, height: 170)),
            (.systemLarge, "Widget-large", CGSize(width: 364, height: 382))
        ]
        for (family, name, size) in sizes {
            let entry = VillageEntry(date: Date(timeIntervalSince1970: Double(timestamp)), document: document)
            try capture(VillageWidgetContent(entry: entry, family: family), name: name, size: size)
        }
        XCTAssertNotNil(UIFont(name: "LilitaOne", size: 13), "The original font must actually be registered.")
        for name in ["1000011", "1000084", "28000007", "73000016", "builder_potion", "apprentice"] {
            XCTAssertNotNil(OriginalTheme.image([name]), "Original artwork missing for \(name)")
        }
        try capture(VillagePanel(document: document, date: Date(timeIntervalSince1970: Double(timestamp))),
                    name: "Original-full-panel", size: CGSize(width: 364, height: 475))

        var boosted = document
        TimerActions.addBoost(.builderPotion, state: &boosted.state, settings: boosted.settings.boosts, now: timestamp)
        let active = VillageEntry(date: Date(timeIntervalSince1970: Double(timestamp)), document: boosted)
        try capture(VillageWidgetContent(entry: active, family: .systemLarge),
                    name: "Widget-active-potion", size: CGSize(width: 364, height: 382))

        let wizard = try XCTUnwrap(document.state.village?.jobs.first { $0.dataID == 1000011 })
        TimerActions.toggleHelper(jobID: wizard.id, state: &boosted.state)
        let linked = VillageEntry(date: Date(timeIntervalSince1970: Double(timestamp)), document: boosted)
        try capture(VillageWidgetContent(entry: linked, family: .systemLarge),
                    name: "Widget-linked-helper", size: CGSize(width: 364, height: 382))

        let finished = VillageEntry(date: Date(timeIntervalSince1970: Double(timestamp + 900000)), document: document)
        try capture(VillageWidgetContent(entry: finished, family: .systemLarge),
                    name: "Widget-completed", size: CGSize(width: 364, height: 382))
        let empty = VillageEntry(date: .now, document: StoredDocument())
        try capture(VillageWidgetContent(entry: empty, family: .systemMedium),
                    name: "Widget-empty", size: CGSize(width: 364, height: 170))
    }

    @MainActor
    private func capture<V: View>(_ view: V, name: String, size: CGSize) throws {
        let renderer = ImageRenderer(content: view
            .frame(width: size.width, height: size.height, alignment: .topLeading)
            .environment(\.colorScheme, .light))
        renderer.scale = 3
        let png = try XCTUnwrap(renderer.uiImage?.pngData())
        let attachment = XCTAttachment(data: png, uniformTypeIdentifier: "public.png")
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
