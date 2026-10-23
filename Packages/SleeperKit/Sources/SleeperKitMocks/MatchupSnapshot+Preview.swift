import Foundation
import SleeperKit

/// Datos de ejemplo para previews de SwiftUI. Son inventados a mano (nombres genéricos), no vienen de Sleeper.
extension MatchupSnapshot {
    private static let previewDate = Date(timeIntervalSince1970: 1_791_000_000)

    private static func line(
        _ id: String, _ name: String, _ position: String, _ points: Double, _ status: PlayStatus
    ) -> StarterLine {
        StarterLine(playerId: id, name: name, position: position, points: points, status: status)
    }

    private static func team(_ id: Int, _ name: String, _ lines: [StarterLine]) -> TeamScore {
        TeamScore(
            rosterId: id,
            teamName: name,
            avatarURL: nil,
            points: lines.reduce(0) { $0 + $1.points },
            starters: lines
        )
    }

    /// Partido en curso: mezcla de titulares jugando, terminados y pendientes.
    public static let previewLive = MatchupSnapshot(
        week: 7,
        me: team(1, "Equipo 1", [
            line("p1", "Jugador A", "QB", 18.4, .playing),
            line("p2", "Jugador B", "RB", 9.2, .done),
            line("p3", "Jugador C", "WR", 0, .pending),
        ]),
        opponent: team(2, "Equipo 2", [
            line("p4", "Jugador D", "QB", 12.1, .done),
            line("p5", "Jugador E", "RB", 6.5, .playing),
            line("p6", "Jugador F", "WR", 0, .pending),
        ]),
        fetchedAt: previewDate,
        isStale: false
    )

    /// Partido terminado.
    public static let previewFinal = MatchupSnapshot(
        week: 7,
        me: team(1, "Equipo 1", [
            line("p1", "Jugador A", "QB", 24.6, .done),
            line("p2", "Jugador B", "RB", 14.3, .done),
        ]),
        opponent: team(2, "Equipo 2", [
            line("p4", "Jugador D", "QB", 20.0, .done),
            line("p5", "Jugador E", "RB", 11.8, .done),
        ]),
        fetchedAt: previewDate,
        isStale: false
    )

    /// Semana de descanso: sin rival.
    public static let previewBye = MatchupSnapshot(
        week: 14,
        me: team(3, "Equipo 3", [line("p7", "Jugador G", "QB", 0, .unknown)]),
        opponent: nil,
        fetchedAt: previewDate,
        isStale: false
    )

    /// Datos viejos: la última actualización falló y se muestra lo último conocido.
    public static let previewStale = MatchupSnapshot(
        week: 7,
        me: team(1, "Equipo 1", [line("p1", "Jugador A", "QB", 18.4, .playing)]),
        opponent: team(2, "Equipo 2", [line("p4", "Jugador D", "QB", 12.1, .playing)]),
        fetchedAt: previewDate,
        isStale: true
    )
}
