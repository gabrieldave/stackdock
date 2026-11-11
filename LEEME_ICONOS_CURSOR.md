# Kit Completo: Iconos Nativo macOS + Favicons Web + Landing Actualizada (StackDock 4.0)

Todo viene ya conectado en sus carpetas exactas para copiar directo en la raíz de tu proyecto en **Cursor**:

1. **`Resources/` (Para la App de macOS)**:
   - `Resources/AppIcon.icns` — Icono nativo compilado con máscara squircle oficial de macOS (16px hasta 1024px Retina), listo para copiarse dentro de `StackDock.app/Contents/Resources/AppIcon.icns`.
   - `Resources/icon.png` — Fuente maestra de `1024x1024` con margen y sombra oficial Apple HIG por si corres `Scripts/build_icns.sh`.
   - `Resources/icon-fullbleed-1024.png` — Versión a sangre completa `1024x1024`.

2. **`Web/` (Lista para subir al VPS en `stackdock.iareal.net`)**:
   - `Web/index.html` — Ya tiene inyectadas todas las etiquetas `<link rel="icon">`, `<link rel="apple-touch-icon">`, `site.webmanifest` y `og:image`.
   - `Web/public/favicon.ico` (16/32/48), `favicon.svg`, `favicon-16x16.png`, `favicon-32x32.png`, `apple-touch-icon.png` (180x180), `android-chrome-192x192.png`, `android-chrome-512x512.png`, `site.webmanifest`, `og-image.jpg` (1200x630) y `Web/public/media/*.webp`.
