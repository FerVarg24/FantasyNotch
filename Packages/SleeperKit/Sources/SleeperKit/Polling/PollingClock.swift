import Foundation

/// Reloj inyectable del poller. En producción es `SystemPollingClock`; los tests usan uno controlado.
public protocol PollingClock: Sendable {
    func now() -> Date
    /// Debe lanzar `CancellationError` si la tarea se cancela durante la espera.
    func sleep(for duration: Duration) async throws
}

public struct SystemPollingClock: PollingClock {
    public init() {}

    public func now() -> Date { Date() }

    public func sleep(for duration: Duration) async throws {
        try await Task.sleep(for: duration)
    }
}

extension Duration {
    /// Segundos como `TimeInterval`, para comparar con diferencias de `Date`.
    var timeInterval: TimeInterval {
        Double(components.seconds) + Double(components.attoseconds) / 1e18
    }
}
