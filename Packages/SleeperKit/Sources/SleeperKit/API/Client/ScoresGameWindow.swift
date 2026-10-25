import Foundation

/// Implementación real de `GameWindowProviding` (FN-008): decide la cadencia del poller a partir de `scores`.
///
/// Reglas (spike FN-003 §2). Se ignoran los partidos cancelados.
/// - `.live`: algún partido con `is_in_progress == true` o `status == "in_game"`.
/// - `.gameDay`: algún partido sin terminar que ya empezó (`has_started`) o que arranca en las próximas 24 h
///   (un `start_time` ya pasado sin confirmación de que terminó también cuenta).
/// - `.idle`: en cualquier otro caso.
///
/// Si `scores` falla, `window(forWeek:)` lanza el mismo error y el poller conserva el modo anterior.
/// La temporada se fija al crear el proveedor: si cambia con la app abierta (septiembre), `scores` devolverá
/// `notFound` y el poller seguirá con el último modo hasta reiniciar.
public struct ScoresGameWindow: GameWindowProviding {
    private let scores: any ScoresProviding
    private let season: String
    private let clock: any PollingClock

    public init(scores: any ScoresProviding, season: String, clock: any PollingClock = SystemPollingClock()) {
        self.scores = scores
        self.season = season
        self.clock = clock
    }

    public func window(forWeek week: Int) async throws -> GameWindow {
        let games = try await scores.games(season: season, week: week)
        return Self.window(from: games, now: clock.now())
    }

    /// Lógica pura, sin red ni reloj: la usan los tests.
    static func window(from games: [ScoreGame], now: Date) -> GameWindow {
        let horizon = now.addingTimeInterval(24 * 3600)
        var teamStates: [String: TeamPlayState] = [:]
        var anyLive = false
        var anyGameDay = false

        for game in games where game.metadata?.canceled != true {
            let state = playState(of: game)
            for team in [game.metadata?.homeTeam, game.metadata?.awayTeam].compactMap({ $0 }) where !team.isEmpty {
                teamStates[team] = state
            }
            switch state {
            case .inProgress:
                anyLive = true
            case .over:
                break
            case .preGame:
                if game.metadata?.hasStarted == true {
                    anyGameDay = true
                } else if let startTime = game.startTime,
                    Date(timeIntervalSince1970: Double(startTime) / 1000) <= horizon
                {
                    anyGameDay = true
                }
            }
        }

        let mode: PollingMode = anyLive ? .live : (anyGameDay ? .gameDay : .idle)
        return GameWindow(mode: mode, teamStates: teamStates)
    }

    private static func playState(of game: ScoreGame) -> TeamPlayState {
        if game.metadata?.isOver == true || game.status == "complete" { return .over }
        if game.metadata?.isInProgress == true || game.status == "in_game" { return .inProgress }
        return .preGame
    }
}

/// Respaldo sin red cuando `scores` no está disponible: solo conoce el horario habitual de la NFL (hora del este).
/// **Nunca devuelve `.live`**: sin datos del partido no se puede saber si uno está en juego.
public enum ScheduleFallback {
    public static func mode(at date: Date) -> PollingMode {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York") ?? TimeZone(secondsFromGMT: -5 * 3600) ?? .gmt
        let parts = calendar.dateComponents([.weekday, .hour], from: date)
        guard let weekday = parts.weekday, let hour = parts.hour else { return .idle }
        switch weekday {
        case 1 where hour >= 12: return .gameDay  // domingo, de 12:00 a 24:00
        case 2 where hour >= 20, 5 where hour >= 20: return .gameDay  // lunes y jueves, de 20:00 a 24:00
        default: return .idle
        }
    }
}
