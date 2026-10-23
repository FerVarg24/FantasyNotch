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
- **Paths:** Packages/SleeperKit/Sources/SleeperKit/API/Models/, Packages/SleeperKit/Sources/SleeperKit/API/SleeperAPI.swift, Packages/SleeperKit/Sources/SleeperKit/Domain/Models/, Packages/SleeperKit/Sources/SleeperKitMocks/, Packages/SleeperKit/Tests/SleeperKitTests/ModelDecodingTests.swift, docs/DESIGN.md
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
- **Paths:** Packages/SleeperKit/Sources/SleeperKit/API/Client/, Packages/SleeperKit/Tests/SleeperKitTests/API/
- **Freeze-Allowed:** no
- **Acceptance:**
  - Implementa `SleeperAPI` con `URLSession` async/await contra `https://api.sleeper.app/v1` (host fijo; rechaza otros hosts)
  - Timeout 10 s (30 s para `/players/nfl`), límite de respuesta 20 MB, mapea 404 → `.notFound`, 429 → `.rateLimited`, 5xx → `.server`
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
- **Depends on:** FN-005, FN-006, FN-007, FN-008, FN-009, FN-010
- **Uses contract:** None
- **Related:** FN-013
- **Paths:** App/AppModel/, App/System/, App/FantasyNotchApp.swift
- **Freeze-Allowed:** no
- **Acceptance:**
  - `AppModel` (@Observable) crea `LiveSleeperAPI` + `PlayerCache` + `MatchupResolver` + `MatchupPoller` y conecta el stream al `NotchController`
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
