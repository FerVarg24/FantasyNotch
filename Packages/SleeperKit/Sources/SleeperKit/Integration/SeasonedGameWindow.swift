import Foundation

/// `GameWindowProviding` que averigua la temporada al primer uso, en vez de fijarla al construirlo.
///
/// `ScoresGameWindow` necesita la temporada al crearse, pero arrancar la app (por ejemplo al iniciar sesión, sin
/// red) puede ocurrir antes de poder leer `nflState`. Aquí, si la temporada no está disponible, se lanza el error:
/// el poller lo cuenta como fallo del proveedor (backoff y bajada de `.live`, FN-018) y se reintenta en la siguiente
/// consulta. Una vez obtenida se reutiliza. No hay respaldo que oculte el error a propósito.
public actor SeasonedGameWindow: GameWindowProviding {
    private let scores: any ScoresProviding
    private let clock: any PollingClock
    private let loadSeason: @Sendable () async throws -> String
    private var resolved: ScoresGameWindow?

    public init(
        scores: any ScoresProviding,
        clock: any PollingClock = SystemPollingClock(),
        season: @escaping @Sendable () async throws -> String
    ) {
        self.scores = scores
        self.clock = clock
        loadSeason = season
    }

    public func window(forWeek week: Int) async throws -> GameWindow {
        if let resolved { return try await resolved.window(forWeek: week) }
        let provider = ScoresGameWindow(scores: scores, season: try await loadSeason(), clock: clock)
        resolved = provider
        return try await provider.window(forWeek: week)
    }
}
