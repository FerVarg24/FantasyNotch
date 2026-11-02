import Foundation
import Testing

@testable import SleeperKit
@testable import SleeperKitMocks

@Suite("Integración: piezas puras que usa AppModel")
struct IntegrationTests {
    // MARK: - Fase de arranque

    @MainActor
    private static func store(user: String?, league: String?, version: Int? = SettingsKeys.currentVersion)
        -> InMemorySettingsStore
    {
        let store = InMemorySettingsStore()
        store.userId = user
        store.leagueId = league
        store.settingsVersion = version
        return store
    }

    @Test("Sin leagueId el estado es .onboarding; con usuario y liga arranca el poller")
    @MainActor
    func phaseFromSettings() {
        #expect(AppPhase(store: Self.store(user: "U1", league: nil)) == .onboarding)
        #expect(AppPhase(store: Self.store(user: nil, league: "L1")) == .onboarding)
        #expect(AppPhase(store: Self.store(user: "U1", league: "")) == .onboarding)
        #expect(AppPhase(store: Self.store(user: "U1", league: "L1", version: 99)) == .onboarding)
        #expect(AppPhase(store: Self.store(user: "U1", league: "L1")) == .running(userId: "U1", leagueId: "L1"))
    }

    // MARK: - Puente MatchupResolving

    private static func input(
        _ scenario: MockSleeperAPI.Scenario, userId: String, teamStates: [String: TeamPlayState] = [:]
    ) async throws -> MatchupInput {
        let api = MockSleeperAPI(scenario: scenario)
        let players = try await api.players().mapValues {
            Player(playerId: $0.playerId, fullName: $0.fullName, position: $0.position, team: $0.team)
        }
        return MatchupInput(
            week: 1, userId: userId, rosters: try await api.rosters(leagueId: "x"),
            leagueUsers: try await api.leagueUsers(leagueId: "x"),
            matchups: try await api.matchups(leagueId: "x", week: 1), players: players, teamStates: teamStates)
    }

    @Test("El puente traduce TeamPlayState a PlayStatus de cada titular")
    func bridgeMapsTeamStates() async throws {
        let userId = "900000000000000001"
        let base = try await Self.input(.live, userId: userId)
        let teams = Set(base.players.values.compactMap(\.team))
        let allPlaying = try await Self.input(
            .live, userId: userId, teamStates: Dictionary(uniqueKeysWithValues: teams.map { ($0, .inProgress) }))

        let without = try #require(try MatchupResolverBridge().resolve(base))
        let with = try #require(try MatchupResolverBridge().resolve(allPlaying))
        #expect(!without.me.starters.contains { $0.status == .playing })
        #expect(with.me.starters.contains { $0.status == .playing })
    }

    @Test("Un usuario sin roster en la liga lanza (cuenta como fallo del poller)")
    func bridgeThrowsForUnknownUser() async throws {
        let input = try await Self.input(.final, userId: "no-existe")
        #expect(throws: MatchupResolverError.rosterNotFound) { try MatchupResolverBridge().resolve(input) }
    }

    @Test("Semana sin datos devuelve nil (ni se emite ni hay backoff)")
    func bridgeReturnsNilForEmptyWeek() async throws {
        let input = try await Self.input(.empty, userId: "900000000000000001")
        #expect(try MatchupResolverBridge().resolve(input) == nil)
    }

    // MARK: - Razones de pausa

    @Test("Dormir y bloquear se combinan: despertar con la pantalla bloqueada no reanuda")
    func wakeWhileLockedStaysPaused() {
        var reasons = PauseReasons()
        #expect(reasons.set(.screenLocked, active: true) == .pause)
        #expect(reasons.set(.systemSleep, active: true) == nil)
        #expect(reasons.set(.systemSleep, active: false) == nil, "sigue bloqueado")
        #expect(reasons.set(.screenLocked, active: false) == .resume)
    }

    @Test("Repetir la misma razón no emite una segunda acción")
    func repeatedReasonIsIdempotent() {
        var reasons = PauseReasons()
        #expect(reasons.set(.systemSleep, active: true) == .pause)
        #expect(reasons.set(.systemSleep, active: true) == nil)
        #expect(reasons.set(.systemSleep, active: false) == .resume)
        #expect(reasons.set(.systemSleep, active: false) == nil)
        #expect(!reasons.isPaused)
    }

    // MARK: - Título de la barra de menús

    @Test("Sin notch el marcador va en la barra de menús; con notch solo el icono")
    func menuBarTitle() {
        #expect(MenuBarTitle.text(for: .previewLive, hasNotch: false) == ScoreDisplay.compactText(for: .previewLive))
        #expect(MenuBarTitle.text(for: .previewLive, hasNotch: true) == nil)
        #expect(MenuBarTitle.text(for: nil, hasNotch: false) == nil)
    }

    @Test("Bye y datos viejos tampoco dependen solo del color")
    func menuBarTitleStatesHaveText() {
        #expect(MenuBarTitle.text(for: .previewBye, hasNotch: false) == "Sin matchup")
        #expect(MenuBarTitle.text(for: .previewStale, hasNotch: false)?.hasPrefix("⚠︎ ") == true)
    }

    // MARK: - Proveedor de ventana con temporada diferida

    private struct FakeScores: ScoresProviding {
        let seasons: SeasonLog
        func games(season: String, week: Int) async throws -> [ScoreGame] {
            await seasons.record(season)
            return []
        }
    }

    private actor SeasonLog {
        private(set) var requested: [String] = []
        private(set) var lookups = 0
        func record(_ season: String) { requested.append(season) }
        func lookup() { lookups += 1 }
    }

    @Test("La temporada se pide una vez y se reutiliza; si falla, lanza y se reintenta en la siguiente consulta")
    func seasonIsMemoizedOnlyOnSuccess() async throws {
        let log = SeasonLog()
        let failures = FailuresLeft(1)
        let window = SeasonedGameWindow(
            scores: FakeScores(seasons: log),
            season: {
                await log.lookup()
                if await failures.take() { throw SleeperAPIError.network(detail: "offline") }
                return "2026"
            })

        await #expect(throws: SleeperAPIError.self) { try await window.window(forWeek: 7) }
        #expect(await log.requested.isEmpty, "sin temporada no se consulta scores")
        _ = try await window.window(forWeek: 7)
        _ = try await window.window(forWeek: 7)
        #expect(await log.lookups == 2, "un fallo y un éxito; después se reutiliza")
        #expect(await log.requested == ["2026", "2026"])
    }

    private actor FailuresLeft {
        private var left: Int
        init(_ left: Int) { self.left = left }
        func take() -> Bool {
            guard left > 0 else { return false }
            left -= 1
            return true
        }
    }
}
