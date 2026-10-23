/// Un jugador de `GET /v1/players/nfl` (respuesta: diccionario `player_id → Player`).
///
/// Casi todos los campos pueden ser `null`: los equipos DEF no traen `full_name` (usan nombre y apellido
/// de ciudad y mote) y los agentes libres no traen `team`.
public struct Player: Codable, Sendable, Equatable {
    public let playerId: String
    public let firstName: String?
    public let lastName: String?
    public let fullName: String?
    public let position: String?
    public let team: String?
    public let status: String?
    public let injuryStatus: String?

    enum CodingKeys: String, CodingKey {
        case playerId = "player_id"
        case firstName = "first_name"
        case lastName = "last_name"
        case fullName = "full_name"
        case position, team, status
        case injuryStatus = "injury_status"
    }

    public init(
        playerId: String,
        firstName: String? = nil,
        lastName: String? = nil,
        fullName: String? = nil,
        position: String? = nil,
        team: String? = nil,
        status: String? = nil,
        injuryStatus: String? = nil
    ) {
        self.playerId = playerId
        self.firstName = firstName
        self.lastName = lastName
        self.fullName = fullName
        self.position = position
        self.team = team
        self.status = status
        self.injuryStatus = injuryStatus
    }

    /// Nombre para mostrar: `full_name`, o nombre + apellido, o el ID como último recurso.
    public var displayName: String {
        if let fullName, !fullName.isEmpty { return fullName }
        let joined = [firstName, lastName].compactMap { $0 }.joined(separator: " ")
        return joined.isEmpty ? playerId : joined
    }
}
