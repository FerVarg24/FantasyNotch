# TASKS · stateless backlog

State lives on the `claims` branch (`uak status`); this file holds only tasks. IDs are `FN-NNN`. Spec: `docs/specs/001-mvp/` · ADRs: `docs/adr/`.
Priority is `P0/P1/P2`. Type is `setup/contract/spike/feature/bug/integration/demo/docs`. Check the graph with `uak graph`.

Format rules (the CLI parses them):
- `Depends on:` real IDs separated by commas, or `None`. It blocks the claim until they are INTEGRATED. Text in parentheses is ignored.
- `Uses contract:` soft dependency. It never blocks; it routes contract notices. Work against the mock.
- `Paths:` relative paths separated by commas; directories end in `/`. Reserve everything you will touch.
- `Verify:` one exact command that exits 0 when the task is done.
- `Estimate:` minutes or hours, used for the critical path.

## FN-001 · Esqueleto: proyecto XcodeGen, app de barra de menú, paquete SleeperKit y CI

- **Type:** setup
- **Priority:** P0
- **Estimate:** 2 h
- **Rubric / Spec:** ADR 0001, 0002, 0004 · `docs/specs/001-mvp/spec.md`
- **Depends on:** None
- **Uses contract:** None
- **Related:** FN-002
- **Paths:** project.yml, App/FantasyNotchApp.swift, App/Info.plist, App/FantasyNotch.entitlements, App/Assets.xcassets/, Packages/SleeperKit/Package.swift, Packages/SleeperKit/Sources/SleeperKit/SleeperKit.swift, Packages/SleeperKit/Sources/SleeperKitMocks/SleeperKitMocks.swift, Packages/SleeperKit/Tests/SleeperKitTests/SmokeTests.swift, .github/workflows/ci.yml, .swift-format, scripts/verify.sh, LICENSE
- **Freeze-Allowed:** no
- **Acceptance:**
  - `project.yml`: target `FantasyNotch` (macOS 14, arm64, `LSUIElement`, App Sandbox con solo `network.client`, firma ad-hoc), dependencia DynamicNotchKit `exactVersion: 1.1.0` y paquete local `Packages/SleeperKit`
  - `Package.swift` (swift-tools 6.0, macOS 14): targets `SleeperKit`, `SleeperKitMocks` (con `resources: [.process("Fixtures")]`) y `SleeperKitTests`; strict concurrency
  - La app arranca con un `MenuBarExtra` (ítem "Salir") y sin ícono en el Dock
  - `scripts/verify.sh` corre `swift test --package-path Packages/SleeperKit` + `xcodegen generate` + `xcodebuild build` y sale 0
  - `.github/workflows/ci.yml` corre `scripts/verify.sh` en `macos-latest` en cada PR
  - `LICENSE` MIT con copyright de FerVarg24
- **Verify:** `bash scripts/verify.sh`
- **Next step:** Escribir `Packages/SleeperKit/Package.swift` y un `SmokeTests.swift` que falle

## FN-002 · Contrato: modelos de Sleeper, protocolo SleeperAPI, MatchupSnapshot, mocks y fixtures

- **Type:** contract
- **Priority:** P0
- **Estimate:** 3 h
- **Rubric / Spec:** `docs/specs/001-mvp/spec.md` · `docs/specs/001-mvp/plan.md` §Contracts
- **Depends on:** FN-001
- **Uses contract:** None
- **Related:** FN-003, FN-005, FN-007
- **Paths:** Packages/SleeperKit/Sources/SleeperKit/API/Models/, Packages/SleeperKit/Sources/SleeperKit/API/SleeperAPI.swift, Packages/SleeperKit/Sources/SleeperKit/Domain/Models/, Packages/SleeperKit/Sources/SleeperKitMocks/Fixtures/, Packages/SleeperKit/Sources/SleeperKitMocks/MockSleeperAPI.swift, Packages/SleeperKit/Sources/SleeperKitMocks/MatchupSnapshot+Preview.swift, Packages/SleeperKit/Tests/SleeperKitTests/ModelDecodingTests.swift, docs/DESIGN.md
- **Freeze-Allowed:** no
- **Acceptance:**
  - Modelos `Codable` para `NFLState`, `SleeperUser`, `League`, `LeagueUser`, `Roster`, `Matchup`, `Player` con opcionales donde Sleeper omite campos
  - `SleeperAPI` y `MatchupSnapshot`/`TeamScore`/`StarterLine`/`PlayStatus` exactamente como en plan.md §Contracts (cambios = `uak msg impact:FN-002 --kind contract`)
  - Fixtures JSON reales y anonimizados (sin usernames reales) de cada endpoint en `SleeperKitMocks/Fixtures/`, incluyendo un matchup en vivo, una semana de bye y un JSON inválido
  - `MockSleeperAPI` sirve los fixtures; `MatchupSnapshot.preview*` para previews de SwiftUI
  - Un JSON inválido produce un error tipado, sin crash
  - `docs/DESIGN.md` provisional: medidas de la vista compacta/expandida, colores (ganando/perdiendo/empate/desactualizado), tipografía monoespaciada para números
