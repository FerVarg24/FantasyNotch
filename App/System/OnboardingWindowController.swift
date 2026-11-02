import AppKit
import SleeperKit
import SwiftUI

/// Ventana del onboarding. La app es `LSUIElement` (sin Dock), así que hay que activarla a mano o la ventana
/// sale detrás de las demás y el campo de texto no toma el foco.
@MainActor
final class OnboardingWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private let model: OnboardingViewModel
    private let onClose: @MainActor () -> Void

    /// - Parameter onClose: se llama al cerrar la ventana con la X (no al cerrarla por código con `close()`).
    init(model: OnboardingViewModel, onClose: @escaping @MainActor () -> Void) {
        self.model = model
        self.onClose = onClose
    }

    func show() {
        if window == nil {
            let window = NSWindow(
                contentRect: .zero, styleMask: [.titled, .closable], backing: .buffered, defer: false)
            window.title = "FantasyNotch"
            window.isReleasedWhenClosed = false
            let hosting = NSHostingController(rootView: OnboardingView(model: model))
            // Con los `sizingOptions` por defecto (min/intrinsic/max) el tamaño de la ventana y el de la vista se
            // persiguen y AppKit lanza «more Update Constraints passes than views». Solo se sigue el tamaño preferido.
            hosting.sizingOptions = [.preferredContentSize]
            window.contentViewController = hosting
            window.delegate = self
            window.center()
            self.window = window
        }
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
    }

    /// Cierra por código (liga elegida): no cuenta como cancelar.
    func close() {
        guard let window else { return }
        window.delegate = nil
        window.close()
        self.window = nil
    }

    func windowWillClose(_ notification: Notification) {
        window?.delegate = nil
        window = nil
        onClose()
    }
}
