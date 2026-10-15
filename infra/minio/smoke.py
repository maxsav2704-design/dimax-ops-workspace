"""Build and verify only a uniquely named, disposable S3 environment."""
from __future__ import annotations

import json
from pathlib import Path
import subprocess
import sys
import time
import urllib.error
import urllib.request
from uuid import uuid4

PAYLOAD = "DIMAX synthetic storage proof"


def anonymous_probe():
    for path in ("/acceptance/test.txt", "/acceptance?list-type=2"):
        try:
            urllib.request.urlopen("http://minio:9000" + path, timeout=10)
        except urllib.error.HTTPError as exc:
            assert exc.code == 403, f"Expected anonymous denial, got {exc.code}"
        else:
            raise AssertionError("Anonymous storage access unexpectedly allowed")
    print("PASS: anonymous object and bucket listing denied")


def smoke():
    project = "dimax-minio-check-" + uuid4().hex[:12]
    config = Path(__file__).with_name("compose.test.yml").resolve()
    prefix = ["docker", "compose", "-p", project, "-f", str(config)]

    def command(*args, check=True, timeout=240):
        result = subprocess.run([*prefix, *args], text=True, capture_output=True, timeout=timeout)
        if check and result.returncode:
            raise RuntimeError(f"Compose {args[0]} failed:\n{result.stderr[-4000:]}")
        return result

    def mc(script, check=True):
        return command("run", "--rm", "-T", "--no-deps", "client", script, check=check)

    def ready():
        for _ in range(30):
            if mc("mc ls local > /dev/null", check=False).returncode == 0:
                return
            time.sleep(2)
        raise RuntimeError("S3 did not become ready within the bounded retry window")

    try:
        command("build", "minio", "client", timeout=900)
        command("pull", "probe")
        command("up", "-d", "--no-build", "--pull", "never", "minio")
        ready()
        # Repeat the actual workspace initializer to check idempotent private buckets.
        for _ in range(2):
            mc("mc mb -p local/acceptance || true; mc anonymous set none local/acceptance")
        mc(f"printf '%s' '{PAYLOAD}' | mc pipe local/acceptance/test.txt")
        assert mc("mc cat local/acceptance/test.txt").stdout == PAYLOAD
        command("run", "--rm", "-T", "--no-deps", "probe")
        command("up", "-d", "--no-build", "--pull", "never", "--force-recreate", "minio")
        ready()
        assert mc("mc cat local/acceptance/test.txt").stdout == PAYLOAD
        command("run", "--rm", "-T", "--no-deps", "probe")
        print(json.dumps({"status": "PASS", "upload_download": True,
                          "anonymous_access_denied": True, "recreate_preserves_object": True,
                          "existing_volume_upgrade_verified": False}))
    finally:
        # The project ID is generated here, never accepted from caller/environment.
        command("down", "--volumes", "--remove-orphans")


if __name__ == "__main__":
    if sys.argv[1:] == ["--anonymous-probe"]:
        anonymous_probe()
    elif sys.argv[1:]:
        raise SystemExit("No external project or cleanup target is accepted")
    else:
        smoke()
