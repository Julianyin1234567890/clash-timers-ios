import SwiftUI
import ClashTimersCore

enum VillagePanelSize { case small, medium, large, app }

struct VillagePanel: View {
    let document: StoredDocument
    let date: Date
    var size: VillagePanelSize = .app
    var error: String?
    var handler: ((VillageAction) -> Void)?
    private var now: Int { Int(date.timeIntervalSince1970) }
    private var snapshot: DashboardSnapshot { DashboardSnapshot(document: document, at: now) }

    var body: some View {
        Group {
            if size == .app {
                content(snapshot, compact: false, builderLimit: nil, rowHeight: nil).padding(10)
            } else {
                GeometryReader { geometry in
                    let builderCount = snapshot.rows(for: .builder).count
                    let capacity = max(0, Int((geometry.size.height - 160) / 22) - 2)
                    let limit = min(8, capacity)
                    let rows = max(1, min(builderCount, limit) + 2)
                    let rowHeight = min(25, max(20, (geometry.size.height - 160) / CGFloat(rows) - 2))
                    content(snapshot, compact: true, builderLimit: size == .large ? limit : 1,
                            rowHeight: size == .medium ? 23 : rowHeight)
                        .padding(10)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                }
            }
        }
        .background { WoodenPanel() }
        .environment(\.colorScheme, .light)
    }

