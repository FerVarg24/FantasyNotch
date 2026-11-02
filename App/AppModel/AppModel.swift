import AppKit
import Observation
import SleeperKit
#if DEBUG
    import os
#endif

/// Une las piezas: onboarding → poller → notch y título de la barra de menús, con pausa por sueño y bloqueo.
///
/// Se crea una sola vez y arranca desde `applicationDidFinishLaunching` (`start()`): el contenido del
/// `MenuBarExtra` solo se evalúa al abrir el menú, así que no sirve para arrancar.
@MainActor
@Observable
final class AppModel {
    /// Último marcador recibido de la liga activa; `nil` hasta el primer refresco o tras cambiar de liga.
    private(set) var snapshot: MatchupSnapshot?
    private(set) var hasNotch: Bool

    @ObservationIgnored let launchAtLogin = LaunchAtLoginModel()

    #if DEBUG
        private static let logger = Logger(subsystem: "com.fervarg.FantasyNotch", category: "app")
    #endif

    @ObservationIgnored private let api: any SleeperAPI
    @ObservationIgnored private let scores: any ScoresProviding
    @ObservationIgnored private let playerCache: PlayerCache
    @ObservationIgnored private let store: any SettingsStoring
    @ObservationIgnored private let onboarding: OnboardingViewModel
    @ObservationIgnored private let notch = NotchController()
    @ObservationIgnored private var onboardingWindow: OnboardingWindowController?
    @ObservationIgnored private var systemEvents: SystemEventsObserver?

    @ObservationIgnored private var poller: MatchupPoller?
    @ObservationIgnored private var consumer: Task<Void, Never>?
    /// Distingue el poller actual de uno anterior: `bufferingNewest(1)` puede entregar un snapshot tardío.
    @ObservationIgnored private var generation = 0
    /// Un poller creado mientras el Mac duerme o está bloqueado no arranca hasta que vuelva.
    @ObservationIgnored private var pollerNeedsStart = false

    init(
        api: any SleeperAPI = LiveSleeperAPI(),
        scores: any ScoresProviding = ScoresClient(),
        playerCache: PlayerCache = PlayerCache(),
        store: any SettingsStoring = UserDefaultsSettingsStore()
    ) {
        self.api = api
        self.scores = scores
        self.playerCache = playerCache
        self.store = store
        onboarding = OnboardingViewModel(api: api, store: store)
        hasNotch = ScreenInfo.menuBarScreenHasNotch
    }

    /// Texto de la barra de menús: `nil` = solo icono (con notch, el marcador va junto al notch).
    var menuBarTitle: String? { MenuBarScoreTitle.text(for: snapshot, hasNotch: hasNotch) }

    // MARK: - Arranque

    func start() {
        guard systemEvents == nil else { return }
        onboarding.onConfigured = { [weak self] userId, leagueId in
            self?.onboardingWindow?.close()
            self?.startPolling(userId: userId, leagueId: leagueId)
        }
        onboardingWindow = OnboardingWindowController(model: onboarding) { [weak self] in
            self?.onboardingClosedByUser()
        }
        let events = SystemEventsObserver(
            onPauseAction: { [weak self] action in self?.apply(action) },
            onScreensChanged: { [weak self] in self?.screensChanged() })
        events.start()
        systemEvents = events

        switch AppPhase(store: store) {
        case .onboarding: onboardingWindow?.show()
        case .running(let userId, let leagueId): startPolling(userId: userId, leagueId: leagueId)
        }
    }

    // MARK: - Acciones del menú

    func refreshNow() {
        guard let poller else { return }
        Task { await poller.refreshNow() }
    }

    /// «Cambiar de liga…»: lista las ligas del usuario guardado (o pide el usuario si no hay ninguno).
    func changeLeague() {
        onboardingWindow?.show()
        Task { await onboarding.changeLeague() }
    }

    // MARK: - Poller

    private func startPolling(userId: String, leagueId: String) {
        stopPolling()
        generation += 1
        let id = generation

        let api = self.api
        let cache = playerCache
        let poller = MatchupPoller(
            api: api,
            leagueId: leagueId,
            userId: userId,
            resolver: MatchupResolverBridge(),
            gameWindow: SeasonedGameWindow(scores: scores, season: { try await api.nflState().season }),
            players: { try await cache.players(using: api) })
        self.poller = poller

        consumer = Task { [weak self] in
            for await snapshot in poller.snapshots {
                guard let self, self.generation == id else { return }
                self.receive(snapshot)
            }
        }

        let bornPaused = systemEvents?.isPaused == true
        #if DEBUG
            Self.logger.debug("poller created, born paused=\(bornPaused, privacy: .public)")
        #endif
        if bornPaused {
            pollerNeedsStart = true
        } else {
            Task { await poller.start() }
        }
    }

    /// Para el poller anterior y olvida su marcador, para no mostrar el de la liga previa.
    private func stopPolling() {
        consumer?.cancel()
        consumer = nil
        if let old = poller { Task { await old.stop() } }
        poller = nil
        pollerNeedsStart = false
        snapshot = nil
        notch.close()
    }

    private func receive(_ snapshot: MatchupSnapshot) {
        self.snapshot = snapshot
        if hasNotch { notch.show(snapshot) }
    }

    private func apply(_ action: PauseReasons.Action) {
        guard let poller else { return }
        switch action {
        case .pause:
            Task { await poller.pause() }
        case .resume:
            if pollerNeedsStart {
                pollerNeedsStart = false
                Task { await poller.start() }
            } else {
                Task { await poller.resume() }
            }
        }
    }

    // MARK: - Pantallas y ventana

    /// Conectar o desconectar un monitor puede cambiar qué pantalla es la de la barra de menús. Se cierra el notch y
    /// se vuelve a abrir (si hay notch) para que no quede un estado «compacto» sin ventana (spike FN-004, riesgo 1).
    private func screensChanged() {
        hasNotch = ScreenInfo.menuBarScreenHasNotch
        #if DEBUG
            Self.logger.debug("screens changed, hasNotch=\(self.hasNotch, privacy: .public)")
        #endif
        notch.close()
        if hasNotch, let snapshot { notch.show(snapshot) }
    }

    /// Cerrar la ventana a mitad de un cambio de liga conserva la liga actual.
    private func onboardingClosedByUser() {
        onboarding.cancelLeagueChange()
    }
}
