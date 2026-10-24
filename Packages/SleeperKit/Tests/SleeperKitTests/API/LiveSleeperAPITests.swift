import Foundation
import Testing

@testable import SleeperKit
@testable import SleeperKitMocks

@Suite("LiveSleeperAPI")
struct LiveSleeperAPITests {
    private func api(
        recorder: RequestRecorder = RequestRecorder(),
        status: Int = 200,
        fixture: String? = nil,
        headers: [String: String] = [:],
        body: Data? = nil
    ) -> LiveSleeperAPI {
        let session = StubURLProtocol.session { request in
            recorder.record(request)
            let data = try body ?? fixture.map { try MockFixtures.data(named: $0) } ?? Data()
            return stubResponse(for: request, status: status, headers: headers, body: data)
        }
        return LiveSleeperAPI(session: session)
    }

    // MARK: - Endpoints y decodificación

    @Test("user(username:) pide /user/{username} por GET y decodifica el fixture")
    func userRequestAndDecoding() async throws {
        let recorder = RequestRecorder()
        let user = try await api(recorder: recorder, fixture: "user").user(username: "manager_1")
        #expect(user.userId == "900000000000000001")
        let request = try #require(recorder.requests.first)
        #expect(request.url?.absoluteString == "https://api.sleeper.app/v1/user/manager_1")
        #expect(request.httpMethod == "GET")
    }

    @Test("Cada método usa su ruta de Sleeper v1")
    func endpointPaths() async throws {
        let recorder = RequestRecorder()
        _ = try await api(recorder: recorder, fixture: "state_nfl").nflState()
        _ = try await api(recorder: recorder, fixture: "user_leagues").leagues(userId: "42", season: "2026")
        _ = try await api(recorder: recorder, fixture: "league_users").leagueUsers(leagueId: "L1")
        _ = try await api(recorder: recorder, fixture: "rosters").rosters(leagueId: "L1")
        _ = try await api(recorder: recorder, fixture: "matchups_week1_final").matchups(leagueId: "L1", week: 7)
        _ = try await api(recorder: recorder, fixture: "players_subset").players()
        let paths = recorder.requests.compactMap { $0.url?.path }
        #expect(
            paths == [
                "/v1/state/nfl", "/v1/user/42/leagues/nfl/2026", "/v1/league/L1/users",
                "/v1/league/L1/rosters", "/v1/league/L1/matchups/7", "/v1/players/nfl",
            ])
    }

    @Test("Timeout de 10 s, y de 30 s para /players/nfl")
    func timeouts() async throws {
        let recorder = RequestRecorder()
        _ = try await api(recorder: recorder, fixture: "state_nfl").nflState()
        _ = try await api(recorder: recorder, fixture: "players_subset").players()
        #expect(recorder.requests.map(\.timeoutInterval) == [10, 30])
    }

    @Test("La sesión por defecto no guarda cookies ni caché y limita la petición completa a 30 s")
    func defaultSessionConfiguration() {
        let configuration = LiveSleeperAPI.makeSession().configuration
        #expect(configuration.httpCookieStorage == nil)
        #expect(!configuration.httpShouldSetCookies)
        #expect(configuration.urlCache == nil)
        #expect(configuration.requestCachePolicy == .reloadIgnoringLocalCacheData)
        #expect(configuration.timeoutIntervalForResource == 30)
    }

    // MARK: - Estados HTTP

    @Test("404 → notFound")
    func notFound() async {
        await #expect(throws: SleeperAPIError.notFound) {
            try await api(status: 404).nflState()
        }
    }

    @Test("Usuario inexistente: Sleeper responde 200 con cuerpo null → notFound")
    func unknownUserReturnsNull() async {
        await #expect(throws: SleeperAPIError.notFound) {
            try await api(body: Data("null".utf8)).user(username: "no_existe")
        }
    }

    @Test("429 → rateLimited")
    func rateLimited() async {
        await #expect(throws: SleeperAPIError.rateLimited) {
            try await api(status: 429).nflState()
        }
    }

    @Test("5xx → server(status:)", arguments: [500, 502, 503])
    func serverErrors(status: Int) async {
        await #expect(throws: SleeperAPIError.server(status: status)) {
            try await api(status: status).nflState()
        }
    }

    @Test("Otros estados no exitosos → badStatus")
    func otherStatuses() async {
        await #expect(throws: SleeperAPIError.badStatus(403)) {
            try await api(status: 403).nflState()
        }
    }

    @Test("Una redirección no se sigue y se reporta como badStatus")
    func redirectsAreNotFollowed() async {
        await #expect(throws: SleeperAPIError.badStatus(302)) {
            try await api(status: 302, headers: ["Location": "https://evil.example/x"]).nflState()
        }
    }

    // MARK: - Límites y seguridad

    @Test("Content-Length mayor que 20 MB → responseTooLarge")
    func declaredLengthTooLarge() async {
        await #expect(throws: SleeperAPIError.responseTooLarge) {
            try await api(headers: ["Content-Length": "\(21 * 1024 * 1024)"], body: Data("{}".utf8)).nflState()
        }
    }

    @Test("Cuerpo mayor que 20 MB sin Content-Length → responseTooLarge")
    func actualBodyTooLarge() async {
        await #expect(throws: SleeperAPIError.responseTooLarge) {
            try await api(body: Data(count: 20 * 1024 * 1024 + 1)).players()
        }
    }

    @Test("Una respuesta de otro host se rechaza")
    func foreignHostResponse() async {
        let session = StubURLProtocol.session { request in
            stubResponse(for: request, url: URL(string: "https://evil.example/v1/state/nfl")!, body: Data("{}".utf8))
        }
        await #expect {
            try await LiveSleeperAPI(session: session).nflState()
        } throws: { error in
            guard case SleeperAPIError.invalidRequest = error else { return false }
            return true
        }
    }

    @Test("Identificadores vacíos o con / o .. no generan ninguna petición", arguments: ["", "a/b", "..", "a b", "x?y=1"])
    func invalidIdentifiers(value: String) async {
        let recorder = RequestRecorder()
        let client = api(recorder: recorder, fixture: "user")
        await #expect {
            try await client.user(username: value)
        } throws: { error in
            guard case SleeperAPIError.invalidRequest = error else { return false }
            return true
        }
        #expect(recorder.requests.isEmpty)
    }

    // MARK: - Errores de red y de formato

    @Test("Un timeout de URLSession se convierte en SleeperAPIError.network")
    func networkFailure() async {
        let session = StubURLProtocol.session { _ in throw URLError(.timedOut) }
        await #expect {
            try await LiveSleeperAPI(session: session).nflState()
        } throws: { error in
            guard case SleeperAPIError.network = error else { return false }
            return true
        }
    }

    @Test("JSON inválido con 200 → decoding, sin crash")
    func invalidBody() async {
        await #expect {
            try await api(fixture: "matchups_invalid").matchups(leagueId: "L1", week: 1)
        } throws: { error in
            guard case SleeperAPIError.decoding = error else { return false }
            return true
        }
    }

    @Test("Sin manejador no hay red: la petición falla en vez de salir a internet")
    func stubBlocksRealNetwork() async {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        await #expect {
            try await LiveSleeperAPI(session: URLSession(configuration: configuration)).nflState()
        } throws: { error in
            guard case SleeperAPIError.network = error else { return false }
            return true
        }
    }
}
