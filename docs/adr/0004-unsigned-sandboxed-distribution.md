# ADR 0004 · Distribución sin firmar, con App Sandbox
- Status: accepted · Date: 2026-10-23 · Decider: fer

## Context
No hay cuenta de Apple Developer por ahora. La app solo necesita red saliente y guardar un archivo de caché.

## Decision
- Releases `.zip` sin firmar ni notarizar en GitHub Releases, creados por un humano con un tag semver. El README explica clic derecho → Abrir.
- Se activa **App Sandbox** con solo `com.apple.security.network.client`. La firma ad-hoc (`-`) basta para que funcionen los entitlements localmente.
- Arquitectura `arm64` únicamente (todas las MacBook con notch son Apple Silicon); macOS 14+.

## Alternatives
- Firmar y notarizar ($99/año): mejor experiencia de instalación; se adopta cuando haya usuarios.
- Sin sandbox: más simple, pero un fallo o dependencia comprometida tendría acceso a todo el usuario.

## Consequences
Gatekeeper muestra una advertencia al primer arranque. Migrar a firma/notarización solo cambia el workflow de release y el Team ID en `project.yml`.
