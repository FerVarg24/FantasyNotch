# Shared-file owners

One writer per shared file. Others ask the owner with `uak msg ID --kind request`. Patterns are relative, with no spaces; directories end in `/`.
An owner is not a prerequisite for everyone: consumers work on published contracts and mocks. To transfer ownership, open a PR to main.

| Pattern | Owner task |
|---|---|
| project.yml | FN-001 |
| Packages/SleeperKit/Package.swift | FN-001 |
| Packages/SleeperKit/Sources/SleeperKitMocks/SleeperKitMocks.swift | FN-001 |
| App/FantasyNotchApp.swift | FN-001 |
| App/Info.plist | FN-001 |
| App/FantasyNotch.entitlements | FN-001 |
| .github/workflows/ci.yml | FN-001 |
| scripts/verify.sh | FN-001 |
| .uak/PROJECT.md | FN-001 |
| Packages/SleeperKit/Sources/SleeperKit/API/SleeperAPI.swift | FN-005 |
| Packages/SleeperKit/Sources/SleeperKit/API/Models/ | FN-002 |
| Packages/SleeperKit/Sources/SleeperKit/Domain/Models/ | FN-002 |
| Packages/SleeperKit/Sources/SleeperKitMocks/Fixtures/ | FN-002 |
| Packages/SleeperKit/Sources/SleeperKitMocks/MockSleeperAPI.swift | FN-002 |
| Packages/SleeperKit/Sources/SleeperKitMocks/MatchupSnapshot+Preview.swift | FN-002 |
| docs/DESIGN.md | FN-002 |
| .github/workflows/release.yml | FN-012 |
