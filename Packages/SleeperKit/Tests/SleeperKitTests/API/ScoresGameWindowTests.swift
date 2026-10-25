import Foundation
import Testing

@testable import SleeperKit

/// `ScoresProviding` de prueba: devuelve partidos fijos o lanza.
private struct FakeScores: ScoresProviding {
    let result: Result<[ScoreGame], Error>

    func games(season: String, week: Int) async throws -> [ScoreGame] {
        try result.get()
    }
}

private struct FixedClock: PollingClock {
    let date: Date
    func now() -> Date { date }
    func sleep(for duration: Duration) async throws {}
}

private let referenceNow = ISO8601DateFormatter().date(from: "2026-10-25T10:00:00Z")!

/// Construye un partido con la forma real de `scores`. Los estados `in_game`/en juego **no se han observado en un
/// partido en vivo real**: estos casos son sintéticos, derivados de la forma de un partido `pre_game`.
private func game(
    _ home: String, _ away: String,
    status: String = "pre_game",
    startsIn hours: Double = 3,
    inProgress: Bool? = false,
    over: Bool? = false,
    started: Bool? = false,
    canceled: Bool? = false
) -> ScoreGame {
    let startMs = Int((referenceNow.timeIntervalSince1970 + hours * 3600) * 1000)
    func flag(_ value: Bool?) -> String { value.map(String.init) ?? "null" }
    let json = """
        {"game_id": "\(home)\(away)", "status": "\(status)", "start_time": \(startMs),
         "metadata": {"home_team": "\(home)", "away_team": "\(away)", "is_in_progress": \(flag(inProgress)),
         "is_over": \(flag(over)), "has_started": \(flag(started)), "canceled": \(flag(canceled))}}
        """
    return try! SleeperDecoder.decode(ScoreGame.self, from: Data(json.utf8))
}

@Suite("ScoresGameWindow")
struct ScoresGameWindowTests {
    private func window(_ games: [ScoreGame]) -> GameWindow {
        ScoresGameWindow.window(from: games, now: referenceNow)
    }

    // MARK: - Modo (spike 003 §2)

    @Test("Un partido con is_in_progress == true → live")
    func inProgressIsLive() {
        #expect(window([game("ARI", "DEN", status: "in_game", inProgress: true, started: true)]).mode == .live)
    }

    @Test("status == in_game sin banderas → live")
    func inGameStatusIsLive() {
        #expect(window([game("ARI", "DEN", status: "in_game", inProgress: nil, over: nil, started: nil)]).mode == .live)
    }

    @Test("Un partido en vivo gana sobre los que no han empezado")
    func liveWinsOverPending() {
        let games = [game("CHI", "GB"), game("ARI", "DEN", inProgress: true, started: true)]
        #expect(window(games).mode == .live)
    }

    @Test("Partido que empieza en menos de 24 h → gameDay")
    func startingSoonIsGameDay() {
        #expect(window([game("ARI", "DEN", startsIn: 3)]).mode == .gameDay)
        #expect(window([game("ARI", "DEN", startsIn: 23.9)]).mode == .gameDay)
    }

    @Test("Partido que empieza en más de 24 h → idle")
    func startingLaterIsIdle() {
        #expect(window([game("ARI", "DEN", startsIn: 24.1)]).mode == .idle)
    }

    @Test("has_started sin is_over (sin confirmar) → gameDay aunque start_time quede lejos")
    func startedAndNotOverIsGameDay() {
        #expect(window([game("ARI", "DEN", status: "pre_game", startsIn: -30, inProgress: false, over: false, started: true)]).mode == .gameDay)
    }

    @Test("Todos los partidos terminados → idle")
    func allCompleteIsIdle() {
        let games = [
            game("ARI", "DEN", status: "complete", startsIn: -50, inProgress: false, over: true, started: true),
            game("CHI", "GB", status: "complete", startsIn: -49, inProgress: false, over: true, started: true),
        ]
        #expect(window(games).mode == .idle)
    }

    @Test("Un partido cancelado se ignora")
    func canceledIsIgnored() {
        #expect(window([game("ARI", "DEN", inProgress: true, started: true, canceled: true)]).mode == .idle)
    }

