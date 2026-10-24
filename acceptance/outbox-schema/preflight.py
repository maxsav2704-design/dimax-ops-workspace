"""Metadata-only preflight. There is deliberately no apply/start/migrate command."""
import argparse
import ast
from hashlib import sha256
import json
from pathlib import Path
import subprocess
from urllib.parse import urlsplit

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
API = "dimaxoperationssuite-api-1"
WORKER = "dimaxoperationssuite-outbox-worker-1"
SOURCE = "0088_work_stages"
TARGET = "0089_outbox_recovery"
PIN = "ee10b44c08d1dd175d6bc49ed14b64cc77cb0613"
MIGRATION = "alembic/versions/0089_outbox_recovery.py"


def command(args, *, stdin=None):
    result = subprocess.run(args, input=stdin, capture_output=True, timeout=60)
    if result.returncode:
        raise RuntimeError(f"Command failed ({args[0]}); raw output suppressed to protect settings")
    return result.stdout


def target(value):
    parsed = urlsplit(value)
    if parsed.scheme != "postgresql+psycopg2" or parsed.query or parsed.fragment:
        raise ValueError("Unsupported database configuration; manual inspection required")
    return {"host": parsed.hostname, "port": parsed.port or 5432, "database": parsed.path.lstrip('/')}


def env(container):
    return dict(pair.split('=', 1) for pair in container['Config'].get('Env', []) if '=' in pair)


def decision(report):
    if report['session'][0]['read_only'] != 'on':
        return 'BLOCKED_NOT_READ_ONLY'
    if [row['version_num'] for row in report['revisions']] != [SOURCE]:
        return 'BLOCKED_REVISION_REQUIRES_REVIEW'
    recovery_names = {'outbox_recoveries', 'outbox_recovery_items', 'outbox_recovery_decisions'}
    if any(row['name'] in recovery_names for row in report['relations']) or report['functions'] or report['triggers']:
        return 'BLOCKED_PARTIAL_OR_SHADOW_SCHEMA'
    if any(row['name'] == 'uq_outbox_message_tenant' for row in report['constraints']):
        return 'BLOCKED_PARTIAL_OR_SHADOW_SCHEMA'
    if report['session'][0]['schema'] != 'public':
        return 'BLOCKED_SEARCH_PATH'
    required = {('public', name, 'r') for name in ('alembic_version', 'outbox_messages')}
    actual = {(row['schema'], row['name'], row['kind']) for row in report['relations']}
    if not required.issubset(actual) or any(row['schema'] != 'public' for row in report['relations']):
        return 'BLOCKED_BASE_RELATIONS'
    primary_keys = {row['table_name'] for row in report['constraints']
                    if row['kind'] == 'p' and row['validated'] and row['definition'] == 'PRIMARY KEY (id)'}
    if not {'outbox_messages', 'companies', 'users'}.issubset(primary_keys):
        return 'BLOCKED_PRIMARY_KEYS'
    columns = {(row['column_name'], row['data_type'], row['is_nullable']) for row in report['columns']
               if row['table_name'] == 'outbox_messages'}
    if not {('company_id', 'uuid', 'NO'), ('id', 'uuid', 'NO')}.issubset(columns):
        return 'BLOCKED_BASE_COLUMNS'
    if report['long_transactions'][0]['count']:
        return 'BLOCKED_LONG_TRANSACTIONS'
    return 'PREPARED_REQUIRES_BACKUP_REHEARSAL_AND_APPROVAL'


def migration_metadata(source):
    values = {}
    for node in ast.parse(source).body:
        if isinstance(node, ast.Assign):
            for name in node.targets:
                if isinstance(name, ast.Name) and name.id in {'revision', 'down_revision'}:
                    values[name.id] = ast.literal_eval(node.value)
    if values != {'revision': TARGET, 'down_revision': SOURCE}:
        raise RuntimeError('Unexpected migration ancestry')
    return values


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', required=True, help='New directory strictly under workspace artifacts/')
    args = parser.parse_args()
    output = Path(args.output).resolve()
    artifacts = (ROOT / 'artifacts').resolve()
    if output == artifacts or not output.is_relative_to(artifacts) or output.exists():
        raise ValueError('Use a new private artifacts subdirectory')
    api, worker = json.loads(command(['docker', 'inspect', API, WORKER]))
    if api['State']['Status'] != 'running' or worker['State']['Status'] != 'exited':
        raise RuntimeError('API must be running and mail worker stopped; no service changes attempted')
    api_env, worker_env = env(api), env(worker)
    api_target, worker_target = target(api_env['DATABASE_URL']), target(worker_env['DATABASE_URL'])
    if api_target != worker_target:
        raise RuntimeError('Different API/worker database targets; stop for investigation')
    probe = (HERE / 'probe.py').read_bytes()
    report = json.loads(command(['docker', 'exec', '-i', '--workdir', '/app', API,
                                'python', '-B', '-'], stdin=probe))
    if report['configured_target'] != worker_target:
        raise RuntimeError('Probe settings differ from worker target')
    pinned = command(['git', '-C', str(ROOT / 'backend'), 'show', f'{PIN}:{MIGRATION}'])
    local = (ROOT / 'backend' / MIGRATION).read_bytes()
    canonical = lambda value: value.replace(b'\r\n', b'\n')
    if canonical(pinned) != canonical(local):
        raise RuntimeError('Local migration differs from verified revision; do not modify Claude files')
    migration_metadata(pinned)
    after = json.loads(command(['docker', 'inspect', API, WORKER]))
    if any(before['Id'] != later['Id'] or before['State']['StartedAt'] != later['State']['StartedAt']
           or before['State']['Status'] != later['State']['Status'] for before, later in zip((api, worker), after)):
        raise RuntimeError('Service state changed during preflight; report not valid')
    mounts = lambda container: [(m['Type'], m['Source'], m['Destination']) for m in container['Mounts'] if m['Destination'] == '/app']
    report['services'] = {'api_image': api['Image'], 'worker_image': worker['Image'],
                          'same_app_mount': mounts(api) == mounts(worker), 'worker_state': worker['State']['Status']}
    report['migration'] = {'source': SOURCE, 'target': TARGET, 'verified_commit': PIN,
                           'sha256': sha256(pinned).hexdigest(), 'local_matches_verified': True}
    report['outcome'] = decision(report)
    if api['Image'] != worker['Image'] or not report['services']['same_app_mount']:
        report['outcome'] = 'BLOCKED_SERVICE_CODE_MISMATCH'
    output.mkdir(parents=True)
    (output / 'catalog-report.json').write_text(json.dumps(report, indent=2, ensure_ascii=True), encoding='utf-8')
    (output / '0089_outbox_recovery.pinned.py').write_bytes(pinned)
    print(json.dumps({'outcome': report['outcome'], 'revision': report['revisions'], 'worker': 'exited',
                      'report': str(output / 'catalog-report.json')}, ensure_ascii=True))


if __name__ == '__main__':
    main()
