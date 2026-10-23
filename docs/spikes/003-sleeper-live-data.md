# Spike FN-003 · Proyecciones, estado de partidos y frecuencia de actualización en Sleeper

- Fecha de medición: 2026-10-23 (viernes, semana 7 de 2026, ningún partido en vivo)
- Liga usada: `LigaPrueba` (8 equipos, `in_season`) de un usuario real; solo lecturas públicas sin autenticación.
- Todo lo marcado **no documentado** no aparece en la documentación oficial de Sleeper (docs.sleeper.com) y puede cambiar sin aviso.

## 1. Endpoints verificados

| Endpoint | Oficial | Uso | `s-maxage` (CDN) |
|---|---|---|---|
| `GET https://api.sleeper.app/v1/state/nfl` | sí | semana y temporada actuales | 60 s |
| `GET https://api.sleeper.app/v1/league/{id}/matchups/{week}` | sí | puntos por jugador y matchups | **60 s** |
| `GET https://api.sleeper.com/scores/nfl/regular/{season}/{week}` | **no** | estado en vivo de cada partido | **10 s** |
| `GET https://api.sleeper.com/schedule/nfl/regular/{season}` | **no** | calendario y estado por partido | 600 s |
| `GET https://api.sleeper.app/v1/projections/nfl/regular/{season}/{week}` | **no** | proyecciones por jugador | 600 s |
| `GET https://api.sleeper.app/v1/stats/nfl/regular/{season}/{week}` | **no** (aparece en la doc comunitaria) | stats reales por jugador | 30 s |
| `GET https://api.sleeper.app/v1/players/nfl` | sí | catálogo de jugadores (~MB) | 600 s |

`https://api.sleeper.app/v1/schedule/...` y `/v1/scoreboard/...` devuelven 404: el calendario y los marcadores solo viven en el host `api.sleeper.com` (sin `/v1`).

### 1.1 `/state/nfl` (oficial)
```json
{"week":7,"leg":7,"season":"2026","season_type":"regular","league_season":"2026",
 "previous_season":"2025","season_start_date":"2026-09-09","display_week":7,
 "league_create_season":"2026","season_has_scores":true}
```
Usar `league_season` para listar ligas y `week` para pedir matchups. Riesgo bajo.

### 1.2 `/league/{id}/matchups/{week}` (oficial)
Arreglo con una entrada por roster. Campos: `roster_id`, `matchup_id` (dos rosters con el mismo valor se enfrentan), `points` (total del roster), `starters` (IDs en orden de slot), `starters_points` (mismo orden), `players` (todos), `players_points` (dict `player_id → puntos`), `custom_points` (null salvo ajuste del comisionado).
Ejemplo recortado (semana 7, antes de jugar):
```json
{"roster_id":1,"matchup_id":4,"points":0.0,"custom_points":null,
 "starters":["…10 ids…"],"starters_points":[0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0],
 "players":["…15 ids…"],"players_points":{"11584":0.0,"12526":0.0,"13287":0.0}}
```
Notas:
- **No incluye** estado del jugador, equipo NFL ni proyección. Se cruza con `/players/nfl` (`team`, `position`, `injury_status`).
- La respuesta se cachea 60 s en Cloudflare (`cache-control: public, s-maxage=60`; vimos `cf-cache-status: HIT` con `age` creciente 28→33→38 s). **Consultar cada 15 s devuelve el mismo cuerpo hasta 4 veces seguidas.**
- Posiciones DEF usan el código del equipo como ID (`"NE"`), no un número.

### 1.3 `scores` (no documentado): estado de partido
Arreglo de partidos de la semana (14 en la semana 7). Campos de primer nivel útiles: `game_id`, `status`, `start_time` (epoch ms), `date`, `updated_at`, `week`. Dentro de `metadata`: `home_team`, `away_team`, `is_in_progress`, `is_over`, `has_started`, `quarter`, `quarter_num`, `canceled`, `date_time` (ISO UTC), `home_score_quarter1..4`/`away_score_quarter1..4`, `*_score_overtime`, `is_overtime`, `home_record`, `away_record`.
Valores de `status` observados: `pre_game`, `complete`. **`in_game` no se pudo observar** (sin partido en vivo); se infiere de `is_in_progress`. Reloj, down&distance y posesión **no aparecieron** como campos en estado `pre_game`; hay que revisarlos un domingo.
Caché de 10 s: es el endpoint con mejor frescura.

### 1.4 `schedule` (no documentado)
272 partidos; cada uno: `{"status":"pre_game|complete","date":"2026-10-25","home":"ARI","away":"DEN","week":7,"game_id":"202610701"}`. Sin hora exacta (solo fecha), por eso `scores` es mejor para el horario (`start_time`).

### 1.5 `projections` (no documentado)
`/v1/projections/nfl/regular/2026/7` → objeto `player_id → {stats}`; incluye `pts_ppr`, `pts_half_ppr`, `pts_std` (p. ej. `pts_half_ppr: 8.88`) además de proyecciones por estadística. Muchos jugadores solo traen `adp_dd_ppr` (sin proyección útil). Las proyecciones **ya reflejan las reglas de puntuación estándar**, no las de la liga: para una liga con puntuación personalizada solo son una aproximación. Existe también `https://api.sleeper.app/projections/nfl/2026/7?season_type=regular` (5.6 MB, arreglo con objeto `player` embebido): demasiado pesado, no usar.
Riesgo: endpoint sin documentar y sin contrato; en la práctica lo usa la web de Sleeper.

