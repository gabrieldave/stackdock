#!/usr/bin/env python3
from __future__ import annotations

import subprocess
import tempfile
from pathlib import Path

SECRETS = Path("/Users/daveax/Documents/VibeSystems/secrets.env")
HOST = "root@147.93.181.3"
WID = "hylP1FTMflH1rDuc"


def main() -> None:
    env = {}
    for line in SECRETS.read_text(errors="ignore").splitlines():
        if not line or line.strip().startswith("#") or "=" not in line:
            continue
        k, v = line.split("=", 1)
        env[k.strip()] = v.strip().strip('"').strip("'")
    with tempfile.TemporaryDirectory() as td:
        key = Path(td) / "k"
        key.write_text(env["N8N_API_KEY"])
        subprocess.check_call(
            ["scp", "-o", "BatchMode=yes", str(key), f"{HOST}:/tmp/n8n_key_only.txt"]
        )
    script = Path("/tmp/n8n_exec_check.sh")
    script.write_text(
        f"""#!/bin/bash
set -euo pipefail
chmod 600 /tmp/n8n_key_only.txt
API_KEY=$(cat /tmp/n8n_key_only.txt)
WID={WID}
curl -sS -H "X-N8N-API-KEY: $API_KEY" \
  "http://127.0.0.1:5677/api/v1/executions?workflowId=${{WID}}&limit=8" > /tmp/n8n_execs.json
python3 - <<'PY'
import json
d=json.load(open('/tmp/n8n_execs.json'))
items=d.get('data') or d
print('count', len(items) if isinstance(items, list) else type(d))
for e in (items if isinstance(items, list) else [])[:8]:
  print('exec', e.get('id'), 'status', e.get('status'), 'mode', e.get('mode'), 'started', e.get('startedAt'))
PY
rm -f /tmp/n8n_key_only.txt
"""
    )
    subprocess.check_call(
        ["scp", "-o", "BatchMode=yes", str(script), f"{HOST}:/tmp/n8n_exec_check.sh"]
    )
    p = subprocess.run(
        ["ssh", "-o", "BatchMode=yes", HOST, "bash", "/tmp/n8n_exec_check.sh"],
        capture_output=True,
        text=True,
    )
    print(p.stdout)
    if p.returncode:
        print(p.stderr[:400])
        raise SystemExit(p.returncode)


if __name__ == "__main__":
    main()
