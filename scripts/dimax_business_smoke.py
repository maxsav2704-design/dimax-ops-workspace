from __future__ import annotations

import argparse
import atexit
import base64
import json
import sys
import uuid
from datetime import datetime, timezone
from pathlib import Path
from typing import Any
from urllib.error import HTTPError, URLError
from urllib.parse import urlencode, urlparse
from urllib.request import Request, urlopen


class SmokeError(RuntimeError):
    pass


class ApiClient:
    def __init__(self, base_url: str, token: str | None = None) -> None:
        self.base_url = base_url.rstrip("/")
        self.token = token

    def request(
        self,
        method: str,
        path: str,
        *,
        body: dict[str, Any] | None = None,
        query: dict[str, Any] | None = None,
        expected: tuple[int, ...] = (200,),
    ) -> Any:
        url = f"{self.base_url}{path}"
        if query:
            url = f"{url}?{urlencode(query)}"

        data = None
        headers = {"Accept": "application/json"}
        if body is not None:
            data = json.dumps(body).encode("utf-8")
            headers["Content-Type"] = "application/json"
        if self.token:
            headers["Authorization"] = f"Bearer {self.token}"

        request = Request(url, data=data, headers=headers, method=method)
        try:
            with urlopen(request, timeout=30) as response:
                status = response.status
                raw = response.read().decode("utf-8")
        except HTTPError as exc:
            raw = exc.read().decode("utf-8", errors="replace")
            raise SmokeError(
                f"{method} {path} failed with HTTP {exc.code}: {raw[:1000]}"
            ) from exc
        except URLError as exc:
            raise SmokeError(f"{method} {path} failed: {exc.reason}") from exc

        if status not in expected:
            raise SmokeError(
                f"{method} {path} returned HTTP {status}, expected {expected}: {raw[:1000]}"
            )
        if not raw.strip():
            return None
        try:
            return json.loads(raw)
        except json.JSONDecodeError:
            return raw


def load_preview_seed(path: Path) -> dict[str, Any]:
    if not path.exists():
        return {}
    return json.loads(path.read_text(encoding="utf-8"))


def require_value(name: str, value: str | None) -> str:
    if not value:
        raise SmokeError(f"Missing required value: {name}")
    return value


def ensure_local_or_allowed(base_url: str, allow_remote_write: bool) -> None:
    host = (urlparse(base_url).hostname or "").lower()
    if host in {"localhost", "127.0.0.1"}:
        return
    if allow_remote_write:
        return
    raise SmokeError(
        "Remote write smoke is blocked by default. Re-run with --allow-remote-write "
        "only against staging/demo or a dedicated smoke tenant."
    )


def login(
    public_client: ApiClient,
    *,
    company_id: str,
    email: str,
    password: str,
    device_id: str,
) -> dict[str, Any]:
    return public_client.request(
        "POST",
        "/api/v1/auth/login",
        body={
            "company_id": company_id,
            "email": email,
            "password": password,
            "device_id": device_id,
        },
    )


def pick_installer_id(installers: Any, installer_user_id: str, installer_email: str) -> str:
    items = installers if isinstance(installers, list) else installers.get("items", [])
    for item in items:
        if item.get("user_id") == installer_user_id:
            return item["id"]
    for item in items:
        if (item.get("email") or "").lower() == installer_email.lower():
            return item["id"]
    raise SmokeError("Could not find installer profile for logged-in installer user")


def assert_true(condition: bool, message: str) -> None:
    if not condition:
        raise SmokeError(message)


def b64(text: str) -> str:
    return base64.b64encode(text.encode("utf-8")).decode("ascii")


def cleanup_api_resource(client: ApiClient, path: str) -> None:
    try:
        client.request("DELETE", path, expected=(200, 204))
    except SmokeError as exc:
        print(f"Business smoke cleanup warning: {exc}", file=sys.stderr)


