# DECISIONS

Coordination decisions on the claims branch.
Why: a reversible option after 15 min keeps work moving.
- 1792782209 | FN-004 | Doc-only; hover/click and screenshots left unverified and flagged for FN-009 | Why: No screen-recording/accessibility permission in session
- 1792783174 | FN-003 | Recomendar 60 s para /matchups y 15 s para scores; projections fuera del MVP | Why: CDN cachea /matchups 60 s
- 1792784573 | FN-001 | Parado en uak-ship paso 3: smoke falla por falta de .uak/bin/smoke-project | Why: init-smoke exige un comando explicito del humano y escribe fuera de Paths de FN-001
- 1792785411 | FN-001 | Merge manual del humano tras approve | Why: modo marathon
- 1792791437 | FN-012 | dry-run compila, empaqueta y valida el zip en tmp sin dejar dist/ | Why: mismo flujo local y CI sin publicar
- 1792791720 | FN-002 | PlayStatus como plan.md (pending/playing/done/unknown); fixtures en SleeperKitMocks/Fixtures; sin cliente HTTP | Why: criterio exacto de plan.md; Package.swift define resources en SleeperKitMocks
- 1792791967 | FN-002 | Merge manual del humano tras approve; PlayStatus segun plan.md | Why: modo marathon; criterio de la tarea
- 1792792993 | FN-005 | descarga completa antes de medir 20MB (limite documentado); user null->notFound (verificado contra API real); redirecciones cortadas | Why: URLSession.data(for:) sin streaming; Sleeper responde 200 null para usuario inexistente
- 1792793016 | FN-006 | Devuelve [String: Player] reconstruido con los 4 campos guardados; archivo corrupto = sin caché; error de escritura se ignora | Why: Mismo tipo que SleeperAPI.players() para que FN-007/008 no distingan origen; la caché nunca debe tumbar la app
- 1792793161 | FN-005 | Merge manual del humano tras approve | Why: modo marathon
- 1792793725 | FN-006 | Sin advisor ni security-reviewer: 262 líneas, sin auth/dinero/migraciones | Why: No cae en diff riesgoso
- 1792815865 | FN-015 | Solo tests: la implementación ya cumplía | Why: Los tests nuevos pasaron sin cambios en PlayerCache.swift
- 1792869709 | FN-007 | resolve devuelve MatchupSnapshot? (nil = semana sin datos), solo rosterNotFound lanza; TeamGameState por Player.team; custom_points ignorado | Why: FN-008 no debe aplicar backoff en semana vacia; el advisor se consulto en plan y de nuevo despues del push (328 lineas)
- 1792869768 | FN-008 | resolver y proveedor de ventana inyectados por protocolo; sin tipo de FN-007 (no esta en main); scores sin implementar (decision abierta, scope) | Why: TeamGameState de FN-007 aun no existe en main; api.sleeper.com fuera del threat model
- 1792870009 | FN-008 | Merge manual del humano tras approve; scores sin implementar (decision scope abierta) | Why: modo marathon; api.sleeper.com fuera del threat model
- 1792886282 | deadline decision/FN-008-1792869490/1792870390 | BLOCKED_OTHER_TASK | Option: Nueva tarea que consulte scores en api.sleeper.com para producir PollingMode.live (hoy ninguna tarea lo hace; FN-005 solo permite api.sleeper.app); Why: Sin ella el poller nunca pasa de gameDay/idle en la app real; ampliar la lista de hosts sale del threat model de plan.md; no money, accounts, publishing or scope expansion.
- 1792886983 | FN-016 | Backoff en vivo pasa a 120/240/300 s porque parte del intervalo base; spec.md y plan.md quedan en 15 s (fuera de Paths) | Why: Los criterios de FN-016 autorizan actualizar solo los tests de 15 s; la frescura del spec la decide el humano
