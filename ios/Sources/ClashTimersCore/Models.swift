import Foundation

public enum JobCategory: String, Codable, CaseIterable, Sendable {
    case builder = "BUILDER", lab = "LAB", pet = "PET"

    public var title: String {
        switch self {
        case .builder: return "Builders"
        case .lab: return "Laboratory"
        case .pet: return "Pet House"
        }
    }

    public var symbol: String {
        switch self {
        case .builder: return "hammer.fill"
        case .lab: return "flask.fill"
        case .pet: return "pawprint.fill"
        }
    }

    public var helperID: Int? {
        switch self {
        case .builder: return 93000000
        case .lab: return 93000001
        case .pet: return nil
        }
    }
}

public enum JobSource: String, Codable, Sendable {
    case building, module, trap, hero, guardian, unit, spell, siegeMachine, pet
}

public struct Job: Codable, Equatable, Identifiable, Sendable {
    public var category: JobCategory
    public var source: JobSource
    public var dataID: Int
    public var currentLevel: Int
    public var remainingAtT0: Int
    public var helperLinked: Bool
    public var parentDataID: Int?
    public var typeDataID: Int?
    public var occurrence = 0
    public var isGoblin = false
    public var helperTimer = 0

    public var targetLevel: Int { currentLevel + 1 }
    public var isNewBuilding: Bool { currentLevel == 0 }
    public var id: String { "\(category.rawValue):\(dataID):\(targetLevel)#\(occurrence)" }
}

public struct Helper: Codable, Equatable, Sendable {
    public var dataID: Int
    public var level: Int
    public var cooldown: Int
}

public struct VillageExport: Equatable, Sendable {
    public var tag: String
    public var timestamp: Int
    public var townHallLevel: Int?
    public var builderHutCount: Int
    public var hasBobsHut: Bool
    public var helpers: [Helper]
    public var jobs: [Job]
    public var helperOnFinishedItem: Set<JobCategory>
    public var builderBoostRemaining: Int?

    public var regularBuilderJobs: [Job] { jobs.filter { $0.category == .builder && !$0.isGoblin } }
    public var derivedTotalBuilders: Int? {
        builderHutCount > 0 ? builderHutCount + (hasBobsHut ? 1 : 0) : nil
    }
}

public enum BoostType: String, Codable, CaseIterable, Identifiable, Sendable {
    case builderPotion, builderBite, researchPotion, petPotion
    public var id: String { rawValue }
    public var category: JobCategory {
        switch self {
        case .builderPotion, .builderBite: return .builder
        case .researchPotion: return .lab
        case .petPotion: return .pet
        }
    }
    public var title: String {
        switch self {
        case .builderPotion: return "Builder Potion"
        case .builderBite: return "Builder Bite"
        case .researchPotion: return "Research Potion"
        case .petPotion: return "Pet Potion"
        }
    }
    public var symbol: String { self == .builderBite ? "birthday.cake.fill" : "waterbottle.fill" }
}

public struct BoostUse: Codable, Equatable, Sendable {
    public var type: BoostType
    public var start: Int
    public var end: Int
    public init(type: BoostType, start: Int, end: Int) {
        self.type = type; self.start = start; self.end = end
    }
}

public struct BoostSettings: Codable, Equatable, Sendable {
    public var boostDuration = 3600
    public var builderPotionSaving = 9 * 3600
    public var builderBiteSaving = 3600
    public var researchPotionSaving = 23 * 3600
    public var petPotionSaving = 23 * 3600
    public var apprenticeSavingOverride: Int?
    public var labAssistantSavingOverride: Int?
    public var helperWindow = 3600
    public var helperPeriod = 23 * 3600
    public var boostsApplyToGoblin = true
    public init() {}

    public func saving(for type: BoostType) -> Int {
        switch type {
        case .builderPotion: return builderPotionSaving
        case .builderBite: return builderBiteSaving
        case .researchPotion: return researchPotionSaving
        case .petPotion: return petPotionSaving
        }
    }

    public var isValid: Bool {
        (60...86400).contains(boostDuration) &&
        (60...86400).contains(helperWindow) &&
        (helperWindow...604800).contains(helperPeriod) &&
        BoostType.allCases.allSatisfy { (0...604800).contains(saving(for: $0)) } &&
        [apprenticeSavingOverride, labAssistantSavingOverride].compactMap { $0 }
            .allSatisfy { (0...604800).contains($0) }
    }
}

public struct HelperLinks: Codable, Equatable, Sendable {
    public var apprenticeJobKey: String?
    public var labAssistantJobKey: String?
    public init(apprenticeJobKey: String? = nil, labAssistantJobKey: String? = nil) {
        self.apprenticeJobKey = apprenticeJobKey
        self.labAssistantJobKey = labAssistantJobKey
    }
    public subscript(category: JobCategory) -> String? {
        get {
            switch category {
            case .builder: return apprenticeJobKey
            case .lab: return labAssistantJobKey
            case .pet: return nil
            }
        }
        set {
            switch category {
            case .builder: apprenticeJobKey = newValue
            case .lab: labAssistantJobKey = newValue
            case .pet: break
            }
        }
    }
    public static func from(_ export: VillageExport) -> Self {
        Self(apprenticeJobKey: export.jobs.first { $0.category == .builder && $0.helperLinked }?.id,
             labAssistantJobKey: export.jobs.first { $0.category == .lab && $0.helperLinked }?.id)
    }
}

public struct AppState: Codable, Equatable, Sendable {
    public var exportJSON: String?
    public var links = HelperLinks()
    public var boosts: [BoostUse] = []
    public var firstRemaining: [String: Int] = [:]
    public init() {}
    public var village: VillageExport? { exportJSON.flatMap { try? ExportParser.parse($0) } }
}

public struct AppSettings: Codable, Equatable, Sendable {
    public var playerName = ""
    public var totalBuildersOverride: Int?
    public var boosts = BoostSettings()
    public var notificationsEnabled = false
    public init() {}
    public var displayName: String {
        let name = playerName.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? "Chief" : String(name.prefix(24))
    }
    public func totalBuilders(for village: VillageExport) -> Int {
        max(totalBuildersOverride ?? village.derivedTotalBuilders ?? 6, village.regularBuilderJobs.count)
    }
}

/// A single versioned document prevents mismatched settings and timer state after a write.
public struct StoredDocument: Codable, Equatable, Sendable {
    public var version = 1
    public var state = AppState()
    public var settings = AppSettings()
    public init() {}
}

public enum ClashError: LocalizedError, Equatable {
    case invalidExport(String), olderExport, futureExport, invalidSettings, unsupportedVersion
    public var errorDescription: String? {
        switch self {
        case .invalidExport(let reason): return reason
        case .olderExport: return "This export is older than your last sync. Copy fresh data from Clash of Clans."
        case .futureExport: return "The export is dated in the future. Check your phone’s date and copy fresh data."
        case .invalidSettings: return "Choose positive boost durations and a helper interval at least as long as its session."
        case .unsupportedVersion: return "This data was saved by a newer version of Clash Timers. Update the app to open it."
        }
    }
}
