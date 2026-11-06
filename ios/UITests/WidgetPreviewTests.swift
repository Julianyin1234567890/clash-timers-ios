import SwiftUI
import WidgetKit
import XCTest
import ClashTimersCore

final class WidgetPreviewTests: XCTestCase {
    /// Capture the production widget content with sample data for the installation guide.
    @MainActor
    func testCaptureWidgetSizes() throws {
        let timestamp = Int(Date.now.timeIntervalSince1970)
        let export = """
        {"tag":"#PREVIEW","timestamp":\(timestamp),
         "buildings":[{"data":1000008,"lvl":4,"timer":36000}],
         "units":[{"data":4000008,"lvl":4,"timer":54000}],
         "pets":[{"data":73000010,"lvl":2,"timer":72000}]}
        """
        var document = StoredDocument()
        document.state = try SyncLogic.apply(export, to: document.state, now: timestamp)
        let entry = VillageEntry(date: Date(timeIntervalSince1970: Double(timestamp)), document: document)
        let sizes: [(WidgetFamily, String, CGSize)] = [
            (.systemSmall, "Widget-small", CGSize(width: 170, height: 170)),
            (.systemMedium, "Widget-medium", CGSize(width: 364, height: 170)),
            (.systemLarge, "Widget-large", CGSize(width: 364, height: 382))
        ]
        for (family, name, size) in sizes {
            let view = VillageWidgetContent(entry: entry, family: family)
                .padding(16)
                .frame(width: size.width, height: size.height, alignment: .topLeading)
                .background(.white, in: RoundedRectangle(cornerRadius: 22))
                .environment(\.colorScheme, .light)
            let renderer = ImageRenderer(content: view)
            renderer.scale = 3
            let png = try XCTUnwrap(renderer.uiImage?.pngData())
            let attachment = XCTAttachment(data: png, uniformTypeIdentifier: "public.png")
            attachment.name = name
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }
}
