import Foundation

public enum SyncLogic {
    /// Return a new state only after validation; a failed paste never destroys saved timers.
    public static func apply(_ text: String, to old: AppState, now: Int = Int(Date().timeIntervalSince1970)) throws -> AppState {
        let village = try ExportParser.parse(text)
        guard village.timestamp <= now + 300 else { throw ClashError.futureExport }
        let previous = old.village
        let sameVillage = previous?.tag == village.tag
        if sameVillage, let previous, village.timestamp < previous.timestamp { throw ClashError.olderExport }

        var state = AppState()
        state.exportJSON = text.trimmingCharacters(in: .whitespacesAndNewlines)
        state.links = HelperLinks.from(village)
        for category in [JobCategory.builder, .lab] {
            if sameVillage, state.links[category] == nil, !village.helperOnFinishedItem.contains(category),
               let key = old.links[category] {
                let candidates = village.jobs.filter { $0.category == category }
                if candidates.contains(where: { $0.id == key }) { state.links[category] = key }
                else if let oldJob = previous?.jobs.first(where: { $0.id == key }) {
                    state.links[category] = candidates.first {
                        $0.dataID == oldJob.dataID && $0.targetLevel == oldJob.targetLevel
                    }?.id
                }
            }
        }
        state.boosts = sameVillage ? old.boosts.filter { $0.end > village.timestamp } : []
        if let duration = village.builderBoostRemaining {
            state.boosts.removeAll { $0.type == .builderPotion }
            state.boosts.append(BoostUse(type: .builderPotion, start: village.timestamp, end: village.timestamp + duration))
        }
        state.firstRemaining = Dictionary(uniqueKeysWithValues: village.jobs.map {
            ($0.id, max(sameVillage ? old.firstRemaining[$0.id, default: 0] : 0, $0.remainingAtT0))
        })
        return state
    }
}

public enum TimerActions {
    public static func toggleHelper(jobID: String, state: inout AppState) {
        guard let village = state.village,
              let job = village.jobs.first(where: { $0.id == jobID }),
              let helperID = job.category.helperID,
              village.helpers.contains(where: { $0.dataID == helperID && $0.level > 0 }) else { return }
        state.links[job.category] = state.links[job.category] == jobID ? nil : jobID
    }
    public static func addBoost(_ type: BoostType, state: inout AppState, settings: BoostSettings, now: Int) {
        guard let village = state.village, settings.isValid else { return }
        let kept = state.boosts.filter { $0.end > village.timestamp }
        state.boosts = BoostStacking.adding(type, to: kept, at: max(now, village.timestamp), duration: settings.boostDuration)
    }
    public static func undoBoost(_ type: BoostType, state: inout AppState, now: Int) {
        state.boosts = BoostStacking.undoing(type, in: state.boosts, at: now)
    }
}
