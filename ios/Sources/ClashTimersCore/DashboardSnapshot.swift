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
            let duration = gameData.fullDuration(for: job)
            let full = max(1, duration.flatMap { $0 >= job.remainingAtT0 ? $0 : nil }
                ?? max(document.state.firstRemaining[job.id] ?? 0, job.remainingAtT0))
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
    public func rows(for category: JobCategory) -> [TimerRow] {
        rows.filter { $0.job.category == category && !($0.job.isGoblin && $0.isDone) }
            .sorted { $0.finishAt == $1.finishAt ? $0.id < $1.id : $0.finishAt < $1.finishAt }
    }
}

public enum Countdown {
    public static func text(seconds: Int) -> String {
        let s = max(0, seconds)
        let hours = (s % 86400) / 3600
        let minutes = (s % 3600) / 60
        let seconds = s % 60
        if s >= 86400 {
            return String(format: "%dd %02d:%02d:%02d", s / 86400, hours, minutes, seconds)
        }
        return String(format: "%d:%02d:%02d", hours, minutes, seconds)
    }

    /// Supply the day/hour/minute padding around SwiftUI's live system timer.
    public static func timerPrefix(seconds: Int) -> String {
        let seconds = max(0, seconds)
        let days = seconds / 86400
        let inDay = seconds % 86400
        var prefix = days > 0 ? "\(days)d " : ""
        if inDay < 3600 {
            prefix += days > 0 ? "00:" : "0:"
            if inDay < 600 { prefix += "0" }
        } else if days > 0 && inDay < 36000 {
            prefix += "0"
        }
        return prefix
    }
}

/// WidgetKit can show the precomputed finished state without launching our process at every finish.
public enum WidgetSchedule {
    public static func dates(for document: StoredDocument, now: Int) -> [Int] {
        let snapshot = DashboardSnapshot(document: document, at: now)
        let finishes = snapshot.rows.map(\.finishAt).filter { $0 > now }
        var edges = Set(finishes)
        // Refresh the progress fills, boost labels and sync age once per minute.
        edges.formUnion(stride(from: now + 60, through: now + 3600, by: 60))
        for boost in document.state.boosts where boost.end > now {
            edges.insert(boost.start)
            edges.insert(boost.end)
        }
        // A live countdown displays a day prefix plus the remaining hours.
        for finish in finishes {
            let days = (finish - now) / 86400
            for boundary in [0, 600, 3600, 36000] {
                edges.insert(finish - days * 86400 - boundary + 1)
            }
        }
        return [now] + edges.filter { $0 > now }.sorted().prefix(120)
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
