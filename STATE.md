# STATE

Phase: execution
Updated: 1792792929
AVAILABLE: FN-007 FN-008 FN-009 FN-010 FN-011 FN-013 FN-014 
CLAIMED: FN-005 FN-006 
BLOCKED: -
REVIEW: -
INTEGRATED: FN-001 FN-002 FN-003 FN-004 FN-012 
CANCELLED: -

Claims (first 24; status --task ID shows detail):
FN-005 | CLAIMED | fervarg24-3 | until 1792807247
FN-006 | CLAIMED | fervarg24-1 | until 1792807329

Blockers: BLOCKED tasks; use status --task ID --summary.
Current decisions (last 5):
- 1792784573 | FN-001 | Parado en uak-ship paso 3: smoke falla por falta de .uak/bin/smoke-project | Why: init-smoke exige un comando explicito del humano y escribe fuera de Paths 
- 1792785411 | FN-001 | Merge manual del humano tras approve | Why: modo marathon
- 1792791437 | FN-012 | dry-run compila, empaqueta y valida el zip en tmp sin dejar dist/ | Why: mismo flujo local y CI sin publicar
- 1792791720 | FN-002 | PlayStatus como plan.md (pending/playing/done/unknown); fixtures en SleeperKitMocks/Fixtures; sin cliente HTTP | Why: criterio exacto de plan.md; Package.sw
- 1792791967 | FN-002 | Merge manual del humano tras approve; PlayStatus segun plan.md | Why: modo marathon; criterio de la tarea

Global next step: available P0; else review PRs, tests, demo, rehearsal.
Why: bounded snapshot to resume without rereading history.
