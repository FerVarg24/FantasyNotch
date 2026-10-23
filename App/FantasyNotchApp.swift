import AppKit
import SwiftUI

@main
struct FantasyNotchApp: App {
    var body: some Scene {
        MenuBarExtra("FantasyNotch", systemImage: "football") {
            Button("Salir") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
    }
}
