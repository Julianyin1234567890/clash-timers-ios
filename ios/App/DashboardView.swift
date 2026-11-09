import SwiftUI
import ClashTimersCore

private enum AppSheet: String, Identifiable {
    case importVillage, settings, levels
    var id: String { rawValue }
}

struct DashboardView: View {
    let model: AppModel
    @Environment(\.scenePhase) private var scenePhase
    @State private var sheet: AppSheet?
    @State private var showBoosts = false
    @State private var syncRequested = false

    var body: some View {
        NavigationStack {
            ScrollView {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    VStack(spacing: 14) {
                        Button { sheet = .levels } label: {
                            Label("Refresh levels online", systemImage: "arrow.down.circle.fill")
                                .font(OriginalTheme.font(18)).foregroundStyle(OriginalTheme.ink)
                                .padding(.horizontal, 20).padding(.vertical, 12)
                                .frame(maxWidth: .infinity)
                                .background(OriginalTheme.goldButton, in: RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(OriginalButtonStyle()).disabled(!model.isReady)
                        .accessibilityIdentifier("openLevels")
                        if let profile = model.document.playerProfile {
                            Text("\(profile.name) · TH \(profile.townHallLevel) · \(profile.levels.count) saved levels")
                                .font(.caption).foregroundStyle(OriginalTheme.cream)
                        }
                        VillagePanel(document: model.document, date: context.date,
                                     error: model.storageError, handler: handle)
                        if let status = model.syncStatus {
                            Label(status, systemImage: "checkmark.circle.fill")
                                .font(.subheadline).foregroundStyle(OriginalTheme.cream)
                                .accessibilityIdentifier("syncSuccess")
                        }
                        if model.document.state.exportJSON == nil && model.isReady {
                            Button("Sync copied village") { requestSync() }
                                .font(OriginalTheme.font(18))
                                .foregroundStyle(OriginalTheme.ink)
                                .padding(.horizontal, 20).padding(.vertical, 12)
                                .background(OriginalTheme.goldButton, in: RoundedRectangle(cornerRadius: 10))
                                .buttonStyle(OriginalButtonStyle())
                                .accessibilityIdentifier("startSync")
                        } else if let village = model.document.state.village {
                            Text(village.tag).font(.footnote).foregroundStyle(OriginalTheme.cream)
                            Text("Timer snapshot saved on this iPhone. Copy new data in Clash, then tap Sync to update countdowns. Use Refresh levels online for public upgrade levels.")
                                .font(.caption).foregroundStyle(OriginalTheme.cream)
                                .multilineTextAlignment(.center)
                            Button("Log a potion or snack") { showBoosts = true }
                                .font(OriginalTheme.font(15)).foregroundStyle(OriginalTheme.gold)
                                .accessibilityIdentifier("openBoosts")
                            Text("Log items after using them in Clash. Your item stock is not shown here.")
                                .font(.caption).foregroundStyle(OriginalTheme.cream)
                                .multilineTextAlignment(.center)
                        }
                        Button("Paste village data manually") { sheet = .importVillage }
                            .font(.footnote).foregroundStyle(OriginalTheme.gold)
                            .disabled(!model.isReady)
                            .accessibilityIdentifier("startImport")
                    }
                    .padding(12).frame(maxWidth: 580).frame(maxWidth: .infinity)
                }
            }
            .background(OriginalTheme.color(0x261C14))
            .navigationTitle("Clash Timers")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(OriginalTheme.color(0x3D2A1C), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .tint(OriginalTheme.gold)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { sheet = .settings } label: { Image(systemName: "gearshape") }
                        .accessibilityLabel("Settings").disabled(!model.isReady)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { requestSync() } label: { Image(systemName: "arrow.clockwise") }
                        .accessibilityLabel("Sync copied village").disabled(!model.isReady)
                        .accessibilityIdentifier("syncVillage")
                }
            }
            .navigationDestination(isPresented: $showBoosts) { BoostsView(model: model) }
            .sheet(item: $sheet) { destination in
                switch destination {
                case .importVillage: ImportVillageView(model: model)
                case .settings: SettingsView(model: model)
                case .levels: PlayerLevelsView(model: model)
                }
            }
            .alert(model.alert?.title ?? "", isPresented: Binding(
                get: { sheet == nil && model.alert != nil },
                set: { if !$0 && sheet == nil { model.alert = nil } }
            )) {
                Button("OK") { model.alert = nil }
            } message: { Text(model.alert?.message ?? "") }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    model.refresh()
                    completeRequestedSync()
                }
            }
            .task(id: scenePhase) {
                if scenePhase == .active { await model.refreshLevelsIfNeeded() }
            }
            .onReceive(NotificationCenter.default.publisher(for: .villageDidChange)) { _ in model.refresh() }
            .onOpenURL { url in
                guard url.scheme == "clashtimers" else { return }
                switch url.host {
                case "sync": requestSync()
                case "boosts": showBoosts = true
                case "settings": sheet = .settings
                case "levels": sheet = .levels
                default: break
                }
            }
        }
    }

    private func requestSync() {
        sheet = nil
        showBoosts = false
        syncRequested = true
        completeRequestedSync()
    }

    private func completeRequestedSync() {
        // A widget link may arrive before the app becomes active. Consume it once;
        // returning from the system's paste permission prompt must not read again.
        guard syncRequested, scenePhase == .active else { return }
        syncRequested = false
        if !model.syncFromClipboard() { sheet = .importVillage }
    }

    private func handle(_ action: VillageAction) {
        switch action {
        case .sync: requestSync()
        case .add(let type): model.addBoost(type)
        case .undo(let type): model.undoBoost(type)
        case .helper(let id):
            if let row = DashboardSnapshot(document: model.document, at: Int(Date().timeIntervalSince1970))
                .rows.first(where: { $0.id == id }) {
                model.toggleHelper(row)
            }
        }
    }
}
