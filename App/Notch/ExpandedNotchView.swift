import SleeperKit
import SwiftUI

/// Vista expandida: cabecera con ambos equipos y dos columnas de titulares (docs/DESIGN.md).
struct ExpandedNotchView: View {
    let model: NotchModel

    var body: some View {
        Group {
            if let snapshot = model.snapshot {
                content(snapshot)
            } else {
                Text(ScoreDisplay.noMatchupText).foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .frame(width: 360)
        .frame(maxHeight: 260)
    }

    private func content(_ snapshot: MatchupSnapshot) -> some View {
        let tone = ScoreDisplay.tone(for: snapshot)
        return VStack(spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                TeamColumn(team: snapshot.me, highlight: leads(snapshot.me, snapshot.opponent), tone: tone)
                if let opponent = snapshot.opponent {
                    TeamColumn(team: opponent, highlight: leads(opponent, snapshot.me), tone: .tied)
                } else {
                    Text(ScoreDisplay.noMatchupText)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            Text(footer(snapshot))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private func leads(_ team: TeamScore, _ other: TeamScore?) -> Bool {
        guard let other else { return false }
        return ScoreDisplay.isLeading(team.points, over: other.points)
    }

    private func footer(_ snapshot: MatchupSnapshot) -> String {
        let elapsed = max(0, Int(Date().timeIntervalSince(snapshot.fetchedAt)))
        if snapshot.isStale {
            return "Sin conexión · datos de hace \(max(1, elapsed / 60)) min"
        }
        return "Actualizado hace \(elapsed) s"
    }
}

private struct TeamColumn: View {
    let team: TeamScore
    let highlight: Bool
    let tone: ScoreTone

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                TeamAvatarView(url: team.avatarURL, size: 20)
                Text(team.teamName)
                    .font(.callout.weight(highlight ? .semibold : .regular))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            Text(ScoreDisplay.points(team.points))
                .font(.title3.weight(highlight ? .semibold : .regular).monospacedDigit())
                .foregroundStyle(NotchPalette.color(for: tone))
            ForEach(team.starters, id: \.playerId) { StarterRow(line: $0) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
    }
}

private struct StarterRow: View {
    let line: StarterLine

    var body: some View {
        HStack(spacing: 4) {
            Text(line.position).font(.caption2).foregroundStyle(.secondary).frame(width: 24, alignment: .leading)
            Text(line.name).font(.caption).lineLimit(1).truncationMode(.tail)
            Spacer(minLength: 2)
            Text(ScoreDisplay.points(line.points)).font(.caption.monospacedDigit())
            StatusIndicator(status: line.status)
        }
        .opacity(line.status == .pending ? 0.7 : 1)
        .accessibilityElement(children: .combine)
    }
}

private struct StatusIndicator: View {
    let status: PlayStatus
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    var body: some View {
        Group {
            switch status {
            case .pending:
                Image(systemName: "circle").foregroundStyle(.secondary)
                    .accessibilityLabel("Pendiente")
            case .playing:
                Image(systemName: "circle.fill").foregroundStyle(.secondary)
                    .opacity(pulse ? 1 : 0.4)
                    .accessibilityLabel("Jugando")
                    .onAppear {
                        guard !reduceMotion else { return }
                        withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                            pulse = true
                        }
                    }
            case .done:
                Image(systemName: "checkmark").foregroundStyle(.secondary)
                    .accessibilityLabel("Terminado")
            case .unknown:
                Text("\u{2013}").foregroundStyle(.secondary)
                    .accessibilityLabel("Sin datos")
            }
        }
        .font(.caption2)
        .frame(width: 12)
    }
}

#if canImport(SleeperKitMocks)
import SleeperKitMocks

#Preview("Expandida · en vivo") {
    let model = NotchModel()
    model.snapshot = .previewLive
    return ExpandedNotchView(model: model).background(.black)
}

#Preview("Expandida · desactualizado") {
    let model = NotchModel()
    model.snapshot = .previewStale
    return ExpandedNotchView(model: model).background(.black)
}

#Preview("Expandida · bye") {
    let model = NotchModel()
    model.snapshot = .previewBye
    return ExpandedNotchView(model: model).background(.black)
}
#endif