- **Verify:** `swift test --package-path Packages/SleeperKit --filter ModelDecodingTests`
- **Next step:** Grabar fixtures con `curl` de `/state/nfl` y de una liga pública, y escribir `ModelDecodingTests` que fallen

## FN-003 · Spike: proyecciones, estado de partidos y frecuencia de actualización en Sleeper

- **Type:** spike
- **Priority:** P0
- **Estimate:** 1 h
- **Rubric / Spec:** `docs/specs/001-mvp/spec.md` §Open questions · ADR 0003
- **Depends on:** None
- **Uses contract:** None
- **Related:** FN-002, FN-007, FN-008
- **Paths:** docs/spikes/003-sleeper-live-data.md
- **Freeze-Allowed:** no
- **Acceptance:**
  - Documenta si existe un endpoint usable para proyecciones y para el estado/horario de los partidos NFL (URL, ejemplo de respuesta, si es oficial o no documentado, riesgo)
  - Propone cómo decidir "hay partidos en vivo" para el poller y cómo derivar `PlayStatus` por jugador
  - Incluye un script `curl` para medir la frecuencia de cambio de `points` un domingo, y su resultado si ya se midió
  - Recomendación final: qué entra en el MVP y qué queda fuera
- **Verify:** `test -s docs/spikes/003-sleeper-live-data.md`
- **Next step:** Consultar `/state/nfl` y `/league/{id}/matchups/{week}` de una liga pública y anotar los campos

## FN-004 · Spike: vista compacta de DynamicNotchKit y comportamiento sin notch

- **Type:** spike
- **Priority:** P0
- **Estimate:** 45 min
- **Rubric / Spec:** `docs/specs/001-mvp/spec.md` §Open questions · ADR 0002
- **Depends on:** None
- **Uses contract:** None
- **Related:** FN-009, FN-011
- **Paths:** docs/spikes/004-dynamicnotchkit.md
- **Freeze-Allowed:** no
- **Acceptance:**
  - Documenta la API de DynamicNotchKit 1.1.0 para contenido compacto a izquierda/derecha del notch, expandir por hover/clic y cerrar
  - Documenta qué pasa en una pantalla sin notch o con monitor externo como principal
  - Prototipo en un directorio temporal (no versionado); el doc incluye el snippet mínimo que funcionó y capturas o descripción
- **Verify:** `test -s docs/spikes/004-dynamicnotchkit.md`
- **Next step:** Crear un paquete temporal con DynamicNotchKit y mostrar texto fijo en modo compacto

## FN-005 · Cliente LiveSleeperAPI con timeouts, límites y errores tipados

- **Type:** feature
- **Priority:** P0
- **Estimate:** 4 h
- **Rubric / Spec:** `docs/specs/001-mvp/spec.md` §Onboarding, §Actualización · plan.md §Threat model
- **Depends on:** FN-002
- **Uses contract:** None
- **Related:** FN-008, FN-010
- **Paths:** Packages/SleeperKit/Sources/SleeperKit/API/Client/, Packages/SleeperKit/Sources/SleeperKit/API/SleeperAPI.swift, Packages/SleeperKit/Tests/SleeperKitTests/API/
- **Freeze-Allowed:** no
- **Acceptance:**
  - Implementa `SleeperAPI` con `URLSession` async/await contra `https://api.sleeper.app/v1` (host fijo; rechaza otros hosts)
  - Timeout 10 s (30 s para `/players/nfl`), límite de respuesta 20 MB, mapea 404 → `.notFound`, 429 → `.rateLimited`, 5xx → `.server`
  - Amplía `SleeperAPIError` (contrato de FN-002) con `rateLimited`, `server(status:)`, `responseTooLarge` e `invalidRequest(detail:)`; avisar con `uak msg related:FN-005 --kind contract` antes de hacer push
  - Tests con `URLProtocol` stub sobre los fixtures; ninguna llamada real a la red en tests
  - El username y los IDs se loguean con `privacy: .private`
