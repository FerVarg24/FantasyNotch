/// Cadencias del poller según ADR 0003. Todas las constantes viven aquí para ajustarlas con datos reales.
public enum PollingMode: Sendable, Equatable, CaseIterable {
    /// Hay partidos en vivo con jugadores del matchup.
    case live
    /// Día de juego sin partidos en vivo.
    case gameDay
    /// Sin partidos.
    case idle

    public var interval: Duration {
        switch self {
        case .live: .seconds(60)
        case .gameDay: .seconds(300)
        case .idle: .seconds(1800)
        }
    }
}

public enum PollingPolicy {
    /// Mínimo entre dos llamadas a `/matchups`, cualquiera que sea su origen (tick, `refreshNow`, `resume`).
    /// 60 s porque Sleeper cachea esa respuesta 60 s (spike 003 §3): pedirla antes devuelve el mismo cuerpo.
    public static let minimumMatchupGap: Duration = .seconds(60)
    /// Tope del backoff exponencial ante errores (429, 5xx, red).
    public static let maxBackoff: Duration = .seconds(300)
    /// Cada cuánto se vuelven a pedir semana, rosters, usuarios de la liga y jugadores.
    public static let slowRefreshInterval: Duration = .seconds(1800)
    /// Refrescos fallidos seguidos tras los cuales el último snapshot se marca `isStale`.
    public static let staleAfterFailures = 2
}

/// Estado del partido de un equipo de la NFL, por código de equipo (`Player.team`).
public enum TeamPlayState: Sendable, Equatable {
    case preGame
    case inProgress
    case over
}

/// Lo que el poller necesita saber de la jornada para elegir su cadencia y resolver `PlayStatus`.
public struct GameWindow: Sendable, Equatable {
    public let mode: PollingMode
    /// Por código de equipo NFL; un equipo ausente se interpreta como estado desconocido.
    public let teamStates: [String: TeamPlayState]

    public init(mode: PollingMode, teamStates: [String: TeamPlayState] = [:]) {
        self.mode = mode
        self.teamStates = teamStates
    }
}

/// Origen de `GameWindow`. La implementación real (endpoint `scores` de Sleeper, otro host) **no existe aún**:
/// ninguna tarea del backlog la cubre. Ver la decisión abierta de FN-008.
public protocol GameWindowProviding: Sendable {
    func window(forWeek week: Int) async throws -> GameWindow
}
