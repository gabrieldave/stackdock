#!/usr/bin/env bash
# StackDock v4.0 — build local + instalación en /Applications
# Firma con Developer ID si existe (estable para TCC/Accesibilidad).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="${ROOT}/build"
APP_NAME="StackDock"
BUNDLE_ID="com.blackeye.stackdock"
APP_PATH="${BUILD_DIR}/${APP_NAME}.app"
INSTALL_PATH="/Applications/${APP_NAME}.app"
MACOSX_DEPLOYMENT_TARGET="${MACOSX_DEPLOYMENT_TARGET:-13.0}"

detect_developer_id() {
  security find-identity -v -p codesigning 2>/dev/null \
    | sed -n 's/.*"\(Developer ID Application: .*\)"/\1/p' \
    | head -n 1
}
SIGN_IDENTITY="${STACKDOCK_SIGN_IDENTITY:-$(detect_developer_id)}"

echo "==> StackDock v4.0 — build local"
echo "    Root: ${ROOT}"

rm -rf "${BUILD_DIR}"
mkdir -p "${APP_PATH}/Contents/MacOS"
mkdir -p "${APP_PATH}/Contents/Resources"

SOURCES=(
  "${ROOT}/Sources/Models/DockModels.swift"
  "${ROOT}/Sources/Services/WindowTeleportAndProfileService.swift"
  "${ROOT}/Sources/Services/BrowserProfileLaunchService.swift"
  "${ROOT}/Sources/Services/LicenseManager.swift"
  "${ROOT}/Sources/Services/GlobalHotKeyCenter.swift"
  "${ROOT}/Sources/Views/DockTileView.swift"
  "${ROOT}/Sources/Views/DockGlassBarView.swift"
  "${ROOT}/Sources/Views/DockSpecialIcons.swift"
  "${ROOT}/Sources/App/StackDockAppController.swift"
  "${ROOT}/Sources/main.swift"
)

SDK_PATH="$(xcrun --show-sdk-path)"
SWIFTC="$(xcrun --find swiftc)"

echo "==> Compilando con swiftc (SDK: ${SDK_PATH})"
"${SWIFTC}" \
  -sdk "${SDK_PATH}" \
  -target "arm64-apple-macosx${MACOSX_DEPLOYMENT_TARGET}" \
  -O \
  -swift-version 5 \
  -framework Cocoa \
  -framework Carbon \
  -framework ApplicationServices \
  -framework ServiceManagement \
  -framework CryptoKit \
  "${SOURCES[@]}" \
  -o "${APP_PATH}/Contents/MacOS/${APP_NAME}"

cp "${ROOT}/Resources/Info.plist" "${APP_PATH}/Contents/Info.plist"
cp "${ROOT}/Resources/Entitlements.plist" "${APP_PATH}/Contents/Resources/Entitlements.plist"
if [[ -f "${ROOT}/Resources/AppIcon.icns" ]]; then
  cp "${ROOT}/Resources/AppIcon.icns" "${APP_PATH}/Contents/Resources/AppIcon.icns"
  /usr/libexec/PlistBuddy -c "Delete :CFBundleIconFile" "${APP_PATH}/Contents/Info.plist" 2>/dev/null || true
  /usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string AppIcon" "${APP_PATH}/Contents/Info.plist"
fi

/usr/libexec/PlistBuddy -c "Set :CFBundleExecutable ${APP_NAME}" "${APP_PATH}/Contents/Info.plist" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier ${BUNDLE_ID}" "${APP_PATH}/Contents/Info.plist" 2>/dev/null || true

if [[ -n "${SIGN_IDENTITY}" ]]; then
  echo "==> Firmando Developer ID (estable para Accesibilidad)"
  echo "    ${SIGN_IDENTITY}"
  codesign --force --deep --options runtime --timestamp \
    --identifier "${BUNDLE_ID}" \
    --entitlements "${ROOT}/Resources/Entitlements.plist" \
    --sign "${SIGN_IDENTITY}" \
    "${APP_PATH}"
else
  echo "==> Firmando ad-hoc (WARNING: Accesibilidad se rompe en cada rebuild)"
  codesign --force --deep --sign - \
    --identifier "${BUNDLE_ID}" \
    --entitlements "${ROOT}/Resources/Entitlements.plist" \
    "${APP_PATH}"
fi

echo "==> Verificando firma"
codesign --verify --verbose=2 "${APP_PATH}"
codesign -dv --verbose=2 "${APP_PATH}" 2>&1 | grep -E 'Authority|Identifier|Signature|TeamIdentifier|Runtime' || true

echo "==> Instalando en ${INSTALL_PATH}"
pkill -x "${APP_NAME}" 2>/dev/null || true
sleep 0.3

rm -rf "${INSTALL_PATH}"
cp -R "${APP_PATH}" "${INSTALL_PATH}"
xattr -cr "${INSTALL_PATH}" 2>/dev/null || true

echo "==> Lanzando ${INSTALL_PATH}"
open "${INSTALL_PATH}"

echo ""
echo "✅ StackDock v4.0 instalado en ${INSTALL_PATH}"
echo "   Atajos: ⌥+D docks | ⌃W monitor (ajustable en menú)"
if [[ -n "${SIGN_IDENTITY}" ]]; then
  echo "   Firma: Developer ID — concede Accesibilidad UNA vez y no se pierde entre rebuilds."
fi