- **Verify:** `swift test --package-path Packages/SleeperKit --filter LiveSleeperAPITests`
- **Next step:** Escribir un test que falle para `user(username:)` con un `URLProtocol` stub

## FN-006 · Caché de jugadores en disco (máx. 1 descarga al día)

- **Type:** feature
- **Priority:** P0
- **Estimate:** 3 h
- **Rubric / Spec:** `docs/specs/001-mvp/spec.md` §Actualización · ADR 0003
- **Depends on:** FN-002
- **Uses contract:** None
- **Related:** FN-007, FN-008
- **Paths:** Packages/SleeperKit/Sources/SleeperKit/Cache/, Packages/SleeperKit/Tests/SleeperKitTests/Cache/
- **Freeze-Allowed:** no
- **Acceptance:**
  - `PlayerCache` guarda solo `player_id`, `full_name`, `position`, `team` + `fetchedAt` en `Application Support/FantasyNotch/players-v1.json`
  - Si el archivo tiene menos de 24 h no llama a la API; si falla la descarga usa la copia vieja
  - Directorio y reloj inyectables en tests
- **Verify:** `swift test --package-path Packages/SleeperKit --filter PlayerCacheTests`
- **Next step:** Escribir un test que falle: con caché de 1 h no se llama a `players()`

## FN-007 · MatchupResolver: de datos crudos a MatchupSnapshot

- **Type:** feature
- **Priority:** P0
- **Estimate:** 4 h
- **Rubric / Spec:** `docs/specs/001-mvp/spec.md` §Vista compacta, §Vista expandida
- **Depends on:** FN-002
- **Uses contract:** FN-003
- **Related:** FN-006, FN-009
- **Paths:** Packages/SleeperKit/Sources/SleeperKit/Domain/Resolver/, Packages/SleeperKit/Tests/SleeperKitTests/Domain/
- **Freeze-Allowed:** no
- **Acceptance:**
  - Dado `userId`, `rosters`, `leagueUsers`, `matchups` y jugadores, encuentra el roster del usuario y su rival por `matchup_id`
  - Arma `TeamScore` con nombre de equipo (`metadata.team_name` o `display_name`), avatar (`sleepercdn.com/avatars/thumbs/…`), puntos y titulares con sus puntos
  - Semana de bye o sin `matchup_id` → `opponent == nil`
  - `PlayStatus` según la recomendación del spike FN-003 (o `.unknown` si no hay datos)
- **Verify:** `swift test --package-path Packages/SleeperKit --filter MatchupResolverTests`
- **Next step:** Escribir un test que falle con el fixture de matchup en vivo

## FN-008 · MatchupPoller: polling adaptativo, backoff y pausa

- **Type:** feature
- **Priority:** P0
- **Estimate:** 5 h
- **Rubric / Spec:** `docs/specs/001-mvp/spec.md` §Actualización · ADR 0003
- **Depends on:** FN-002, FN-003
- **Uses contract:** FN-005, FN-006, FN-007
- **Related:** FN-011
- **Paths:** Packages/SleeperKit/Sources/SleeperKit/Polling/, Packages/SleeperKit/Tests/SleeperKitTests/Polling/
- **Freeze-Allowed:** no
- **Acceptance:**
  - `actor MatchupPoller` publica `AsyncStream<MatchupSnapshot>`; reloj, API y resolver inyectables
  - Intervalos de ADR 0003 (15 s en vivo / 5 min día de juego / 30 min sin juegos); nunca dos llamadas a `/matchups` con menos de 15 s
  - Backoff ×2 con tope de 5 min ante 429/5xx; `isStale = true` tras 2 refrescos fallidos
  - `pause()`/`resume()` (resume refresca de inmediato); `refreshNow()`
  - En debug, log del instante en que cambian los `points` (medición de frescura)
- **Verify:** `swift test --package-path Packages/SleeperKit --filter MatchupPollerTests`
- **Next step:** Escribir un test que falle con reloj falso: en vivo, 2 ticks a 15 s = 2 llamadas

## FN-009 · Vistas del notch: compacta y expandida

