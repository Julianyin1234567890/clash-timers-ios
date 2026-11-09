import XCTest
@testable import ClashTimersCore
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

final class PlayerProfileTests: XCTestCase {
    private let tag = "#P0Y8LQ"
    private func fixture(king: Int = 8) -> Data {
        Data("""
        {"tag":"#P0Y8LQ","name":"Sample Village","townHallLevel":16,
         "heroes":[{"id":0,"level":\(king),"maxLevel":105,"village":"home"}],
         "troops":[{"id":14,"level":1,"maxLevel":7,"village":"home"},
                   {"id":24,"level":14,"maxLevel":20,"village":"builder"},
                   {"id":17,"level":5,"maxLevel":11,"village":"home"},
                   {"id":999,"level":2,"maxLevel":5,"village":"home"},
                   {"id":16,"level":0,"maxLevel":8,"village":"home"}],
         "spells":[{"id":8,"level":1,"maxLevel":8,"village":"home"}],
         "heroEquipment":[{"id":0,"apiName":"Barbarian Puppet","level":1,"maxLevel":18,"isUnlocked":true},
                          {"id":9,"apiName":"Unowned Item","level":1,"maxLevel":18,"isUnlocked":false}]}
        """.utf8)
    }

    func testProviderIDsNamesVillagesAndOwnedEquipment() throws {
        let profile = try PlayerProfileDecoder.decode(fixture(), expectedTag: tag)
        XCTAssertEqual(profile.levels.count, 7)
        XCTAssertEqual(profile.levels.first?.name, "Barbarian King")
        XCTAssertTrue(profile.levels.contains { $0.name == "Witch" })
        XCTAssertTrue(profile.levels.contains { $0.name == "Clone Spell" })
        let dragons = profile.levels.filter { $0.name == "Baby Dragon" }
        XCTAssertEqual(Set(dragons.map(\.village)), ["home", "builderBase"])
        XCTAssertEqual(Set(dragons.map(\.id)).count, 2)
        XCTAssertFalse(profile.levels.contains { $0.name == "Unowned Item" || $0.level == 0 })
        XCTAssertEqual(profile.levels.first { $0.id == "troops:home:999" }?.name, "Unknown troops #999")
    }

    func testCompareOnlySamePlayerAndKnownPreviousLevels() throws {
        let original = try PlayerProfileDecoder.decode(fixture(), expectedTag: tag)
        let newer = try PlayerProfileDecoder.decode(fixture(king: 9), expectedTag: tag)
        XCTAssertTrue(original.increases.isEmpty)
        XCTAssertFalse(original.hasPreviousCheck)
        let compared = newer.comparing(to: original)
        XCTAssertTrue(compared.hasPreviousCheck)
        XCTAssertEqual(compared.increases.map(\.name), ["Barbarian King"])
        XCTAssertEqual(compared.increases.first?.previousLevel, 8)
        XCTAssertTrue(newer.comparing(to: newer).increases.isEmpty)
        var other = original
        other.tag = "#P0Y8LJ"
        XCTAssertFalse(newer.comparing(to: other).hasPreviousCheck)
        other = original
        other.levels.removeAll { $0.category == .heroes }
        XCTAssertTrue(newer.comparing(to: other).increases.isEmpty)
    }

    func testBadOrMismatchedResponsesAreRejected() throws {
        XCTAssertThrowsError(try PlayerProfileDecoder.decode(fixture(), expectedTag: "#P0Y8LJ")) {
            XCTAssertEqual($0 as? PlayerProfileError, .wrongPlayer)
        }
        for bad in [Data("{}".utf8), Data("<html>Error</html>".utf8), fixture(king: -1), fixture(king: 1001)] {
            XCTAssertThrowsError(try PlayerProfileDecoder.decode(bad, expectedTag: tag))
        }
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: fixture()) as? [String: Any])
        json["heroes"] = [["id": 0, "level": 8, "maxLevel": 105], ["id": 0, "level": 9, "maxLevel": 105]]
        XCTAssertThrowsError(try PlayerProfileDecoder.decode(JSONSerialization.data(withJSONObject: json), expectedTag: tag))
    }

    func testTagNormalizationRejectsURLsAndCredentials() throws {
        XCTAssertEqual(try PlayerProfileDecoder.normalizedTag("  p0y8lq\n"), tag)
        for invalid in ["", "#", "##P0Y8LQ", "name@example.com", "https://example.com", "POY8LQ", String(repeating: "P", count: 16)] {
            XCTAssertThrowsError(try PlayerProfileDecoder.normalizedTag(invalid))
        }
    }

    func testOldDocumentLoadsAndOnlineRefreshPreservesTimers() throws {
        var document = StoredDocument()
        document.state.exportJSON = "{\"tag\":\"#P0Y8LQ\",\"timestamp\":100,\"buildings\":[{\"data\":1000008,\"lvl\":4,\"timer\":1000}]}"
        let old = try JSONEncoder().encode(document) // nil optional keys are omitted, as in 1.0.4.
        let loaded = try JSONDecoder().decode(StoredDocument.self, from: old)
        XCTAssertNil(loaded.playerProfile)
        XCTAssertNil(loaded.settings.refreshLevelsOnOpen)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = DocumentStore(fileURL: directory.appendingPathComponent("document.json"))
        try store.save(loaded)
        let profile = try PlayerProfileDecoder.decode(fixture(), expectedTag: tag)
        try store.update { $0.playerProfile = profile }
        let saved = try store.load()
        XCTAssertEqual(saved.state, loaded.state)
        XCTAssertEqual(saved.playerProfile, profile)
        try store.update { $0.state.links.apprenticeJobKey = "builder-job" }
        XCTAssertEqual(try store.load().playerProfile, profile)
    }

    func testClientUsesPublicHTTPSRequestAndHandlesServiceFailure() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [ProfileTestProtocol.self]
        let session = URLSession(configuration: config)
        defer { session.invalidateAndCancel(); ProfileTestProtocol.handler = nil }
        let data = fixture()
        ProfileTestProtocol.handler = { request in
            XCTAssertEqual(request.url?.absoluteString, "https://api.clashofstats.com/players/P0Y8LQ")
            XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
            XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "application/json")
            return (200, data)
        }
        let client = PlayerProfileClient(session: session)
        let profile = try await client.fetch(tag: tag)
        XCTAssertEqual(profile.tag, tag)
        ProfileTestProtocol.handler = { _ in (429, Data()) }
        do {
            _ = try await client.fetch(tag: tag)
            XCTFail("Expected rate limit error")
        } catch {
            XCTAssertEqual(error as? PlayerProfileError, .unavailable(429))
        }
    }
}

private final class ProfileTestProtocol: URLProtocol {
    static var handler: ((URLRequest) -> (Int, Data))?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        guard let handler = Self.handler, let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse)); return
        }
        let (status, data) = handler(request)
        let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: "HTTP/1.1", headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
