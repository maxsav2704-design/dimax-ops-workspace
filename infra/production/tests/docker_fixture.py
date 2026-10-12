#!/usr/bin/env python3
"""No Docker access: record only commands from the disposable deploy.sh tests."""
import json
import os
from pathlib import Path
import sys

args = sys.argv[1:]
with Path(os.environ["FIXTURE_DOCKER_LOG"]).open("a") as log:
    log.write(json.dumps(args) + "\n")
if os.getenv("FIXTURE_FAIL_COMMAND") in args:
    print("synthetic failure", file=sys.stderr)
    raise SystemExit(1)
if "config" in args:
    print(Path(os.environ["FIXTURE_COMPOSE_JSON"]).read_text())
elif args[:2] == ["image", "inspect"]:
    base = "http://localhost:8000" if os.getenv("FIXTURE_BAD_IMAGE") else "https://api.dimax.co.il"
    print(json.dumps([{"Config": {"Env": [f"NEXT_PUBLIC_API_BASE_URL={base}"], "User": "10001:10001"}}]))