- **Type:** feature
- **Priority:** P0
- **Estimate:** 5 h
- **Rubric / Spec:** `docs/specs/001-mvp/spec.md` §Vista compacta, §Vista expandida · `docs/DESIGN.md`
- **Depends on:** FN-002, FN-004
- **Uses contract:** FN-007
- **Related:** FN-011
- **Paths:** App/Notch/
- **Freeze-Allowed:** no
- **Acceptance:**
  - Compacta: avatar a la izquierda, `mis – rival` con 1 decimal a la derecha; verde/rojo/blanco según el marcador; estado "Sin matchup" y "desactualizado"
  - Expandida (hover/clic): ambos equipos con avatar, nombre, total y titulares con puntos; los pendientes marcados
  - Un `NotchController` que recibe `MatchupSnapshot` y muestra/actualiza/cierra la notch con DynamicNotchKit
  - Previews de SwiftUI con `MatchupSnapshot.preview*`; tests de la lógica de color/formato
- **Verify:** `bash scripts/verify.sh`
- **Next step:** Escribir el test del formateo `112.4 – 98.7` y el color por estado

## FN-010 · Onboarding, ajustes y menú de la barra

- **Type:** feature
- **Priority:** P0
- **Estimate:** 5 h
- **Rubric / Spec:** `docs/specs/001-mvp/spec.md` §Onboarding, §Barra de menú
- **Depends on:** FN-002
- **Uses contract:** FN-005
- **Related:** FN-011
- **Paths:** App/Onboarding/, App/MenuBar/, App/Settings/
- **Freeze-Allowed:** no
- **Acceptance:**
  - Onboarding: campo de username → lista de ligas NFL de la temporada actual → elegir una; errores inline (no existe / sin red)
  - Persiste `sleeperUserId`, `sleeperUsername`, `leagueId`, `settingsVersion = 1` con `@AppStorage`
  - Menú: refrescar ahora, cambiar de liga, abrir al iniciar sesión (`SMAppService`), salir
  - Funciona contra `MockSleeperAPI` en previews; ViewModel testeable
- **Verify:** `bash scripts/verify.sh`
- **Next step:** Crear `OnboardingViewModel` con un test que falle para username inexistente

## FN-011 · Integración: AppModel, sueño/reactivación y respaldo sin notch

- **Type:** integration
- **Priority:** P0
- **Estimate:** 5 h
- **Rubric / Spec:** `docs/specs/001-mvp/spec.md` (todos los criterios) · plan.md §Design
- **Depends on:** FN-005, FN-006, FN-007, FN-008, FN-009, FN-010, FN-017
- **Uses contract:** None
- **Related:** FN-013
- **Paths:** App/AppModel/, App/System/, App/FantasyNotchApp.swift
- **Freeze-Allowed:** no
- **Acceptance:**
  - `AppModel` (@Observable) crea `LiveSleeperAPI` + `PlayerCache` + `MatchupResolver` + `ScoresGameWindow` + `MatchupPoller` y conecta el stream al `NotchController`. Aquí vive el puente entre FN-007 y FN-008: `MatchupResolver` → `MatchupResolving` y `TeamPlayState` → `TeamGameState`
  - Sin liga configurada abre el onboarding; al elegir liga arranca el poller sin reiniciar
  - `NSWorkspace` sleep/wake y bloqueo de pantalla → `pause()`/`resume()`
  - Sin notch en la pantalla principal → marcador en el título del `MenuBarExtra`
  - Prueba manual documentada en el PR: liga real, semana actual, marcador visible
- **Verify:** `bash scripts/verify.sh`
- **Next step:** Crear `AppModel` con un test que falle: sin `leagueId` el estado es `.onboarding`

## FN-012 · Workflow de release sin firmar

- **Type:** setup
- **Priority:** P1
- **Estimate:** 2 h
- **Rubric / Spec:** ADR 0004
- **Depends on:** FN-001
- **Uses contract:** None
- **Related:** FN-013
- **Paths:** .github/workflows/release.yml, scripts/package-release.sh
- **Freeze-Allowed:** no
- **Acceptance:**
  - Al pushear un tag `v*` (lo crea un humano) compila Release arm64, empaqueta `FantasyNotch.app` en `.zip` y lo sube a GitHub Releases como borrador
  - `scripts/package-release.sh` funciona igual en local
- **Verify:** `bash scripts/package-release.sh --dry-run`
- **Next step:** Escribir `scripts/package-release.sh` con `xcodebuild archive` y `ditto -c -k`

## FN-013 · Documentación: README, CHANGELOG y runbook

