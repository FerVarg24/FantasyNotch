import Foundation
import Testing

@testable import SleeperKit
@testable import SleeperKitMocks

/// Todos los tiempos salen de `FakeClock`: ningún test espera tiempo real, salvo una pausa de 50 ms en las
/// aserciones negativas ("no hay más llamadas"), que solo pueden dar un falso verde, nunca un falso rojo.
@Suite("MatchupPoller", .timeLimit(.minutes(1)))
struct MatchupPollerTests {
    struct Harness {
        let clock = FakeClock()
        let api: SpyAPI
        let window: FakeGameWindow
        let resolver: FakeResolver
        let poller: MatchupPoller
        let origin: Date

        init(
            mode: PollingMode = .live,
            resolver outcome: FakeResolver.Outcome = .snapshot,
            teamStates: [String: TeamPlayState] = [:],
            behavior: SpyAPI.MatchupsBehavior? = nil,
            players: @escaping @Sendable () async throws -> [String: Player] = { [:] }
        ) {
            let clock = self.clock
            api = behavior.map { SpyAPI(clock: clock, behavior: $0) } ?? SpyAPI(clock: clock)
            window = FakeGameWindow(mode, teamStates: teamStates)
            resolver = FakeResolver(outcome)
            origin = clock.now()
            poller = MatchupPoller(
                api: api, leagueId: "L1", userId: "U1", resolver: resolver, gameWindow: window,
                players: players, clock: clock)
        }

        /// Avanza el reloj y espera a que el bucle vuelva a quedar dormido.
        func tick(_ seconds: TimeInterval) async {
            clock.advance(by: seconds)
            await clock.untilSleeping()
        }

        func startAndSettle() async {
            await poller.start()
            await clock.untilSleeping()
        }
    }

    // MARK: - Intervalos (ADR 0003)

    @Test("En vivo: dos ticks a 60 s = dos llamadas a /matchups")
    func liveTwoTicksTwoCalls() async {
        let h = Harness(mode: .live)
        await h.startAndSettle()
        #expect(h.api.matchupsCalls == 1)
        await h.tick(60)
        #expect(h.api.matchupsCalls == 2)
        await h.poller.stop()
    }

    @Test("Intervalo por modo: ni un segundo antes, y llamada exacta al cumplirse",
        arguments: [(PollingMode.live, 60.0), (.gameDay, 300.0), (.idle, 1800.0)])
    func intervalPerMode(mode: PollingMode, interval: TimeInterval) async {
        let h = Harness(mode: mode)
        await h.startAndSettle()
        await h.tick(interval - 1)
        #expect(h.api.matchupsCalls == 1)
        await h.tick(1)
        #expect(h.api.matchupsCalls == 2)
        await h.poller.stop()
    }

    @Test("Cada refresco emite un snapshot con fetchedAt del reloj inyectado y isStale en false")
    func emitsSnapshotOnEveryRefresh() async {
        let h = Harness(mode: .live)
        var iterator = h.poller.snapshots.makeAsyncIterator()
        await h.startAndSettle()
        let first = await iterator.next()
        #expect(first?.fetchedAt == h.origin)
        #expect(first?.isStale == false)
        await h.tick(60)
        let second = await iterator.next()
        #expect(second?.fetchedAt == h.origin.addingTimeInterval(60))
        await h.poller.stop()
    }

    // MARK: - Mínimo de 60 s entre llamadas a /matchups

    @Test("Dos refreshNow() seguidos no producen dos llamadas con menos de 60 s")
    func refreshNowRespectsFloor() async {
        let h = Harness(mode: .gameDay)
        await h.startAndSettle()
        await h.poller.refreshNow()
        await h.clock.untilSleeping()
        await h.poller.refreshNow()
        #expect(h.api.matchupsCalls == 1)
        await h.tick(59)
        #expect(h.api.matchupsCalls == 1)
        await h.tick(1)
        #expect(h.api.matchupsCalls == 2)
        #expect(h.api.matchupGaps(since: h.origin) == [0, 60])
        await h.poller.stop()
    }

    @Test("resume() justo después de una llamada espera hasta completar los 60 s")
    func resumeRespectsFloor() async {
        let h = Harness(mode: .gameDay)
        await h.startAndSettle()
        h.clock.advance(by: 3)
        await h.poller.pause()
        await h.poller.resume()
        await h.clock.untilSleeping()
        #expect(h.api.matchupsCalls == 1)
        await h.tick(57)
        #expect(h.api.matchupsCalls == 2)
        await h.poller.stop()
    }

    // MARK: - Backoff e isStale

    @Test("Ante 503 el intervalo se duplica y se topa en 300 s")
    func backoffDoublesAndCaps() async {
        let h = Harness(mode: .live, behavior: { _ in throw serverError })
        await h.startAndSettle()
        for delay: TimeInterval in [120, 240, 300, 300, 300] {
            await h.tick(delay)
        }
        #expect(h.api.matchupGaps(since: h.origin) == [0, 120, 240, 300, 300, 300])
        await h.poller.stop()
    }

    @Test("El backoff nunca acorta el intervalo normal: en idle sigue siendo 30 min")
    func backoffNeverShortensIdle() async {
        let h = Harness(mode: .idle, behavior: { index in
            if index == 1 { throw serverError }
            return try SpyAPI.fixtureMatchups()
        })
        await h.startAndSettle()
        await h.tick(1799)
        #expect(h.api.matchupsCalls == 1)
        await h.tick(1)
        #expect(h.api.matchupGaps(since: h.origin) == [0, 1800])
        await h.poller.stop()
    }

