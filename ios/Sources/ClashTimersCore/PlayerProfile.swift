import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public enum ProfileCategory: String, Codable, CaseIterable, Sendable {
    case heroes, troops, spells, equipment
    public var title: String {
        switch self {
        case .heroes: return "Heroes"
        case .troops: return "Troops, siege machines & pets"
        case .spells: return "Spells"
        case .equipment: return "Owned hero equipment"
        }
    }
}

public struct PlayerLevel: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var name: String
    public var category: ProfileCategory
    public var village: String
    public var level: Int
    public var maxLevel: Int
    public var previousLevel: Int?
    public var increased: Bool { previousLevel.map { level > $0 } ?? false }
}

/// An online profile is deliberately separate from the exported timer snapshot.
public struct PlayerProfile: Codable, Equatable, Sendable {
    public var tag: String
    public var name: String
    public var townHallLevel: Int
    public var checkedAt: Date
    public var levels: [PlayerLevel]
    public var hasPreviousCheck: Bool

    public var increases: [PlayerLevel] { levels.filter(\.increased) }

    public func comparing(to previous: PlayerProfile?) -> Self {
        var result = self
        guard let previous, previous.tag == tag else { return result }
        result.hasPreviousCheck = true
        let old = Dictionary(previous.levels.map { ($0.id, $0.level) }, uniquingKeysWith: { first, _ in first })
        for index in result.levels.indices {
            // Missing items are not assumed to have been level zero: the provider
            // may have added support for them between requests.
            result.levels[index].previousLevel = old[result.levels[index].id]
        }
        return result
    }
}

public enum PlayerProfileError: LocalizedError, Equatable {
    case invalidTag, wrongPlayer, invalidResponse, unavailable(Int)
    public var errorDescription: String? {
        switch self {
        case .invalidTag: return "Enter the player tag from your Clash profile, such as #P0Y8LQ. Use the tag, not your Supercell ID."
        case .wrongPlayer: return "The service returned a different player. Your saved levels have not changed."
        case .invalidResponse: return "The level service returned data this app could not read. Your saved levels have not changed."
        case .unavailable(404): return "That player could not be found. Check the tag and try again."
        case .unavailable(429): return "The level service is busy. Wait a few minutes before refreshing again."
        case .unavailable: return "The level service is unavailable. Try again later; your saved levels are still available."
        }
    }
}

public enum PlayerProfileDecoder {
    public static func normalizedTag(_ text: String) throws -> String {
        var tag = text.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if tag.hasPrefix("#") { tag.removeFirst() }
        let alphabet = Set("0289PYLQGRJCUV")
        guard (3...15).contains(tag.count), tag.allSatisfy({ alphabet.contains($0) }) else {
            throw PlayerProfileError.invalidTag
        }
        return "#" + tag
    }

    private struct Response: Decodable {
        var tag: String
        var name: String
        var townHallLevel: Int
        var heroes: [Item]
        var troops: [Item]
        var spells: [Item]
        var heroEquipment: [Item]
    }
    private struct Item: Decodable {
        var id: Int
        var level: Int
        var maxLevel: Int
        var village: String?
        var order: Int?
        var apiName: String?
        var isUnlocked: Bool?
    }
    // Provider IDs are NOT Supercell export data IDs. Keep a separate, verified
    // name table; unknown IDs remain explicitly unnamed instead of mislabelled.
    private static let names: [String: [String: String]] = {
        guard let url = Bundle.module.url(forResource: "profile_names", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let names = try? JSONDecoder().decode([String: [String: String]].self, from: data) else { return [:] }
        return names
    }()

    public static func decode(_ data: Data, expectedTag: String, checkedAt: Date = Date()) throws -> PlayerProfile {
        let expected = try normalizedTag(expectedTag)
        guard data.count <= 1_000_000,
              let response = try? JSONDecoder().decode(Response.self, from: data),
              let tag = try? normalizedTag(response.tag),
              !response.name.isEmpty, (1...100).contains(response.townHallLevel) else {
            throw PlayerProfileError.invalidResponse
        }
        guard tag == expected else { throw PlayerProfileError.wrongPlayer }
        let groups: [(ProfileCategory, [Item])] = [(.heroes, response.heroes), (.troops, response.troops),
                                                   (.spells, response.spells), (.equipment, response.heroEquipment)]
        var levels: [PlayerLevel] = []
        var seen = Set<String>()
        for (category, items) in groups {
            guard items.count <= 500 else { throw PlayerProfileError.invalidResponse }
            for item in items.sorted(by: { ($0.order ?? $0.id, $0.id) < ($1.order ?? $1.id, $1.id) }) {
                guard item.id >= 0, (0...1000).contains(item.level), (1...1000).contains(item.maxLevel),
                      item.level <= item.maxLevel else { throw PlayerProfileError.invalidResponse }
                guard item.level > 0 else { continue }
                if category == .equipment && item.isUnlocked != true { continue }
                let village = item.village == "builder" ? "builderBase" : (item.village ?? "home")
                guard village == "home" || village == "builderBase" else { throw PlayerProfileError.invalidResponse }
                let id = "\(category.rawValue):\(village):\(item.id)"
                guard seen.insert(id).inserted else { throw PlayerProfileError.invalidResponse }
                let name = item.apiName.flatMap { $0.isEmpty ? nil : $0 }
                    ?? names[category.rawValue]?[String(item.id)]
                    ?? "Unknown \(category.rawValue) #\(item.id)"
                levels.append(PlayerLevel(id: id, name: String(name.prefix(100)), category: category,
                                          village: village, level: item.level, maxLevel: item.maxLevel))
            }
        }
        guard !levels.isEmpty else { throw PlayerProfileError.invalidResponse }
        return PlayerProfile(tag: tag, name: String(response.name.prefix(100)), townHallLevel: response.townHallLevel,
                             checkedAt: checkedAt, levels: levels, hasPreviousCheck: false)
    }
}

public struct PlayerProfileClient: Sendable {
    private let session: URLSession
    public init(session: URLSession? = nil) {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 30
        self.session = session ?? URLSession(configuration: configuration)
    }

    public func fetch(tag rawTag: String) async throws -> PlayerProfile {
        let tag = try PlayerProfileDecoder.normalizedTag(rawTag)
        let url = URL(string: "https://api.clashofstats.com/players/\(tag.dropFirst())")!
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 20)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("ClashTimers-iOS/1.0.5 (+https://github.com/Julianyin1234567890/clash-timers-ios)", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await session.data(for: request)
        try Task.checkCancellation()
        guard let http = response as? HTTPURLResponse else { throw PlayerProfileError.invalidResponse }
        guard http.statusCode == 200 else { throw PlayerProfileError.unavailable(http.statusCode) }
        return try PlayerProfileDecoder.decode(data, expectedTag: tag)
    }
}
