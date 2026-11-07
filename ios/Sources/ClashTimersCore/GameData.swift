import Foundation

public struct GameData: Sendable {
    public static let resourceBundle = Bundle.module

    public let names: [String: String]
    public let times: [String: [String: Int]]

    public static let bundled: GameData = {
        struct Names: Decodable { var names: [String: String] }
        struct Times: Decodable { var times: [String: [String: Int]] }
        let namesURL = Bundle.module.url(forResource: "names", withExtension: "json")!
        let timesURL = Bundle.module.url(forResource: "upgrade_times", withExtension: "json")!
        // These are versioned, tested resources shipped inside the local package, never a network fetch.
        let names = try! JSONDecoder().decode(Names.self, from: Data(contentsOf: namesURL)).names
        let times = try! JSONDecoder().decode(Times.self, from: Data(contentsOf: timesURL)).times
        return Self(names: names, times: times)
    }()

    public func name(_ id: Int) -> String { names[String(id)] ?? "Unknown (\(id))" }
    public func title(for job: Job) -> String {
        guard job.source == .module else { return name(job.dataID) }
        let parent = (job.typeDataID ?? job.parentDataID).map(name) ?? "Crafted defense"
        return "\(parent) \(name(job.dataID))"
    }
    public func label(for job: Job) -> String {
        title(for: job) + (job.isNewBuilding ? " (new)" : " → \(job.targetLevel)")
    }
    public func fullDuration(for job: Job) -> Int? {
        times[String(job.dataID)]?[String(job.targetLevel)].flatMap { $0 > 0 ? $0 : nil }
    }

    public static var legalNotices: String {
        ["LICENSE", "NOTICE", "LilitaOne-OFL.txt"].compactMap { name in
            Bundle.module.url(forResource: name, withExtension: nil).flatMap { try? String(contentsOf: $0) }
        }.joined(separator: "\n\n")
    }
}
