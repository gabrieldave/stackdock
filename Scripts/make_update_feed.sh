#!/usr/bin/env bash
# Genera y firma el feed de actualizaciones de StackDock.
#
# Uso:
#   Scripts/make_update_feed.sh [ruta/al/StackDock-X.Y.Z.dmg]
#
# Sin argumento usa dist/StackDock-<versión de Info.plist>.dmg.
# Escribe Web/public/updates/latest.json + latest.json.sig (firmado Ed25519).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)"
BUILD="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' Resources/Info.plist)"
MIN_MACOS="$(/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' Resources/Info.plist)"

DMG="${1:-dist/StackDock-${VERSION}.dmg}"
[[ -f "$DMG" ]] || { echo "❌ No existe el DMG: $DMG" >&2; exit 1; }

SHA="$(shasum -a 256 "$DMG" | awk '{print $1}')"
OUT_DIR="Web/public/updates"
mkdir -p "$OUT_DIR"
JSON="$OUT_DIR/latest.json"

cat > "$JSON" <<EOF
{
  "version": "${VERSION}",
  "build": ${BUILD},
  "min_macos": "${MIN_MACOS}",
  "dmg_url": "https://stackdock.iareal.net/download/StackDock-${VERSION}.dmg",
  "sha256": "${SHA}",
  "notes_url": "https://stackdock.iareal.net/",
  "published_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF

echo "==> Feed: $JSON"
cat "$JSON"
echo "==> Firmando (Ed25519)"
swift Scripts/sign_update_feed.swift "$JSON"