def write_evidence(summary: dict[str, Any], evidence_dir: Path) -> dict[str, str]:
    evidence_dir.mkdir(parents=True, exist_ok=True)
    try:
        checked_at = datetime.fromisoformat(summary["checked_at"])
        stamp = checked_at.strftime("%Y%m%dT%H%M%SZ")
    except ValueError:
        stamp = summary["checked_at"].replace(":", "").replace("+", "Z")
    smoke_id = summary["smoke_id"]
    base_name = f"business-smoke-{stamp}-{smoke_id}"
    json_path = evidence_dir / f"{base_name}.json"
    md_path = evidence_dir / f"{base_name}.md"
    latest_json_path = evidence_dir / "business-smoke-latest.json"
    latest_md_path = evidence_dir / "business-smoke-latest.md"
    evidence = {
        "json_path": str(json_path),
        "markdown_path": str(md_path),
        "latest_json_path": str(latest_json_path),
        "latest_markdown_path": str(latest_md_path),
    }
    evidence_summary = {**summary, "evidence": evidence}

    json_text = json.dumps(evidence_summary, ensure_ascii=False, indent=2)
    json_path.write_text(json_text + "\n", encoding="utf-8")
    latest_json_path.write_text(json_text + "\n", encoding="utf-8")

    markdown = "\n".join(
        [
            "# DIMAX Business Smoke Evidence",
            "",
            f"- Status: `{summary['status']}`",
            f"- Checked at: `{summary['checked_at']}`",
            f"- Base URL: `{summary['base_url']}`",
            f"- Company ID: `{summary['company_id']}`",
            f"- Admin user: `{summary['admin_email']}`",
            f"- Installer user: `{summary['installer_email']}`",
            f"- Project: `{summary['project_name']}`",
            f"- Project ID: `{summary['project_id']}`",
            f"- Order number: `{summary['order_number']}`",
            f"- Imported doors: `{summary['imported_count']}`",
            f"- Bulk assigned doors: `{summary['assigned_count']}`",
            f"- Completed door ID: `{summary['completed_door_id']}`",
            f"- Ledger amount: `{summary['ledger_amount']}`",
            f"- Completion percent: `{summary['completion_pct']}`",
            f"- Plan/fact total doors: `{summary['plan_fact']['total_doors']}`",
            f"- Plan/fact installed doors: `{summary['plan_fact']['installed_doors']}`",
            f"- Plan/fact not installed doors: `{summary['plan_fact']['not_installed_doors']}`",
            f"- Actual payroll total: `{summary['plan_fact']['actual_payroll_total']}`",
            "",
            "## Business Checks",
            "",
            "- Door import created exactly 2 doors.",
            "- Bulk assignment assigned both smoke doors to the installer.",
            "- Installer sync included only the assigned smoke project doors needed for the flow.",
            "- Installer completed one assigned door.",
            "- Admin earnings ledger contains the completed door.",
            "- Installer earnings summary contains the completed door.",
            "- Project plan/fact report reflects 1 installed and 1 remaining door.",
            "",
            "## Evidence Files",
            "",
            f"- JSON: `{json_path}`",
            f"- Markdown: `{md_path}`",
            "",
        ]
    )
    md_path.write_text(markdown, encoding="utf-8")
    latest_md_path.write_text(markdown, encoding="utf-8")

    return evidence


