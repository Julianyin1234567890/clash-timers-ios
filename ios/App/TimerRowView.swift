import SwiftUI
import ClashTimersCore

extension JobCategory {
    var color: Color {
        switch self {
        case .builder: return .orange
        case .lab: return .purple
        case .pet: return .teal
        }
    }
}

struct TimerRowView: View {
    let row: TimerRow
    let now: Int
    let toggleHelper: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: row.isDone ? "checkmark.circle.fill" : row.job.category.symbol)
                    .font(.title3)
                    .foregroundStyle(row.isDone ? .green : row.job.category.color)
                    .frame(width: 40, height: 40)
                    .background(row.job.category.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(row.title).font(.headline)
                    Text(row.job.isNewBuilding ? "New construction" : "Level \(row.job.currentLevel) → \(row.job.targetLevel)")
                        .font(.subheadline).foregroundStyle(.secondary)
                    if row.job.isGoblin {
                        Label("Goblin Builder", systemImage: "sparkles")
                            .font(.caption).foregroundStyle(.green)
                    }
                }
                Spacer(minLength: 0)
                if row.helperAvailable && !row.isDone {
                    Button(action: toggleHelper) {
                        Image(systemName: row.helperLinked ? "person.crop.circle.fill.badge.checkmark" : "person.crop.circle.badge.plus")
                            .font(.title3)
                            .foregroundStyle(row.helperLinked ? .orange : .secondary)
                            .frame(width: 44, height: 44)
                            .background(.quaternary, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(row.helperLinked ? "Unlink" : "Link") helper for \(row.title)")
                }
            }
            if row.isDone {
                Label("Finished — ready for the next upgrade", systemImage: "checkmark")
                    .font(.subheadline.weight(.medium)).foregroundStyle(.green)
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .firstTextBaseline) {
                        countdown
                        Spacer()
                        finishLabel
                    }
                    VStack(alignment: .leading, spacing: 4) { countdown; finishLabel }
                }
                ProgressView(value: row.progress).tint(row.job.category.color)
                    .accessibilityLabel("Upgrade progress")
                if row.helperLinked {
                    Label("Includes future helper sessions", systemImage: "person.fill.checkmark")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20))
    }
    private var countdown: some View {
        Text(Countdown.text(seconds: row.finishAt - now))
            .font(.system(.title3, design: .rounded, weight: .bold))
            .monospacedDigit()
            .accessibilityLabel("Time remaining \(Countdown.text(seconds: row.finishAt - now))")
    }
    private var finishLabel: some View {
        Text(row.finishDate, format: .dateTime.weekday(.abbreviated).hour().minute())
            .font(.caption).foregroundStyle(.secondary)
    }
}
