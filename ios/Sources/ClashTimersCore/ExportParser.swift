import Foundation
import CoreFoundation

public enum ExportParser {
    // Limits prevent an accidental paste from overflowing dates or creating unbounded simulation work.
    static let maximumDuration = 10 * 366 * 86400

    public static func parse(_ text: String) throws -> VillageExport {
        guard text.utf8.count <= 5_000_000,
              let data = text.trimmingCharacters(in: .whitespacesAndNewlines).data(using: .utf8),
              let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            throw ClashError.invalidExport("Paste the complete village JSON from Settings → Data Export in Clash of Clans.")
        }
        guard let tag = root["tag"] as? String, tag.hasPrefix("#"), tag.count > 1,
              let timestamp = integer(root["timestamp"]), (0...253_402_300_799).contains(timestamp),
              let buildings = root["buildings"] as? [Any] else {
            throw ClashError.invalidExport("The export needs a player tag, a numeric timestamp, and a buildings list.")
        }
        var jobs: [Job] = []
        var helperOnFinished: Set<JobCategory> = []

        func visit(_ item: [String: Any], _ category: JobCategory, _ source: JobSource,
                   parent: Int? = nil, type: Int? = nil) throws {
            let linked = flag(item["helper_recurrent"])
            guard let timerValue = item["timer"] else {
                if linked { helperOnFinished.insert(category) }
                return
            }
            guard let timer = integer(timerValue), abs(Double(timer)) <= Double(maximumDuration),
                  let id = integer(item["data"]), (0...Int(Int32.max)).contains(id),
                  let level = item["lvl"] == nil ? 0 : integer(item["lvl"]), (0...10000).contains(level) else {
                throw ClashError.invalidExport("An upgrade has an invalid ID, level, or timer. Copy a fresh export.")
            }
            let helperTimer = integer(item["helper_timer"]) ?? 0
            guard (0...maximumDuration).contains(helperTimer), jobs.count < 256 else {
                throw ClashError.invalidExport("This export contains an unsupported timer or too many upgrades.")
            }
            jobs.append(Job(category: category, source: source, dataID: id, currentLevel: level,
                            remainingAtT0: max(0, timer), helperLinked: linked,
                            parentDataID: parent, typeDataID: type, isGoblin: flag(item["extra"]),
                            helperTimer: helperTimer))
        }

        let buildingObjects = buildings.compactMap { $0 as? [String: Any] }
        for building in buildingObjects {
            try visit(building, .builder, .building)
            for type in objects(building["types"]) {
                for module in objects(type["modules"]) {
                    try visit(module, .builder, .module, parent: integer(building["data"]), type: integer(type["data"]))
                }
            }
        }
        let sections: [(String, JobCategory, JobSource)] = [
            ("traps", .builder, .trap), ("heroes", .builder, .hero), ("guardians", .builder, .guardian),
            ("units", .lab, .unit), ("spells", .lab, .spell), ("siege_machines", .lab, .siegeMachine),
            ("pets", .pet, .pet)
        ]
        for (key, category, source) in sections {
            for item in objects(root[key]) { try visit(item, category, source) }
        }

        var occurrences: [String: Int] = [:]
        for index in jobs.indices {
            let base = jobs[index].id
            jobs[index].occurrence = occurrences[base, default: 0]
            occurrences[base, default: 0] += 1
        }
        let helpers = try objects(root["helpers"]).compactMap { item -> Helper? in
            guard let id = integer(item["data"]) else { return nil }
            let level = integer(item["lvl"]) ?? 0
            let cooldown = integer(item["helper_cooldown"]) ?? 0
            guard (0...1000).contains(level), (0...maximumDuration).contains(cooldown) else {
                throw ClashError.invalidExport("A helper has an invalid level or cooldown.")
            }
            return Helper(dataID: id, level: level, cooldown: cooldown)
        }
        let boost = integer((root["boosts"] as? [String: Any])?["builder_boost"])
        if let boost, !(0...maximumDuration).contains(boost) {
            throw ClashError.invalidExport("The builder potion duration is invalid.")
        }
        let huts = buildingObjects.filter { integer($0["data"]) == 1000015 }
            .reduce(0) { $0 + min(20, max(0, integer($1["cnt"]) ?? 1)) }
        return VillageExport(
            tag: tag, timestamp: timestamp,
            townHallLevel: buildingObjects.first { integer($0["data"]) == 1000001 }.flatMap { integer($0["lvl"]) },
            builderHutCount: min(20, huts), hasBobsHut: buildingObjects.contains { integer($0["data"]) == 1000064 },
            helpers: helpers, jobs: jobs, helperOnFinishedItem: helperOnFinished,
            builderBoostRemaining: boost.flatMap { $0 > 0 ? $0 : nil }
        )
    }

    private static func objects(_ value: Any?) -> [[String: Any]] {
        (value as? [Any])?.compactMap { $0 as? [String: Any] } ?? []
    }
    private static func flag(_ value: Any?) -> Bool {
        guard let number = value as? NSNumber, CFGetTypeID(number) == CFBooleanGetTypeID() else { return false }
        return number.boolValue
    }
    private static func integer(_ value: Any?) -> Int? {
        guard let number = value as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID() else { return nil }
        return Int(number.stringValue)
    }
}
