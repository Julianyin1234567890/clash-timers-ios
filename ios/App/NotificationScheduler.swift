import Foundation
import UserNotifications
import ClashTimersCore

/// Drain updates serially so a suspended older request cannot overwrite a newer notification plan.
@MainActor
final class NotificationScheduler: NSObject, UNUserNotificationCenterDelegate {
    private let center = UNUserNotificationCenter.current()
    private var pendingStore: DocumentStore?
    private var isUpdating = false

    override init() {
        super.init()
        center.delegate = self
    }

    func requestPermission() async throws -> Bool {
        try await center.requestAuthorization(options: [.alert, .sound])
    }

    func replace(using store: DocumentStore, onError: @escaping (Error) -> Void) {
        pendingStore = store
        guard !isUpdating else { return }
        isUpdating = true
        Task {
            defer { isUpdating = false }
            var lastError: Error?
            while let next = pendingStore {
                pendingStore = nil
                do { try await reconcileLatest(next); lastError = nil }
                catch { lastError = error }
            }
            if let lastError { onError(lastError) }
        }
    }

    /// Re-read after asynchronous scheduling so another process cannot leave an older plan behind.
    func reconcileLatest(_ store: DocumentStore) async throws {
        var document = try store.load()
        while true {
            try await reconcile(document)
            let latest = try store.load()
            if latest == document { return }
            document = latest
        }
    }

    private func reconcile(_ document: StoredDocument) async throws {
        let settings = await center.notificationSettings()
        let permitted = settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
        let desired = permitted ? NotificationPlan.make(document: document, now: Int(Date().timeIntervalSince1970)) : []
        let pending = await center.pendingNotificationRequests()
        let wantedIDs = Set(desired.map(\.id))
        let obsolete = pending.map(\.identifier).filter { $0.hasPrefix("clash-timers.") && !wantedIDs.contains($0) }
        center.removePendingNotificationRequests(withIdentifiers: obsolete)

        for notice in desired {
            let content = UNMutableNotificationContent()
            content.title = notice.title
            content.body = notice.body
            content.sound = .default
            // A duration from the absolute finish date remains correct across timezone changes.
            let delay = max(1, Double(notice.fireAt) - Date().timeIntervalSince1970)
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
            try await center.add(UNNotificationRequest(identifier: notice.id, content: content, trigger: trigger))
        }
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            willPresent notification: UNNotification,
                                            withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .list])
    }
}