    @ViewBuilder
    private func content(_ snapshot: DashboardSnapshot, compact: Bool, builderLimit: Int?, rowHeight: CGFloat?) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            header(snapshot)
            if let error {
                Text(error).villageText(13, color: OriginalTheme.color(0xFF7A7A))
                    .padding(.vertical, 10).lineLimit(4)
            } else if snapshot.village == nil {
                Text("Copy village data in Clash, then tap Sync")
                    .villageText(14, color: OriginalTheme.cream).padding(.vertical, 12)
            } else if size == .small {
                small(snapshot)
            } else {
                sectionHeader(.builder, snapshot: snapshot)
                let builders = snapshot.rows(for: .builder)
                ForEach(Array(builders.prefix(builderLimit ?? builders.count))) { row in
                    timer(row, category: .builder, compact: compact, rowHeight: rowHeight)
                }
                if let builderLimit, builders.count > builderLimit {
                    Text("+\(builders.count - builderLimit) builders in app")
                        .villageText(9, color: OriginalTheme.cream, shadow: false)
                        .frame(maxWidth: .infinity, alignment: .trailing).padding(.bottom, 2)
                }
                if size == .medium {
                    // The shorter system size keeps one row from each category visible.
                    timer(snapshot.rows(for: .lab).first, category: .lab, compact: true, rowHeight: rowHeight)
                    timer(snapshot.rows(for: .pet).first, category: .pet, compact: true, rowHeight: rowHeight)
                } else {
                    sectionHeader(.lab, snapshot: snapshot)
                    timer(snapshot.rows(for: .lab).first, category: .lab, compact: compact, rowHeight: rowHeight)
                    sectionHeader(.pet, snapshot: snapshot)
                    timer(snapshot.rows(for: .pet).first, category: .pet, compact: compact, rowHeight: rowHeight)
                    footer(snapshot).padding(.top, 6)
                }
            }
        }
    }

    private func header(_ snapshot: DashboardSnapshot) -> some View {
        HStack(spacing: 4) {
            (Text(snapshot.playerName).font(OriginalTheme.font(size == .small ? 15 : 17)).foregroundColor(.white)
             + Text(snapshot.village?.townHallLevel.map { " TH\($0)" } ?? "")
                .font(OriginalTheme.font(12)).foregroundColor(OriginalTheme.gold))
                .lineLimit(1).minimumScaleFactor(0.75)
                .shadow(color: .black.opacity(0.45), radius: 0, x: 0, y: 2)
            Spacer(minLength: 2)
            VillageActionButton(action: .sync, handler: handler) {
                HStack(spacing: 5) {
                    Image(systemName: "arrow.clockwise").font(.system(size: 12, weight: .semibold))
                    if size != .small { Text("Sync").font(OriginalTheme.font(13)) }
                }
                .foregroundStyle(OriginalTheme.ink)
                .padding(.horizontal, size == .small ? 7 : 10).padding(.top, 5).padding(.bottom, 7)
                .background {
                    RoundedRectangle(cornerRadius: 10).fill(OriginalTheme.color(0x6B4308))
                        .overlay(alignment: .top) {
                            RoundedRectangle(cornerRadius: 10).fill(OriginalTheme.goldButton)
                                .overlay {
                                    RoundedRectangle(cornerRadius: 10)
                                        .strokeBorder(OriginalTheme.color(0x8A5A10), lineWidth: 1.5)
                                }.padding(.bottom, 2)
                        }
                }
            }
            .accessibilityLabel("Sync village").accessibilityIdentifier("panelSync")
        }
        .padding(.horizontal, 4).padding(.top, 2).padding(.bottom, 6)
    }

    private func sectionHeader(_ category: JobCategory, snapshot: DashboardSnapshot) -> some View {
        HStack(spacing: 4) {
            if category == .builder {
                (Text("BUILDERS \(snapshot.totalBuilders - snapshot.freeBuilders)/\(snapshot.totalBuilders)")
                    .foregroundColor(OriginalTheme.gold)
                 + Text(snapshot.rows.contains { $0.job.isGoblin && !$0.isDone } ? " + Goblin" : "")
                    .foregroundColor(OriginalTheme.green))
                    .font(OriginalTheme.font(12.5)).lineLimit(1).minimumScaleFactor(0.75)
            } else {
                Text(category == .lab ? "LAB" : "PETS")
                    .villageText(12.5, color: OriginalTheme.gold).tracking(0.3)
            }
            Spacer(minLength: 0)
            if category == .builder { pill(.builderBite) }
            pill(category == .builder ? .builderPotion : category == .lab ? .researchPotion : .petPotion)
        }
        .padding(.horizontal, 4).padding(.top, 4).padding(.bottom, 3)
    }

    private func pill(_ type: BoostType) -> some View {
        let active = document.state.boosts.contains { $0.type == type && $0.end > now }
        let icon: String = switch type {
        case .builderBite: "builder_bite"
        case .builderPotion: "builder_potion"
        case .researchPotion: "research_potion"
        case .petPotion: "pet_potion"
        }
        return HStack(spacing: 0) {
            VillageActionButton(action: .add(type), handler: handler) {
                HStack(spacing: 3) {
                    VillageArtwork(names: [icon]).frame(width: 14, height: 14)
                    Text(VillageLabels.boostText(type, document: document, now: now))
                        .villageText(11, color: active ? OriginalTheme.gold : .white, shadow: false)
                        .fixedSize()
                }.padding(.horizontal, 7).frame(height: 22)
            }.accessibilityLabel("Record \(type.title)").accessibilityIdentifier("panel-add-\(type.rawValue)")
            if active {
                Rectangle().fill(OriginalTheme.color(0xC98A1A)).frame(width: 1, height: 12)
                VillageActionButton(action: .undo(type), handler: handler) {
                    Text("−").font(.system(size: 15, weight: .bold)).foregroundStyle(OriginalTheme.gold)
                        .padding(.horizontal, 6).frame(height: 22)
                }.accessibilityLabel("Undo \(type.title)").accessibilityIdentifier("panel-undo-\(type.rawValue)")
            }
        }
        .background(active ? OriginalTheme.gradient(0x3B2A12, 0x2A1E10) : OriginalTheme.gradient(0x2A1E14, 0x2A1E14),
                    in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(OriginalTheme.color(active ? 0xC98A1A : 0x1A120B), lineWidth: 1.5)
                .allowsHitTesting(false)
        }
    }

    private func timer(_ row: TimerRow?, category: JobCategory, compact: Bool, rowHeight: CGFloat?) -> some View {
        TimerRowView(row: row, category: category, date: date, compact: compact,
                     systemCountdown: size != .app, rowHeight: rowHeight, handler: handler)
            .padding(.bottom, compact ? 2 : 3)
    }

    private func footer(_ snapshot: DashboardSnapshot) -> some View {
        let apprentice = VillageLabels.helperName(.builder, snapshot: snapshot)
        let assistant = VillageLabels.helperName(.lab, snapshot: snapshot)
        return HStack(alignment: .center, spacing: 5) {
            (Text(apprentice.map { "Apprentice: \($0)" } ?? "Apprentice idle")
                .foregroundColor(apprentice == nil ? OriginalTheme.idle : OriginalTheme.cream)
             + Text(" · ").foregroundColor(OriginalTheme.cream)
             + Text(assistant.map { "Assistant: \($0)" } ?? "Assistant idle")
                .foregroundColor(assistant == nil ? OriginalTheme.idle : OriginalTheme.cream))
                .font(OriginalTheme.font(11)).lineLimit(1).minimumScaleFactor(0.7)
            Spacer(minLength: 0)
            if let village = snapshot.village {
                Text(VillageLabels.syncAge(timestamp: village.timestamp, now: now))
                    .villageText(10, color: OriginalTheme.cream, shadow: false)
                    .lineLimit(1).minimumScaleFactor(0.75)
            }
        }.padding(.horizontal, 4)
    }

    private func small(_ snapshot: DashboardSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("BUILDERS \(snapshot.totalBuilders - snapshot.freeBuilders)/\(snapshot.totalBuilders)")
                .villageText(12.5, color: OriginalTheme.gold)
            if let row = snapshot.nextFinish {
                HStack(spacing: 5) {
                    VillageArtwork(names: [String(row.job.dataID)]).frame(width: 27, height: 27)
                    Text(row.label).villageText(12).lineLimit(2)
                }
                HStack(spacing: 4) {
                    ClockArtwork().frame(width: 14, height: 14)
                    VillageCountdown(finish: row.finishDate, date: date, system: true)
                        .villageText(16)
                }
            } else {
                Text("Completed ✓").villageText(16)
            }
            Spacer(minLength: 0)
        }.padding(.horizontal, 3)
    }
}
