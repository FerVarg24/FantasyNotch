import Foundation

/// Estado de un titular según el partido de su equipo. Es una aproximación a nivel de partido
/// (Sleeper no expone si el jugador está en el campo). Ver `docs/spikes/003-sleeper-live-data.md` §2.
public enum PlayStatus: Sendable, Equatable, Hashable, CaseIterable {
    case pending
    case playing
    case done
    case unknown
}

public struct StarterLine: Sendable, Equatable {
    public let playerId: String
    public let name: String
    public let position: String
    public let points: Double
    public let status: PlayStatus

    public init(playerId: String, name: String, position: String, points: Double, status: PlayStatus) {
        self.playerId = playerId
        self.name = name
        self.position = position
        self.points = points
        self.status = status
    }
}

public struct TeamScore: Sendable, Equatable {
    public let rosterId: Int
    public let teamName: String
    public let avatarURL: URL?
    public let points: Double
    public let starters: [StarterLine]

    public init(rosterId: Int, teamName: String, avatarURL: URL?, points: Double, starters: [StarterLine]) {
        self.rosterId = rosterId
        self.teamName = teamName
        self.avatarURL = avatarURL
        self.points = points
        self.starters = starters
    }
}

public struct MatchupSnapshot: Sendable, Equatable {
    public let week: Int
    public let me: TeamScore
    /// `nil` = bye / sin matchup.
    public let opponent: TeamScore?
    public let fetchedAt: Date
    public let isStale: Bool

    public init(week: Int, me: TeamScore, opponent: TeamScore?, fetchedAt: Date, isStale: Bool) {
        self.week = week
        self.me = me
        self.opponent = opponent
        self.fetchedAt = fetchedAt
        self.isStale = isStale
    }
}
