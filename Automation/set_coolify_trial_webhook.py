#!/usr/bin/env python3
from __future__ import annotations

import json
import subprocess
import tempfile
from pathlib import Path

SECRETS = Path("/Users/daveax/Documents/VibeSystems/secrets.env")
HOST = "root@147.93.181.3"
APP = "rg1yofysovlxtm2h2dbl4e8h"
VALUE = "https://n8n.vibesystems.tech/webhook/stackdock-trial"


def load_secrets() -> dict[str, str]:
    env: dict[str, str] = {}
    for line in SECRETS.read_text(errors="ignore").splitlines():
        if not line or line.strip().startswith("#") or "=" not in line:
            continue
        k, v = line.split("=", 1)
        env[k.strip()] = v.strip().strip('"').strip("'")
    return env


def main() -> None:
    token = load_secrets().get("COOLIFY_API_TOKEN") or ""
    if not token:
        raise SystemExit("COOLIFY_API_TOKEN EMPTY")
    with tempfile.TemporaryDirectory() as td:
        key = Path(td) / "k.txt"
        key.write_text(token)
        subprocess.check_call(
            ["scp", "-o", "BatchMode=yes", str(key), f"{HOST}:/tmp/cf_key.txt"]
        )

    remote = f"""
set -euo pipefail
chmod 600 /tmp/cf_key.txt
TOKEN=$(cat /tmp/cf_key.txt)
UUID={APP}
# Discover env API
for path in /api/v1/applications/$UUID /api/v1/applications/$UUID/envs; do
  code=$(curl -sS -o /tmp/cf_probe.json -w '%{{http_code}}' -H "Authorization: Bearer $TOKEN" "http://127.0.0.1:8000$path" || true)
  echo PROBE:$path:$code
done
python3 <<'PY'
import json
app=json.load(open('/tmp/cf_probe.json')) if open('/tmp/cf_probe.json').read(1) else {{}}
# If full app object, print env-related keys
if isinstance(app, dict):
  print('keys', [k for k in app.keys() if 'env' in k.lower() or 'var' in k.lower()][:20])
PY

# Create/update env via POST commonly used by Coolify v4
BODY='{{"key":"TRIAL_WEBHOOK_URL","value":"{VALUE}","is_preview":false,"is_literal":true,"is_shown_once":false}}'
code=$(curl -sS -o /tmp/cf_env_post.json -w '%{{http_code}}' -X POST \
  -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  --data '$BODY' \
  "http://127.0.0.1:8000/api/v1/applications/$UUID/envs" || true)
echo POST_ENV:$code
# fix: use proper body file
python3 - <<'PY'
import json
open('/tmp/cf_env_body.json','w').write(json.dumps({{
  'key':'TRIAL_WEBHOOK_URL',
  'value':'{VALUE}',
  'is_preview': False,
  'is_literal': True,
}}))
PY
code=$(curl -sS -o /tmp/cf_env_post.json -w '%{{http_code}}' -X POST \
  -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  --data-binary @/tmp/cf_env_body.json \
  "http://127.0.0.1:8000/api/v1/applications/$UUID/envs" || true)
echo POST_ENV2:$code
python3 - <<'PY'
import json
try:
  print(json.load(open('/tmp/cf_env_post.json')))
except Exception as e:
  print('parse', e, open('/tmp/cf_env_post.json').read()[:300])
PY
rm -f /tmp/cf_key.txt
"""
    # The f-string above got messy with braces. Use a simpler remote script file.
    script = Path("/tmp/set_coolify_trial.sh")
    script.write_text(
        f"""#!/bin/bash
set -euo pipefail
chmod 600 /tmp/cf_key.txt
TOKEN=$(cat /tmp/cf_key.txt)
UUID={APP}
python3 - <<'PY'
import json
open('/tmp/cf_env_body.json','w').write(json.dumps({{
  'key': 'TRIAL_WEBHOOK_URL',
  'value': '{VALUE}',
  'is_preview': False,
  'is_literal': True,
}}))
print('body_ok')
PY
for path in \
  "/api/v1/applications/$UUID/envs" \
  "/api/v1/applications/$UUID/environment-variables"
 do
  code=$(curl -sS -o /tmp/cf_env_post.json -w '%{{http_code}}' -X POST \
    -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
    --data-binary @/tmp/cf_env_body.json \
    "http://127.0.0.1:8000$path" || true)
  echo "POST $path -> $code"
  python3 - <<'PY'
import json
try:
  d=json.load(open('/tmp/cf_env_post.json'))
  print({{k:d.get(k) for k in list(d)[:8]}} if isinstance(d,dict) else d)
except Exception as e:
  print(open('/tmp/cf_env_post.json').read()[:240])
PY
 done
# trigger deploy so entrypoint picks env
code=$(curl -sS -o /tmp/cf_dep.json -w '%{{http_code}}' -X POST \
  -H "Authorization: Bearer $TOKEN" \
  "http://127.0.0.1:8000/api/v1/deploy?uuid=$UUID" || true)
echo DEPLOY:$code
python3 - <<'PY'
import json
try:
  print(json.load(open('/tmp/cf_dep.json')))
except Exception:
  print(open('/tmp/cf_dep.json').read()[:240])
PY
rm -f /tmp/cf_key.txt
"""
    )
    subprocess.check_call(
        ["scp", "-o", "BatchMode=yes", str(script), f"{HOST}:/tmp/set_coolify_trial.sh"]
    )
    p = subprocess.run(
        ["ssh", "-o", "BatchMode=yes", HOST, "bash", "/tmp/set_coolify_trial.sh"],
        capture_output=True,
        text=True,
    )
    print(p.stdout)
    if p.returncode != 0:
        print(p.stderr[:500])
        raise SystemExit(p.returncode)


if __name__ == "__main__":
    main()
