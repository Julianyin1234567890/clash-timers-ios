import Foundation

public struct TimerRow: Identifiable, Sendable {
    public let job: Job
    public let title: String
    public let label: String
    public let finishAt: Int
    public let progress: Double
    public let isDone: Bool
    public let helperLinked: Bool
    public let helperAvailable: Bool
    public var id: String { job.id }
    public var finishDate: Date { Date(timeIntervalSince1970: Double(finishAt)) }
}

public struct DashboardSnapshot: Sendable {
    public let village: VillageExport?
    public let playerName: String
    public let rows: [TimerRow]
    public let totalBuilders: Int
    public let freeBuilders: Int

    public init(document: StoredDocument, at now: Int, gameData: GameData = .bundled) {
        playerName = document.settings.displayName
        village = document.state.village
        guard let village else {
            rows = []; totalBuilders = 0; freeBuilders = 0
            return
        }
        let engine = TimerEngine(settings: document.settings.boosts)
        rows = village.jobs.map { job in
            let finish = engine.finishTime(for: job, village: village, state: document.state)
            let remaining = engine.remaining(for: job, village: village, state: document.state, at: now)
            let full = max(1, max(gameData.fullDuration(for: job) ?? 0,
                                  document.state.firstRemaining[job.id] ?? job.remainingAtT0))
            return TimerRow(job: job, title: gameData.title(for: job), label: gameData.label(for: job),
                            finishAt: finish, progress: min(1, max(0, 1 - Double(remaining) / Double(full))),
                            isDone: finish <= now, helperLinked: document.state.links[job.category] == job.id,
                            helperAvailable: village.helpers.contains { $0.dataID == job.category.helperID && $0.level > 0 })
        }.sorted {
            if $0.isDone != $1.isDone { return !$0.isDone }
            if $0.finishAt != $1.finishAt { return $0.finishAt < $1.finishAt }
            return $0.id < $1.id
        }
        totalBuilders = document.settings.totalBuilders(for: village)
        freeBuilders = max(0, totalBuilders - rows.filter { $0.job.category == .builder && !$0.job.isGoblin && !$0.isDone }.count)
    }

    public var nextFinish: TimerRow? { rows.first { !$0.isDone } }
    public func rows(for category: JobCategory) -> [TimerRow] { rows.filter { $0.job.category == category } }
}

public enum Countdown {
    public static func text(seconds: Int) -> String {
        let s = max(0, seconds)
        let time = String(format: "%02d:%02d:%02d", (s % 86400) / 3600, (s % 3600) / 60, s % 60)
        return s >= 86400 ? "\(s / 86400)d \(time)" : time
    }
}

/// WidgetKit can show the precomputed finished state without launching our process at every finish.
public enum WidgetSchedule {
    public static func dates(for document: StoredDocument, now: Int) -> [Int] {
        let snapshot = DashboardSnapshot(document: document, at: now)
        let finishes = snapshot.rows.map(\.finishAt).filter { $0 > now }
        return [now] + Array(Set(finishes)).sorted().prefix(60)
    }
}

public struct FinishNotice: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let body: String
    public let fireAt: Int
}

public enum NotificationPlan {
    public static func make(document: StoredDocument, now: Int) -> [FinishNotice] {
        guard document.settings.notificationsEnabled else { return [] }
        let snapshot = DashboardSnapshot(document: document, at: now)
        // Keep comfortably below the OS's pending-notification budget; closest completions win.
        return snapshot.rows.filter { !$0.isDone }.prefix(60).map { row in
            let title: String
            switch row.job.category {
            case .builder: title = row.job.isGoblin ? "Goblin Builder finished" : "Builder free"
            case .lab: title = "Laboratory free"
            case .pet: title = "Pet House free"
            }
            let body = row.job.isNewBuilding ? "\(row.title) is built." : "\(row.title) reached level \(row.job.targetLevel)."
            return FinishNotice(id: "clash-timers.\(row.id)", title: title, body: body, fireAt: row.finishAt)
        }
    }
}
