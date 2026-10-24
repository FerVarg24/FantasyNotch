import Foundation

/// Contrato interno de acceso a Sleeper v1 (solo lectura, sin autenticación).
/// Lo implementan el cliente HTTP real y `MockSleeperAPI`. Ver `docs/specs/001-mvp/plan.md` §Contracts.
public protocol SleeperAPI: Sendable {
    func nflState() async throws -> NFLState
    func user(username: String) async throws -> SleeperUser
    func leagues(userId: String, season: String) async throws -> [League]
    func leagueUsers(leagueId: String) async throws -> [LeagueUser]
    func rosters(leagueId: String) async throws -> [Roster]
    func matchups(leagueId: String, week: Int) async throws -> [Matchup]
    func players() async throws -> [String: Player]
}

/// Errores tipados de la capa de API. La app nunca debe fallar por una respuesta inesperada de Sleeper.
public enum SleeperAPIError: Error, Equatable, Sendable {
    /// El cuerpo no tiene la forma esperada (`detail` describe la ruta del campo, sin datos del usuario).
    case decoding(detail: String)
    /// Respuesta HTTP fuera de 200–299 que no tiene un caso propio (por ejemplo, 400 o 403).
    case badStatus(Int)
    /// 429: demasiadas llamadas. El poller debe espaciar los intentos (backoff exponencial, máx. 5 min).
    case rateLimited
    /// 5xx: fallo del servidor de Sleeper; `status` es el código recibido.
    case server(status: Int)
    /// La respuesta supera el límite de 20 MB.
    case responseTooLarge
    /// La petición no se envió: identificador inválido (vacío o con `/`) o respuesta de un host distinto.
    case invalidRequest(detail: String)
    /// Fallo de red (sin conexión, timeout, etc.).
    case network(detail: String)
    /// El recurso no existe (por ejemplo, usuario o liga desconocidos).
    case notFound
}

/// Decodifica cuerpos de Sleeper convirtiendo cualquier `DecodingError` en `SleeperAPIError.decoding`.
public enum SleeperDecoder {
    public static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch let error as DecodingError {
            throw SleeperAPIError.decoding(detail: describe(error))
        } catch {
            throw SleeperAPIError.decoding(detail: "invalid JSON")
        }
    }

    private static func describe(_ error: DecodingError) -> String {
        func path(_ context: DecodingError.Context) -> String {
            context.codingPath.map(\.stringValue).joined(separator: ".")
        }
        switch error {
        case .keyNotFound(let key, let context):
            return "missing key \(key.stringValue) at \(path(context))"
        case .typeMismatch(_, let context), .valueNotFound(_, let context), .dataCorrupted(let context):
            return "\(context.debugDescription) at \(path(context))"
        @unknown default:
            return "decoding failed"
        }
    }
}
