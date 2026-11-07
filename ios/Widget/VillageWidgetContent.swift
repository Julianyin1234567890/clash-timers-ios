import SwiftUI
import WidgetKit
import ClashTimersCore

struct VillageEntry: TimelineEntry {
    let date: Date
    let document: StoredDocument
    var error: String?
}

struct VillageWidgetContent: View {
    let entry: VillageEntry
    let family: WidgetFamily

    var body: some View {
        VillagePanel(document: entry.document, date: entry.date, size: size, error: entry.error)
    }

    private var size: VillagePanelSize {
        switch family {
        case .systemSmall: .small
        case .systemMedium: .medium
        default: .large
        }
    }
}
