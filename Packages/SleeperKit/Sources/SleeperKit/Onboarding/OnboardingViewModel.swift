import Foundation
import Observation

/// Lógica del onboarding: username → ligas NFL de la temporada actual → elegir una.
///
/// Los errores son valores (`Failure`), nunca excepciones: la vista los muestra inline y el flujo sigue abierto.
/// Nada se guarda hasta que se elige liga, y entonces se escriben las cuatro claves juntas.
@MainActor
@Observable
public final class OnboardingViewModel {
    public enum Phase: Equatable {
        case enterUsername
        case loading
        case pickLeague([League])
        /// Hay liga configurada.
        case done
    }

    public enum Failure: Error, Equatable, Sendable {
        case emptyUsername
        case userNotFound
        /// Sin conexión, límite de llamadas o servidor de Sleeper caído: reintentar suele bastar.
        case network
        case noLeagues
        /// Respuesta con una forma que la app no entiende.
        case unexpected
    }

    public var username = ""
    public private(set) var phase: Phase
    public private(set) var failure: Failure?

    /// Se llama una vez cada vez que se elige liga (onboarding o cambio de liga), después de guardar. No se llama
    /// si el cambio falla, no hay ligas o se cancela: así quien lo use (FN-011) sabe cuándo reiniciar el poller.
    @ObservationIgnored public var onConfigured: (@MainActor (_ userId: String, _ leagueId: String) -> Void)?

    @ObservationIgnored private let api: any SleeperAPI
    @ObservationIgnored private let store: any SettingsStoring
    /// Usuario cuyas ligas se están mostrando; se guarda al elegir liga.
    @ObservationIgnored private var candidate: (userId: String, username: String)?

    public init(api: any SleeperAPI, store: any SettingsStoring) {
        self.api = api
        self.store = store
        phase = store.isConfigured ? .done : .enterUsername
    }

    /// Resuelve el username escrito y lista sus ligas. Se ignora si ya hay una consulta en curso.
    public func submit() async {
        guard phase != .loading else { return }
        let name = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            failure = .emptyUsername
            return
        }
        let before = phase
        failure = nil
        phase = .loading

        let user: SleeperUser
        do {
            user = try await api.user(username: name)
        } catch {
            return abort(error, userStep: true, back: .enterUsername, previous: before)
        }
        do {
            let leagues = try await loadLeagues(userId: user.userId)
            guard !leagues.isEmpty else {
                failure = .noLeagues
                phase = .enterUsername
                return
            }
            candidate = (user.userId, user.username ?? name)
            phase = .pickLeague(leagues)
        } catch {
            abort(error, userStep: false, back: .enterUsername, previous: before)
        }
    }

    /// Guarda usuario y liga y termina el onboarding. Solo vale mientras se muestra la lista de ligas.
    public func select(_ league: League) {
        guard case .pickLeague = phase, let candidate else { return }
        store.save(userId: candidate.userId, username: candidate.username, leagueId: league.leagueId)
        self.candidate = nil
        failure = nil
        phase = .done
        onConfigured?(candidate.userId, league.leagueId)
    }

    /// Menú «cambiar de liga»: vuelve a listar las ligas del usuario guardado, sin pedir el username otra vez.
    /// Si falla se conserva la liga actual.
    public func changeLeague() async {
        guard phase != .loading else { return }
        guard let userId = store.userId, !userId.isEmpty else {
            phase = .enterUsername
            return
        }
        let before = phase
        failure = nil
        phase = .loading
        do {
            let leagues = try await loadLeagues(userId: userId)
            guard !leagues.isEmpty else {
                failure = .noLeagues
                phase = .done
                return
            }
            candidate = (userId, store.username ?? "")
            phase = .pickLeague(leagues)
        } catch {
            abort(error, userStep: false, back: .done, previous: before)
        }
    }

    /// Abandona la lista de ligas sin tocar lo guardado.
    public func cancelLeagueChange() {
        candidate = nil
        failure = nil
        phase = store.isConfigured ? .done : .enterUsername
    }

    // MARK: - Piezas

    private func loadLeagues(userId: String) async throws -> [League] {
        let state = try await api.nflState()
        let season = state.leagueSeason.flatMap { $0.isEmpty ? nil : $0 } ?? state.season
        return try await api.leagues(userId: userId, season: season)
    }

    /// Una tarea cancelada vuelve a la fase anterior sin error; el resto se convierte en `Failure`.
    private func abort(_ error: Error, userStep: Bool, back: Phase, previous: Phase) {
        if error is CancellationError {
            phase = previous
            return
        }
        failure = Self.failure(for: error, userStep: userStep)
        phase = back
    }

    private static func failure(for error: Error, userStep: Bool) -> Failure {
        guard let error = error as? SleeperAPIError else { return .unexpected }
        switch error {
        case .notFound, .invalidRequest:
            // Un username con caracteres inválidos tampoco existe para el usuario.
            return userStep ? .userNotFound : .unexpected
        case .network, .rateLimited, .server, .badStatus, .responseTooLarge:
            return .network
        case .decoding:
            return .unexpected
        }
    }
}
