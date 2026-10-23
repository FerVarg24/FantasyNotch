#!/usr/bin/env bash
# Verificación completa de FantasyNotch: tests del paquete + generar proyecto + compilar la app.
set -euo pipefail

cd "$(dirname "$0")/.."

echo "==> swift test (SleeperKit)"
swift test --package-path Packages/SleeperKit

echo "==> xcodegen generate"
xcodegen generate --quiet

echo "==> xcodebuild build (FantasyNotch)"
xcodebuild build \
  -project FantasyNotch.xcodeproj \
  -scheme FantasyNotch \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath .build/DerivedData \
  -quiet

echo "verify: OK"
