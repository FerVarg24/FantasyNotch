import Foundation
import Testing

@testable import SleeperKit
@testable import SleeperKitMocks

/// `SleeperAPI` que devuelve resultados fijos y registra con qué argumentos lo llamaron.
private final class StubAPI: SleeperAPI, @unchecked Sendable {
    private let lock = NSLock()
    private var _usernames: [String] = []
    private var _seasons: [String] = []
    private var _leagueUserIds: [String] = []

    var userResult: Result<SleeperUser, SleeperAPIError>
    var stateResult: Result<NFLState, SleeperAPIError>
    var leaguesResult: Result<[League], SleeperAPIError>
    var userDelay: Duration = .zero

    init(
        user: Result<SleeperUser, SleeperAPIError> = .success(SleeperUser(userId: "U1", username: "manager_1")),
        state: Result<NFLState, SleeperAPIError> = .success(
            NFLState(week: 7, season: "2030", seasonType: "regular", leagueSeason: "2030")),
        leagues: Result<[League], SleeperAPIError> = .success(StubAPI.twoLeagues)
    ) {
        userResult = user
        stateResult = state
        leaguesResult = leagues
    }

    static let twoLeagues = [League(leagueId: "L1", name: "Liga Uno"), League(leagueId: "L2", name: "Liga Dos")]

    var usernames: [String] { lock.withLock { _usernames } }
    var seasons: [String] { lock.withLock { _seasons } }
    var leagueUserIds: [String] { lock.withLock { _leagueUserIds } }

    func user(username: String) async throws -> SleeperUser {
        lock.withLock { _usernames.append(username) }
        if userDelay > .zero { try await Task.sleep(for: userDelay) }
        return try userResult.get()
    }

    func nflState() async throws -> NFLState { try stateResult.get() }

    func leagues(userId: String, season: String) async throws -> [League] {
        lock.withLock {
            _leagueUserIds.append(userId)
            _seasons.append(season)
        }
        return try leaguesResult.get()
    }

    func leagueUsers(leagueId: String) async throws -> [LeagueUser] { throw SleeperAPIError.notFound }
    func rosters(leagueId: String) async throws -> [Roster] { throw SleeperAPIError.notFound }
    func matchups(leagueId: String, week: Int) async throws -> [Matchup] { throw SleeperAPIError.notFound }
    func players() async throws -> [String: Player] { throw SleeperAPIError.notFound }
}

@MainActor
@Suite("OnboardingViewModel: username → ligas → elegir liga")
struct OnboardingViewModelTests {
    private func configuredStore() -> InMemorySettingsStore {
        let store = InMemorySettingsStore()
        store.save(userId: "U1", username: "manager_1", leagueId: "L1")
        return store
    }

    // MARK: - Errores inline

    @Test("Username inexistente: error inline, el onboarding sigue abierto y no se guarda nada")
    func unknownUsername() async {
        let api = StubAPI(user: .failure(.notFound))
        let store = InMemorySettingsStore()
        let model = OnboardingViewModel(api: api, store: store)
        model.username = "no_existe"

        await model.submit()

        #expect(model.failure == .userNotFound)
        #expect(model.phase == .enterUsername)
        #expect(store.userId == nil && store.leagueId == nil && store.settingsVersion == nil)
    }

    @Test("Un username con caracteres inválidos (invalidRequest) se muestra como inexistente")
    func invalidUsernameIsNotFound() async {
        let model = OnboardingViewModel(
            api: StubAPI(user: .failure(.invalidRequest(detail: "path"))), store: InMemorySettingsStore())
        model.username = "a/b"
        await model.submit()
        #expect(model.failure == .userNotFound)
    }

    @Test("Sin red, límite o servidor caído: error de red inline y se puede reintentar",
        arguments: [
            SleeperAPIError.network(detail: "offline"), .rateLimited, .server(status: 503), .badStatus(500),
            .responseTooLarge,
        ])
    func networkFailures(error: SleeperAPIError) async {
        let api = StubAPI(user: .failure(error))
        let model = OnboardingViewModel(api: api, store: InMemorySettingsStore())
        model.username = "manager_1"

        await model.submit()
        #expect(model.failure == .network)
        #expect(model.phase == .enterUsername)

        api.userResult = .success(SleeperUser(userId: "U1", username: "manager_1"))
        await model.submit()
        #expect(model.failure == nil)
        #expect(model.phase == .pickLeague(StubAPI.twoLeagues))
    }

    @Test("Una respuesta con forma inesperada no revienta: error genérico inline")
    func decodingFailure() async {
        let model = OnboardingViewModel(
            api: StubAPI(user: .failure(.decoding(detail: "x"))), store: InMemorySettingsStore())
        model.username = "manager_1"
        await model.submit()
        #expect(model.failure == .unexpected)
        #expect(model.phase == .enterUsername)
    }

