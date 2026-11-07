import AppIntents
import SwiftUI
import WidgetKit
import ClashTimersCore

enum VillageAction {
    case sync, add(BoostType), undo(BoostType), helper(String)
}

struct VillageWidgetIntent: AppIntent {
    static var title: LocalizedStringResource = "Update Clash timer"
    static var isDiscoverable: Bool = false
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Action") var operation: String
    @Parameter(title: "Upgrade or boost") var argument: String

    init() {}
    init(_ action: VillageAction) {
        switch action {
        case .add(let type): operation = "add"; argument = type.rawValue
        case .undo(let type): operation = "undo"; argument = type.rawValue
        case .helper(let id): operation = "helper"; argument = id
        case .sync: operation = "sync"; argument = ""
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        let store = try SharedStore.make()
        try store.update { document in
            let now = Int(Date().timeIntervalSince1970)
            switch operation {
            case "add":
                if let type = BoostType(rawValue: argument) {
                    TimerActions.addBoost(type, state: &document.state, settings: document.settings.boosts, now: now)
                }
            case "undo":
                if let type = BoostType(rawValue: argument) {
                    TimerActions.undoBoost(type, state: &document.state, now: now)
                }
            case "helper":
                TimerActions.toggleHelper(jobID: argument, state: &document.state)
            default: break
            }
        }
        WidgetCenter.shared.reloadAllTimelines()
        NotificationCenter.default.post(name: .villageDidChange, object: nil)
        try await NotificationScheduler().reconcileLatest(store)
        return .result()
    }
}

extension Notification.Name {
    static let villageDidChange = Notification.Name("ClashTimersVillageDidChange")
}

struct VillageActionButton<Content: View>: View {
    let action: VillageAction
    var handler: ((VillageAction) -> Void)?
    @ViewBuilder let content: () -> Content

    var body: some View {
        Group {
            if let handler {
                Button { handler(action) } label: { content() }
            } else if case .sync = action {
                Link(destination: URL(string: "clashtimers://sync")!, label: content)
            } else {
                Button(intent: VillageWidgetIntent(action), label: content)
            }
        }.buttonStyle(OriginalButtonStyle())
    }
}
