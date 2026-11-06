import SwiftUI
import WidgetKit
import ClashTimersCore

struct VillageEntry: TimelineEntry {
    let date: Date
    let document: StoredDocument
    var error: String?
    var snapshot: DashboardSnapshot { DashboardSnapshot(document: document, at: Int(date.timeIntervalSince1970)) }
}

struct VillageWidgetContent: View {
    let entry: VillageEntry
    let family: WidgetFamily

    var body: some View {
        let snapshot = entry.snapshot
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Clash Timers", systemImage: "timer").font(.caption.weight(.bold))
                Spacer(minLength: 0)
                if family != .systemSmall {
                    Link(destination: URL(string: "clashtimers://sync")!) {
                        Image(systemName: "arrow.triangle.2.circlepath").padding(4)
                    }.accessibilityLabel("Sync village")
                }
            }.foregroundStyle(.orange)
            if snapshot.village == nil {
                Spacer(minLength: 0)
                Text("Your village,\nat a glance.").font(.headline)
                Text(entry.error ?? "Open Clash Timers and import your village to get started.")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer(minLength: 0)
            } else if family == .systemSmall {
                small(snapshot)
            } else {
                expanded(snapshot)
            }
        }
    }

    private func small(_ snapshot: DashboardSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(snapshot.freeBuilders)/\(snapshot.totalBuilders) builders free").font(.caption)
            if let next = snapshot.nextFinish {
                Text(next.title).font(.headline).lineLimit(2)
                clock(next).font(.system(.title3, design: .rounded, weight: .bold))
            } else {
                Label("All done", systemImage: "checkmark.circle.fill").font(.headline).foregroundStyle(.green)
            }
            Spacer(minLength: 0)
        }
    }

    private func expanded(_ snapshot: DashboardSnapshot) -> some View {
        VStack(alignment: .leading, spacing: family == .systemLarge ? 10 : 6) {
            HStack {
                Text(snapshot.playerName).font(.headline).lineLimit(1)
                Spacer()
                Text("\(snapshot.freeBuilders)/\(snapshot.totalBuilders) free").font(.caption).foregroundStyle(.secondary)
            }
            let limit = family == .systemLarge ? 8 : 2
            ForEach(Array(snapshot.rows.prefix(limit))) { row in
                HStack(spacing: 8) {
                    Image(systemName: row.isDone ? "checkmark.circle.fill" : row.job.category.symbol)
                        .foregroundStyle(row.isDone ? .green : .orange)
                        .frame(width: 16)
                    Text(row.label).font(.caption).lineLimit(1)
                    Spacer(minLength: 4)
                    if row.isDone {
                        Text("Done").font(.caption.weight(.semibold)).foregroundStyle(.green)
                    } else {
                        clock(row).font(.caption.monospacedDigit()).frame(width: 92, alignment: .trailing)
                    }
                }
            }
            if snapshot.rows.isEmpty { Text("All builders, lab & pets are free.").font(.caption).foregroundStyle(.secondary) }
            Spacer(minLength: 0)
            HStack {
                if snapshot.rows.count > limit {
                    Text("+\(snapshot.rows.count - limit) more in app").font(.caption2).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Link("Potions & snacks", destination: URL(string: "clashtimers://boosts")!).font(.caption2)
            }
        }
    }

    private func clock(_ row: TimerRow) -> some View {
        // Closed range stops at zero, unlike Text(date, style: .timer), which starts counting up.
        Text(timerInterval: entry.date...max(entry.date, row.finishDate), countsDown: true)
            .monospacedDigit()
            .minimumScaleFactor(0.7)
            .lineLimit(1)
    }
}
