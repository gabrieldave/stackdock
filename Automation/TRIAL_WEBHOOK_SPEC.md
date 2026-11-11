# StackDock — Trial Lead Webhook + Resend 5-email sequence

## Endpoint

- **Method:** `POST`
- **URL (Coolify env `TRIAL_WEBHOOK_URL`):** `https://n8n.iareal.net/webhook/stackdock-trial-lead`
- **Content-Type:** `application/json`
- **CORS:** allow `https://stackdock.iareal.net` (and preview hosts if needed)

## Payload (landing modal)

```json
{
  "event": "stackdock.trial.lead",
  "email": "user@example.com",
  "locale": "en",
  "product": "stackdock",
  "version": "4.0.0",
  "source": "landing_download_modal",
  "dmg_url": "https://stackdock.iareal.net/download/StackDock-4.0.0.dmg",
  "dmg_sha256": "3449e4976099f77f5b083fe9e4a5c6cfe01087821010dc13768eddac7f4a8920",
  "team_id": "YH6W55MP95",
  "ts": "2026-11-11T02:00:00.000Z"
}
```

| Field | Notes |
|---|---|
| `email` | Required when webhook is called (landing skips POST if empty) |
| `locale` | `en` (default `/`) or `es` (`/es/`) |
| `dmg_sha256` / `team_id` | Integrity + notarization proof mirrored in the modal |

## n8n flow (recommended)

1. **Webhook** path `stackdock-trial-lead` → respond `200 {"ok":true}` immediately
2. **IF** email looks valid
3. **Data store / table** upsert by email (`product=stackdock`, `trial_started_at`)
4. **Resend** send Email #1 immediately
5. **Wait** nodes schedule Emails #2–#5 (or use Resend audiences + delayed sends)

## 5-email conversion sequence (Resend)

From: `stackdock@iareal.net` · Reply-To: `stackdock@iareal.net`

| # | Delay | EN subject | Goal |
|---|---|---|---|
| 1 | 0 min | Your StackDock 7-day trial starts now | DMG link + SHA-256 + Team ID + ⌥+D tip |
| 2 | Day 1 | Summon docks on every display | Dual-monitor stacked edge tip |
| 3 | Day 3 | Split Chrome Work / Personal icons | Profile badge demo CTA |
| 4 | Day 5 | Teleport windows with Shift+Click | Feature close + soft Personal/Pro CTA |
| 5 | Day 7 | Trial ends today — keep StackDock | Personal **$9.99** / Pro **$19** + 14-day refund |

Spanish (`locale=es`): same cadence; subjects localized. Include checkout links from Coolify `STRIPE_CHECKOUT_URL_PERSONAL` / `_PRO`.

## Security

- Do not log full payloads with PII longer than needed
- Rate-limit webhook (n8n / reverse proxy)
- Never embed Resend or Stripe secrets in the static landing — only the webhook URL
