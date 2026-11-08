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
                        Text("Your timers are already saved. For the quickest update, copy fresh village data in Clash and tap Sync on the widget or in this app.")
                            .font(.subheadline)
                    }
                }
                Section {
                    Label("Open Clash of Clans", systemImage: "1.circle.fill")
                    Label("Settings → More Settings → Data Export → Copy", systemImage: "2.circle.fill")
                    Label("Tap Paste to save your village", systemImage: "3.circle.fill")
                } header: { Text("Import your home village") }
                footer: {
                    Text("This imports a snapshot. Later game changes do not arrive automatically. Everything stays on your device.")
                }

                Section {
                    // Explicit system paste also works if programmatic paste access was denied.
                    PasteButton(payloadType: String.self) { values in
                        text = values.first ?? ""
                        if model.importVillage(text) { dismiss() }
                    }
                        .buttonBorderShape(.capsule)
                        .accessibilityIdentifier("pasteAndImport")
                    TextEditor(text: $text)
                        .font(.system(.footnote, design: .monospaced))
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .frame(minHeight: 190)
                        .accessibilityLabel("Village export JSON")
                        .accessibilityIdentifier("villageExportInput")
                } header: { Text("Village export") }
                footer: {
                    Text("Paste saves immediately. If you enter the text yourself, tap Import. Another player tag replaces the current village; invalid or older data won’t replace your saved timers.")
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
