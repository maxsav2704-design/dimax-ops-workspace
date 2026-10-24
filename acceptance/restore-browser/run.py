"""CI-only disaster rehearsal using owned, disposable resources and pinned code."""
import argparse
from ipaddress import IPv4Address
import json
from pathlib import Path
import os
import re
import signal
import shutil
import subprocess
import sys
import tempfile
import time
from urllib.request import urlopen
from uuid import uuid4

ROOT = Path(__file__).resolve().parents[2]
BACKEND = ROOT / 'inputs/backend'
FRONTEND = ROOT / 'inputs/frontend'
BACKEND_REV = 'ee10b44c08d1dd175d6bc49ed14b64cc77cb0613'
FRONTEND_REV = 'a2ace1ac35129968c2639bf1b6ab181af12c9b39'


def validate_inputs(environ, revisions, images, available):
    if environ.get('GITHUB_ACTIONS') != 'true' or environ.get('DIMAX_RESTORE_BROWSER') != 'synthetic-only':
        raise ValueError('Disposable GitHub runner and explicit opt-in required')
    if revisions != [BACKEND_REV, FRONTEND_REV]:
        raise ValueError('Only reviewed source revisions are allowed')
    if len(images) != 3 or any(not re.fullmatch(r'sha256:[0-9a-f]{64}', image) for image in images):
        raise ValueError('Three immutable image IDs required')
    if available < 4096:
        raise ValueError('At least 4 GiB available RAM required; no services may be stopped automatically')


def wait_http(url):
    last_error = None
    for _ in range(90):
        try:
            with urlopen(url, timeout=3) as response:
                if response.status == 200:
                    return
        except OSError as error:
            last_error = error
        time.sleep(1)
    raise RuntimeError('Isolated HTTP service did not become ready: ' + url) from last_error


def bridge_address(inspected, network):
    address = IPv4Address(inspected['NetworkSettings']['Networks'][network]['IPAddress'])
    if not address.is_private or address.is_loopback or address.is_link_local or address.is_unspecified:
        raise ValueError('Only the owned private bridge address may be forwarded')
    return str(address)


def wait_database(docker, name, database):
    # The image's temporary initdb server accepts Unix sockets, but not TCP.
    for _ in range(60):
        if docker('exec', name, 'pg_isready', '-h', '127.0.0.1', '-U', 'postgres',
                  '-d', database, check=False).returncode == 0:
            return
        time.sleep(1)
    raise RuntimeError('Isolated PostgreSQL not ready')


