"""Idempotent reference data for the isolated acceptance database only."""
from __future__ import annotations

import json
import os
import uuid
from datetime import datetime, timezone
from decimal import Decimal

from sqlalchemy import text
from sqlalchemy.engine import make_url

from app.core.config import settings
from app.core.security.password import hash_password
from app.modules.addons.infrastructure.models import AddonTypeORM
from app.modules.companies.infrastructure.models import CompanyPlanORM
from app.modules.door_types.infrastructure.models import DoorTypeORM
from app.modules.identity.domain.enums import UserRole
from app.modules.identity.infrastructure.models import AdminProfileORM, CompanyORM, UserORM
from app.modules.installers.infrastructure.models import InstallerORM, InstallerProfileORM
from app.modules.library.infrastructure.models import ProductLibraryItemORM
from app.modules.rates.infrastructure.models import InstallerRateORM
from app.modules.reasons.infrastructure.default_seed import seed_default_reasons
from app.shared.infrastructure.db.session import SessionLocal


def stable_id(key: str) -> uuid.UUID:
    return uuid.uuid5(uuid.NAMESPACE_URL, f"https://example.test/dimax-acceptance/{key}")


def main() -> None:
    url = make_url(settings.DATABASE_URL)
    if (
        os.environ.get("APP_ENV") != "test"
        or url.host != "db"
        or url.database != "dimax_acceptance"
        or settings.SMTP_HOST != "mailpit"
        or settings.WHATSAPP_ENABLED
    ):
        raise RuntimeError("Only the isolated acceptance compose environment is allowed")
    password = os.environ.get("DIMAX_ACCEPTANCE_PASSWORD")
    if not password or len(password) < 14:
        raise RuntimeError("Set a test-only DIMAX_ACCEPTANCE_PASSWORD with at least 14 characters")

    with SessionLocal.begin() as session:
        if session.execute(text("SELECT current_database()")).scalar_one() != "dimax_acceptance":
            raise RuntimeError("Unexpected database")

        def add_once(model, key, **values):
            identity = stable_id(key)
            existing = session.get(model, identity)
            if existing is not None:
                if "company_id" in values and existing.company_id != values["company_id"]:
                    raise RuntimeError("Acceptance identity collision")
                return existing
            obj = model(id=identity, **values)
            session.add(obj)
            session.flush()
            return obj

        summary = {}
        for company_key in ("a", "b"):
            company = add_once(
                CompanyORM, company_key, name=f"DIMAX Acceptance {company_key.upper()}", is_active=True
            )
            if company.name != f"DIMAX Acceptance {company_key.upper()}":
                raise RuntimeError("Refusing to reuse a non-acceptance company")
            add_once(
                CompanyPlanORM, f"{company_key}/plan", company_id=company.id,
                plan_code="acceptance", is_active=True, currency="ILS",
            )
            users = []
            scopes = ("OWNER", "OPERATIONS", "FINANCE", "VIEWER") if company_key == "a" else ("OWNER",)
            for scope in scopes:
                email = f"{scope.lower()}.{company_key}@example.test"
                user = add_once(
                    UserORM, f"{company_key}/{scope}", company_id=company.id,
                    email=email, full_name=f"Acceptance {company_key.upper()} {scope}",
                    role=UserRole.ADMIN, password_hash=hash_password(password),
                    is_active=True, status="ACTIVE",
                )
                add_once(
                    AdminProfileORM, f"{company_key}/{scope}/profile", company_id=company.id,
                    user_id=user.id, admin_scope=scope, can_view_rates=scope in {"OWNER", "FINANCE"},
                    can_manage_imports=scope in {"OWNER", "OPERATIONS"}, can_manage_users=scope == "OWNER",
                )
                users.append(email)
            types = []
            for code, name in (("ENTRANCE", "Entrance / Входная"), ("FIRE", "Fire / Огнестойкая")):
                door_type = add_once(
                    DoorTypeORM, f"{company_key}/type/{code}", company_id=company.id,
                    code=code.lower(), name=name, is_active=True, is_critical_default=False,
                )
                door_type.code = code.lower()
                types.append(door_type)
                add_once(
                    ProductLibraryItemORM, f"{company_key}/product/{code}", company_id=company.id,
                    sku=f"QA-{code}", name_ru=name, name_he="דלת בדיקה", install_type=code,
                    unit="piece", status="ACTIVE",
                )
            for number in (1, 2):
                email = f"installer{number}.{company_key}@example.test"
                name = f"Test Installer {company_key.upper()}-{number}"
                user = add_once(
                    UserORM, f"{company_key}/installer/{number}/user", company_id=company.id,
                    email=email, full_name=name, role=UserRole.INSTALLER,
                    password_hash=hash_password(password), is_active=True, status="ACTIVE",
                )
                installer = add_once(
                    InstallerORM, f"{company_key}/installer/{number}", company_id=company.id,
                    full_name=name, email=email, user_id=user.id, is_active=True, status="ACTIVE",
                )
                if session.get(InstallerProfileORM, user.id) is None:
                    session.add(InstallerProfileORM(
                        user_id=user.id, company_id=company.id, installer_id=installer.id,
                        display_name=name, language="ru", is_active=True,
                    ))
                for door_type in types:
                    add_once(
                        InstallerRateORM, f"{company_key}/rate/{number}/{door_type.code.upper()}",
                        company_id=company.id, installer_id=installer.id, door_type_id=door_type.id,
                        price=Decimal("250.00"), effective_from=datetime(2026, 1, 1, tzinfo=timezone.utc),
                    )
                users.append(email)
            add_once(
                AddonTypeORM, f"{company_key}/addon", company_id=company.id,
                name="Test adjustment / Регулировка", unit="pcs", default_client_price=Decimal("80"),
                default_installer_price=Decimal("50"), is_active=True,
            )
            seed_default_reasons(session, company_id=company.id)
            summary[company_key] = {"company_id": str(company.id), "users": users}
    print(json.dumps(summary, ensure_ascii=False))


if __name__ == "__main__":
    main()