    @Test("Un fallo al pedir las ligas también es inline y no deja nada guardado")
    func leaguesFailure() async {
        let store = InMemorySettingsStore()
        let model = OnboardingViewModel(api: StubAPI(leagues: .failure(.network(detail: "x"))), store: store)
        model.username = "manager_1"
        await model.submit()
        #expect(model.failure == .network)
        #expect(model.phase == .enterUsername)
        #expect(store.userId == nil)
    }

    @Test("Username vacío o solo espacios: error y ninguna llamada a la API")
    func emptyUsername() async {
        let api = StubAPI()
        let model = OnboardingViewModel(api: api, store: InMemorySettingsStore())
        model.username = "   "
        await model.submit()
        #expect(model.failure == .emptyUsername)
        #expect(api.usernames.isEmpty)
    }

    @Test("Usuario sin ligas NFL esta temporada: aviso inline")
    func noLeagues() async {
        let model = OnboardingViewModel(api: StubAPI(leagues: .success([])), store: InMemorySettingsStore())
        model.username = "manager_1"
        await model.submit()
        #expect(model.failure == .noLeagues)
        #expect(model.phase == .enterUsername)
    }

    // MARK: - Camino feliz

    @Test("Con el MockSleeperAPI lista las ligas del usuario")
    func listsLeaguesFromMock() async throws {
        let mock = MockSleeperAPI()
        let model = OnboardingViewModel(api: mock, store: InMemorySettingsStore())
        model.username = "manager_1"

        await model.submit()

        let expected = try await mock.leagues(userId: "x", season: "x")
        #expect(!expected.isEmpty)
        #expect(model.phase == .pickLeague(expected))
        #expect(model.failure == nil)
    }

    @Test("Recorta el username y pide las ligas de la liga_season de /state/nfl")
    func usesLeagueSeasonAndTrimsUsername() async {
        let state = NFLState(week: 1, season: "2030", seasonType: "pre", leagueSeason: "2031")
        let api = StubAPI(state: .success(state))
        let model = OnboardingViewModel(api: api, store: InMemorySettingsStore())
        model.username = "  manager_1 \n"

        await model.submit()

        #expect(api.usernames == ["manager_1"])
        #expect(api.seasons == ["2031"])
        #expect(api.leagueUserIds == ["U1"])
    }

    @Test("Sin league_season usa season")
    func fallsBackToSeason() async {
        let state = NFLState(week: 1, season: "2030", seasonType: "regular", leagueSeason: nil)
        let api = StubAPI(state: .success(state))
        let model = OnboardingViewModel(api: api, store: InMemorySettingsStore())
        model.username = "manager_1"
        await model.submit()
        #expect(api.seasons == ["2030"])
    }

    @Test("Elegir liga guarda las cuatro claves juntas y termina el onboarding")
    func selectingPersists() async {
        let store = InMemorySettingsStore()
        let model = OnboardingViewModel(api: StubAPI(), store: store)
        model.username = "manager_1"
        await model.submit()
        #expect(store.leagueId == nil)  // todavía no: se guarda solo al elegir

        model.select(StubAPI.twoLeagues[1])

        #expect(store.userId == "U1")
        #expect(store.username == "manager_1")
        #expect(store.leagueId == "L2")
        #expect(store.settingsVersion == 1)
        #expect(model.phase == .done)
        #expect(store.isConfigured)
    }

    @Test("Doble envío mientras carga: se ignora el segundo")
    func doubleSubmitIsIgnored() async throws {
        let api = StubAPI()
        api.userDelay = .milliseconds(150)
        let model = OnboardingViewModel(api: api, store: InMemorySettingsStore())
        model.username = "manager_1"

        let first = Task { await model.submit() }
        // Test y ViewModel son @MainActor y `.loading` se fija antes del primer await: sin esperas fijas.
        while model.phase != .loading { await Task.yield() }
        await model.submit()
        await first.value

        #expect(api.usernames.count == 1)
    }

    // MARK: - Señal de «liga configurada» para FN-011

    @MainActor
    private final class ConfiguredRecorder {
        private(set) var calls: [String] = []
        func record(_ userId: String, _ leagueId: String) { calls.append("\(userId)/\(leagueId)") }
    }

    @Test("onConfigured se llama una vez, con usuario y liga, solo al elegir liga")
    func onConfiguredFiresOnSelect() async {
        let recorder = ConfiguredRecorder()
        let model = OnboardingViewModel(api: StubAPI(), store: InMemorySettingsStore())
        model.onConfigured = { recorder.record($0, $1) }
        model.username = "manager_1"

        await model.submit()
        #expect(recorder.calls.isEmpty)

        model.select(StubAPI.twoLeagues[1])
        model.select(StubAPI.twoLeagues[0])  // ya no vale: la fase es .done
        #expect(recorder.calls == ["U1/L2"])
    }

    @Test("onConfigured también avisa al cambiar de liga, con el userId guardado")
    func onConfiguredFiresOnChangeLeague() async {
        let recorder = ConfiguredRecorder()
        let model = OnboardingViewModel(api: StubAPI(), store: configuredStore())
        model.onConfigured = { recorder.record($0, $1) }

        await model.changeLeague()
        model.select(StubAPI.twoLeagues[1])

        #expect(recorder.calls == ["U1/L2"])
    }

