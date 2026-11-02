/// En qué fase arranca la app: pedir la liga (onboarding) o refrescar el marcador.
public enum AppPhase: Sendable, Equatable {
    case onboarding
    case running(userId: String, leagueId: String)

    /// Se decide solo por los ajustes guardados (`SettingsStoring.isConfigured`): sin usuario, sin liga o con una
    /// versión de ajustes desconocida se vuelve al onboarding.
    @MainActor
    public init(store: any SettingsStoring) {
        if store.isConfigured, let userId = store.userId, let leagueId = store.leagueId {
            self = .running(userId: userId, leagueId: leagueId)
        } else {
            self = .onboarding
        }
    }
}