def exercise(temporary, resources, images, helpers):
    docker, freeze_sources, label_key = helpers
    source, work = temporary / 'source', temporary / 'work'
    source.mkdir()
    work.mkdir()
    freeze_sources(BACKEND, source, resume_outbox=True)
    # The API startup guard imports this script; the worker-only snapshot omits it.
    shutil.copyfile(BACKEND / 'scripts/validate_production_env.py', source / 'scripts/validate_production_env.py')
    shutil.copyfile(Path(__file__).with_name('probe.py'), source / 'browser_probe.py')
    labels = ['--label', f'{label_key}={resources.run_id}']
    network = resources.reserve('network', 'network')
    docker('network', 'create', '--internal', *labels, network)

    def volume(suffix):
        name = resources.reserve('volume', suffix)
        docker('volume', 'create', *labels, name)
        return name

    def container(suffix, image, options, command):
        name = resources.reserve('container', suffix)
        docker('run', '-d', '--pull', 'never', '--name', name, *labels, '--network', network,
               '--read-only', '--cap-drop', 'ALL', '--security-opt', 'no-new-privileges:true',
               '--pids-limit', '128', *options, image, *command)
        return name

    def database(suffix, name):
        data = volume(suffix + '-data')
        pg = container(suffix, images[0], ['--user', 'postgres', '--network-alias', 'recovery-db',
            '--memory', '192m', '--memory-swap', '192m', '--tmpfs', '/tmp:rw,nosuid,size=32m',
            '--tmpfs', '/var/run/postgresql:rw,nosuid,mode=1777,size=4m',
            '--mount', f'type=volume,source={data},target=/var/lib/postgresql/data',
            '--env', f'POSTGRES_DB={name}', '--env', 'POSTGRES_PASSWORD=synthetic-local-only',
            '--env', 'POSTGRES_INITDB_ARGS=--encoding=UTF8 --locale=C'],
            ['postgres', '-c', 'shared_buffers=16MB', '-c', 'max_connections=24', '-c', 'work_mem=1MB'])
        wait_database(docker, pg, name)
        return pg, data

    def storage(suffix):
        data = volume(suffix + '-data')
        name = container(suffix, images[2], ['--network-alias', 'recovery-storage',
            '--memory', '256m', '--memory-swap', '256m', '--tmpfs', '/tmp:rw,nosuid,size=32m',
            '--mount', f'type=volume,source={data},target=/data',
            '--env', 'MINIO_ROOT_USER=synthetic-recovery', '--env', 'MINIO_ROOT_PASSWORD=synthetic-local-only',
            '--env', 'GOMEMLIMIT=192MiB', '--env', 'MINIO_BROWSER=off'], ['server', '/data', '--address', ':9000'])
        return name, data

    def app(suffix, db, script, args, *, restored=False):
        env = {'DIMAX_FULL_RESTORE': 'synthetic-only', 'DIMAX_OUTBOX_RESTORE': 'synthetic-only',
            'DIMAX_RESTORE_BROWSER': 'synthetic-only', 'APP_ENV': 'test',
            'DATABASE_URL': f'postgresql+psycopg2://postgres:synthetic-local-only@recovery-db:5432/{db}',
            'JWT_SECRET': 'synthetic-browser-restore-not-a-real-secret', 'EMAIL_ENABLED': 'false',
            'WHATSAPP_ENABLED': 'false', 'AI_ENABLED': 'false', 'MINIO_ENDPOINT': 'recovery-storage:9000',
            'MINIO_BUCKET': 'dimax-recovery', 'MINIO_ACCESS_KEY': 'synthetic-recovery',
            'MINIO_SECRET_KEY': 'synthetic-local-only', 'MINIO_SECURE': 'false',
            'PUBLIC_BASE_URL': 'https://api.dimax.example', 'PUBLIC_APP_BASE_URL': 'https://app.dimax.example',
            'PYTHONPATH': '/probe', 'PYTHONDONTWRITEBYTECODE': '1', 'CORS_ALLOW_ORIGINS': 'http://127.0.0.1:4196'}
        if restored:
            # Supplied outside the restored database before either API or worker starts.
            env['OUTBOX_RECOVERY_EPOCH'] = resources.run_id
        options = ['--memory', '512m', '--memory-swap', '512m', '--user', f'{os.getuid()}:{os.getgid()}',
            '--workdir', '/probe', '--entrypoint', 'python', '--tmpfs', '/tmp:rw,nosuid,size=64m',
            '--mount', f'type=bind,source={source},target=/probe,readonly',
            '--mount', f'type=bind,source={work},target=/work']
        for key, value in env.items():
            options += ['--env', f'{key}={value}']
        return container(suffix, images[1], options, ['-B', script, *args])

    def job(step, db='dimax_full_source', script='scripts/full_restore_probe.py'):
        name = app(step, db, script, [step])
        try:
            result = subprocess.run(['docker', 'wait', name], capture_output=True, timeout=600, check=True)
            logs = docker('logs', name, check=False)
            print((logs.stdout + logs.stderr).decode(errors='replace')[-24000:], flush=True)
            if result.stdout.strip() != b'0':
                raise RuntimeError('Synthetic phase failed: ' + step)
        finally:
            resources.remove('container', name)

    pg, pg_data = database('source-db', 'dimax_full_source')
    original_store, original_data = storage('source-storage')
    job('seed')
    job('prepare', script='scripts/outbox_restore_probe.py')
    job('prepare', script='browser_probe.py')
    job('backup-pdf')
    dump = temporary / 'source.dump'
    with dump.open('wb') as stream:
        subprocess.run(['docker', 'exec', pg, 'pg_dump', '-U', 'postgres', '-d', 'dimax_full_source', '-Fc'], stdout=stream, check=True, timeout=120)
    job('source-send', script='browser_probe.py')
    for kind, name in (('container', original_store), ('volume', original_data), ('container', pg), ('volume', pg_data)):
        resources.remove(kind, name)
    print('PASS: original test database AND object-store containers/volumes destroyed after backup', flush=True)

    restored_pg, _ = database('restored-db', 'dimax_full_restored')
    with dump.open('rb') as stream:
        subprocess.run(['docker', 'exec', '-i', restored_pg, 'pg_restore', '-U', 'postgres', '-d', 'dimax_full_restored', '--exit-on-error', '--single-transaction'], stdin=stream, check=True, timeout=120)
    job('verify-db', 'dimax_full_restored')
    storage('restored-storage')
    job('restore-pdf', 'dimax_full_restored')
    api = app('api', 'dimax_full_restored', '-m', ['uvicorn', 'app.main:app', '--host', '0.0.0.0', '--port', '8000'], restored=True)
    observer = app('smtp-observer', 'dimax_full_restored', 'browser_probe.py', ['serve'], restored=True)
    relays = []
    try:
        # Internal Docker networks need a host-side loopback relay, not published ports.
        for name, local_port, remote_port in ((api, 18090, 8000), (observer, 18091, 8081)):
            if not resources.owns('container', name):
                raise RuntimeError('Cannot forward an unowned container')
            inspected = json.loads(docker('container', 'inspect', name).stdout)[0]
            address = bridge_address(inspected, network)
            relays.append(subprocess.Popen([
                'socat', f'TCP4-LISTEN:{local_port},bind=127.0.0.1,fork,reuseaddr',
                f'TCP4:{address}:{remote_port}',
            ], start_new_session=True))
        wait_http('http://127.0.0.1:18090/health')
        wait_http('http://127.0.0.1:18091/ready')
        subprocess.run(['node', str(Path(__file__).with_name('browser.mjs')), str(work)], check=True, timeout=420)
        shutil.copyfile(work / 'browser-result.json', ROOT / 'evidence/restore-browser-result.json')
    finally:
        for relay in relays:
            if relay.poll() is None:
                os.killpg(relay.pid, signal.SIGTERM)
            relay.wait(timeout=10)
        for name in (api, observer):
            logs = docker('logs', name, check=False)
            print((logs.stdout + logs.stderr).decode(errors='replace')[-16000:], flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ('postgres', 'app', 'storage'):
        parser.add_argument('--' + name + '-image', required=True)
    args = parser.parse_args()
    sys.path.insert(0, str(BACKEND))
    from scripts.test_full_restore_acceptance import Resources, LABEL, freeze_sources
    from scripts.test_backup_restore_acceptance import docker, free_memory_mib
    images = [args.postgres_image, args.app_image, args.storage_image]
    revisions = [subprocess.check_output(['git', '-C', str(path), 'rev-parse', 'HEAD'], text=True).strip() for path in (BACKEND, FRONTEND)]
    validate_inputs(os.environ, revisions, images, free_memory_mib())
    if any(path.is_file() for root in (BACKEND, FRONTEND) for path in root.glob('.env*') if not path.name.endswith('.example')):
        raise RuntimeError('Unexpected dotenv file in acceptance source')
    resources = Resources(uuid4().hex)
    with tempfile.TemporaryDirectory(prefix='dimax-restore-browser-') as temporary:
        try:
            exercise(Path(temporary), resources, images, (docker, freeze_sources, LABEL))
        finally:
            resources.cleanup()
            print('PASS: owned acceptance resources cleaned; no working services addressed', flush=True)


if __name__ == '__main__':
    main()
