import Foundation
import Observation
import WidgetKit
import ClashTimersCore

struct AppAlert: Identifiable {
    let id = UUID()
    var title: String
    var message: String
}

@MainActor
@Observable
final class AppModel {
    private(set) var document = StoredDocument()
    private(set) var isReady = false
    private(set) var storageError: String?
    var alert: AppAlert?

    @ObservationIgnored private var store: DocumentStore?
    @ObservationIgnored private let notifications = NotificationScheduler()
    @ObservationIgnored private let isTesting = ProcessInfo.processInfo.arguments.contains("--uitesting")

    init() {
        do {
            let store = try SharedStore.make(isTesting: isTesting)
            self.store = store
            if isTesting && !ProcessInfo.processInfo.arguments.contains("--keep-state") { try store.save(StoredDocument()) }
            document = try store.load()
            isReady = true
        } catch {
            // Never overwrite a corrupt or newer document with an empty default state.
            storageError = error.localizedDescription
        }
    }

    @discardableResult
    func importVillage(_ text: String) -> Bool {
        do {
            return try commit { $0.state = try SyncLogic.apply(text, to: $0.state) }
        } catch {
            report(error, title: "Couldn’t import village")
            return false
        }
    }

    func toggleHelper(_ row: TimerRow) {
        change { TimerActions.toggleHelper(jobID: row.id, state: &$0.state) }
    }
    func addBoost(_ type: BoostType) {
        change { updated in
            TimerActions.addBoost(type, state: &updated.state, settings: updated.settings.boosts,
                                  now: Int(Date().timeIntervalSince1970))
        }
    }
    func undoBoost(_ type: BoostType) {
        change { TimerActions.undoBoost(type, state: &$0.state, now: Int(Date().timeIntervalSince1970)) }
    }
    @discardableResult
    func saveSettings(_ settings: AppSettings) -> Bool {
        do {
            return try commit {
                $0.settings = settings
                $0.settings.playerName = String(settings.playerName.trimmingCharacters(in: .whitespacesAndNewlines).prefix(24))
            }
        } catch { report(error, title: "Couldn’t save settings"); return false }
    }

    func requestNotifications() async -> Bool {
        do {
            let allowed = try await notifications.requestPermission()
            if !allowed {
                alert = AppAlert(title: "Notifications are off", message: "Allow notifications for Clash Timers in your iPhone’s Settings, then enable finish alerts here.")
            }
            return allowed
        } catch { report(error, title: "Couldn’t enable alerts"); return false }
    }

    func refresh() {
        guard isReady, let store else { return }
        do {
            document = try store.load()
            scheduleNotifications()
        } catch { report(error, title: "Couldn’t load saved timers") }
    }

    func clearVillage() {
        change { $0.state = AppState() }
    }

    private func change(_ edit: (inout StoredDocument) -> Void) {
        do { try commit(edit) } catch { report(error, title: "Couldn’t save changes") }
    }

    @discardableResult
    private func commit(_ edit: (inout StoredDocument) throws -> Void) throws -> Bool {
        guard isReady, let store else {
            throw SharedStoreError.unavailableGroup(SharedStore.groupIdentifier ?? "")
        }
        document = try store.update(edit)
        if SharedStore.hasWidgetSupport { WidgetCenter.shared.reloadAllTimelines() }
        scheduleNotifications()
        return true
    }

    private func scheduleNotifications() {
        guard !isTesting else { return }
        guard let store else { return }
        notifications.replace(using: store) { [weak self] error in
            self?.report(error, title: "Couldn’t schedule finish alerts")
        }
    }
    private func report(_ error: Error, title: String) {
        alert = AppAlert(title: title, message: error.localizedDescription)
    }
}
