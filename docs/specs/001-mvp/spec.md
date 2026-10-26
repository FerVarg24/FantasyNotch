# Spec 001 · MVP: marcador en vivo de un matchup de Sleeper en el notch
- Status: approved (fer, 2026-10-23) · Owner: fer · PROJECT principles: 1, 4, 5, 6

## Problem
Durante los partidos de la NFL, quien juega Fantasy en Sleeper tiene que abrir la app del teléfono o una pestaña del navegador para ver cómo va su matchup. Rompe la concentración y no hay ninguna app de Mac que lo muestre de forma pasiva (MenuScores y similares cubren marcadores reales, no fantasy).

## Stories
- Como jugador de Sleeper, quiero escribir mi username y elegir una de mis ligas, para no tener que buscar IDs.
- Como jugador, quiero ver en el notch mi puntaje contra el de mi rival en tiempo real, para saber cómo voy sin cambiar de app.
- Como jugador, quiero expandir el notch y ver el detalle de ambos equipos, para saber qué jugadores faltan por jugar.
- Como usuario de MacBook, quiero que la app no gaste batería ni red cuando no hay partidos, para olvidarme de que está abierta.

## Acceptance criteria (EARS)
**Onboarding**
- When the user enters a Sleeper username and confirms, the system shall resolve it with `GET /user/{username}` and list the user's NFL leagues for the current season (`/state/nfl` → `league_season`).
- If the username does not exist or the network fails, the system shall show an inline error and keep the onboarding open, without crashing.
- When the user picks a league, the system shall persist `user_id` and `league_id` locally and show the matchup without restarting.
- While a league is configured, the system shall skip the onboarding on the next launch.

**Vista compacta (notch)**
- While a matchup exists for the current week, the system shall show, next to the notch, the avatar of the user's team on the left and `<mis puntos> – <puntos rival>` (1 decimal) on the right.
- While the user's points are greater than the opponent's, the system shall render the score in green; when lower, in red; when tied, in neutral white.
- If the league is on a bye week or there is no matchup, the system shall show a neutral state ("Sin matchup") instead of an error.

**Vista expandida**
- When the user hovers or clicks the compact view, the system shall expand to show both team names, avatars, total points and each starter with their points.
- While a starter has not played yet, the system shall mark them as pending.

**Actualización**
- While NFL games are in progress, the system shall refresh the matchup at most every 60 s (Sleeper caches `/matchups` for 60 s, spike FN-003; changed from 15 s on 2026-10-24).
- While no games are in progress, the system shall refresh at most every 30 min, and never more than once per day for `/players/nfl`.
- When the Mac goes to sleep or the screen locks, the system shall stop polling; when it wakes, it shall refresh once immediately.
- If Sleeper answers 429 or 5xx, the system shall back off exponentially (max 5 min) and keep showing the last score with a "desactualizado" indicator after 2 missed refreshes.
- When points change, the system shall update the compact view within one polling cycle.

**Barra de menú y sistema**
- The system shall run as a menu bar app with no Dock icon (`LSUIElement`).
- The menu shall offer: refrescar ahora, cambiar de liga, abrir al iniciar sesión, salir.
- If the main screen has no notch, the system shall show the score in the menu bar instead of the notch.

## Non-functional
- Frescura: cambio visible ≤ 60 s en el caso típico y ≤ 120 s en el peor (Sleeper cachea `/matchups` 60 s y la app lo consulta cada 60 s) después de que Sleeper lo publique. A confirmar con la medición del spike FN-003 (pendiente: domingo 2026-10-25).
- CPU < 1 % promedio y < 100 MB de memoria con polling en vivo.
- Red: ≤ 4 llamadas/min a `/matchups` con partidos en vivo; `/players/nfl` ≤ 1/día.
- Privacidad: ningún dato sale de la Mac excepto las llamadas a `api.sleeper.app` y `sleepercdn.com`; sin telemetría; el username no aparece en logs.
- Accesibilidad: la vista expandida es legible con VoiceOver (P2).

## Out of scope
- ESPN, Yahoo u otras plataformas.
- Más de una liga a la vez.
- Notificaciones, sonidos, widgets, iOS.
- Firma, notarización, Sparkle.
- Ligas de mejor ball / IDP con reglas especiales (se muestran tal cual las calcula Sleeper).

## Open questions
- [ ] ¿Sleeper expone proyecciones y estado de partidos en algún endpoint público estable? · spike FN-003
- [ ] ¿Cada cuánto actualiza Sleeper `points` en `/matchups` durante un partido? · spike FN-003 (medir un domingo)
- [ ] ¿DynamicNotchKit permite contenido compacto a izquierda y derecha del notch sin expandir, y cómo se comporta sin notch? · spike FN-004
