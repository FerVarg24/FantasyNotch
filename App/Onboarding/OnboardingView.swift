import SleeperKit
import SwiftUI

extension OnboardingViewModel.Failure {
    /// Texto inline del error. No dice nada del usuario salvo lo que él mismo escribió.
    var message: LocalizedStringKey {
        switch self {
        case .emptyUsername: "Escribe tu usuario de Sleeper."
        case .userNotFound: "No encontramos ese usuario en Sleeper. Revisa que esté bien escrito."
        case .network: "No pudimos conectar con Sleeper. Revisa tu conexión e inténtalo de nuevo."
        case .noLeagues: "Ese usuario no tiene ligas de NFL esta temporada."
        case .unexpected: "Sleeper respondió algo que no entendemos. Inténtalo más tarde."
        }
    }
}

/// Onboarding: usuario de Sleeper → lista de ligas → elegir una. Los errores salen inline y el flujo sigue abierto.
struct OnboardingView: View {
    @Bindable var model: OnboardingViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            switch model.phase {
            case .enterUsername, .loading:
                usernameStep
            case .pickLeague(let leagues):
                leagueStep(leagues)
            case .done:
                Label("Liga configurada", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }

            if let failure = model.failure {
                // Icono + texto: el color no es la única señal (DESIGN.md §Colores).
                Label(failure.message, systemImage: "exclamationmark.triangle.fill")
                    .font(.callout)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel(Text(failure.message))
            }
        }
        .padding(20)
        .frame(width: 360)
    }

    private var isLoading: Bool { model.phase == .loading }

    private var usernameStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Conecta tu liga")
                .font(.headline)
            Text("Escribe tu usuario de Sleeper para ver tu marcador en el notch.")
                .font(.callout)
                .foregroundStyle(.secondary)

            TextField("Usuario de Sleeper", text: $model.username)
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled()
                .disabled(isLoading)
                .onSubmit { Task { await model.submit() } }

            HStack {
                if isLoading { ProgressView().controlSize(.small) }
                Spacer()
                Button("Continuar") { Task { await model.submit() } }
                    .keyboardShortcut(.defaultAction)
                    .disabled(isLoading)
            }
        }
    }

    private func leagueStep(_ leagues: [League]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Elige tu liga")
                .font(.headline)

            VStack(spacing: 6) {
                ForEach(leagues, id: \.leagueId) { league in
                    Button {
                        model.select(league)
                    } label: {
                        HStack {
                            Text(league.name)
                            Spacer()
                            Image(systemName: "chevron.right").foregroundStyle(.secondary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.bordered)
                    .accessibilityHint(Text("Muestra el marcador de esta liga en el notch"))
                }
            }

            HStack {
                Spacer()
                Button("Cancelar") { model.cancelLeagueChange() }
            }
        }
    }
}

#if canImport(SleeperKitMocks)
import SleeperKitMocks

#Preview("Onboarding · usuario") {
    OnboardingView(model: OnboardingViewModel(api: MockSleeperAPI(), store: InMemorySettingsStore()))
}

#Preview("Onboarding · elegir liga") {
    let model = OnboardingViewModel(api: MockSleeperAPI(), store: InMemorySettingsStore())
    model.username = "manager_1"
    Task { await model.submit() }
    return OnboardingView(model: model)
}
#endif
