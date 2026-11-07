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
            ScrollView {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    VStack(spacing: 14) {
                        VillagePanel(document: model.document, date: context.date,
                                     error: model.storageError, handler: handle)
                        if model.document.state.exportJSON == nil && model.isReady {
                            Button("Import your village") { sheet = .importVillage }
                                .font(OriginalTheme.font(18))
                                .foregroundStyle(OriginalTheme.ink)
                                .padding(.horizontal, 20).padding(.vertical, 12)
                                .background(OriginalTheme.goldButton, in: RoundedRectangle(cornerRadius: 10))
                                .buttonStyle(OriginalButtonStyle())
                                .accessibilityIdentifier("startImport")
                        } else if let village = model.document.state.village {
                            Text(village.tag).font(.footnote).foregroundStyle(OriginalTheme.cream)
                            Button("Potions & snacks") { showBoosts = true }
                                .font(OriginalTheme.font(15)).foregroundStyle(OriginalTheme.gold)
                                .accessibilityIdentifier("openBoosts")
                        }
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
                    Button { sheet = .importVillage } label: { Image(systemName: "arrow.clockwise") }
                        .accessibilityLabel("Sync").disabled(!model.isReady)
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
            .onReceive(NotificationCenter.default.publisher(for: .villageDidChange)) { _ in model.refresh() }
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

    private func handle(_ action: VillageAction) {
        switch action {
        case .sync: sheet = .importVillage
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
