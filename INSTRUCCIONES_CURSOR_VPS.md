# Paquete de Despliegue: StackDock 4.0 Web (`stackdock.iareal.net`)

Este paquete está limpio (sin cadenas Base64 pesadas) para abrirlo directamente en **Cursor** y desplegarlo hoy mismo en tu VPS (Coolify + Cloudflare).

## Estructura del paquete
- `Web/index.html` — Landing page interactiva 3D estilo Apple (bilingüe `ES | EN`, galería panorámica para monitores grandes, auto-zoom 3D vertical en móviles y menú móvil desplegable).
- `Web/public/media/*.webp` — Tus 6 capturas reales en Mac mini M4 optimizadas en formato WebP (~295 KB en total) y limpias de datos personales de escritorio.

## Pasos rápidos para pedirle a Cursor antes del deploy en tu VPS
1. **Conectar Stripe y descarga del `.dmg`**:
   En `Web/index.html`, busca el bloque `const STACKDOCK_CONFIG = { ... }` al inicio del `<script>` y pega tu enlace real de **Stripe Payment Link** en `stripeCheckoutUrl` y la URL pública de tu instalador notarizado en `dmgDownloadUrl` (por ejemplo desde Cloudflare R2).
2. **Generar Favicons e imagen OpenGraph**:
   Pídele a Cursor tu rutina habitual de favicons (`favicon.ico`, `apple-touch-icon.png` 180×180, `og-image.png` 1200×630) usando `Resources/AppIcon.icns` o tu PNG maestro de 1024×1024, y añade `<meta property="og:image" content="https://stackdock.iareal.net/og-image.png" />` en el `<head>`.
3. **Compilar Tailwind CSS estático (Opcional recomendado para Lighthouse 100)**:
   Si quieres eliminar el script `cdn.tailwindcss.com` en producción, ejecuta `npx tailwindcss -i input.css -o ./public/styles.min.css --minify` desde Cursor y enlázalo con `<link rel="stylesheet" href="./public/styles.min.css">`.
4. **Recordatorio crítico de seguridad antes de abrir cobros**:
   En tu flujo de n8n (`Automation/n8n_stackdock_stripe_resend.json`), asegúrate de validar el encabezado `Stripe-Signature` con tu `whsec_...` ([Documentación oficial de Stripe Webhooks](https://docs.stripe.com/webhooks)) antes de generar claves `SDOCK-...`, y verifica que `Scripts/build_signed_notarized_dmg.sh` copie `Resources/AppIcon.icns` al `.app` antes de firmar.
