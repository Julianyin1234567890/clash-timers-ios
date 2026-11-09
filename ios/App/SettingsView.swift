import SwiftUI
import ClashTimersCore

struct SettingsView: View {
    let model: AppModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var settings: AppSettings
    @State private var confirmingClear = false
    @State private var requestingPermission = false

    init(model: AppModel) {
        self.model = model
        _settings = State(initialValue: model.document.settings)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Your village") {
                    TextField("Chief", text: $settings.playerName)
                        .textContentType(.nickname).autocorrectionDisabled()
                        .accessibilityLabel("Player name")
                    Picker("Builders", selection: Binding(
                        get: { settings.totalBuildersOverride ?? 0 },
                        set: { settings.totalBuildersOverride = $0 == 0 ? nil : $0 }
                    )) {
                        Text("From village export").tag(0)
                        ForEach(1...10, id: \.self) { Text("\($0)").tag($0) }
                    }
                }

                Section {
                    Toggle("Finish alerts", isOn: Binding(
                        get: { settings.notificationsEnabled },
                        set: { enabled in
                            if !enabled { settings.notificationsEnabled = false; return }
                            requestingPermission = true
                            Task {
                                settings.notificationsEnabled = await model.requestNotifications()
                                requestingPermission = false
                            }
                        }
                    )).disabled(requestingPermission)
                    Button("Open iPhone notification settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                    }
                } header: { Text("Notifications") }
                footer: { Text("Alerts use your predicted finish times and work while the app is closed. Focus modes and notification settings can affect delivery.") }

                Section {
                    NavigationLink("Potion & helper settings") { tuning }
                    Button("Restore default timer settings") { settings.boosts = BoostSettings() }
                } header: { Text("Predictions") }
                footer: { Text("Helpers use their exported level by default. Future sessions assume you return to the game to activate them.") }

                if SharedStore.hasWidgetSupport {
                    Section("Home Screen widget") {
                        Text("Touch and hold your Home Screen, choose Edit → Add Widget, then search for Clash Timers. Choose a small, medium, or large widget.")
                        Text("Copy village data in Clash, then tap Sync on the widget. On the small widget, tap anywhere to Sync. The app opens and saves the copied village immediately. Choose Allow Paste if iOS asks. Ordinary app launches do not read your clipboard.")
                            .foregroundStyle(.secondary)
                    }
                }

                Section("About") {
                    LabeledContent("Version", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—")
                    Text("Timer snapshots work offline and stay on this device; iOS may include them in your personal backup. Optional online level refresh sends your public player tag to Clash of Stats. No Supercell login, analytics, ads, or background clipboard access.")
                    Link("Online level provider: Clash of Stats", destination: URL(string: "https://www.clashofstats.com")!)
                    Text("Unofficial fan project. Not endorsed by Supercell. Clash of Clans names and game data belong to Supercell.")
                        .font(.footnote).foregroundStyle(.secondary)
                    Link("Original project & source", destination: URL(string: "https://github.com/Kuswaa/clash-timers")!)
                    Link("Supercell Fan Content Policy", destination: URL(string: "https://supercell.com/en/fan-content-policy/")!)
                    NavigationLink("Open source notices") { LegalView() }
                }
                Section {
                    Button("Clear saved village", role: .destructive) { confirmingClear = true }
                        .disabled(model.document.state.exportJSON == nil)
                } footer: { Text("Clears timers and scheduled alerts. Your display preferences stay saved.") }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { if model.saveSettings(settings) { dismiss() } }
                        .disabled(requestingPermission)
                }
            }
            .confirmationDialog("Clear this village and its finish alerts?", isPresented: $confirmingClear, titleVisibility: .visible) {
                Button("Clear village", role: .destructive) { model.clearVillage(); dismiss() }
            }
            .alert(model.alert?.title ?? "", isPresented: Binding(get: { model.alert != nil }, set: { if !$0 { model.alert = nil } })) {
                Button("OK") { model.alert = nil }
            } message: { Text(model.alert?.message ?? "") }
        }
    }

    private var tuning: some View {
        Form {
            Section("Boost duration") {
                minuteStepper("Minutes per potion / snack", value: $settings.boosts.boostDuration, range: 1...240)
            }
            Section("Hours saved per boost") {
                hourStepper("Builder Potion", value: $settings.boosts.builderPotionSaving)
                hourStepper("Builder Bite", value: $settings.boosts.builderBiteSaving)
                hourStepper("Research Potion", value: $settings.boosts.researchPotionSaving)
                hourStepper("Pet Potion", value: $settings.boosts.petPotionSaving)
            }
            Section("Helper schedule") {
                minuteStepper("Session minutes", value: $settings.boosts.helperWindow, range: 1...240)
                Stepper("Hours between starts: \(settings.boosts.helperPeriod / 3600)", value: Binding(
                    get: { settings.boosts.helperPeriod / 3600 }, set: { settings.boosts.helperPeriod = $0 * 3600 }
                ), in: 1...168)
                helperPicker("Apprentice hours saved", value: $settings.boosts.apprenticeSavingOverride)
                helperPicker("Lab Assistant hours saved", value: $settings.boosts.labAssistantSavingOverride)
            }
            Section {
                Toggle("Builder boosts affect Goblin", isOn: $settings.boosts.boostsApplyToGoblin)
            } footer: { Text("A level 8 Apprentice saves 8 extra hours during a one-hour session. Boost savings add together when their windows overlap.") }
        }.navigationTitle("Timer settings")
    }
    private func minuteStepper(_ title: String, value: Binding<Int>, range: ClosedRange<Int>) -> some View {
        Stepper("\(title): \(value.wrappedValue / 60)", value: Binding(get: { value.wrappedValue / 60 }, set: { value.wrappedValue = $0 * 60 }), in: range)
    }
    private func hourStepper(_ title: String, value: Binding<Int>) -> some View {
        Stepper("\(title): \(value.wrappedValue / 3600) h", value: Binding(get: { value.wrappedValue / 3600 }, set: { value.wrappedValue = $0 * 3600 }), in: 0...168)
    }
    private func helperPicker(_ title: String, value: Binding<Int?>) -> some View {
        Picker(title, selection: Binding(get: { value.wrappedValue.map { $0 / 3600 } ?? -1 }, set: { value.wrappedValue = $0 < 0 ? nil : $0 * 3600 })) {
            Text("From helper level").tag(-1)
            ForEach(0...24, id: \.self) { Text("\($0) h").tag($0) }
        }
    }
}

private struct LegalView: View {
    var body: some View {
        ScrollView {
            Text(GameData.legalNotices).font(.footnote).textSelection(.enabled).padding()
        }.navigationTitle("Notices")
    }
}
