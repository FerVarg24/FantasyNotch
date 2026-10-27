import AppKit
import SwiftUI

/// Contenido del menú de la barra: refrescar ahora, cambiar de liga, abrir al iniciar sesión y salir.
/// Las acciones que dependen del poller o de las ventanas las inyecta quien monta el menú (FN-011).
struct MenuBarContent: View {
    let onRefresh: @MainActor () -> Void
    let onChangeLeague: @MainActor () -> Void
    let onQuit: @MainActor () -> Void
    @Bindable var launchAtLogin: LaunchAtLoginModel

    init(
        onRefresh: @escaping @MainActor () -> Void,
        onChangeLeague: @escaping @MainActor () -> Void,
        launchAtLogin: LaunchAtLoginModel,
        onQuit: @escaping @MainActor () -> Void = { NSApplication.shared.terminate(nil) }
    ) {
        self.onRefresh = onRefresh
        self.onChangeLeague = onChangeLeague
        self.launchAtLogin = launchAtLogin
        self.onQuit = onQuit
    }

    var body: some View {
        Button("Refrescar ahora", action: onRefresh)
            .keyboardShortcut("r")

        Button("Cambiar de liga…", action: onChangeLeague)

        Toggle(
            "Abrir al iniciar sesión",
            isOn: Binding(get: { launchAtLogin.isEnabled }, set: { launchAtLogin.setEnabled($0) })
        )

        if launchAtLogin.needsApproval {
            Text("Apruébalo en Ajustes del Sistema → Elementos de inicio")
        }
        if let error = launchAtLogin.errorMessage {
            Text("No se pudo cambiar: \(error)")
        }

        Divider()

        Button("Salir", action: onQuit)
            .keyboardShortcut("q")
    }
}
