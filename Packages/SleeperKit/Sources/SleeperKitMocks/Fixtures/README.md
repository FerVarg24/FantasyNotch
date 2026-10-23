# Fixtures de SleeperKitMocks

JSON de la API pública de Sleeper v1, sin autenticación. Se sirven con `MockSleeperAPI` y `MockFixtures.data(named:)`.
Los nombres de archivo deben ser únicos: `.process("Fixtures")` aplana los directorios dentro del bundle.

## De dónde salen

La liga es el ejemplo público de la documentación oficial de Sleeper (temporada 2018, ya terminada). Se grabó con `curl`/`urllib`
el 2026-10-23 y se **anonimizó** antes de guardarse:

- `display_name`, `username`, `team_name`, `avatar` y el nombre de las ligas se reemplazaron por valores genéricos.
- Los `user_id` se remapearon de forma consistente (`9000000000000000NN`) para que `rosters` y `league_users` sigan cruzando.
- `user.json` contiene solo los campos del contrato (sin email, teléfono ni token).

| Archivo | Origen |
|---|---|
| `state_nfl.json` | **Real**, `/state/nfl` del día de la grabación. |
| `user.json`, `user_leagues.json`, `league_users.json`, `rosters.json` | **Real**, anonimizado. |
| `matchups_week1_final.json` | **Real**: semana 1 completa. |
| `matchups_week14_bye.json` | **Real**: semana de playoffs con 4 byes (`matchup_id` nulo) y un slot vacío `"0"`. |
| `matchups_week18_empty.json` | **Real**: la semana 18 de esa liga devuelve `[]`. |
| `matchups_week1_live_DERIVED.json` | **DERIVADO, no capturado en vivo.** Semana 1 con la segunda mitad de los titulares en 0 y `points` recalculado. Sirve para probar un partido a medias. |
| `matchups_invalid.json` | **Escrito a mano**: JSON truncado para probar `SleeperAPIError.decoding`. |
| `players_subset.json` | **Real**, solo los 240 jugadores referenciados por las semanas 1 y 14 (el catálogo completo pesa ~14 MB). |

No hay ninguna captura de un partido en vivo real: Sleeper solo tiene ese estado durante un partido (ver `docs/spikes/003-sleeper-live-data.md`).
