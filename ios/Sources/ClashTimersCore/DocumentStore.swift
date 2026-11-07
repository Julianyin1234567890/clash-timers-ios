import Foundation
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif

public struct DocumentStore: Sendable {
    private static let mutationLock = NSLock()
    public let fileURL: URL
    public init(fileURL: URL) { self.fileURL = fileURL }

    /// AltStore Classic puts the provisioned groups for *each* bundle in ALTAppGroups.
    /// The app and its widget must resolve the same group after AltStore appends the team ID.
    public static func sharedGroup(configured: String?, altStoreGroups: [String]) -> String? {
        guard let base = configured, base.hasPrefix("group."), !base.contains("$(") else { return nil }
        let prefix = base + "."
        let remapped = altStoreGroups.first { group in
            guard group.hasPrefix(prefix) else { return false }
            let teamID = group.dropFirst(prefix.count).utf8
            return teamID.count == 10 && teamID.allSatisfy { (65...90).contains($0) || (48...57).contains($0) }
        }
        return remapped ?? base
    }

    public func load() throws -> StoredDocument {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return StoredDocument() }
        let document = try JSONDecoder().decode(StoredDocument.self, from: Data(contentsOf: fileURL))
        try validate(document)
        return document
    }

    public func save(_ document: StoredDocument) throws {
        _ = try update { $0 = document }
    }

    /// Serialize app and widget read-modify-write operations across threads and processes.
    @discardableResult
    public func update(_ edit: (inout StoredDocument) throws -> Void) throws -> StoredDocument {
        Self.mutationLock.lock()
        defer { Self.mutationLock.unlock() }
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let fd = open(fileURL.appendingPathExtension("lock").path, O_CREAT | O_RDWR, 0o600)
        guard fd >= 0 else { throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno)) }
        defer { close(fd) }
        guard lockf(fd, F_LOCK, 0) == 0 else { throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno)) }
        defer { _ = lockf(fd, F_ULOCK, 0) }
        var document = try load()
        try edit(&document)
        try write(document)
        return document
    }

    private func write(_ document: StoredDocument) throws {
        try validate(document)
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        var options: Data.WritingOptions = .atomic
        #if os(iOS)
        options.insert(.completeFileProtectionUntilFirstUserAuthentication)
        #endif
        try encoder.encode(document).write(to: fileURL, options: options)
    }

    private func validate(_ document: StoredDocument) throws {
        guard document.version == 1 else { throw ClashError.unsupportedVersion }
        guard document.settings.boosts.isValid,
              document.settings.totalBuildersOverride.map({ (1...20).contains($0) }) ?? true else {
            throw ClashError.invalidSettings
        }
        if let text = document.state.exportJSON { _ = try ExportParser.parse(text) }
        guard document.state.boosts.allSatisfy({ $0.start >= 0 && $0.end >= $0.start && $0.end <= 253_402_300_799 }) else {
            throw ClashError.invalidExport("The saved boost history is invalid.")
        }
    }
}
