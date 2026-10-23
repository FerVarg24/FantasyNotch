import Foundation
import os

/// Cliente HTTP de Sleeper v1 (solo lectura, sin autenticación).
///
/// Garantías (plan.md §Threat model):
/// - Host fijo `https://api.sleeper.app/v1`: los identificadores solo pueden ser un segmento de ruta
///   (`A–Z a–z 0–9 _ - .`), y se descarta cualquier respuesta cuyo host final sea otro.
/// - Timeout de 10 s (30 s para `/players/nfl`) y límite de respuesta de 20 MB.
/// - Las redirecciones no se siguen. El username y los IDs se registran con `privacy: .private`.
///
/// Límite conocido: `URLSession.data(for:)` descarga el cuerpo completo antes de que se mida. El tamaño solo
/// se corta de antemano si la respuesta declara `Content-Length`; una respuesta sin él se mide al terminar.
public struct LiveSleeperAPI: SleeperAPI {
    static let host = "api.sleeper.app"
    static let baseURL = URL(string: "https://api.sleeper.app/v1")!
    static let maxResponseBytes = 20 * 1024 * 1024
    static let requestTimeout: TimeInterval = 10
    static let playersTimeout: TimeInterval = 30

    private static let logger = Logger(subsystem: "com.fervarg.FantasyNotch", category: "api")

    private let session: URLSession

    public init(session: URLSession = LiveSleeperAPI.makeSession()) {
        self.session = session
    }

    /// Sesión efímera sin caché, cookies ni espera de conectividad: cada llamada va al CDN de Sleeper.
    public static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.waitsForConnectivity = false
        configuration.httpShouldSetCookies = false
        configuration.httpCookieStorage = nil
        return URLSession(configuration: configuration)
    }

    // MARK: - SleeperAPI

    public func nflState() async throws -> NFLState {
        try await get(NFLState.self, ["state", "nfl"], label: "state/nfl")
    }

    public func user(username: String) async throws -> SleeperUser {
        // Para un usuario que no existe, Sleeper responde 200 con el cuerpo `null`, no 404.
        let user = try await get(SleeperUser?.self, ["user", username], label: "user/{username}", ids: username)
        guard let user else { throw SleeperAPIError.notFound }
        return user
    }

    public func leagues(userId: String, season: String) async throws -> [League] {
        try await get(
            [League].self, ["user", userId, "leagues", "nfl", season],
            label: "user/{id}/leagues/nfl/{season}", ids: "\(userId) \(season)")
    }

    public func leagueUsers(leagueId: String) async throws -> [LeagueUser] {
        try await get([LeagueUser].self, ["league", leagueId, "users"], label: "league/{id}/users", ids: leagueId)
    }

    public func rosters(leagueId: String) async throws -> [Roster] {
        try await get([Roster].self, ["league", leagueId, "rosters"], label: "league/{id}/rosters", ids: leagueId)
    }

    public func matchups(leagueId: String, week: Int) async throws -> [Matchup] {
        guard (0...30).contains(week) else {
            throw SleeperAPIError.invalidRequest(detail: "week out of range")
        }
        return try await get(
            [Matchup].self, ["league", leagueId, "matchups", String(week)],
            label: "league/{id}/matchups/{week}", ids: "\(leagueId) \(week)")
    }

    public func players() async throws -> [String: Player] {
        try await get([String: Player].self, ["players", "nfl"], label: "players/nfl", timeout: Self.playersTimeout)
    }

    // MARK: - Petición

    private func get<T: Decodable>(
        _ type: T.Type,
        _ segments: [String],
        label: String,
        ids: String = "",
        timeout: TimeInterval = LiveSleeperAPI.requestTimeout
    ) async throws -> T {
        let url = try Self.url(for: segments)
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: timeout)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        Self.logger.debug("GET \(label, privacy: .public) \(ids, privacy: .private)")

        let data = try await send(request)
        return try SleeperDecoder.decode(type, from: data)
    }

    private func send(_ request: URLRequest) async throws -> Data {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request, delegate: NoRedirectDelegate())
        } catch let error as URLError {
            if error.code == .cancelled { throw CancellationError() }
            throw SleeperAPIError.network(detail: "URLError \(error.code.rawValue)")
        }

        guard let http = response as? HTTPURLResponse else {
            throw SleeperAPIError.invalidRequest(detail: "non-HTTP response")
        }
        guard http.url?.scheme == "https", http.url?.host == Self.host else {
            throw SleeperAPIError.invalidRequest(detail: "response from unexpected host")
        }
        switch http.statusCode {
        case 200...299: break
        case 404: throw SleeperAPIError.notFound
        case 429: throw SleeperAPIError.rateLimited
        case 500...599: throw SleeperAPIError.server(status: http.statusCode)
        default: throw SleeperAPIError.badStatus(http.statusCode)
        }

        let declared = http.value(forHTTPHeaderField: "Content-Length").flatMap(Int.init)
        if let declared, declared > Self.maxResponseBytes { throw SleeperAPIError.responseTooLarge }
        if data.count > Self.maxResponseBytes { throw SleeperAPIError.responseTooLarge }
        return data
    }

    /// Construye la URL a partir de segmentos validados: nada de `/`, `..`, espacios ni parámetros.
    static func url(for segments: [String]) throws -> URL {
        var url = baseURL
        for segment in segments {
            guard isSafe(segment) else {
                throw SleeperAPIError.invalidRequest(detail: "invalid path segment")
            }
            url.append(path: segment)
        }
        return url
    }

    private static let allowed = CharacterSet(
        charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-.")

    private static func isSafe(_ segment: String) -> Bool {
        !segment.isEmpty
            && segment != "." && segment != ".."
            && segment.unicodeScalars.allSatisfy(allowed.contains)
    }
}

/// Corta las redirecciones: la respuesta 3xx se devuelve tal cual y el cliente la reporta como `badStatus`.
private final class NoRedirectDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest
    ) async -> URLRequest? {
        nil
    }
}