    @Test("Sin partidos → idle y sin estados de equipo")
    func noGames() {
        let result = window([])
        #expect(result.mode == .idle)
        #expect(result.teamStates.isEmpty)
    }

    // MARK: - Estados por equipo

    @Test("teamStates asigna el estado del partido a ambos equipos, por código")
    func teamStates() {
        let games = [
            game("ARI", "DEN", status: "in_game", inProgress: true, started: true),
            game("CHI", "GB", status: "complete", startsIn: -4, inProgress: false, over: true, started: true),
            game("NE", "MIA", startsIn: 5),
        ]
        #expect(
            window(games).teamStates == [
                "ARI": .inProgress, "DEN": .inProgress,
                "CHI": .over, "GB": .over,
                "NE": .preGame, "MIA": .preGame,
            ])
    }

    @Test("Un equipo cuyo partido está cancelado no aparece: queda como desconocido")
    func canceledTeamsHaveNoState() {
        #expect(window([game("ARI", "DEN", canceled: true)]).teamStates.isEmpty)
    }

    // MARK: - Proveedor

    @Test("window(forWeek:) usa los partidos del proveedor y el reloj inyectado")
    func providerUsesInjectedScoresAndClock() async throws {
        let provider = ScoresGameWindow(
            scores: FakeScores(result: .success([game("ARI", "DEN", startsIn: 3)])),
            season: "2026", clock: FixedClock(date: referenceNow))
        #expect(try await provider.window(forWeek: 7).mode == .gameDay)
    }

    @Test("Si scores falla, window(forWeek:) lanza el mismo error (el poller conserva el modo anterior)")
    func providerRethrows() async {
        let provider = ScoresGameWindow(
            scores: FakeScores(result: .failure(SleeperAPIError.server(status: 503))),
            season: "2026", clock: FixedClock(date: referenceNow))
        await #expect(throws: SleeperAPIError.server(status: 503)) {
            try await provider.window(forWeek: 7)
        }
    }

    // MARK: - Respaldo por horario

    private func eastern(_ iso: String) -> Date {
        // Fechas de octubre de 2026: America/New_York está en horario de verano (UTC-4).
        ISO8601DateFormatter().date(from: iso)!
    }

    @Test("Respaldo: domingo 12:00–24:00 ET, jueves y lunes 20:00–24:00 ET → gameDay")
    func fallbackWindows() {
        // 2026-10-25 es domingo; 22 jueves; 26 lunes. ET = UTC-4 en estas fechas.
        #expect(ScheduleFallback.mode(at: eastern("2026-10-25T16:00:00Z")) == .gameDay)  // dom 12:00 ET
        #expect(ScheduleFallback.mode(at: eastern("2026-10-25T15:59:00Z")) == .idle)  // dom 11:59 ET
        #expect(ScheduleFallback.mode(at: eastern("2026-10-26T03:59:00Z")) == .gameDay)  // dom 23:59 ET
        #expect(ScheduleFallback.mode(at: eastern("2026-10-23T00:00:00Z")) == .gameDay)  // jue 20:00 ET
        #expect(ScheduleFallback.mode(at: eastern("2026-10-22T23:59:00Z")) == .idle)  // jue 19:59 ET
        #expect(ScheduleFallback.mode(at: eastern("2026-10-27T00:30:00Z")) == .gameDay)  // lun 20:30 ET
        #expect(ScheduleFallback.mode(at: eastern("2026-10-27T17:00:00Z")) == .idle)  // mar 13:00 ET
        #expect(ScheduleFallback.mode(at: eastern("2026-10-26T16:00:00Z")) == .idle)  // lun 12:00 ET
    }

    @Test("El respaldo nunca devuelve live, a ninguna hora de la semana")
    func fallbackNeverLive() {
        let start = eastern("2026-10-19T00:00:00Z")
        for hour in 0..<(7 * 24) {
            let date = start.addingTimeInterval(Double(hour) * 3600)
            #expect(ScheduleFallback.mode(at: date) != .live)
        }
    }
}
