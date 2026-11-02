# Changelog

Formato basado en [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/) y versionado [semántico](https://semver.org/lang/es/).

## [0.1.0] - sin publicar

Primera versión. Todavía no se ha cortado ningún release ni existe el tag `v0.1.0`; la fecha se añade al publicarla (ver [`docs/runbook.md`](docs/runbook.md)).

### Añadido

- **Marcador en el notch:** vista compacta (avatar y `mis puntos – puntos del rival`, con un decimal) y vista expandida (ambos equipos y cada titular con sus puntos y estado: pendiente, jugando o terminado), sobre DynamicNotchKit. Indicador de "desactualizado" tras dos refrescos fallidos y "Sin matchup" en semana de bye.
- **Sin notch:** si la pantalla principal no lo tiene, el marcador se muestra en el título del menú de la barra.
- **Onboarding:** usuario de Sleeper → ligas de NFL de la temporada actual → elegir liga, con errores inline (usuario inexistente, sin red). Se salta en los siguientes arranques mientras haya liga configurada.
- **Menú de la barra:** refrescar ahora, cambiar de liga, abrir al iniciar sesión (`SMAppService`) y salir. La app no aparece en el Dock.
- **Polling adaptativo:** 60 s con partidos en vivo, 5 min en día de juego y 30 min sin partidos; backoff ×2 con tope de 5 min ante errores; pausa al dormir el Mac o bloquear la pantalla y un refresco al volver. Consulta del estado de los partidos con su propio mínimo y backoff.
- **Caché de jugadores en disco:** como máximo una descarga al día, solo con ID, nombre, posición y equipo; usa la copia anterior si falla la descarga.
- **SleeperKit:** cliente de la API de Sleeper v1 (solo lectura, sin autenticación) con host fijo, tiempos de espera, límite de tamaño de respuesta y errores tipados, más el resolutor de matchups y la lógica de presentación. Se prueba con `swift test`.
- **Distribución:** `.zip` `arm64` sin firmar y con App Sandbox (solo red saliente), creado con un tag semver; `scripts/package-release.sh` con `--dry-run` y workflow de GitHub Actions que prepara el release en borrador.

### Notas

- El estado en vivo de los partidos usa un endpoint no documentado de Sleeper (`api.sleeper.com`). Valores como `in_game`, el reloj y el down & distance nunca se observaron en un partido real.
- El intervalo en vivo es de 60 s y no de 15 s: Sleeper cachea `/matchups` 60 s (spike FN-003, ADR 0003).
- Textos solo en español; la localización es/en y la accesibilidad completa están pendientes.
- La pantalla de ajustes existe pero todavía no está alojada en ninguna ventana.