def parse_args() -> argparse.Namespace:
    workspace_root = Path(__file__).resolve().parents[1]
    seed_path = workspace_root / "dimax-operations-suite-main" / ".preview-seed.json"
    evidence_dir = workspace_root / "artifacts" / "release"

    seed_parser = argparse.ArgumentParser(add_help=False)
    seed_parser.add_argument("--preview-seed", default=str(seed_path))
    seed_args, _ = seed_parser.parse_known_args()
    seed = load_preview_seed(Path(seed_args.preview_seed))

    parser = argparse.ArgumentParser(
        parents=[seed_parser],
        description="Run DIMAX API business smoke: import doors, assign installer, sync, complete work, verify reports."
    )
    parser.add_argument("--base-url", default=seed.get("api_base_url", "http://127.0.0.1:8000"))
    parser.add_argument("--company-id", default=seed.get("company_id"))
    parser.add_argument("--admin-email", default=seed.get("admin", {}).get("email"))
    parser.add_argument("--admin-password", default=seed.get("admin", {}).get("password"))
    parser.add_argument("--installer-email", default=seed.get("installer", {}).get("email"))
    parser.add_argument("--installer-password", default=seed.get("installer", {}).get("password"))
    parser.add_argument("--allow-remote-write", action="store_true")
    parser.add_argument("--evidence-dir", default=str(evidence_dir))
    parser.add_argument("--no-evidence", action="store_true")
    parser.add_argument(
        "--keep-data",
        action="store_true",
        help="Keep temporary smoke resources for manual inspection.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    base_url = require_value("base-url", args.base_url)
    ensure_local_or_allowed(base_url, args.allow_remote_write)

    company_id = require_value("company-id", args.company_id)
    admin_email = require_value("admin-email", args.admin_email)
    admin_password = require_value("admin-password", args.admin_password)
    installer_email = require_value("installer-email", args.installer_email)
    installer_password = require_value("installer-password", args.installer_password)

    suffix = uuid.uuid4().hex[:8]
    public = ApiClient(base_url)
    public.request("GET", "/health")

    admin_login = login(
        public,
        company_id=company_id,
        email=admin_email,
        password=admin_password,
        device_id=f"business-smoke-admin-{suffix}",
    )
    installer_login = login(
        public,
        company_id=company_id,
        email=installer_email,
        password=installer_password,
        device_id=f"business-smoke-installer-{suffix}",
    )

    admin = ApiClient(base_url, token=admin_login["access_token"])
    installer = ApiClient(base_url, token=installer_login["access_token"])
    installer_user_id = installer_login["user"]["id"]
    installer_id = pick_installer_id(
        admin.request("GET", "/api/v1/admin/installers"),
        installer_user_id,
        installer_email,
    )

    door_type_code = f"smoke-door-{suffix}"
    door_type = admin.request(
        "POST",
        "/api/v1/admin/door-types",
        body={"code": door_type_code, "name": f"Smoke Door {suffix}", "is_active": True},
        expected=(201,),
    )
    if not args.keep_data:
        atexit.register(
            cleanup_api_resource,
            admin,
            f"/api/v1/admin/door-types/{door_type['id']}",
        )
    rate = admin.request(
        "POST",
        "/api/v1/admin/installer-rates",
        body={
            "installer_id": installer_id,
            "door_type_id": door_type["id"],
            "price": "80.00",
            "effective_from": datetime.now(timezone.utc).isoformat(),
        },
        expected=(201,),
    )
    if not args.keep_data:
        atexit.register(
            cleanup_api_resource,
            admin,
            f"/api/v1/admin/installer-rates/{rate['id']}",
        )
    project = admin.request(
        "POST",
        "/api/v1/admin/projects",
        body={"name": f"Business Smoke {suffix}", "address": f"Smoke Address {suffix}"},
    )
    if not args.keep_data:
        atexit.register(
            cleanup_api_resource,
            admin,
            f"/api/v1/admin/projects/{project['id']}",
        )

    order_number = f"SMOKE-{suffix.upper()}"
    csv_payload = (
        "order_number,house,floor,apartment,location,marking,door_type,qty,price\n"
        f"{order_number},A,4,401,dira,D-401,{door_type_code},1,150\n"
        f"{order_number},A,4,402,mamad,M-402,{door_type_code},1,150\n"
    )
    import_result = admin.request(
        "POST",
        f"/api/v1/admin/projects/{project['id']}/doors/import-file",
        body={
            "filename": f"business_smoke_{suffix}.csv",
            "content_base64": b64(csv_payload),
            "default_our_price": "0",
        },
    )
    assert_true(import_result.get("imported") == 2, "Door import did not create 2 doors")

    details = admin.request("GET", f"/api/v1/admin/projects/{project['id']}")
    project_name = details.get("name") or f"Business Smoke {suffix}"
    imported_doors = sorted(
        [door for door in details["doors"] if door.get("order_number") == order_number],
        key=lambda door: door.get("apartment_number") or "",
    )
    assert_true(len(imported_doors) == 2, "Project details did not return imported smoke doors")
    door_ids = [door["id"] for door in imported_doors]

    bulk = admin.request(
        "POST",
        "/api/v1/admin/projects/doors/bulk-assign-installer",
        body={"door_ids": door_ids, "installer_id": installer_id},
    )
    assert_true(bulk.get("assigned") == 2, "Bulk assignment did not assign both smoke doors")

    sync = installer.request(
        "POST",
        "/api/v1/installer/sync",
        body={
            "since_cursor": 0,
            "ack_cursor": 0,
            "events": [],
            "app_version": "business-smoke",
            "device_id": f"business-smoke-{suffix}",
        },
    )
    snapshot = sync.get("snapshot") or {}
    synced_project_doors = [
        door for door in snapshot.get("doors", []) if door.get("project_id") == project["id"]
    ]
    synced_ids = {door.get("id") for door in synced_project_doors}
    assert_true(set(door_ids).issubset(synced_ids), "Installer sync did not include assigned doors")

    installed_door_id = door_ids[0]
    installer.request(
        "PATCH",
        f"/api/v1/installer/doors/{installed_door_id}/status",
        body={"status": "IN_PROGRESS"},
    )
    installer.request(
        "PATCH",
        f"/api/v1/installer/doors/{installed_door_id}/status",
        body={"status": "INSTALLED"},
    )

    ledger = admin.request(
        "GET",
        "/api/v1/admin/earnings/ledger",
        query={
            "installer_id": installer_id,
            "project_id": project["id"],
            "work_kind": "DOOR",
            "entry_type": "ORIGINAL",
        },
    )
    ledger_items = ledger.get("items", [])
    installed_ledger = next(
        (item for item in ledger_items if item.get("door_id") == installed_door_id),
        None,
    )
    assert_true(installed_ledger is not None, "Admin earnings ledger missed installed smoke door")
    assert_true(
        str(installed_ledger["amount_snapshot"]) == "80.00",
        "Admin earnings ledger amount is not 80.00",
    )

    earnings = installer.request(
        "GET",
        "/api/v1/installer/earnings/summary",
        query={"period": "day"},
    )
    row_match = any(
        row.get("project_id") == project["id"]
        and row.get("door_label") == installed_ledger.get("door_label")
        and str(row.get("amount")) == "80.00"
        for row in earnings.get("rows", [])
    )
    assert_true(row_match, "Installer earnings summary missed installed smoke door")

    plan_fact = admin.request(
        "GET",
        f"/api/v1/admin/reports/project-plan-fact/{project['id']}",
    )
    assert_true(plan_fact.get("total_doors") == 2, "Plan/fact total_doors mismatch")
    assert_true(plan_fact.get("installed_doors") == 1, "Plan/fact installed_doors mismatch")
    assert_true(plan_fact.get("not_installed_doors") == 1, "Plan/fact remaining doors mismatch")
    assert_true(str(plan_fact.get("actual_payroll_total")) == "80.00", "Plan/fact payroll mismatch")

    sync_health = admin.request("GET", "/api/v1/admin/sync/health/summary")

    summary = {
        "status": "ok",
        "smoke_id": suffix,
        "checked_at": datetime.now(timezone.utc).isoformat(),
        "base_url": base_url,
        "company_id": company_id,
        "admin_email": admin_email,
        "installer_email": installer_email,
        "project_id": project["id"],
        "project_name": project_name,
        "installer_id": installer_id,
        "door_type_id": door_type["id"],
        "rate_id": rate["id"],
        "order_number": order_number,
        "import_filename": f"business_smoke_{suffix}.csv",
        "imported_count": import_result.get("imported"),
        "assigned_count": bulk.get("assigned"),
        "imported_door_ids": door_ids,
        "completed_door_id": installed_door_id,
        "completed_door_label": installed_ledger.get("door_label"),
        "ledger_amount": str(installed_ledger["amount_snapshot"]),
        "completion_pct": plan_fact.get("completion_pct"),
        "plan_fact": {
            "total_doors": plan_fact.get("total_doors"),
            "installed_doors": plan_fact.get("installed_doors"),
            "not_installed_doors": plan_fact.get("not_installed_doors"),
            "actual_payroll_total": str(plan_fact.get("actual_payroll_total")),
        },
        "sync_health_keys": sorted(sync_health.keys()) if isinstance(sync_health, dict) else [],
    }
    if not args.no_evidence:
        summary["evidence"] = write_evidence(summary, Path(args.evidence_dir))
    print(json.dumps(summary, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except SmokeError as exc:
        print(f"Business smoke failed: {exc}", file=sys.stderr)
        raise SystemExit(1)
