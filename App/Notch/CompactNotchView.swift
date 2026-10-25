import SleeperKit
import SwiftUI

/// Zona izquierda del notch: avatar de mi equipo.
struct CompactLeadingView: View {
    let model: NotchModel
    /// `true` si se pidió por hover, `false` por clic.
    let onExpand: (_ viaHover: Bool) -> Void

    var body: some View {
        TeamAvatarView(url: model.snapshot?.me.avatarURL)
            .padding(.horizontal, 4)
            .contentShape(Rectangle())
            .onHover { if $0 { onExpand(true) } }
            .onTapGesture { onExpand(false) }
    }
}

/// Zona derecha del notch: `mis – rival` en el color del estado, o "Sin matchup".
struct CompactTrailingView: View {
    let model: NotchModel
    /// `true` si se pidió por hover, `false` por clic.
    let onExpand: (_ viaHover: Bool) -> Void

    var body: some View {
        Group {
            if let snapshot = model.snapshot {
                HStack(spacing: 3) {
                    // El color gris no es la única señal de datos viejos (DESIGN.md §Colores).
                    if snapshot.isStale { Image(systemName: "wifi.slash") }
                    Text(ScoreDisplay.compactText(for: snapshot))
                }
                .foregroundStyle(NotchPalette.color(for: ScoreDisplay.tone(for: snapshot)))
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(ScoreDisplay.accessibilityLabel(for: snapshot))
            } else {
                Text(ScoreDisplay.noMatchupText)
                    .foregroundStyle(NotchPalette.secondary)
            }
        }
        .font(.caption.weight(.semibold).monospacedDigit())
        .lineLimit(1)
        .padding(.horizontal, 4)
        .contentShape(Rectangle())
        .onHover { if $0 { onExpand(true) } }
        .onTapGesture { onExpand(false) }
    }
}

#if canImport(SleeperKitMocks)
import SleeperKitMocks

#Preview("Compacta · ganando") {
    let model = NotchModel()
    model.snapshot = .previewLive
    return HStack {
        CompactLeadingView(model: model, onExpand: { _ in })
        CompactTrailingView(model: model, onExpand: { _ in })
    }
    .padding()
    .background(.black)
}

#Preview("Compacta · bye") {
    let model = NotchModel()
    model.snapshot = .previewBye
    return CompactTrailingView(model: model, onExpand: { _ in }).padding().background(.black)
}

#Preview("Compacta · desactualizado") {
    let model = NotchModel()
    model.snapshot = .previewStale
    return CompactTrailingView(model: model, onExpand: { _ in }).padding().background(.black)
}
#endif
