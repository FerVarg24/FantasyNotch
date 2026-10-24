import Foundation

/// Caché en disco de `GET /v1/players/nfl` (ADR 0003: como máximo 1 descarga al día).
///
/// Guarda solo `player_id`, `full_name`, `position` y `team` de cada jugador más `fetchedAt`, en
/// `<directorio>/players-v1.json`. Directorio y reloj se inyectan para poder probarlo sin tocar el disco real
/// ni esperar 24 h.
public actor PlayerCache {
    public static let fileName = "players-v1.json"
    public static let maxAge: TimeInterval = 24 * 3600

    private let fileURL: URL
    private let clock: @Sendable () -> Date

    /// `Application Support/FantasyNotch`, el directorio de producción.
    public static var defaultDirectory: URL {
        URL.applicationSupportDirectory.appendingPathComponent("FantasyNotch", isDirectory: true)
    }

    public init(directory: URL = PlayerCache.defaultDirectory, clock: @escaping @Sendable () -> Date = { Date() }) {
        self.fileURL = directory.appendingPathComponent(Self.fileName)
        self.clock = clock
    }

    /// Jugadores de la caché si tiene menos de 24 h; si no, los descarga con `api` y la reescribe.
    /// Si la descarga falla y hay una copia vieja legible, devuelve esa copia en vez de propagar el error.
    public func players(using api: any SleeperAPI) async throws -> [String: Player] {
        let stored = read()
        if let stored, clock().timeIntervalSince(stored.fetchedAt) < Self.maxAge {
            return stored.players.mapValues(\.player)
        }
        do {
            let fresh = try await api.players()
            write(File(fetchedAt: clock(), players: fresh.mapValues(StoredPlayer.init)))
            return fresh
        } catch {
            if let stored { return stored.players.mapValues(\.player) }
            throw error
        }
    }

    // MARK: - Disco

    private struct StoredPlayer: Codable {
        let playerId: String
        let fullName: String?
        let position: String?
        let team: String?

        enum CodingKeys: String, CodingKey {
            case playerId = "player_id"
            case fullName = "full_name"
            case position, team
        }

        init(_ player: Player) {
            playerId = player.playerId
            fullName = player.fullName
            position = player.position
            team = player.team
        }

        var player: Player {
            Player(playerId: playerId, fullName: fullName, position: position, team: team)
        }
    }

    private struct File: Codable {
        let fetchedAt: Date
        let players: [String: StoredPlayer]
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    /// Un archivo ausente, ilegible o con otra forma cuenta como "sin caché".
    private func read() -> File? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? Self.decoder.decode(File.self, from: data)
    }

    /// Escribir es un favor: si falla, la app sigue con los datos recién descargados.
    private func write(_ file: File) {
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Self.encoder.encode(file).write(to: fileURL, options: .atomic)
        } catch {
            return
        }
    }
}
