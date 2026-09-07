from __future__ import annotations

import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
COMPOSE_FILES = (
    ROOT / "docker-compose.workspace.yml",
    ROOT / "docker-compose.workspace.test.yml",
    ROOT / "docker-compose.demo.yml",
    ROOT / "backend" / "docker-compose.yml",
)
PUBLIC_POLICY_RE = re.compile(r"mc\s+anonymous\s+set\s+(?!none\b)\S+", re.IGNORECASE)
MASKED_PRIVATE_POLICY_RE = re.compile(
    r"mc\s+anonymous\s+set\s+none[^\n]*\|\|\s*true", re.IGNORECASE
)


def main() -> int:
    errors: list[str] = []
    for path in COMPOSE_FILES:
        if not path.is_file():
            errors.append(f"missing compose file: {path.relative_to(ROOT)}")
            continue

        text = path.read_text(encoding="utf-8")
        relative = path.relative_to(ROOT)
        if "mc anonymous set none" not in text:
            errors.append(f"{relative}: private MinIO policy is not enforced")
        if "set -eu;" not in text or "until mc alias set" not in text:
            errors.append(f"{relative}: MinIO readiness must fail closed with retries")
        match = PUBLIC_POLICY_RE.search(text)
        if match:
            errors.append(f"{relative}: public MinIO policy found: {match.group(0)}")
        if MASKED_PRIVATE_POLICY_RE.search(text):
            errors.append(f"{relative}: private policy failure is masked with || true")

    if errors:
        for error in errors:
            print(f"ERROR: {error}")
        return 1

    print(f"Storage privacy guard passed for {len(COMPOSE_FILES)} compose files.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())