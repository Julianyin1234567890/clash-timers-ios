import Foundation

public enum SpeedWindow: Equatable, Sendable {
    case fixed(start: Int, end: Int, extraRate: Double)
    case periodic(firstStart: Int, duration: Int, period: Int, extraRate: Double)

    func rate(at time: Int) -> Double {
        switch self {
        case let .fixed(start, end, rate): return time >= start && time < end ? rate : 0
        case let .periodic(start, duration, period, rate):
            guard time >= start, period > 0 else { return 0 }
            return (time - start) % period < duration ? rate : 0
        }
    }
    func nextEdge(after time: Int) -> Int? {
        switch self {
        case let .fixed(start, end, _): return time < start ? start : (time < end ? end : nil)
        case let .periodic(start, duration, period, _):
            if time < start { return start }
            guard period > 0, duration > 0 else { return nil }
            let window = start + ((time - start) / period) * period
            return time < window + duration ? window + duration : window + period
        }
    }
}

public struct TimerEngine: Sendable {
    public let settings: BoostSettings
    public init(settings: BoostSettings = BoostSettings()) {
        self.settings = settings.isValid ? settings : BoostSettings()
    }

    public func windows(for job: Job, village: VillageExport, links: HelperLinks, boosts: [BoostUse]) -> [SpeedWindow] {
        var windows: [SpeedWindow] = boosts.filter {
            $0.type.category == job.category && (!job.isGoblin || settings.boostsApplyToGoblin)
        }.map {
            .fixed(start: $0.start, end: $0.end,
                   extraRate: Double(settings.saving(for: $0.type)) / Double(settings.boostDuration))
        }
        if job.id == links[job.category], let helperID = job.category.helperID,
           let helper = village.helpers.first(where: { $0.dataID == helperID }) {
            let override = job.category == .builder ? settings.apprenticeSavingOverride : settings.labAssistantSavingOverride
            let saving = override ?? helper.level * 3600
            if saving > 0 {
                let rate = Double(saving) / Double(settings.helperWindow)
                if job.helperTimer > 0 {
                    windows.append(.fixed(start: village.timestamp, end: village.timestamp + job.helperTimer, extraRate: rate))
                }
                windows.append(.periodic(firstStart: village.timestamp + helper.cooldown,
                                         duration: settings.helperWindow, period: settings.helperPeriod, extraRate: rate))
            }
        }
        return windows
    }

    public func finishTime(for job: Job, village: VillageExport, state: AppState) -> Int {
        Self.finishTime(t0: village.timestamp, remaining: job.remainingAtT0,
                        windows: windows(for: job, village: village, links: state.links, boosts: state.boosts))
    }
    public func remaining(for job: Job, village: VillageExport, state: AppState, at time: Int) -> Int {
        Self.remaining(t0: village.timestamp, remaining: job.remainingAtT0,
                       windows: windows(for: job, village: village, links: state.links, boosts: state.boosts), at: time)
    }

    public static func finishTime(t0: Int, remaining: Int, windows: [SpeedWindow]) -> Int {
        Int(ceil(simulate(t0: t0, remaining: remaining, windows: windows, until: nil).time - 0.000001))
    }
    public static func remaining(t0: Int, remaining: Int, windows: [SpeedWindow], at time: Int) -> Int {
        Int(max(0, simulate(t0: t0, remaining: remaining, windows: windows, until: max(time, t0)).remaining.rounded()))
    }

    // Advance only between speed changes. Timers keep their correct finish date while iOS suspends the app.
    private static func simulate(t0: Int, remaining: Int, windows: [SpeedWindow], until: Int?) -> (time: Double, remaining: Double) {
        var time = t0
        var work = Double(max(0, remaining))
        for _ in 0..<100_000 {
            if work <= 0.000001 { return (Double(time), 0) }
            if let until, time >= until { return (Double(time), work) }
            let rate = 1 + windows.reduce(0) { $0 + max(0, $1.rate(at: time)) }
            let edge = (windows.compactMap { $0.nextEdge(after: time) } + [until].compactMap { $0 })
                .filter { $0 > time }.min()
            let finish = Double(time) + work / rate
            guard let edge, finish > Double(edge) else { return (finish, 0) }
            work -= Double(edge - time) * rate
            time = edge
        }
        // A malformed schedule must never stall a widget provider.
        if let until { return (Double(until), max(0, work - Double(until - time))) }
        return (Double(time) + work, 0)
    }
}

public enum BoostStacking {
    public static func adding(_ type: BoostType, to boosts: [BoostUse], at time: Int, duration: Int) -> [BoostUse] {
        let start = max(time, boosts.filter { $0.type == type }.map(\.end).max() ?? time)
        return boosts + [BoostUse(type: type, start: start, end: start + duration)]
    }
    public static func undoing(_ type: BoostType, in boosts: [BoostUse], at time: Int) -> [BoostUse] {
        guard let index = boosts.indices.filter({ boosts[$0].type == type && boosts[$0].end > time })
            .max(by: { boosts[$0].start < boosts[$1].start }) else { return boosts }
        var result = boosts
        if result[index].start >= time { result.remove(at: index) }
        else { result[index].end = time } // Keep the acceleration that already happened.
        return result
    }
}
