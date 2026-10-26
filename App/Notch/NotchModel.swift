import Observation
import SleeperKit

/// Estado que leen las vistas. DynamicNotch evalúa sus closures una sola vez, así que las
/// vistas observan este modelo en lugar de recibir el snapshot por parámetro.
@MainActor
@Observable
final class NotchModel {
    var snapshot: MatchupSnapshot?
}
