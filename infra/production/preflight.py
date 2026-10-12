"""Read rendered Compose on stdin. Never print its environment or execute env files."""
from __future__ import annotations

import argparse
import importlib.util
import ipaddress
import json
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("backend_env_validator", ROOT / "backend/scripts/validate_production_env.py")
validator = importlib.util.module_from_spec(spec)
spec.loader.exec_module(validator)

BACKEND_SERVICES = ("api", "outbox-worker", "maintenance-worker", "sync-gc-worker", "sync-health", "migrate", "bootstrap")
SHARED_SETTINGS = ("DATABASE_URL", "JWT_SECRET", "FACTORY_APPROVAL_EMAIL_KEY", "PUBLIC_BASE_URL", "PUBLIC_APP_BASE_URL",
                   "MINIO_ENDPOINT", "MINIO_ACCESS_KEY", "MINIO_SECRET_KEY", "MINIO_BUCKET", "MINIO_SECURE",
                   "EMAIL_ENABLED", "SMTP_HOST", "SMTP_PORT", "SMTP_TLS", "SMTP_USER", "SMTP_PASSWORD", "SMTP_FROM")


def public_host(value):
    if not isinstance(value, str) or value != value.lower() or len(value) > 253:
        return False
    if value.endswith((".localhost", ".local", ".internal", ".test", ".invalid", ".example")):
        return False
    labels = value.split(".")
    if len(labels) < 2 or not all(re.fullmatch(r"[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?", label) for label in labels):
        return False
    try:
        ipaddress.ip_address(value)
    except ValueError:
        return not validator.has_placeholder_value(value)
    return False


def validate(config, *, bootstrap=False, inspect_admin_image=False):
    errors = []
    services = config.get("services", {})
    if not re.fullmatch(r"dimax-(?:production|staging)(?:-[a-z0-9_-]+)?", config.get("name", "")):
        errors.append("Compose project name must identify dimax-production or dimax-staging, not a local workspace")
    missing = [name for name in (*BACKEND_SERVICES, "admin", "gateway") if name not in services]
    if missing:
        return errors + [f"Required service missing: {name}" for name in missing]
    api = services["api"]
    env = api.get("environment", {})
    edge_env = services["gateway"].get("environment", {})
    api_host, admin_host = edge_env.get("DIMAX_API_HOST", ""), edge_env.get("DIMAX_ADMIN_HOST", "")
    for key in ("DIMAX_API_HOST", "DIMAX_ADMIN_HOST"):
        if not public_host(edge_env.get(key, "")):
            errors.append(f"{key} must be a lowercase public DNS hostname, without URL syntax or placeholders")
    if api_host == admin_host:
        errors.append("API and admin must use different public hosts")
    errors.extend(validator.validate_email("DIMAX_TLS_EMAIL", edge_env.get("DIMAX_TLS_EMAIL", "")))
    if not public_host(edge_env.get("DIMAX_TLS_EMAIL", "").rpartition("@")[2]):
        errors.append("DIMAX_TLS_EMAIL must use a public mail domain")
    for key, expected in (("PUBLIC_BASE_URL", f"https://{api_host}"), ("PUBLIC_APP_BASE_URL", f"https://{admin_host}")):
        if env.get(key, "").rstrip("/") != expected:
            errors.append(f"{key} must match its configured HTTPS gateway host")
    if {v.strip().rstrip("/") for v in env.get("CORS_ALLOW_ORIGINS", "").split(",")} != {f"https://{admin_host}"}:
        errors.append("CORS_ALLOW_ORIGINS must contain only the configured HTTPS admin origin")
    for name in BACKEND_SERVICES:
        service = services[name]
        current = service.get("environment", {})
        if current.get("APP_ENV") != "production":
            errors.append(f"{name}: APP_ENV must be production")
        try:
            findings, _ = validator.validate_runtime_environment(current)
            errors.extend(f"{name}: {finding}" for finding in findings)
        except (ValueError, TypeError):
            errors.append(f"{name}: malformed production environment")
        if service.get("image") != api.get("image"):
            errors.append(f"{name}: backend image must match the API image")
        for key in SHARED_SETTINGS:
            if current.get(key) != env.get(key):
                errors.append(f"{name}: {key} must match the API configuration")
        if name != "api" and service.get("ports"):
            errors.append(f"{name}: backend workers/tools must not publish ports")
    errors.extend(validator.validate_backend_image(api.get("image", "")))
    errors.extend(error.replace("DIMAX_BACKEND_IMAGE", "DIMAX_ADMIN_IMAGE")
                  for error in validator.validate_backend_image(services["admin"].get("image", "")))
    for name in ("api", "admin"):
        if any(port.get("host_ip") not in {"127.0.0.1", "::1"} for port in services[name].get("ports", [])):
            errors.append(f"{name}: direct published ports must bind only to loopback")
    worker = services["outbox-worker"]
    if worker.get("restart") != "unless-stopped" or worker.get("healthcheck", {}).get("disable"):
        errors.append("outbox-worker requires restart supervision and an enabled healthcheck")
    if worker.get("healthcheck", {}).get("test") != ["CMD", "python", "-m", "app.workers.outbox_health"]:
        errors.append("outbox-worker must use the committed-pass health probe")
    if bootstrap:
        setup_env = {**services["bootstrap"].get("environment", {}), "DIMAX_BACKEND_IMAGE": api.get("image", "")}
        findings, _ = validator.validate_environment(setup_env)
        errors.extend(f"bootstrap: {finding}" for finding in findings)
    if inspect_admin_image and not errors:
        try:
            result = subprocess.run(["docker", "image", "inspect", services["admin"]["image"]],
                                    capture_output=True, text=True, timeout=30, check=True)
            image = json.loads(result.stdout)[0]
            built_env = dict(item.split("=", 1) for item in image["Config"].get("Env", []) if "=" in item)
            if built_env.get("NEXT_PUBLIC_API_BASE_URL", "").rstrip("/") != f"https://{api_host}":
                errors.append("Admin image was built for a different API origin; rebuild it before deployment")
            if image["Config"].get("User") != "10001:10001":
                errors.append("Admin image must run as 10001:10001")
        except (OSError, subprocess.SubprocessError, ValueError, KeyError, IndexError, TypeError):
            errors.append("Cannot validate the local admin image; pull the selected image and retry")
    return errors


def main(argv=None, stream=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--bootstrap", action="store_true")
    parser.add_argument("--inspect-admin-image", action="store_true")
    args = parser.parse_args(argv)
    try:
        errors = validate(json.load(stream or sys.stdin), bootstrap=args.bootstrap, inspect_admin_image=args.inspect_admin_image)
    except (ValueError, TypeError, KeyError, AttributeError):
        print("Preflight rejected malformed Compose data. No configuration values are printed.", file=sys.stderr)
        return 2
    if errors:
        print("Production preflight failed:", file=sys.stderr)
        for error in dict.fromkeys(errors):
            print(f"- {error}", file=sys.stderr)
        return 1
    print("PASS: deployment configuration agrees; external DNS/TLS/SMTP delivery is not verified.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
