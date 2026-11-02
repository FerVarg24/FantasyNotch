# Runbook de FantasyNotch

Qué hacer para publicar una versión y para diagnosticar problemas. Todo lo que aquí se afirma sale de `scripts/`, `.github/workflows/`, el código y los ADR; lo que no se ha probado en un Mac real está marcado.

## Cortar un release

Los releases los crea **un humano** con un tag semver ([ADR 0004](adr/0004-unsigned-sandboxed-distribution.md)): `.zip` `arm64`, sin firmar ni notarizar. Un agente no publica.

1. **`main` en verde.** El workflow `CI` corre `bash scripts/verify.sh` en cada PR. Comprueba que el último commit de `main` pasó.
2. **Actualiza `CHANGELOG.md`.** Cambia `## [X.Y.Z] - sin publicar` por la fecha real y revisa que "Añadido" y "Notas" digan la verdad de esa versión.
3. **Ensayo local, sin publicar nada:**
   ```bash
   bash scripts/package-release.sh --dry-run
   ```
   Compila en Release, empaqueta, valida que el `.zip` contiene `FantasyNotch.app/Contents/MacOS/FantasyNotch` y lo borra. Sin `--dry-run` deja `dist/FantasyNotch-<versión>.zip`.
4. **Crea y sube el tag** (esto es lo que dispara el release):
   ```bash
   git tag vX.Y.Z
   git push origin vX.Y.Z
   ```
5. **El workflow `Release`** (`.github/workflows/release.yml`, en cada tag `v*`) instala XcodeGen, ejecuta `scripts/package-release.sh --version X.Y.Z` y crea un release **en borrador** con el `.zip` y las notas generadas.
6. **Revisa el borrador** en GitHub Releases (el `.zip` está, las notas son correctas, la versión coincide) y **publícalo a mano**.
7. **Prueba de humo en un Mac limpio** (no automatizada): descarga el `.zip` publicado, ábrelo con clic derecho → Abrir, completa el onboarding y comprueba que aparece el marcador.

**Si algo sale mal:** un tag mal puesto o un borrador erróneo se borran antes de publicar (`gh release delete vX.Y.Z` y `git push --delete origin vX.Y.Z`); no reutilices un tag que ya estuvo público, sube la siguiente versión. El rollback para los usuarios es bajar la versión anterior de GitHub Releases; `settingsVersion` permite que una versión vieja ignore ajustes escritos por una más nueva.

## Diagnosticar

### Ver los logs

Todos los mensajes usan el subsistema `com.fervarg.FantasyNotch`:

```bash
log stream --level debug --predicate 'subsystem == "com.fervarg.FantasyNotch"'
```

Los mensajes están en nivel `debug`, por eso hace falta `--level debug`. Para ver el pasado: `log show --last 30m --info --debug --predicate 'subsystem == "com.fervarg.FantasyNotch"'`.

Qué categorías hay, según el código:

| Categoría | De dónde viene | ¿En un release? |
|---|---|---|
| `api` | cliente de Sleeper y consulta del estado de los partidos | sí |
| `app` | arranque, onboarding, cambio de liga, eventos de sueño y bloqueo | **solo en builds de Debug** |
| `poller` | ciclo de polling (modo, backoff, refrescos) | **solo en builds de Debug** |

Para diagnosticar el polling o el arranque hay que compilar en Debug (`xcodebuild build` con la configuración por defecto, o desde Xcode). Los identificadores de usuario y liga se registran como `private`: en un Mac sin modo de desarrollo aparecen como `<private>`.

### Síntomas habituales

| Síntoma | Qué mirar |
|---|---|
| macOS no deja abrir la app | Es esperado en una app sin firmar: clic derecho → Abrir, o *Ajustes del Sistema → Privacidad y seguridad → Abrir de todos modos* (macOS 15 o posterior). |
| No aparece ningún marcador | ¿Hay liga configurada? Menú → *Cambiar de liga…*. ¿Es semana de bye? Se muestra "Sin matchup". ¿Sin notch en la pantalla principal? El marcador va en el título del menú de la barra, no en el notch. |
| El marcador sale como "desactualizado" | Dos refrescos seguidos fallaron (red, límite 429 o error 5xx de Sleeper). La app reintenta con backoff ×2 hasta 5 min y limpia el aviso en el primer éxito. Busca errores en la categoría `api`. |
| El marcador no se refresca cada 60 s en vivo | El modo en vivo depende del endpoint no documentado de `api.sleeper.com`. Si falla, el poller conserva el modo anterior y, tras 3 fallos seguidos, baja de en vivo a día de juego hasta que vuelva a responder. |
| El marcador se atrasa | Esperado hasta unos 2 minutos en el peor caso (caché de 60 s de Sleeper más un ciclo de 60 s). Es un cálculo, aún sin medir en un domingo de partidos. |
| "Abrir al iniciar sesión" no se activa | Puede quedar pendiente de aprobación en *Ajustes del Sistema → Elementos de inicio*; la app lo indica en el menú. Sin verificar en una app firmada ad hoc. |

### Reiniciar los ajustes y la caché

La app corre con App Sandbox, así que sus archivos viven en el contenedor:

Cierra la app y ejecuta:

```bash
defaults delete com.fervarg.FantasyNotch            # usuario, liga y versión de ajustes
rm -f ~/Library/Containers/com.fervarg.FantasyNotch/Data/Library/Application\ Support/FantasyNotch/players-v1.json
```

Si tras `defaults delete` la app sigue arrancando sin onboarding, borra el archivo de preferencias del contenedor: `rm -f ~/Library/Containers/com.fervarg.FantasyNotch/Data/Library/Preferences/com.fervarg.FantasyNotch.plist`. Estas rutas salen del identificador de la app y de la configuración del sandbox, pero **no se han probado en un Mac real**.

Tras borrar los ajustes, la app vuelve al onboarding en el siguiente arranque. La caché de jugadores se vuelve a descargar sola (como máximo una vez al día).

### Pruebas en el repositorio

```bash
bash scripts/verify.sh                                                         # todo: swift test + xcodegen + xcodebuild
swift test --package-path Packages/SleeperKit                                  # solo SleeperKit
swift test --package-path Packages/SleeperKit --filter MatchupPollerTests      # un grupo
```

## Pendiente de verificar

Cosas que este runbook no puede afirmar porque nadie las ha comprobado en un equipo real: el comportamiento de sueño, bloqueo de pantalla y monitor externo; la activación de "Abrir al iniciar sesión" con una firma ad hoc; las rutas del contenedor del sandbox para reiniciar ajustes y caché; la frescura real frente a la teórica; y los valores de estado en vivo de los partidos (`in_game`) en el endpoint no documentado.
