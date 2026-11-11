#!/usr/bin/env python3
from __future__ import annotations

import json
import subprocess
import tempfile
import uuid
from pathlib import Path

SECRETS = Path("/Users/daveax/Documents/VibeSystems/secrets.env")
HOST = "root@147.93.181.3"
WID = "dN8RJkBbIPb4Ae1r"


def load_secrets() -> dict[str, str]:
    env: dict[str, str] = {}
    for line in SECRETS.read_text(errors="ignore").splitlines():
        if not line or line.strip().startswith("#") or "=" not in line:
            continue
        k, v = line.split("=", 1)
        env[k.strip()] = v.strip().strip('"').strip("'")
    return env


def main() -> None:
    api_key = load_secrets().get("N8N_API_KEY") or ""
    if not api_key:
        raise SystemExit("N8N_API_KEY EMPTY")

    with tempfile.TemporaryDirectory() as td:
        key = Path(td) / "key.txt"
        key.write_text(api_key)
        subprocess.check_call(
            ["scp", "-o", "BatchMode=yes", str(key), f"{HOST}:/tmp/n8n_key_only.txt"]
        )

    remote = r"""
set -euo pipefail
chmod 600 /tmp/n8n_key_only.txt
API_KEY=$(cat /tmp/n8n_key_only.txt)
WID=dN8RJkBbIPb4Ae1r
curl -sS -H "X-N8N-API-KEY: $API_KEY" "http://127.0.0.1:5677/api/v1/workflows/$WID" > /tmp/sd_lic_wf.json
python3 <<'PY'
import json, uuid
wf=json.load(open('/tmp/sd_lic_wf.json'))
nodes=wf['nodes']
names={n['name'] for n in nodes}
if 'Notify Trial Stop' not in names:
  stop_node={
    "parameters": {
      "method": "POST",
      "url": "https://n8n.vibesystems.tech/webhook/stackdock-paid",
      "sendHeaders": True,
      "headerParameters": {"parameters": [{"name":"Content-Type","value":"application/json"}]},
      "sendBody": True,
      "specifyBody": "json",
      "jsonBody": "={{ JSON.stringify({ email: $json.email, source: 'stackdock-stripe-license', stripeEventId: $json.stripeEventId || null }) }}",
      "options": {"response": {"response": {"neverError": True}}}
    },
    "id": str(uuid.uuid4()),
    "name": "Notify Trial Stop",
    "type": "n8n-nodes-base.httpRequest",
    "typeVersion": 4.2,
    "position": [448, 180]
  }
  nodes.append(stop_node)
  con=wf.setdefault('connections', {})
  gen=con.setdefault('Generate SDOCK License', {}).setdefault('main', [[]])
  if not gen:
    gen.append([])
  targets=gen[0]
  if not any(t.get('node')=='Notify Trial Stop' for t in targets):
    targets.append({"node":"Notify Trial Stop","type":"main","index":0})
  print('WIRED_OK')
else:
  print('ALREADY_WIRED')

payload={
  'name': wf['name'],
  'nodes': wf['nodes'],
  'connections': wf['connections'],
  'settings': wf.get('settings') or {'executionOrder':'v1'},
}
open('/tmp/sd_lic_wf_put.json','w').write(json.dumps(payload))
PY
HTTP=$(curl -sS -o /tmp/sd_lic_put_resp.json -w '%{http_code}' -X PUT \
  -H "X-N8N-API-KEY: $API_KEY" -H 'Content-Type: application/json' \
  --data-binary @/tmp/sd_lic_wf_put.json \
  "http://127.0.0.1:5677/api/v1/workflows/$WID")
echo PUT_HTTP:$HTTP
python3 <<'PY'
import json
d=json.load(open('/tmp/sd_lic_put_resp.json'))
print('id', d.get('id'), 'active', d.get('active'))
print('has_notify', any(n.get('name')=='Notify Trial Stop' for n in d.get('nodes',[])))
if not d.get('id'):
  print(str(d)[:800])
PY
curl -sS -o /tmp/sd_lic_act.json -w 'ACTIVATE_HTTP:%{http_code}\n' -X POST \
  -H "X-N8N-API-KEY: $API_KEY" \
  "http://127.0.0.1:5677/api/v1/workflows/$WID/activate" || true
rm -f /tmp/n8n_key_only.txt
"""
    p = subprocess.run(
        ["ssh", "-o", "BatchMode=yes", HOST, "bash", "-lc", remote],
        capture_output=True,
        text=True,
    )
    print(p.stdout)
    if p.returncode != 0:
        print(p.stderr[:500])
        raise SystemExit(p.returncode)


if __name__ == "__main__":
    main()