- **Type:** docs
- **Priority:** P1
- **Estimate:** 2 h
- **Rubric / Spec:** PROJECT.md §Environments
- **Depends on:** FN-011, FN-012
- **Uses contract:** None
- **Related:** None
- **Paths:** README.md, CHANGELOG.md, docs/runbook.md
- **Freeze-Allowed:** no
- **Acceptance:**
  - README: qué es, captura, instalación sin firmar (clic derecho → Abrir), build desde el código, privacidad, licencia
  - CHANGELOG con la entrada `0.1.0`
  - Runbook: cómo cortar un release, cómo diagnosticar con `log stream --predicate subsystem == "com.fervarg.FantasyNotch"`
- **Verify:** `test -s README.md && test -s CHANGELOG.md && test -s docs/runbook.md`
- **Next step:** Reescribir `README.md`

## FN-014 · Accesibilidad y localización es/en

- **Type:** feature
- **Priority:** P2
- **Estimate:** 3 h
- **Rubric / Spec:** `docs/specs/001-mvp/spec.md` §Non-functional
- **Depends on:** FN-011
- **Uses contract:** None
- **Related:** None
- **Paths:** App/Notch/, App/Onboarding/, App/MenuBar/, App/Settings/, App/Localizable.xcstrings
- **Freeze-Allowed:** no
- **Acceptance:**
  - Etiquetas de VoiceOver en la vista expandida ("Vas ganando 112.4 a 98.7")
  - Respeta "Reducir movimiento"
  - Textos en `Localizable.xcstrings` en español e inglés
- **Verify:** `bash scripts/verify.sh`
- **Next step:** Agregar `accessibilityLabel` a la vista compacta

## FN-015 · PlayerCache: formato antiguo válido y ruta compatible con sandbox (followup de FN-006)

