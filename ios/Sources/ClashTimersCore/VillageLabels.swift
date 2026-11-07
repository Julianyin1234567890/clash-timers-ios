import Foundation

/// The Android widget's compact labels, including stacked boosts and helper status.
public enum VillageLabels {
    public static func boostText(_ type: BoostType, document: StoredDocument, now: Int) -> String {
        let windows = document.state.boosts.filter { $0.type == type }.sorted { $0.start < $1.start }
        guard let active = windows.first(where: { $0.start <= now && $0.end > now }) else {
            return type == .builderBite ? "Bite" : "+1"
        }
        var end = active.end
        for window in windows where window.start <= end && window.end > end { end = window.end }
        let minutes = max(1, (end - now + 59) / 60)
        if minutes < 60 { return "\(minutes)m" }
        return minutes % 60 == 0 ? "\(minutes / 60)h" : "\(minutes / 60)h \(minutes % 60)m"
    }

    public static func syncAge(timestamp: Int, now: Int) -> String {
        let seconds = max(0, now - timestamp)
        if seconds < 60 { return "synced just now" }
        if seconds < 3600 { return "synced \(seconds / 60)m ago" }
        if seconds < 172800 { return "synced \(seconds / 3600)h ago" }
        return "synced \(seconds / 86400)d ago"
    }

    public static func helperName(_ category: JobCategory, snapshot: DashboardSnapshot) -> String? {
        guard let row = snapshot.rows.first(where: { $0.job.category == category && $0.helperLinked && !$0.isDone }) else {
            return nil
        }
        return row.job.source == .hero ? row.title.components(separatedBy: " ").last : row.title
    }
}
