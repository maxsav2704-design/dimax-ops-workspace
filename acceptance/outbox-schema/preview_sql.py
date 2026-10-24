"""Render the pinned upgrade as review-only SQL, with no database connection."""
import argparse
from hashlib import sha256
import json
from pathlib import Path

import preflight


RENDER = '''import io, json, sys
from alembic.migration import MigrationContext
from alembic.operations import Operations
source = json.load(sys.stdin)['source']
buffer = io.StringIO()
context = MigrationContext.configure(dialect_name='postgresql',
    opts={'as_sql': True, 'output_buffer': buffer})
namespace = {'__name__': 'pinned_migration_preview'}
exec(compile(source, 'pinned_0089.py', 'exec'), namespace)
with Operations.context(context):
    namespace['upgrade']()
print(buffer.getvalue())
'''


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--report-dir', required=True)
    args = parser.parse_args()
    directory = Path(args.report_dir).resolve()
    if not directory.is_relative_to((preflight.ROOT / 'artifacts').resolve()):
        raise ValueError('Expected private artifacts directory')
    output = directory / '0089-review-only.sql'
    manifest = directory / 'preparation-manifest.json'
    if output.exists() or manifest.exists():
        raise ValueError('Do not overwrite previous evidence')
    report = json.loads((directory / 'catalog-report.json').read_text(encoding='utf-8'))
    source = (directory / '0089_outbox_recovery.pinned.py').read_bytes()
    verified = preflight.command(['git', '-C', str(preflight.ROOT / 'backend'), 'show',
                                 f'{preflight.PIN}:{preflight.MIGRATION}'])
    if source != verified or sha256(source).hexdigest() != report['migration']['sha256']:
        raise ValueError('Pinned migration mismatch')
    if report['outcome'] != 'PREPARED_REQUIRES_BACKUP_REHEARSAL_AND_APPROVAL':
        raise ValueError('Preflight blocked; SQL preview not generated')
    preflight.migration_metadata(source)
    rendered = preflight.command(['docker', 'exec', '-i', preflight.API, 'python', '-B', '-c', RENDER],
                                 stdin=json.dumps({'source': source.decode('utf-8')}).encode('utf-8'))
    sql = (b'-- REVIEW ONLY: not a deployment script. No DB connection was opened.\n'
           b'-- Does not update alembic_version. Use pinned Alembic after backup and approval.\n' + rendered)
    output.write_bytes(sql)
    manifest.write_text(json.dumps({
        'status': 'PREPARED_NOT_APPLIED', 'source_revision': preflight.SOURCE,
        'target_revision': preflight.TARGET, 'backend_commit': preflight.PIN,
        'migration_sha256': sha256(source).hexdigest(), 'sql_sha256': sha256(sql).hexdigest(),
        'database_writes': False, 'worker_started': False,
        'pending': ['Private backup and verified restore', 'Fresh preflight in agreed maintenance window',
                    'Approval for exact migration with bounded lock/statement timeouts',
                    'Schema and recovery-mode verification', 'Separate approval before mail dispatch resumes'],
    }, indent=2), encoding='utf-8')
    print(json.dumps({'status': 'PREPARED_NOT_APPLIED', 'sql': str(output), 'manifest': str(manifest)}))


if __name__ == '__main__':
    main()
