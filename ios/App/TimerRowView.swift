import SwiftUI
import ClashTimersCore

struct TimerRowView: View {
    let row: TimerRow?
    let category: JobCategory
    let date: Date
    var compact = false
    var systemCountdown = false
    var rowHeight: CGFloat?
    var handler: ((VillageAction) -> Void)?

    private var height: CGFloat { rowHeight ?? (compact ? 25 : 30) }
    private var iconSize: CGFloat { min(compact ? 20 : 24, height - 3) }
    private var title: String { row?.title ?? (category == .lab ? "Laboratory" : "Pet House") }
    private var finished: Bool { row?.isDone ?? true }
    private var artwork: [String] {
        guard let job = row?.job else { return [category == .lab ? "1000007" : "1000068"] }
        return [job.dataID, job.typeDataID, job.parentDataID].compactMap { $0 }.map(String.init)
    }

    var body: some View {
        HStack(spacing: 4) {
            VillageArtwork(names: artwork, fallback: initials)
                .padding(1).frame(width: iconSize, height: iconSize)
                .background(.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 6))
                .overlay { RoundedRectangle(cornerRadius: 6).stroke(.white.opacity(0.15), lineWidth: 1) }
            name
            Spacer(minLength: 0)
            status
            helper.frame(width: compact ? 19 : 22, height: compact ? 19 : 22)
        }
        .padding(.horizontal, 4)
        .frame(height: height)
        .background { background }
        .accessibilityElement(children: .contain)
    }

    private var initials: String {
        title.split(separator: " ").prefix(2).compactMap(\.first).map(String.init).joined()
    }

    private var name: some View {
        HStack(spacing: 3) {
            if row?.job.isGoblin == true {
                Text("GOBLIN").font(.system(size: compact ? 7 : 8, weight: .bold))
                    .foregroundStyle(OriginalTheme.color(0x123B0C)).padding(.horizontal, 3).padding(.vertical, 1)
                    .background(OriginalTheme.color(0xB8F07A), in: RoundedRectangle(cornerRadius: 4))
                    .overlay { RoundedRectangle(cornerRadius: 4).stroke(OriginalTheme.color(0x2F5E14), lineWidth: 1) }
            }
            Text(title).villageText(compact ? 12 : 13.5)
                .lineLimit(1).truncationMode(.tail)
            if let row, !finished {
                Text(row.job.isNewBuilding ? "(new)" : "→ \(row.job.targetLevel)")
                    .villageText(compact ? 10 : 11, color: OriginalTheme.cream)
                    .fixedSize()
            }
        }
    }

    private var status: some View {
        HStack(spacing: 3) {
            if let row, !finished {
                ClockArtwork().frame(width: compact ? 11 : 12, height: compact ? 11 : 12)
                VillageCountdown(finish: row.finishDate, date: date, system: systemCountdown, fontSize: compact ? 12 : 13)
                    .villageText(compact ? 12 : 13)
            } else {
                Text(row == nil ? "Idle" : "Completed").villageText(compact ? 12 : 13).fixedSize()
                if row != nil {
                    Image(systemName: "checkmark").font(.system(size: 12, weight: .heavy))
                        .foregroundStyle(OriginalTheme.green)
                }
            }
        }
        .layoutPriority(1)
    }

    @ViewBuilder
    private var helper: some View {
        if let row, !finished, category != .pet {
            VillageActionButton(action: .helper(row.id), handler: handler) {
                Group {
                    if row.helperLinked {
                        VillageArtwork(names: [category == .builder ? "apprentice" : "lab_assistant"], fallback: "H")
                            .padding(2)
                    } else {
                        Text("+").font(.system(size: compact ? 15 : 17, weight: .heavy)).foregroundStyle(.white)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(row.helperLinked ? OriginalTheme.goldButton : OriginalTheme.greenButton,
                            in: RoundedRectangle(cornerRadius: 7))
                .overlay {
                    RoundedRectangle(cornerRadius: 7)
                        .strokeBorder(OriginalTheme.color(row.helperLinked ? 0x8A5A10 : 0x2F5E14), lineWidth: 1.5)
                }
            }
            .accessibilityLabel("\(row.helperLinked ? "Unlink" : "Link") helper for \(row.title)")
            .accessibilityIdentifier("helper-\(row.id)")
        } else {
            Color.clear
        }
    }

    private var background: some View {
        GeometryReader { geometry in
            RoundedRectangle(cornerRadius: 7)
                .fill(OriginalTheme.color(0x2E2219))
                .overlay(alignment: .leading) {
                    if finished {
                        OriginalTheme.done
                    } else if let row {
                        OriginalTheme.progress.frame(width: max(0, geometry.size.width - 3) * row.progress)
                            .padding(1.5)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 7))
                .overlay {
                    RoundedRectangle(cornerRadius: 7).strokeBorder(OriginalTheme.color(0x1E160F), lineWidth: 1.5)
                }
        }
    }
}

struct VillageCountdown: View {
    let finish: Date
    let date: Date
    var system: Bool
    var fontSize: CGFloat = 13
    private var remaining: Int { max(0, Int(finish.timeIntervalSince(date))) }

    var body: some View {
        if system {
            let end = max(date, finish.addingTimeInterval(-Double(remaining / 86400 * 86400)))
            (Text(Countdown.timerPrefix(seconds: remaining))
             + Text(timerInterval: date...end, countsDown: true))
                .monospacedDigit().multilineTextAlignment(.trailing)
                .lineLimit(1).minimumScaleFactor(0.75)
                .frame(width: fontSize * (remaining >= 86400 ? 7 : 4.8))
        } else {
            Text(Countdown.text(seconds: remaining)).monospacedDigit().fixedSize()
        }
    }
}

/// Original Android vector clock, used when the optional clock artwork is absent.
struct ClockArtwork: View {
    var body: some View {
        ZStack {
            Circle().fill(OriginalTheme.color(0xB68A22))
            Circle().strokeBorder(OriginalTheme.color(0x6B4A10), lineWidth: 0.7)
            Circle().fill(OriginalTheme.color(0xE8C56A)).padding(1.5)
            Circle().fill(.white).padding(2.3)
            GeometryReader { geometry in
                Path { path in
                    path.move(to: CGPoint(x: geometry.size.width * 0.5, y: geometry.size.height * 0.32))
                    path.addLine(to: CGPoint(x: geometry.size.width * 0.5, y: geometry.size.height * 0.5))
                    path.addLine(to: CGPoint(x: geometry.size.width * 0.63, y: geometry.size.height * 0.575))
                }.stroke(OriginalTheme.color(0x6B4A10), style: StrokeStyle(lineWidth: 1, lineCap: .round))
            }
        }.accessibilityHidden(true)
    }
}
