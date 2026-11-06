import SwiftUI
import ClashTimersCore

private enum AppSheet: String, Identifiable {
    case importVillage, settings
    var id: String { rawValue }
}

struct DashboardView: View {
    let model: AppModel
    @Environment(\.scenePhase) private var scenePhase
    @State private var sheet: AppSheet?
    @State private var showBoosts = false

    var body: some View {
        NavigationStack {
            Group {
                if let error = model.storageError {
                    ContentUnavailableView {
                        Label("Couldn’t open saved data", systemImage: "externaldrive.badge.exclamationmark")
                    } description: { Text(error) }
                } else if model.document.state.exportJSON == nil {
                    welcome
                } else {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        let now = Int(context.date.timeIntervalSince1970)
                        let snapshot = DashboardSnapshot(document: model.document, at: now)
                        ScrollView {
                            VStack(alignment: .leading, spacing: 24) {
                                villageHeader(snapshot)
                                summary(snapshot, now: now)
                                ForEach(JobCategory.allCases, id: \.self) { category in
                                    categorySection(category, snapshot: snapshot, now: now)
                                }
                                Text("Finish times include planned helper sessions. Helpers still need you to open the game; sync again to correct predictions.")
                                    .font(.footnote).foregroundStyle(.secondary)
                            }
                            .padding(20)
                            .frame(maxWidth: 700)
                            .frame(maxWidth: .infinity)
                        }
                        .background(Color(uiColor: .systemGroupedBackground))
                    }
                }
            }
            .navigationTitle("Clash Timers")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { sheet = .settings } label: { Image(systemName: "gearshape") }
                        .accessibilityLabel("Settings")
                        .disabled(!model.isReady)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { sheet = .importVillage } label: { Label("Sync", systemImage: "arrow.triangle.2.circlepath") }
                        .disabled(!model.isReady)
                        .accessibilityIdentifier("syncVillage")
                }
            }
            .navigationDestination(isPresented: $showBoosts) { BoostsView(model: model) }
            .sheet(item: $sheet) { destination in
                switch destination {
                case .importVillage: ImportVillageView(model: model)
                case .settings: SettingsView(model: model)
                }
            }
            .alert(model.alert?.title ?? "", isPresented: Binding(
                get: { sheet == nil && model.alert != nil },
                set: { if !$0 && sheet == nil { model.alert = nil } }
            )) {
                Button("OK") { model.alert = nil }
            } message: { Text(model.alert?.message ?? "") }
            .onChange(of: scenePhase) { _, phase in if phase == .active { model.refresh() } }
            .onOpenURL { url in
                guard url.scheme == "clashtimers" else { return }
                switch url.host {
                case "sync": sheet = .importVillage
                case "boosts": showBoosts = true
                case "settings": sheet = .settings
                default: break
                }
            }
        }
    }

    private var welcome: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Image(systemName: "timer")
                    .font(.system(size: 56, weight: .medium))
                    .foregroundStyle(.orange)
                    .padding(24)
                    .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 28))
                    .accessibilityHidden(true)
                Text("Your village.\nRight on time.")
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                Text("Keep every builder, laboratory, and pet upgrade in view. Import your village once, and your timers keep counting offline.")
                    .font(.title3).foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 16) {
                    Label("Accurate potion & helper predictions", systemImage: "sparkles")
                    Label("Optional finish notifications", systemImage: "bell.badge")
                    Label("No account, ads, or tracking", systemImage: "lock.shield")
                }
                Button { sheet = .importVillage } label: {
                    Label("Import your village", systemImage: "arrow.down.doc.fill")
                        .frame(maxWidth: .infinity).padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("startImport")
                Text("Unofficial fan project. Not endorsed by Supercell.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .padding(24).frame(maxWidth: 620).frame(maxWidth: .infinity)
        }
    }

    private func villageHeader(_ snapshot: DashboardSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Welcome back, \(snapshot.playerName)")
                .font(.system(.title2, design: .rounded, weight: .bold))
            if let village = snapshot.village {
                HStack {
                    Text(village.tag)
                    if let th = village.townHallLevel { Text("•  Town Hall \(th)") }
                }.font(.subheadline).foregroundStyle(.secondary)
                Text("Exported \(Date(timeIntervalSince1970: Double(village.timestamp)), format: .dateTime.month(.abbreviated).day().hour().minute())")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func summary(_ snapshot: DashboardSnapshot, now: Int) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(snapshot.freeBuilders)/\(snapshot.totalBuilders)")
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                Text("builders free").font(.headline)
            }
            if let next = snapshot.nextFinish {
                VStack(alignment: .leading, spacing: 4) {
                    Text("UP NEXT").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    Text(next.label).font(.headline)
                    Text(Countdown.text(seconds: next.finishAt - now))
                        .font(.system(.title2, design: .rounded, weight: .semibold)).monospacedDigit()
                }
            } else {
                Label("All upgrades finished", systemImage: "checkmark.seal.fill").foregroundStyle(.green)
            }
            Button { showBoosts = true } label: {
                Label("Potions & snacks", systemImage: "sparkles").frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("openBoosts")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 24))
    }

    private func categorySection(_ category: JobCategory, snapshot: DashboardSnapshot, now: Int) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(category.title, systemImage: category.symbol)
                .font(.title3.weight(.semibold)).foregroundStyle(category.color)
            let rows = snapshot.rows(for: category)
            ForEach(rows) { row in
                TimerRowView(row: row, now: now) { model.toggleHelper(row) }
            }
            if rows.isEmpty {
                Label("\(category == .builder ? "Builders are" : "\(category.title) is") free", systemImage: "checkmark.circle")
                    .foregroundStyle(.secondary).padding(20).frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20))
            }
        }
    }
}
