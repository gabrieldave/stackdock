#!/usr/bin/env bash
# Convierte icon.png (1024²) → Resources/AppIcon.icns y recompila StackDock
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC=""
for candidate in \
  "${1:-}" \
  "$HOME/Desktop/icon.png" \
  "$HOME/Downloads/icon.png" \
  "$HOME/Desktop/StackDock.png" \
  "$HOME/Downloads/StackDock.png" \
  "$HOME/Desktop/AppIcon.png" \
  "$ROOT/Resources/icon.png"
do
  if [[ -n "${candidate}" && -f "${candidate}" ]]; then
    SRC="${candidate}"
    break
  fi
done

if [[ -z "${SRC}" ]]; then
  echo "❌ No encontré icon.png (Desktop/Downloads/Resources)."
  echo "   Uso: Scripts/build_icns.sh /ruta/a/icon-1024.png"
  exit 1
fi

echo "==> Icono fuente: ${SRC}"
ICONSET="${ROOT}/build/AppIcon.iconset"
rm -rf "${ICONSET}"
mkdir -p "${ICONSET}" "${ROOT}/Resources"

# Normalizar a 1024 cuadrado
TMP1024="${ROOT}/build/icon-1024.png"
sips -z 1024 1024 "${SRC}" --out "${TMP1024}" >/dev/null

make_size() {
  local size="$1" name="$2"
  sips -z "${size}" "${size}" "${TMP1024}" --out "${ICONSET}/icon_${name}.png" >/dev/null
}

make_size 16 16x16
make_size 32 16x16@2x
make_size 32 32x32
make_size 64 32x32@2x
make_size 128 128x128
make_size 256 128x128@2x
make_size 256 256x256
make_size 512 256x256@2x
make_size 512 512x512
make_size 1024 512x512@2x

iconutil -c icns "${ICONSET}" -o "${ROOT}/Resources/AppIcon.icns"
echo "==> Generado Resources/AppIcon.icns"

# Registrar en Info.plist
/usr/libexec/PlistBuddy -c "Delete :CFBundleIconFile" "${ROOT}/Resources/Info.plist" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string AppIcon" "${ROOT}/Resources/Info.plist"

# Copiar icns dentro del bundle en el próximo build_local
echo "==> Recompilando e instalando con icono…"
# Parche mínimo: asegurar que build_local copie el icns
if ! grep -q 'AppIcon.icns' "${ROOT}/Scripts/build_local.sh"; then
  # insert copy after Info.plist copy via awk once
  python3 - <<'PY'
from pathlib import Path
p=Path('/Users/davidai/.cursor/dock/Scripts/build_local.sh')
t=p.read_text()
needle='cp "${ROOT}/Resources/Info.plist" "${APP_PATH}/Contents/Info.plist"'
inject=needle+'\ncp "${ROOT}/Resources/AppIcon.icns" "${APP_PATH}/Contents/Resources/AppIcon.icns" 2>/dev/null || true'
if 'AppIcon.icns' not in t:
  t=t.replace(needle, inject)
  p.write_text(t)
  print('build_local patched for icns')
else:
  print('build_local already has icns')
PY
fi

"${ROOT}/Scripts/build_local.sh"
echo "✅ Icono aplicado en /Applications/StackDock.app"
