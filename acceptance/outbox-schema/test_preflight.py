import ast
from copy import deepcopy
import unittest

import preflight
import probe
import preview_sql


def catalog():
    return {
        'session': [{'read_only': 'on', 'schema': 'public'}],
        'revisions': [{'version_num': preflight.SOURCE}],
        'relations': [{'schema': 'public', 'name': name, 'kind': 'r'}
                      for name in ('alembic_version', 'outbox_messages')],
        'constraints': [{'table_name': name, 'kind': 'p', 'validated': True,
                         'definition': 'PRIMARY KEY (id)', 'name': name + '_pkey'}
                        for name in ('outbox_messages', 'companies', 'users')],
        'columns': [{'table_name': 'outbox_messages', 'column_name': name,
                     'data_type': 'uuid', 'is_nullable': 'NO'} for name in ('id', 'company_id')],
        'functions': [], 'triggers': [], 'long_transactions': [{'count': 0}],
    }


class PreflightTests(unittest.TestCase):
    def test_ready_still_requires_backup_rehearsal_and_approval(self):
        self.assertEqual(preflight.decision(catalog()), 'PREPARED_REQUIRES_BACKUP_REHEARSAL_AND_APPROVAL')

    def test_revision_must_be_exact_single_predecessor(self):
        for revisions in ([], [{'version_num': '0087'}], [{'version_num': preflight.TARGET}],
                          [{'version_num': preflight.SOURCE}, {'version_num': 'other'}]):
            report = catalog()
            report['revisions'] = revisions
            self.assertEqual(preflight.decision(report), 'BLOCKED_REVISION_REQUIRES_REVIEW')

    def test_partial_schema_including_other_namespace_blocks(self):
        for key, value in (
            ('relations', {'schema': 'other', 'name': 'outbox_recoveries', 'kind': 'r'}),
            ('functions', {'name': 'outbox_recovery_decision_immutable'}),
            ('triggers', {'name': 'outbox_recovery_decision_immutable'}),
            ('constraints', {'name': 'uq_outbox_message_tenant'}),
        ):
            report = catalog()
            report[key].append(value)
            self.assertEqual(preflight.decision(report), 'BLOCKED_PARTIAL_OR_SHADOW_SCHEMA')

    def test_readonly_schema_constraints_and_transactions(self):
        cases = [
            ('session', [{'read_only': 'off', 'schema': 'public'}], 'NOT_READ_ONLY'),
            ('session', [{'read_only': 'on', 'schema': 'other'}], 'SEARCH_PATH'),
            ('relations', [], 'BASE_RELATIONS'),
            ('constraints', [], 'PRIMARY_KEYS'),
            ('columns', [], 'BASE_COLUMNS'),
            ('long_transactions', [{'count': 1}], 'LONG_TRANSACTIONS'),
        ]
        for key, value, expected in cases:
            report = deepcopy(catalog())
            report[key] = value
            self.assertEqual(preflight.decision(report), 'BLOCKED_' + expected)

    def test_target_does_not_return_credentials(self):
        self.assertEqual(preflight.target('postgresql+psycopg2://test:secret@db/sample'),
                         {'host': 'db', 'port': 5432, 'database': 'sample'})
        for url in ('sqlite:///a.db', 'postgresql+psycopg2://db/sample?options=unsafe'):
            with self.assertRaises(ValueError):
                preflight.target(url)

    def test_ancestry_is_parsed_without_executing_source(self):
        source = "raise RuntimeError('must not execute')\nrevision='0089_outbox_recovery'\ndown_revision='0088_work_stages'"
        self.assertEqual(preflight.migration_metadata(source)['revision'], preflight.TARGET)
        with self.assertRaises(RuntimeError):
            preflight.migration_metadata("revision='other'\ndown_revision='0088_work_stages'")

    def test_probe_queries_are_select_only(self):
        for query in probe.QUERIES.values():
            self.assertTrue(query.strip().upper().startswith('SELECT '))
            self.assertNotIn(';', query)
        self.assertIn('default_transaction_read_only=on', probe.OPTIONS)
        self.assertIn('statement_timeout=5000', probe.OPTIONS)
        self.assertIn('lock_timeout=1000', probe.OPTIONS)
        source = (preflight.HERE / 'probe.py').read_text(encoding='utf-8')
        calls = [node.func.attr for node in ast.walk(ast.parse(source))
                 if isinstance(node, ast.Call) and isinstance(node.func, ast.Attribute)]
        self.assertNotIn('commit', calls)
        self.assertIn('rollback', calls)

    def test_sql_renderer_is_offline_and_does_not_import_application(self):
        tree = ast.parse(preview_sql.RENDER)
        imports = [node.module for node in ast.walk(tree) if isinstance(node, ast.ImportFrom)]
        self.assertEqual(imports, ['alembic.migration', 'alembic.operations'])
        self.assertIn("'as_sql': True", preview_sql.RENDER)
        self.assertNotIn('create_engine', preview_sql.RENDER)
        self.assertNotIn('DATABASE_URL', preview_sql.RENDER)


if __name__ == '__main__':
    unittest.main()
