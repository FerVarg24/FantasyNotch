import SleeperKit
import SwiftUI

/// Zona izquierda del notch: avatar de mi equipo.
struct CompactLeadingView: View {
    let model: NotchModel
    let onExpand: () -> Void

    var body: some View {
        TeamAvatarView(url: model.snapshot?.me.avatarURL)
            .padding(.horizontal, 4)
            .contentShape(Rectangle())
            .onHover { if $0 { onExpand() } }
            .onTapGesture(perform: onExpand)
    }
}

/// Zona derecha del notch: `mis – rival` en el color del estado, o "Sin matchup".
struct CompactTrailingView: View {
    let model: NotchModel
    let onExpand: () -> Void

    var body: some View {
        Group {
            if let snapshot = model.snapshot {
                Text(ScoreDisplay.compactText(for: snapshot))
                    .foregroundStyle(NotchPalette.color(for: ScoreDisplay.tone(for: snapshot)))
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
        .onHover { if $0 { onExpand() } }
        .onTapGesture(perform: onExpand)
    }
}

#if canImport(SleeperKitMocks)
import SleeperKitMocks

#Preview("Compacta · ganando") {
    let model = NotchModel()
    model.snapshot = .previewLive
    return HStack {
        CompactLeadingView(model: model, onExpand: {})
        CompactTrailingView(model: model, onExpand: {})
    }
    .padding()
    .background(.black)
}

#Preview("Compacta · bye") {
    let model = NotchModel()
    model.snapshot = .previewBye
    return CompactTrailingView(model: model, onExpand: {}).padding().background(.black)
}

#Preview("Compacta · desactualizado") {
    let model = NotchModel()
    model.snapshot = .previewStale
    return CompactTrailingView(model: model, onExpand: {}).padding().background(.black)
}
#endif
