#!/usr/bin/env python3
"""Deploy StackDock trial sequence workflow to n8n (secret-free Resend via $env)."""
from __future__ import annotations

import json
import re
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SECRETS = Path("/Users/daveax/Documents/VibeSystems/secrets.env")
SDK = Path(__file__).resolve().parent / "n8n_stackdock_trial_sequence.sdk.js"
HOST = "root@147.93.181.3"


def load_secrets() -> dict[str, str]:
    env: dict[str, str] = {}
    for line in SECRETS.read_text(errors="ignore").splitlines():
        if not line or line.strip().startswith("#") or "=" not in line:
            continue
        k, v = line.split("=", 1)
        env[k.strip()] = v.strip().strip('"').strip("'")
    return env


def extract_jscodes(sdk_text: str) -> list[str]:
    return re.findall(r"jsCode: `(.*?)`", sdk_text, flags=re.S)


def build_workflow(codes: list[str]) -> dict:
    register_code, evaluate_code, attach_code, stop_code = codes[:4]
    return {
        "name": "BLACK EYE — StackDock 7-Day Trial Sequence (EN/ES + Resend)",
        "nodes": [
            {
                "parameters": {
                    "httpMethod": "POST",
                    "path": "stackdock-trial",
                    "responseMode": "onReceived",
                    "options": {
                        "allowedOrigins": "*",
                        "responseData": '{"ok":true,"event":"stackdock.trial.lead"}',
                        "responseHeaders": {
                            "entries": [{"name": "Content-Type", "value": "application/json"}]
                        },
                    },
                },
                "id": "b1a00001-0001-4000-8000-000000000001",
                "name": "Webhook Descarga DMG",
                "type": "n8n-nodes-base.webhook",
                "typeVersion": 2.1,
                "position": [240, 220],
                "webhookId": "stackdock-trial",
            },
            {
                "parameters": {
                    "mode": "runOnceForAllItems",
                    "language": "javaScript",
                    "jsCode": register_code,
                },
                "id": "b1a00001-0002-4000-8000-000000000002",
                "name": "Registrar Trial y Correo 1",
                "type": "n8n-nodes-base.code",
                "typeVersion": 2,
                "position": [500, 220],
            },
            {
                "parameters": {
                    "rule": {
                        "interval": [{"field": "cronExpression", "expression": "0 9 * * *"}]
                    }
                },
                "id": "b1a00001-0003-4000-8000-000000000003",
                "name": "Revision Diaria 9AM",
                "type": "n8n-nodes-base.scheduleTrigger",
                "typeVersion": 1.2,
                "position": [240, 440],
            },
            {
                "parameters": {
                    "mode": "runOnceForAllItems",
                    "language": "javaScript",
                    "jsCode": evaluate_code,
                },
                "id": "b1a00001-0004-4000-8000-000000000004",
                "name": "Evaluar Dias 2-4-6-7 (EN y ES)",
                "type": "n8n-nodes-base.code",
                "typeVersion": 2,
                "position": [500, 440],
            },
            {
                "parameters": {
                    "mode": "runOnceForEachItem",
                    "language": "javaScript",
                    "jsCode": attach_code,
                },
                "id": "b1a00001-0008-4000-8000-000000000008",
                "name": "Adjuntar RESEND_API_KEY",
                "type": "n8n-nodes-base.code",
                "typeVersion": 2,
                "position": [720, 330],
            },
            {
                "parameters": {
                    "method": "POST",
                    "url": "https://api.resend.com/emails",
                    "sendHeaders": True,
                    "headerParameters": {
                        "parameters": [
                            {
                                "name": "Authorization",
                                "value": "=Bearer {{ $json.resendKey }}",
                            },
                            {"name": "Content-Type", "value": "application/json"},
                        ]
                    },
                    "sendBody": True,
                    "contentType": "raw",
                    "rawContentType": "application/json",
                    "body": "={{ $json.resendPayload }}",
                    "options": {},
                },
                "id": "b1a00001-0005-4000-8000-000000000005",
                "name": "Enviar Correo via Resend",
                "type": "n8n-nodes-base.httpRequest",
                "typeVersion": 4.2,
                "position": [940, 330],
            },
            {
                "parameters": {
                    "httpMethod": "POST",
                    "path": "stackdock-paid",
                    "responseMode": "lastNode",
                    "responseData": "firstEntryJson",
                    "options": {"allowedOrigins": "*"},
                },
                "id": "b1a00001-0006-4000-8000-000000000006",
                "name": "Webhook Compra Stripe",
                "type": "n8n-nodes-base.webhook",
                "typeVersion": 2.1,
                "position": [240, 660],
                "webhookId": "stackdock-paid",
            },
            {
                "parameters": {
                    "mode": "runOnceForAllItems",
                    "language": "javaScript",
                    "jsCode": stop_code,
                },
                "id": "b1a00001-0007-4000-8000-000000000007",
                "name": "Detener Secuencia al Comprar",
                "type": "n8n-nodes-base.code",
                "typeVersion": 2,
                "position": [500, 660],
            },
        ],
        "connections": {
            "Webhook Descarga DMG": {
                "main": [[{"node": "Registrar Trial y Correo 1", "type": "main", "index": 0}]]
            },
            "Registrar Trial y Correo 1": {
                "main": [[{"node": "Adjuntar RESEND_API_KEY", "type": "main", "index": 0}]]
            },
            "Revision Diaria 9AM": {
                "main": [
                    [{"node": "Evaluar Dias 2-4-6-7 (EN y ES)", "type": "main", "index": 0}]
                ]
            },
            "Evaluar Dias 2-4-6-7 (EN y ES)": {
                "main": [[{"node": "Adjuntar RESEND_API_KEY", "type": "main", "index": 0}]]
            },
            "Adjuntar RESEND_API_KEY": {
                "main": [[{"node": "Enviar Correo via Resend", "type": "main", "index": 0}]]
            },
            "Webhook Compra Stripe": {
                "main": [[{"node": "Detener Secuencia al Comprar", "type": "main", "index": 0}]]
            },
        },
        "settings": {"executionOrder": "v1"},
    }


