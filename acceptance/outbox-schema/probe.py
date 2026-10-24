"""Run inside the existing API container: catalog-only, read-only, rolled back."""
import json

QUERIES = {
    "session": """SELECT current_database() AS database, current_schema() AS schema,
        current_setting('search_path') AS search_path,
        current_setting('transaction_read_only') AS read_only,
        current_setting('statement_timeout') AS statement_timeout,
        current_setting('lock_timeout') AS lock_timeout,
        inet_server_addr()::text AS server_address, inet_server_port() AS server_port""",
    "revisions": "SELECT version_num FROM public.alembic_version ORDER BY version_num",
    "relations": """SELECT n.nspname AS schema, c.relname AS name, c.relkind AS kind
        FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
        WHERE c.relname IN ('alembic_version','outbox_messages','outbox_recoveries',
          'outbox_recovery_items','outbox_recovery_decisions') ORDER BY 1,2""",
    "constraints": """SELECT c.conname AS name, c.contype AS kind, c.convalidated AS validated,
        t.relname AS table_name, pg_get_constraintdef(c.oid) AS definition
        FROM pg_constraint c JOIN pg_class t ON t.oid=c.conrelid
        JOIN pg_namespace n ON n.oid=t.relnamespace
        WHERE n.nspname='public' AND t.relname IN ('outbox_messages','companies','users',
          'outbox_recoveries','outbox_recovery_items','outbox_recovery_decisions') ORDER BY 4,1""",
    "columns": """SELECT table_name,column_name,data_type,is_nullable
        FROM information_schema.columns WHERE table_schema='public'
        AND table_name IN ('outbox_messages','outbox_recoveries','outbox_recovery_items','outbox_recovery_decisions')
        ORDER BY table_name,ordinal_position""",
    "functions": """SELECT n.nspname AS schema, p.proname AS name
        FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
        WHERE p.proname='outbox_recovery_decision_immutable'""",
    "triggers": """SELECT n.nspname AS schema,t.tgname AS name,t.tgenabled AS enabled
        FROM pg_trigger t JOIN pg_class c ON c.oid=t.tgrelid
        JOIN pg_namespace n ON n.oid=c.relnamespace
        WHERE t.tgname='outbox_recovery_decision_immutable' AND NOT t.tgisinternal""",
    "outbox_size": """SELECT c.reltuples AS estimated_rows,pg_total_relation_size(c.oid) AS total_bytes
        FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
        WHERE n.nspname='public' AND c.relname='outbox_messages'""",
    "long_transactions": """SELECT count(*) AS count FROM pg_stat_activity
        WHERE datname=current_database() AND pid<>pg_backend_pid()
        AND xact_start < now()-interval '30 seconds'""",
}
OPTIONS = "-c default_transaction_read_only=on -c statement_timeout=5000 -c lock_timeout=1000"


def main():
    from sqlalchemy import create_engine, text
    from sqlalchemy.engine import make_url
    from app.core.config import settings

    url = make_url(settings.DATABASE_URL)
    if url.drivername != "postgresql+psycopg2":
        raise RuntimeError("Expected PostgreSQL psycopg2; no connection opened")
    engine = create_engine(url, connect_args={"options": OPTIONS, "connect_timeout": 5,
        "application_name": "dimax_schema_readonly_audit"}, isolation_level="REPEATABLE READ")
    try:
        with engine.connect() as connection:
            connection.execute(text("SET TRANSACTION READ ONLY"))
            report = {name: [dict(row) for row in connection.execute(text(query)).mappings()]
                      for name, query in QUERIES.items()}
            if report["session"][0]["read_only"] != "on":
                raise RuntimeError("Read-only guarantee missing")
            connection.rollback()
        report["configured_target"] = {"host": url.host, "port": url.port or 5432, "database": url.database}
        report["config"] = {"email_enabled": settings.EMAIL_ENABLED,
            "whatsapp_enabled": settings.WHATSAPP_ENABLED,
            "recovery_epoch_configured": settings.OUTBOX_RECOVERY_EPOCH is not None}
        print(json.dumps(report, ensure_ascii=True, default=str))
    finally:
        engine.dispose()


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        # SQLAlchemy exceptions can contain connection strings or parameters.
        print(json.dumps({"error_type": type(error).__name__, "message": "Read-only probe failed; no migration was attempted"}))
        raise SystemExit(1)
