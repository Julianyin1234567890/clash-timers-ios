import SwiftUI

struct ImportVillageView: View {
    let model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""

    var body: some View {
        NavigationStack {
            Form {
                if let village = model.document.state.village {
                    Section {
                        Label("Saved village: \(village.tag)", systemImage: "checkmark.circle.fill")
                        Text("Your timers are already saved. Import again after changing upgrades in the game; reopening this app does not need a new export.")
                            .font(.subheadline)
                    }
                }
                Section {
                    Label("Open Clash of Clans", systemImage: "1.circle.fill")
                    Label("Settings → More Settings → Data Export → Copy", systemImage: "2.circle.fill")
                    Label("Paste your export below", systemImage: "3.circle.fill")
                } header: { Text("Import your home village") }
                footer: {
                    Text("This imports a snapshot. Later game changes do not arrive automatically. Everything stays on your device.")
                }

                Section {
                    // PasteButton grants explicit paste access. No clipboard polling or launch-time reads.
                    PasteButton(payloadType: String.self) { values in text = values.first ?? "" }
                        .buttonBorderShape(.capsule)
                    TextEditor(text: $text)
                        .font(.system(.footnote, design: .monospaced))
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .frame(minHeight: 190)
                        .accessibilityLabel("Village export JSON")
                        .accessibilityIdentifier("villageExportInput")
                } header: { Text("Village export") }
                footer: {
                    Text("Importing another player tag replaces the current village. Invalid or older data won’t replace your saved timers.")
                }

                Section {
                    Button {
                        if model.importVillage(text) { dismiss() }
                    } label: {
                        Label("Import village", systemImage: "arrow.down.doc.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !model.isReady)
                    .accessibilityIdentifier("confirmImportBody")
                    .listRowBackground(Color.clear)
                }
            }
            .navigationTitle("Import village")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Import") { if model.importVillage(text) { dismiss() } }
                        .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !model.isReady)
                        .accessibilityIdentifier("confirmImport")
                }
            }
            .alert(model.alert?.title ?? "", isPresented: Binding(get: { model.alert != nil }, set: { if !$0 { model.alert = nil } })) {
                Button("OK") { model.alert = nil }
            } message: { Text(model.alert?.message ?? "") }
        }
    }
}
