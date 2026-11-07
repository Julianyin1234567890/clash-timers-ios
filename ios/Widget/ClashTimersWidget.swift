import SwiftUI
import WidgetKit
import ClashTimersCore

struct VillageProvider: TimelineProvider {
    func placeholder(in context: Context) -> VillageEntry {
        VillageEntry(date: .now, document: StoredDocument())
    }
    func getSnapshot(in context: Context, completion: @escaping (VillageEntry) -> Void) {
        completion(load(at: .now))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<VillageEntry>) -> Void) {
        let now = Date()
        let current = load(at: now)
        let dates = WidgetSchedule.dates(for: current.document, now: Int(now.timeIntervalSince1970))
        let entries = dates.map { VillageEntry(date: Date(timeIntervalSince1970: Double($0)), document: current.document, error: current.error) }
        // iOS chooses the exact reload time. Absolute system countdowns do not depend on this reload.
        completion(Timeline(entries: entries, policy: .after(now.addingTimeInterval(3600))))
    }
    private func load(at date: Date) -> VillageEntry {
        do { return VillageEntry(date: date, document: try SharedStore.make().load()) }
        catch { return VillageEntry(date: date, document: StoredDocument(), error: "Open Clash Timers to check shared storage.") }
    }
}

struct VillageWidgetView: View {
    let entry: VillageEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        VillageWidgetContent(entry: entry, family: family)
            .containerBackground(.clear, for: .widget)
            .widgetURL(URL(string: "clashtimers://timers"))
    }
}

@main
struct ClashTimersWidget: Widget {
    let kind = "ClashTimersWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: VillageProvider()) { VillageWidgetView(entry: $0) }
            .configurationDisplayName("Clash Timers")
            .description("Builder, laboratory, and pet upgrade countdowns.")
            .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
            .contentMarginsDisabled()
            .containerBackgroundRemovable(false)
    }
}
