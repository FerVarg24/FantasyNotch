#!/usr/bin/env bash
# Empaqueta FantasyNotch.app (Release, arm64, sin firmar) en un .zip para GitHub Releases.
# Uso: scripts/package-release.sh [--version X.Y.Z] [--dry-run]
#   Sin --dry-run deja dist/FantasyNotch-<version>.zip; con --dry-run compila, empaqueta y
#   valida el .zip en un directorio temporal y no deja nada en dist/.
set -euo pipefail

cd "$(dirname "$0")/.."

version=""
dry_run=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --version) version="${2:?--version necesita un valor}"; shift 2 ;;
    --dry-run) dry_run=1; shift ;;
    *) echo "uso: $0 [--version X.Y.Z] [--dry-run]" >&2; exit 2 ;;
  esac
done

if [[ -z "$version" ]]; then
  version="$(git describe --tags --abbrev=0 2>/dev/null || true)"
  version="${version#v}"
  version="${version:-dev}"
fi

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

echo "==> xcodegen generate"
xcodegen generate --quiet

echo "==> xcodebuild archive (Release, arm64)"
xcodebuild archive \
  -project FantasyNotch.xcodeproj \
  -scheme FantasyNotch \
  -configuration Release \
  -destination 'platform=macOS,arch=arm64' \
  -archivePath "$work/FantasyNotch.xcarchive" \
  -derivedDataPath .build/DerivedData \
  -quiet

app="$work/FantasyNotch.xcarchive/Products/Applications/FantasyNotch.app"
[[ -d "$app" ]] || { echo "package-release: no se encontró FantasyNotch.app en el archive" >&2; exit 1; }

echo "==> ditto -c -k (FantasyNotch-$version.zip)"
zip="$work/FantasyNotch-$version.zip"
ditto -c -k --sequesterRsrc --keepParent "$app" "$zip"

# El zip debe contener la app en su raíz.
listing="$(unzip -l "$zip")"
grep -q "FantasyNotch.app/Contents/MacOS/FantasyNotch" <<<"$listing" \
  || { echo "package-release: el .zip no contiene el ejecutable de la app" >&2; exit 1; }

if [[ $dry_run -eq 1 ]]; then
  echo "package-release: dry-run OK ($(du -h "$zip" | cut -f1) FantasyNotch-$version.zip, no se publicó nada)"
else
  mkdir -p dist
  cp "$zip" "dist/FantasyNotch-$version.zip"
  echo "package-release: OK dist/FantasyNotch-$version.zip"
fi
