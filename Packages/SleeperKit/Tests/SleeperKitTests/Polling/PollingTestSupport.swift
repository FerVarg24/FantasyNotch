import Foundation

@testable import SleeperKit
@testable import SleeperKitMocks

/// Reloj controlado por el test. `sleep` solo termina cuando el test avanza el tiempo con `advance(by:)`.
///
/// Para no sincronizar con `Task.yield()` ni con esperas reales (flaky en CI), el test espera con
/// `untilSleeping()` a que el bucle del poller esté realmente suspendido en un `sleep`.
final class FakeClock: PollingClock, @unchecked Sendable {
    private struct Sleeper {
        let deadline: Date
        let continuation: CheckedContinuation<Void, Error>
    }

    private struct Waiter {
        let count: Int
        let continuation: CheckedContinuation<Void, Never>
    }

    private let lock = NSLock()
    private var current: Date
    private var sleepers: [UUID: Sleeper] = [:]
    private var waiters: [Waiter] = []

    init(start: Date = Date(timeIntervalSince1970: 1_800_000_000)) {
        current = start
    }

    func now() -> Date { lock.withLock { current } }

    func sleep(for duration: Duration) async throws {
        let id = UUID()
        let seconds = Double(duration.components.seconds) + Double(duration.components.attoseconds) / 1e18
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                lock.lock()
                if Task.isCancelled {
                    lock.unlock()
                    continuation.resume(throwing: CancellationError())
                    return
                }
                sleepers[id] = Sleeper(deadline: current.addingTimeInterval(seconds), continuation: continuation)
                let ready = takeSatisfiedWaiters()
                lock.unlock()
                ready.forEach { $0.resume() }
            }
        } onCancel: {
            let sleeper = lock.withLock { sleepers.removeValue(forKey: id) }
            sleeper?.continuation.resume(throwing: CancellationError())
        }
    }

    /// Avanza el reloj y despierta a los que vencen, en orden de plazo.
    func advance(by seconds: TimeInterval) {
        let due: [Sleeper] = lock.withLock {
            current = current.addingTimeInterval(seconds)
            let ids = sleepers.filter { $0.value.deadline <= current }.sorted { $0.value.deadline < $1.value.deadline }
            ids.forEach { sleepers.removeValue(forKey: $0.key) }
            return ids.map(\.value)
        }
        due.forEach { $0.continuation.resume() }
    }

    /// Espera a que haya al menos `count` tareas suspendidas en `sleep`.
    func untilSleeping(atLeast count: Int = 1) async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            lock.lock()
            if sleepers.count >= count {
                lock.unlock()
                continuation.resume()
                return
            }
            waiters.append(Waiter(count: count, continuation: continuation))
            lock.unlock()
        }
    }

    var sleeperCount: Int { lock.withLock { sleepers.count } }

    private func takeSatisfiedWaiters() -> [CheckedContinuation<Void, Never>] {
        let ready = waiters.filter { sleepers.count >= $0.count }
        waiters.removeAll { sleepers.count >= $0.count }
        return ready.map(\.continuation)
    }
}

/// API espía: cuenta llamadas por método y anota el instante de cada `/matchups`.
final class SpyAPI: SleeperAPI, @unchecked Sendable {
    typealias MatchupsBehavior = @Sendable (_ callIndex: Int) throws -> [Matchup]

    private let lock = NSLock()
    private let base = MockSleeperAPI(scenario: .final)
    private let clock: FakeClock
    private let behavior: MatchupsBehavior
    private var counts: [String: Int] = [:]
    private var times: [Date] = []

    init(clock: FakeClock, behavior: @escaping MatchupsBehavior = { _ in try SpyAPI.fixtureMatchups() }) {
        self.clock = clock
        self.behavior = behavior
    }

    static func fixtureMatchups() throws -> [Matchup] {
        try SleeperDecoder.decode([Matchup].self, from: MockFixtures.data(named: "matchups_week1_final"))
    }

    func calls(_ method: String) -> Int { lock.withLock { counts[method, default: 0] } }
    var matchupsCalls: Int { calls("matchups") }

