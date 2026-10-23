import Foundation
import SleeperKit

/// Acceso público a los JSON de `SleeperKitMocks/Fixtures/`. Los nombres son únicos porque `.process`
/// aplana los directorios dentro del bundle.
public enum MockFixtures {
    public static func data(named name: String) throws -> Data {
        guard let url = Bundle.module.url(forResource: name, withExtension: "json") else {
            throw SleeperAPIError.notFound
        }
        return try Data(contentsOf: url)
    }
}

/// Implementación de `SleeperAPI` que sirve fixtures reales y anonimizados (ver `Fixtures/README.md`).
public struct MockSleeperAPI: SleeperAPI {
    /// Qué respuesta devuelve `matchups(leagueId:week:)`.
    public enum Scenario: Sendable, Equatable {
        /// Semana 1 de una liga pública ya terminada (datos reales).
        case final
        /// Misma semana con la segunda mitad de los titulares en 0. **Derivado, no capturado en vivo.**
        case live
        /// Semana de playoffs con byes reales: `matchup_id` nulo y slot vacío `"0"`.
        case bye
        /// Semana sin datos: arreglo vacío.
        case empty
        /// Cuerpo JSON truncado, para probar el error tipado.
        case invalid
    }

    public let scenario: Scenario

    public init(scenario: Scenario = .final) {
        self.scenario = scenario
    }

    public func nflState() async throws -> NFLState {
        try load("state_nfl")
    }

    public func user(username: String) async throws -> SleeperUser {
        try load("user")
    }

    public func leagues(userId: String, season: String) async throws -> [League] {
        try load("user_leagues")
    }

    public func leagueUsers(leagueId: String) async throws -> [LeagueUser] {
        try load("league_users")
    }

    public func rosters(leagueId: String) async throws -> [Roster] {
        try load("rosters")
    }

    public func matchups(leagueId: String, week: Int) async throws -> [Matchup] {
        switch scenario {
        case .final: try load("matchups_week1_final")
        case .live: try load("matchups_week1_live_DERIVED")
        case .bye: try load("matchups_week14_bye")
        case .empty: try load("matchups_week18_empty")
        case .invalid: try load("matchups_invalid")
        }
    }

    public func players() async throws -> [String: Player] {
        try load("players_subset")
    }

    private func load<T: Decodable>(_ name: String) throws -> T {
        try SleeperDecoder.decode(T.self, from: MockFixtures.data(named: name))
    }
}
