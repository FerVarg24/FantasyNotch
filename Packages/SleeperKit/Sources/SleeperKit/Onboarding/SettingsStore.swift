import Foundation

/// Claves de `UserDefaults` de `plan.md` §Data. Las usan tanto `UserDefaultsSettingsStore` como los `@AppStorage`
/// de las vistas, así que ambos lados leen y escriben lo mismo (IDs como `String`, versión como `Int`).
public enum SettingsKeys {
    public static let userId = "sleeperUserId"
    public static let username = "sleeperUsername"
    public static let leagueId = "leagueId"
    public static let settingsVersion = "settingsVersion"

    /// Versión del formato de ajustes. Si en disco hay otra, los ajustes se ignoran (`plan.md` §Rollback).
    public static let currentVersion = 1
}

/// Dónde se guarda lo que el onboarding elige. Un protocolo para probar el flujo sin tocar `UserDefaults` reales.
@MainActor
public protocol SettingsStoring: AnyObject {
    var userId: String? { get set }
    var username: String? { get set }
    var leagueId: String? { get set }
    var settingsVersion: Int? { get set }
}

extension SettingsStoring {
    /// Hay usuario y liga de una versión de ajustes conocida: el onboarding se salta al arrancar.
    public var isConfigured: Bool {
        settingsVersion == SettingsKeys.currentVersion
            && !(userId ?? "").isEmpty
            && !(leagueId ?? "").isEmpty
    }

    /// Guarda las cuatro claves juntas. La versión va al final: hasta entonces `isConfigured` sigue en `false`.
    public func save(userId: String, username: String, leagueId: String) {
        self.userId = userId
        self.username = username
        self.leagueId = leagueId
        settingsVersion = SettingsKeys.currentVersion
    }
}

/// Persistencia real: `UserDefaults`, con las mismas claves que leen los `@AppStorage`.
@MainActor
public final class UserDefaultsSettingsStore: SettingsStoring {
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public var userId: String? {
        get { defaults.string(forKey: SettingsKeys.userId) }
        set { set(newValue, forKey: SettingsKeys.userId) }
    }

    public var username: String? {
        get { defaults.string(forKey: SettingsKeys.username) }
        set { set(newValue, forKey: SettingsKeys.username) }
    }

    public var leagueId: String? {
        get { defaults.string(forKey: SettingsKeys.leagueId) }
        set { set(newValue, forKey: SettingsKeys.leagueId) }
    }

    public var settingsVersion: Int? {
        get { defaults.object(forKey: SettingsKeys.settingsVersion) as? Int }
        set { set(newValue, forKey: SettingsKeys.settingsVersion) }
    }

    private func set(_ value: Any?, forKey key: String) {
        if let value {
            defaults.set(value, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }
}

/// Almacén en memoria para tests y previews.
@MainActor
public final class InMemorySettingsStore: SettingsStoring {
    public var userId: String?
    public var username: String?
    public var leagueId: String?
    public var settingsVersion: Int?

    public init() {}
}
