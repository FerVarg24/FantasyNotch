# STATE

Phase: execution
Updated: 1793651356
AVAILABLE: FN-013 
CLAIMED: FN-014 
BLOCKED: -
REVIEW: -
INTEGRATED: FN-001 FN-002 FN-003 FN-004 FN-005 FN-006 FN-007 FN-008 FN-009 FN-010 FN-011 FN-012 FN-015 FN-016 FN-017 FN-018 FN-019 
CANCELLED: -

Claims (first 24; status --task ID shows detail):
FN-014 | CLAIMED | fervarg24-2 | until 1793665756

Blockers: BLOCKED tasks; use status --task ID --summary.
Current decisions (last 5):
- 1793067033 | FN-010 | Logica en SleeperKit/Onboarding con onConfigured; vistas en App/; LaunchAtLogin lee SMAppService.mainApp.status | Why: App sin target de tests; el advisor s
- 1793072404 | FN-018 | Reservar lastWindowCall antes de suspender; cancelacion no cuenta como fallo | Why: actor reentrante: refrescos solapados no deben duplicar la llamada
- 1793651017 | FN-011 | ScheduleFallback sin cablear (no ocultar fallos a FN-018); temporada diferida; sizingOptions preferredContentSize | Why: verify.sh no detecta crashes de run
- 1793651080 | deadline decision/FN-011-1793649555/1793650455 | BLOCKED_OTHER_TASK | Option: Ampliar Paths a SleeperKit/Integration/ y Tests/Integration/ para logica testeable (pue
- 1793651080 | deadline decision/FN-011-1793649860/1793650760 | REVERSIBLE_AND_LOG | Option: No cablear ScheduleFallback: SeasonedGameWindow lanza si falta la temporada o scores fa

Global next step: available P0; else review PRs, tests, demo, rehearsal.
Why: bounded snapshot to resume without rereading history.
