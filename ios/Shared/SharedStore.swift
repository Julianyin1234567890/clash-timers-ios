import Foundation
import ClashTimersCore

enum SharedStore {
    static var groupIdentifier: String? {
        DocumentStore.sharedGroup(
            configured: Bundle.main.object(forInfoDictionaryKey: "AppGroupIdentifier") as? String,
            altStoreGroups: Bundle.main.object(forInfoDictionaryKey: "ALTAppGroups") as? [String] ?? []
        )
    }
    static var hasWidgetSupport: Bool { groupIdentifier != nil }
    static var groupContainer: URL? {
        groupIdentifier.flatMap { FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: $0) }
    }
    static func make(isTesting: Bool = false) throws -> DocumentStore {
        if isTesting {
            return DocumentStore(fileURL: FileManager.default.temporaryDirectory
                .appendingPathComponent("ClashTimersUITests/state.json"))
        }
        if let groupIdentifier {
            guard let folder = groupContainer else {
                throw SharedStoreError.unavailableGroup(groupIdentifier)
            }
            return DocumentStore(fileURL: folder.appendingPathComponent("ClashTimers/state.json"))
        }
        let folder = try FileManager.default.url(for: .applicationSupportDirectory,
                                                in: .userDomainMask, appropriateFor: nil, create: true)
        return DocumentStore(fileURL: folder.appendingPathComponent("ClashTimers/state.json"))
    }
}

enum SharedStoreError: LocalizedError {
    case unavailableGroup(String)
    var errorDescription: String? {
        switch self {
        case .unavailableGroup:
            return "Shared storage is unavailable. For AltStore Classic, install ClashTimers-AltStore.ipa and keep its widget extension. The app and widget must share an App Group."
        }
    }
}
