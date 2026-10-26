import Foundation

public enum NotchPresentation: Sendable, Equatable {
    case hidden, compact, expanded
}

/// Reglas de transición del notch, sin AppKit para poder probarlas. Cada método devuelve el nuevo
/// estado si hay que animar una transición, o `nil` si no hay nada que hacer.
public struct NotchPresentationMachine: Sendable {
    /// Tras colapsar, las zonas compactas reaparecen bajo el puntero: durante este lapso el hover
    /// no vuelve a expandir (el clic sí).
    public static let hoverCooldown: TimeInterval = 0.8

    public private(set) var presentation: NotchPresentation = .hidden
    private var lastCollapse = Date.distantPast

    public init() {}

    public mutating func show() -> NotchPresentation? {
        guard presentation == .hidden else { return nil }
        presentation = .compact
        return .compact
    }

    public mutating func expand(viaHover: Bool, now: Date) -> NotchPresentation? {
        guard presentation == .compact else { return nil }
        if viaHover, now.timeIntervalSince(lastCollapse) < Self.hoverCooldown { return nil }
        presentation = .expanded
        return .expanded
    }

    public mutating func collapse(now: Date) -> NotchPresentation? {
        guard presentation == .expanded else { return nil }
        lastCollapse = now
        presentation = .compact
        return .compact
    }

    public mutating func close() -> NotchPresentation? {
        guard presentation != .hidden else { return nil }
        presentation = .hidden
        return .hidden
    }

    /// `true` si al salir el puntero hay que programar el colapso.
    public func shouldCollapseOnHoverChange(inside: Bool) -> Bool {
        !inside && presentation == .expanded
    }
}
