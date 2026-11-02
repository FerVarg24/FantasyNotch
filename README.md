# FantasyNotch

El marcador de tu matchup de **Sleeper** (Fantasy Football) en vivo, en el notch de tu MacBook. Sin abrir el navegador ni la app del teléfono.

- **Compacto:** tu avatar a la izquierda del notch y `mis puntos – puntos del rival` a la derecha, con un decimal.
- **Expandido** (al pasar el cursor o hacer clic): ambos equipos con avatar, nombre y total, y cada titular con sus puntos y si está pendiente, jugando o terminado.
- **Barra de menú:** refrescar ahora, cambiar de liga, abrir al iniciar sesión y salir. Si tu pantalla principal no tiene notch, el marcador se muestra en el título del menú.

> **Captura:** pendiente. Todavía no hay una captura de la app en el repositorio.

## Requisitos

- macOS 14 o posterior, en un Mac con Apple Silicon (el release es solo `arm64`).
- Una cuenta de Sleeper con al menos una liga de NFL en la temporada actual. Solo necesitas tu nombre de usuario; no hay contraseñas ni inicio de sesión.

## Instalación (versión sin firmar)

Los releases se publican en [GitHub Releases](../../releases) como un `.zip` **sin firmar ni notarizar** (ver [ADR 0004](docs/adr/0004-unsigned-sandboxed-distribution.md)), así que macOS mostrará una advertencia la primera vez.

1. Descarga `FantasyNotch-<versión>.zip` del release, descomprímelo y mueve `FantasyNotch.app` a `/Applications`.
2. Haz **clic derecho sobre la app → Abrir**, y confirma en el diálogo.
3. Si macOS no ofrece el botón *Abrir* (en macOS 15 o posterior suele pasar), intenta abrirla una vez, y luego ve a **Ajustes del Sistema → Privacidad y seguridad**, baja hasta el aviso sobre FantasyNotch y pulsa **Abrir de todos modos**.
4. En el primer arranque, escribe tu usuario de Sleeper y elige la liga. La app no necesita reiniciarse.

La app vive en la barra de menú y no aparece en el Dock.

## Compilar desde el código

Necesitas Xcode y [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).

```bash
bash scripts/verify.sh          # swift test + xcodegen + xcodebuild
open FantasyNotch.xcodeproj     # después de verify.sh (o de `xcodegen generate`)
```

El proyecto de Xcode se genera desde `project.yml`; no se versiona. Para empaquetar un `.zip` local sin publicar nada: `bash scripts/package-release.sh --dry-run`.

## Cómo está hecho

- `App/`: la app SwiftUI (notch, menú de la barra, onboarding, ajustes, integración).
- `Packages/SleeperKit/`: el cliente de Sleeper, la caché, el polling y la lógica de presentación. Se prueba con `swift test` sin la app.
- Decisiones de diseño en [`docs/adr/`](docs/adr/) y especificación en [`docs/specs/001-mvp/`](docs/specs/001-mvp/).

## Privacidad

- **Sin backend, sin cuentas, sin telemetría.** La app habla directamente con Sleeper desde tu Mac.
- Lo único tuyo que guarda, en local, es tu nombre de usuario de Sleeper (que es público), tu ID de usuario y el ID de tu liga, en las preferencias de la app.
- También guarda en disco una copia mínima del catálogo de jugadores de Sleeper (ID, nombre, posición y equipo) para no descargarlo más de una vez al día.
- Se ejecuta con **App Sandbox** y solo con permiso de red saliente.
- Se conecta solo a tres hosts de Sleeper: `api.sleeper.app` (API pública y documentada), `api.sleeper.com` (estado de los partidos; es un endpoint **no documentado** de Sleeper y puede cambiar sin aviso) y `sleepercdn.com` (el CDN público desde el que se cargan los avatares).

## Limitaciones conocidas

- El estado "en vivo" de un partido depende de ese endpoint no documentado. Algunos valores (por ejemplo `in_game`) nunca se han observado en un partido real; los casos en vivo de las pruebas son sintéticos.
- El marcador puede tardar hasta unos 2 minutos en reflejar un cambio: Sleeper cachea `/matchups` 60 s y la app lo consulta cada 60 s en vivo. Es un cálculo del peor caso, aún sin medir en un domingo de partidos.
- Los textos están solo en español por ahora.

## Licencia

[MIT](LICENSE) © 2026 FerVarg24.