def scp(local: Path, remote: str) -> None:
    subprocess.check_call(
        ["scp", "-o", "BatchMode=yes", str(local), f"{HOST}:{remote}"]
    )


def ssh(script: str) -> str:
    p = subprocess.run(
        ["ssh", "-o", "BatchMode=yes", HOST, "bash", "-lc", script],
        capture_output=True,
        text=True,
    )
    if p.returncode != 0:
        raise RuntimeError(p.stderr or p.stdout)
    return p.stdout


def main() -> None:
    env = load_secrets()
    api_key = env.get("N8N_API_KEY") or ""
    if not api_key:
        raise SystemExit("N8N_API_KEY EMPTY")

    codes = extract_jscodes(SDK.read_text(encoding="utf-8"))
    if len(codes) < 4:
        raise SystemExit(f"expected >=4 jsCode blocks, got {len(codes)}")
    wf = build_workflow(codes)

    with tempfile.TemporaryDirectory() as td:
        td_path = Path(td)
        wf_path = td_path / "wf.json"
        key_path = td_path / "key.txt"
        wf_path.write_text(json.dumps(wf), encoding="utf-8")
        key_path.write_text(api_key, encoding="utf-8")
        scp(wf_path, "/tmp/stackdock_trial_wf.json")
        scp(key_path, "/tmp/n8n_key_only.txt")

    out = ssh(
        r"""
set -euo pipefail
chmod 600 /tmp/n8n_key_only.txt
API_KEY=$(cat /tmp/n8n_key_only.txt)
curl -sS -H "X-N8N-API-KEY: $API_KEY" "http://127.0.0.1:5677/api/v1/workflows?limit=100" > /tmp/n8n_wfs.json
python3 - <<'PY'
import json
data=json.load(open('/tmp/n8n_wfs.json'))
items=data.get('data') or data
for w in items:
  n=w.get('name','')
  if '7-Day Trial' in n and 'StackDock' in n:
    print('EXISTING', w.get('id'), 'active='+str(w.get('active')))
PY
HTTP=$(curl -sS -o /tmp/n8n_create.json -w '%{http_code}' -X POST \
  -H "X-N8N-API-KEY: $API_KEY" -H 'Content-Type: application/json' \
  --data-binary @/tmp/stackdock_trial_wf.json \
  "http://127.0.0.1:5677/api/v1/workflows")
echo CREATE_HTTP:$HTTP
python3 - <<'PY'
import json
d=json.load(open('/tmp/n8n_create.json'))
wid=d.get('id')
print('CREATED_ID', wid)
print('CREATED_NAME', d.get('name'))
print('CREATED_ACTIVE', d.get('active'))
if not wid:
  print('CREATE_ERR', json.dumps(d)[:1000])
else:
  open('/tmp/n8n_trial_id.txt','w').write(wid)
PY
if [ -f /tmp/n8n_trial_id.txt ]; then
  WID=$(cat /tmp/n8n_trial_id.txt)
  ACT=$(curl -sS -o /tmp/n8n_act.json -w '%{http_code}' -X POST \
    -H "X-N8N-API-KEY: $API_KEY" \
    "http://127.0.0.1:5677/api/v1/workflows/${WID}/activate")
  echo ACTIVATE_HTTP:$ACT
  python3 - <<'PY'
import json
d=json.load(open('/tmp/n8n_act.json'))
print('ACTIVE', d.get('active'), 'ID', d.get('id'))
PY
fi
rm -f /tmp/n8n_key_only.txt
"""
    )
    print(out)


if __name__ == "__main__":
    main()
