import SwiftUI
import ClashTimersCore

struct BoostsView: View {
    let model: AppModel
    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let now = Int(context.date.timeIntervalSince1970)
            List {
                Section {
                    Text("Use the potion or snack in Clash of Clans first, then record it here. These buttons only adjust your timer predictions.")
                        .foregroundStyle(.secondary)
                }
                ForEach(BoostType.allCases) { type in
                    Section {
                        Label(type.title, systemImage: type.symbol)
                            .font(.headline).foregroundStyle(type.category.color)
                        let end = model.document.state.boosts.filter { $0.type == type && $0.end > now }.map(\.end).max()
                        if let end {
                            Text("Active / queued: \(Countdown.text(seconds: end - now))")
                                .font(.subheadline).monospacedDigit()
                        } else {
                            Text("No boost recorded").foregroundStyle(.secondary)
                        }
                        HStack {
                            Button { model.addBoost(type) } label: {
                                Label("Record boost", systemImage: "plus.circle.fill")
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(model.document.state.exportJSON == nil)
                            .accessibilityIdentifier("record-\(type.rawValue)")
                            Spacer()
                            Button("Undo", role: .destructive) { model.undoBoost(type) }
                                .buttonStyle(.bordered)
                                .disabled(end == nil)
                                .accessibilityIdentifier("undo-\(type.rawValue)")
                        }
                    } footer: {
                        Text("\(model.document.settings.boosts.boostDuration / 60) minutes per use · \(1 + model.document.settings.boosts.saving(for: type) / model.document.settings.boosts.boostDuration)× speed. Repeated uses queue end to end.")
                    }
                }
            }
        }
        .navigationTitle("Potions & snacks")
    }
}