### 1.6 `stats` (no documentado)
`player_id → {stats reales}`, con `pts_ppr`, `pts_half_ppr`, `pts_std` y conteos de snaps. Solo útil para recalcular puntos con reglas propias; **no es necesario**, porque `players_points` de `/matchups` ya usa las reglas de la liga.

## 2. Cómo decidir "hay partidos en vivo" (para `MatchupPoller`)

1. Al arrancar y cada 30 min: `GET /state/nfl` → `week`.
2. Pedir `scores/nfl/regular/{season}/{week}` (caché 10 s) y calcular el estado de la ventana:
   - **En vivo** si algún partido tiene `metadata.is_in_progress == true` (o `status == "in_game"`).
   - **Día de juego** si hay partidos con `start_time` dentro de las próximas 24 h o con `has_started && !is_over` sin confirmación.
   - **Sin partidos** en cualquier otro caso (todos `complete` o `pre_game` a más de 24 h).
3. Para "con jugadores del matchup" (ADR 0003): cruzar `team` de cada jugador del roster (`/players/nfl`) con `home_team`/`away_team` de los partidos en vivo.
4. **Fallback** si `scores` falla o cambia de forma: usar solo `schedule` + hora local, y tratar el domingo 12:00–24:00 ET y jueves/lunes 20:00–24:00 ET como "día de juego".

### Derivar `PlayStatus` por jugador

| `PlayStatus` | Condición |
|---|---|
| `notStarted` | el partido del equipo del jugador está `pre_game` |
| `playing` | partido `is_in_progress == true` |
| `finished` | partido `is_over == true` o `status == "complete"` |
| `bye` / `inactive` | el equipo no aparece en `scores` esa semana, o `injury_status` ∈ {`Out`, `IR`} con puntos 0 |

Es una aproximación a nivel de partido: no sabemos si el jugador ya jugó sus snaps ni si está en el campo (esa precisión no existe en Sleeper).

## 3. Frecuencia de actualización de `points`

Resultado ya medido: **no hay medición de un partido en vivo** (la ventana disponible hoy fue viernes sin partidos). Sí medimos la caché del CDN:
- `/matchups`: 60 s de `s-maxage`, con `stale-while-revalidate=300`. Es el límite inferior real de frescura que verá el cliente, y probablemente el de `points` en vivo.
- `/scores`: 10 s.

Implicación para ADR 0003: el intervalo de 15 s para `/matchups` no ayuda; **60 s** da el mismo resultado con 4× menos llamadas. Se puede poll a `/scores` cada 15 s (barato, 50 KB) para detectar cambios de estado de partido.

### Script para medir un domingo
Guardar como `measure.sh`, ejecutar durante un partido (≥ 30 min) con `LEAGUE` y `WEEK` definidos. Imprime una línea solo cuando cambia el total de `points`, con la edad de caché.

```bash
#!/usr/bin/env bash
# Uso: LEAGUE=<id> WEEK=<n> ./measure.sh
set -u
prev=""
while true; do
  resp=$(curl -s -D hdr.txt "https://api.sleeper.app/v1/league/$LEAGUE/matchups/$WEEK")
  sum=$(printf '%s' "$resp" | python3 -I -c "import sys,json;print(sum(r['points'] for r in json.load(sys.stdin)))")
  age=$(grep -i '^age:' hdr.txt | tr -d '\r' | awk '{print $2}')
  if [ "$sum" != "$prev" ]; then echo "$(date -u +%H:%M:%S) total=$sum age=${age:-0}"; prev="$sum"; fi
  sleep 5
done
```
Registrar el resultado aquí cuando exista (pendiente: domingo 2026-10-25).

## 4. Recomendación final

**Entra en el MVP**
- `/state/nfl` y `/league/{id}/matchups/{week}` (oficiales) como fuente de puntos.
- `scores/nfl/regular/{season}/{week}` (no documentado) solo para decidir el modo del poller y derivar `PlayStatus`, con el fallback de calendario de la §2. Si falla, el MVP sigue funcionando sin `PlayStatus` fino.
- Intervalos: `/matchups` cada **60 s** en vivo (no 15 s), `/scores` cada 15 s en vivo, 5 min en día de juego, 30 min sin partidos. Ajustar ADR 0003.

**Queda fuera del MVP**
- Proyecciones (`projections`): endpoint sin documentar y calculado con puntuación estándar, no la de la liga. Candidato a v1.1 detrás de una bandera.
- `stats` y recalcular puntos localmente.
- Cualquier dato que solo exista en `metadata` de `scores` (reloj, down&distance, posesión) hasta confirmarlo un domingo.

**Seguimiento**
- Medir con el script el domingo 2026-10-25 y anotar el resultado en §3.
- Verificar el valor real de `status` "en vivo" en `scores`.
