# ADR 0002 · DynamicNotchKit para la UI del notch
- Status: accepted · Date: 2026-10-23 · Decider: fer

## Context
Dibujar sobre el notch requiere un `NSPanel` sin bordes, detección del notch (`NSScreen.safeAreaInsets`, `auxiliaryTopLeftArea`), animaciones de expandir/contraer y manejo de varias pantallas.

## Decision
Usar **DynamicNotchKit** (MIT, macOS 13+, v1.1.0) vía SPM, fijado a versión exacta `1.1.0`. Lo usa también MenuScores en producción.

## Alternatives
- Implementación propia con `NSPanel`: control total pero semanas de trabajo en casos borde.
- Fork de boring.notch / MenuScores: GPL-3.0 y mucho código ajeno al producto.

## Consequences
Dependemos del ritmo del mantenedor (último push abril 2026). Si se abandona o no cubre un caso, la UI del notch está aislada en `App/Notch/` y se puede reemplazar por un `NSPanel` propio sin tocar `SleeperKit`.
