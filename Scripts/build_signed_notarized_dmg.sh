#!/usr/bin/env bash
# StackDock v4.0 — build firmado Developer ID + DMG (+ notarización si hay credenciales)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="${ROOT}/build"
DIST_DIR="${ROOT}/dist"
APP_NAME="StackDock"
BUNDLE_ID="com.blackeye.stackdock"
VERSION="4.0.1"
APP_PATH="${BUILD_DIR}/${APP_NAME}.app"
DMG_NAME="${STACKDOCK_DMG_NAME:-StackDock-${VERSION}.dmg}"
DMG_PATH="${DIST_DIR}/${DMG_NAME}"
MACOSX_DEPLOYMENT_TARGET="${MACOSX_DEPLOYMENT_TARGET:-13.0}"

# Autodetecta Developer ID Application del Llavero (sin hardcodear secretos)
detect_developer_id() {
  security find-identity -v -p codesigning 2>/dev/null \
    | sed -n 's/.*"\(Developer ID Application: .*\)"/\1/p' \
    | head -n 1
}
SIGN_IDENTITY="${STACKDOCK_SIGN_IDENTITY:-$(detect_developer_id)}"
if [[ -z "${SIGN_IDENTITY}" ]]; then
  echo "❌ No hay 'Developer ID Application' en el Llavero"
  exit 1
fi
# Team ID desde el paréntesis final del identity, si no viene por env
TEAM_ID="${STACKDOCK_TEAM_ID:-}"
if [[ -z "${TEAM_ID}" && "${SIGN_IDENTITY}" =~ \(([A-Z0-9]+)\)$ ]]; then
  TEAM_ID="${BASH_REMATCH[1]}"
fi

echo "==> StackDock v4.0 — build firmado + DMG"
echo "    Identity: ${SIGN_IDENTITY}"
echo "    Team: ${TEAM_ID:-unknown}"

rm -rf "${BUILD_DIR}" "${DIST_DIR}"
mkdir -p "${APP_PATH}/Contents/MacOS" "${APP_PATH}/Contents/Resources" "${DIST_DIR}"

SOURCES=(
  "${ROOT}/Sources/Models/DockModels.swift"
  "${ROOT}/Sources/Services/WindowTeleportAndProfileService.swift"
  "${ROOT}/Sources/Services/BrowserProfileLaunchService.swift"
  "${ROOT}/Sources/Services/LicenseManager.swift"
  "${ROOT}/Sources/Services/GlobalHotKeyCenter.swift"
  "${ROOT}/Sources/Views/DockTileView.swift"
  "${ROOT}/Sources/Views/DockGlassBarView.swift"
  "${ROOT}/Sources/App/StackDockAppController.swift"
  "${ROOT}/Sources/main.swift"
)

SDK_PATH="$(xcrun --show-sdk-path)"
SWIFTC="$(xcrun --find swiftc)"

echo "==> Compilando (arm64 + x86_64 universal si posible)"
BIN_ARM="${BUILD_DIR}/StackDock.arm64"
BIN_X86="${BUILD_DIR}/StackDock.x86_64"

"${SWIFTC}" \
  -sdk "${SDK_PATH}" \
  -target "arm64-apple-macosx${MACOSX_DEPLOYMENT_TARGET}" \
  -O -swift-version 5 \
  -framework Cocoa -framework Carbon -framework ApplicationServices -framework ServiceManagement -framework CryptoKit \
  "${SOURCES[@]}" -o "${BIN_ARM}"

if "${SWIFTC}" \
  -sdk "${SDK_PATH}" \
  -target "x86_64-apple-macosx${MACOSX_DEPLOYMENT_TARGET}" \
  -O -swift-version 5 \
  -framework Cocoa -framework Carbon -framework ApplicationServices -framework ServiceManagement -framework CryptoKit \
  "${SOURCES[@]}" -o "${BIN_X86}" 2>/dev/null; then
  lipo -create -output "${APP_PATH}/Contents/MacOS/${APP_NAME}" "${BIN_ARM}" "${BIN_X86}"
  echo "    Binario universal (arm64 + x86_64)"
else
  cp "${BIN_ARM}" "${APP_PATH}/Contents/MacOS/${APP_NAME}"
  echo "    Binario arm64"
fi

