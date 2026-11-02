import AppKit
import SleeperKit

/// Traduce los avisos del sistema (sueño, pantalla apagada, bloqueo, cambio de pantallas) a acciones del poller.
///
/// Sueño y pantalla apagada llegan por `NSWorkspace.shared.notificationCenter`; el bloqueo de pantalla no tiene API
/// pública y llega por `DistributedNotificationCenter` (`com.apple.screenIsLocked`/`Unlocked`). Las razones se
/// combinan en `PauseReasons`: despertar con la pantalla bloqueada no reanuda.
@MainActor
final class SystemEventsObserver {
    private var reasons = PauseReasons()
    private var tokens: [(center: NotificationCenter, token: NSObjectProtocol)] = []

    private let onPauseAction: @MainActor (PauseReasons.Action) -> Void
    private let onScreensChanged: @MainActor () -> Void

    init(
        onPauseAction: @escaping @MainActor (PauseReasons.Action) -> Void,
        onScreensChanged: @escaping @MainActor () -> Void
    ) {
        self.onPauseAction = onPauseAction
        self.onScreensChanged = onScreensChanged
    }

    var isPaused: Bool { reasons.isPaused }

    func start() {
        guard tokens.isEmpty else { return }
        let workspace = NSWorkspace.shared.notificationCenter
        observe(workspace, NSWorkspace.willSleepNotification, reason: .systemSleep, active: true)
        observe(workspace, NSWorkspace.didWakeNotification, reason: .systemSleep, active: false)
        observe(workspace, NSWorkspace.screensDidSleepNotification, reason: .screenOff, active: true)
        observe(workspace, NSWorkspace.screensDidWakeNotification, reason: .screenOff, active: false)

        let distributed = DistributedNotificationCenter.default()
        observe(distributed, Notification.Name("com.apple.screenIsLocked"), reason: .screenLocked, active: true)
        observe(distributed, Notification.Name("com.apple.screenIsUnlocked"), reason: .screenLocked, active: false)

        let token = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.onScreensChanged() }
        }
        tokens.append((NotificationCenter.default, token))
    }

    func stop() {
        tokens.forEach { $0.center.removeObserver($0.token) }
        tokens = []
    }

    private func observe(
        _ center: NotificationCenter, _ name: Notification.Name, reason: PauseReasons.Reason, active: Bool
    ) {
        let token = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.set(reason, active: active) }
        }
        tokens.append((center, token))
    }

    private func set(_ reason: PauseReasons.Reason, active: Bool) {
        if let action = reasons.set(reason, active: active) { onPauseAction(action) }
    }
}
