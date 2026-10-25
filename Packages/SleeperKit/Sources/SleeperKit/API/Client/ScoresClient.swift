import Foundation
import os

/// Un partido de `GET https://api.sleeper.com/scores/nfl/regular/{season}/{week}`.
///
/// Endpoint **no documentado**: solo se decodifican los campos que usa la app, todos opcionales. El resto del objeto
/// (decenas de campos de apuestas, estadio, reacciones…) se ignora. `start_time` son milisegundos desde 1970.
public struct ScoreGame: Codable, Sendable, Equatable {
    public struct Metadata: Codable, Sendable, Equatable {
        public let homeTeam: String?
        public let awayTeam: String?
        public let isInProgress: Bool?
        public let isOver: Bool?
        public let hasStarted: Bool?
        public let canceled: Bool?

        enum CodingKeys: String, CodingKey {
            case homeTeam = "home_team"
            case awayTeam = "away_team"
            case isInProgress = "is_in_progress"
            case isOver = "is_over"
            case hasStarted = "has_started"
            case canceled
        }

        public init(
            homeTeam: String? = nil, awayTeam: String? = nil, isInProgress: Bool? = nil,
            isOver: Bool? = nil, hasStarted: Bool? = nil, canceled: Bool? = nil
        ) {
            self.homeTeam = homeTeam
            self.awayTeam = awayTeam
            self.isInProgress = isInProgress
            self.isOver = isOver
            self.hasStarted = hasStarted
            self.canceled = canceled
        }
    }

    public let gameId: String?
    /// Valores observados: `pre_game` y `complete`. `in_game` se infiere, **nunca se observó** en un partido real.
    public let status: String?
    public let startTime: Int?
    public let metadata: Metadata?

    enum CodingKeys: String, CodingKey {
        case gameId = "game_id"
        case status
        case startTime = "start_time"
        case metadata
    }

    public init(gameId: String? = nil, status: String? = nil, startTime: Int? = nil, metadata: Metadata? = nil) {
        self.gameId = gameId
        self.status = status
        self.startTime = startTime
        self.metadata = metadata
    }
}

/// Origen de partidos de la semana. Lo implementa `ScoresClient`; los tests usan uno falso.
public protocol ScoresProviding: Sendable {
    func games(season: String, week: Int) async throws -> [ScoreGame]
}

/// Cliente HTTP del endpoint `scores`. Vive aparte de `LiveSleeperAPI` a propósito: cada cliente tiene **un solo host
/// fijo** (`api.sleeper.app` y `api.sleeper.com`), y ninguno acepta respuestas del otro (plan.md §Threat model).
///
/// Mismas garantías que `LiveSleeperAPI`: timeout de 10 s, límite de 20 MB, sin redirecciones, cookies ni caché,
/// segmentos de ruta validados e IDs registrados con `privacy: .private`. Tiene el mismo límite conocido: la
/// descarga completa ocurre antes de medir el tamaño.
///
/// Deuda: parte del transporte está duplicada con `LiveSleeperAPI`; extraerlo a un tipo común es un seguimiento.
public struct ScoresClient: ScoresProviding {
    static let host = "api.sleeper.com"
    static let baseURL = URL(string: "https://api.sleeper.com")!
    static let maxResponseBytes = 20 * 1024 * 1024
    static let requestTimeout: TimeInterval = 10

    private static let logger = Logger(subsystem: "com.fervarg.FantasyNotch", category: "api")

    private let session: URLSession

    /// - Parameter session: por defecto la misma sesión efímera de `LiveSleeperAPI` (sin caché ni cookies).
    public init(session: URLSession = LiveSleeperAPI.makeSession()) {
        self.session = session
    }

    public func games(season: String, week: Int) async throws -> [ScoreGame] {
        guard (0...30).contains(week) else {
            throw SleeperAPIError.invalidRequest(detail: "week out of range")
        }
        let url = try Self.url(for: ["scores", "nfl", "regular", season, String(week)])
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: Self.requestTimeout)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        Self.logger.debug("GET scores/nfl/regular/{season}/{week} \("\(season) \(week)", privacy: .private)")

        let data = try await send(request)
        return try SleeperDecoder.decode([ScoreGame].self, from: data)
    }

    // MARK: - Transporte

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