cp "${ROOT}/Resources/Info.plist" "${APP_PATH}/Contents/Info.plist"
cp "${ROOT}/Resources/Entitlements.plist" "${APP_PATH}/Contents/Resources/Entitlements.plist"
if [[ -f "${ROOT}/Resources/AppIcon.icns" ]]; then
  cp "${ROOT}/Resources/AppIcon.icns" "${APP_PATH}/Contents/Resources/AppIcon.icns"
  /usr/libexec/PlistBuddy -c "Delete :CFBundleIconFile" "${APP_PATH}/Contents/Info.plist" 2>/dev/null || true
  /usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string AppIcon" "${APP_PATH}/Contents/Info.plist"
fi
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier ${BUNDLE_ID}" "${APP_PATH}/Contents/Info.plist" 2>/dev/null || true

echo "==> Firmando app (Developer ID + hardened runtime + timestamp)"
codesign --force --deep --options runtime --timestamp \
  --identifier "${BUNDLE_ID}" \
  --entitlements "${ROOT}/Resources/Entitlements.plist" \
  --sign "${SIGN_IDENTITY}" \
  "${APP_PATH}"

codesign --verify --deep --strict --verbose=2 "${APP_PATH}"
codesign -dv --verbose=2 "${APP_PATH}" 2>&1 | grep -E 'Authority|Identifier|TeamIdentifier|Runtime' || true

echo "==> Empaquetando DMG"
STAGE="${BUILD_DIR}/dmg-stage"
rm -rf "${STAGE}"
mkdir -p "${STAGE}"
cp -R "${APP_PATH}" "${STAGE}/"
ln -sf /Applications "${STAGE}/Applications"
hdiutil create -volname "${APP_NAME}" -srcfolder "${STAGE}" -ov -format UDZO "${DMG_PATH}"

echo "==> Firmando DMG"
codesign --force --sign "${SIGN_IDENTITY}" --timestamp "${DMG_PATH}"

NOTARIZED=0
if [[ -n "${STACKDOCK_NOTARY_PROFILE:-}" ]]; then
  echo "==> Notarizando (keychain profile: ${STACKDOCK_NOTARY_PROFILE})"
  xcrun notarytool submit "${DMG_PATH}" --keychain-profile "${STACKDOCK_NOTARY_PROFILE}" --wait
  NOTARIZED=1
elif [[ -n "${STACKDOCK_APPLE_ID:-}" && -n "${STACKDOCK_NOTARY_PASSWORD:-}" ]]; then
  echo "==> Notarizando (Apple ID)"
  xcrun notarytool submit "${DMG_PATH}" \
    --apple-id "${STACKDOCK_APPLE_ID}" \
    --team-id "${TEAM_ID}" \
    --password "${STACKDOCK_NOTARY_PASSWORD}" \
    --wait
  NOTARIZED=1
else
  echo "⚠️  DMG firmado SIN notarizar (no hay credenciales notarytool)."
  echo "    Para notarizar una vez:"
  echo "    xcrun notarytool store-credentials StackDock-Notary \\"
  echo "      --apple-id \"TU_APPLE_ID\" --team-id ${TEAM_ID} --password \"app-specific-password\""
  echo "    luego: STACKDOCK_NOTARY_PROFILE=StackDock-Notary Scripts/build_signed_notarized_dmg.sh"
fi

if [[ "${NOTARIZED}" -eq 1 ]]; then
  echo "==> Grapando ticket"
  xcrun stapler staple "${DMG_PATH}"
  xcrun stapler validate "${DMG_PATH}"
  # También staple la .app dentro del build para instalar local
  xcrun stapler staple "${APP_PATH}" 2>/dev/null || true
fi

echo "==> Instalando app firmada en /Applications"
pkill -x "${APP_NAME}" 2>/dev/null || true
sleep 0.3
rm -rf "/Applications/${APP_NAME}.app"
cp -R "${APP_PATH}" "/Applications/${APP_NAME}.app"
xattr -cr "/Applications/${APP_NAME}.app" 2>/dev/null || true
open "/Applications/${APP_NAME}.app"

echo ""
echo "✅ DMG: ${DMG_PATH}"
echo "✅ App: /Applications/${APP_NAME}.app"
spctl --assess --type execute -vv "/Applications/${APP_NAME}.app" 2>&1 || true
ls -lh "${DMG_PATH}"
