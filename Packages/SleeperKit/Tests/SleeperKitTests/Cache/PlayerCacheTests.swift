import Foundation
import Testing

@testable import SleeperKit
@testable import SleeperKitMocks

/// `SleeperAPI` que cuenta las llamadas a `players()` y puede fallar a demanda.
private final class CountingAPI: SleeperAPI, @unchecked Sendable {
    private let lock = NSLock()
    private var calls = 0
    private let result: Result<[String: Player], SleeperAPIError>

    init(_ result: Result<[String: Player], SleeperAPIError>) {
        self.result = result
    }

    var playersCalls: Int { lock.withLock { calls } }

    func players() async throws -> [String: Player] {
        lock.withLock { calls += 1 }
        return try result.get()
    }

    func nflState() async throws -> NFLState { throw SleeperAPIError.notFound }
    func user(username: String) async throws -> SleeperUser { throw SleeperAPIError.notFound }
    func leagues(userId: String, season: String) async throws -> [League] { throw SleeperAPIError.notFound }
    func leagueUsers(leagueId: String) async throws -> [LeagueUser] { throw SleeperAPIError.notFound }
    func rosters(leagueId: String) async throws -> [Roster] { throw SleeperAPIError.notFound }
    func matchups(leagueId: String, week: Int) async throws -> [Matchup] { throw SleeperAPIError.notFound }
}

@Suite("PlayerCache: caché de jugadores en disco")
struct PlayerCacheTests {
    private static let t0 = Date(timeIntervalSince1970: 1_800_000_000)
    private static let hour: TimeInterval = 3600

    private static let sample: [String: Player] = [
        "4046": Player(
            playerId: "4046", firstName: "Patrick", lastName: "Mahomes", fullName: "Patrick Mahomes",
            position: "QB", team: "KC", status: "Active", injuryStatus: "Questionable"),
        "KC": Player(playerId: "KC", firstName: "Kansas City", lastName: "Chiefs", position: "DEF", team: "KC"),
    ]

    private func makeDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("PlayerCacheTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func cache(in directory: URL, at now: Date) -> PlayerCache {
        PlayerCache(directory: directory, clock: { now })
    }

    @Test("Con caché de 1 h no se llama a players()")
    func freshCacheSkipsAPI() async throws {
        let dir = try makeDirectory()
        _ = try await cache(in: dir, at: Self.t0).players(using: CountingAPI(.success(Self.sample)))

        let api = CountingAPI(.failure(.badStatus(500)))
        let result = try await cache(in: dir, at: Self.t0 + Self.hour).players(using: api)

        #expect(api.playersCalls == 0)
        #expect(result["4046"]?.fullName == "Patrick Mahomes")
    }

    @Test("Sin caché descarga una vez y la guarda en players-v1.json")
    func missingCacheDownloads() async throws {
        let dir = try makeDirectory()
        let api = CountingAPI(.success(Self.sample))

        let result = try await cache(in: dir, at: Self.t0).players(using: api)

        #expect(api.playersCalls == 1)
        #expect(result.keys.sorted() == ["4046", "KC"])
        #expect(FileManager.default.fileExists(atPath: dir.appendingPathComponent("players-v1.json").path))
    }

    @Test("Con caché de más de 24 h vuelve a descargar")
    func staleCacheRefreshes() async throws {
        let dir = try makeDirectory()
        _ = try await cache(in: dir, at: Self.t0).players(using: CountingAPI(.success(Self.sample)))

        let updated = ["4046": Player(playerId: "4046", fullName: "Pat Mahomes", position: "QB", team: "KC")]
        let api = CountingAPI(.success(updated))
        let result = try await cache(in: dir, at: Self.t0 + 25 * Self.hour).players(using: api)

        #expect(api.playersCalls == 1)
        #expect(result.keys.sorted() == ["4046"])
        #expect(result["4046"]?.fullName == "Pat Mahomes")
    }

    @Test("Si la descarga falla con caché vieja, usa la copia vieja")
    func failedRefreshFallsBackToStaleCopy() async throws {
        let dir = try makeDirectory()
        _ = try await cache(in: dir, at: Self.t0).players(using: CountingAPI(.success(Self.sample)))

        let api = CountingAPI(.failure(.network(detail: "offline")))
        let result = try await cache(in: dir, at: Self.t0 + 48 * Self.hour).players(using: api)

        #expect(api.playersCalls == 1)
        #expect(result["4046"]?.fullName == "Patrick Mahomes")
    }

    @Test("Si la descarga falla y no hay copia, propaga el error")
    func failedDownloadWithoutCopyThrows() async throws {
        let dir = try makeDirectory()
        let api = CountingAPI(.failure(.network(detail: "offline")))

        await #expect(throws: SleeperAPIError.network(detail: "offline")) {
            _ = try await cache(in: dir, at: Self.t0).players(using: api)
        }
    }

    @Test("Un archivo corrupto se trata como ausente")
    func corruptFileIsIgnored() async throws {
        let dir = try makeDirectory()
        try Data("{ no es json".utf8).write(to: dir.appendingPathComponent("players-v1.json"))
        let api = CountingAPI(.success(Self.sample))

        let result = try await cache(in: dir, at: Self.t0).players(using: api)

        #expect(api.playersCalls == 1)
        #expect(result.count == 2)
    }

    @Test("Guarda solo player_id, full_name, position, team y fetchedAt")
    func persistsOnlyMinimalFields() async throws {
        let dir = try makeDirectory()
        _ = try await cache(in: dir, at: Self.t0).players(using: CountingAPI(.success(Self.sample)))

        let data = try Data(contentsOf: dir.appendingPathComponent("players-v1.json"))
        let root = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(Set(root.keys) == ["fetchedAt", "players"])

        let players = try #require(root["players"] as? [String: [String: Any]])
        let mahomes = try #require(players["4046"])
        #expect(Set(mahomes.keys) == ["player_id", "full_name", "position", "team"])

        let text = String(decoding: data, as: UTF8.self)
        for leaked in ["first_name", "last_name", "injury_status", "Questionable", "Patrick\"", "Active"] {
            #expect(!text.contains(leaked), "se filtró \(leaked) al disco")
        }
    }

    @Test("Los jugadores devueltos desde disco conservan los campos guardados")
    func roundTripKeepsStoredFields() async throws {
        let dir = try makeDirectory()
        _ = try await cache(in: dir, at: Self.t0).players(using: CountingAPI(.success(Self.sample)))

        let result = try await cache(in: dir, at: Self.t0 + Self.hour)
            .players(using: CountingAPI(.failure(.badStatus(500))))

        let mahomes = try #require(result["4046"])
        #expect(mahomes.fullName == "Patrick Mahomes")
        #expect(mahomes.position == "QB")
        #expect(mahomes.team == "KC")
        #expect(mahomes.injuryStatus == nil)
    }
}
