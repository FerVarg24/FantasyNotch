# Lessons (uak learn)

Append-only. Format: - N | epoch | agent | task | paths | text. `uak recall` and `uak next` show the ones for your paths.

- 1 | 1792989426 | fervarg24-1 | FN-009 | App/Notch/ | una vista de la app que necesita un helper testeable se tienta a crearlo en Packages/SleeperKit/.../Display/ · FN-009 se rechazo por salirse de Paths (App/Notch/) · antes de crear archivos fuera de Paths pide ampliarlos con uak msg al humano o deja el helper dentro de Paths
- 2 | 1793033919 | fervarg24-2 | FN-009 | App/Notch/,Packages/SleeperKit/Sources/SleeperKit/Display/,Packages/SleeperKit/Tests/SleeperKitTests/Display/ | validar previews enlazando SleeperKitMocks deja el modulo en .build/DerivedData y canImport(SleeperKitMocks) pasa a true sin enlazar · verify falla en el link con Undefined symbols previewLive · rm -rf .build/DerivedData antes de reverificar
