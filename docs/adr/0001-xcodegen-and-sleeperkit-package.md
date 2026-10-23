# ADR 0001 · XcodeGen + paquete local SleeperKit
- Status: accepted · Date: 2026-10-23 · Decider: fer

## Context
Varios agentes trabajan en paralelo. El `project.pbxproj` de Xcode cambia con cada archivo nuevo y genera conflictos de merge constantes. Además, la lógica de la API y del dominio debe probarse rápido y sin UI.

## Decision
- El proyecto Xcode se genera con **XcodeGen** desde `project.yml`; el `.xcodeproj` no se versiona.
- Toda la lógica sin UI vive en un **Swift Package local** `Packages/SleeperKit` (API, caché, dominio, polling), probado con `swift test`.
- El target `App/` solo contiene SwiftUI/AppKit y depende de `SleeperKit` y DynamicNotchKit.

## Alternatives
- `.xcodeproj` versionado: conflictos de merge entre agentes.
- Tuist: más potente pero más pesado de aprender y mantener para un proyecto de un target.
- Todo en el target de la app: tests más lentos (requieren `xcodebuild`) y acoplamiento UI/lógica.

## Consequences
Hay que correr `xcodegen generate` tras clonar o cambiar `project.yml`. Revertir es fácil: generar el `.xcodeproj` una vez y versionarlo.
