import Foundation

/// Estado visual del marcador; la vista lo traduce a color (docs/DESIGN.md §Colores).
public enum ScoreTone: Sendable, Equatable, CaseIterable {
    case winning
    case losing
    case tied
    case stale
    case noMatchup
}

/// Lógica pura de formato y color del marcador, sin SwiftUI para poder probarla en `swift test`.
public enum ScoreDisplay {
    public static let noMatchupText = "Sin matchup"

    /// Un decimal con punto, sin depender del locale. Redondea a décimas enteras para no
    /// producir "-0.0".
    public static func points(_ value: Double) -> String {
        let tenths = tenths(value)
        let sign = tenths < 0 ? "-" : ""
        let magnitude = abs(tenths)
        return "\(sign)\(magnitude / 10).\(magnitude % 10)"
    }

    /// `112.4 – 98.7` (raya U+2013 con espacios), o "Sin matchup" si no hay rival.
    public static func compactText(for snapshot: MatchupSnapshot) -> String {
        guard let opponent = snapshot.opponent else { return noMatchupText }
        return "\(points(snapshot.me.points)) \u{2013} \(points(opponent.points))"
    }

    /// Compara los valores ya redondeados a 1 decimal: lo que se ve en pantalla manda.
    /// `isStale` anula verde/rojo para no presentar datos viejos como actuales.
    public static func tone(for snapshot: MatchupSnapshot) -> ScoreTone {
        if snapshot.isStale { return .stale }
        guard let opponent = snapshot.opponent else { return .noMatchup }
        let mine = tenths(snapshot.me.points)
        let theirs = tenths(opponent.points)
        if mine > theirs { return .winning }
        if mine < theirs { return .losing }
        return .tied
    }

    public static func accessibilityLabel(for snapshot: MatchupSnapshot) -> String {
        guard let opponent = snapshot.opponent else { return noMatchupText }
        return "Tú \(points(snapshot.me.points)), rival \(points(opponent.points))"
    }

    /// `true` si `value` supera a `other` según lo que se muestra (1 decimal).
    public static func isLeading(_ value: Double, over other: Double) -> Bool {
        tenths(value) > tenths(other)
    }

    private static func tenths(_ value: Double) -> Int {
        Int((value * 10).rounded())
    }
}
