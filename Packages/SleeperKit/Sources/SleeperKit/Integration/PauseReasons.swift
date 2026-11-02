/// Por qué está pausado el poller. Dormir y bloquear la pantalla se solapan (el Mac despierta con la pantalla
/// bloqueada), así que se reanuda solo cuando ya no queda ninguna razón activa.
public struct PauseReasons: Sendable, Equatable {
    public enum Reason: Sendable, Hashable {
        case systemSleep
        case screenOff
        case screenLocked
    }

    public enum Action: Sendable, Equatable {
        case pause
        case resume
    }

    private var active: Set<Reason> = []

    public init() {}

    public var isPaused: Bool { !active.isEmpty }

    /// Activa o desactiva una razón y devuelve la acción que el poller debe ejecutar, o `nil` si no cambia nada.
    public mutating func set(_ reason: Reason, active isActive: Bool) -> Action? {
        let wasPaused = isPaused
        if isActive { active.insert(reason) } else { active.remove(reason) }
        switch (wasPaused, isPaused) {
        case (false, true): return .pause
        case (true, false): return .resume
        default: return nil
        }
    }
}