    @Test("Tras exactamente 2 fallos se reemite el último snapshot con isStale; un éxito lo limpia")
    func staleAfterTwoFailuresThenRecovers() async {
        let h = Harness(mode: .live, behavior: { index in
            if index == 2 || index == 3 { throw SleeperAPIError.rateLimited }
            return try SpyAPI.fixtureMatchups()
        })
        var iterator = h.poller.snapshots.makeAsyncIterator()
        await h.startAndSettle()
        let good = await iterator.next()
        #expect(good?.isStale == false)

        await h.tick(60)  // fallo 1: todavía no es stale, no se emite nada
        await h.tick(120)  // fallo 2: se reemite el último bueno como stale
        let stale = await iterator.next()
        #expect(stale?.isStale == true)
        #expect(stale?.me == good?.me)

        await h.tick(240)  // éxito
        let recovered = await iterator.next()
        #expect(recovered?.isStale == false)
        await h.poller.stop()
    }

    @Test("Dos fallos sin ningún snapshot previo no emiten nada")
    func noStaleEmissionWithoutSnapshot() async {
        let h = Harness(mode: .live, behavior: { _ in throw serverError })
        var iterator = h.poller.snapshots.makeAsyncIterator()
        await h.startAndSettle()
        await h.tick(120)
        await h.poller.stop()
        #expect(await iterator.next() == nil)
    }

    // MARK: - pause / resume / stop

    @Test("pause(): por mucho que avance el reloj no hay llamadas; resume() refresca de inmediato")
    func pauseStopsAndResumeRefreshesImmediately() async throws {
        let h = Harness(mode: .gameDay)
        await h.startAndSettle()
        await h.poller.pause()
        h.clock.advance(by: 3600)
        try await Task.sleep(for: .milliseconds(50))
        #expect(h.api.matchupsCalls == 1)

        await h.poller.resume()
        await h.clock.untilSleeping()
        #expect(h.api.matchupsCalls == 2)
        await h.poller.stop()
    }

    @Test("pause() con un refresco ya en vuelo: no llega a llamar a /matchups cuando termina el paso pendiente")
    func pauseDuringInFlightRefreshMakesNoMatchupsCall() async throws {
        let gate = Gate()
        let h = Harness(mode: .live, players: {
            await gate.passThrough()
            return [:]
        })
        await h.poller.start()
        await gate.waitUntilEntered()
        await h.poller.pause()
        await gate.release()
        try await Task.sleep(for: .milliseconds(50))
        #expect(h.api.matchupsCalls == 0)
        await h.poller.stop()
    }

    @Test("stop() termina el stream y deja de llamar")
    func stopFinishesStream() async throws {
        let h = Harness(mode: .live)
        var iterator = h.poller.snapshots.makeAsyncIterator()
        await h.startAndSettle()
        _ = await iterator.next()
        await h.poller.stop()
        #expect(await iterator.next() == nil)
        h.clock.advance(by: 3600)
        try await Task.sleep(for: .milliseconds(50))
        #expect(h.api.matchupsCalls == 1)
    }

    // MARK: - Robustez

    @Test("Si el proveedor de ventana de juego falla se conserva el modo anterior")
    func gameWindowFailureKeepsPreviousMode() async {
        let h = Harness(mode: .live)
        await h.startAndSettle()
        h.window.fail()
        await h.tick(60)
        await h.tick(60)
        #expect(h.api.matchupGaps(since: h.origin) == [0, 60, 60])
        await h.poller.stop()
    }

    @Test("Un resolver que devuelve nil no emite ni cuenta como fallo")
    func nilResolutionIsNotAFailure() async {
        let h = Harness(mode: .live, resolver: .none)
        var iterator = h.poller.snapshots.makeAsyncIterator()
        await h.startAndSettle()
        await h.tick(60)
        #expect(h.api.matchupGaps(since: h.origin) == [0, 60])
        await h.poller.stop()
        #expect(await iterator.next() == nil)
    }

    @Test("Un resolver que lanza cuenta como fallo y aplica backoff")
    func resolverFailureBacksOff() async {
        let h = Harness(mode: .live, resolver: .failure)
        await h.startAndSettle()
        await h.tick(120)
        #expect(h.api.matchupGaps(since: h.origin) == [0, 120])
        await h.poller.stop()
    }

    @Test("El resolver recibe semana, usuario, datos crudos y los estados de equipo del proveedor")
    func resolverReceivesInputs() async {
        let states: [String: TeamPlayState] = ["CHI": .inProgress, "GB": .over]
        let h = Harness(mode: .live, teamStates: states)
        await h.startAndSettle()
        let input = h.resolver.lastInput
        #expect(input?.userId == "U1")
        #expect(input?.teamStates == states)
        #expect(input?.matchups.count == 12)
        #expect(input?.rosters.count == 12)
        #expect(input?.leagueUsers.count == 14)
        await h.poller.stop()
    }

    @Test("nflState, rosters y leagueUsers se piden cada 30 min, no en cada tick")
    func slowDataCadence() async {
        let h = Harness(mode: .gameDay)
        await h.startAndSettle()
        for _ in 1...5 { await h.tick(300) }
        #expect(h.api.calls("nflState") == 1)
        #expect(h.api.calls("rosters") == 1)
        #expect(h.api.calls("leagueUsers") == 1)
        await h.tick(300)  // t = 30 min
        #expect(h.api.calls("nflState") == 2)
        #expect(h.api.matchupsCalls == 7)
        await h.poller.stop()
    }
}
