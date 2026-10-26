# Plan 001 · MVP

## Design
Dos módulos (ver ADR 0001):

```text
App (SwiftUI, target Xcode)                      SleeperKit (Swift Package, sin UI)
┌──────────────────────────────┐                 ┌───────────────────────────────────┐
│ FantasyNotchApp (MenuBarExtra)│                 │ API/Models   Codable de Sleeper    │
│ AppModel (@Observable) ───────┼── usa ────────▶ │ API/Client   SleeperAPI (protocol) │
│ Notch/ compacta + expandida   │                 │              LiveSleeperAPI        │
│ Onboarding/ Settings/ MenuBar/│                 │ Cache/       PlayerCache (1/día)   │
└──────────────────────────────┘                 │ Domain/      MatchupResolver       │
        ▲  DynamicNotchKit (ADR 0002)             │              → MatchupSnapshot     │
        │                                         │ Polling/     MatchupPoller (actor) │
        └──────── AsyncStream<MatchupSnapshot> ◀──┤              (ADR 0003)            │
                                                  └───────────────────────────────────┘
```

Flujo: `AppModel` arranca `MatchupPoller` con `(userId, leagueId)`. El poller pide `/state/nfl` (semana), `/league/{id}/matchups/{week}`, y con `rosters`, `users` y el `PlayerCache` el `MatchupResolver` arma un `MatchupSnapshot` que se publica por `AsyncStream`. La UI solo consume `MatchupSnapshot`, nunca modelos crudos de la API.

Alternativas descartadas: fork de MenuScores (GPL, modelo de datos de ESPN); lógica dentro del target de la app (no testeable con `swift test`, choques en el `.pbxproj`).

## Data and migrations
Sin base de datos.
- `UserDefaults` (`@AppStorage`): `sleeperUserId`, `sleeperUsername`, `leagueId`, `launchAtLogin`. Clave `settingsVersion = 1` para migraciones futuras.
- `~/Library/Application Support/FantasyNotch/players-v1.json`: subconjunto de `/players/nfl` (`player_id`, `full_name`, `position`, `team`) + `fetchedAt`. Si el formato cambia se crea `players-v2.json` y se borra el anterior.

## Contracts
Contrato interno (FN-002), en `SleeperKit`:

```swift
public protocol SleeperAPI: Sendable {
    func nflState() async throws -> NFLState
    func user(username: String) async throws -> SleeperUser
    func leagues(userId: String, season: String) async throws -> [League]
    func leagueUsers(leagueId: String) async throws -> [LeagueUser]
    func rosters(leagueId: String) async throws -> [Roster]
    func matchups(leagueId: String, week: Int) async throws -> [Matchup]
    func players() async throws -> [String: Player]
}

public struct MatchupSnapshot: Sendable, Equatable {
    public let week: Int
    public let me: TeamScore
    public let opponent: TeamScore?        // nil = bye / sin matchup
    public let fetchedAt: Date
    public let isStale: Bool
}

public struct TeamScore: Sendable, Equatable {
    public let rosterId: Int
    public let teamName: String
    public let avatarURL: URL?
    public let points: Double
    public let starters: [StarterLine]
}

public struct StarterLine: Sendable, Equatable {
    public let playerId: String
    public let name: String
    public let position: String
    public let points: Double
    public let status: PlayStatus           // .pending, .playing, .done, .unknown
}
```

`MockSleeperAPI` sirve los fixtures de `Tests/SleeperKitTests/Fixtures/` y es lo que usan la UI (previews) y los tests.

API externa (Sleeper v1, solo lectura, sin auth): `https://api.sleeper.app/v1/…`; avatares en `https://sleepercdn.com/avatars/thumbs/{avatar}`.

## Threat model (STRIDE)
Área sensible: llamadas externas y un dato personal (username). Sin auth, sin pagos, sin servidor propio.

| Threat | Vector | Mitigation | Test |
|---|---|---|---|
| Spoofing | Un host falso responde como Sleeper | Solo HTTPS a `api.sleeper.app`, `sleepercdn.com` y, únicamente para el endpoint no documentado `scores` (FN-017), `api.sleeper.com` (ATS por defecto, sin excepciones); hosts fijos en el código, un cliente por host (`LiveSleeperAPI`, `ScoresClient`) | Test: cada cliente rechaza URLs de otro host y redirecciones |
| Tampering | JSON malformado o inesperado | `Codable` estricto con campos opcionales donde Sleeper los omite; sin `eval`/ejecución de contenido | Fixtures inválidos → error tipado, sin crash |
| Repudiation | — (sin acciones de escritura) | N/A | — |
| Information disclosure | Username o IDs en logs; caché legible por otras apps | `os.Logger` con `privacy: .private` para username/IDs; App Sandbox (ADR 0004) aísla el contenedor | Revisión en PR (security-reviewer) |
| Denial of service | Respuesta enorme o lenta; bucle de reintentos; bloqueo de IP por exceso de llamadas | Timeout 10 s (30 s para `/players`), límite de tamaño de respuesta 20 MB, backoff exponencial con tope, intervalos mínimos garantizados por el poller | Tests del poller con reloj inyectado: nunca < 60 s entre llamadas a `/matchups` |
| Elevation of privilege | Dependencia comprometida | Una sola dependencia (DynamicNotchKit, MIT) fijada a versión exacta; App Sandbox con solo `network.client` | `uak decision` por dependencia nueva |

## Observability
`os.Logger` (subsystem `com.fervarg.FantasyNotch`), categorías `api`, `poller`, `ui`. Sin PII. En builds de debug: contador de requests por endpoint y timestamp de cada cambio de `points` (para medir la frescura). Sin telemetría remota.

## Rollout and rollback
Releases semver manuales en GitHub (`.zip` sin firmar). Rollback = el usuario baja la versión anterior del release. `settingsVersion` permite ignorar ajustes de versiones futuras.

## Cost
USD 0: sin servidores; la API de Sleeper es gratuita.

## Tasks
FN-001 … FN-014 en `.uak/TASKS.md`. Cada feature empieza con un test que falla (TDD) sobre `MockSleeperAPI` o fixtures.
