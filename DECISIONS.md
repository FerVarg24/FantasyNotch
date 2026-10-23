# DECISIONS

Coordination decisions on the claims branch.
Why: a reversible option after 15 min keeps work moving.
- 1792782209 | FN-004 | Doc-only; hover/click and screenshots left unverified and flagged for FN-009 | Why: No screen-recording/accessibility permission in session
- 1792783174 | FN-003 | Recomendar 60 s para /matchups y 15 s para scores; projections fuera del MVP | Why: CDN cachea /matchups 60 s
- 1792784573 | FN-001 | Parado en uak-ship paso 3: smoke falla por falta de .uak/bin/smoke-project | Why: init-smoke exige un comando explicito del humano y escribe fuera de Paths de FN-001
- 1792785411 | FN-001 | Merge manual del humano tras approve | Why: modo marathon
- 1792791437 | FN-012 | dry-run compila, empaqueta y valida el zip en tmp sin dejar dist/ | Why: mismo flujo local y CI sin publicar
- 1792791720 | FN-002 | PlayStatus como plan.md (pending/playing/done/unknown); fixtures en SleeperKitMocks/Fixtures; sin cliente HTTP | Why: criterio exacto de plan.md; Package.swift define resources en SleeperKitMocks
