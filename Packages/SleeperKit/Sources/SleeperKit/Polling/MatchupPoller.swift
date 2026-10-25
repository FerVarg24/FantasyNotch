import Foundation
import os

/// Refresca el matchup del usuario y publica `MatchupSnapshot` con una cadencia adaptativa (ADR 0003).
///
/// - Cadencia por `PollingMode`; nunca dos llamadas a `/matchups` con menos de 15 s entre sí.
/// - Ante cualquier error: backoff ×2 con tope de 5 min (sin acortar nunca el intervalo normal) y, tras
///   2 refrescos fallidos seguidos, el último snapshot se reemite con `isStale = true`.
/// - `pause()`/`resume()` los llama quien conozca el sueño y el bloqueo de pantalla (FN-011); el poller no importa AppKit.
/// - `snapshots` conserva solo el último valor sin consumir. Quien lo use debe llamar a `stop()` al terminar.
public actor MatchupPoller {
    private enum State { case idle, running, paused, stopped }

    private struct SlowData {
        let week: Int
        let rosters: [Roster]
        let leagueUsers: [LeagueUser]
        let players: [String: Player]
        let fetchedAt: Date
    }

    public nonisolated let snapshots: AsyncStream<MatchupSnapshot>
    private let continuation: AsyncStream<MatchupSnapshot>.Continuation

    private let api: any SleeperAPI
    private let leagueId: String
    private let userId: String
    private let resolver: any MatchupResolving
    private let gameWindow: any GameWindowProviding
    private let players: @Sendable () async throws -> [String: Player]
    private let clock: any PollingClock

    private var state = State.idle
    private var generation = 0
    private var loop: Task<Void, Never>?
    private var delayTask: Task<Void, Error>?

    private var mode = PollingMode.gameDay
    private var teamStates: [String: TeamPlayState] = [:]
    private var slow: SlowData?
    private var lastMatchupsCall: Date?
    private var lastSnapshot: MatchupSnapshot?
    private var consecutiveFailures = 0

    #if DEBUG
        private static let logger = Logger(subsystem: "com.fervarg.FantasyNotch", category: "poller")
    #endif

    /// - Parameter players: normalmente `{ try await cache.players(using: api) }` (FN-006: máx. 1 descarga al día).
    public init(
        api: any SleeperAPI,
        leagueId: String,
        userId: String,
        resolver: any MatchupResolving,
        gameWindow: any GameWindowProviding,
        players: @escaping @Sendable () async throws -> [String: Player],
        clock: any PollingClock = SystemPollingClock()
    ) {
        (snapshots, continuation) = AsyncStream.makeStream(
            of: MatchupSnapshot.self, bufferingPolicy: .bufferingNewest(1))
        self.api = api
        self.leagueId = leagueId
        self.userId = userId
        self.resolver = resolver
        self.gameWindow = gameWindow
        self.players = players
        self.clock = clock
    }

    // MARK: - Ciclo de vida

    /// Empieza a refrescar de inmediato. No hace nada si ya está en marcha o terminó.
    public func start() {
        guard state == .idle else { return }
        state = .running
        launchLoop()
    }

    /// Detiene todas las llamadas hasta `resume()`.
    public func pause() {
        guard state == .running else { return }
        state = .paused
        invalidateLoop()
    }

    /// Vuelve a refrescar de inmediato (respetando el mínimo de 60 s desde la última llamada a `/matchups`).
    public func resume() {
        guard state == .paused else { return }
        state = .running
        launchLoop()
    }

    /// Adelanta el próximo refresco. Si ya hay uno en curso o en espera del mínimo de 60 s, no hace nada.
    public func refreshNow() {
        guard state == .running else { return }
        delayTask?.cancel()
    }

    /// Termina el stream y cancela el bucle. No se puede reanudar.
    public func stop() {
        guard state != .stopped else { return }
        state = .stopped
        invalidateLoop()
        continuation.finish()
    }

    // MARK: - Bucle

    private func launchLoop() {
        generation += 1
        let id = generation
        loop = Task { [weak self] in
            await self?.run(generation: id)
        }
    }

    private func invalidateLoop() {
        generation += 1
        loop?.cancel()
        loop = nil
        delayTask?.cancel()
        delayTask = nil
    }

    private func isCurrent(_ id: Int) -> Bool {
        state == .running && generation == id && !Task.isCancelled
    }

    private func run(generation id: Int) async {
        while isCurrent(id) {
            await refresh()
            guard isCurrent(id) else { return }
            await sleepUntilNextRefresh()
        }
    }

    /// Espera el intervalo del modo actual. `refreshNow()` la corta cancelando solo esta espera.
    private func sleepUntilNextRefresh() async {
        let delay = nextDelay()
        let clock = self.clock
        let task = Task { try await clock.sleep(for: delay) }
        delayTask = task
        // La espera es una `Task` no estructurada: sin el manejador, cancelar el bucle no la cancelaría.
        _ = try? await withTaskCancellationHandler {
            try await task.value
        } onCancel: {
            task.cancel()
        }
        // Tras `pause()` + `resume()` otro bucle puede haber guardado ya su propia espera: solo se limpia la propia.
        if delayTask == task { delayTask = nil }
    }

    /// Intervalo normal del modo; con fallos, ×2 por fallo con tope de 5 min, sin bajar nunca del intervalo normal.
    private func nextDelay() -> Duration {
        let base = mode.interval.timeInterval
        guard consecutiveFailures > 0 else { return mode.interval }
        let backoff = min(base * pow(2, Double(consecutiveFailures)), PollingPolicy.maxBackoff.timeInterval)
        return .seconds(max(base, backoff))
    }

    // MARK: - Refresco

    private func refresh() async {
        do {
            try await refreshSlowDataIfNeeded()
            try Task.checkCancellation()  // un `pause()` durante la descarga no debe seguir llamando
            guard let slow else { return }
            await updateGameWindow(week: slow.week)
            try await acquireMatchupSlot()
            try Task.checkCancellation()
            let matchups = try await api.matchups(leagueId: leagueId, week: slow.week)
            let input = MatchupInput(
                week: slow.week, userId: userId, rosters: slow.rosters, leagueUsers: slow.leagueUsers,
                matchups: matchups, players: slow.players, teamStates: teamStates)
            let resolved = try resolver.resolve(input)
            consecutiveFailures = 0
            if let resolved { publish(resolved) }
        } catch is CancellationError {
            // Pausa o parada: no es un fallo.
        } catch {
            registerFailure()
        }
    }

    /// Semana, rosters, usuarios y jugadores cambian despacio: se piden cada 30 min, no en cada tick.
    private func refreshSlowDataIfNeeded() async throws {
        let now = clock.now()
        if let slow, now.timeIntervalSince(slow.fetchedAt) < PollingPolicy.slowRefreshInterval.timeInterval {
            return
        }
        let state = try await api.nflState()
        let rosters = try await api.rosters(leagueId: leagueId)
        let leagueUsers = try await api.leagueUsers(leagueId: leagueId)
        let players = try await players()
        slow = SlowData(
            week: state.week, rosters: rosters, leagueUsers: leagueUsers, players: players, fetchedAt: now)
    }

    /// Si el proveedor falla se conserva el modo anterior: un error de `scores` no debe cambiar la cadencia.
    private func updateGameWindow(week: Int) async {
        guard let window = try? await gameWindow.window(forWeek: week) else { return }
        mode = window.mode
        teamStates = window.teamStates
    }

    /// Reserva el derecho a llamar a `/matchups`. Comprobar y reservar ocurren sin suspensión de por medio,
    /// así que dos refrescos solapados (p. ej. tras `pause()` + `resume()`) no pueden llamar a la vez.
    private func acquireMatchupSlot() async throws {
        let gap = PollingPolicy.minimumMatchupGap.timeInterval
        while true {
            let now = clock.now()
            if let last = lastMatchupsCall {
                let remaining = last.addingTimeInterval(gap).timeIntervalSince(now)
                if remaining > 0 {
                    try await clock.sleep(for: .seconds(remaining))
                    continue
                }
            }
            lastMatchupsCall = now
            return
        }
    }

    private func publish(_ resolved: MatchupSnapshot) {
        let snapshot = MatchupSnapshot(
            week: resolved.week, me: resolved.me, opponent: resolved.opponent,
            fetchedAt: clock.now(), isStale: false)
        logPointChange(from: lastSnapshot, to: snapshot)
        lastSnapshot = snapshot
        continuation.yield(snapshot)
    }

    private func registerFailure() {
        consecutiveFailures += 1
        guard consecutiveFailures == PollingPolicy.staleAfterFailures, let last = lastSnapshot else { return }
        let stale = MatchupSnapshot(
            week: last.week, me: last.me, opponent: last.opponent, fetchedAt: last.fetchedAt, isStale: true)
        lastSnapshot = stale
        continuation.yield(stale)
    }

    /// Mide la frescura real: el instante en que cambian los puntos respecto al snapshot anterior (solo en debug).
    private func logPointChange(from previous: MatchupSnapshot?, to current: MatchupSnapshot) {
        #if DEBUG
            guard let previous else { return }
            let mine = previous.me.points != current.me.points
            let theirs = previous.opponent?.points != current.opponent?.points
            guard mine || theirs else { return }
            Self.logger.debug(
                "points changed at \(self.clock.now().timeIntervalSince1970, privacy: .public) mine=\(mine, privacy: .public) opponent=\(theirs, privacy: .public)"
            )
        #endif
    }
}
