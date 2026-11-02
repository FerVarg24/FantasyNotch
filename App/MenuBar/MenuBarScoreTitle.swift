import SleeperKit

/// Título del `MenuBarExtra` en el idioma del sistema. Con notch el marcador ya está junto al notch y la barra solo
/// muestra el icono (`nil`); sin notch (o con un monitor externo como principal) el marcador va en la barra.
enum MenuBarScoreTitle {
    static func text(for snapshot: MatchupSnapshot?, hasNotch: Bool) -> String? {
        guard !hasNotch, let snapshot else { return nil }
        let text = NotchText.compact(for: snapshot)
        // El gris de «desactualizado» no es la única señal (DESIGN.md §Colores).
        return snapshot.isStale ? "⚠︎ \(text)" : text
    }
}
