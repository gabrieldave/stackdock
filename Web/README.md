# StackDock web 4.0.6 — Concepto A "Plano de escritorio"

Arquetipo 02 Precision Industrial TE · BLACK EYE · Vite + TypeScript, sin framework en runtime.

## Comandos

```bash
npm ci
npm run dev        # prerender + servidor Vite
npm run build      # typecheck → prerender EN/ES → dist/ → dist-preview/StackDock-Preview.html
```

## Lo único que edita marketing: `src/config/funnel.ts`

| Campo | Estado |
|---|---|
| `version` / `build` / `minMacOS` / `teamId` | 4.0.6 · 406 · 13.0+ · YH6W55MP95 |
| `dmgUrl` | `/download/StackDock-4.0.6.dmg` → copiar el DMG notarizado a `public/download/` |
| `sha256` | **`PENDING_SHA256_V406`** → pegar el hash del DMG notarizado |
| `youtubeVideoId` | **`PENDING_VIDEO_ID`** → mientras tanto se ve la fachada técnica (sin iframe) |
| `trialWebhookUrl` | **`REPLACE_…`** → webhook n8n del trial (email opcional). Mientras tanto: modo demo etiquetado |
| `checkoutEndpoint` | `/api/checkout` (nginx lo reenvía a `CHECKOUT_UPSTREAM`) |
| `panel.callouts` | Posición (%) de ①–⑥: ajustar cuando lleguen las capturas reales |
| Copy EN/ES | `es: Copy` obliga a que ambos idiomas tengan las mismas claves |

Capturas del Panel 4.0.6: `public/media/media_control_panel_en.webp` y `…_es.webp`. Si no existen, se muestra el wireframe SVG.

## Contrato del checkout

`POST /api/checkout` con `{ "plan": "personal" | "pro", "addFindaro": boolean, "locale": "en" | "es", "customerEmail"?: string }` → responder `{ "url": "https://…" }`. La web redirige solo a URLs `https:`. Si falla o tarda más de 15 s, ofrece reintentar o escribir por email.

## Despliegue (Coolify)

- `docker-compose.yaml`: puerto `127.0.0.1:3048:80`, `read_only` + tmpfs `/tmp`, health en `/api/health`.
- Variables: `CHECKOUT_UPSTREAM` (webhook del Payment Gateway Universal) y `NGINX_RESOLVER` (DNS; `127.0.0.11` para servicios internos).
- Idioma: `/` sin cookie y con `CF-IPCountry` de un país hispanohablante → 302 a `/es/`. La cookie `stackdock-lang` (1 año) siempre manda. Los bots nunca se redirigen. Requiere el DNS de Cloudflare en modo proxy.
- `/updates/latest.json(.sig)` es el feed del actualizador de la app: el pipeline de release debe escribir en `public/updates/`.
- `/#buy` (botón Comprar de la app) cae en la sección de precios.