- **Type:** chore
- **Priority:** P1
- **Estimate:** 1 h
- **Rubric / Spec:** ADR 0003 · notas de la revisión de FN-006 (#29)
- **Depends on:** FN-006
- **Uses contract:** None
- **Related:** FN-011
- **Paths:** Packages/SleeperKit/Sources/SleeperKit/Cache/, Packages/SleeperKit/Tests/SleeperKitTests/Cache/
- **Freeze-Allowed:** no
- **Acceptance:**
  - Test: un `players-v1.json` con forma válida pero campos de otra versión (claves extra o `fetchedAt` en otro formato) se trata sin crash; si no decodifica, equivale a "sin caché"
  - Test: `PlayerCache.defaultDirectory` cuelga de `URL.applicationSupportDirectory` y termina en `FantasyNotch` (sin rutas de HOME fijas, para que funcione dentro del sandbox)
- **Verify:** `swift test --package-path Packages/SleeperKit --filter PlayerCacheTests`
- **Next step:** Escribir el test de archivo con claves extra y `fetchedAt` inválido

## FN-016 · Polling en vivo a 60 s según el spike FN-003 (followup de FN-008)

- **Type:** chore
- **Priority:** P1
- **Estimate:** 1 h
- **Rubric / Spec:** `docs/spikes/003-sleeper-live-data.md` §3 y §4 · ADR 0003 · nota de la revisión de FN-008
- **Depends on:** FN-008
- **Uses contract:** None
- **Related:** FN-011
- **Paths:** Packages/SleeperKit/Sources/SleeperKit/Polling/, Packages/SleeperKit/Tests/SleeperKitTests/Polling/, docs/adr/0003-adaptive-polling.md
- **Freeze-Allowed:** no
- **Acceptance:**
  - `PollingMode.live` y `minimumMatchupGap` pasan de 15 s a 60 s, definidos en un solo lugar; los demás intervalos (5 min día de juego, 30 min sin partidos) y el backoff ×2 con tope de 5 min no cambian
  - Los tests de `MatchupPollerTests` que fijan 15 s se actualizan a 60 s: es un cambio de criterio autorizado por esta tarea, no se relaja ningún otro test
  - ADR 0003: la tabla dice 60 s en vivo para `/matchups` y la sección de alternativas explica por qué se descarta 15 s (Sleeper cachea la respuesta 60 s, spike 003 §3); se anota que `/scores` a 15 s queda para cuando exista `GameWindowProviding`
- **Verify:** `swift test --package-path Packages/SleeperKit --filter MatchupPollerTests`
- **Next step:** Cambiar los tests de intervalo en vivo a 60 s y verlos fallar

## FN-017 · Proveedor real de ventana de juego: consulta a `scores` (GameWindowProviding)

- **Type:** feature
- **Priority:** P0
- **Estimate:** 4 h
- **Rubric / Spec:** `docs/spikes/003-sleeper-live-data.md` §1.3 y §2 · ADR 0003 · plan.md §Threat model (host nuevo)
- **Depends on:** FN-005, FN-008
- **Uses contract:** FN-008, FN-003
- **Related:** FN-011, FN-016
- **Paths:** Packages/SleeperKit/Sources/SleeperKit/API/Client/ScoresClient.swift, Packages/SleeperKit/Sources/SleeperKit/API/Client/ScoresGameWindow.swift, Packages/SleeperKit/Tests/SleeperKitTests/API/ScoresClientTests.swift, Packages/SleeperKit/Tests/SleeperKitTests/API/ScoresGameWindowTests.swift
- **Freeze-Allowed:** no
- **Acceptance:**
  - `ScoresClient` pide `GET https://api.sleeper.com/scores/nfl/regular/{season}/{week}` (endpoint **no documentado**, otro host que `LiveSleeperAPI`): host fijo `api.sleeper.com` que rechaza otros hosts y redirecciones, segmentos de ruta validados como en `LiveSleeperAPI`, timeout 10 s, límite 20 MB, sin cookies ni caché, mismos errores tipados de `SleeperAPIError`, IDs con `privacy: .private`. No modifica `LiveSleeperAPI` ni su host `api.sleeper.app`
  - Decodifica solo los campos que usa (`status`, `start_time`, `metadata.home_team`, `away_team`, `is_in_progress`, `is_over`, `has_started`, `canceled`), todos opcionales: un cambio de forma da `SleeperAPIError.decoding`, nunca un crash
  - `ScoresGameWindow: GameWindowProviding` con reloj inyectable, según spike 003 §2: `.live` si algún partido tiene `is_in_progress == true` o `status == "in_game"`; `.gameDay` si hay partidos con `start_time` en las próximas 24 h o `has_started` sin `is_over`; `.idle` en otro caso. `teamStates` por código de equipo (`home_team`/`away_team`): `.inProgress`, `.preGame` u `.over`
  - Si `scores` falla, `window(forWeek:)` lanza y el poller conserva el modo anterior (FN-008). Función pura de respaldo por horario (domingo 12:00–24:00 ET, jueves y lunes 20:00–24:00 ET → `.gameDay`) que nunca devuelve `.live`
  - Tests con `URLProtocol` stub y JSON incrustado con la forma que documenta el spike; ninguna llamada real a la red en tests. El estado `in_game`, el reloj y el down & distance nunca se observaron en un partido en vivo: marcarlos "sin verificar" en el PR
  - `security-reviewer` revisa el PR (host nuevo y endpoint no documentado); un hallazgo HIGH bloquea
- **Verify:** `swift test --package-path Packages/SleeperKit --filter Scores`
- **Next step:** Escribir un test que falle: un partido con `is_in_progress: true` da `.live`

## FN-018 · Spec y plan: frescura y mínimo entre llamadas a 60 s (followup de FN-016)

- **Type:** chore
- **Priority:** P1
- **Estimate:** 30 min
- **Rubric / Spec:** ADR 0003 (enmendado en FN-016) · spike FN-003 §3 · decisión del humano de actualizar el spec
- **Depends on:** FN-016
- **Uses contract:** None
- **Related:** None
- **Paths:** docs/specs/001-mvp/spec.md, docs/specs/001-mvp/plan.md
- **Freeze-Allowed:** no
- **Acceptance:**
  - `spec.md` §Non-functional, línea "Frescura": ya no promete ≤ 15 s; dice ≤ 60 s en el caso típico y ≤ 120 s en el peor (caché de 60 s de Sleeper más un ciclo de 60 s), a confirmar con la medición del spike FN-003
  - `plan.md` fila "Denial of service": la prueba dice "nunca < 60 s entre llamadas a `/matchups`"
  - `git grep -n '15 s' docs/specs/001-mvp/` no devuelve nada que describa el intervalo de `/matchups` (la línea de `spec.md` §Actualización ya dice 60 s)
  - No se toca `.uak/PROJECT.md` (es del humano; sigue con 15 s en las líneas 7, 13, 54 y 62)
- **Verify:** `! git grep -n -E 'Frescura: cambio visible ≤ 15|nunca < 15 s' -- docs/specs/001-mvp/`
- **Next step:** Reescribir la línea de Frescura en `spec.md`
