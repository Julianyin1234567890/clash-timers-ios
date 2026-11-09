import SwiftUI
import ClashTimersCore

struct PlayerLevelsView: View {
    let model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var tag: String
    @State private var requestID: UUID?
    @State private var confirmingClear = false
    @FocusState private var editingTag: Bool

    init(model: AppModel) {
        self.model = model
        _tag = State(initialValue: model.document.playerProfile?.tag ?? model.document.state.village?.tag ?? "")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    connectionPanel
                    if let error = model.levelsError {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(OriginalTheme.idle).font(.subheadline)
                            .accessibilityIdentifier("levelsError")
                    }
                    if let profile = model.document.playerProfile {
                        profileHeader(profile)
                        ForEach(ProfileCategory.allCases, id: \.self) { category in
                            let items = profile.levels.filter { $0.category == category }
                            if !items.isEmpty { levelsPanel(category.title, items: items) }
                        }
                        Button("Remove saved online profile", role: .destructive) { confirmingClear = true }
                            .disabled(model.isRefreshingLevels)
                    }
                    Text("Online levels do not include active building countdowns or your potion and snack stock. Widget timers still use your last in-game export.")
                        .font(.footnote).foregroundStyle(OriginalTheme.cream)
                    Link("Level data: Clash of Stats", destination: URL(string: "https://www.clashofstats.com")!)
                        .font(.footnote).foregroundStyle(OriginalTheme.gold)
                }
                .padding().frame(maxWidth: 580).frame(maxWidth: .infinity)
            }
            .background(OriginalTheme.color(0x261C14))
            .navigationTitle("Village levels")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(OriginalTheme.color(0x3D2A1C), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .tint(OriginalTheme.gold)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .task(id: requestID) {
                guard requestID != nil else { return }
                await model.refreshLevels(tag: tag)
            }
            .confirmationDialog("Remove saved levels and stop automatic level refresh?", isPresented: $confirmingClear, titleVisibility: .visible) {
                Button("Remove online profile", role: .destructive) { model.clearLevels() }
            }
            .alert(model.alert?.title ?? "", isPresented: Binding(
                get: { model.alert != nil }, set: { if !$0 { model.alert = nil } }
            )) {
                Button("OK") { model.alert = nil }
            } message: { Text(model.alert?.message ?? "") }
        }
    }

    private var connectionPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Download your upgrade levels").villageText(23, color: OriginalTheme.gold)
            Text("Enter your player tag once. Then refresh here without opening Clash or copying village data.")
                .font(.subheadline).foregroundStyle(OriginalTheme.cream)
            TextField("#PLAYER TAG", text: $tag)
                .textInputAutocapitalization(.characters).autocorrectionDisabled()
                .font(.body.monospaced()).foregroundStyle(.white)
                .padding(12).background(.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 8))
                .accessibilityLabel("Player tag").accessibilityIdentifier("onlinePlayerTag")
                .focused($editingTag).disabled(model.isRefreshingLevels)
                .submitLabel(.go).onSubmit(requestRefresh)
            Button(action: requestRefresh) {
                HStack {
                    if model.isRefreshingLevels { ProgressView().tint(OriginalTheme.ink) }
                    Text(model.isRefreshingLevels ? "Downloading…" : "Download & sync levels")
                        .font(OriginalTheme.font(19))
                }
                .foregroundStyle(OriginalTheme.ink).frame(maxWidth: .infinity).padding(12)
                .background(OriginalTheme.goldButton, in: RoundedRectangle(cornerRadius: 9))
            }
            .buttonStyle(OriginalButtonStyle())
            .disabled(model.isRefreshingLevels || tag.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .accessibilityIdentifier("downloadLevels")
            Text("This sends your public player tag to Clash of Stats over the internet. No Supercell login or API key is needed. The service may return cached levels.")
                .font(.caption).foregroundStyle(OriginalTheme.cream)
        }
        .padding(16).background { WoodenPanel() }
    }

    private func profileHeader(_ profile: PlayerProfile) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("\(profile.name) · TH \(profile.townHallLevel)").villageText(23, color: OriginalTheme.gold)
                .accessibilityIdentifier("onlineProfileName")
            Text(profile.tag).font(.footnote.monospaced()).foregroundStyle(OriginalTheme.cream)
            Text("Last successful check: \(profile.checkedAt.formatted(date: .abbreviated, time: .shortened))")
                .font(.caption).foregroundStyle(OriginalTheme.cream)
            Text(profile.hasPreviousCheck
                 ? "\(profile.increases.count) level increase(s) since the previous check."
                 : "Starting levels saved. Your next refresh will show which levels increased.")
                .font(.subheadline).foregroundStyle(OriginalTheme.green)
                .accessibilityIdentifier("levelsChanges")
            Toggle("Refresh when I open the app", isOn: Binding(
                get: { model.document.settings.refreshLevelsOnOpen == true },
                set: { model.setRefreshLevelsOnOpen($0) }
            )).foregroundStyle(OriginalTheme.cream).tint(OriginalTheme.green)
                .accessibilityIdentifier("autoRefreshLevels")
            Text("Checks on opening after at least 5 minutes. Does not run continuously while the app is closed.")
                .font(.caption).foregroundStyle(OriginalTheme.cream)
        }
        .padding(16).background { WoodenPanel() }
    }

    private func levelsPanel(_ title: String, items: [PlayerLevel]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).villageText(21, color: OriginalTheme.gold)
            ForEach(items) { item in
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.name).font(.body.weight(.semibold)).foregroundStyle(.white)
                        if item.village == "builderBase" {
                            Text("Builder Base").font(.caption).foregroundStyle(OriginalTheme.cream)
                        }
                        if item.increased, let old = item.previousLevel {
                            Text("Upgraded: \(old) → \(item.level)")
                                .font(.caption.weight(.semibold)).foregroundStyle(OriginalTheme.green)
                        }
                    }
                    Spacer(minLength: 0)
                    Text("Lv \(item.level) / \(item.maxLevel)")
                        .font(.subheadline.monospacedDigit()).foregroundStyle(OriginalTheme.cream)
                }.accessibilityElement(children: .combine)
            }
        }.padding(16).background { WoodenPanel() }
    }

    private func requestRefresh() {
        guard !model.isRefreshingLevels else { return }
        editingTag = false
        requestID = UUID()
    }
}
