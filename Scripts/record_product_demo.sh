#!/usr/bin/env bash
# StackDock — grabación guiada del demo de producto (~15s) → MP4 web < 4 MB
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT_DIR="${ROOT}/Web/public/media"
mkdir -p "${OUT_DIR}"
RAW="${OUT_DIR}/_demo_raw.mov"
MP4="${OUT_DIR}/stackdock-demo.mp4"
DURATION="${DEMO_SECONDS:-15}"
FPS="${DEMO_FPS:-60}"

echo "==> StackDock Product Demo Recorder"
echo "    Destino: ${MP4}"
echo "    Duración: ${DURATION}s @ ${FPS}fps"
echo ""
echo "Durante la grabación haz esto (≈15s):"
echo "  1) ⌥D  → ocultar / mostrar StackDock"
echo "  2) Abre / enfoca 2 perfiles de Chrome"
echo "  3) Shift+Clic en un icono Chrome → teletransporte de monitor"
echo ""

# Lista dispositivos avfoundation (vídeo)
echo "==> Cámaras / pantallas disponibles (avfoundation):"
ffmpeg -f avfoundation -list_devices true -i "" 2>&1 | sed -n '/AVFoundation.*devices/,/audio devices/p' || true
echo ""

# Preferencia: captura de pantalla vía índice de dispositivo "Capture screen 0"
# Override: DEMO_AV_DEVICE="Capture screen 0"
AV_DEVICE="${DEMO_AV_DEVICE:-Capture screen 0}"

echo "Grabando en 3…"
sleep 1; echo "2…"; sleep 1; echo "1…"; sleep 1
echo "🔴 REC ${DURATION}s — ¡ahora!"

# Grabación pantalla principal (sin audio) — mov temporal
ffmpeg -y -f avfoundation -framerate "${FPS}" -capture_cursor 1 -i "${AV_DEVICE}:none" \
  -t "${DURATION}" -pix_fmt yuv420p -c:v h264_videotoolbox -b:v 8M \
  "${RAW}"

echo "==> Comprimiendo a MP4 web (objetivo < 4 MB)…"
ffmpeg -y -i "${RAW}" \
  -vf "scale=1920:-2:flags=lanczos,fps=30" \
  -c:v libx264 -preset slow -crf 28 -pix_fmt yuv420p -movflags +faststart \
  -an "${MP4}"

rm -f "${RAW}"
SIZE=$(stat -f%z "${MP4}" 2>/dev/null || stat -c%s "${MP4}")
SIZE_MB=$(python3 -c "print(round(${SIZE}/1024/1024, 2))")
echo "✅ Demo listo: ${MP4} (${SIZE_MB} MB)"
if python3 -c "import sys; sys.exit(0 if ${SIZE} < 4*1024*1024 else 1)"; then
  echo "   Peso OK para autoplay web (< 4 MB)."
else
  echo "   ⚠️ > 4 MB — recomprimiendo más agresivo…"
  ffmpeg -y -i "${MP4}" \
    -vf "scale=1280:-2:flags=lanczos,fps=24" \
    -c:v libx264 -preset slow -crf 32 -pix_fmt yuv420p -movflags +faststart \
    -an "${OUT_DIR}/stackdock-demo.tmp.mp4"
  mv "${OUT_DIR}/stackdock-demo.tmp.mp4" "${MP4}"
  SIZE=$(stat -f%z "${MP4}")
  echo "   Nuevo peso: $(python3 -c "print(round(${SIZE}/1024/1024, 2))") MB"
fi

echo ""
echo "Abre Web/index.html y verifica el bloque de galería."
open "${OUT_DIR}"
