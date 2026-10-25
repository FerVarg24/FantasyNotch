# ADR 0003 · Polling adaptativo a la API de Sleeper
- Status: accepted · Date: 2026-10-23 · Decider: fer

## Context
Sleeper no ofrece WebSockets ni push. Su límite documentado es ~1000 llamadas/min por IP; cada usuario llama desde su propia IP. Queremos frescura sin gastar batería ni red.

## Decision
Un `actor MatchupPoller` con reloj inyectable y estos intervalos:
| Estado | Intervalo |
|---|---|
| Partidos en vivo con jugadores del matchup | 60 s (`/matchups`; enmendado en FN-016, antes 15 s) |
| Día de juego sin partidos en vivo | 5 min |
| Sin partidos | 30 min |
| Mac dormida / pantalla bloqueada | pausado; 1 refresh al despertar |
| Error 429/5xx | backoff exponencial ×2, tope 5 min |
`/players/nfl` se descarga como máximo 1 vez al día y se cachea en disco. El estado "en vivo" se determina según el resultado del spike FN-003.

## Alternatives
- Intervalo fijo de 15 s: gasto innecesario 6 días a la semana. Tampoco en vivo: Sleeper cachea `/matchups` unos 60 s (spike FN-003 §3), así que pedirlo cada 15 s casi siempre devuelve el mismo cuerpo y cuadruplica las llamadas sin ganar frescura.
- Intervalo fijo de 60 s todo el tiempo: gasto innecesario fuera de los partidos; por eso 60 s solo rige en vivo y el resto de estados espera más.

## Consequences
Los intervalos son constantes en un solo lugar y se ajustan con datos reales (medición de frescura en debug).

El mínimo entre dos llamadas a `/matchups` (`PollingPolicy.minimumMatchupGap`) es también de 60 s, y el backoff parte del intervalo base: en vivo, 2 min, 4 min y tope de 5 min.

El spike FN-003 recomienda además pedir `scores` cada 15 s en vivo. Esa cadencia queda pendiente hasta que exista una implementación de `GameWindowProviding`; no afecta a `/matchups`.
