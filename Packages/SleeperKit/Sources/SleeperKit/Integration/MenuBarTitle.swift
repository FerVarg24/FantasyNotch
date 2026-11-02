/// Texto del `MenuBarExtra`. Con notch el marcador ya está junto al notch y la barra solo muestra el icono; sin
/// notch (o con un monitor externo como principal) el marcador se muestra en la propia barra (spec §Barra de menú).
public enum MenuBarTitle {
    /// `nil` = solo icono.
    public static func text(for snapshot: MatchupSnapshot?, hasNotch: Bool) -> String? {
        guard !hasNotch, let snapshot else { return nil }
        let text = ScoreDisplay.compactText(for: snapshot)
        // El gris de «desactualizado» no es la única señal (DESIGN.md §Colores).
        return snapshot.isStale ? "⚠︎ \(text)" : text
    }
}
