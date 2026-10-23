# ADR 0003 · Polling adaptativo a la API de Sleeper
- Status: accepted · Date: 2026-10-23 · Decider: fer

## Context
Sleeper no ofrece WebSockets ni push. Su límite documentado es ~1000 llamadas/min por IP; cada usuario llama desde su propia IP. Queremos frescura sin gastar batería ni red.

## Decision
Un `actor MatchupPoller` con reloj inyectable y estos intervalos:
| Estado | Intervalo |
|---|---|
| Partidos en vivo con jugadores del matchup | 15 s |
| Día de juego sin partidos en vivo | 5 min |
| Sin partidos | 30 min |
| Mac dormida / pantalla bloqueada | pausado; 1 refresh al despertar |
| Error 429/5xx | backoff exponencial ×2, tope 5 min |
`/players/nfl` se descarga como máximo 1 vez al día y se cachea en disco. El estado "en vivo" se determina según el resultado del spike FN-003.

## Alternatives
- Intervalo fijo de 15 s: gasto innecesario 6 días a la semana.
- Intervalo fijo de 60 s: experiencia poco "en vivo".

## Consequences
Los intervalos son constantes en un solo lugar y se ajustan con datos reales (medición de frescura en debug).
