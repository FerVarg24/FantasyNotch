import Observation
import ServiceManagement

/// «Abrir al iniciar sesión». La fuente de verdad es `SMAppService.mainApp.status`: no se guarda ningún `Bool`
/// aparte que pueda desincronizarse si el usuario lo cambia en Ajustes del Sistema.
@MainActor
@Observable
final class LaunchAtLoginModel {
    private(set) var status: SMAppService.Status
    /// Último error de `register()`/`unregister()`, para mostrarlo en vez de fallar en silencio.
    private(set) var errorMessage: String?

    init() {
        status = SMAppService.mainApp.status
    }

    var isEnabled: Bool { status == .enabled }

    /// El sistema pide que el usuario lo apruebe en Ajustes del Sistema → Elementos de inicio.
    var needsApproval: Bool { status == .requiresApproval }

    func setEnabled(_ enabled: Bool) {
        errorMessage = nil
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        refresh()
    }

    /// Vuelve a leer el estado real (al abrir el menú, por ejemplo).
    func refresh() {
        status = SMAppService.mainApp.status
    }
}
