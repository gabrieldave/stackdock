# BLACK EYE — 7-Day Trial Funnel Clone Guide

Reusable EN/ES trial sequence (webhook lead → Resend day 1 → daily cadence → Stripe stop).

## StackDock (live)

| Item | Value |
|---|---|
| Workflow | `BLACK EYE — StackDock 7-Day Trial Sequence (EN/ES + Resend)` |
| Trial webhook | `https://n8n.vibesystems.tech/webhook/stackdock-trial` |
| Paid stop webhook | `https://n8n.vibesystems.tech/webhook/stackdock-paid` |
| From | `David · BLACK EYE <stackdock@iareal.net>` |
| Reply-To | `stackdock@iareal.net` |
| Resend secret | n8n env `RESEND_API_KEY` (**never** in git / frontend) |

## Clone for Findaro (or any app)

1. Copy `blackeye-7day-funnel-template.json` + the StackDock workflow SDK/JSON.
2. Replace placeholders:
   - `{{APP_NAME}}`, `{{DOMAIN}}`, `{{SENDER_EMAIL}}`
   - `{{TRIAL_SLUG}}` / `{{PAID_SLUG}}` (unique webhook paths)
   - installer URL / SHA-256 / Team ID / pricing URLs
3. Ensure n8n env has `RESEND_API_KEY` (and optional `*_FROM_EMAIL` / `*_REPLY_TO`).
4. Create workflow via n8n API or UI → **Activate** (required for `$getWorkflowStaticData('global')` persistence).
5. Point landing modal `TRIAL_WEBHOOK_URL` to `.../webhook/{{TRIAL_SLUG}}`.
6. From the paid Stripe→license workflow, POST buyer email to `.../webhook/{{PAID_SLUG}}`.

## Cadence

| Step | When | Purpose |
|---|---|---|
| 1 | Immediate on trial email | Installer + 3 shortcuts |
| 2 | Day ≥2 | Chrome/Cursor split tip |
| 3 | Day ≥4 | Activity Monitor / soft CTA |
| 4 | Day ≥6 | Trial ends tomorrow |
| 5 | Day ≥7 | Trial ended + feedback ask |

## Frontend contract

```json
{ "email": "user@example.com", "lang": "en", "locale": "en", "product": "stackdock", "source": "landing_download_modal" }
```

`lang`/`locale` = `es` on `/es/`. Empty email → skip webhook, still download `.dmg`.

## Safety

- Do not hardcode Resend keys in nodes or repos.
- Do not create duplicate active workflows on the same webhook path.
- Paying buyers must hit the paid stop webhook so reminder emails stop.
