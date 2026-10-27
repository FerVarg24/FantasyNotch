import SleeperKit
import SwiftUI

/// Ajustes: qué usuario y liga están configurados, con atajo para cambiar de liga.
/// Lee las mismas claves de `UserDefaults` que escribe `UserDefaultsSettingsStore`.
struct SettingsView: View {
    @AppStorage(SettingsKeys.username) private var username = ""
    @AppStorage(SettingsKeys.leagueId) private var leagueId = ""
    @Bindable var launchAtLogin: LaunchAtLoginModel
    let onChangeLeague: @MainActor () -> Void

    var body: some View {
        Form {
            LabeledContent("Usuario de Sleeper", value: username.isEmpty ? "—" : username)
            LabeledContent("Liga", value: leagueId.isEmpty ? "—" : leagueId)

            Button("Cambiar de liga…", action: onChangeLeague)

            Toggle(
                "Abrir al iniciar sesión",
                isOn: Binding(get: { launchAtLogin.isEnabled }, set: { launchAtLogin.setEnabled($0) })
            )
            if launchAtLogin.needsApproval {
                Text("Apruébalo en Ajustes del Sistema → Elementos de inicio")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            if let error = launchAtLogin.errorMessage {
                Text("No se pudo cambiar: \(error)")
                    .font(.callout)
                    .foregroundStyle(.red)
            }
        }
        .formStyle(.grouped)
        .frame(width: 380)
        .padding(.vertical, 8)
    }
}

#Preview("Ajustes") {
    SettingsView(launchAtLogin: LaunchAtLoginModel(), onChangeLeague: {})
}
