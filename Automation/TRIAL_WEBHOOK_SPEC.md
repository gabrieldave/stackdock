# StackDock — Trial Lead Webhook + Resend 5-email sequence

## Live endpoints

| Role | URL |
|---|---|
| Trial lead | `https://n8n.vibesystems.tech/webhook/stackdock-trial` |
| Paid stop | `https://n8n.vibesystems.tech/webhook/stackdock-paid` |
| Workflow | `BLACK EYE — StackDock 7-Day Trial Sequence (EN/ES + Resend)` (`hylP1FTMflH1rDuc`) |

## Payload (landing modal)

```json
{
  "event": "stackdock.trial.lead",
  "email": "user@example.com",
  "lang": "en",
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

`lang` / `locale`: `en` on `/`, `es` on `/es/`.

## Secrets

- Resend: n8n env `RESEND_API_KEY` (never in git / frontend)
- From/Reply: `STACKDOCK_FROM_EMAIL` / `STACKDOCK_REPLY_TO` (fallback `stackdock@iareal.net`)

## Clone

See `FUNNEL_CLONE_GUIDE.md` + `blackeye-7day-funnel-template.json`.