    @Test("onConfigured no se llama si changeLeague() falla, si no hay ligas ni al cancelar")
    func onConfiguredSilentWithoutNewLeague() async {
        let recorder = ConfiguredRecorder()

        let failing = OnboardingViewModel(
            api: StubAPI(leagues: .failure(.network(detail: "x"))), store: configuredStore())
        failing.onConfigured = { recorder.record($0, $1) }
        await failing.changeLeague()

        let empty = OnboardingViewModel(api: StubAPI(leagues: .success([])), store: configuredStore())
        empty.onConfigured = { recorder.record($0, $1) }
        await empty.changeLeague()

        let cancelled = OnboardingViewModel(api: StubAPI(), store: configuredStore())
        cancelled.onConfigured = { recorder.record($0, $1) }
        await cancelled.changeLeague()
        cancelled.cancelLeagueChange()

        #expect(recorder.calls.isEmpty)
    }

    // MARK: - Configurado / saltar onboarding

    @Test("isConfigured exige las claves y la versión 1")
    func isConfiguredRules() {
        let ok = configuredStore()
        #expect(ok.isConfigured)

        let noLeague = InMemorySettingsStore()
        noLeague.userId = "U1"
        noLeague.settingsVersion = 1
        #expect(!noLeague.isConfigured)

        let noVersion = configuredStore()
        noVersion.settingsVersion = nil
        #expect(!noVersion.isConfigured)

        let future = configuredStore()
        future.settingsVersion = 99
        #expect(!future.isConfigured)

        let emptyLeague = configuredStore()
        emptyLeague.leagueId = ""
        #expect(!emptyLeague.isConfigured)
    }

    @Test("Arranca en .done si ya hay liga configurada, y en .enterUsername si no")
    func initialPhase() {
        #expect(OnboardingViewModel(api: StubAPI(), store: configuredStore()).phase == .done)
        #expect(OnboardingViewModel(api: StubAPI(), store: InMemorySettingsStore()).phase == .enterUsername)
    }

    // MARK: - Cambiar de liga

    @Test("changeLeague() reutiliza el userId guardado, sin volver a pedir el usuario")
    func changeLeagueReusesUser() async {
        let api = StubAPI()
        let store = configuredStore()
        let model = OnboardingViewModel(api: api, store: store)

        await model.changeLeague()
        #expect(model.phase == .pickLeague(StubAPI.twoLeagues))
        #expect(api.usernames.isEmpty)
        #expect(api.leagueUserIds == ["U1"])
        #expect(store.leagueId == "L1")  // no cambia hasta elegir

        model.select(StubAPI.twoLeagues[1])
        #expect(store.leagueId == "L2")
        #expect(store.userId == "U1")
        #expect(model.phase == .done)
    }

    @Test("Si changeLeague() falla se conserva la liga actual")
    func changeLeagueFailureKeepsLeague() async {
        let store = configuredStore()
        let model = OnboardingViewModel(api: StubAPI(leagues: .failure(.network(detail: "x"))), store: store)

        await model.changeLeague()

        #expect(model.failure == .network)
        #expect(model.phase == .done)
        #expect(store.leagueId == "L1")
        #expect(store.isConfigured)
    }

    @Test("Cancelar el cambio de liga no borra la liga actual")
    func cancelKeepsLeague() async {
        let store = configuredStore()
        let model = OnboardingViewModel(api: StubAPI(), store: store)
        await model.changeLeague()

        model.cancelLeagueChange()

        #expect(model.phase == .done)
        #expect(store.leagueId == "L1")
    }

    @Test("changeLeague() sin usuario guardado vuelve al onboarding")
    func changeLeagueWithoutUser() async {
        let model = OnboardingViewModel(api: StubAPI(), store: InMemorySettingsStore())
        await model.changeLeague()
        #expect(model.phase == .enterUsername)
    }

    // MARK: - UserDefaults real (mismas claves y tipos que @AppStorage)

    @Test("UserDefaultsSettingsStore escribe las claves de plan.md con los tipos que lee @AppStorage")
    func userDefaultsStoreMatchesAppStorage() throws {
        let suite = "OnboardingTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = UserDefaultsSettingsStore(defaults: defaults)

        store.save(userId: "U1", username: "manager_1", leagueId: "L2")

        #expect(defaults.string(forKey: "sleeperUserId") == "U1")
        #expect(defaults.string(forKey: "sleeperUsername") == "manager_1")
        #expect(defaults.string(forKey: "leagueId") == "L2")
        #expect(defaults.object(forKey: "settingsVersion") as? Int == 1)
        #expect(UserDefaultsSettingsStore(defaults: defaults).isConfigured)
    }

    @Test("Un UserDefaults vacío no cuenta como configurado")
    func emptyDefaultsNotConfigured() throws {
        let suite = "OnboardingTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        #expect(!UserDefaultsSettingsStore(defaults: defaults).isConfigured)
    }
}
