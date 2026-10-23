# PROJECT · FantasyNotch (marathon mode)

> The project constitution. Humans change it by reviewed PR. uak reads the last block from the remote `main`.

## Purpose
Para jugadores de Fantasy Football en **Sleeper** que usan una MacBook con notch: ver el marcador de su matchup de la semana **en vivo, en el notch**, sin abrir el navegador ni la app del teléfono.
Resultado medible: el marcador del notch refleja un cambio de puntos de Sleeper en ≤ 15 s (más la latencia propia de Sleeper), con impacto de energía "bajo" en el Monitor de Actividad.

## Non-negotiable principles
1. **Privado por diseño:** sin backend, sin cuentas, sin telemetría. El único dato del usuario es su username de Sleeper (público), guardado localmente. No hay secretos en el proyecto.
2. Nothing reaches `main` without green CI and human CODEOWNERS approval.
3. Every decision that is costly to reverse has an ADR (`docs/adr/`): target de macOS, dependencias nuevas, formato de caché, estrategia de polling.
4. **Buen ciudadano de la API de Sleeper:** ≤ 1 llamada cada 15 s por liga con partidos en vivo, polling largo o pausado fuera de juego, `/players/nfl` como máximo 1 vez al día, backoff exponencial ante 429/5xx.
5. **Discreta:** nunca roba el foco, no tapa contenido fuera del área del notch y en Macs sin notch cae a la barra de menú.
6. **MIT y código limpio:** no se copia código de proyectos GPL (MenuScores, boring.notch); solo se usan como referencia de arquitectura.

## Stack
| Capa | Elección |
|---|---|
| Lenguaje | Swift 6 (strict concurrency) |
| UI | SwiftUI + AppKit donde haga falta; `MenuBarExtra`, `LSUIElement` (sin ícono en el Dock) |
| Notch | DynamicNotchKit (SPM, MIT) |
| Red | `URLSession` async/await + `Codable`, sin dependencias |
| Persistencia | `@AppStorage` (ajustes) + JSON en Application Support (caché de jugadores) |
| Arranque | `SMAppService` (abrir al iniciar sesión) |
| Proyecto | XcodeGen (`project.yml`); el `.xcodeproj` no se versiona |
| Tests | Swift Testing + fixtures JSON reales de Sleeper (sin red en los tests) |
| Formato | `swift-format` |
| CI | GitHub Actions, runner macOS |
| Target mínimo | macOS 14 Sonoma, Apple Silicon |

## Estructura
```text
project.yml                 # XcodeGen
App/                        # target de la app: SwiftUI, notch, menu bar, ajustes
Packages/SleeperKit/        # Swift Package sin UI
  Sources/SleeperKit/API/       # cliente Sleeper, endpoints, modelos Codable
  Sources/SleeperKit/Domain/    # matchup, puntajes, proyecciones
  Sources/SleeperKit/Polling/   # scheduler adaptativo (actor)
  Tests/SleeperKitTests/Fixtures/
docs/adr/
```

## Verify
```bash
swift test --package-path Packages/SleeperKit
xcodegen generate && xcodebuild -scheme FantasyNotch -destination 'platform=macOS' build
```

## Alcance del MVP
- Onboarding: el usuario escribe su username de Sleeper y elige una liga.
- Vista compacta en el notch: avatar + marcador propio vs rival, en verde si va ganando y en rojo si va perdiendo.
- Vista expandida (hover/clic): ambos equipos, puntos y proyección, jugadores pendientes de jugar.
- Polling adaptativo: 15 s en vivo, minutos entre partidos, 30–60 min sin juegos, pausa al dormir la Mac.
- Menú en la barra: cambiar de liga, refrescar, abrir al iniciar sesión, salir.

**Fuera de alcance (por ahora):** otras plataformas (ESPN, Yahoo), varias ligas a la vez en el notch, notificaciones, iOS/widgets, firma y notarización, Sparkle.

## Non-functional requirements (measurable)
| Attribute | Target | Measured by |
|---|---|---|
| Frescura | cambio visible ≤ 15 s tras la actualización en Sleeper | log con timestamp de respuesta vs cambio de `points` |
| CPU | < 1 % promedio con polling en vivo | Instruments / Monitor de Actividad |
| Memoria | < 100 MB residentes | Instruments |
| Energía | impacto "bajo" en Monitor de Actividad | revisión manual en un día de juegos |
| Red | ≤ 4 llamadas/min por liga en vivo; `/players/nfl` ≤ 1/día | contador de requests en logs de debug |
| Arranque | < 2 s hasta mostrar el último marcador en caché | medición manual / `os_signpost` |
| Coverage | ≥ 80 % en `SleeperKit` | `swift test --enable-code-coverage` |
| Cost | USD 0 (sin servidores) | — |

## Environments and ownership
| Env | URL | Deploys | Secrets in |
|---|---|---|---|
| dev | local (Xcode) | build local | ninguno |
| release | GitHub Releases (`.zip` sin firmar) | a human, via a semver tag | ninguno |

CODEOWNERS: `* → @FerVarg24` · Mantenedor: @FerVarg24 · Runbook: `docs/runbook.md` (pendiente).

## Executable config
```text
Mode: marathon
Backlog-Proposed-Epoch: 0
Backlog-Approved: yes
Autonomy: yes
Auto-Merge: no
Review-Mode: gh
Plan-Channel: main
Freeze-Epoch: 0
Lease-Seconds: 14400
Review-Lease-Seconds: 86400
Events-Per-Session: 150
Checkpoint-Percent: 60
Merge-Lease-Seconds: 1800
Merge-Wait-Seconds: 180
Max-Parallel-Subagents: 3
Opus-Subagents-Per-Session: 4
Pace: auto
Subagent-Hard-Cap: 4
Strong-Hard-Cap: 4
Subagents-Per-Session: 30
Subagents-Per-Machine: 6
Subagent-Burst-Per-Minute: 6
Max-Worktree-Agents: 4
Blackbox: on
Additive-Paths: -
```
