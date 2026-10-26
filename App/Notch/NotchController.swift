import AppKit
import Combine
import DynamicNotchKit
import SleeperKit
import SwiftUI

/// Muestra, actualiza y cierra la notch con DynamicNotchKit (docs/spikes/004-dynamicnotchkit.md).
///
/// - Una sola instancia de `DynamicNotch`: cada una escucha cambios de pantalla y nunca se libera.
/// - Pantalla de la barra de menús (`screens[0]`), nunca `NSScreen.main`.
/// - La librería no expande por hover/clic: las vistas llaman a `expand()` y al salir el puntero se
///   vuelve a compacto.
/// - Sin notch `compact()` no muestra nada (fallback en la barra de menús: FN-011).
@MainActor
final class NotchController {
    var presentation: NotchPresentation { machine.presentation }

    private var machine = NotchPresentationMachine()

    private let model = NotchModel()
    private let screen: @MainActor () -> NSScreen
    private var notch: DynamicNotch<AnyView, AnyView, AnyView>?
    private var collapseTask: Task<Void, Never>?
    private var transition: Task<Void, Never>?
    private var hoverObserver: AnyCancellable?

    init(screen: @escaping @MainActor () -> NSScreen = { NSScreen.screens[0] }) {
        self.screen = screen
    }

    /// Muestra el snapshot en compacto o, si ya está visible, solo actualiza los valores.
    func show(_ snapshot: MatchupSnapshot) {
        model.snapshot = snapshot
        if let target = machine.show() { move(to: target) }
    }

    /// Consume el flujo del poller hasta que se cancele la tarea o termine el stream.
    func run(_ snapshots: AsyncStream<MatchupSnapshot>) async {
        for await snapshot in snapshots { show(snapshot) }
    }

    /// El clic siempre expande; el hover se ignora justo después de colapsar.
    func expand(viaHover: Bool = false) {
        collapseTask?.cancel()
        if let target = machine.expand(viaHover: viaHover, now: Date()) { move(to: target) }
    }

    func collapse() {
        collapseTask?.cancel()
        if let target = machine.collapse(now: Date()) { move(to: target) }
    }

    func close() {
        collapseTask?.cancel()
        if let target = machine.close() { move(to: target) }
    }

    private func hoverChanged(_ inside: Bool) {
        collapseTask?.cancel()
        guard machine.shouldCollapseOnHoverChange(inside: inside) else { return }
        // Pequeña espera para no cerrar si el puntero solo cruza un borde.
        collapseTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            self?.collapse()
        }
    }

    /// Encadena las transiciones: cada `await` de DynamicNotchKit tarda ~0.4 s.
    private func move(to target: NotchPresentation) {
        let previous = transition
        transition = Task { [weak self] in
            await previous?.value
            guard let self else { return }
            let notch = self.makeNotchIfNeeded()
            let screen = self.screen()
            switch target {
            case .compact: await notch.compact(on: screen)
            case .expanded: await notch.expand(on: screen)
            case .hidden: await notch.hide()
            }
        }
    }

    private func makeNotchIfNeeded() -> DynamicNotch<AnyView, AnyView, AnyView> {
        if let notch { return notch }
        let model = model
        let notch = DynamicNotch<AnyView, AnyView, AnyView>(hoverBehavior: .all) {
            AnyView(ExpandedNotchView(model: model).environment(\.colorScheme, .dark))
        } compactLeading: {
            AnyView(
                CompactLeadingView(model: model) { [weak self] in self?.expand(viaHover: $0) }
                    .environment(\.colorScheme, .dark))
        } compactTrailing: {
            AnyView(
                CompactTrailingView(model: model) { [weak self] in self?.expand(viaHover: $0) }
                    .environment(\.colorScheme, .dark))
        }
        // `isHovering` cubre todo el contenedor en cualquier estado (spike FN-004).
        hoverObserver = notch.$isHovering.removeDuplicates().sink { [weak self] inside in
            MainActor.assumeIsolated { self?.hoverChanged(inside) }
        }
        self.notch = notch
        return notch
    }
}
