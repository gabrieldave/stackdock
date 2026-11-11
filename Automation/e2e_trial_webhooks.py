#!/usr/bin/env python3
from __future__ import annotations

import json
import time
import urllib.error
import urllib.request

TRIAL = "https://n8n.vibesystems.tech/webhook/stackdock-trial"
PAID = "https://n8n.vibesystems.tech/webhook/stackdock-paid"


def post(url: str, payload: dict) -> tuple[int, str]:
    data = json.dumps(payload).encode()
    req = urllib.request.Request(
        url,
        data=data,
        method="POST",
        headers={
            "Content-Type": "application/json",
            "User-Agent": "StackDock-Funnel-Test/1.0",
            "Origin": "https://stackdock.iareal.net",
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=45) as r:
            return r.status, r.read().decode("utf-8", "ignore")
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode("utf-8", "ignore")[:800]


def main() -> None:
    tests = [
        (
            TRIAL,
            {
                "email": "daveax+stackdock-trial-en@iareal.net",
                "lang": "en",
                "locale": "en",
                "product": "stackdock",
                "source": "e2e_curl",
            },
        ),
        (
            TRIAL,
            {
                "email": "daveax+stackdock-trial-es@iareal.net",
                "lang": "es",
                "locale": "es",
                "product": "stackdock",
                "source": "e2e_curl",
            },
        ),
        (
            PAID,
            {
                "email": "daveax+stackdock-trial-en@iareal.net",
                "source": "e2e_curl",
            },
        ),
    ]
    for url, payload in tests:
        code, body = post(url, payload)
        label = payload.get("lang") or "paid"
        print(f"{url.rsplit('/', 1)[-1]} lang={label} HTTP={code} body={body[:240]}")
        time.sleep(1.2)


if __name__ == "__main__":
    main()
