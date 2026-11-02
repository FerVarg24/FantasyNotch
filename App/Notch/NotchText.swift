import Foundation
import SleeperKit

/// Texto del notch en el idioma del sistema (claves en `App/Localizable.xcstrings`, fuente en español).
///
/// Las claves viven aquí y no en `ScoreDisplay` porque SleeperKit no tiene recursos de localización; de SleeperKit
/// solo se usan números, colores y comparaciones (`points`, `tone`, `isLeading`).
enum NotchText {
    static var noMatchup: String { String(localized: "Sin matchup") }

    /// `112.4 – 98.7`, o «Sin matchup» si no hay rival.
    static func compact(for snapshot: MatchupSnapshot) -> String {
        snapshot.opponent == nil ? noMatchup : ScoreDisplay.compactText(for: snapshot)
    }

    /// Frase de VoiceOver: «Vas ganando 112.4 a 98.7». El estado «desactualizado» se añade al final para que el color
    /// no sea la única señal.
    static func summary(for snapshot: MatchupSnapshot) -> String {
        guard let opponent = snapshot.opponent else {
            return withStaleSuffix(noMatchup, snapshot)
        }
        let mine = ScoreDisplay.points(snapshot.me.points)
        let theirs = ScoreDisplay.points(opponent.points)
        let base: String
        if ScoreDisplay.isLeading(snapshot.me.points, over: opponent.points) {
            base = String(localized: "Vas ganando \(mine) a \(theirs)")
        } else if ScoreDisplay.isLeading(opponent.points, over: snapshot.me.points) {
            base = String(localized: "Vas perdiendo \(mine) a \(theirs)")
        } else {
            base = String(localized: "Empate \(mine) a \(theirs)")
        }
        return withStaleSuffix(base, snapshot)
    }

    /// Pie de la vista expandida.
    static func footer(for snapshot: MatchupSnapshot, now: Date) -> String {
        let elapsed = max(0, Int(now.timeIntervalSince(snapshot.fetchedAt)))
        if snapshot.isStale {
            let minutes = max(1, elapsed / 60)
            return String(localized: "Sin conexión · datos de hace \(minutes) min")
        }
        return String(localized: "Actualizado hace \(elapsed) s")
    }

    static func status(_ status: PlayStatus) -> String {
        switch status {
        case .pending: String(localized: "Pendiente")
        case .playing: String(localized: "Jugando")
        case .done: String(localized: "Terminado")
        case .unknown: String(localized: "Sin datos")
        }
    }

    /// Titular para VoiceOver: «Jugador A, QB, 18.4 puntos, Jugando».
    static func starter(_ line: StarterLine) -> String {
        let points = ScoreDisplay.points(line.points)
        return String(localized: "\(line.name), \(line.position), \(points) puntos, \(status(line.status))")
    }

    /// Equipo para VoiceOver: «Equipo 1, 112.4 puntos».
    static func team(_ team: TeamScore) -> String {
        let points = ScoreDisplay.points(team.points)
        return String(localized: "\(team.teamName), \(points) puntos")
    }

    private static func withStaleSuffix(_ text: String, _ snapshot: MatchupSnapshot) -> String {
        snapshot.isStale ? String(localized: "\(text), desactualizado") : text
    }
}
