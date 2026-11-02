import AppKit

enum ScreenInfo {
    /// ¿La pantalla de la barra de menús tiene notch? Misma regla que DynamicNotchKit (`auxiliaryTop*Area`) y
    /// `screens[0]`, nunca `NSScreen.main` (spike FN-004): si el usuario pone un monitor externo como principal,
    /// `screens[0]` es el externo y no hay compacto.
    @MainActor
    static var menuBarScreenHasNotch: Bool {
        guard let screen = NSScreen.screens.first else { return false }
        return screen.auxiliaryTopLeftArea != nil && screen.auxiliaryTopRightArea != nil
    }
}
