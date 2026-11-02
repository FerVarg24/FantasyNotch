import AppKit
import SwiftUI

@main
struct FantasyNotchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        MenuBarExtra {
            MenuBarContent(
                onRefresh: { delegate.model.refreshNow() },
                onChangeLeague: { delegate.model.changeLeague() },
                launchAtLogin: delegate.model.launchAtLogin)
        } label: {
            if let title = delegate.model.menuBarTitle {
                Text(title).monospacedDigit()
            } else {
                Image(systemName: "football")
            }
        }
    }
}

/// Arranca el modelo al terminar el lanzamiento: el contenido del `MenuBarExtra` no se evalúa hasta abrir el menú.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = AppModel()

    func applicationDidFinishLaunching(_ notification: Notification) {
        model.start()
    }
}
