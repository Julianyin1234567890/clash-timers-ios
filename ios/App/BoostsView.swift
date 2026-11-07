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
                        .foregroundStyle(OriginalTheme.cream)
                }
                ForEach(BoostType.allCases) { type in
                    Section {
                        HStack(spacing: 8) {
                            VillageArtwork(names: [artwork(type)]).frame(width: 28, height: 28)
                            Text(type.title).villageText(18, color: OriginalTheme.gold)
                        }
                        let end = model.document.state.boosts.filter { $0.type == type && $0.end > now }.map(\.end).max()
                        if let end {
                            Text("Active / queued: \(Countdown.text(seconds: end - now))")
                                .font(.subheadline).monospacedDigit()
                        } else {
                            Text("No boost recorded").foregroundStyle(OriginalTheme.cream)
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
                }.listRowBackground(OriginalTheme.color(0x5A3F2B))
            }
            .scrollContentBackground(.hidden)
            .background(OriginalTheme.color(0x261C14))
            .foregroundStyle(OriginalTheme.cream)
            .tint(OriginalTheme.gold)
        }
        .navigationTitle("Potions & snacks")
    }

    private func artwork(_ type: BoostType) -> String {
        switch type {
        case .builderPotion: "builder_potion"
        case .builderBite: "builder_bite"
        case .researchPotion: "research_potion"
        case .petPotion: "pet_potion"
        }
    }
}