    /// Segundos transcurridos entre llamadas consecutivas a `/matchups`, empezando por la primera desde `origin`.
    func matchupGaps(since origin: Date) -> [TimeInterval] {
        let all = lock.withLock { times }
        var previous = origin
        return all.map { time in
            defer { previous = time }
            return time.timeIntervalSince(previous)
        }
    }

    private func bump(_ method: String) { lock.withLock { counts[method, default: 0] += 1 } }

    func nflState() async throws -> NFLState {
        bump("nflState")
        return try await base.nflState()
    }

    func user(username: String) async throws -> SleeperUser {
        bump("user")
        return try await base.user(username: username)
    }

    func leagues(userId: String, season: String) async throws -> [League] {
        bump("leagues")
        return try await base.leagues(userId: userId, season: season)
    }

    func leagueUsers(leagueId: String) async throws -> [LeagueUser] {
        bump("leagueUsers")
        return try await base.leagueUsers(leagueId: leagueId)
    }

    func rosters(leagueId: String) async throws -> [Roster] {
        bump("rosters")
        return try await base.rosters(leagueId: leagueId)
    }

    func matchups(leagueId: String, week: Int) async throws -> [Matchup] {
        let index: Int = lock.withLock {
            times.append(clock.now())
            counts["matchups", default: 0] += 1
            return counts["matchups", default: 1]
        }
        return try behavior(index)
    }

    func players() async throws -> [String: Player] {
        bump("players")
        return try await base.players()
    }
}

/// Proveedor de ventana de juego controlable. Puede fallar para probar que se conserva el modo anterior.
final class FakeGameWindow: GameWindowProviding, @unchecked Sendable {
    private let lock = NSLock()
    private var result: Result<GameWindow, Error>
    private var calls = 0

    /// Veces que el poller ha consultado la ventana (incluye las que fallaron).
    var callCount: Int { lock.withLock { calls } }

    init(_ mode: PollingMode, teamStates: [String: TeamPlayState] = [:]) {
        result = .success(GameWindow(mode: mode, teamStates: teamStates))
    }

    func set(_ mode: PollingMode, teamStates: [String: TeamPlayState] = [:]) {
        lock.withLock { result = .success(GameWindow(mode: mode, teamStates: teamStates)) }
    }

    func fail() { fail(with: SleeperAPIError.network(detail: "scores")) }

    func fail(with error: any Error) { lock.withLock { result = .failure(error) } }

    func window(forWeek week: Int) async throws -> GameWindow {
        try lock.withLock {
            calls += 1
            return result
        }.get()
    }
}

/// Resolver de prueba: devuelve el snapshot de ejemplo, `nil`, o lanza; guarda la última entrada recibida.
final class FakeResolver: MatchupResolving, @unchecked Sendable {
    enum Outcome { case snapshot, none, failure }

    private let lock = NSLock()
    private var outcome: Outcome
    private var calls = 0
    private var last: MatchupInput?

    init(_ outcome: Outcome = .snapshot) { self.outcome = outcome }

    var callCount: Int { lock.withLock { calls } }
    var lastInput: MatchupInput? { lock.withLock { last } }

    func resolve(_ input: MatchupInput) throws -> MatchupSnapshot? {
        lock.withLock {
            calls += 1
            last = input
        }
        switch outcome {
        case .snapshot: return MatchupSnapshot.previewLive
        case .none: return nil
        case .failure: throw SleeperAPIError.invalidRequest(detail: "roster not found")
        }
    }
}

/// Compuerta para dejar un paso del refresco "en vuelo": avisa de que se entró y no continúa hasta `release()`.
/// No reacciona a la cancelación, como un `players()` real que ya está descargando.
actor Gate {
    private var entered = false
    private var released = false
    private var enteredWaiters: [CheckedContinuation<Void, Never>] = []
    private var releaseWaiters: [CheckedContinuation<Void, Never>] = []

    func passThrough() async {
        entered = true
        enteredWaiters.forEach { $0.resume() }
        enteredWaiters = []
        if !released {
            await withCheckedContinuation { releaseWaiters.append($0) }
        }
    }

    func waitUntilEntered() async {
        if entered { return }
        await withCheckedContinuation { enteredWaiters.append($0) }
    }

    func release() {
        released = true
        releaseWaiters.forEach { $0.resume() }
        releaseWaiters = []
    }
}

let serverError = SleeperAPIError.server(status: 503)
